import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/app_version_and_update_service.dart';
import 'package:desperrengue_app/core/services/public_ota_installer.dart';
import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/boot/update_gate.dart';

String release({int build = 29712345, String version = '0.2.0', String notes = 'corrige o login', bool withApk = true}) => jsonEncode({
      'tag_name': 'beta-latest',
      'body': 'build: $build\nversion: $version\n## Novidades\n$notes\n\n---\nInstalador beta para testadores.',
      'assets': [
        if (withApk) {'name': 'desperrengue.apk', 'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk', 'size': 64471667},
      ],
    });

void main() {
  group('UpdateService.parse', () {
    test('lê build, versão, tamanho, URL e novidades (só até o separador ---)', () {
      final i = UpdateService.parse(release())!;
      expect(i.build, 29712345);
      expect(i.version, '0.2.0');
      expect(i.apkUrl, endsWith('/beta-latest/desperrengue.apk'));
      expect(i.sizeLabel, '61 MB');
      expect(i.notes, 'corrige o login');
    });

    test('release sem "build:" ou sem APK é ignorado', () {
      expect(UpdateService.parse(jsonEncode({'body': 'sem build', 'assets': []})), isNull);
      expect(UpdateService.parse(release(withApk: false)), isNull);
      expect(UpdateService.parse('lixo'), isNull);
    });
  });

  group('UpdateService.check', () {
    UpdateService svc(http.Client c, {int installed = 100, bool enabled = true}) =>
        UpdateService(client: c, installedBuild: () async => installed, repo: 'x/y', enabled: enabled);

    test('versão mais nova => devolve a atualização', () async {
      final s = svc(MockClient((r) async {
        expect(r.url.path, '/repos/x/y/releases/tags/beta-latest');
        return http.Response(release(build: 101), 200, headers: {'etag': 'W/"a"'});
      }));
      expect((await s.check())?.build, 101);
    });

    test('mesma versão ou mais antiga => null', () async {
      expect(await svc(MockClient((_) async => http.Response(release(build: 100), 200)), installed: 100).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response(release(build: 50), 200)), installed: 100).check(), isNull);
    });

    test('usa ETag: a 2ª consulta manda If-None-Match e o 304 reaproveita o cache', () async {
      var calls = 0;
      String? sent;
      final s = svc(MockClient((r) async {
        calls++;
        sent = r.headers['If-None-Match'];
        return calls == 1 ? http.Response(release(build: 101), 200, headers: {'etag': 'W/"v1"'}) : http.Response('', 304);
      }));
      expect((await s.check())?.build, 101);
      expect(sent, isNull);
      expect((await s.check())?.build, 101, reason: '304 mantém a informação em cache');
      expect(sent, 'W/"v1"');
    });

    test('erro de rede, 404 e 500 nunca lançam (devolvem null)', () async {
      expect(await svc(MockClient((_) async => throw Exception('sem rede'))).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response('nf', 404))).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response('err', 500))).check(), isNull);
    });

    test('desativado (build da Play Store / debug) não faz nenhuma requisição', () async {
      var calls = 0;
      final s = svc(MockClient((_) async {
        calls++;
        return http.Response(release(build: 999), 200);
      }), enabled: false);
      expect(await s.check(), isNull);
      expect(calls, 0);
    });
  });

  group('UpdateGate (aviso na tela)', () {
    UpdateInfo info(int b) => UpdateInfo(build: b, version: '0.2.0', apkUrl: 'https://x/y.apk', sizeBytes: 64471667, notes: 'novidade');

    Future<void> pump(WidgetTester t, {required Future<UpdateInfo?> Function() check, Future<void> Function(String)? open, Brightness b = Brightness.light}) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, b),
        home: const SizedBox(),
        builder: (c, child) => UpdateGate(check: check, openUrl: open, initialDelay: const Duration(milliseconds: 50), interval: const Duration(minutes: 5), child: child!),
      ));
    }

    testWidgets('mostra o aviso quando há versão nova e esconde com "Depois"', (t) async {
      await pump(t, check: () async => info(5));
      expect(find.text('Nova versão'), findsNothing, reason: 'ainda não checou');
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      expect(find.text('Nova versão'), findsOneWidget);
      expect(find.text('Versão 0.2.0 · 61 MB'), findsOneWidget);
      await t.tap(find.text('Depois'));
      await t.pump();
      expect(find.text('Nova versão'), findsNothing);
      await t.pumpWidget(const SizedBox()); // desmonta e cancela os timers
    });

    testWidgets('"Atualizar" abre o APK e mostra as instruções de instalação', (t) async {
      String? opened;
      await pump(t, check: () async => info(5), open: (u) async => opened = u);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      await t.tap(find.text('Atualizar'));
      await t.pump();
      expect(opened, 'https://x/y.apk');
      expect(find.text('Baixando...'), findsOneWidget);
      expect(find.textContaining('toque na notificação'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sem versão nova não aparece nada (e funciona no tema escuro)', (t) async {
      await pump(t, check: () async => null, b: Brightness.dark);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      expect(find.text('Nova versão'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'Atualização Sem Dor de Cabeça (Zero-Browser): baixa em streaming, confere assinatura digital e abre instalador nativo',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        AppVersionAndUpdateService.updateAcknowledgedNotifier.value = false;

        final stepDownload = Completer<void>();
        final stepVerify = Completer<void>();

        final installer = PublicNativeOtaInstaller(
          isAndroidOverride: true,
          customRunner: (target, onProgress) async {
            onProgress(
              const PublicOtaProgress(
                phase: PublicOtaInstallPhase.downloading,
                receivedBytes: 31457280,
                totalBytes: 62914560,
                progress: 0.5,
              ),
            );
            await stepDownload.future;
            onProgress(
              const PublicOtaProgress(
                phase: PublicOtaInstallPhase.verifying,
                receivedBytes: 62914560,
                totalBytes: 62914560,
                progress: 1.0,
              ),
            );
            await stepVerify.future;
            onProgress(
              const PublicOtaProgress(
                phase: PublicOtaInstallPhase.installerLaunched,
                receivedBytes: 62914560,
                totalBytes: 62914560,
                progress: 1.0,
                verifiedSha256:
                    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            );
          },
        );
        addTearDown(installer.dispose);

        const releaseInfo = UpdateInfo(
          build: 888,
          version: '2.15.0',
          apkUrl:
              'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue.apk',
          sizeBytes: 62914560,
          sha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          notes: 'Experiência fluida e segura',
        );

        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(UserMode.client, Brightness.light),
            home: const Scaffold(body: Center(child: Text('Tela inicial'))),
            builder: (context, child) => UpdateGate(
              check: () async => releaseInfo,
              installer: installer,
              initialDelay: const Duration(milliseconds: 30),
              interval: const Duration(minutes: 5),
              child: child!,
            ),
          ),
        );

        await t.pump(const Duration(milliseconds: 60));
        await t.pump(const Duration(milliseconds: 220));

        expect(find.text('Nova versão'), findsOneWidget);
        expect(find.text('Versão 2.15.0 · 60 MB'), findsOneWidget);
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

        await t.tap(find.byKey(const ValueKey<String>('public-ota-install-btn')));
        await t.pump();

        expect(find.text('Baixando atualização…'), findsOneWidget);
        expect(find.text('50% · 30.0 / 60.0 MB'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('public-ota-progress-bar')),
          findsOneWidget,
        );

        stepDownload.complete();
        await t.pump();
        expect(find.text('Verificando assinatura digital…'), findsOneWidget);
        expect(
          find.textContaining('assinatura digital de segurança'),
          findsOneWidget,
        );

        stepVerify.complete();
        await t.pump();
        expect(
          find.text('Pronto! Toque em "Atualizar" no Android'),
          findsOneWidget,
        );
        expect(find.text('Abrir instalador'), findsOneWidget);
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX discreta em 2 níveis: pílula do cabeçalho recolhe enquanto aviso de entrada está aberto e aciona OTA direto após "Depois"',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        AppVersionAndUpdateService.updateAcknowledgedNotifier.value = false;

        final mockUpdateService = UpdateService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'tag_name': 'beta-latest',
                'body':
                    'build: 950\nversion: 2.16.0\n## Novidades\nBotão discreto\n---\n'
                    '- SHA-256 (`desperrengue.apk`): `0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`',
                'assets': [
                  {
                    'name': 'desperrengue.apk',
                    'browser_download_url':
                        'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue.apk',
                    'size': 62914560,
                  },
                ],
              }),
              200,
              headers: {'etag': 'W/"950"'},
            ),
          ),
          installedBuild: () async => 900,
          repo: 'WagnerxOliveira/DesperrengueApp_TAI3',
          enabled: true,
        );

        var directInstallTriggered = false;
        final installer = PublicNativeOtaInstaller(
          isAndroidOverride: true,
          customRunner: (target, onProgress) async {
            directInstallTriggered = true;
            onProgress(
              const PublicOtaProgress(
                phase: PublicOtaInstallPhase.installerLaunched,
                receivedBytes: 62914560,
                totalBytes: 62914560,
                progress: 1.0,
              ),
            );
          },
        );
        addTearDown(installer.dispose);

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.resolve(UserMode.client, Brightness.light),
              home: Scaffold(
                body: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(child: Text('Desperrengue')),
                        AppQuickUpdateButton(
                          compact: true,
                          updateService: mockUpdateService,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppQuickUpdateButton(
                      compact: false,
                      updateService: mockUpdateService,
                    ),
                  ],
                ),
              ),
              builder: (context, child) => UpdateGate(
                service: mockUpdateService,
                installer: installer,
                initialDelay: const Duration(milliseconds: 30),
                interval: const Duration(minutes: 5),
                child: child!,
              ),
            ),
          ),
        );

        await t.pump(const Duration(milliseconds: 60));
        await t.pump(const Duration(milliseconds: 220));

        // Com o aviso flutuante de entrada aberto, a pílula compacta do topo se recolhe
        // para nunca poluir ou duplicar botões na mesma faixa visual:
        expect(
          find.byKey(const ValueKey<String>('public-floating-ota-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('public-discreet-update-pill')),
          findsNothing,
        );

        // O usuário toca em "Depois": o aviso flutuante some e a pílula discreta aparece no topo!
        await t.tap(find.byKey(const ValueKey<String>('public-ota-later-btn')));
        await t.pump();
        expect(
          find.byKey(const ValueKey<String>('public-floating-ota-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('public-discreet-update-pill')),
          findsOneWidget,
        );

        // Ao tocar na pílula discreta "Atualizar", inicia imediatamente o instalador direto in-app!
        await t.tap(
          find.byKey(const ValueKey<String>('public-discreet-update-pill')),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 220));

        expect(directInstallTriggered, isTrue);
        expect(
          find.text('Pronto! Toque em "Atualizar" no Android'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Matriz de tortura 320x640 @ 1.4x (Claro/Escuro, Cliente/Profissional) em todas as fases OTA sem overflow',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        AppVersionAndUpdateService.updateAcknowledgedNotifier.value = false;

        final installer = PublicNativeOtaInstaller(
          isAndroidOverride: true,
          customRunner: (_, _) async {},
        );
        addTearDown(installer.dispose);

        const releaseInfo = UpdateInfo(
          build: 999,
          version: '2.17.0',
          apkUrl:
              'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue.apk',
          sizeBytes: 64471667,
          sha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          notes:
              'Melhorias de performance, segurança criptográfica e experiência discreta',
        );

        await t.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => t.binding.setSurfaceSize(null));

        for (final mode in <UserMode>[UserMode.client, UserMode.provider]) {
          for (final brightness in <Brightness>[
            Brightness.light,
            Brightness.dark,
          ]) {
            installer.reset();
            await t.pumpWidget(
              ProviderScope(
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 640),
                    textScaler: TextScaler.linear(1.4),
                  ),
                  child: MaterialApp(
                    theme: AppTheme.resolve(mode, brightness),
                    home: const Scaffold(
                      body: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16, 180, 16, 24),
                        child: Column(
                          children: <Widget>[
                            AppQuickUpdateButton(
                              compact: true,
                              reloadWebOnTap: false,
                            ),
                            SizedBox(height: 12),
                            AppQuickUpdateButton(
                              compact: false,
                              reloadWebOnTap: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    builder: (context, child) => UpdateGate(
                      check: () async => releaseInfo,
                      installer: installer,
                      initialDelay: const Duration(milliseconds: 10),
                      interval: const Duration(minutes: 5),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(1.4),
                        ),
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            );

            await t.pump(const Duration(milliseconds: 30));
            await t.pump(const Duration(milliseconds: 220));
            expect(t.takeException(), isNull);

            for (final state in const <PublicOtaProgress>[
              PublicOtaProgress(
                phase: PublicOtaInstallPhase.downloading,
                receivedBytes: 31457280,
                totalBytes: 64471667,
                progress: 0.49,
              ),
              PublicOtaProgress(
                phase: PublicOtaInstallPhase.verifying,
                receivedBytes: 64471667,
                totalBytes: 64471667,
                progress: 1.0,
              ),
              PublicOtaProgress(
                phase: PublicOtaInstallPhase.awaitingPermission,
                receivedBytes: 64471667,
                totalBytes: 64471667,
                progress: 1.0,
              ),
              PublicOtaProgress(
                phase: PublicOtaInstallPhase.installerLaunched,
                receivedBytes: 64471667,
                totalBytes: 64471667,
                progress: 1.0,
              ),
              PublicOtaProgress(
                phase: PublicOtaInstallPhase.error,
                errorMessage:
                    'Assinatura de segurança inválida ou arquivo incompleto. Instalação bloqueada para sua proteção.',
              ),
            ]) {
              installer.progressNotifier.value = state;
              await t.pump();
              expect(
                t.takeException(),
                isNull,
                reason: 'Zero overflow em $mode / $brightness / ${state.phase}',
              );
            }
          }
        }

        await t.pumpWidget(const SizedBox());
      },
    );
  });
}

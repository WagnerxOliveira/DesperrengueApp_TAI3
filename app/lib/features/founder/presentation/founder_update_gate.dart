import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/env.dart';
import '../../../core/services/update_service.dart';
import 'founder_animations_and_shaders.dart';

/// Informações criptográficas e de release do binário exclusivo `desperrengue-founder-ceo.apk`.
@immutable
class FounderUpdateInfo {
  const FounderUpdateInfo({
    required this.version,
    required this.build,
    required this.currentBuild,
    required this.apkUrl,
    this.sizeBytes,
    this.sha256,
    this.notes,
    this.headlineNotes = '',
  });

  final String version;
  final int build;
  final int currentBuild;
  final String apkUrl;
  final int? sizeBytes;
  final String? sha256;
  final String? notes;
  final String headlineNotes;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return mb >= 10 ? '${mb.toStringAsFixed(0)} MB' : '${mb.toStringAsFixed(1)} MB';
  }
}

/// Fases do instalador direto in-app do `Desperrengue CEO` (Zero-Browser).
enum FounderOtaInstallPhase {
  idle,
  downloading,
  verifying,
  awaitingPermission,
  installerLaunched,
  browserFallbackLaunched,
  error,
}

/// Telemetria reativa de download e verificação SHA-256 in-app.
@immutable
class FounderOtaProgress {
  const FounderOtaProgress({
    this.phase = FounderOtaInstallPhase.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.verifiedSha256,
    this.errorMessage,
  });

  static const FounderOtaProgress idle = FounderOtaProgress();

  final FounderOtaInstallPhase phase;
  final int receivedBytes;
  final int totalBytes;
  final double progress;
  final String? verifiedSha256;
  final String? errorMessage;

  bool get isBusy =>
      phase == FounderOtaInstallPhase.downloading ||
      phase == FounderOtaInstallPhase.verifying;

  String get transferLabel {
    if (receivedBytes <= 0) return '';
    final recvMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes > 0) {
      final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      final pct = (progress * 100).clamp(0, 100).round();
      return '$pct% · $recvMb / $totalMb MB';
    }
    return '$recvMb MB recebidos';
  }
}

typedef FounderOtaInstallRunner = Future<void> Function(
  FounderUpdateInfo info,
  ValueChanged<FounderOtaProgress> onProgress,
);

/// Ponte nativa Android (`br.com.desperrengue.app.founder/ota`) que baixa o
/// `desperrengue-founder-ceo.apk` em streaming direto para o cache privado do app,
/// valida o digest `SHA-256` contra o release `beta-latest` e abre imediatamente a
/// folha nativa do sistema Android ("Atualizar Desperrengue CEO?") sem passar por navegador.
class FounderNativeOtaInstaller {
  FounderNativeOtaInstaller({
    MethodChannel? channel,
    this.customRunner,
    bool? isAndroidOverride,
  })  : _channel = channel ?? _defaultChannel,
        _isAndroid = isAndroidOverride ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (customRunner == null && _isAndroid) {
      _attachChannelCallbacks();
    }
  }

  static const MethodChannel _defaultChannel = MethodChannel(
    'br.com.desperrengue.app.founder/ota',
  );

  final MethodChannel _channel;
  final FounderOtaInstallRunner? customRunner;
  final bool _isAndroid;

  final ValueNotifier<FounderOtaProgress> progressNotifier =
      ValueNotifier<FounderOtaProgress>(FounderOtaProgress.idle);

  void _attachChannelCallbacks() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onOtaProgress') return;
      final args = call.arguments;
      if (args is! Map) return;
      final phaseRaw = '${args['phase'] ?? ''}';
      final recv = (args['receivedBytes'] as num?)?.toInt() ?? 0;
      final total = (args['totalBytes'] as num?)?.toInt() ?? 0;
      final prog = (args['progress'] as num?)?.toDouble() ?? 0.0;
      final sha = args['sha256']?.toString();
      final errCode = args['errorCode']?.toString();

      final mappedPhase = switch (phaseRaw) {
        'downloading' => FounderOtaInstallPhase.downloading,
        'verifying' => FounderOtaInstallPhase.verifying,
        'permission_required' => FounderOtaInstallPhase.awaitingPermission,
        'installer_launched' => FounderOtaInstallPhase.installerLaunched,
        'error' => FounderOtaInstallPhase.error,
        _ => FounderOtaInstallPhase.idle,
      };

      progressNotifier.value = FounderOtaProgress(
        phase: mappedPhase,
        receivedBytes: recv,
        totalBytes: total,
        progress: prog.clamp(0.0, 1.0),
        verifiedSha256: sha,
        errorMessage: mappedPhase == FounderOtaInstallPhase.error
            ? _humanizeErrorCode(errCode)
            : null,
      );
    });
  }

  static String _humanizeErrorCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Falha ao baixar a atualização direta. Toque para tentar novamente.';
    }
    if (code.contains('SHA256_MISMATCH')) {
      return 'Pacote inválido ou corrompido. Instalação bloqueada por segurança.';
    }
    if (code.contains('UNTRUSTED')) {
      return 'Origem de atualização bloqueada por segurança.';
    }
    return 'Oscilação de rede ao baixar o pacote ($code). Toque para repetir.';
  }

  Future<void> downloadAndInstall(FounderUpdateInfo info) async {
    if (!UpdateService.isTrustedDownloadUrl(info.apkUrl) ||
        !info.apkUrl
            .toLowerCase()
            .endsWith('/${FounderUpdateService.founderApkAssetName}')) {
      progressNotifier.value = const FounderOtaProgress(
        phase: FounderOtaInstallPhase.error,
        errorMessage: 'URL de atualização inválida ou não confiável.',
      );
      return;
    }

    final runner = customRunner;
    if (runner != null) {
      await runner(info, (next) => progressNotifier.value = next);
      return;
    }

    if (!_isAndroid) {
      final ok = await FounderUpdateService.launchTrustedFounderApkDownload(
        info.apkUrl,
      );
      progressNotifier.value = FounderOtaProgress(
        phase: ok
            ? FounderOtaInstallPhase.browserFallbackLaunched
            : FounderOtaInstallPhase.error,
        progress: ok ? 1.0 : 0.0,
        errorMessage: ok ? null : 'Não foi possível iniciar a atualização.',
      );
      return;
    }

    progressNotifier.value = FounderOtaProgress(
      phase: FounderOtaInstallPhase.downloading,
      receivedBytes: 0,
      totalBytes: info.sizeBytes ?? 0,
      progress: 0.0,
    );

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'downloadAndInstallApk',
        <String, dynamic>{
          'apkUrl': info.apkUrl,
          'expectedSha256': info.sha256,
        },
      );
      final status = '${res?['status'] ?? ''}';
      final bytes = (res?['bytes'] as num?)?.toInt() ?? (info.sizeBytes ?? 0);
      final sha = res?['sha256']?.toString() ?? info.sha256;
      if (status == 'permission_required') {
        progressNotifier.value = FounderOtaProgress(
          phase: FounderOtaInstallPhase.awaitingPermission,
          receivedBytes: bytes,
          totalBytes: bytes,
          progress: 1.0,
          verifiedSha256: sha,
        );
      } else if (status == 'installer_launched') {
        progressNotifier.value = FounderOtaProgress(
          phase: FounderOtaInstallPhase.installerLaunched,
          receivedBytes: bytes,
          totalBytes: bytes,
          progress: 1.0,
          verifiedSha256: sha,
        );
      }
    } on MissingPluginException {
      final ok = await FounderUpdateService.launchTrustedFounderApkDownload(
        info.apkUrl,
      );
      progressNotifier.value = FounderOtaProgress(
        phase: ok
            ? FounderOtaInstallPhase.browserFallbackLaunched
            : FounderOtaInstallPhase.error,
        progress: ok ? 1.0 : 0.0,
        errorMessage: ok ? null : 'Canal nativo indisponível neste dispositivo.',
      );
    } on PlatformException catch (e) {
      progressNotifier.value = FounderOtaProgress(
        phase: FounderOtaInstallPhase.error,
        errorMessage: _humanizeErrorCode(e.code),
      );
    } catch (_) {
      progressNotifier.value = const FounderOtaProgress(
        phase: FounderOtaInstallPhase.error,
        errorMessage:
            'Não foi possível concluir o download direto. Toque para repetir.',
      );
    }
  }

  Future<void> triggerPendingInstall() async {
    if (!_isAndroid) return;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'triggerPendingInstall',
      );
      final status = '${res?['status'] ?? ''}';
      if (status == 'installer_launched') {
        final cur = progressNotifier.value;
        progressNotifier.value = FounderOtaProgress(
          phase: FounderOtaInstallPhase.installerLaunched,
          receivedBytes: cur.receivedBytes,
          totalBytes: cur.totalBytes,
          progress: 1.0,
          verifiedSha256: cur.verifiedSha256,
        );
      }
    } catch (_) {}
  }

  void reset() {
    progressNotifier.value = FounderOtaProgress.idle;
  }

  void dispose() {
    if (customRunner == null && _isAndroid) {
      _channel.setMethodCallHandler(null);
    }
    progressNotifier.dispose();
  }
}

/// Serviço OTA dedicado exclusivamente ao `Desperrengue CEO` (`desperrengue-founder-ceo.apk`).
///
/// Sempre ativo por padrão no Android (`!kIsWeb`), pois o binário soberano do CEO
/// nunca é distribuído pela Play Store: as atualizações chegam diretamente ao celular
/// via canal `beta-latest` com validação ETag (`304 Not Modified` sem gasto de cota)
/// e verificação criptográfica `SHA-256`.
class FounderUpdateService {
  FounderUpdateService({
    http.Client? client,
    Future<int> Function()? buildNumber,
    bool? enabled,
    String? repo,
  })  : _client = client ?? http.Client(),
        _buildNumber = buildNumber ?? _installedBuild,
        _enabled = enabled ?? !kIsWeb,
        _repo = repo ?? Env.updateRepo;

  final http.Client _client;
  final Future<int> Function() _buildNumber;
  final bool _enabled;
  final String _repo;

  static const String founderApkAssetName = 'desperrengue-founder-ceo.apk';
  static const String _etagPrefKey = 'founder_ceo_update_etag_v2';
  static const String _cachedBodyPrefKey = 'founder_ceo_update_body_v2';
  static const String acknowledgedBuildPrefKey =
      'founder_ceo_acknowledged_build_v1';

  String? _memoryEtag;
  String? _memoryBody;

  static String get directFounderApkFallbackUrl =>
      'https://github.com/${Env.updateRepo}/releases/download/${UpdateService.releaseTag}/$founderApkAssetName';

  static Future<int> _installedBuild() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Verifica se há um `desperrengue-founder-ceo.apk` mais novo publicado em `beta-latest`.
  Future<FounderUpdateInfo?> check({bool forceManualCheck = false}) async {
    if (kIsWeb) return null;
    if (!forceManualCheck && (!_enabled || _repo.isEmpty)) return null;
    if (_repo.isEmpty) return null;

    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };
      final etag = _memoryEtag ?? prefs?.getString(_etagPrefKey);
      if (!forceManualCheck && etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }

      final uri = Uri.https(
        'api.github.com',
        '/repos/$_repo/releases/tags/${UpdateService.releaseTag}',
      );
      final resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      String? rawBody;
      if (resp.statusCode == 200) {
        rawBody = resp.body;
        _memoryBody = rawBody;
        final newEtag = resp.headers['etag'];
        if (newEtag != null && newEtag.isNotEmpty) {
          _memoryEtag = newEtag;
          await prefs?.setString(_etagPrefKey, newEtag);
          await prefs?.setString(_cachedBodyPrefKey, rawBody);
        }
      } else if (resp.statusCode == 304) {
        rawBody = _memoryBody ?? prefs?.getString(_cachedBodyPrefKey);
      }

      if (rawBody == null || rawBody.isEmpty) return null;
      final current = await _buildNumber();
      return parseFounderRelease(rawBody, currentBuild: current, repo: _repo);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static FounderUpdateInfo? parseFounderRelease(
    String rawJson, {
    required int currentBuild,
    String repo = '',
  }) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      final body = (decoded['body'] as String?) ?? '';

      int? remoteBuild;
      String remoteVersion = '';

      final lineBuildMatch =
          RegExp(r'^build:\s*(\d+)', multiLine: true).firstMatch(body);
      if (lineBuildMatch != null) {
        remoteBuild = int.tryParse(lineBuildMatch.group(1)!);
        remoteVersion = RegExp(r'^version:\s*([\w.\-+]+)', multiLine: true)
                .firstMatch(body)
                ?.group(1) ??
            '';
      } else {
        final commentMatch = RegExp(
          r'<!--\s*build:(\d+)\s+version:([^\s>]+)\s*-->',
        ).firstMatch(body);
        if (commentMatch != null) {
          remoteBuild = int.tryParse(commentMatch.group(1)!);
          remoteVersion = commentMatch.group(2)!;
        }
      }

      if (remoteBuild == null || remoteBuild <= currentBuild) return null;

      final assets =
          (decoded['assets'] as List<dynamic>?) ?? const <dynamic>[];
      String? founderApkUrl;
      int? founderSizeBytes;
      String? assetDigestSha256;

      for (final item in assets) {
        if (item is Map<String, dynamic>) {
          final assetName = (item['name'] as String?)?.trim() ?? '';
          final downloadUrl =
              (item['browser_download_url'] as String?)?.trim() ?? '';
          if (assetName == founderApkAssetName && downloadUrl.isNotEmpty) {
            founderApkUrl = downloadUrl;
            founderSizeBytes = (item['size'] as num?)?.toInt();
            final digestRaw = (item['digest'] as String?)?.trim() ?? '';
            if (digestRaw.toLowerCase().startsWith('sha256:') &&
                digestRaw.length == 71) {
              assetDigestSha256 = digestRaw.substring(7).toLowerCase();
            }
            break;
          }
        }
      }

      if (founderApkUrl == null ||
          !UpdateService.isTrustedDownloadUrl(founderApkUrl) ||
          !founderApkUrl.toLowerCase().endsWith('/$founderApkAssetName')) {
        return null;
      }
      if (repo.isNotEmpty &&
          !founderApkUrl.toLowerCase().contains(repo.toLowerCase())) {
        return null;
      }

      final notesShaMatch = RegExp(
        r'SHA-256\s*\(`?desperrengue-founder-ceo\.apk`?\)\s*:\s*`?([0-9a-fA-F]{64})`?',
        caseSensitive: false,
      ).firstMatch(body);
      final sha256Hex =
          notesShaMatch?.group(1)?.toLowerCase() ?? assetDigestSha256;

      final headline = RegExp(
            r'## Novidades\s*\n([\s\S]*?)(?:\n---|$)',
          ).firstMatch(body)?.group(1)?.trim() ??
          '';

      final cleanNotes = body
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
          .trim();

      return FounderUpdateInfo(
        version: remoteVersion.isEmpty ? '$remoteBuild' : remoteVersion,
        build: remoteBuild,
        currentBuild: currentBuild,
        apkUrl: founderApkUrl,
        sizeBytes: founderSizeBytes,
        sha256: sha256Hex,
        notes: cleanNotes.isEmpty ? null : cleanNotes,
        headlineNotes: headline,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> launchTrustedFounderApkDownload(
    String apkUrl, {
    String? repo,
  }) async {
    final effectiveRepo = repo ?? Env.updateRepo;
    if (!UpdateService.isTrustedDownloadUrl(apkUrl) ||
        !apkUrl.toLowerCase().endsWith('/$founderApkAssetName')) {
      return false;
    }
    if (effectiveRepo.isNotEmpty &&
        !apkUrl.toLowerCase().contains(effectiveRepo.toLowerCase())) {
      return false;
    }
    return launchUrl(
      Uri.parse(apkUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Controlador exposto pelo [FounderUpdateGate] para permitir que o painel
/// executivo (Aba 4 `Cofre`) dispare o mesmo fluxo de atualização direta in-app.
abstract interface class FounderUpdateGateController {
  Future<FounderUpdateInfo?> checkNowAndPrompt({bool autoStartInstall = false});
}

class _FounderUpdateScope extends InheritedWidget {
  const _FounderUpdateScope({
    required this.controller,
    required super.child,
  });

  final FounderUpdateGateController controller;

  @override
  bool updateShouldNotify(_FounderUpdateScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Portão global flutuante de atualização automática direta no celular para o
/// `Desperrengue CEO` (montado em `MaterialApp.builder` de `main_founder.dart`,
/// exatamente como `UpdateGate` no app público — porém com download em streaming
/// dentro do próprio app, validação `SHA-256` e abertura direta do instalador
/// nativo do Android sem navegador).
///
/// Frequência automática:
/// - `4 s` após abrir o app (funciona inclusive antes de digitar o PIN);
/// - A cada `60 s` enquanto o app estiver aberto (via `ETag` / `304`);
/// - Toda vez que o app volta ao primeiro plano (`AppLifecycleState.resumed`, mín. `15 s`).
class FounderUpdateGate extends StatefulWidget {
  const FounderUpdateGate({
    super.key,
    required this.child,
    this.service,
    this.installer,
    this.initialDelay = const Duration(seconds: 4),
    this.interval = const Duration(seconds: 60),
  });

  final Widget child;
  final FounderUpdateService? service;
  final FounderNativeOtaInstaller? installer;
  final Duration initialDelay;
  final Duration interval;

  static FounderUpdateGateController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FounderUpdateScope>()
        ?.controller;
  }

  @override
  State<FounderUpdateGate> createState() => _FounderUpdateGateState();
}

class _FounderUpdateGateState extends State<FounderUpdateGate>
    with WidgetsBindingObserver
    implements FounderUpdateGateController {
  late final FounderUpdateService _service =
      widget.service ?? FounderUpdateService();
  late final FounderNativeOtaInstaller _installer =
      widget.installer ?? FounderNativeOtaInstaller();
  late final bool _ownsInstaller = widget.installer == null;

  Timer? _firstTimer;
  Timer? _periodicTimer;
  DateTime _lastCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _checking = false;

  FounderUpdateInfo? _pendingUpdate;
  int? _dismissedBuild;
  bool _manualOverrideVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPersistedDismissedBuild());
    _firstTimer = Timer(widget.initialDelay, _runBackgroundCheck);
    _periodicTimer =
        Timer.periodic(widget.interval, (_) => _runBackgroundCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstTimer?.cancel();
    _periodicTimer?.cancel();
    if (_ownsInstaller) {
      _installer.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_lastCheckAt) >
            const Duration(seconds: 15)) {
      unawaited(_runBackgroundCheck());
    }
  }

  Future<void> _loadPersistedDismissedBuild() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getInt(FounderUpdateService.acknowledgedBuildPrefKey);
      if (saved != null && mounted) {
        setState(() => _dismissedBuild = saved);
      }
    } catch (_) {}
  }

  Future<void> _persistDismissedBuild(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(FounderUpdateService.acknowledgedBuildPrefKey, build);
    } catch (_) {}
  }

  Future<void> _runBackgroundCheck() async {
    if (_checking || !mounted) return;
    _checking = true;
    _lastCheckAt = DateTime.now();
    try {
      final info = await _service.check();
      if (!mounted || info == null) return;
      if (_pendingUpdate?.build != info.build) {
        _installer.reset();
        setState(() {
          _pendingUpdate = info;
        });
      }
    } catch (_) {
      // Silencioso em background: nunca interrompe o uso do cockpit.
    } finally {
      _checking = false;
    }
  }

  @override
  Future<FounderUpdateInfo?> checkNowAndPrompt({
    bool autoStartInstall = false,
  }) async {
    _lastCheckAt = DateTime.now();
    final info = await _service.check(forceManualCheck: true);
    if (!mounted) return info;
    if (info != null) {
      if (_pendingUpdate?.build != info.build) {
        _installer.reset();
      }
      setState(() {
        _pendingUpdate = info;
        _manualOverrideVisible = true;
      });
      if (autoStartInstall) {
        unawaited(_startDirectInstall(info));
      }
    }
    return info;
  }

  Future<void> _startDirectInstall(FounderUpdateInfo info) async {
    HapticFeedback.mediumImpact();
    await _installer.downloadAndInstall(info);
  }

  void _dismissForThisBuild(FounderUpdateInfo info) {
    unawaited(_persistDismissedBuild(info.build));
    if (!_installer.progressNotifier.value.isBusy) {
      _installer.reset();
    }
    setState(() {
      _dismissedBuild = info.build;
      _manualOverrideVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _pendingUpdate;
    final showCard = info != null &&
        (_manualOverrideVisible ||
            _dismissedBuild == null ||
            info.build > _dismissedBuild!);
    final mediaPadding = MediaQuery.paddingOf(context);
    final safeTop = FounderSovereignTokens.safeTopInset(context) + 8.0;
    final safeLeft = math.max(12.0, mediaPadding.left + 12.0);
    final safeRight = math.max(12.0, mediaPadding.right + 12.0);

    return _FounderUpdateScope(
      controller: this,
      child: Stack(
        children: <Widget>[
          widget.child,
          if (showCard)
            Positioned(
              top: safeTop,
              left: safeLeft,
              right: safeRight,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ValueListenableBuilder<FounderOtaProgress>(
                    valueListenable: _installer.progressNotifier,
                    builder: (context, otaState, _) {
                      return _FounderFloatingUpdateCard(
                        info: info,
                        otaState: otaState,
                        onDismiss: () => _dismissForThisBuild(info),
                        onInstallNow: () => _startDirectInstall(info),
                        onTriggerPendingInstall:
                            _installer.triggerPendingInstall,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FounderFloatingUpdateCard extends StatelessWidget {
  const _FounderFloatingUpdateCard({
    required this.info,
    required this.otaState,
    required this.onDismiss,
    required this.onInstallNow,
    required this.onTriggerPendingInstall,
  });

  final FounderUpdateInfo info;
  final FounderOtaProgress otaState;
  final VoidCallback onDismiss;
  final VoidCallback onInstallNow;
  final VoidCallback onTriggerPendingInstall;

  @override
  Widget build(BuildContext context) {
    final phase = otaState.phase;
    final busy = otaState.isBusy;

    final title = switch (phase) {
      FounderOtaInstallPhase.downloading => 'Baixando atualização no celular…',
      FounderOtaInstallPhase.verifying => 'Conferindo segurança da atualização…',
      FounderOtaInstallPhase.awaitingPermission =>
        'Autorize a instalação direta (1 única vez)',
      FounderOtaInstallPhase.installerLaunched =>
        'Pronto! Toque em "Atualizar" no Android',
      FounderOtaInstallPhase.browserFallbackLaunched =>
        'Download iniciado — abra o pacote ao concluir',
      FounderOtaInstallPhase.error => 'Falha ao atualizar automaticamente',
      FounderOtaInstallPhase.idle => 'Nova versão · Desperrengue CEO',
    };

    final metaParts = <String>[
      'Versão ${info.version}',
      if (info.sizeLabel.isNotEmpty) info.sizeLabel,
      if (info.sha256 != null) 'Download seguro',
    ];

    final subtitle = switch (phase) {
      FounderOtaInstallPhase.downloading => otaState.transferLabel.isNotEmpty
          ? otaState.transferLabel
          : 'Transferindo pacote oficial diretamente para o seu celular…',
      FounderOtaInstallPhase.verifying =>
        'Validando o pacote oficial antes de abrir o instalador do Android…',
      FounderOtaInstallPhase.awaitingPermission =>
        'Ative "Permitir desta fonte" para o Desperrengue CEO e volte: o instalador abrirá sozinho.',
      FounderOtaInstallPhase.installerLaunched =>
        'Pacote validado no aparelho. Confirme em "Atualizar" na janela nativa do Android.',
      FounderOtaInstallPhase.browserFallbackLaunched =>
        'Ao concluir, confirme em "Atualizar" na janela do sistema.',
      FounderOtaInstallPhase.error =>
        otaState.errorMessage ?? 'Toque em "Tentar novamente" para repetir.',
      FounderOtaInstallPhase.idle => metaParts.join(' · '),
    };

    final dismissLabel = busy
        ? 'Ocultar'
        : (phase == FounderOtaInstallPhase.installerLaunched ||
                phase == FounderOtaInstallPhase.browserFallbackLaunched
            ? 'Fechar'
            : 'Depois');

    return Semantics(
      liveRegion: true,
      label: 'Nova atualização direta do Desperrengue CEO disponível',
      child: Material(
        key: const ValueKey<String>('founder-floating-ota-card'),
        color: const Color(0xFF111622),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF17130A),
                Color(0xFF0E131D),
              ],
            ),
            border: Border.all(
              color: phase == FounderOtaInstallPhase.error
                  ? FounderSovereignTokens.crimsonAlert.withValues(alpha: 0.75)
                  : FounderSovereignTokens.imperialGold.withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FounderPrecisionBadge(
                    phase == FounderOtaInstallPhase.installerLaunched
                        ? FounderIconGlyph.shieldVerified
                        : FounderIconGlyph.otaDirectUpdate,
                    boxSize: 36,
                    iconSize: 18,
                    tintColor: phase == FounderOtaInstallPhase.error
                        ? FounderSovereignTokens.crimsonAlert
                        : phase == FounderOtaInstallPhase.installerLaunched
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.imperialGoldBright,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 12,
                            height: 1.28,
                          ),
                        ),
                        if (phase == FounderOtaInstallPhase.idle &&
                            info.headlineNotes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              info.headlineNotes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FounderSovereignTokens.primaryInk,
                                fontSize: 11.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (busy) ...<Widget>[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const ValueKey<String>('founder-ota-progress-bar'),
                    value: phase == FounderOtaInstallPhase.verifying ||
                            otaState.totalBytes <= 0
                        ? null
                        : otaState.progress,
                    minHeight: 6,
                    backgroundColor: FounderSovereignTokens.obsidianSurface,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    TextButton(
                      key: const ValueKey<String>('founder-ota-later-btn'),
                      style: TextButton.styleFrom(
                        foregroundColor: FounderSovereignTokens.mutedInk,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: onDismiss,
                      child: Text(
                        dismissLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (phase == FounderOtaInstallPhase.idle ||
                        phase == FounderOtaInstallPhase.error)
                      FilledButton.icon(
                        key: const ValueKey<String>('founder-ota-install-btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: FounderSovereignTokens.imperialGold,
                          foregroundColor: const Color(0xFF111827),
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                        ),
                        onPressed: onInstallNow,
                        icon: const FounderPrecisionIcon(
                          FounderIconGlyph.otaDirectUpdate,
                          size: 16,
                          color: Color(0xFF111827),
                          accentColor: Color(0xFF111827),
                          duotoneAlpha: 0.14,
                        ),
                        label: Text(
                          phase == FounderOtaInstallPhase.error
                              ? 'Tentar novamente'
                              : 'Atualizar',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (phase == FounderOtaInstallPhase.awaitingPermission ||
                        phase == FounderOtaInstallPhase.installerLaunched)
                      FilledButton(
                        key: const ValueKey<String>(
                          'founder-ota-reopen-installer-btn',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: FounderSovereignTokens.imperialGold,
                          foregroundColor: const Color(0xFF111827),
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: onTriggerPendingInstall,
                        child: const Text(
                          'Abrir Instalador',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

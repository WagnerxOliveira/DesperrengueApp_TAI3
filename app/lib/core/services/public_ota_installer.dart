import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

/// Fases do instalador direto dentro do aplicativo `Desperrengue` (Zero-Browser).
enum PublicOtaInstallPhase {
  idle,
  downloading,
  verifying,
  awaitingPermission,
  installerLaunched,
  browserFallbackLaunched,
  error,
}

/// Estado reativo de progresso de download, verificação de integridade (`SHA-256` +
/// assinatura digital X.509) e abertura automática do instalador nativo Android.
@immutable
class PublicOtaProgress {
  const PublicOtaProgress({
    this.phase = PublicOtaInstallPhase.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.verifiedSha256,
    this.errorMessage,
  });

  static const PublicOtaProgress idle = PublicOtaProgress();

  final PublicOtaInstallPhase phase;
  final int receivedBytes;
  final int totalBytes;
  final double progress;
  final String? verifiedSha256;
  final String? errorMessage;

  bool get isBusy =>
      phase == PublicOtaInstallPhase.downloading ||
      phase == PublicOtaInstallPhase.verifying;

  int get percentInt => (progress * 100).clamp(0, 100).round();

  String get transferLabel {
    if (receivedBytes <= 0) return '';
    final recvMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes > 0) {
      final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$percentInt% · $recvMb / $totalMb MB';
    }
    return '$recvMb MB transferidos';
  }
}

typedef PublicOtaInstallRunner = Future<void> Function(
  UpdateInfo info,
  ValueChanged<PublicOtaProgress> onProgress,
);

/// Ponte nativa Android (`br.com.desperrengue.app/ota`) que baixa `desperrengue.apk`
/// diretamente dentro do aplicativo, confere o hash `SHA-256` e a assinatura digital
/// de segurança do pacote, e abre automaticamente a janela nativa do Android
/// ("Atualizar Desperrengue?") sem abrir navegador nem exigir busca em pastas.
class PublicNativeOtaInstaller {
  PublicNativeOtaInstaller({
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
    'br.com.desperrengue.app/ota',
  );

  final MethodChannel _channel;
  final PublicOtaInstallRunner? customRunner;
  final bool _isAndroid;

  final ValueNotifier<PublicOtaProgress> progressNotifier =
      ValueNotifier<PublicOtaProgress>(PublicOtaProgress.idle);

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
        'downloading' => PublicOtaInstallPhase.downloading,
        'verifying' => PublicOtaInstallPhase.verifying,
        'permission_required' => PublicOtaInstallPhase.awaitingPermission,
        'installer_launched' => PublicOtaInstallPhase.installerLaunched,
        'error' => PublicOtaInstallPhase.error,
        _ => PublicOtaInstallPhase.idle,
      };

      progressNotifier.value = PublicOtaProgress(
        phase: mappedPhase,
        receivedBytes: recv,
        totalBytes: total,
        progress: prog.clamp(0.0, 1.0),
        verifiedSha256: sha,
        errorMessage: mappedPhase == PublicOtaInstallPhase.error
            ? humanizeErrorCode(errCode)
            : null,
      );
    });
  }

  static String humanizeErrorCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Não foi possível concluir o download agora. Toque para tentar novamente.';
    }
    final upper = code.toUpperCase();
    if (upper.contains('SHA256_MISMATCH') ||
        upper.contains('SIGNATURE_MISMATCH') ||
        upper.contains('PACKAGE_MISMATCH') ||
        upper.contains('INVALID_APK')) {
      return 'Assinatura de segurança inválida ou arquivo incompleto. Instalação bloqueada para sua proteção.';
    }
    if (upper.contains('UNTRUSTED')) {
      return 'Origem de atualização não autorizada. Instalação bloqueada por segurança.';
    }
    if (upper.contains('ALREADY_RUNNING')) {
      return 'A atualização já está sendo baixada neste instante.';
    }
    return 'Oscilação de conexão ao baixar a atualização. Toque para tentar novamente.';
  }

  static bool isValidPublicApkUrl(String url) {
    final lower = url.trim().toLowerCase();
    return UpdateService.isTrustedDownloadUrl(url) &&
        !lower.contains('founder') &&
        lower.endsWith('.apk');
  }

  Future<void> downloadAndInstall(UpdateInfo info) async {
    if (!isValidPublicApkUrl(info.apkUrl)) {
      progressNotifier.value = const PublicOtaProgress(
        phase: PublicOtaInstallPhase.error,
        errorMessage: 'Endereço de atualização inválido ou não autorizado.',
      );
      return;
    }

    final runner = customRunner;
    if (runner != null) {
      await runner(info, (next) => progressNotifier.value = next);
      return;
    }

    if (!_isAndroid) {
      final ok = await _launchTrustedBrowserFallback(info.apkUrl);
      progressNotifier.value = PublicOtaProgress(
        phase: ok
            ? PublicOtaInstallPhase.browserFallbackLaunched
            : PublicOtaInstallPhase.error,
        progress: ok ? 1.0 : 0.0,
        errorMessage: ok ? null : 'Não foi possível iniciar a atualização.',
      );
      return;
    }

    progressNotifier.value = PublicOtaProgress(
      phase: PublicOtaInstallPhase.downloading,
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
        progressNotifier.value = PublicOtaProgress(
          phase: PublicOtaInstallPhase.awaitingPermission,
          receivedBytes: bytes,
          totalBytes: bytes,
          progress: 1.0,
          verifiedSha256: sha,
        );
      } else if (status == 'installer_launched') {
        progressNotifier.value = PublicOtaProgress(
          phase: PublicOtaInstallPhase.installerLaunched,
          receivedBytes: bytes,
          totalBytes: bytes,
          progress: 1.0,
          verifiedSha256: sha,
        );
      }
    } on MissingPluginException {
      final ok = await _launchTrustedBrowserFallback(info.apkUrl);
      progressNotifier.value = PublicOtaProgress(
        phase: ok
            ? PublicOtaInstallPhase.browserFallbackLaunched
            : PublicOtaInstallPhase.error,
        progress: ok ? 1.0 : 0.0,
        errorMessage: ok ? null : 'Instalador direto indisponível neste aparelho.',
      );
    } on PlatformException catch (e) {
      progressNotifier.value = PublicOtaProgress(
        phase: PublicOtaInstallPhase.error,
        errorMessage: humanizeErrorCode(e.code),
      );
    } catch (_) {
      progressNotifier.value = const PublicOtaProgress(
        phase: PublicOtaInstallPhase.error,
        errorMessage:
            'Não foi possível concluir o download direto. Toque para tentar novamente.',
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
        progressNotifier.value = PublicOtaProgress(
          phase: PublicOtaInstallPhase.installerLaunched,
          receivedBytes: cur.receivedBytes,
          totalBytes: cur.totalBytes,
          progress: 1.0,
          verifiedSha256: cur.verifiedSha256,
        );
      }
    } catch (_) {}
  }

  Future<bool> _launchTrustedBrowserFallback(String apkUrl) async {
    if (!isValidPublicApkUrl(apkUrl)) return false;
    try {
      return await launchUrl(
        Uri.parse(apkUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  void reset() {
    progressNotifier.value = PublicOtaProgress.idle;
  }

  void dispose() {
    if (customRunner == null && _isAndroid) {
      _channel.setMethodCallHandler(null);
    }
    progressNotifier.dispose();
  }
}

/// Controlador exposto pelo `UpdateGate` na árvore global do aplicativo `Desperrengue`
/// para que os botões discretos de atualização acionem o mesmo fluxo direto dentro do app
/// (download em streaming + verificação `SHA-256` e assinatura digital + abertura automática
/// do instalador nativo do Android, sem navegador externo).
abstract interface class PublicUpdateGateController {
  ValueListenable<PublicOtaProgress> get otaProgressListenable;
  ValueListenable<bool> get floatingCardVisibleListenable;
  UpdateInfo? get pendingUpdate;
  Future<UpdateInfo?> checkNowAndPrompt({bool autoStartInstall = false});
  Future<void> startDirectInstall(UpdateInfo info);
}

class PublicUpdateGateScope extends InheritedWidget {
  const PublicUpdateGateScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PublicUpdateGateController controller;

  static PublicUpdateGateController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PublicUpdateGateScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(PublicUpdateGateScope oldWidget) =>
      controller != oldWidget.controller;
}

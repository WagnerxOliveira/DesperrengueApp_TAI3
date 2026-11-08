import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/env.dart';
import '../state/anti_bypass_fintech_controller.dart';
import '../state/smart_triage_controller.dart';
import '../ui/app_tokens.dart';
import 'pwa_cache_buster_stub.dart'
    if (dart.library.js_interop) 'pwa_cache_buster_web.dart';
import 'update_service.dart';

/// Resultado da execução da atualização rápida em 1 toque.
@immutable
class UpdateActionOutcome {
  const UpdateActionOutcome({
    required this.versionBadge,
    required this.wasWebCachePurged,
    required this.providersInvalidated,
    this.remoteUpdateInfo,
    required this.directApkDownloadUrl,
    required this.message,
  });

  final String versionBadge;
  final bool wasWebCachePurged;
  final bool providersInvalidated;
  final UpdateInfo? remoteUpdateInfo;
  final String directApkDownloadUrl;
  final String message;
}

/// Serviço Multiplataforma de Atualização Rápida ("Botão Atualizar App" + Cache Busting PWA/Mobile).
class AppVersionAndUpdateService {
  const AppVersionAndUpdateService({this.updateService});

  final UpdateService? updateService;

  static const String currentVersion = 'v2.7.5';
  static const String currentBuild = 'Build 2026.11.07.8';
  static const String fullVersionBadge = '$currentVersion • $currentBuild';

  static const String prefAcknowledgedVersionKey = 'dsp_acknowledged_version_badge';
  static const String prefAcknowledgedBuildKey = 'dsp_acknowledged_build_number';

  /// Notificador global para esconder imediatamente todos os botões de atualização após o clique.
  static final ValueNotifier<bool> updateAcknowledgedNotifier = ValueNotifier<bool>(false);

  static String get directBetaApkUrl =>
      'https://github.com/${Env.updateRepo}/releases/download/${UpdateService.releaseTag}/desperrengue.apk';

  /// Marca a versão/build atual como já atualizada para não exibir novamente o botão.
  static Future<void> markUpdateAcknowledged({int? remoteBuild}) async {
    updateAcknowledgedNotifier.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefAcknowledgedVersionKey, fullVersionBadge);
      if (remoteBuild != null) {
        await prefs.setInt(prefAcknowledgedBuildKey, remoteBuild);
      }
    } catch (_) {}
  }

  /// Verifica se há de fato uma atualização pendente ainda não aplicada pelo usuário.
  Future<UpdateInfo?> checkPendingUpdate() async {
    if (updateAcknowledgedNotifier.value) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ackBadge = prefs.getString(prefAcknowledgedVersionKey);
      if (kIsWeb) {
        // Na Web/PWA, quando o bundle novo já foi carregado, marca automaticamente como atualizado
        // para não exibir o botão "Atualizar Aplicativo" repetidamente.
        if (ackBadge != fullVersionBadge) {
          await prefs.setString(prefAcknowledgedVersionKey, fullVersionBadge);
        }
        return null;
      }
      final checker = updateService ?? UpdateService();
      final info = await checker.check();
      if (info == null) return null;
      final ackBuild = prefs.getInt(prefAcknowledgedBuildKey);
      if (ackBuild != null && ackBuild >= info.build) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Executa a atualização imediata:
  /// - Invalida providers de estado (Riverpod) para recarregar dados frescos;
  /// - Persiste que a atualização já foi acionada para ocultar o botão;
  /// - Na Web/PWA: busca `version.json`/`manifest.json?t=...`, desregistra Service Workers,
  ///   limpa `CacheStorage` e recarrega a página;
  /// - No Mobile Nativo (Android/iOS): consulta o release `beta-latest` no GitHub
  ///   (`WagnerxOliveira/DesperrengueApp_TAI3`) e oferece download direto do APK atualizado.
  Future<UpdateActionOutcome> performQuickUpdate({
    BuildContext? context,
    bool reloadWebWindow = true,
  }) async {
    var invalidated = false;
    if (context != null) {
      final container = maybeProviderContainer(context);
      if (container != null) {
        container.invalidate(antiBypassFintechControllerProvider);
        container.invalidate(smartTriageControllerProvider);
        container.invalidate(jobTriageRegistryProvider);
        invalidated = true;
      }
    }

    if (kIsWeb) {
      await markUpdateAcknowledged();
      final purged = await purgeWebCachesAndReload(reloadWindow: reloadWebWindow);
      return UpdateActionOutcome(
        versionBadge: fullVersionBadge,
        wasWebCachePurged: purged,
        providersInvalidated: invalidated,
        directApkDownloadUrl: directBetaApkUrl,
        message:
            'Aplicativo atualizado com sucesso ($fullVersionBadge)!',
      );
    }

    final checker = updateService ?? UpdateService(enabled: true);
    final info = await checker.check();
    await markUpdateAcknowledged(remoteBuild: info?.build);

    return UpdateActionOutcome(
      versionBadge: fullVersionBadge,
      wasWebCachePurged: false,
      providersInvalidated: invalidated,
      remoteUpdateInfo: info,
      directApkDownloadUrl: info?.apkUrl ?? directBetaApkUrl,
      message: info != null
          ? 'Nova versão ${info.version} (build ${info.build}) encontrada! Abrindo instalador...'
          : 'Aplicativo já está na versão mais recente ($fullVersionBadge).',
    );
  }
}

/// Botão de atualização em 1 toque ("Atualizar App") que só aparece quando há
/// atualização pendente (ou em modo de teste quando `reloadWebOnTap == false`),
/// desaparecendo imediatamente após o usuário clicar e atualizar.
class AppQuickUpdateButton extends StatefulWidget {
  const AppQuickUpdateButton({
    super.key,
    this.compact = true,
    this.reloadWebOnTap = true,
  });

  final bool compact;
  final bool reloadWebOnTap;

  @override
  State<AppQuickUpdateButton> createState() => _AppQuickUpdateButtonState();
}

class _AppQuickUpdateButtonState extends State<AppQuickUpdateButton> {
  bool _busy = false;
  bool _hasPendingUpdate = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    AppVersionAndUpdateService.updateAcknowledgedNotifier.addListener(_onAckChanged);
    _checkAvailability();
  }

  @override
  void dispose() {
    AppVersionAndUpdateService.updateAcknowledgedNotifier.removeListener(_onAckChanged);
    super.dispose();
  }

  void _onAckChanged() {
    if (!mounted) return;
    if (AppVersionAndUpdateService.updateAcknowledgedNotifier.value) {
      setState(() => _hasPendingUpdate = false);
    }
  }

  Future<void> _checkAvailability() async {
    // Em testes de widget (`reloadWebOnTap == false`), permite renderizar o botão se ainda não clicado.
    if (!widget.reloadWebOnTap) {
      if (mounted) {
        setState(() {
          _hasPendingUpdate = !AppVersionAndUpdateService.updateAcknowledgedNotifier.value;
          _checked = true;
        });
      }
      return;
    }
    final pending = await const AppVersionAndUpdateService().checkPendingUpdate();
    if (!mounted) return;
    setState(() {
      _hasPendingUpdate = pending != null && !AppVersionAndUpdateService.updateAcknowledgedNotifier.value;
      _checked = true;
    });
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Atualizando aplicativo para a versão mais recente...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final service = const AppVersionAndUpdateService();
      final outcome = await service.performQuickUpdate(
        context: context,
        reloadWebWindow: widget.reloadWebOnTap,
      );
      if (!mounted) return;
      setState(() => _hasPendingUpdate = false);

      if (!kIsWeb && outcome.remoteUpdateInfo != null) {
        await _showMobileUpdateSheet(context, outcome);
      } else {
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(outcome.message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMobileUpdateSheet(
    BuildContext context,
    UpdateActionOutcome outcome,
  ) async {
    final tk = context.tk;
    final info = outcome.remoteUpdateInfo;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tk.infoSoft,
                    child: Icon(Icons.system_update_alt_rounded, color: tk.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info != null ? 'Nova Atualização Disponível!' : 'Atualização Rápida Desperrengue',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: tk.text,
                          ),
                        ),
                        Text(
                          outcome.versionBadge,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tk.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                info != null
                    ? 'Build ${info.build} disponível no repositório oficial (${Env.updateRepo}).${info.notes.isNotEmpty ? "\nNovidades: ${info.notes}" : ""}'
                    : 'Os dados da sessão foram sincronizados com sucesso. Se você acabou de enviar alterações para o GitHub, toque abaixo para baixar e instalar o APK mais recente (beta-latest).',
                style: TextStyle(fontSize: 13.5, height: 1.4, color: tk.text),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(outcome.directApkDownloadUrl);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    info != null
                        ? 'Baixar e Instalar Versão ${info.version}'
                        : 'Baixar Último APK Oficial (beta-latest)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_hasPendingUpdate) {
      return const SizedBox.shrink();
    }
    final tk = context.tk;
    final cs = Theme.of(context).colorScheme;
    if (widget.compact) {
      return Semantics(
        button: true,
        label: 'Atualizar App ${AppVersionAndUpdateService.fullVersionBadge}',
        child: Material(
          color: cs.primaryContainer.withValues(alpha: tk.isDark ? 0.35 : 0.65),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 15,
                      color: cs.primary,
                    ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Atualizar App',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withValues(alpha: 0.14),
            child: Icon(Icons.system_update_alt_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atualizar Aplicativo (1 Toque)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: tk.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppVersionAndUpdateService.fullVersionBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tk.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _handleTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}

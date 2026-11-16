import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/env.dart';
import '../state/anti_bypass_fintech_controller.dart';
import '../state/smart_triage_controller.dart';
import '../ui/app_tokens.dart';
import 'public_ota_installer.dart';
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

/// Serviço Multiplataforma de Atualização Sem Dor de Cabeça do aplicativo
/// `Desperrengue` (Cache Busting PWA na Web + Download Direto, Verificação de
/// Assinatura Digital e Instalador Nativo no Android, sem abrir navegador).
class AppVersionAndUpdateService {
  const AppVersionAndUpdateService({this.updateService});

  final UpdateService? updateService;

  static const String currentVersion = 'v2.17.0';
  static const String currentBuild = 'Build 2026.11.16.1';
  static const String fullVersionBadge = '$currentVersion • $currentBuild';

  static const String prefAcknowledgedVersionKey =
      'dsp_acknowledged_version_badge';
  static const String prefAcknowledgedBuildKey =
      'dsp_acknowledged_build_number';

  /// Notificador global para sincronizar os indicadores discretos de atualização.
  static final ValueNotifier<bool> updateAcknowledgedNotifier =
      ValueNotifier<bool>(false);

  static String get directBetaApkUrl =>
      'https://github.com/${Env.updateRepo}/releases/download/${UpdateService.releaseTag}/${UpdateService.publicApkAssetName}';

  /// Invalida controladores reativos para garantir dados frescos de sessão.
  static bool invalidateCoreProviders(BuildContext? context) {
    if (context == null) return false;
    final container = maybeProviderContainer(context);
    if (container == null) return false;
    container.invalidate(antiBypassFintechControllerProvider);
    container.invalidate(smartTriageControllerProvider);
    container.invalidate(jobTriageRegistryProvider);
    return true;
  }

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

  /// Executa a atualização imediata sem navegador externo:
  /// - Invalida providers de estado (Riverpod) para recarregar dados frescos;
  /// - Na Web/PWA: desregistra Service Workers, limpa `CacheStorage` e recarrega;
  /// - No Android: consulta `beta-latest` e aciona o instalador direto in-app com
  ///   verificação de `SHA-256` e assinatura digital X.509.
  Future<UpdateActionOutcome> performQuickUpdate({
    BuildContext? context,
    bool reloadWebWindow = true,
  }) async {
    final invalidated = invalidateCoreProviders(context);

    if (kIsWeb) {
      await markUpdateAcknowledged();
      final purged =
          await purgeWebCachesAndReload(reloadWindow: reloadWebWindow);
      return UpdateActionOutcome(
        versionBadge: fullVersionBadge,
        wasWebCachePurged: purged,
        providersInvalidated: invalidated,
        directApkDownloadUrl: directBetaApkUrl,
        message: 'Aplicativo atualizado com sucesso ($fullVersionBadge)!',
      );
    }

    final checker = updateService ?? UpdateService(enabled: true);
    final info = await checker.check(forceManualCheck: true);
    if (info == null) {
      await markUpdateAcknowledged();
    }

    return UpdateActionOutcome(
      versionBadge: fullVersionBadge,
      wasWebCachePurged: false,
      providersInvalidated: invalidated,
      remoteUpdateInfo: info,
      directApkDownloadUrl: info?.apkUrl ?? directBetaApkUrl,
      message: info != null
          ? 'Baixando versão ${info.version} com verificação de segurança…'
          : 'Seu Desperrengue já está na versão mais recente ($fullVersionBadge).',
    );
  }
}

/// Botão elegante e discreto de atualização rápida em 1 toque ("Atualizar").
///
/// - Aparece silenciosamente apenas quando existe uma versão mais nova disponível
///   (ou em modo de teste determinístico quando `reloadWebOnTap == false`);
/// - No cabeçalho (`compact: true`), recolhe-se automaticamente enquanto o cartão
///   flutuante de entrada (`UpdateGate`) já estiver visível no topo, evitando
///   duplicidade visual;
/// - Ao tocar, aciona diretamente o download em streaming dentro do próprio app,
///   confere `SHA-256` + assinatura digital e abre o instalador nativo do Android
///   sozinho — sem abrir navegador nem exigir busca em pastas.
class AppQuickUpdateButton extends StatefulWidget {
  const AppQuickUpdateButton({
    super.key,
    this.compact = true,
    this.reloadWebOnTap = true,
    this.updateService,
    this.otaInstaller,
  });

  final bool compact;
  final bool reloadWebOnTap;
  final UpdateService? updateService;
  final PublicNativeOtaInstaller? otaInstaller;

  @override
  State<AppQuickUpdateButton> createState() => _AppQuickUpdateButtonState();
}

class _AppQuickUpdateButtonState extends State<AppQuickUpdateButton> {
  bool _busy = false;
  bool _hasPendingUpdate = false;
  bool _checked = false;
  UpdateInfo? _pendingInfo;
  PublicNativeOtaInstaller? _standaloneInstaller;

  @override
  void initState() {
    super.initState();
    AppVersionAndUpdateService.updateAcknowledgedNotifier
        .addListener(_onAckChanged);
    _checkAvailability();
  }

  @override
  void dispose() {
    AppVersionAndUpdateService.updateAcknowledgedNotifier
        .removeListener(_onAckChanged);
    _standaloneInstaller?.dispose();
    super.dispose();
  }

  void _onAckChanged() {
    if (!mounted) return;
    if (AppVersionAndUpdateService.updateAcknowledgedNotifier.value) {
      setState(() => _hasPendingUpdate = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (!widget.reloadWebOnTap && widget.updateService == null) {
      if (mounted) {
        setState(() {
          _hasPendingUpdate =
              !AppVersionAndUpdateService.updateAcknowledgedNotifier.value;
          _checked = true;
        });
      }
      return;
    }
    final pending = await AppVersionAndUpdateService(
      updateService: widget.updateService,
    ).checkPendingUpdate();
    if (!mounted) return;
    setState(() {
      _pendingInfo = pending;
      _hasPendingUpdate = pending != null &&
          !AppVersionAndUpdateService.updateAcknowledgedNotifier.value;
      _checked = true;
    });
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      AppVersionAndUpdateService.invalidateCoreProviders(context);

      if (kIsWeb) {
        final service = AppVersionAndUpdateService(
          updateService: widget.updateService,
        );
        final outcome = await service.performQuickUpdate(
          context: context,
          reloadWebWindow: widget.reloadWebOnTap,
        );
        if (!mounted) return;
        setState(() => _hasPendingUpdate = false);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(outcome.message),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final gate = PublicUpdateGateScope.maybeOf(context);
      if (gate != null) {
        final found = await gate.checkNowAndPrompt(autoStartInstall: true);
        if (!mounted) return;
        if (found == null) {
          await AppVersionAndUpdateService.markUpdateAcknowledged();
          if (!mounted) return;
          setState(() => _hasPendingUpdate = false);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'Seu Desperrengue já está na versão mais recente.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Modo autônomo (quando montado fora de um UpdateGate, ex.: testes isolados):
      final info = _pendingInfo ??
          await (widget.updateService ?? UpdateService(enabled: true))
              .check(forceManualCheck: true);
      if (info != null) {
        final installer = widget.otaInstaller ??
            (_standaloneInstaller ??= PublicNativeOtaInstaller());
        await installer.downloadAndInstall(info);
        await AppVersionAndUpdateService.markUpdateAcknowledged(
          remoteBuild: info.build,
        );
        if (mounted) {
          setState(() => _hasPendingUpdate = false);
        }
      } else {
        await AppVersionAndUpdateService.markUpdateAcknowledged();
        if (!mounted) return;
        setState(() => _hasPendingUpdate = false);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Seu Desperrengue já está na versão mais recente.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildContent(BuildContext context) {
    final tk = context.tk;
    final cs = Theme.of(context).colorScheme;

    if (widget.compact) {
      return Semantics(
        button: true,
        label: 'Atualizar aplicativo',
        child: Material(
          key: const ValueKey<String>('public-discreet-update-pill'),
          color: cs.primary.withValues(alpha: tk.isDark ? 0.13 : 0.08),
          shape: StadiumBorder(
            side: BorderSide(
              color: cs.primary.withValues(alpha: tk.isDark ? 0.28 : 0.18),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _busy ? null : _handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9.5, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_busy)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.system_update_rounded,
                      size: 13.5,
                      color: cs.primary,
                    ),
                  const SizedBox(width: 4.5),
                  Flexible(
                    child: Text(
                      'Atualizar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
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

    final info = _pendingInfo;
    final subtitleText = info != null && info.version.isNotEmpty
        ? [
            'Versão ${info.version}',
            if (info.sizeLabel.isNotEmpty) info.sizeLabel,
            'Instalação segura no app',
          ].join(' · ')
        : 'Baixa, verifica a segurança e instala sem sair do app';

    final actionButton = FilledButton(
      key: const ValueKey<String>('public-discreet-update-card-btn'),
      onPressed: _busy ? null : _handleTap,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary.withValues(alpha: tk.isDark ? 0.18 : 0.11),
        foregroundColor: cs.primary,
        disabledBackgroundColor:
            cs.primary.withValues(alpha: tk.isDark ? 0.10 : 0.06),
        elevation: 0,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_busy) ...<Widget>[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Text(
            'Atualizar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Container(
      key: const ValueKey<String>('public-discreet-update-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tk.isDark ? tk.raised : tk.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tk.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final stacked = constraints.maxWidth < 290 || textScale > 1.3;

          final leadingIcon = Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: tk.isDark ? 0.15 : 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.system_update_rounded,
              size: 18,
              color: cs.primary,
            ),
          );

          final textColumn = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Nova versão disponível',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.1,
                  color: tk.text,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitleText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  color: tk.textMuted,
                ),
              ),
            ],
          );

          if (!stacked) {
            return Row(
              children: <Widget>[
                leadingIcon,
                const SizedBox(width: 12),
                Expanded(child: textColumn),
                const SizedBox(width: 10),
                actionButton,
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  leadingIcon,
                  const SizedBox(width: 12),
                  Expanded(child: textColumn),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: actionButton,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_hasPendingUpdate) {
      return const SizedBox.shrink();
    }
    final gate = PublicUpdateGateScope.maybeOf(context);
    if (widget.compact && widget.reloadWebOnTap && gate != null) {
      return ValueListenableBuilder<bool>(
        valueListenable: gate.floatingCardVisibleListenable,
        builder: (context, gateCardVisible, _) {
          if (gateCardVisible) {
            return const SizedBox.shrink();
          }
          return _buildContent(context);
        },
      );
    }
    return _buildContent(context);
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_version_and_update_service.dart';
import '../../core/services/public_ota_installer.dart';
import '../../core/services/update_service.dart';
import '../../core/ui/app_tokens.dart';

/// Portão flutuante discreto de **Atualização Sem Dor de Cabeça** do aplicativo
/// `Desperrengue` (montado em `MaterialApp.builder` de `lib/main.dart`).
///
/// Quando sai uma versão nova no canal oficial (`beta-latest`), exibe um aviso
/// elegante e discreto logo na entrada (mesmo antes do login). Ao tocar em
/// **Atualizar**, o próprio aplicativo baixa o pacote em streaming, confere o
/// hash `SHA-256` e a assinatura digital X.509 de segurança e abre sozinho o
/// instalador nativo do Android — sem abrir navegador e sem procurar arquivos
/// nas pastas do celular.
///
/// Desativado automaticamente (não faz requisições) em builds da Play Store
/// compilados sem `BETA_UPDATES=true`.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.check,
    this.openUrl,
    this.service,
    this.installer,
    this.interval = const Duration(seconds: 60),
    this.initialDelay = const Duration(seconds: 3),
  });

  final Widget child;

  /// Callbacks e serviços injetáveis para testes determinísticos.
  final Future<UpdateInfo?> Function()? check;
  final Future<void> Function(String url)? openUrl;
  final UpdateService? service;
  final PublicNativeOtaInstaller? installer;
  final Duration interval;
  final Duration initialDelay;

  static const String gateDismissedBuildPrefKey = 'dsp_gate_dismissed_build_v2';

  static PublicUpdateGateController? maybeOf(BuildContext context) {
    return PublicUpdateGateScope.maybeOf(context);
  }

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate>
    with WidgetsBindingObserver
    implements PublicUpdateGateController {
  late final UpdateService _service = widget.service ?? UpdateService();
  late final Future<UpdateInfo?> Function() _check =
      widget.check ?? _service.check;
  late final PublicNativeOtaInstaller _installer =
      widget.installer ?? PublicNativeOtaInstaller();
  late final bool _ownsInstaller = widget.installer == null;

  final ValueNotifier<bool> _floatingCardVisibleNotifier =
      ValueNotifier<bool>(false);

  Timer? _first;
  Timer? _periodic;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _checking = false;

  UpdateInfo? _info;
  int? _dismissedBuild;
  bool _manualOverrideVisible = false;
  bool _legacyDownloading = false;

  @override
  ValueListenable<PublicOtaProgress> get otaProgressListenable =>
      _installer.progressNotifier;

  @override
  ValueListenable<bool> get floatingCardVisibleListenable =>
      _floatingCardVisibleNotifier;

  @override
  UpdateInfo? get pendingUpdate => _info;

  bool get _shouldShowFloatingCard {
    final info = _info;
    if (info == null) return false;
    return _manualOverrideVisible ||
        _dismissedBuild == null ||
        info.build > _dismissedBuild!;
  }

  void _syncVisibilityNotifier() {
    final next = _shouldShowFloatingCard;
    if (_floatingCardVisibleNotifier.value != next) {
      _floatingCardVisibleNotifier.value = next;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _installer.progressNotifier.addListener(_onOtaProgressChanged);
    if (widget.check == null) {
      unawaited(_loadPersistedDismissedBuild());
    }
    _first = Timer(widget.initialDelay, _run);
    _periodic = Timer.periodic(widget.interval, (_) => _run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _installer.progressNotifier.removeListener(_onOtaProgressChanged);
    _first?.cancel();
    _periodic?.cancel();
    if (_ownsInstaller) {
      _installer.dispose();
    }
    _floatingCardVisibleNotifier.dispose();
    super.dispose();
  }

  void _onOtaProgressChanged() {
    final phase = _installer.progressNotifier.value.phase;
    final currentInfo = _info;
    if (currentInfo != null &&
        widget.check == null &&
        (phase == PublicOtaInstallPhase.installerLaunched ||
            phase == PublicOtaInstallPhase.browserFallbackLaunched)) {
      unawaited(
        AppVersionAndUpdateService.markUpdateAcknowledged(
          remoteBuild: currentInfo.build,
        ),
      );
    }
  }

  Future<void> _loadPersistedDismissedBuild() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var gateDismissed = prefs.getInt(UpdateGate.gateDismissedBuildPrefKey);
      var ackBuild =
          prefs.getInt(AppVersionAndUpdateService.prefAcknowledgedBuildKey);
      if (gateDismissed != null &&
          gateDismissed >= 200000000 &&
          gateDismissed < 210000000) {
        await prefs.remove(UpdateGate.gateDismissedBuildPrefKey);
        gateDismissed = null;
      }
      if (ackBuild != null && ackBuild >= 200000000 && ackBuild < 210000000) {
        await prefs.remove(AppVersionAndUpdateService.prefAcknowledgedBuildKey);
        ackBuild = null;
      }
      int? effective;
      if (gateDismissed != null && ackBuild != null) {
        effective = gateDismissed > ackBuild ? gateDismissed : ackBuild;
      } else {
        effective = gateDismissed ?? ackBuild;
      }
      if (effective != null && mounted && _dismissedBuild != effective) {
        setState(() {
          _dismissedBuild = effective;
          _syncVisibilityNotifier();
        });
      }
    } catch (_) {}
  }

  Future<void> _persistGateDismissedBuild(
    int build, {
    required bool alsoMarkGlobalAck,
  }) async {
    if (widget.check != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(UpdateGate.gateDismissedBuildPrefKey, build);
      if (alsoMarkGlobalAck) {
        await AppVersionAndUpdateService.markUpdateAcknowledged(
          remoteBuild: build,
        );
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_last) > const Duration(seconds: 15)) {
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    if (_checking || !mounted) return;
    _checking = true;
    _last = DateTime.now();
    try {
      if (widget.check == null) {
        await _loadPersistedDismissedBuild();
      }
      final info = await _check();
      if (!mounted) return;
      if (info?.build != _info?.build) {
        if (info != null) {
          _installer.reset();
        }
        setState(() {
          _info = info;
          _legacyDownloading = false;
          _syncVisibilityNotifier();
        });
      }
    } catch (_) {
      // Falha de rede ou parse nunca vira erro não tratado no Timer.
    } finally {
      _checking = false;
    }
  }

  @override
  Future<UpdateInfo?> checkNowAndPrompt({
    bool autoStartInstall = false,
  }) async {
    _last = DateTime.now();
    UpdateInfo? info;
    try {
      if (widget.check != null) {
        info = await widget.check!();
      } else {
        final effectiveService = widget.service ?? UpdateService(enabled: true);
        info = await effectiveService.check(forceManualCheck: true);
      }
    } catch (_) {
      info = _info;
    }
    info ??= _info;
    if (!mounted) return info;
    if (info != null) {
      if (_info?.build != info.build) {
        _installer.reset();
      }
      setState(() {
        _info = info;
        _manualOverrideVisible = true;
        _legacyDownloading = false;
        _syncVisibilityNotifier();
      });
      if (autoStartInstall) {
        unawaited(startDirectInstall(info));
      }
    }
    return info;
  }

  @override
  Future<void> startDirectInstall(UpdateInfo info) async {
    if (widget.openUrl != null) {
      setState(() => _legacyDownloading = true);
      try {
        await widget.openUrl!(info.apkUrl);
      } catch (_) {
        if (mounted) {
          setState(() => _legacyDownloading = false);
        }
      }
      return;
    }

    HapticFeedback.selectionClick();
    await _installer.downloadAndInstall(info);
  }

  void _dismissCard(UpdateInfo info, {required bool completedInstall}) {
    unawaited(
      _persistGateDismissedBuild(
        info.build,
        alsoMarkGlobalAck: completedInstall,
      ),
    );
    _installer.reset();
    setState(() {
      _dismissedBuild = info.build;
      _manualOverrideVisible = false;
      _legacyDownloading = false;
      _syncVisibilityNotifier();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final show = _shouldShowFloatingCard && info != null;

    return PublicUpdateGateScope(
      controller: this,
      child: Stack(
        children: <Widget>[
          widget.child,
          if (show)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ValueListenableBuilder<PublicOtaProgress>(
                    valueListenable: _installer.progressNotifier,
                    builder: (context, otaState, _) {
                      final completedPhase = otaState.phase ==
                              PublicOtaInstallPhase.installerLaunched ||
                          otaState.phase ==
                              PublicOtaInstallPhase.browserFallbackLaunched;
                      return _DiscreetFloatingUpdateCard(
                        info: info,
                        otaState: otaState,
                        legacyDownloading: _legacyDownloading,
                        onDismiss: () => _dismissCard(
                          info,
                          completedInstall:
                              completedPhase || _legacyDownloading,
                        ),
                        onUpdateNow: () => startDirectInstall(info),
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

class _DiscreetFloatingUpdateCard extends StatelessWidget {
  const _DiscreetFloatingUpdateCard({
    required this.info,
    required this.otaState,
    required this.legacyDownloading,
    required this.onDismiss,
    required this.onUpdateNow,
    required this.onTriggerPendingInstall,
  });

  final UpdateInfo info;
  final PublicOtaProgress otaState;
  final bool legacyDownloading;
  final VoidCallback onDismiss;
  final VoidCallback onUpdateNow;
  final VoidCallback onTriggerPendingInstall;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final accent = Theme.of(context).colorScheme.primary;
    final phase = otaState.phase;
    final busy = otaState.isBusy;

    final statusColor = switch (phase) {
      PublicOtaInstallPhase.error => tk.danger,
      PublicOtaInstallPhase.verifying ||
      PublicOtaInstallPhase.installerLaunched =>
        tk.success,
      PublicOtaInstallPhase.awaitingPermission => tk.warningInk,
      _ => accent,
    };

    final String title;
    final String subtitle;
    if (legacyDownloading) {
      title = 'Baixando...';
      subtitle = 'Quando terminar, toque na notificação e em "Instalar".';
    } else {
      title = switch (phase) {
        PublicOtaInstallPhase.downloading => 'Baixando atualização…',
        PublicOtaInstallPhase.verifying => 'Verificando assinatura digital…',
        PublicOtaInstallPhase.awaitingPermission =>
          'Autorize a instalação direta (1 vez)',
        PublicOtaInstallPhase.installerLaunched =>
          'Pronto! Toque em "Atualizar" no Android',
        PublicOtaInstallPhase.browserFallbackLaunched =>
          'Download seguro iniciado',
        PublicOtaInstallPhase.error => 'Não foi possível atualizar agora',
        PublicOtaInstallPhase.idle => 'Nova versão',
      };

      subtitle = switch (phase) {
        PublicOtaInstallPhase.downloading => otaState.transferLabel.isNotEmpty
            ? otaState.transferLabel
            : 'Baixando diretamente no aplicativo…',
        PublicOtaInstallPhase.verifying =>
          'Conferindo integridade SHA-256 e assinatura digital de segurança…',
        PublicOtaInstallPhase.awaitingPermission =>
          'Ative "Permitir desta fonte" e volte: o instalador abre sozinho.',
        PublicOtaInstallPhase.installerLaunched =>
          'Assinatura digital conferida. Confirme na janela do Android.',
        PublicOtaInstallPhase.browserFallbackLaunched =>
          'Ao concluir, confirme em "Atualizar" na janela do sistema.',
        PublicOtaInstallPhase.error =>
          otaState.errorMessage ?? 'Toque em "Tentar de novo" para repetir.',
        PublicOtaInstallPhase.idle => [
            if (info.version.isNotEmpty) 'Versão ${info.version}',
            if (info.sizeLabel.isNotEmpty) info.sizeLabel,
          ].join(' · '),
      };
    }

    final showIdleNotes = !legacyDownloading &&
        phase == PublicOtaInstallPhase.idle &&
        info.notes.isNotEmpty;

    final Widget leadingBadge = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: tk.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: phase == PublicOtaInstallPhase.downloading &&
                        otaState.progress > 0
                    ? otaState.progress
                    : null,
                color: statusColor,
              ),
            )
          : Icon(
              switch (phase) {
                PublicOtaInstallPhase.verifying => Icons.verified_user_rounded,
                PublicOtaInstallPhase.awaitingPermission =>
                  Icons.security_update_good_rounded,
                PublicOtaInstallPhase.installerLaunched =>
                  Icons.check_circle_rounded,
                PublicOtaInstallPhase.error => Icons.error_outline_rounded,
                _ => Icons.system_update_rounded,
              },
              color: statusColor,
              size: 18,
            ),
    );

    final dismissLabel = (legacyDownloading ||
            busy ||
            phase == PublicOtaInstallPhase.installerLaunched ||
            phase == PublicOtaInstallPhase.browserFallbackLaunched)
        ? 'Fechar'
        : 'Depois';

    final Widget dismissButton = TextButton(
      key: const ValueKey<String>('public-ota-later-btn'),
      onPressed: onDismiss,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: tk.textMuted,
      ),
      child: Text(
        dismissLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );

    Widget? primaryActionButton;
    if (!legacyDownloading && !busy) {
      switch (phase) {
        case PublicOtaInstallPhase.idle:
          primaryActionButton = _DiscreetCapsuleActionButton(
            buttonKey: const ValueKey<String>('public-ota-install-btn'),
            label: 'Atualizar',
            accent: accent,
            isDark: tk.isDark,
            onPressed: onUpdateNow,
          );
        case PublicOtaInstallPhase.awaitingPermission:
          primaryActionButton = _DiscreetCapsuleActionButton(
            buttonKey: const ValueKey<String>('public-ota-resume-btn'),
            label: 'Instalar agora',
            accent: accent,
            isDark: tk.isDark,
            onPressed: onTriggerPendingInstall,
          );
        case PublicOtaInstallPhase.installerLaunched:
          primaryActionButton = _DiscreetCapsuleActionButton(
            buttonKey: const ValueKey<String>('public-ota-reopen-btn'),
            label: 'Abrir instalador',
            accent: tk.success,
            isDark: tk.isDark,
            tonal: true,
            onPressed: onTriggerPendingInstall,
          );
        case PublicOtaInstallPhase.error:
          primaryActionButton = _DiscreetCapsuleActionButton(
            buttonKey: const ValueKey<String>('public-ota-retry-btn'),
            label: 'Tentar de novo',
            accent: accent,
            isDark: tk.isDark,
            onPressed: onUpdateNow,
          );
        case PublicOtaInstallPhase.downloading:
        case PublicOtaInstallPhase.verifying:
        case PublicOtaInstallPhase.browserFallbackLaunched:
          primaryActionButton = null;
      }
    }

    return Semantics(
      liveRegion: true,
      label: 'Nova versão do aplicativo disponível',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1.0 - anim) * -4.0),
            child: child,
          ),
        ),
        child: Material(
          key: const ValueKey<String>('public-floating-ota-card'),
          color: tk.isDark ? tk.raised : tk.surface,
          elevation: tk.isDark ? 0 : 8,
          shadowColor: tk.shadow,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: statusColor.withValues(alpha: tk.isDark ? 0.28 : 0.18),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final stackActions = constraints.maxWidth < 340 ||
                    textScale > 1.15 ||
                    (!legacyDownloading && phase != PublicOtaInstallPhase.idle);

                final textColumn = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: tk.text,
                              fontSize: 13.5,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        if (!legacyDownloading &&
                            phase == PublicOtaInstallPhase.idle &&
                            info.sha256 != null) ...<Widget>[
                          const SizedBox(width: 5),
                          Semantics(
                            label:
                                'Pacote com assinatura digital e SHA-256 verificados',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 13.5,
                              color: tk.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tk.textMuted,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (showIdleNotes) ...<Widget>[
                      const SizedBox(height: 1.5),
                      Text(
                        info.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tk.textMuted.withValues(alpha: 0.85),
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                );

                if (!stackActions) {
                  return Row(
                    children: <Widget>[
                      leadingBadge,
                      const SizedBox(width: 10),
                      Expanded(child: textColumn),
                      const SizedBox(width: 6),
                      dismissButton,
                      if (primaryActionButton != null) ...<Widget>[
                        const SizedBox(width: 4),
                        primaryActionButton,
                      ],
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
                        leadingBadge,
                        const SizedBox(width: 10),
                        Expanded(child: textColumn),
                      ],
                    ),
                    if (busy) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          key: const ValueKey<String>(
                            'public-ota-progress-bar',
                          ),
                          minHeight: 4.5,
                          value: phase == PublicOtaInstallPhase.downloading &&
                                  otaState.progress > 0
                              ? otaState.progress
                              : null,
                          backgroundColor:
                              statusColor.withValues(alpha: 0.14),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        dismissButton,
                        ?primaryActionButton,
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscreetCapsuleActionButton extends StatelessWidget {
  const _DiscreetCapsuleActionButton({
    required this.buttonKey,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onPressed,
    this.tonal = false,
  });

  final Key buttonKey;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final bg = tonal
        ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
        : accent;
    final fg = tonal ? accent : Colors.white;
    return FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

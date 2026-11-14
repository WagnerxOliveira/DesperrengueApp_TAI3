import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/money.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';
import 'founder_auth_and_vault_gate.dart';
import 'founder_charts_painters.dart';
import 'founder_innovations_widgets.dart';
import 'founder_live_sheets_and_radar.dart';
import 'founder_update_gate.dart';

class _PeriodOption {
  const _PeriodOption(this.key, this.label);
  final String key;
  final String label;
}

const List<_PeriodOption> _kPeriodOptions = <_PeriodOption>[
  _PeriodOption('today', 'Hoje'),
  _PeriodOption('7d', '7d'),
  _PeriodOption('30d', '30d'),
  _PeriodOption('90d', '90d'),
  _PeriodOption('365d', '365d'),
  _PeriodOption('all', 'Tudo'),
];

class _NavTabSpec {
  const _NavTabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<_NavTabSpec> _kFiveTabs = <_NavTabSpec>[
  _NavTabSpec('Ao Vivo', Icons.bolt_rounded),
  _NavTabSpec('Caixa', Icons.account_balance_rounded),
  _NavTabSpec('Operações', Icons.explore_rounded),
  _NavTabSpec('Usuários', Icons.groups_rounded),
  _NavTabSpec('Cofre', Icons.shield_rounded),
];

String _formatShortBrt(DateTime? utc) {
  if (utc == null) return '—';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  final hh = brt.hour.toString().padLeft(2, '0');
  final min = brt.minute.toString().padLeft(2, '0');
  final sec = brt.second.toString().padLeft(2, '0');
  return '$dd/$mm $hh:$min:$sec';
}

/// Sala de Guerra em Tempo Real & Cofre Monocrático do `Desperrengue CEO`.
///
/// Princípios inegociáveis:
/// - **Zero dados falsos (`Zero-Fake Policy`)**: 100% alimentado pelas tabelas reais
///   do `Desperrengue` via PostgreSQL 17 + WebSocket `WSS TLS 1.3` (`ceo:war-room:live`).
/// - **Exclusividade Monocrática**: acesso único e irrestrito de `wagneroliveira2395@gmail.com`.
/// - **Zero campos pré-preenchidos**: toda entrada de credencial, código ou filtro inicia vazia.
class FounderCockpitScreen extends StatefulWidget {
  const FounderCockpitScreen({
    super.key,
    this.repository,
    this.updateService,
    this.screenSecurityBridge = const CeoScreenSecurityBridge(),
    this.inactivityLockTimeout = const Duration(minutes: 10),
    this.backgroundLockTimeout = const Duration(minutes: 5),
  });

  final FounderCockpitRepository? repository;
  final FounderUpdateService? updateService;
  final CeoScreenSecurityBridge screenSecurityBridge;
  final Duration inactivityLockTimeout;
  final Duration backgroundLockTimeout;

  @override
  State<FounderCockpitScreen> createState() => _FounderCockpitScreenState();
}

class _FounderCockpitScreenState extends State<FounderCockpitScreen>
    with WidgetsBindingObserver {
  late final FounderCockpitRepository _repo;
  late final bool _ownsRepo;

  StreamSubscription<FounderDashboardSnapshot>? _snapshotSub;
  StreamSubscription<CeoLiveEventItem>? _liveEventSub;
  Timer? _inactivityTimer;
  Timer? _captureCountdownTimer;
  Timer? _liveBannerTimer;
  DateTime? _pausedAtUtc;

  FounderStepUpSession? _session;
  FounderDashboardSnapshot _snapshot = FounderDashboardSnapshot.emptyZero();

  int _selectedTabIndex = 0;
  String _selectedWindowKey = '30d';
  String _ordersStatusFilter = 'all';
  bool _showAll33Categories = false;
  bool _privacyBlurActive = false;
  bool _loadingSnapshot = false;
  bool _pinResetFlowRequested = false;
  String? _lockReasonBanner;
  String? _snapshotErrorBanner;
  CeoLiveEventItem? _transientLiveBanner;

  CeoScreenProtectionState _screenProtection =
      CeoScreenProtectionState.lockedDefault;
  String? _otaStatusMessage;
  bool _checkingOta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? FounderCockpitRepository();
    _session = _repo.activeStepUpSession;
    _snapshot = _repo.currentSnapshot;

    _snapshotSub = _repo.snapshotChanges.listen((next) {
      if (!mounted) return;
      setState(() {
        _snapshot = next;
        _selectedWindowKey = next.windowKey;
        _snapshotErrorBanner = null;
      });
    });

    _liveEventSub = _repo.liveEventArrivals.listen((ev) {
      if (!mounted) return;
      _liveBannerTimer?.cancel();
      setState(() => _transientLiveBanner = ev);
      _liveBannerTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _transientLiveBanner = null);
      });
    });

    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    unawaited(_refreshScreenSecurityStatus());
    if (_session != null) {
      _resetInactivityTimer();
      unawaited(_refreshLiveSnapshot());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _snapshotSub?.cancel();
    _liveEventSub?.cancel();
    _inactivityTimer?.cancel();
    _captureCountdownTimer?.cancel();
    _liveBannerTimer?.cancel();
    if (_ownsRepo) {
      _repo.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_session == null) return;
    if (state == AppLifecycleState.paused) {
      _pausedAtUtc = DateTime.now().toUtc();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAtUtc;
      _pausedAtUtc = null;
      if (pausedAt != null &&
          DateTime.now().toUtc().difference(pausedAt) >=
              widget.backgroundLockTimeout) {
        unawaited(
          _lockVaultWithReason(
            'Cofre trancado automaticamente após período em segundo plano.',
          ),
        );
      } else {
        _resetInactivityTimer();
        unawaited(_repo.catchUpMissedLiveEvents());
        unawaited(_refreshScreenSecurityStatus());
      }
    }
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_session == null) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null) {
      var hasEditable = false;
      focused.visitAncestorElements((el) {
        if (el.widget is EditableText) {
          hasEditable = true;
          return false;
        }
        return true;
      });
      if (focused.widget is EditableText || hasEditable) return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      HapticFeedback.selectionClick();
      setState(() => _privacyBlurActive = !_privacyBlurActive);
      return true;
    }
    return false;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_session == null) return;
    _inactivityTimer = Timer(widget.inactivityLockTimeout, () {
      unawaited(
        _lockVaultWithReason(
          'Cofre trancado automaticamente por inatividade executiva.',
        ),
      );
    });
  }

  Future<void> _lockVaultWithReason(String? reason, {bool pinReset = false}) async {
    _inactivityTimer?.cancel();
    await _repo.lockVault();
    if (!mounted) return;
    setState(() {
      _session = null;
      _pinResetFlowRequested = pinReset;
      _lockReasonBanner = reason;
      _transientLiveBanner = null;
    });
  }

  Future<void> _onVaultUnlocked(FounderStepUpSession unlockedSession) async {
    if (!mounted) return;
    setState(() {
      _session = unlockedSession;
      _pinResetFlowRequested = false;
      _lockReasonBanner = null;
      _loadingSnapshot = true;
    });
    _resetInactivityTimer();
    await _refreshLiveSnapshot();
  }

  Future<void> _refreshLiveSnapshot({String? windowKey}) async {
    if (_session == null) return;
    final targetWindow = windowKey ?? _selectedWindowKey;
    setState(() {
      _loadingSnapshot = true;
      _selectedWindowKey = targetWindow;
      _snapshotErrorBanner = null;
    });
    try {
      final fresh = await _repo.fetchLiveSnapshot(windowKey: targetWindow);
      if (!mounted) return;
      setState(() {
        _snapshot = fresh;
        _loadingSnapshot = false;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.errorCode.contains('STEPUP_SESSION') ||
          e.errorCode.contains('VAULT_LOCKED') ||
          e.errorCode.contains('UNAUTHENTICATED')) {
        await _lockVaultWithReason(e.userMessagePt);
        return;
      }
      setState(() {
        _loadingSnapshot = false;
        _snapshotErrorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSnapshot = false;
        _snapshotErrorBanner = e.toString();
      });
    }
  }

  Future<void> _refreshScreenSecurityStatus() async {
    final st = await widget.screenSecurityBridge.getProtectionStatus();
    if (!mounted) return;
    setState(() => _screenProtection = st);
    _syncCaptureCountdown(st);
  }

  void _syncCaptureCountdown(CeoScreenProtectionState st) {
    _captureCountdownTimer?.cancel();
    if (!st.temporaryCaptureAllowed) return;
    _captureCountdownTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      final next = await widget.screenSecurityBridge.getProtectionStatus();
      if (!mounted) return;
      setState(() => _screenProtection = next);
      if (!next.temporaryCaptureAllowed) {
        _captureCountdownTimer?.cancel();
      }
    });
  }

  Future<void> _toggleTemporaryScreenCapture() async {
    HapticFeedback.mediumImpact();
    final allow = !_screenProtection.temporaryCaptureAllowed;
    final next = await widget.screenSecurityBridge.setTemporaryCaptureAllowed(
      allow: allow,
      durationSeconds: 300,
    );
    if (!mounted) return;
    setState(() => _screenProtection = next);
    _syncCaptureCountdown(next);
  }

  Future<void> _checkManualOtaUpdate() async {
    if (_checkingOta) return;
    setState(() {
      _checkingOta = true;
      _otaStatusMessage = null;
    });
    try {
      final svc = widget.updateService ?? FounderUpdateService();
      final info = await svc.check(forceManualCheck: true);
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _checkingOta = false;
          _otaStatusMessage =
              'Você já está executando a edição mais recente publicada no canal beta-latest.';
        });
      } else {
        setState(() {
          _checkingOta = false;
          _otaStatusMessage =
              'Nova versão v${info.version} (build ${info.build}) localizada! Abrindo download seguro…';
        });
        await FounderUpdateService.launchTrustedFounderApkDownload(info.apkUrl);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingOta = false;
        _otaStatusMessage =
            'Não foi possível consultar o GitHub Releases agora. Verifique a rede.';
      });
    }
  }

  void _openOrderForensics(String jobId, [String? orderCode]) {
    FounderOrderForensicSheet.show(
      context,
      repository: _repo,
      jobId: jobId,
      initialOrderCode: orderCode,
      privacyBlurActive: _privacyBlurActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return FounderAuthAndVaultGate(
        key: ValueKey<String>(
          'ceo-vault-gate-${_pinResetFlowRequested ? "reset" : "normal"}',
        ),
        repository: _repo,
        initialPinResetFlow: _pinResetFlowRequested,
        lockReasonBanner: _lockReasonBanner,
        onVaultUnlocked: _onVaultUnlocked,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopWide = constraints.maxWidth >= 960;
          return Scaffold(
            key: const ValueKey<String>('founder-cockpit-unlocked-scaffold'),
            backgroundColor: FounderSovereignTokens.obsidianBackground,
            extendBody: !isDesktopWide,
            body: SafeArea(
              bottom: isDesktopWide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isDesktopWide) _buildDesktopNavigationRail(),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _buildTopExecutiveHeader(isDesktopWide),
                        if (_transientLiveBanner != null)
                          _buildLiveArrivalBanner(_transientLiveBanner!),
                        if (_snapshotErrorBanner != null)
                          _buildSnapshotErrorBar(_snapshotErrorBanner!),
                        Expanded(
                          child: RefreshIndicator(
                            color: FounderSovereignTokens.imperialGoldBright,
                            backgroundColor:
                                FounderSovereignTokens.obsidianCard,
                            onRefresh: () => _refreshLiveSnapshot(),
                            child: StaggeredEntranceOrchestrator(
                              key: ValueKey<String>(
                                'tab-anim-$_selectedTabIndex-$_selectedWindowKey',
                              ),
                              builder: (context, anim) {
                                return _buildActiveTabBody(
                                  anim,
                                  bottomInset: isDesktopWide ? 24 : 104,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar:
                isDesktopWide ? null : _buildMobileFloatingGlassDock(),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // NAVEGAÇÃO ADAPTATIVA (RAIL DESKTOP >= 960PX / FLOATING GLASS DOCK MOBILE)
  // ===========================================================================

  Widget _buildDesktopNavigationRail() {
    return Container(
      width: 212,
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          right: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const FounderSovereignCrest(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Desperrengue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'CEO · COFRE SOBERANO',
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _kFiveTabs.length; i++) ...<Widget>[
            _buildRailItem(i, _kFiveTabs[i]),
            const SizedBox(height: 6),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'TITULAR MONOCRÁTICO',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kMonocraticCeoEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10.5,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, _NavTabSpec spec) {
    final active = _selectedTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('ceo-nav-tab-$index'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? FounderSovereignTokens.imperialGoldSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.65)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                spec.icon,
                size: 19,
                color: active
                    ? FounderSovereignTokens.imperialGoldBright
                    : FounderSovereignTokens.mutedInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? FounderSovereignTokens.primaryInk
                        : FounderSovereignTokens.mutedInk,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFloatingGlassDock() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color:
                    FounderSovereignTokens.obsidianSurface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: FounderSovereignTokens.imperialGold
                      .withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                children: List<Widget>.generate(_kFiveTabs.length, (i) {
                  final spec = _kFiveTabs[i];
                  final active = _selectedTabIndex == i;
                  return Expanded(
                    child: InkWell(
                      key: ValueKey<String>('ceo-nav-tab-$i'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            spec.icon,
                            size: 20,
                            color: active
                                ? FounderSovereignTokens.imperialGoldBright
                                : FounderSovereignTokens.mutedInk,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spec.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? FounderSovereignTokens.imperialGoldBright
                                  : FounderSovereignTokens.mutedInk,
                              fontSize: 10.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOPO SOBERANO + INDICADOR WSS TLS 1.3 + SELETOR DE PERÍODO
  // ===========================================================================

  Widget _buildTopExecutiveHeader(bool isDesktopWide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          bottom: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (!isDesktopWide) ...<Widget>[
                const FounderSovereignCrest(size: 32),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          isDesktopWide
                              ? 'Sala de Guerra Executiva · ${_kFiveTabs[_selectedTabIndex].label}'
                              : 'Desperrengue CEO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _buildRealtimeStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sincronizado: ${_formatShortBrt(_snapshot.generatedAt)} BRT · Seq #${_snapshot.latestEventSeq}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 10,
                        color: FounderSovereignTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey<String>('ceo-privacy-blur-toggle-btn'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                tooltip: _privacyBlurActive
                    ? 'Mostrar valores (Espaço)'
                    : 'Ocultar valores em público (Espaço)',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _privacyBlurActive = !_privacyBlurActive);
                },
                icon: Icon(
                  _privacyBlurActive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 19,
                  color: _privacyBlurActive
                      ? FounderSovereignTokens.imperialGoldBright
                      : FounderSovereignTokens.mutedInk,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('ceo-manual-refresh-btn'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                tooltip: 'Sincronizar banco real agora',
                onPressed: _loadingSnapshot ? null : () => _refreshLiveSnapshot(),
                icon: _loadingSnapshot
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        size: 19,
                        color: FounderSovereignTokens.mutedInk,
                      ),
              ),
              IconButton(
                key: const ValueKey<String>('ceo-lock-vault-btn'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                tooltip: 'Trancar Cofre Soberano (exige PIN)',
                onPressed: () => _lockVaultWithReason(
                  'Cofre trancado manualmente pelo titular.',
                ),
                icon: const Icon(
                  Icons.lock_rounded,
                  size: 19,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final opt in _kPeriodOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey<String>('ceo-period-${opt.key}'),
                      label: Text(opt.label),
                      selected: _selectedWindowKey == opt.key,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        _refreshLiveSnapshot(windowKey: opt.key);
                      },
                      selectedColor: FounderSovereignTokens.imperialGoldSoft,
                      backgroundColor: FounderSovereignTokens.obsidianCard,
                      side: BorderSide(
                        color: _selectedWindowKey == opt.key
                            ? FounderSovereignTokens.imperialGold
                            : FounderSovereignTokens.crispBorder,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedWindowKey == opt.key
                            ? FounderSovereignTokens.imperialGoldBright
                            : FounderSovereignTokens.mutedInk,
                        fontSize: 11,
                        fontWeight: _selectedWindowKey == opt.key
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeStatusBadge() {
    return ValueListenableBuilder<CeoRealtimeConnectionStatus>(
      valueListenable: _repo.realtimeStatusNotifier,
      builder: (context, status, _) {
        final (label, color) = switch (status) {
          CeoRealtimeConnectionStatus.liveConnected => (
              '● AO VIVO · WSS',
              FounderSovereignTokens.solvencyEmerald,
            ),
          CeoRealtimeConnectionStatus.connecting => (
              '● CONECTANDO…',
              FounderSovereignTokens.imperialGoldBright,
            ),
          CeoRealtimeConnectionStatus.reconnecting => (
              '● RECONECTANDO…',
              FounderSovereignTokens.warmAmber,
            ),
          CeoRealtimeConnectionStatus.disconnected => (
              '● OFFLINE',
              FounderSovereignTokens.mutedInk,
            ),
        };
        return Container(
          key: const ValueKey<String>('ceo-realtime-wss-pill'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveArrivalBanner(CeoLiveEventItem ev) {
    return Material(
      color: const Color(0xFF10281E),
      child: InkWell(
        onTap: ev.linkedJobId != null
            ? () => _openOrderForensics(ev.linkedJobId!)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: FounderSovereignTokens.solvencyEmerald
                    .withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.sensors_rounded,
                size: 16,
                color: FounderSovereignTokens.solvencyEmerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NOVO EVENTO #${ev.eventSeq}: ${ev.title} — ${ev.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ev.amountCents > 0)
                AnimatedMoneyOdometer(
                  cents: ev.amountCents,
                  privacyBlurActive: _privacyBlurActive,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotErrorBar(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: FounderSovereignTokens.crimsonAlertSoft,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: FounderSovereignTokens.crimsonAlert,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: FounderSovereignTokens.primaryInk,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _refreshLiveSnapshot(),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ROTEAMENTO DAS 5 ABAS EXECUTIVAS
  // ===========================================================================

  Widget _buildActiveTabBody(
    Animation<double> anim, {
    required double bottomInset,
  }) {
    final padding = EdgeInsets.fromLTRB(14, 14, 14, bottomInset);
    switch (_selectedTabIndex) {
      case 0:
        return ListView(
          key: const ValueKey<String>('ceo-tab-0-live-view'),
          padding: padding,
          children: _buildTab0LivePulse(anim),
        );
      case 1:
        return ListView(
          key: const ValueKey<String>('ceo-tab-1-caixa-view'),
          padding: padding,
          children: _buildTab1CaixaTreasury(anim),
        );
      case 2:
        return ListView(
          key: const ValueKey<String>('ceo-tab-2-operacoes-view'),
          padding: padding,
          children: _buildTab2OperacoesRadar(anim),
        );
      case 3:
        return ListView(
          key: const ValueKey<String>('ceo-tab-3-usuarios-view'),
          padding: padding,
          children: _buildTab3UsuariosComunidade(anim),
        );
      default:
        return ListView(
          key: const ValueKey<String>('ceo-tab-4-cofre-view'),
          padding: padding,
          children: _buildTab4CofreSeguranca(anim),
        );
    }
  }

  // ===========================================================================
  // ABA 0: ⚡ AO VIVO (HERO FINANCEIRO + CONTADORES REAIS + STREAM WSS)
  // ===========================================================================

  List<Widget> _buildTab0LivePulse(Animation<double> anim) {
    final dre = _snapshot.dreCents;
    final tr = _snapshot.treasury;
    final p = _snapshot.livePulse;
    final demo = _snapshot.demographics;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-hero-financial-pulse-card'),
          accentTopBarColor: FounderSovereignTokens.imperialGold,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'RECEITA BRUTA PLATAFORMA (13,5% + SOS)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _snapshot.reconciliation.threeWayReconciliationOk
                          ? FounderSovereignTokens.solvencyEmeraldSoft
                          : FounderSovereignTokens.crimsonAlertSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _snapshot.reconciliation.threeWayReconciliationOk
                          ? 'Conciliação Tripla Exata (0 centavos)'
                          : 'Divergência Contábil Detectada',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _snapshot.reconciliation.threeWayReconciliationOk
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.crimsonAlert,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedMoneyOdometer(
                key: const ValueKey<String>('ceo-hero-platform-revenue-odometer'),
                cents: dre.platformGrossRevenueCents,
                privacyBlurActive: _privacyBlurActive,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: FounderSovereignTokens.primaryInk,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: FounderSovereignTokens.crispBorder),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: <Widget>[
                  _buildHeroSubMetric(
                    label: 'GMV Transacionado Real',
                    cents: dre.gmvTotalCents,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                  _buildHeroSubMetric(
                    label: 'Custódia Total (Carteiras + Escrow)',
                    cents: tr.totalCustodyCents,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                  _buildHeroSubMetric(
                    label: 'Resultado Líquido Real (EBITDA)',
                    cents: dre.netProfitEbitdaCents,
                    color: dre.netProfitEbitdaCents >= 0
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.crimsonAlert,
                  ),
                  _buildHeroSubMetric(
                    label: 'Fundo Garantidor (1,5%)',
                    cents: _snapshot.actuarialPool.runningBalanceCents,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 720 ? 4 : 2;
            final spacing = 10.0;
            final cardW = (c.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: <Widget>[
                SizedBox(
                  width: cardW,
                  child: _LiveCounterTile(
                    title: 'Pedidos Ativos Agora',
                    value: '${p.activeOrdersTotalCount}',
                    subtitle:
                        '${p.awaitingQuoteOrPaymentCount} abertos · ${p.inExecutionPipelineCount} em curso',
                    accent: FounderSovereignTokens.imperialGoldBright,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _LiveCounterTile(
                    title: 'Serviços Concluídos',
                    value: '${p.completedAllTimeCount}',
                    subtitle:
                        '${dre.completedOrdersCount} concluídos na janela selecionada',
                    accent: FounderSovereignTokens.solvencyEmerald,
                    icon: Icons.task_alt_rounded,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _LiveCounterTile(
                    title: 'Comunidade Cadastrada',
                    value: '${demo.totalUsersCount}',
                    subtitle:
                        '${demo.totalActiveClients} clientes · ${demo.totalActiveProviders} prestadores',
                    accent: FounderSovereignTokens.cyberCyan,
                    icon: Icons.groups_rounded,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _LiveCounterTile(
                    title: 'Orçamentos & Avaliações',
                    value: '${p.quotesPendingCount} prop.',
                    subtitle: p.reviewsTotalCount > 0
                        ? 'Média real ${p.reviewsAvgStars.toStringAsFixed(2)}★ (${p.reviewsTotalCount})'
                        : '0 avaliações reveladas até agora',
                    accent: FounderSovereignTokens.warmAmber,
                    icon: Icons.star_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 2,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-live-activity-stream-card'),
          accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.stream_rounded,
                    size: 18,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Feed em Tempo Real do Desperrengue (${_snapshot.liveEvents.length})',
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada cadastro, pedido, orçamento, recarga PIX, custódia escrow, check-in GPS, NF-e, avaliação ou exclusão LGPD aparece instantaneamente aqui.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 12),
              if (_snapshot.liveEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Icon(
                        Icons.sensors_rounded,
                        size: 28,
                        color: FounderSovereignTokens.cyberCyan,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Escuta Criptografada Ativa — Aguardando Movimentação Real',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nenhum evento fictício é exibido. Assim que um cliente ou profissional agir no Desperrengue, o registro aparecerá em tempo real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: <Widget>[
                    for (final ev in _snapshot.liveEvents.take(40))
                      _buildLiveEventRow(ev),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildHeroSubMetric({
    required String label,
    required int cents,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedMoneyOdometer(
          cents: cents,
          privacyBlurActive: _privacyBlurActive,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveEventRow(CeoLiveEventItem ev) {
    final sevColor = switch (ev.severity.toUpperCase()) {
      'CRITICAL' => FounderSovereignTokens.crimsonAlert,
      'WARN' => FounderSovereignTokens.warmAmber,
      'FINANCE' || 'SUCCESS' => FounderSovereignTokens.solvencyEmerald,
      _ => FounderSovereignTokens.cyberCyan,
    };
    final jobId = ev.linkedJobId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: jobId != null ? () => _openOrderForensics(jobId) : null,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sevColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: sevColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            ev.title,
                            style: const TextStyle(
                              color: FounderSovereignTokens.primaryInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '#${ev.eventSeq} · ${_formatShortBrt(ev.occurredAt)}',
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 10,
                              color: FounderSovereignTokens.mutedInk,
                            ),
                          ),
                        ],
                      ),
                      if (ev.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          ev.subtitle,
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ev.amountCents > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  AnimatedMoneyOdometer(
                    cents: ev.amountCents,
                    privacyBlurActive: _privacyBlurActive,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                ],
                if (jobId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ABA 1: 🏛️ CAIXA (CONCILIAÇÃO TRIPLA + DRE REAL + DESPESAS + PDF CPC 47)
  // ===========================================================================

  List<Widget> _buildTab1CaixaTreasury(Animation<double> anim) {
    final recon = _snapshot.reconciliation;
    final dre = _snapshot.dreCents;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-three-way-reconciliation-card'),
          accentTopBarColor: recon.threeWayReconciliationOk
              ? FounderSovereignTokens.solvencyEmerald
              : FounderSovereignTokens.crimsonAlert,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Conciliação Tripla de Custódia (Precisão de 1 Centavo)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    recon.threeWayReconciliationOk
                        ? 'ÍNTEGRA · DIVERGÊNCIA R\$ 0,00'
                        : 'ALERTA · DIVERGÊNCIA ${Money.formatBrl(recon.discrepancyCents)}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: recon.threeWayReconciliationOk
                          ? FounderSovereignTokens.solvencyEmerald
                          : FounderSovereignTokens.crimsonAlert,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: <Widget>[
                  _buildHeroSubMetric(
                    label: '1. PIX Confirmados',
                    cents: recon.pixTopupsConfirmedCents,
                    color: FounderSovereignTokens.primaryInk,
                  ),
                  _buildHeroSubMetric(
                    label: '2. Soma Líquida Razão (Ledger)',
                    cents: recon.ledgerNetSumCents,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                  _buildHeroSubMetric(
                    label: '3. Carteiras + Custódia Escrow',
                    cents: recon.walletsAndEscrowTotalCents,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-real-dre-card'),
          accentTopBarColor: FounderSovereignTokens.imperialGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'DRE Real Smart Split (CPC 47 / Simples Anexo III)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey<String>('ceo-open-real-expense-modal-btn'),
                    onPressed: () async {
                      await FounderRealExpenseModal.show(
                        context,
                        repository: _repo,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Registrar Despesa Real',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDreLine(
                '(+) GMV Bruto Liquidado (${dre.completedOrdersCount} OS)',
                dre.gmvTotalCents,
                FounderSovereignTokens.primaryInk,
              ),
              _buildDreLine(
                '(-) Repasse Direto 85% Mão de Obra Profissionais',
                -dre.providerNetLaborCents,
                FounderSovereignTokens.mutedInk,
              ),
              _buildDreLine(
                '(-) Reembolso Integral Peças Isentas (0% Taxa)',
                -dre.materialsExemptCents,
                FounderSovereignTokens.cyberCyan,
              ),
              _buildDreLine(
                '(-) Destinação Vinculada Fundo Garantidor (1,5%)',
                -dre.warrantyPoolCarveoutCents,
                FounderSovereignTokens.warmAmber,
              ),
              const Divider(height: 16, color: FounderSovereignTokens.crispBorder),
              _buildDreLine(
                '(=) Receita Bruta Tributável Plataforma (13,5% + SOS)',
                dre.platformGrossRevenueCents,
                FounderSovereignTokens.imperialGoldBright,
                bold: true,
              ),
              _buildDreLine(
                '(-) Simples Nacional DAS (6,00% sobre Receita App)',
                -dre.simplesNacionalTaxCents,
                FounderSovereignTokens.crimsonAlert,
              ),
              _buildDreLine(
                '(-) Despesas Variáveis Reais (PSP / Cloud)',
                -dre.variablePspAndCloudCents,
                FounderSovereignTokens.mutedInk,
              ),
              _buildDreLine(
                '(=) Margem de Contribuição Real',
                dre.contributionMarginCents,
                FounderSovereignTokens.primaryInk,
                bold: true,
              ),
              _buildDreLine(
                '(-) Despesas Operacionais Fixas Reais (OPEX)',
                -dre.fixedOpexCents,
                FounderSovereignTokens.mutedInk,
              ),
              const Divider(height: 16, color: FounderSovereignTokens.crispBorder),
              _buildDreLine(
                '(=) Resultado Operacional Líquido Real (EBITDA)',
                dre.netProfitEbitdaCents,
                dre.netProfitEbitdaCents >= 0
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.crimsonAlert,
                bold: true,
              ),
              if (_snapshot.realExpenses.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Despesas Reais Lançadas na Janela (${_snapshot.realExpenses.length})',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final exp in _snapshot.realExpenses)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: FounderSovereignTokens.crispBorder),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${exp.competenceDateIso} · ${exp.kindLabelPt} · ${exp.category}'
                            '${exp.description.isNotEmpty ? " (${exp.description})" : ""}',
                            style: const TextStyle(
                              color: FounderSovereignTokens.primaryInk,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        AnimatedMoneyOdometer(
                          cents: exp.amountCents,
                          privacyBlurActive: _privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.crimsonAlert,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover lançamento',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _repo.deleteRealExpense(exp.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      FounderSankeyMoneyFlowChart(
        dre: dre,
        animation: anim,
        privacyBlurActive: _privacyBlurActive,
      ),
      if (_snapshot.dailySeries.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        FounderJCurveBreakEvenChart(
          dailySeries: _snapshot.dailySeries,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        ),
      ],
      const SizedBox(height: 12),
      FounderTreasuryEscrowHistogramChart(
        treasury: _snapshot.treasury,
        animation: anim,
        privacyBlurActive: _privacyBlurActive,
      ),
      const SizedBox(height: 12),
      FounderActuarialSpeedometerChart(
        pool: _snapshot.actuarialPool,
        animation: anim,
        privacyBlurActive: _privacyBlurActive,
      ),
      const SizedBox(height: 12),
      FounderAccountantPackExporterWidget(snapshot: _snapshot),
    ];
  }

  Widget _buildDreLine(
    String label,
    int signedCents,
    Color color, {
    bool bold = false,
  }) {
    final prefix = signedCents < 0 ? '- ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.mutedInk,
                fontSize: bold ? 12.5 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedMoneyOdometer(
            cents: signedCents.abs(),
            prefix: prefix,
            privacyBlurActive: _privacyBlurActive,
            style: FounderSovereignTokens.monoMetric(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ABA 2: 🧭 OPERAÇÕES (RADAR CARTOGRÁFICO + ORDENS REAIS + BAIRROS + 33 CATS)
  // ===========================================================================

  List<Widget> _buildTab2OperacoesRadar(Animation<double> anim) {
    final filteredOrders = _snapshot.recentOrdersMicroPnl.where((o) {
      switch (_ordersStatusFilter) {
        case 'execution':
          return o.status == 'in_progress' || o.status == 'awaiting_approval';
        case 'scheduled':
          return o.status == 'scheduled';
        case 'open':
          return o.status == 'open' || o.status == 'awaiting_payment';
        case 'completed':
          return o.status == 'completed';
        case 'disputed':
          return o.status == 'disputed';
        default:
          return true;
      }
    }).toList(growable: false);

    final sortedCats = List<CategoryLiquidityPoint>.from(
      _snapshot.categoryLiquidity,
    )..sort((a, b) {
        final cmp = b.demandCount.compareTo(a.demandCount);
        if (cmp != 0) return cmp;
        return b.activeProvidersCount.compareTo(a.activeProvidersCount);
      });
    final activeCats = sortedCats
        .where((c) => c.demandCount > 0 || c.activeProvidersCount > 0)
        .toList(growable: false);
    final displayedCats = _showAll33Categories
        ? sortedCats
        : (activeCats.isNotEmpty ? activeCats : sortedCats.take(8).toList());

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderLiveGeoRadarCard(
          points: _snapshot.liveMapPoints,
          privacyBlurActive: _privacyBlurActive,
          onInspectOrder: (jobId, code) => _openOrderForensics(jobId, code),
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-real-orders-pipeline-card'),
          accentTopBarColor: FounderSovereignTokens.imperialGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Esteira Real de Pedidos & Micro-P&L (${filteredOrders.length})',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildOrderFilterChip(
                      'all',
                      'Todos (${_snapshot.recentOrdersMicroPnl.length})',
                    ),
                    const SizedBox(width: 6),
                    _buildOrderFilterChip('open', 'Abertos / PIX'),
                    const SizedBox(width: 6),
                    _buildOrderFilterChip('scheduled', 'Agendados'),
                    const SizedBox(width: 6),
                    _buildOrderFilterChip('execution', 'Em Execução'),
                    const SizedBox(width: 6),
                    _buildOrderFilterChip('completed', 'Concluídos'),
                    const SizedBox(width: 6),
                    _buildOrderFilterChip('disputed', 'Mediação'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filteredOrders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: const Text(
                    'Nenhum pedido real registrado nesta etapa até o momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FounderSovereignTokens.mutedInk,
                      fontSize: 12.5,
                    ),
                  ),
                )
              else
                Column(
                  children: <Widget>[
                    for (final o in filteredOrders.take(30))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: FounderSovereignTokens.obsidianSurface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                _openOrderForensics(o.jobId, o.orderCode),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: founderStatusColor(o.status)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              o.orderCode,
                                              style: FounderSovereignTokens
                                                  .monoMetric(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: founderStatusColor(
                                                  o.status,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              founderStatusLabelPt(o.status),
                                              style: TextStyle(
                                                color: founderStatusColor(
                                                  o.status,
                                                ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '· ${o.categoryName}',
                                              style: const TextStyle(
                                                color: FounderSovereignTokens
                                                    .primaryInk,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${o.title} · ${o.neighborhood} · Cliente: ${o.clientName}'
                                          '${o.providerName != null ? " · Prestador: ${o.providerName}" : " · (${o.quotesCount} propostas)"}',
                                          style: const TextStyle(
                                            color:
                                                FounderSovereignTokens.mutedInk,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      AnimatedMoneyOdometer(
                                        cents: o.gmvCents,
                                        privacyBlurActive: _privacyBlurActive,
                                        style:
                                            FounderSovereignTokens.monoMetric(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: FounderSovereignTokens
                                              .imperialGoldBright,
                                        ),
                                      ),
                                      Text(
                                        'Receita App: ${_privacyBlurActive ? "•••" : Money.formatBrl(o.platformFeeCents)}',
                                        style:
                                            FounderSovereignTokens.monoMetric(
                                          fontSize: 10,
                                          color: FounderSovereignTokens
                                              .solvencyEmerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: FounderSovereignTokens.mutedInk,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      if (_snapshot.neighborhoodHeatmap.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        FounderNeighborhoodBivariateHeatmapWidget(
          snapshot: _snapshot,
          privacyBlurActive: _privacyBlurActive,
        ),
      ],
      const SizedBox(height: 12),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-33-categories-liquidity-card'),
        accentTopBarColor: FounderSovereignTokens.cyberCyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Matriz Real das 33 Categorias Oficiais (Demanda × Oferta)',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _showAll33Categories = !_showAll33Categories,
                  ),
                  child: Text(
                    _showAll33Categories
                        ? 'Recolher lista'
                        : 'Ver todas as 33 categorias',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final c in displayedCats)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      c.categoryName,
                      style: const TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          'Demanda: ${c.demandCount} · Prestadores: ${c.activeProvidersCount}',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 11,
                            color: c.isSupplyBottleneck
                                ? FounderSovereignTokens.crimsonAlert
                                : FounderSovereignTokens.mutedInk,
                          ),
                        ),
                        AnimatedMoneyOdometer(
                          cents: c.avgTicketCents,
                          privacyBlurActive: _privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 11.5,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildOrderFilterChip(String code, String label) {
    final active = _ordersStatusFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _ordersStatusFilter = code),
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 11.5,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  // ===========================================================================
  // ABA 3: 👥 USUÁRIOS (PARTIÇÃO 5 ESTADOS + DIRETÓRIO CRM + REVIEWS + FUNIL)
  // ===========================================================================

  List<Widget> _buildTab3UsuariosComunidade(Animation<double> anim) {
    final d = _snapshot.demographics;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-demographics-partition-card'),
          accentTopBarColor: FounderSovereignTokens.cyberCyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Partição Real de Contas (${d.totalUsersCount} perfis ativos)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    d.partitionInvariantOk
                        ? 'Soma Exata 100% Auditada'
                        : 'Revisar Partição',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: <Widget>[
                  _MiniStatBadge(
                    'Só Clientes',
                    '${d.onlyClientsCount}',
                    FounderSovereignTokens.warmAmber,
                  ),
                  _MiniStatBadge(
                    'Só Prestadores',
                    '${d.onlyProvidersCount}',
                    FounderSovereignTokens.cyberCyan,
                  ),
                  _MiniStatBadge(
                    'Modo Híbrido (Ambos)',
                    '${d.dualModeBothCount}',
                    FounderSovereignTokens.imperialGoldBright,
                  ),
                  _MiniStatBadge(
                    'Em Onboarding',
                    '${d.onboardingIncompleteCount}',
                    FounderSovereignTokens.mutedInk,
                  ),
                  _MiniStatBadge(
                    'KYC Verificado',
                    '${d.kycVerifiedCount}',
                    FounderSovereignTokens.solvencyEmerald,
                  ),
                  _MiniStatBadge(
                    'KYC Pendente',
                    '${d.kycPendingCount}',
                    FounderSovereignTokens.warmAmber,
                  ),
                  _MiniStatBadge(
                    'Exclusões LGPD',
                    '${d.totalLgpdOffboardings}',
                    FounderSovereignTokens.crimsonAlert,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderUsersCrmDirectoryCard(
          repository: _repo,
          privacyBlurActive: _privacyBlurActive,
        ),
      ),
      const SizedBox(height: 12),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-real-conversion-funnel-card'),
        accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Funil Real de Conversão da Plataforma',
              style: FounderSovereignTokens.monoMetric(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (_snapshot.realConversionFunnel.isEmpty)
              const Text(
                'Sem etapas contabilizadas ainda no banco real.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12,
                ),
              )
            else
              for (final st in _snapshot.realConversionFunnel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          st.label,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        '${st.usersCount}',
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      if (_snapshot.cohortRetention.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        FounderCohortRetentionHeatmapChart(
          cohorts: _snapshot.cohortRetention,
          animation: anim,
        ),
      ],
      const SizedBox(height: 12),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-real-reviews-feed-card'),
        accentTopBarColor: FounderSovereignTokens.imperialGold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Avaliações Reais Reveladas (${_snapshot.recentReviews.length})',
              style: FounderSovereignTokens.monoMetric(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_snapshot.recentReviews.isEmpty)
              const Text(
                'Nenhuma avaliação bilateral revelada até o momento.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12,
                ),
              )
            else
              for (final rev in _snapshot.recentReviews.take(15))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${rev.rating}★ · ${rev.reviewerName} -> ${rev.revieweeName} (${rev.categoryName})',
                        style: const TextStyle(
                          color: FounderSovereignTokens.imperialGoldBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (rev.comment.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          rev.comment,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
    ];
  }

  // ===========================================================================
  // ABA 4: 🔐 COFRE (MONOCRÁTICO + PIN SHA-256 + FLAG_SECURE + OTA + WORM)
  // ===========================================================================

  List<Widget> _buildTab4CofreSeguranca(Animation<double> anim) {
    final vm = _snapshot.vaultMetadata;
    final sw = _snapshot.securityWatch;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-monocratic-passport-card'),
          accentTopBarColor: FounderSovereignTokens.imperialGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const FounderSovereignCrest(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Passaporte Soberano Monocrático',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vm.ownerEmail,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 12.5,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  const _MiniStatBadge(
                    'Delegados Autorizados',
                    '0 (Proibido)',
                    FounderSovereignTokens.solvencyEmerald,
                  ),
                  _MiniStatBadge(
                    'Algoritmo PIN',
                    vm.pinAlgoVersion,
                    FounderSovereignTokens.cyberCyan,
                  ),
                  _MiniStatBadge(
                    'Vazamento Geo-Privacidade',
                    '${sw.geoPrivacyLeakBps} bps (0,00%)',
                    FounderSovereignTokens.solvencyEmerald,
                  ),
                  _MiniStatBadge(
                    'Cadeia WORM SHA-256',
                    sw.auditChainIntact ? 'ÍNTEGRA' : 'ALERTA',
                    sw.auditChainIntact
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.crimsonAlert,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    key: const ValueKey<String>('ceo-reset-personal-pin-btn'),
                    onPressed: () => _lockVaultWithReason(
                      'Valide o código de 6 dígitos enviado para $kMonocraticCeoEmail para cadastrar seu novo PIN.',
                      pinReset: true,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF111827),
                    ),
                    icon: const Icon(Icons.password_rounded, size: 16),
                    label: const Text(
                      'Redefinir Meu PIN Pessoal (E-mail 6 Dígitos)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('ceo-signout-primary-btn'),
                    onPressed: () async {
                      await _repo.signOutAndLock();
                      if (!mounted) return;
                      setState(() {
                        _session = null;
                        _lockReasonBanner =
                            'Sessão primária encerrada com segurança.';
                      });
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Encerrar Sessão Completa'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-flag-secure-and-ota-card'),
          accentTopBarColor: FounderSovereignTokens.cyberCyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Blindagem Óptica (FLAG_SECURE) & Atualização Direta (OTA)',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _screenProtection.temporaryCaptureAllowed
                    ? 'Captura temporária liberada (${_screenProtection.remainingCaptureSeconds}s restantes antes da reativação automática do bloqueio).'
                    : 'FLAG_SECURE ATIVO: prints de tela, gravações e miniatura de apps recentes estão bloqueados no Android.',
                style: TextStyle(
                  color: _screenProtection.temporaryCaptureAllowed
                      ? FounderSovereignTokens.warmAmber
                      : FounderSovereignTokens.solvencyEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('ceo-toggle-flag-secure-btn'),
                    onPressed: _toggleTemporaryScreenCapture,
                    icon: Icon(
                      _screenProtection.temporaryCaptureAllowed
                          ? Icons.lock_rounded
                          : Icons.screenshot_monitor_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _screenProtection.temporaryCaptureAllowed
                          ? 'Reativar FLAG_SECURE Agora'
                          : 'Permitir Captura por 5 min',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>('ceo-manual-ota-check-btn'),
                    onPressed: _checkingOta ? null : _checkManualOtaUpdate,
                    icon: const Icon(Icons.system_update_rounded, size: 16),
                    label: Text(
                      _checkingOta
                          ? 'Consultando beta-latest…'
                          : 'Verificar Atualização do APK CEO',
                    ),
                  ),
                ],
              ),
              if (_otaStatusMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _otaStatusMessage!,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-trusted-devices-card'),
        accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Aparelhos Vinculados por Código de 6 Dígitos (${_snapshot.trustedDevices.length})',
              style: FounderSovereignTokens.monoMetric(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_snapshot.trustedDevices.isEmpty)
              const Text(
                'Nenhum aparelho listado.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12,
                ),
              )
            else
              for (final dev in _snapshot.trustedDevices)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dev.isCurrentDevice
                          ? FounderSovereignTokens.solvencyEmerald
                          : FounderSovereignTokens.crispBorder,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: FounderSovereignTokens.cyberCyan,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${dev.deviceLabel}${dev.isCurrentDevice ? " · (Este Aparelho)" : ""}',
                              style: const TextStyle(
                                color: FounderSovereignTokens.primaryInk,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'SHA-256: ${dev.fingerprintPrefix}… · Último acesso: ${_formatShortBrt(dev.lastSeenAt)}',
                              style: FounderSovereignTokens.monoMetric(
                                fontSize: 10.5,
                                color: FounderSovereignTokens.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!dev.isCurrentDevice)
                        TextButton(
                          onPressed: () =>
                              _repo.revokeTrustedDevice(dev.deviceId),
                          child: const Text(
                            'Revogar',
                            style: TextStyle(
                              color: FounderSovereignTokens.crimsonAlert,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FounderSilentDuressWarRoomWidget(securityWatch: sw),
      const SizedBox(height: 12),
      FounderAntiBypassAndSefazRadarWidget(securityWatch: sw),
      const SizedBox(height: 12),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-worm-audit-log-card'),
        accentTopBarColor: sw.intrusionCanariesCount > 0
            ? FounderSovereignTokens.crimsonAlert
            : FounderSovereignTokens.cyberCyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Trilha Forense WORM SHA-256 (${_snapshot.recentAuditLog.length} eventos recentes · ${sw.intrusionCanariesCount} canários)',
              style: FounderSovereignTokens.monoMetric(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_snapshot.recentAuditLog.isEmpty)
              const Text(
                'Nenhum evento registrado na trilha forense ainda.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12,
                ),
              )
            else
              for (final a in _snapshot.recentAuditLog.take(25))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: a.isIntrusionCanary
                          ? FounderSovereignTokens.crimsonAlertSoft
                          : FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: a.isIntrusionCanary
                            ? FounderSovereignTokens.crimsonAlert
                            : FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '#${a.id} · ${a.eventCode} · ${_formatShortBrt(a.createdAt)}',
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: a.isIntrusionCanary
                                  ? FounderSovereignTokens.crimsonAlert
                                  : FounderSovereignTokens.primaryInk,
                            ),
                          ),
                        ),
                        Text(
                          a.rowHash.length >= 12
                              ? '${a.rowHash.substring(0, 12)}…'
                              : a.rowHash,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 10,
                            color: FounderSovereignTokens.cyberCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    ];
  }
}

class _LiveCounterTile extends StatelessWidget {
  const _LiveCounterTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      padding: const EdgeInsets.all(14),
      accentTopBarColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: FounderSovereignTokens.primaryInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FounderSovereignTokens.mutedInk,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  const _MiniStatBadge(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: FounderSovereignTokens.mutedInk,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

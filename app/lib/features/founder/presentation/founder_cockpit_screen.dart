import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/money.dart';
import '../data/founder_cockpit_repository.dart';
import '../domain/founder_deep_link_policy.dart';
import 'founder_animations_and_shaders.dart';
import 'founder_auth_and_vault_gate.dart';
import 'founder_ceo_profile_sheet.dart';
import 'founder_charts_painters.dart';
import 'founder_deep_link_coordinator.dart';
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
  _PeriodOption('7d', '7 dias'),
  _PeriodOption('30d', '30 dias'),
  _PeriodOption('90d', '90 dias'),
  _PeriodOption('365d', '1 ano'),
  _PeriodOption('all', 'Tudo'),
];

class _NavTabSpec {
  const _NavTabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<_NavTabSpec> _kFiveTabs = <_NavTabSpec>[
  _NavTabSpec('Início', Icons.home_rounded),
  _NavTabSpec('Financeiro', Icons.account_balance_wallet_rounded),
  _NavTabSpec('Pedidos', Icons.assignment_rounded),
  _NavTabSpec('Pessoas', Icons.people_alt_rounded),
  _NavTabSpec('Conta', Icons.person_rounded),
];

String _formatHumanTimeBrt(DateTime? utc) {
  if (utc == null) return '—';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final nowBrt = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  final hh = brt.hour.toString().padLeft(2, '0');
  final min = brt.minute.toString().padLeft(2, '0');
  if (brt.year == nowBrt.year &&
      brt.month == nowBrt.month &&
      brt.day == nowBrt.day) {
    return 'hoje às $hh:$min';
  }
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  return '$dd/$mm às $hh:$min';
}

String _humanizeAuditEventCode(String rawCode) {
  final upper = rawCode.trim().toUpperCase();
  if (upper.contains('INTRUSION') || upper.contains('UNAUTHORIZED')) {
    return 'Tentativa bloqueada de outro e-mail';
  }
  if (upper.contains('PASSWORD') || upper.contains('PIN_ROTATED')) {
    return 'Senha de acesso atualizada';
  }
  if (upper.contains('OTP')) {
    return 'Código de 6 dígitos enviado por e-mail';
  }
  if (upper.contains('UNLOCK') || upper.contains('LOGIN')) {
    return 'Entrada confirmada no aplicativo';
  }
  if (upper.contains('DEVICE')) {
    return 'Aparelho verificado na conta';
  }
  if (upper.contains('EXPENSE')) {
    return 'Gasto da empresa registrado';
  }
  if (upper.contains('LOCK') || upper.contains('SIGNOUT')) {
    return 'Aplicativo bloqueado com segurança';
  }
  return rawCode.replaceAll('_', ' ').toLowerCase();
}

({IconData icon, Color color, String category}) _classifyLiveEvent(
  CeoLiveEventItem ev,
) {
  final text =
      '${ev.eventType} ${ev.title} ${ev.subtitle}'.toLowerCase();
  if (ev.severity.toUpperCase() == 'CRITICAL') {
    return (
      icon: Icons.warning_amber_rounded,
      color: FounderSovereignTokens.crimsonAlert,
      category: 'orders',
    );
  }
  if (ev.amountCents > 0 ||
      text.contains('pix') ||
      text.contains('pag') ||
      text.contains('saque') ||
      text.contains('repasse') ||
      text.contains('escrow') ||
      text.contains('carteira')) {
    return (
      icon: Icons.payments_rounded,
      color: FounderSovereignTokens.solvencyEmerald,
      category: 'payments',
    );
  }
  if (text.contains('cadastr') ||
      text.contains('perfil') ||
      text.contains('kyc') ||
      text.contains('usuário') ||
      text.contains('documento') ||
      text.contains('conta')) {
    return (
      icon: Icons.person_add_alt_1_rounded,
      color: FounderSovereignTokens.cyberCyan,
      category: 'people',
    );
  }
  if (text.contains('avalia') || text.contains('nota') || text.contains('★')) {
    return (
      icon: Icons.star_rounded,
      color: FounderSovereignTokens.imperialGoldBright,
      category: 'orders',
    );
  }
  return (
    icon: Icons.handyman_rounded,
    color: FounderSovereignTokens.imperialGoldBright,
    category: 'orders',
  );
}

/// Painel Executivo em Tempo Real do `Desperrengue CEO`.
///
/// Princípios inegociáveis:
/// - **Zero dados falsos (`Zero-Fake Policy`)**: 100% alimentado pelas tabelas reais
///   do `Desperrengue` em tempo real.
/// - **Exclusividade Monocrática**: acesso único de `wagneroliveira2395@gmail.com`.
/// - **Luxo Silencioso Executivo**: zero poluição visual e linguagem 100% clara.
class FounderCockpitScreen extends StatefulWidget {
  const FounderCockpitScreen({
    super.key,
    this.repository,
    this.updateService,
    this.deepLinkCoordinator,
    this.screenSecurityBridge = const CeoScreenSecurityBridge(),
    this.inactivityLockTimeout = const Duration(minutes: 10),
    this.backgroundLockTimeout = const Duration(minutes: 5),
  });

  final FounderCockpitRepository? repository;
  final FounderUpdateService? updateService;
  final FounderDeepLinkCoordinator? deepLinkCoordinator;
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
  late final FounderDeepLinkCoordinator _deepLinks;
  late final bool _ownsDeepLinks;

  StreamSubscription<FounderDashboardSnapshot>? _snapshotSub;
  StreamSubscription<CeoLiveEventItem>? _liveEventSub;
  Timer? _inactivityTimer;
  Timer? _captureCountdownTimer;
  Timer? _liveBannerTimer;
  DateTime? _pausedAtUtc;

  FounderStepUpSession? _session;
  FounderResetLinkGrant? _pendingResetGrant;
  FounderDashboardSnapshot _snapshot = FounderDashboardSnapshot.emptyZero();

  int _selectedTabIndex = 0;
  String _selectedWindowKey = '30d';
  String _liveFeedFilter = 'all';
  String _ordersStatusFilter = 'all';
  int _operationsSubView = 0; // 0 = Serviços e Mapa, 1 = Bairros e Profissões
  bool _showAll33Categories = false;
  bool _showReconciliationProof = false;
  bool _showAdvancedFinanceCharts = false;
  bool _showPeopleJourneyDetails = false;
  bool _showSecurityAuditDetails = false;
  bool _privacyBlurActive = false;
  bool _loadingSnapshot = false;
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
    _ownsDeepLinks = widget.deepLinkCoordinator == null;
    _deepLinks = widget.deepLinkCoordinator ?? FounderDeepLinkCoordinator();
    _session = _repo.activeStepUpSession;
    _snapshot = _repo.currentSnapshot;

    _deepLinks.pendingResetGrant.addListener(_onDeepLinkResetGrantChanged);
    unawaited(_deepLinks.start());

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

  void _onDeepLinkResetGrantChanged() {
    final grant = _deepLinks.pendingResetGrant.value;
    if (!mounted || grant == null) return;
    _inactivityTimer?.cancel();
    Navigator.maybeOf(context)?.popUntil((route) => route.isFirst);
    unawaited(_repo.lockVault());
    setState(() {
      _session = null;
      _pendingResetGrant = grant;
      _lockReasonBanner = null;
      _transientLiveBanner = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _deepLinks.pendingResetGrant.removeListener(_onDeepLinkResetGrantChanged);
    if (_ownsDeepLinks) {
      _deepLinks.dispose();
    }
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
            'Acesso bloqueado por segurança após período em segundo plano.',
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
          'Acesso bloqueado automaticamente por inatividade.',
        ),
      );
    });
  }

  Future<void> _lockVaultWithReason(String? reason) async {
    _inactivityTimer?.cancel();
    await _repo.lockVault();
    if (!mounted) return;
    setState(() {
      _session = null;
      _lockReasonBanner = reason;
      _transientLiveBanner = null;
    });
  }

  Future<void> _onVaultUnlocked(FounderStepUpSession unlockedSession) async {
    if (!mounted) return;
    setState(() {
      _session = unlockedSession;
      _pendingResetGrant = null;
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
      final gateCtrl = FounderUpdateGate.maybeOf(context);
      final FounderUpdateInfo? info;
      if (gateCtrl != null && widget.updateService == null) {
        info = await gateCtrl.checkNowAndPrompt(autoStartInstall: true);
      } else {
        final svc = widget.updateService ?? FounderUpdateService();
        info = await svc.check(forceManualCheck: true);
        if (info != null && mounted) {
          final directInstaller = FounderNativeOtaInstaller();
          try {
            await directInstaller.downloadAndInstall(info);
          } finally {
            directInstaller.dispose();
          }
        }
      }
      if (!mounted) return;
      final resolved = info;
      if (resolved == null) {
        setState(() {
          _checkingOta = false;
          _otaStatusMessage =
              'Seu aplicativo já está atualizado na versão mais recente.';
        });
      } else {
        setState(() {
          _checkingOta = false;
          _otaStatusMessage =
              'Nova versão v${resolved.version} encontrada! Baixando e abrindo instalador…';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingOta = false;
        _otaStatusMessage =
            'Não foi possível verificar atualizações agora. Confira sua internet.';
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
        key: const ValueKey<String>('ceo-vault-gate'),
        repository: _repo,
        pendingResetGrant: _pendingResetGrant,
        onResetGrantConsumed: () {
          _deepLinks.clearPendingGrant();
          if (mounted) {
            setState(() => _pendingResetGrant = null);
          }
        },
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
                                  bottomInset: isDesktopWide ? 28 : 108,
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
  // NAVEGAÇÃO LIMPA (RAIL DESKTOP >= 960PX / DOCK FLUTUANTE MOBILE)
  // ===========================================================================

  Widget _buildDesktopNavigationRail() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          right: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
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
                    Text(
                      'Desperrengue CEO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.titleStyle(fontSize: 15),
                    ),
                    const Text(
                      'Painel da direção',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: FounderSovereignTokens.imperialGoldBright,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _kFiveTabs.length; i++) ...<Widget>[
            _buildRailItem(i, _kFiveTabs[i]),
            const SizedBox(height: 6),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Único acesso autorizado',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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
                  ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.5)
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
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface
                    .withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              spec.icon,
                              size: 21,
                              color: active
                                  ? FounderSovereignTokens.imperialGoldBright
                                  : FounderSovereignTokens.mutedInk,
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                spec.label,
                                maxLines: 1,
                                style: TextStyle(
                                  color: active
                                      ? FounderSovereignTokens
                                          .imperialGoldBright
                                      : FounderSovereignTokens.mutedInk,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
  // CABEÇALHO MINIMALISTA EXECUTIVO
  // ===========================================================================

  Widget _buildTopExecutiveHeader(bool isDesktopWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          bottom: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!isDesktopWide) ...<Widget>[
            const FounderSovereignCrest(size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      isDesktopWide
                          ? 'Olá, Wagner · ${_kFiveTabs[_selectedTabIndex].label}'
                          : 'Olá, Wagner',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                    _buildRealtimeStatusBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _loadingSnapshot
                      ? 'Atualizando números…'
                      : 'Atualizado ${_formatHumanTimeBrt(_snapshot.generatedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
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
            padding: const EdgeInsets.all(5),
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
          if (isDesktopWide)
            IconButton(
              key: const ValueKey<String>('ceo-manual-refresh-btn'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: const EdgeInsets.all(5),
              tooltip: 'Atualizar agora',
              onPressed:
                  _loadingSnapshot ? null : () => _refreshLiveSnapshot(),
              icon: _loadingSnapshot
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 19,
                      color: FounderSovereignTokens.mutedInk,
                    ),
            ),
          IconButton(
            key: const ValueKey<String>('ceo-header-profile-btn'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.all(5),
            tooltip: 'Minha conta e senha',
            onPressed: () {
              HapticFeedback.selectionClick();
              FounderCeoProfileSheet.show(
                context,
                repository: _repo,
                vaultMetadata: _snapshot.vaultMetadata,
                onSignOutComplete: () async {
                  await _repo.signOutAndLock();
                  if (!mounted) return;
                  setState(() {
                    _session = null;
                    _lockReasonBanner = 'Você saiu da sua conta com segurança.';
                  });
                },
              );
            },
            icon: const Icon(
              Icons.manage_accounts_rounded,
              size: 20,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
          IconButton(
            key: const ValueKey<String>('ceo-lock-vault-btn'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.all(5),
            tooltip: 'Bloquear aplicativo agora',
            onPressed: () => _lockVaultWithReason(
              'Aplicativo bloqueado manualmente por você.',
            ),
            icon: const Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: FounderSovereignTokens.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualPeriodBar() {
    return SingleChildScrollView(
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
                  fontSize: 12,
                  fontWeight: _selectedWindowKey == opt.key
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                visualDensity: VisualDensity.compact,
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
              '● Em tempo real',
              FounderSovereignTokens.solvencyEmerald,
            ),
          CeoRealtimeConnectionStatus.connecting => (
              '● Conectando…',
              FounderSovereignTokens.imperialGoldBright,
            ),
          CeoRealtimeConnectionStatus.reconnecting => (
              '● Reconectando…',
              FounderSovereignTokens.warmAmber,
            ),
          CeoRealtimeConnectionStatus.disconnected => (
              '● Sem conexão',
              FounderSovereignTokens.mutedInk,
            ),
        };
        return Container(
          key: const ValueKey<String>('ceo-realtime-wss-pill'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveArrivalBanner(CeoLiveEventItem ev) {
    return Material(
      color: const Color(0xFF0E231C),
      child: InkWell(
        onTap: ev.linkedJobId != null
            ? () => _openOrderForensics(ev.linkedJobId!)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: FounderSovereignTokens.solvencyEmerald
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.notifications_active_rounded,
                size: 17,
                color: FounderSovereignTokens.solvencyEmerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nova movimentação: ${ev.title}${ev.subtitle.isNotEmpty ? " — ${ev.subtitle}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ev.amountCents > 0)
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
    final padding = EdgeInsets.fromLTRB(16, 14, 16, bottomInset);
    switch (_selectedTabIndex) {
      case 0:
        return ListView(
          key: const ValueKey<String>('ceo-tab-0-live-view'),
          padding: padding,
          children: _buildTab0Home(anim),
        );
      case 1:
        return ListView(
          key: const ValueKey<String>('ceo-tab-1-caixa-view'),
          padding: padding,
          children: _buildTab1Finance(anim),
        );
      case 2:
        return ListView(
          key: const ValueKey<String>('ceo-tab-2-operacoes-view'),
          padding: padding,
          children: _buildTab2Orders(anim),
        );
      case 3:
        return ListView(
          key: const ValueKey<String>('ceo-tab-3-usuarios-view'),
          padding: padding,
          children: _buildTab3People(anim),
        );
      default:
        return ListView(
          key: const ValueKey<String>('ceo-tab-4-cofre-view'),
          padding: padding,
          children: _buildTab4Account(anim),
        );
    }
  }

  // ===========================================================================
  // ABA 0: INÍCIO (VISÃO DE 5 SEGUNDOS DO CEO)
  // ===========================================================================

  List<Widget> _buildTab0Home(Animation<double> anim) {
    final dre = _snapshot.dreCents;
    final tr = _snapshot.treasury;
    final p = _snapshot.livePulse;
    final demo = _snapshot.demographics;
    final sw = _snapshot.securityWatch;
    final reconOk = _snapshot.reconciliation.threeWayReconciliationOk;

    final attentionItems = <({String text, int targetTab})>[
      if (sw.duressIncidents.isNotEmpty)
        (
          text:
              '${sw.duressIncidents.length} alerta de segurança em atendimento',
          targetTab: 4,
        ),
      if (!reconOk)
        (
          text: 'Diferença detectada na conferência de saldos',
          targetTab: 1,
        ),
      if (p.disputedJobsCount > 0)
        (
          text: '${p.disputedJobsCount} pedido(s) aguardando solução de disputa',
          targetTab: 2,
        ),
      if (demo.kycPendingCount > 0)
        (
          text: '${demo.kycPendingCount} cadastro(s) com documentos pendentes',
          targetTab: 3,
        ),
    ];

    final filteredEvents = _snapshot.liveEvents.where((ev) {
      if (_liveFeedFilter == 'all') return true;
      return _classifyLiveEvent(ev).category == _liveFeedFilter;
    }).toList(growable: false);

    return <Widget>[
      _buildContextualPeriodBar(),
      const SizedBox(height: 12),
      if (attentionItems.isNotEmpty) ...<Widget>[
        Material(
          color: FounderSovereignTokens.warmAmberSoft,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedTabIndex = attentionItems.first.targetTab,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      FounderSovereignTokens.warmAmber.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.notifications_rounded,
                    size: 18,
                    color: FounderSovereignTokens.warmAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Precisa da sua atenção: ${attentionItems.map((e) => e.text).join(" · ")}',
                      style: const TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: FounderSovereignTokens.warmAmber,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-hero-financial-pulse-card'),
          showTopAccentBar: true,
          accentTopBarColor: FounderSovereignTokens.imperialGold,
          padding: const EdgeInsets.all(20),
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
                    'SEU LUCRO LÍQUIDO',
                    style: FounderSovereignTokens.eyebrowStyle(
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: reconOk
                          ? FounderSovereignTokens.solvencyEmeraldSoft
                          : FounderSovereignTokens.crimsonAlertSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      reconOk
                          ? '✓ Contas 100% conferidas'
                          : 'Verificar conferência de saldos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: reconOk
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.crimsonAlert,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedMoneyOdometer(
                cents: dre.netProfitEbitdaCents,
                privacyBlurActive: _privacyBlurActive,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: dre.netProfitEbitdaCents < 0
                      ? FounderSovereignTokens.crimsonAlert
                      : FounderSovereignTokens.primaryInk,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: FounderSovereignTokens.crispBorder),
              const SizedBox(height: 14),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Faturamento do App (13,5%)',
                        style: TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedMoneyOdometer(
                        key: const ValueKey<String>(
                          'ceo-hero-platform-revenue-odometer',
                        ),
                        cents: dre.platformGrossRevenueCents,
                        privacyBlurActive: _privacyBlurActive,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                    ],
                  ),
                  _buildHeroSubMetric(
                    label: 'Total pago nos serviços',
                    cents: dre.gmvTotalCents,
                    color: FounderSovereignTokens.primaryInk,
                  ),
                  _buildHeroSubMetric(
                    label: 'Guardado de clientes e profissionais',
                    cents: tr.totalCustodyCents,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                  _buildHeroSubMetric(
                    label: 'Reserva de garantia (90 dias)',
                    cents: _snapshot.actuarialPool.runningBalanceCents,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 720 ? 4 : (c.maxWidth < 260 ? 1 : 2);
            const spacing = 12.0;
            final cardW = (c.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: <Widget>[
                SizedBox(
                  width: cardW,
                  child: _BentoSummaryTile(
                    title: 'Acontecendo agora',
                    value: '${p.activeOrdersTotalCount}',
                    subtitle:
                        '${p.awaitingQuoteOrPaymentCount} aguardando · ${p.inExecutionPipelineCount} em curso',
                    accent: FounderSovereignTokens.imperialGoldBright,
                    icon: Icons.bolt_rounded,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _BentoSummaryTile(
                    title: 'Serviços concluídos',
                    value: '${p.completedAllTimeCount}',
                    subtitle: '${dre.completedOrdersCount} neste período',
                    accent: FounderSovereignTokens.solvencyEmerald,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _BentoSummaryTile(
                    title: 'Pessoas no app',
                    value: '${demo.totalUsersCount}',
                    subtitle:
                        '${demo.totalActiveClients} clientes · ${demo.totalActiveProviders} profissionais',
                    accent: FounderSovereignTokens.cyberCyan,
                    icon: Icons.people_outline_rounded,
                    onTap: () => setState(() => _selectedTabIndex = 3),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _BentoSummaryTile(
                    title: 'Avaliação média',
                    value: p.reviewsTotalCount > 0
                        ? '${p.reviewsAvgStars.toStringAsFixed(1).replaceAll(".", ",")} ★'
                        : '—',
                    subtitle: p.reviewsTotalCount > 0
                        ? '${p.reviewsTotalCount} avaliações enviadas'
                        : '${p.quotesPendingCount} orçamentos abertos',
                    accent: FounderSovereignTokens.warmAmber,
                    icon: Icons.star_border_rounded,
                    onTap: () => setState(() => _selectedTabIndex = 3),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 2,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-live-activity-stream-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.bolt_rounded,
                    size: 19,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Últimas movimentações (${filteredEvents.length})',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildLiveFeedFilterChip('all', 'Tudo'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('payments', 'Pagamentos'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('orders', 'Pedidos'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('people', 'Cadastros'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filteredEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Icon(
                        Icons.wifi_tethering_rounded,
                        size: 26,
                        color: FounderSovereignTokens.solvencyEmerald,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tudo pronto e conectado em tempo real',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Assim que um cliente ou profissional usar o Desperrengue, a movimentação aparece aqui na hora.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: <Widget>[
                    for (final ev in filteredEvents.take(35))
                      _buildLiveEventRow(ev),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildLiveFeedFilterChip(String code, String label) {
    final active = _liveFeedFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _liveFeedFilter = code);
      },
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: active
            ? FounderSovereignTokens.imperialGold
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
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
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedMoneyOdometer(
          cents: cents,
          privacyBlurActive: _privacyBlurActive,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveEventRow(CeoLiveEventItem ev) {
    final meta = _classifyLiveEvent(ev);
    final jobId = ev.linkedJobId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: jobId != null ? () => _openOrderForensics(jobId) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meta.icon, size: 17, color: meta.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ev.title,
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
                      const SizedBox(height: 2),
                      Text(
                        _formatHumanTimeBrt(ev.occurredAt),
                        style: const TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ev.amountCents > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  AnimatedMoneyOdometer(
                    cents: ev.amountCents,
                    privacyBlurActive: _privacyBlurActive,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                ],
                if (jobId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
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
  // ABA 1: FINANCEIRO (SEU DINHEIRO × DINHEIRO GUARDADO + CASCATA + CONTADOR)
  // ===========================================================================

  List<Widget> _buildTab1Finance(Animation<double> anim) {
    final recon = _snapshot.reconciliation;
    final dre = _snapshot.dreCents;

    return <Widget>[
      _buildContextualPeriodBar(),
      const SizedBox(height: 12),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-three-way-reconciliation-card'),
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
                    'Seu caixa × Dinheiro guardado no app',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: recon.threeWayReconciliationOk
                          ? FounderSovereignTokens.solvencyEmeraldSoft
                          : FounderSovereignTokens.crimsonAlertSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      recon.threeWayReconciliationOk
                          ? '✓ Contas 100% conferidas'
                          : 'Diferença de ${Money.formatBrl(recon.discrepancyCents)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: recon.threeWayReconciliationOk
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.crimsonAlert,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: <Widget>[
                  _buildHeroSubMetric(
                    label: 'Seu lucro líquido (caixa livre)',
                    cents: dre.netProfitEbitdaCents,
                    color: dre.netProfitEbitdaCents < 0
                        ? FounderSovereignTokens.crimsonAlert
                        : FounderSovereignTokens.solvencyEmerald,
                  ),
                  _buildHeroSubMetric(
                    label: 'Guardado de clientes e profissionais',
                    cents: recon.walletsAndEscrowTotalCents,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                  _buildHeroSubMetric(
                    label: 'Reserva de garantia (90 dias)',
                    cents: _snapshot.actuarialPool.runningBalanceCents,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _showReconciliationProof = !_showReconciliationProof,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _showReconciliationProof
                            ? 'Ocultar conferência dos 3 saldos'
                            : 'Conferir prova dos 3 saldos',
                        style: const TextStyle(
                          color: FounderSovereignTokens.cyberCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showReconciliationProof
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: FounderSovereignTokens.cyberCyan,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showReconciliationProof) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: <Widget>[
                      _buildHeroSubMetric(
                        label: '1. PIX confirmados',
                        cents: recon.pixTopupsConfirmedCents,
                        color: FounderSovereignTokens.primaryInk,
                      ),
                      _buildHeroSubMetric(
                        label: '2. Registro interno do app',
                        cents: recon.ledgerNetSumCents,
                        color: FounderSovereignTokens.cyberCyan,
                      ),
                      _buildHeroSubMetric(
                        label: '3. Carteiras + serviços em andamento',
                        cents: recon.walletsAndEscrowTotalCents,
                        color: FounderSovereignTokens.solvencyEmerald,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-real-dre-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'Para onde foi cada real?',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                  FilledButton.icon(
                    key: const ValueKey<String>(
                      'ceo-open-real-expense-modal-btn',
                    ),
                    onPressed: () async {
                      await FounderRealExpenseModal.show(
                        context,
                        repository: _repo,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF0B0E14),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Lançar gasto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDreLine(
                'Total pago pelos clientes (${dre.completedOrdersCount} serviços)',
                dre.gmvTotalCents,
                FounderSovereignTokens.primaryInk,
              ),
              _buildDreLine(
                'Repasse aos profissionais (85% mão de obra)',
                -dre.providerNetLaborCents,
                FounderSovereignTokens.mutedInk,
              ),
              _buildDreLine(
                'Reembolso de peças compradas (sem taxa)',
                -dre.materialsExemptCents,
                FounderSovereignTokens.cyberCyan,
              ),
              _buildDreLine(
                'Reserva de garantia de 90 dias (1,5%)',
                -dre.warrantyPoolCarveoutCents,
                FounderSovereignTokens.warmAmber,
              ),
              const Divider(height: 18, color: FounderSovereignTokens.crispBorder),
              _buildDreLine(
                'Faturamento do Desperrengue (13,5%)',
                dre.platformGrossRevenueCents,
                FounderSovereignTokens.imperialGoldBright,
                bold: true,
              ),
              _buildDreLine(
                'Imposto Simples Nacional (6% sobre a comissão)',
                -dre.simplesNacionalTaxCents,
                FounderSovereignTokens.crimsonAlert,
              ),
              _buildDreLine(
                'Taxas de PIX e sistema',
                -dre.variablePspAndCloudCents,
                FounderSovereignTokens.mutedInk,
              ),
              _buildDreLine(
                'Gastos fixos da empresa',
                -dre.fixedOpexCents,
                FounderSovereignTokens.mutedInk,
              ),
              const Divider(height: 18, color: FounderSovereignTokens.crispBorder),
              _buildDreLine(
                'Seu Lucro Líquido',
                dre.netProfitEbitdaCents,
                dre.netProfitEbitdaCents >= 0
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.crimsonAlert,
                bold: true,
              ),
              if (_snapshot.realExpenses.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Gastos registrados no período (${_snapshot.realExpenses.length})',
                  style: FounderSovereignTokens.titleStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                for (final exp in _snapshot.realExpenses)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(12),
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
                              fontSize: 12,
                            ),
                          ),
                        ),
                        AnimatedMoneyOdometer(
                          cents: exp.amountCents,
                          privacyBlurActive: _privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.crimsonAlert,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Excluir gasto',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _repo.deleteRealExpense(exp.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
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
      const SizedBox(height: 14),
      FounderAccountantPackExporterWidget(snapshot: _snapshot),
      const SizedBox(height: 14),
      _ProgressiveDisclosureToggleCard(
        toggleKey: const ValueKey<String>('ceo-toggle-advanced-finance-btn'),
        expanded: _showAdvancedFinanceCharts,
        title: _showAdvancedFinanceCharts
            ? 'Ocultar gráficos detalhados e simulador'
            : 'Ver gráficos detalhados e simulador de metas',
        subtitle:
            'Divisão visual do dinheiro, evolução diária, prazos de liberação e projeção para 12 meses',
        onTap: () => setState(
          () => _showAdvancedFinanceCharts = !_showAdvancedFinanceCharts,
        ),
      ),
      if (_showAdvancedFinanceCharts) ...<Widget>[
        const SizedBox(height: 14),
        FounderSankeyMoneyFlowChart(
          dre: dre,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        ),
        if (_snapshot.dailySeries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          FounderJCurveBreakEvenChart(
            dailySeries: _snapshot.dailySeries,
            animation: anim,
            privacyBlurActive: _privacyBlurActive,
          ),
        ],
        const SizedBox(height: 14),
        FounderTreasuryEscrowHistogramChart(
          treasury: _snapshot.treasury,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        ),
        const SizedBox(height: 14),
        FounderActuarialSpeedometerChart(
          pool: _snapshot.actuarialPool,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        ),
        const SizedBox(height: 14),
        FounderMonteCarloSimulatorWidget(
          snapshot: _snapshot,
          privacyBlurActive: _privacyBlurActive,
        ),
        const SizedBox(height: 14),
        FounderExecutiveCopilotWidget(snapshot: _snapshot),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.secondaryInk,
                fontSize: bold ? 13.5 : 12.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedMoneyOdometer(
            cents: signedCents.abs(),
            prefix: prefix,
            privacyBlurActive: _privacyBlurActive,
            style: FounderSovereignTokens.monoMetric(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ABA 2: PEDIDOS (SERVIÇOS E MAPA  |  BAIRROS E PROFISSÕES)
  // ===========================================================================

  List<Widget> _buildTab2Orders(Animation<double> anim) {
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
      _buildTwoWayModeSwitch(
        leftLabel: 'Serviços e Mapa',
        rightLabel: 'Bairros e Profissões',
        selectedIndex: _operationsSubView,
        onChanged: (idx) => setState(() => _operationsSubView = idx),
      ),
      const SizedBox(height: 14),
      if (_operationsSubView == 0) ...<Widget>[
        StaggeredRevealItem(
          animation: anim,
          stageIndex: 0,
          child: FounderLiveGeoRadarCard(
            points: _snapshot.liveMapPoints,
            privacyBlurActive: _privacyBlurActive,
            onInspectOrder: (jobId, code) => _openOrderForensics(jobId, code),
          ),
        ),
        const SizedBox(height: 14),
        StaggeredRevealItem(
          animation: anim,
          stageIndex: 1,
          child: FounderGlassCard(
            key: const ValueKey<String>('ceo-real-orders-pipeline-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pedidos dos clientes (${filteredOrders.length})',
                  style: FounderSovereignTokens.titleStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _buildOrderFilterChip(
                        'all',
                        'Todos (${_snapshot.recentOrdersMicroPnl.length})',
                      ),
                      const SizedBox(width: 6),
                      _buildOrderFilterChip('open', 'Aguardando PIX'),
                      const SizedBox(width: 6),
                      _buildOrderFilterChip('scheduled', 'Agendados'),
                      const SizedBox(width: 6),
                      _buildOrderFilterChip('execution', 'Em andamento'),
                      const SizedBox(width: 6),
                      _buildOrderFilterChip('completed', 'Concluídos'),
                      const SizedBox(width: 6),
                      _buildOrderFilterChip('disputed', 'Em disputa'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: FounderSovereignTokens.crispBorder),
                    ),
                    child: const Text(
                      'Nenhum pedido nesta etapa no momento.',
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
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  _openOrderForensics(o.jobId, o.orderCode),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: FounderSovereignTokens.crispBorder,
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
                                                o.categoryName,
                                                style: const TextStyle(
                                                  color: FounderSovereignTokens
                                                      .primaryInk,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: founderStatusColor(
                                                    o.status,
                                                  ).withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                                child: Text(
                                                  founderStatusLabelPt(
                                                    o.status,
                                                  ),
                                                  style: TextStyle(
                                                    color: founderStatusColor(
                                                      o.status,
                                                    ),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${o.orderCode} · ${o.neighborhood} · Cliente: ${o.clientName}'
                                            '${o.providerName != null ? " · Profissional: ${o.providerName}" : " · (${o.quotesCount} orçamentos)"}',
                                            style: const TextStyle(
                                              color: FounderSovereignTokens
                                                  .mutedInk,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        AnimatedMoneyOdometer(
                                          cents: o.gmvCents,
                                          privacyBlurActive: _privacyBlurActive,
                                          style: FounderSovereignTokens
                                              .monoMetric(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: FounderSovereignTokens
                                                .primaryInk,
                                          ),
                                        ),
                                        Text(
                                          'Seu ganho: ${_privacyBlurActive ? "•••" : Money.formatBrl(o.platformFeeCents)}',
                                          style: FounderSovereignTokens
                                              .monoMetric(
                                            fontSize: 10.5,
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
      ] else ...<Widget>[
        FounderNeighborhoodBivariateHeatmapWidget(
          snapshot: _snapshot,
          privacyBlurActive: _privacyBlurActive,
        ),
        const SizedBox(height: 14),
        FounderGlassCard(
          key: const ValueKey<String>('ceo-33-categories-liquidity-card'),
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
                    'Procura por profissão (33 áreas)',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _showAll33Categories = !_showAll33Categories,
                    ),
                    child: Text(
                      _showAll33Categories
                          ? 'Mostrar principais'
                          : 'Ver todas as 33 áreas',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final c in displayedCats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            '${c.demandCount} pedidos · ${c.activeProvidersCount} profissionais',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.isSupplyBottleneck
                                  ? FounderSovereignTokens.crimsonAlert
                                  : FounderSovereignTokens.mutedInk,
                            ),
                          ),
                          AnimatedMoneyOdometer(
                            cents: c.avgTicketCents,
                            privacyBlurActive: _privacyBlurActive,
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 12,
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
      ],
    ];
  }

  Widget _buildTwoWayModeSwitch({
    required String leftLabel,
    required String rightLabel,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    Widget buildSeg(String label, int idx) {
      final active = selectedIndex == idx;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(idx);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: active
                  ? FounderSovereignTokens.obsidianRaised
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: active
                    ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Row(
        children: <Widget>[
          buildSeg(leftLabel, 0),
          const SizedBox(width: 4),
          buildSeg(rightLabel, 1),
        ],
      ),
    );
  }

  Widget _buildOrderFilterChip(String code, String label) {
    final active = _ordersStatusFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _ordersStatusFilter = code),
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: active
            ? FounderSovereignTokens.imperialGold
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  // ===========================================================================
  // ABA 3: PESSOAS (RESUMO SIMÉTRICO + DIRETÓRIO + AVALIAÇÕES + JORNADA)
  // ===========================================================================

  List<Widget> _buildTab3People(Animation<double> anim) {
    final d = _snapshot.demographics;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-demographics-partition-card'),
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
                    'Pessoas cadastradas (${d.totalUsersCount})',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                  Text(
                    d.partitionInvariantOk
                        ? '✓ Contagem conferida'
                        : 'Revisar cadastros',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final cols =
                      c.maxWidth >= 680 ? 4 : (c.maxWidth < 240 ? 1 : 2);
                  const spacing = 10.0;
                  final tileW = (c.maxWidth - spacing * (cols - 1)) / cols;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: <Widget>[
                      SizedBox(
                        width: tileW,
                        child: _MiniStatBadge(
                          'Só clientes',
                          '${d.onlyClientsCount}',
                          FounderSovereignTokens.warmAmber,
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        child: _MiniStatBadge(
                          'Só profissionais',
                          '${d.onlyProvidersCount}',
                          FounderSovereignTokens.cyberCyan,
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        child: _MiniStatBadge(
                          'Clientes e profissionais',
                          '${d.dualModeBothCount}',
                          FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        child: _MiniStatBadge(
                          'Documentos aprovados',
                          '${d.kycVerifiedCount}',
                          FounderSovereignTokens.solvencyEmerald,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Documentos em análise: ${d.kycPendingCount} · '
                'Cadastro incompleto: ${d.onboardingIncompleteCount} · '
                'Contas encerradas: ${d.totalLgpdOffboardings}',
                style: const TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderUsersCrmDirectoryCard(
          repository: _repo,
          privacyBlurActive: _privacyBlurActive,
        ),
      ),
      const SizedBox(height: 14),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-real-reviews-feed-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Avaliações dos atendimentos (${_snapshot.recentReviews.length})',
              style: FounderSovereignTokens.titleStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_snapshot.recentReviews.isEmpty)
              const Text(
                'Nenhuma avaliação enviada pelos clientes até o momento.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12.5,
                ),
              )
            else
              for (final rev in _snapshot.recentReviews.take(15))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Nota ${rev.rating} ★ · ${rev.reviewerName} avaliou ${rev.revieweeName} (${rev.categoryName})',
                        style: const TextStyle(
                          color: FounderSovereignTokens.imperialGoldBright,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (rev.comment.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          rev.comment,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _ProgressiveDisclosureToggleCard(
        toggleKey: const ValueKey<String>('ceo-toggle-people-journey-btn'),
        expanded: _showPeopleJourneyDetails,
        title: _showPeopleJourneyDetails
            ? 'Ocultar jornada de cadastro e recorrência'
            : 'Ver jornada de cadastro e clientes recorrentes',
        subtitle:
            'Quantas pessoas avançam do cadastro até voltar a pedir novos serviços',
        onTap: () => setState(
          () => _showPeopleJourneyDetails = !_showPeopleJourneyDetails,
        ),
      ),
      if (_showPeopleJourneyDetails) ...<Widget>[
        const SizedBox(height: 14),
        FounderGlassCard(
          key: const ValueKey<String>('ceo-real-conversion-funnel-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Etapas dos usuários no aplicativo',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (_snapshot.realConversionFunnel.isEmpty)
                const Text(
                  'Sem dados suficientes neste período.',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 12.5,
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${st.usersCount}',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 13.5,
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
          const SizedBox(height: 14),
          FounderCohortRetentionHeatmapChart(
            cohorts: _snapshot.cohortRetention,
            animation: anim,
          ),
        ],
      ],
    ];
  }

  // ===========================================================================
  // ABA 4: CONTA (IDENTIDADE DO CEO + SENHA + TELA/ATUALIZAÇÃO + APARELHOS)
  // ===========================================================================

  List<Widget> _buildTab4Account(Animation<double> anim) {
    final vm = _snapshot.vaultMetadata;
    final sw = _snapshot.securityWatch;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderCeoProfileCard(
          key: const ValueKey<String>('ceo-monocratic-passport-card'),
          repository: _repo,
          vaultMetadata: vm,
          onSignOutComplete: () async {
            await _repo.signOutAndLock();
            if (!mounted) return;
            setState(() {
              _session = null;
              _lockReasonBanner = 'Você saiu da sua conta com segurança.';
            });
          },
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-flag-secure-and-ota-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Proteção da tela e atualizações',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _screenProtection.temporaryCaptureAllowed
                    ? 'Prints liberados temporariamente (${_screenProtection.remainingCaptureSeconds}s restantes antes de voltar a bloquear).'
                    : 'Prints e gravações de tela estão bloqueados no seu celular para proteger seus números.',
                style: TextStyle(
                  color: _screenProtection.temporaryCaptureAllowed
                      ? FounderSovereignTokens.warmAmber
                      : FounderSovereignTokens.solvencyEmerald,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
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
                          ? 'Bloquear prints agora'
                          : 'Permitir print por 5 min',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>('ceo-manual-ota-check-btn'),
                    onPressed: _checkingOta ? null : _checkManualOtaUpdate,
                    icon: const Icon(Icons.system_update_rounded, size: 16),
                    label: Text(
                      _checkingOta
                          ? 'Procurando atualização…'
                          : 'Procurar atualização do app',
                    ),
                  ),
                ],
              ),
              if (_otaStatusMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _otaStatusMessage!,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 2,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-trusted-devices-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Aparelhos autorizados (${_snapshot.trustedDevices.length})',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (_snapshot.trustedDevices.isEmpty)
                const Text(
                  'Nenhum aparelho registrado ainda.',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 12.5,
                  ),
                )
              else
                for (final dev in _snapshot.trustedDevices)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dev.isCurrentDevice
                            ? FounderSovereignTokens.solvencyEmerald
                                .withValues(alpha: 0.5)
                            : FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 20,
                          color: FounderSovereignTokens.cyberCyan,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${dev.deviceLabel}${dev.isCurrentDevice ? " · Este aparelho" : ""}',
                                style: const TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Último acesso ${_formatHumanTimeBrt(dev.lastSeenAt)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
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
                              'Desconectar',
                              style: TextStyle(
                                color: FounderSovereignTokens.crimsonAlert,
                                fontWeight: FontWeight.w700,
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
      const SizedBox(height: 14),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-security-posture-badges-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Resumo de proteção da sua conta',
              style: FounderSovereignTokens.titleStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const _SecurityCheckRow(
              text: 'Acesso exclusivo: somente seu e-mail entra neste app',
              ok: true,
            ),
            const SizedBox(height: 6),
            _SecurityCheckRow(
              text: 'Endereços de clientes e profissionais protegidos',
              ok: sw.geoPrivacyLeakBps == 0,
            ),
            const SizedBox(height: 6),
            _SecurityCheckRow(
              text: sw.auditChainIntact
                  ? 'Histórico de acessos íntegro e protegido'
                  : 'Verifique o histórico de acessos abaixo',
              ok: sw.auditChainIntact,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _ProgressiveDisclosureToggleCard(
        toggleKey: const ValueKey<String>('ceo-toggle-security-audit-btn'),
        expanded: _showSecurityAuditDetails,
        title: _showSecurityAuditDetails
            ? 'Ocultar histórico de acessos e proteção avançada'
            : 'Ver histórico de acessos e proteção avançada',
        subtitle:
            'Registro de entradas na sua conta, notas fiscais de peças e alertas de atendimento',
        onTap: () => setState(
          () => _showSecurityAuditDetails = !_showSecurityAuditDetails,
        ),
      ),
      if (_showSecurityAuditDetails) ...<Widget>[
        const SizedBox(height: 14),
        FounderSilentDuressWarRoomWidget(securityWatch: sw),
        const SizedBox(height: 14),
        FounderAntiBypassAndSefazRadarWidget(securityWatch: sw),
        const SizedBox(height: 14),
        FounderGlassCard(
          key: const ValueKey<String>('ceo-worm-audit-log-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Histórico recente de segurança (${_snapshot.recentAuditLog.length})',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (_snapshot.recentAuditLog.isEmpty)
                const Text(
                  'Nenhum registro de acesso recente.',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 12.5,
                  ),
                )
              else
                for (final a in _snapshot.recentAuditLog.take(25))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: a.isIntrusionCanary
                            ? FounderSovereignTokens.crimsonAlertSoft
                            : FounderSovereignTokens.obsidianSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: a.isIntrusionCanary
                              ? FounderSovereignTokens.crimsonAlert
                              : FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            a.isIntrusionCanary
                                ? Icons.gpp_bad_rounded
                                : Icons.verified_user_rounded,
                            size: 16,
                            color: a.isIntrusionCanary
                                ? FounderSovereignTokens.crimsonAlert
                                : FounderSovereignTokens.solvencyEmerald,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _humanizeAuditEventCode(a.eventCode),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: a.isIntrusionCanary
                                    ? FounderSovereignTokens.crimsonAlert
                                    : FounderSovereignTokens.primaryInk,
                              ),
                            ),
                          ),
                          Text(
                            _formatHumanTimeBrt(a.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: FounderSovereignTokens.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _BentoSummaryTile extends StatelessWidget {
  const _BentoSummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: FounderGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FounderSovereignTokens.secondaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 23,
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
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressiveDisclosureToggleCard extends StatelessWidget {
  const _ProgressiveDisclosureToggleCard({
    required this.toggleKey,
    required this.expanded,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key toggleKey;
  final bool expanded;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FounderSovereignTokens.obsidianCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: toggleKey,
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FounderSovereignTokens.crispBorder),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: FounderSovereignTokens.imperialGoldBright,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: FounderSovereignTokens.mutedInk,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: FounderSovereignTokens.imperialGoldBright,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityCheckRow extends StatelessWidget {
  const _SecurityCheckRow({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final col = ok
        ? FounderSovereignTokens.solvencyEmerald
        : FounderSovereignTokens.crimsonAlert;
    return Row(
      children: <Widget>[
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 16,
          color: col,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FounderSovereignTokens.mutedInk,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

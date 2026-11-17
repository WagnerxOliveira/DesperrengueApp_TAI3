import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/utils/money.dart';
import '../data/founder_cockpit_repository.dart';
import '../domain/founder_deep_link_policy.dart';
import 'founder_animations_and_shaders.dart';
import 'founder_auth_and_vault_gate.dart';
import 'founder_ceo_profile_sheet.dart';
import 'founder_charts_painters.dart';
import 'founder_deep_link_coordinator.dart';
import 'founder_executive_calendar_sheet.dart';
import 'founder_innovations_widgets.dart';
import 'founder_live_sheets_and_radar.dart';
import 'founder_treasury_and_slu_widgets.dart';
import 'founder_update_gate.dart';

class _PeriodOption {
  const _PeriodOption(this.key, this.label, this.upperBadge);
  final String key;
  final String label;
  final String upperBadge;
}

const List<_PeriodOption> _kPeriodOptions = <_PeriodOption>[
  _PeriodOption('today', 'Hoje', 'HOJE'),
  _PeriodOption('7d', '7 dias', '7 DIAS'),
  _PeriodOption('30d', '30 dias', '30 DIAS'),
  _PeriodOption('90d', '90 dias', '90 DIAS'),
  _PeriodOption('365d', 'Este ano', 'ESTE ANO'),
  _PeriodOption('all', 'Tudo', 'HISTÓRICO TOTAL'),
];

class _NavTabSpec {
  const _NavTabSpec(this.label, this.glyph);
  final String label;
  final FounderIconGlyph glyph;
}

const List<_NavTabSpec> _kFiveTabs = <_NavTabSpec>[
  _NavTabSpec('Início', FounderIconGlyph.navHome),
  _NavTabSpec('Financeiro', FounderIconGlyph.navFinance),
  _NavTabSpec('Pedidos', FounderIconGlyph.navOrders),
  _NavTabSpec('Pessoas', FounderIconGlyph.navPeople),
  _NavTabSpec('Conta', FounderIconGlyph.navAccount),
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

({FounderIconGlyph glyph, Color color, String category}) _classifyLiveEvent(
  CeoLiveEventItem ev,
) {
  final text = '${ev.eventType} ${ev.title} ${ev.subtitle}'.toLowerCase();
  if (ev.severity.toUpperCase() == 'CRITICAL') {
    return (
      glyph: FounderIconGlyph.warningTriangle,
      color: FounderSovereignTokens.crimsonAlert,
      category: 'orders',
    );
  }
  if (text.contains('avalia') || text.contains('nota') || text.contains('★')) {
    return (
      glyph: FounderIconGlyph.starRating,
      color: FounderSovereignTokens.imperialGoldBright,
      category: 'reviews',
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
      glyph: FounderIconGlyph.pixDiamond,
      color: FounderSovereignTokens.solvencyEmerald,
      category: 'payments',
    );
  }
  if (text.contains('cadastr') ||
      text.contains('perfil') ||
      text.contains('kyc') ||
      text.contains('usuário') ||
      text.contains('documento') ||
      text.contains('conta') ||
      text.contains('modo')) {
    return (
      glyph: FounderIconGlyph.userProvider,
      color: FounderSovereignTokens.imperialGold,
      category: 'people',
    );
  }
  return (
    glyph: FounderIconGlyph.navOrders,
    color: FounderSovereignTokens.imperialGoldBright,
    category: 'orders',
  );
}

/// Painel Executivo em Tempo Real do `Desperrengue CEO` (`v2.18.0`).
///
/// Princípios inegociáveis:
/// - **Zero dados falsos (`Zero-Fake Policy`)**: 100% alimentado pelas tabelas reais
///   do `Desperrengue` em tempo real via PostgreSQL + WebSocket privado.
/// - **Exclusividade Monocrática**: acesso único de `wagneroliveira2395@gmail.com`.
/// - **Luxo Silencioso Executivo (85% Neutro · 10% Ouro Champagne · 5% Semântico)**:
///   zero poluição visual, iconografia vetorial exclusiva (`FounderPrecisionIcon`),
///   ações de 1 toque e linguagem 100% clara de Dono de Empresa.
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
  int _operationsSubView = 0; // 0 = Pedidos e Mapa, 1 = Bairros e Profissões
  int _selectedFinanceChartStage = 0; // Palco interativo 1 gráfico por vez
  String _peopleDirectoryRoleFilter = 'all';
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

  String get _currentPeriodUpperBadge {
    final singleIso =
        CeoBrazilFiscalCalendar.extractSingleDayIsoFromWindowKey(
          _selectedWindowKey,
        );
    if (singleIso != null) {
      final dt = CeoBrazilFiscalCalendar.tryParseDayIso(singleIso);
      if (dt != null) {
        final isFuture = dt.isAfter(CeoBrazilFiscalCalendar.todayBrasilia());
        return '${isFuture ? "AGENDA" : "DIA"} ${CeoBrazilFiscalCalendar.formatDayPtBr(dt)}';
      }
    }
    for (final opt in _kPeriodOptions) {
      if (opt.key == _selectedWindowKey) return opt.upperBadge;
    }
    return '30 DIAS';
  }

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
    _selectedWindowKey = _snapshot.windowKey;

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

  Future<void> _openFullScreenLiveMapFromShortcut() async {
    HapticFeedback.mediumImpact();
    await FounderFullScreenMapModal.show(
      context,
      points: _snapshot.liveMapPoints,
      privacyBlurActive: _privacyBlurActive,
      onInspectOrder: (jobId, code) => _openOrderForensics(jobId, code),
    );
  }

  void _openCeoProfileSheet() {
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
  }

  Future<void> _openExecutiveCalendar() async {
    HapticFeedback.selectionClick();
    final result = await FounderExecutiveCalendarSheet.showExecutiveOverview(
      context,
      snapshot: _snapshot,
      selectedWindowKey: _selectedWindowKey,
      liveSnapshotStream: _repo.snapshotChanges,
      privacyBlurActive: _privacyBlurActive,
      onSelectWindow: (key) => _refreshLiveSnapshot(windowKey: key),
      onInspectOrder: (jobId, code) => _openOrderForensics(jobId, code),
      onAddExpenseForDate: (initialDate) async {
        await FounderRealExpenseModal.show(
          context,
          repository: _repo,
          initialDate: initialDate,
        );
      },
      onToggleExpensePaid: (expenseId, paid) => _repo.toggleExpensePaidStatus(
        expenseId: expenseId,
        paid: paid,
      ),
    );
    if (!mounted || result == null) return;
    if (result.windowKey != _selectedWindowKey) {
      await _refreshLiveSnapshot(windowKey: result.windowKey);
    }
  }

  Future<void> _confirmAndDeleteExpense(CeoRealExpenseEntry exp) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: FounderSovereignTokens.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: FounderSovereignTokens.crispBorder),
          ),
          title: Text(
            'Excluir lançamento?',
            style: FounderSovereignTokens.titleStyle(fontSize: 16.5),
          ),
          content: Text(
            'Deseja remover "${exp.category}" (${Money.formatBrl(exp.amountCents)}) do seu livro-caixa?',
            style: FounderSovereignTokens.subtitleStyle(
              color: FounderSovereignTokens.secondaryInk,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: FounderSovereignTokens.secondaryInk),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: FounderSovereignTokens.crimsonAlert,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Excluir',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await _repo.deleteRealExpense(exp.id);
    }
  }

  void _jumpToPeopleFilter(String roleFilter) {
    HapticFeedback.selectionClick();
    setState(() {
      _peopleDirectoryRoleFilter = roleFilter;
      _selectedTabIndex = 3;
    });
  }

  void _showReconciliationModal() {
    HapticFeedback.selectionClick();
    final recon = _snapshot.reconciliation;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final safeBottom = FounderSovereignTokens.modalBottomSafeSpace(
          ctx,
          extraWhenKeyboardClosed: 18,
        );
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: FounderSovereignTokens.obsidianCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: FounderSovereignTokens.crispBorderStrong),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.crispBorderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    FounderPrecisionBadge(
                      recon.threeWayReconciliationOk
                          ? FounderIconGlyph.shieldVerified
                          : FounderIconGlyph.warningTriangle,
                      boxSize: 38,
                      iconSize: 18,
                      tintColor: recon.threeWayReconciliationOk
                          ? FounderSovereignTokens.solvencyEmerald
                          : FounderSovereignTokens.crimsonAlert,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recon.threeWayReconciliationOk
                            ? 'Contas 100% conferidas'
                            : 'Atenção na conferência de saldos',
                        style: FounderSovereignTokens.titleStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cruzamento automático entre os pagamentos PIX recebidos, o registro interno do Desperrengue e os saldos guardados em carteira e garantia.',
                  style: FounderSovereignTokens.subtitleStyle(),
                ),
                const SizedBox(height: 16),
                _buildDreLine(
                  '1. PIX confirmados na plataforma',
                  recon.pixTopupsConfirmedCents,
                  FounderSovereignTokens.primaryInk,
                ),
                _buildDreLine(
                  '2. Soma líquida do registro interno',
                  recon.ledgerNetSumCents,
                  FounderSovereignTokens.imperialGoldBright,
                ),
                _buildDreLine(
                  '3. Carteiras + serviços em andamento',
                  recon.walletsAndEscrowTotalCents,
                  FounderSovereignTokens.solvencyEmerald,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF0B0E14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          final showCompactRefresh = constraints.maxWidth >= 356;
          final safeBottom = FounderSovereignTokens.safeBottomInset(context);

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
                        _buildTopExecutiveHeader(
                          isDesktopWide: isDesktopWide,
                          showRefreshButton: showCompactRefresh,
                        ),
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
                                  bottomInset: isDesktopWide
                                      ? 36
                                      : (safeBottom + 98),
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
      width: 228,
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          right: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
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
                      'Direção Executiva',
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
          const SizedBox(height: 26),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Acesso exclusivo do fundador',
                  style: TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  kMonocraticCeoEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? FounderSovereignTokens.imperialGoldSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              FounderPrecisionIcon(
                spec.glyph,
                size: 19,
                isActive: active,
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
    final bottomPad = math.max(
      10.0,
      FounderSovereignTokens.safeBottomInset(context) + 8.0,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface
                  .withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(26),
              border:
                  Border.all(color: FounderSovereignTokens.crispBorderStrong),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List<Widget>.generate(_kFiveTabs.length, (i) {
                final spec = _kFiveTabs[i];
                final active = _selectedTabIndex == i;
                return Expanded(
                  child: InkWell(
                    key: ValueKey<String>('ceo-nav-tab-$i'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: active
                            ? FounderSovereignTokens.imperialGoldSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: active
                            ? Border.all(
                                color: FounderSovereignTokens.imperialGold
                                    .withValues(alpha: 0.34),
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          FounderPrecisionIcon(
                            spec.glyph,
                            size: 20,
                            isActive: active,
                            color: active
                                ? FounderSovereignTokens.imperialGoldBright
                                : FounderSovereignTokens.mutedInk,
                          ),
                          const SizedBox(height: 3.5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              spec.label,
                              maxLines: 1,
                              style: TextStyle(
                                color: active
                                    ? FounderSovereignTokens.imperialGoldBright
                                    : FounderSovereignTokens.mutedInk,
                                fontSize: 11,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
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
    );
  }

  // ===========================================================================
  // CABEÇALHO SUPERIOR EXECUTIVO — AVATAR DOURADO W + CONTROLES TÁTEIS
  // ===========================================================================

  Widget _buildTopExecutiveHeader({
    required bool isDesktopWide,
    required bool showRefreshButton,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          bottom: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey<String>('ceo-header-profile-btn'),
                borderRadius: BorderRadius.circular(14),
                onTap: _openCeoProfileSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFF2B2415),
                              Color(0xFF151922),
                            ],
                          ),
                          border: Border.all(
                            color: FounderSovereignTokens.imperialGold
                                .withValues(alpha: 0.72),
                            width: 1.2,
                          ),
                        ),
                        child: const Text(
                          'W',
                          style: TextStyle(
                            color: FounderSovereignTokens.imperialGoldBright,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Wrap(
                              spacing: 8,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Text(
                                  isDesktopWide
                                      ? 'Olá, Wagner · ${_kFiveTabs[_selectedTabIndex].label}'
                                      : 'Olá, Wagner',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FounderSovereignTokens.titleStyle(
                                    fontSize: 15.5,
                                  ),
                                ),
                                _buildRealtimeStatusBadge(),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loadingSnapshot
                                  ? 'Sincronizando dados reais…'
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (showRefreshButton) ...<Widget>[
            _HeaderActionIconBtn(
              buttonKey: const ValueKey<String>('ceo-manual-refresh-btn'),
              tooltip: 'Atualizar agora',
              onPressed:
                  _loadingSnapshot ? null : () => _refreshLiveSnapshot(),
              child: _loadingSnapshot
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    )
                  : const FounderPrecisionIcon(
                      FounderIconGlyph.refreshArc,
                      size: 17.5,
                      color: FounderSovereignTokens.secondaryInk,
                    ),
            ),
            const SizedBox(width: 6),
          ],
          _HeaderActionIconBtn(
            buttonKey: const ValueKey<String>('ceo-privacy-blur-toggle-btn'),
            tooltip: _privacyBlurActive
                ? 'Mostrar valores (Espaço)'
                : 'Ocultar valores em público (Espaço)',
            active: _privacyBlurActive,
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _privacyBlurActive = !_privacyBlurActive);
            },
            child: FounderPrecisionIcon(
              _privacyBlurActive
                  ? FounderIconGlyph.eyeClosed
                  : FounderIconGlyph.eyeOpen,
              size: 18,
              isActive: _privacyBlurActive,
              color: _privacyBlurActive
                  ? FounderSovereignTokens.imperialGoldBright
                  : FounderSovereignTokens.secondaryInk,
            ),
          ),
          const SizedBox(width: 6),
          _HeaderActionIconBtn(
            buttonKey: const ValueKey<String>('ceo-lock-vault-btn'),
            tooltip: 'Trancar aplicativo agora',
            onPressed: () => _lockVaultWithReason(
              'Aplicativo bloqueado manualmente por você.',
            ),
            child: const FounderPrecisionIcon(
              FounderIconGlyph.vaultLock,
              size: 17.5,
              color: FounderSovereignTokens.secondaryInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualPeriodBar() {
    final singleDayIso =
        CeoBrazilFiscalCalendar.extractSingleDayIsoFromWindowKey(
          _selectedWindowKey,
        );
    final singleDate = singleDayIso != null
        ? CeoBrazilFiscalCalendar.tryParseDayIso(singleDayIso)
        : null;
    final isFutureSingleDate = singleDate != null &&
        singleDate.isAfter(CeoBrazilFiscalCalendar.todayBrasilia());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: FounderSovereignTokens.obsidianCard,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: const ValueKey<String>('ceo-open-executive-calendar-btn'),
                borderRadius: BorderRadius.circular(999),
                onTap: _openExecutiveCalendar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: FounderSovereignTokens.imperialGold
                          .withValues(alpha: 0.65),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FounderPrecisionIcon(
                        FounderIconGlyph.calendarExec,
                        size: 14.5,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Calendário',
                        style: TextStyle(
                          color: FounderSovereignTokens.imperialGoldBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (singleDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: isFutureSingleDate
                    ? FounderSovereignTokens.warmAmberSoft
                    : FounderSovereignTokens.imperialGoldSoft,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  key: const ValueKey<String>('ceo-active-single-day-chip'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _refreshLiveSnapshot(windowKey: '30d');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7.5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isFutureSingleDate
                            ? FounderSovereignTokens.warmAmber
                            : FounderSovereignTokens.imperialGold,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FounderPrecisionIcon(
                          isFutureSingleDate
                              ? FounderIconGlyph.upcomingEvent
                              : FounderIconGlyph.calendarExec,
                          size: 14,
                          color: isFutureSingleDate
                              ? FounderSovereignTokens.warmAmber
                              : FounderSovereignTokens.imperialGoldBright,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${isFutureSingleDate ? "Agenda" : "Dia"} ${CeoBrazilFiscalCalendar.formatDayPtBr(singleDate)}',
                          style: TextStyle(
                            color: isFutureSingleDate
                                ? FounderSovereignTokens.warmAmber
                                : FounderSovereignTokens.imperialGoldBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        FounderPrecisionIcon(
                          FounderIconGlyph.closeCross,
                          size: 12.5,
                          color: isFutureSingleDate
                              ? FounderSovereignTokens.warmAmber
                              : FounderSovereignTokens.imperialGoldBright,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
        final (label, color, animatePulse) = switch (status) {
          CeoRealtimeConnectionStatus.liveConnected => (
              'Em tempo real',
              FounderSovereignTokens.solvencyEmerald,
              true,
            ),
          CeoRealtimeConnectionStatus.connecting => (
              'Conectando…',
              FounderSovereignTokens.imperialGoldBright,
              true,
            ),
          CeoRealtimeConnectionStatus.reconnecting => (
              'Reconectando…',
              FounderSovereignTokens.warmAmber,
              true,
            ),
          CeoRealtimeConnectionStatus.disconnected => (
              'Sem conexão',
              FounderSovereignTokens.mutedInk,
              false,
            ),
        };
        return Container(
          key: const ValueKey<String>('ceo-realtime-wss-pill'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LiveBreathingPulseDot(
                color: color,
                size: 6.5,
                animate: animatePulse,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
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
              const LiveBreathingPulseDot(
                color: FounderSovereignTokens.solvencyEmerald,
                size: 8,
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
          const FounderPrecisionIcon(
            FounderIconGlyph.warningTriangle,
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
  // ABA 0: INÍCIO (VISÃO DE 5 SEGUNDOS DO DONO + AÇÕES DIRETAS DE 1 TOQUE)
  // ===========================================================================

  List<Widget> _buildTab0Home(Animation<double> anim) {
    final dre = _snapshot.dreCents;
    final p = _snapshot.livePulse;
    final demo = _snapshot.demographics;
    final sw = _snapshot.securityWatch;
    final reconOk = _snapshot.reconciliation.threeWayReconciliationOk;
    final totalTaxesAndCostsCents = dre.simplesNacionalTaxCents +
        dre.variablePspAndCloudCents +
        dre.fixedOpexCents;

    final attentionItems = <({
      String text,
      VoidCallback onTap,
      bool critical,
      FounderIconGlyph glyph,
    })>[
      if (sw.duressIncidents.isNotEmpty)
        (
          text:
              '${sw.duressIncidents.length} alerta urgente de segurança em atendimento',
          onTap: () => setState(() {
                _selectedTabIndex = 4;
                _showSecurityAuditDetails = true;
              }),
          critical: true,
          glyph: FounderIconGlyph.duressEmergencyShield,
        ),
      if (!reconOk)
        (
          text: 'Diferença detectada na conferência de saldos',
          onTap: _showReconciliationModal,
          critical: true,
          glyph: FounderIconGlyph.warningTriangle,
        ),
      if (p.disputedJobsCount > 0)
        (
          text: '${p.disputedJobsCount} pedido(s) aguardando solução de disputa',
          onTap: () => setState(() {
                _ordersStatusFilter = 'disputed';
                _selectedTabIndex = 2;
              }),
          critical: true,
          glyph: FounderIconGlyph.mediationBalance,
        )
      else if (p.totalOpenMediationsAndTicketsCount > 0)
        (
          text:
              '${p.totalOpenMediationsAndTicketsCount} mediação(ões) ou chamado(s) em aberto',
          onTap: () => setState(() => _selectedTabIndex = 2),
          critical: true,
          glyph: FounderIconGlyph.mediationBalance,
        ),
      if (demo.kycPendingCount > 0)
        (
          text: '${demo.kycPendingCount} cadastro(s) aguardando aprovação',
          onTap: () => _jumpToPeopleFilter('kyc_pending'),
          critical: false,
          glyph: FounderIconGlyph.clockSla,
        ),
    ];

    final filteredEvents = _snapshot.liveEvents.where((ev) {
      if (_liveFeedFilter == 'all') return true;
      return _classifyLiveEvent(ev).category == _liveFeedFilter;
    }).toList(growable: false);

    return <Widget>[
      _buildContextualPeriodBar(),
      const SizedBox(height: 14),
      if (_snapshot.consultedSingleDate != null) ...<Widget>[
        _buildSingleDayConsultedAgendaCard(_snapshot.consultedSingleDate!),
        const SizedBox(height: 14),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'SEU LUCRO LÍQUIDO',
                        style: FounderSovereignTokens.eyebrowStyle(
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.imperialGoldSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _currentPeriodUpperBadge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.imperialGoldBright,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _showReconciliationModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: reconOk
                            ? FounderSovereignTokens.solvencyEmeraldSoft
                            : FounderSovereignTokens.crimsonAlertSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FounderPrecisionIcon(
                            reconOk
                                ? FounderIconGlyph.checkValid
                                : FounderIconGlyph.warningTriangle,
                            size: 13,
                            color: reconOk
                                ? FounderSovereignTokens.solvencyEmerald
                                : FounderSovereignTokens.crimsonAlert,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              reconOk
                                  ? 'Contas 100% conferidas'
                                  : 'Conferir saldos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedMoneyOdometer(
                cents: dre.netProfitEbitdaCents,
                privacyBlurActive: _privacyBlurActive,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: dre.netProfitEbitdaCents < 0
                      ? FounderSovereignTokens.crimsonAlert
                      : FounderSovereignTokens.primaryInk,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(
                height: 1,
                color: FounderSovereignTokens.crispBorder,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final leftBlock = _HeroDualColumnMetric(
                    label: 'Faturamento do App (13,5%)',
                    cents: dre.platformGrossRevenueCents,
                    valueKey: const ValueKey<String>(
                      'ceo-hero-platform-revenue-odometer',
                    ),
                    valueColor: FounderSovereignTokens.imperialGoldBright,
                    privacyBlurActive: _privacyBlurActive,
                    caption: _privacyBlurActive
                        ? 'Gastos e impostos: R\$ •••••'
                        : 'Gastos e impostos: -${Money.formatBrl(totalTaxesAndCostsCents)}',
                  );
                  final rightBlock = _HeroDualColumnMetric(
                    label: 'Total Movimentado',
                    cents: dre.gmvTotalCents,
                    valueColor: FounderSovereignTokens.primaryInk,
                    privacyBlurActive: _privacyBlurActive,
                    caption: _privacyBlurActive
                        ? 'Peças sem taxa: R\$ •••••'
                        : 'Peças sem taxa: ${Money.formatBrl(dre.materialsExemptCents)}',
                  );
                  if (c.maxWidth < 280) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        leftBlock,
                        const SizedBox(height: 14),
                        rightBlock,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: leftBlock),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: FounderSovereignTokens.crispBorder,
                        ),
                        Expanded(child: rightBlock),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(
                height: 1,
                color: FounderSovereignTokens.crispBorder,
              ),
              const SizedBox(height: 12),
              // Ações diretas de 1 toque (economiza múltiplos cliques no dia a dia do CEO!)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _ExecutiveQuickActionPill(
                    glyph: FounderIconGlyph.expenseReceipt,
                    label: '+ Registrar gasto',
                    primary: true,
                    onTap: () async {
                      await FounderRealExpenseModal.show(
                        context,
                        repository: _repo,
                      );
                    },
                  ),
                  _ExecutiveQuickActionPill(
                    glyph: FounderIconGlyph.radarPulse,
                    label: 'Abrir mapa (${_snapshot.liveMapPoints.length})',
                    onTap: _openFullScreenLiveMapFromShortcut,
                  ),
                  _ExecutiveQuickActionPill(
                    glyph: FounderIconGlyph.taxBankDas,
                    label: 'Ver impostos e agenda',
                    onTap: _openExecutiveCalendar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (attentionItems.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        Column(
          children: <Widget>[
            for (var i = 0; i < attentionItems.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final item = attentionItems[i];
                  final accent = item.critical
                      ? FounderSovereignTokens.crimsonAlert
                      : FounderSovereignTokens.warmAmber;
                  return Material(
                    color: item.critical
                        ? FounderSovereignTokens.crimsonAlertSoft
                        : FounderSovereignTokens.warmAmberSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        item.onTap();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            FounderPrecisionIcon(
                              item.glyph,
                              size: 16.5,
                              color: accent,
                              accentColor: accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.text,
                                style: const TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            FounderPrecisionIcon(
                              FounderIconGlyph.chevronRight,
                              size: 15,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ],
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 1,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-home-people-overview-card'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const FounderPrecisionIcon(
                    FounderIconGlyph.navPeople,
                    size: 17,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PESSOAS NA PLATAFORMA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.eyebrowStyle(
                        color: FounderSovereignTokens.secondaryInk,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _jumpToPeopleFilter('all'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Total: ${demo.totalUsersCount}',
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: FounderSovereignTokens.imperialGoldBright,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const FounderPrecisionIcon(
                            FounderIconGlyph.chevronRight,
                            size: 13,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildThreeModePeopleBoxes(
                onlyClients: demo.onlyClientsCount,
                onlyProviders: demo.onlyProvidersCount,
                dualBoth: demo.dualModeBothCount,
                total: demo.totalUsersCount,
                showPercentages: false,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 2,
        child: LayoutBuilder(
          builder: (context, c) {
            final avgStars = p.reviewsTotalCount > 0
                ? '${p.reviewsAvgStars.toStringAsFixed(1).replaceAll(".", ",")} ★'
                : 'Sem notas';
            final ltvCacText = p.quotesAcceptedInWindowCount > 0
                ? '${p.quotesAcceptedInWindowCount} orçamentos aprovados'
                : '${p.quotesPendingCount} orçamentos abertos';

            final tile0 = _BentoSummaryTile(
              title: 'Acontecendo agora',
              value: '${p.activeOrdersTotalCount}',
              subtitle:
                  '${p.inExecutionPipelineCount} em execução · ${p.awaitingQuoteOrPaymentCount} aguardando',
              accent: FounderSovereignTokens.imperialGoldBright,
              glyph: FounderIconGlyph.sparkBolt,
              onTap: () => setState(() => _selectedTabIndex = 2),
            );
            final tile1 = _BentoSummaryTile(
              title: 'Concluídos no período',
              value: '${dre.completedOrdersCount}',
              subtitle:
                  '${p.completedAllTimeCount} no total · Nota $avgStars',
              accent: FounderSovereignTokens.solvencyEmerald,
              glyph: FounderIconGlyph.checkValid,
              onTap: () => setState(() => _selectedTabIndex = 2),
            );
            final tile2 = _BentoSummaryTile(
              title: 'Reserva de Garantia (90d)',
              value: _privacyBlurActive
                  ? 'R\$ •••••'
                  : Money.formatBrl(_snapshot.actuarialPool.runningBalanceCents),
              subtitle: _snapshot.actuarialPool.claimsPaidCents == 0
                  ? 'Zero acionamentos pagos'
                  : 'Pago: ${_privacyBlurActive ? "R\$ •••" : Money.formatBrl(_snapshot.actuarialPool.claimsPaidCents)}',
              accent: FounderSovereignTokens.solvencyEmerald,
              glyph: FounderIconGlyph.shieldVerified,
              onTap: () => setState(() => _selectedTabIndex = 1),
            );
            final tile3 = _BentoSummaryTile(
              title: 'Saúde do Crescimento',
              value: p.reviewsTotalCount > 0
                  ? avgStars
                  : '${demo.kycVerifiedCount} verificados',
              subtitle: ltvCacText,
              accent: FounderSovereignTokens.imperialGold,
              glyph: FounderIconGlyph.profitJCurve,
              onTap: () => setState(() => _selectedTabIndex = 3),
            );

            if (c.maxWidth >= 820) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: tile0),
                    const SizedBox(width: 12),
                    Expanded(child: tile1),
                    const SizedBox(width: 12),
                    Expanded(child: tile2),
                    const SizedBox(width: 12),
                    Expanded(child: tile3),
                  ],
                ),
              );
            }
            if (c.maxWidth < 310) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  tile0,
                  const SizedBox(height: 10),
                  tile1,
                  const SizedBox(height: 10),
                  tile2,
                  const SizedBox(height: 10),
                  tile3,
                ],
              );
            }
            return Column(
              children: <Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: tile0),
                      const SizedBox(width: 12),
                      Expanded(child: tile1),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: tile2),
                      const SizedBox(width: 12),
                      Expanded(child: tile3),
                    ],
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
        stageIndex: 3,
        child: FounderGlassCard(
          key: const ValueKey<String>('ceo-live-activity-stream-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LiveBreathingPulseDot(
                    color: FounderSovereignTokens.solvencyEmerald,
                    size: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Últimas movimentações ao vivo (${filteredEvents.length})',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: <Widget>[
                    _buildLiveFeedFilterChip('all', 'Tudo'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('payments', 'Dinheiro'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('orders', 'Pedidos'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('people', 'Cadastros'),
                    const SizedBox(width: 6),
                    _buildLiveFeedFilterChip('reviews', 'Avaliações'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filteredEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  child: Column(
                    children: <Widget>[
                      const FounderPrecisionBadge(
                        FounderIconGlyph.radarPulse,
                        boxSize: 44,
                        iconSize: 21,
                        tintColor: FounderSovereignTokens.solvencyEmerald,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tudo pronto e conectado em tempo real',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assim que um cliente ou profissional usar o Desperrengue, a movimentação aparece aqui no mesmo segundo.',
                        textAlign: TextAlign.center,
                        style: FounderSovereignTokens.subtitleStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: <Widget>[
                    for (var i = 0;
                        i < filteredEvents.length && i < 35;
                        i++) ...<Widget>[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          color: FounderSovereignTokens.crispBorder,
                        ),
                      _buildLiveEventRow(filteredEvents[i]),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildThreeModePeopleBoxes({
    required int onlyClients,
    required int onlyProviders,
    required int dualBoth,
    required int total,
    required bool showPercentages,
  }) {
    String pct(int count) {
      if (total <= 0) return '0,0%';
      final v = (count * 100.0) / total;
      return '${v.toStringAsFixed(1).replaceAll(".", ",")}%';
    }

    final boxClients = _DemographicRoleTile(
      title: 'Só Clientes',
      count: onlyClients,
      caption: showPercentages ? '(${pct(onlyClients)})' : 'Apenas pedem',
      accent: FounderSovereignTokens.primaryInk,
      selected: showPercentages && _peopleDirectoryRoleFilter == 'client',
      onTap: () => _jumpToPeopleFilter('client'),
    );
    final boxProviders = _DemographicRoleTile(
      title: 'Só Profissionais',
      count: onlyProviders,
      caption: showPercentages ? '(${pct(onlyProviders)})' : 'Apenas atendem',
      accent: FounderSovereignTokens.imperialGoldBright,
      selected:
          showPercentages && _peopleDirectoryRoleFilter == 'only_provider',
      onTap: () => _jumpToPeopleFilter('only_provider'),
    );
    final boxDual = _DemographicRoleTile(
      title: 'Ambos (Os 2 modos)',
      count: dualBoth,
      caption: showPercentages ? '(${pct(dualBoth)})' : 'Pedem e atendem',
      accent: FounderSovereignTokens.solvencyEmerald,
      selected: showPercentages && _peopleDirectoryRoleFilter == 'dual',
      onTap: () => _jumpToPeopleFilter('dual'),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 290) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              boxClients,
              const SizedBox(height: 8),
              boxProviders,
              const SizedBox(height: 8),
              boxDual,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: boxClients),
              const SizedBox(width: 8),
              Expanded(child: boxProviders),
              const SizedBox(width: 8),
              Expanded(child: boxDual),
            ],
          ),
        );
      },
    );
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
    final estimatedNetCents =
        ev.amountCents > 0 ? ((ev.amountCents * 112) ~/ 1000) : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: jobId != null ? () => _openOrderForensics(jobId) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FounderPrecisionIcon(
                  meta.glyph,
                  size: 16.5,
                  color: meta.color,
                  accentColor: meta.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          ev.title,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (ev.amountCents > 0)
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
                    ),
                    if (ev.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        ev.subtitle,
                        style: const TextStyle(
                          color: FounderSovereignTokens.secondaryInk,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    if (ev.amountCents > 0 &&
                        meta.category == 'payments') ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        _privacyBlurActive
                            ? '↳ Seu ganho líquido previsto: + R\$ •••••'
                            : '↳ Seu ganho líquido previsto: + ${Money.formatBrl(estimatedNetCents)}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.solvencyEmerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
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
              if (jobId != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: FounderPrecisionIcon(
                    FounderIconGlyph.chevronRight,
                    size: 15,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ABA 1: FINANCEIRO (2 BOLSOS + CASCATA + PALCO INTERATIVO 1 GRÁFICO POR VEZ)
  // ===========================================================================

  List<Widget> _buildTab1Finance(Animation<double> anim) {
    final recon = _snapshot.reconciliation;
    final dre = _snapshot.dreCents;

    return <Widget>[
      _buildContextualPeriodBar(),
      const SizedBox(height: 14),
      if (_snapshot.consultedSingleDate != null) ...<Widget>[
        _buildSingleDayConsultedAgendaCard(_snapshot.consultedSingleDate!),
        const SizedBox(height: 14),
      ],
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const FounderPrecisionIcon(
                        FounderIconGlyph.walletVault,
                        size: 17,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Seu caixa × Dinheiro guardado no app',
                          style: FounderSovereignTokens.titleStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: recon.threeWayReconciliationOk
                          ? FounderSovereignTokens.solvencyEmeraldSoft
                          : FounderSovereignTokens.crimsonAlertSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FounderPrecisionIcon(
                          recon.threeWayReconciliationOk
                              ? FounderIconGlyph.checkValid
                              : FounderIconGlyph.warningTriangle,
                          size: 13,
                          color: recon.threeWayReconciliationOk
                              ? FounderSovereignTokens.solvencyEmerald
                              : FounderSovereignTokens.crimsonAlert,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            recon.threeWayReconciliationOk
                                ? 'Contas 100% conferidas'
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
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final pocketCompany = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FounderSovereignTokens.imperialGold
                            .withValues(alpha: 0.36),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Caixa Livre do Desperrengue',
                          style: TextStyle(
                            color: FounderSovereignTokens.imperialGoldBright,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedMoneyOdometer(
                          cents: dre.netProfitEbitdaCents,
                          privacyBlurActive: _privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: dre.netProfitEbitdaCents < 0
                                ? FounderSovereignTokens.crimsonAlert
                                : FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Seu lucro líquido disponível',
                          style: TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );

                  final pocketCustody = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Guardado de Clientes e Profissionais',
                          style: TextStyle(
                            color: FounderSovereignTokens.secondaryInk,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedMoneyOdometer(
                          cents: recon.walletsAndEscrowTotalCents,
                          privacyBlurActive: _privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.primaryInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _privacyBlurActive
                              ? 'Garantia 90d: R\$ •••••'
                              : 'Garantia 90d: ${Money.formatBrl(_snapshot.actuarialPool.runningBalanceCents)}',
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (c.maxWidth < 295) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        pocketCompany,
                        const SizedBox(height: 10),
                        pocketCustody,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: pocketCompany),
                        const SizedBox(width: 12),
                        Expanded(child: pocketCustody),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
                      Flexible(
                        child: Text(
                          _showReconciliationProof
                              ? 'Ocultar conferência dos 3 saldos'
                              : 'Conferir prova dos 3 saldos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FounderSovereignTokens.imperialGoldBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      FounderPrecisionIcon(
                        _showReconciliationProof
                            ? FounderIconGlyph.chevronUp
                            : FounderIconGlyph.chevronDown,
                        size: 14,
                        color: FounderSovereignTokens.imperialGoldBright,
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
                        color: FounderSovereignTokens.imperialGoldBright,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const FounderPrecisionIcon(
                        FounderIconGlyph.moneySplitSankey,
                        size: 17,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Para onde foi cada real?',
                          style: FounderSovereignTokens.titleStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
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
                    icon: const FounderPrecisionIcon(
                      FounderIconGlyph.expenseReceipt,
                      size: 15,
                      color: Color(0xFF0B0E14),
                      accentColor: Color(0xFF0B0E14),
                      duotoneAlpha: 0.0,
                    ),
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
                barRatio: 1.0,
              ),
              _buildDreLine(
                'Repasse aos profissionais (85% mão de obra)',
                -dre.providerNetLaborCents,
                FounderSovereignTokens.secondaryInk,
                barRatio: dre.gmvTotalCents > 0
                    ? dre.providerNetLaborCents / dre.gmvTotalCents
                    : 0,
              ),
              _buildDreLine(
                'Reembolso de peças compradas (sem taxa)',
                -dre.materialsExemptCents,
                FounderSovereignTokens.secondaryInk,
                barRatio: dre.gmvTotalCents > 0
                    ? dre.materialsExemptCents / dre.gmvTotalCents
                    : 0,
              ),
              _buildDreLine(
                'Reserva de garantia de 90 dias (1,5%)',
                -dre.warrantyPoolCarveoutCents,
                FounderSovereignTokens.warmAmber,
                barRatio: dre.gmvTotalCents > 0
                    ? dre.warrantyPoolCarveoutCents / dre.gmvTotalCents
                    : 0,
              ),
              const Divider(
                height: 20,
                color: FounderSovereignTokens.crispBorder,
              ),
              _buildDreLine(
                'Faturamento do Desperrengue (13,5%)',
                dre.platformGrossRevenueCents,
                FounderSovereignTokens.imperialGoldBright,
                bold: true,
                barRatio: dre.gmvTotalCents > 0
                    ? dre.platformGrossRevenueCents / dre.gmvTotalCents
                    : 0,
              ),
              _buildDreLine(
                'Imposto Simples Nacional (6% sobre a comissão)',
                -dre.simplesNacionalTaxCents,
                FounderSovereignTokens.warmAmber,
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
              const Divider(
                height: 20,
                color: FounderSovereignTokens.crispBorder,
              ),
              _buildDreLine(
                'Seu Lucro Líquido',
                dre.netProfitEbitdaCents,
                dre.netProfitEbitdaCents >= 0
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.crimsonAlert,
                bold: true,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.solvencyEmeraldSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FounderSovereignTokens.solvencyEmerald
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  children: <Widget>[
                    FounderPrecisionIcon(
                      FounderIconGlyph.shieldVerified,
                      size: 16,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Economia tributária inteligente ativa: imposto calculado apenas sobre a comissão do app (13,5%), sem tributar peças nem o repasse do profissional.',
                        style: TextStyle(
                          color: FounderSovereignTokens.solvencyEmerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_snapshot.realExpenses.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Gastos e contas registradas (${_snapshot.realExpenses.length})',
                  style: FounderSovereignTokens.titleStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                for (var idx = 0;
                    idx < _snapshot.realExpenses.length;
                    idx++) ...<Widget>[
                  if (idx > 0)
                    const Divider(
                      height: 1,
                      color: FounderSovereignTokens.crispBorder,
                    ),
                  Builder(
                    builder: (context) {
                      final exp = _snapshot.realExpenses[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: exp.isScheduled
                                              ? FounderSovereignTokens
                                                  .warmAmberSoft
                                              : FounderSovereignTokens
                                                  .solvencyEmeraldSoft,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          exp.statusLabelPt,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: exp.isScheduled
                                                ? FounderSovereignTokens
                                                    .warmAmber
                                                : FounderSovereignTokens
                                                    .solvencyEmerald,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${exp.competenceDateIso} · ${exp.kindLabelPt}',
                                        style: const TextStyle(
                                          color: FounderSovereignTokens.mutedInk,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${exp.category}${exp.description.isNotEmpty ? " (${exp.description})" : ""}',
                                    style: const TextStyle(
                                      color: FounderSovereignTokens.primaryInk,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedMoneyOdometer(
                              cents: exp.amountCents,
                              prefix: '- ',
                              privacyBlurActive: _privacyBlurActive,
                              style: FounderSovereignTokens.monoMetric(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: exp.isScheduled
                                    ? FounderSovereignTokens.warmAmber
                                    : FounderSovereignTokens.secondaryInk,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              key: ValueKey<String>(
                                'ceo-toggle-expense-paid-${exp.id}',
                              ),
                              tooltip: exp.isScheduled
                                  ? 'Marcar como pago'
                                  : 'Voltar para agendado',
                              style: IconButton.styleFrom(
                                backgroundColor: exp.isScheduled
                                    ? FounderSovereignTokens.warmAmberSoft
                                    : FounderSovereignTokens
                                        .solvencyEmeraldSoft,
                                minimumSize: const Size(34, 34),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _repo.toggleExpensePaidStatus(
                                expenseId: exp.id,
                                paid: exp.isScheduled,
                              ),
                              icon: FounderPrecisionIcon(
                                exp.isScheduled
                                    ? FounderIconGlyph.ringPending
                                    : FounderIconGlyph.checkValid,
                                size: 16,
                                color: exp.isScheduled
                                    ? FounderSovereignTokens.warmAmber
                                    : FounderSovereignTokens.solvencyEmerald,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Excluir gasto',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => _confirmAndDeleteExpense(exp),
                              icon: const FounderPrecisionIcon(
                                FounderIconGlyph.trashDelete,
                                size: 15.5,
                                color: FounderSovereignTokens.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      if (_snapshot.taxObligationsSchedule.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        _buildTaxScheduleCard(),
      ],
      const SizedBox(height: 14),
      FounderBivalentTreasuryCard(
        repository: _repo,
        treasuryState: _snapshot.bivalentTreasury,
        privacyBlurActive: _privacyBlurActive,
      ),
      const SizedBox(height: 14),
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 2,
        child: _buildInteractiveFinanceChartStage(anim, dre),
      ),
      const SizedBox(height: 14),
      FounderAccountantPackExporterWidget(snapshot: _snapshot),
      const SizedBox(height: 14),
      _ProgressiveDisclosureToggleCard(
        toggleKey: const ValueKey<String>('ceo-toggle-advanced-finance-btn'),
        expanded: _showAdvancedFinanceCharts,
        title: _showAdvancedFinanceCharts
            ? 'Ocultar prazos de liberação e assistente financeiro'
            : 'Ver prazos de liberação e assistente financeiro',
        subtitle:
            'Calendário de liberação dos valores retidos e respostas rápidas sobre o caixa',
        onTap: () => setState(
          () => _showAdvancedFinanceCharts = !_showAdvancedFinanceCharts,
        ),
      ),
      if (_showAdvancedFinanceCharts) ...<Widget>[
        const SizedBox(height: 14),
        FounderTreasuryEscrowHistogramChart(
          treasury: _snapshot.treasury,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        ),
        const SizedBox(height: 14),
        FounderExecutiveCopilotWidget(snapshot: _snapshot),
      ],
    ];
  }

  Widget _buildInteractiveFinanceChartStage(
    Animation<double> anim,
    FounderDreCents dre,
  ) {
    const pills = <(int, String, FounderIconGlyph)>[
      (0, 'Fluxo do Dinheiro', FounderIconGlyph.moneySplitSankey),
      (1, 'Evolução do Lucro', FounderIconGlyph.profitJCurve),
      (2, 'Simulador de Metas', FounderIconGlyph.monteCarloCone),
      (3, 'Saúde da Garantia', FounderIconGlyph.shieldVerified),
    ];

    Widget activeChart;
    switch (_selectedFinanceChartStage) {
      case 1:
        activeChart = _snapshot.dailySeries.isNotEmpty
            ? FounderJCurveBreakEvenChart(
                key: const ValueKey<String>('finance-stage-1'),
                dailySeries: _snapshot.dailySeries,
                animation: anim,
                privacyBlurActive: _privacyBlurActive,
              )
            : FounderGlassCard(
                key: const ValueKey<String>('finance-stage-1-empty'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Evolução diária do lucro',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Assim que houver dias com movimentação concluída neste período, a curva diária de faturamento e lucro aparecerá aqui.',
                      style: TextStyle(
                        color: FounderSovereignTokens.mutedInk,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );
      case 2:
        activeChart = FounderMonteCarloSimulatorWidget(
          key: const ValueKey<String>('finance-stage-2'),
          snapshot: _snapshot,
          privacyBlurActive: _privacyBlurActive,
        );
      case 3:
        activeChart = FounderActuarialSpeedometerChart(
          key: const ValueKey<String>('finance-stage-3'),
          pool: _snapshot.actuarialPool,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        );
      default:
        activeChart = FounderSankeyMoneyFlowChart(
          key: const ValueKey<String>('finance-stage-0'),
          dre: dre,
          animation: anim,
          privacyBlurActive: _privacyBlurActive,
        );
    }

    return Container(
      key: const ValueKey<String>('ceo-interactive-chart-stage-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                for (final (idx, label, glyph) in pills)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>('ceo-finance-chart-pill-$idx'),
                      avatar: FounderPrecisionIcon(
                        glyph,
                        size: 14.5,
                        isActive: _selectedFinanceChartStage == idx,
                        color: _selectedFinanceChartStage == idx
                            ? FounderSovereignTokens.imperialGoldBright
                            : FounderSovereignTokens.mutedInk,
                      ),
                      showCheckmark: false,
                      label: Text(label),
                      selected: _selectedFinanceChartStage == idx,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFinanceChartStage = idx);
                      },
                      selectedColor: FounderSovereignTokens.imperialGoldSoft,
                      backgroundColor: FounderSovereignTokens.obsidianCard,
                      side: BorderSide(
                        color: _selectedFinanceChartStage == idx
                            ? FounderSovereignTokens.imperialGold
                            : FounderSovereignTokens.crispBorder,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedFinanceChartStage == idx
                            ? FounderSovereignTokens.imperialGoldBright
                            : FounderSovereignTokens.mutedInk,
                        fontSize: 12,
                        fontWeight: _selectedFinanceChartStage == idx
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: activeChart,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDayConsultedAgendaCard(DateTime consultedDate) {
    final todayBrt = CeoBrazilFiscalCalendar.todayBrasilia();
    final agenda = _snapshot.agendaForDay(
      consultedDate,
      todayBrasilia: todayBrt,
    );
    final events = _snapshot.eventsForDay(consultedDate);
    final dateFormatted = CeoBrazilFiscalCalendar.formatDayPtBr(consultedDate);
    final isFuture = agenda.isFuture;

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-consulted-date-agenda-card'),
      showTopAccentBar: true,
      accentTopBarColor: isFuture
          ? FounderSovereignTokens.warmAmber
          : FounderSovereignTokens.imperialGold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FounderPrecisionIcon(
                    isFuture
                        ? FounderIconGlyph.upcomingEvent
                        : FounderIconGlyph.calendarExec,
                    size: 17,
                    color: isFuture
                        ? FounderSovereignTokens.warmAmber
                        : FounderSovereignTokens.imperialGoldBright,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isFuture
                          ? 'Agenda prevista em $dateFormatted'
                          : 'Consulta exata do dia $dateFormatted',
                      style: FounderSovereignTokens.titleStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                key: const ValueKey<String>('ceo-reset-single-day-btn'),
                onPressed: () => _refreshLiveSnapshot(windowKey: '30d'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: FounderSovereignTokens.imperialGoldBright,
                ),
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.refreshArc,
                  size: 14,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                label: const Text(
                  'Voltar p/ 30 dias',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isFuture
                ? 'Obrigações fiscais oficiais, contas agendadas, mediações ativas e serviços marcados em tempo real para esta data futura.'
                : 'Todos os números e pedidos do painel estão filtrados exclusivamente para $dateFormatted.',
            style: FounderSovereignTokens.subtitleStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              _ConsultedDayStatPill(
                label: 'Impostos e contas',
                value: _privacyBlurActive
                    ? 'R\$ ••••'
                    : Money.formatBrl(
                        isFuture
                            ? agenda.totalPayablesOnDayCents
                            : agenda.totalExpensesAndDasOnDayCents,
                      ),
                accent: (isFuture
                            ? agenda.totalPayablesOnDayCents
                            : agenda.totalExpensesAndDasOnDayCents) >
                        0
                    ? FounderSovereignTokens.warmAmber
                    : FounderSovereignTokens.secondaryInk,
              ),
              _ConsultedDayStatPill(
                label: 'Serviços agendados',
                value: '${agenda.scheduledOrdersCount}',
                accent: FounderSovereignTokens.imperialGoldBright,
              ),
              _ConsultedDayStatPill(
                label: 'Mediações / prazos',
                value: '${agenda.mediationsTotalEventsCount}',
                accent: agenda.hasActiveMediationAlert
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.secondaryInk,
              ),
              if (agenda.maturationReleaseCents > 0)
                _ConsultedDayStatPill(
                  label: 'Liberações profissionais',
                  value: _privacyBlurActive
                      ? 'R\$ ••••'
                      : Money.formatBrl(agenda.maturationReleaseCents),
                  accent: FounderSovereignTokens.solvencyEmerald,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                isFuture
                    ? 'Nenhum imposto previsto, mediação ativa, conta ou serviço agendado nesta data até agora.'
                    : 'Nenhuma movimentação registrada em $dateFormatted.',
                style: FounderSovereignTokens.subtitleStyle(fontSize: 12),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (final ev in events.take(12))
                  _buildConsultedAgendaEventRow(ev),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>(
                'ceo-consulted-date-add-expense-btn',
              ),
              onPressed: () async {
                await FounderRealExpenseModal.show(
                  context,
                  repository: _repo,
                  initialDate: consultedDate,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: FounderSovereignTokens.imperialGoldBright,
                side: BorderSide(
                  color:
                      FounderSovereignTokens.imperialGold.withValues(alpha: 0.4),
                ),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const FounderPrecisionIcon(
                FounderIconGlyph.expenseReceipt,
                size: 15,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              label: Text(
                isFuture
                    ? 'Agendar conta ou imposto para $dateFormatted'
                    : 'Lançar gasto em $dateFormatted',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultedAgendaEventRow(CeoCalendarAgendaEvent ev) {
    final Color accent;
    final FounderIconGlyph glyph;
    if (ev.isMediationOrDispute) {
      accent = ev.severity == 'CRITICAL'
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.warmAmber;
      glyph = FounderIconGlyph.mediationBalance;
    } else if (ev.isTaxEvent) {
      accent = ev.statusCode == 'PAID'
          ? FounderSovereignTokens.solvencyEmerald
          : FounderSovereignTokens.warmAmber;
      glyph = FounderIconGlyph.taxBankDas;
    } else if (ev.eventKind == 'COMPANY_EXPENSE') {
      accent = ev.isScheduledExpense
          ? FounderSovereignTokens.warmAmber
          : FounderSovereignTokens.secondaryInk;
      glyph = FounderIconGlyph.expenseReceipt;
    } else if (ev.eventKind == 'COMPLETED_ORDER') {
      accent = FounderSovereignTokens.solvencyEmerald;
      glyph = FounderIconGlyph.checkValid;
    } else {
      accent = FounderSovereignTokens.imperialGoldBright;
      glyph = FounderIconGlyph.upcomingEvent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: ev.hasLinkedOrder
              ? () => _openOrderForensics(ev.jobId!)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ev.isMediationOrDispute
                    ? accent.withValues(alpha: 0.48)
                    : FounderSovereignTokens.crispBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FounderPrecisionIcon(
                  glyph,
                  size: 16.5,
                  color: accent,
                  accentColor: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ev.title,
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
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
                    ],
                  ),
                ),
                if (ev.grossCents > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 108),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AnimatedMoneyOdometer(
                        cents: ev.grossCents,
                        privacyBlurActive: _privacyBlurActive,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
                if (ev.isScheduledExpense) ...<Widget>[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Marcar conta como paga',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => _repo.toggleExpensePaidStatus(
                      expenseId: ev.refId,
                      paid: true,
                    ),
                    icon: const FounderPrecisionIcon(
                      FounderIconGlyph.checkValid,
                      size: 17,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ] else if (ev.hasLinkedOrder) ...<Widget>[
                  const SizedBox(width: 4),
                  const FounderPrecisionIcon(
                    FounderIconGlyph.chevronRight,
                    size: 15,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaxScheduleCard() {
    final todayIso = CeoBrazilFiscalCalendar.formatDayIso(
      CeoBrazilFiscalCalendar.todayBrasilia(),
    );
    final upcoming = _snapshot.taxObligationsSchedule
        .where(
          (t) =>
              t.dueDateIso.compareTo(todayIso) >= 0 || t.remainingDueCents > 0,
        )
        .take(4)
        .toList(growable: false);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-tax-schedule-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const FounderPrecisionBadge(
                FounderIconGlyph.taxBankDas,
                boxSize: 34,
                iconSize: 16.5,
                tintColor: FounderSovereignTokens.warmAmber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Calendário de Impostos (Simples Nacional · DAS)',
                  style: FounderSovereignTokens.titleStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vencimentos oficiais no dia 20 útil subsequente (6% calculado apenas sobre a comissão real da plataforma). Toque numa data para abrir a consulta do dia.',
            style: FounderSovereignTokens.subtitleStyle(fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < upcoming.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(
                height: 1,
                color: FounderSovereignTokens.crispBorder,
              ),
            Builder(
              builder: (context) {
                final item = upcoming[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey<String>(
                      'ceo-tax-schedule-row-${item.dueDateIso}',
                    ),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _refreshLiveSnapshot(
                      windowKey: 'day:${item.dueDateIso}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Vencimento ${item.dueDateFormattedPt} · Competência ${item.competenceLabelPt}',
                                  style: const TextStyle(
                                    color: FounderSovereignTokens.primaryInk,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.statusLabelPt,
                                  style: TextStyle(
                                    color: item.status == 'PAID'
                                        ? FounderSovereignTokens.solvencyEmerald
                                        : (item.remainingDueCents > 0
                                            ? FounderSovereignTokens.warmAmber
                                            : FounderSovereignTokens.mutedInk),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedMoneyOdometer(
                            cents: item.remainingDueCents,
                            privacyBlurActive: _privacyBlurActive,
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: item.remainingDueCents > 0
                                  ? FounderSovereignTokens.warmAmber
                                  : FounderSovereignTokens.secondaryInk,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const FounderPrecisionIcon(
                            FounderIconGlyph.chevronRight,
                            size: 15,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveMediationsLiveCard() {
    final openMeds = _snapshot.activeMediations
        .where((m) => m.isOpen)
        .toList(growable: false);
    final displayed = openMeds.isNotEmpty
        ? openMeds
        : _snapshot.activeMediations.take(4).toList();

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-active-mediations-card'),
      showTopAccentBar: openMeds.isNotEmpty,
      accentTopBarColor: FounderSovereignTokens.crimsonAlert,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FounderPrecisionIcon(
                    FounderIconGlyph.mediationBalance,
                    size: 18,
                    color: openMeds.isNotEmpty
                        ? FounderSovereignTokens.crimsonAlert
                        : FounderSovereignTokens.solvencyEmerald,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      openMeds.isNotEmpty
                          ? 'Mediações e chamados ativos (${openMeds.length})'
                          : 'Histórico recente de mediações (${displayed.length})',
                      style: FounderSovereignTokens.titleStyle(fontSize: 15.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in displayed.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey<String>('ceo-mediation-row-${m.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: m.hasLinkedOrder
                      ? () => _openOrderForensics(m.jobId!, m.orderCode)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: m.isOpen
                            ? FounderSovereignTokens.crimsonAlert
                                .withValues(alpha: 0.45)
                            : FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${m.protocolCode} · ${m.orderCode} · ${m.categoryName}',
                                style: const TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${m.phaseLabelPt} · ${m.reasonOrCategory}',
                                style: TextStyle(
                                  color: m.isOpen
                                      ? FounderSovereignTokens.warmAmber
                                      : FounderSovereignTokens.solvencyEmerald,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (m.description.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  m.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FounderSovereignTokens.mutedInk,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (m.frozenAmountCents > 0) ...<Widget>[
                          const SizedBox(width: 8),
                          AnimatedMoneyOdometer(
                            cents: m.frozenAmountCents,
                            privacyBlurActive: _privacyBlurActive,
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: FounderSovereignTokens.crimsonAlert,
                            ),
                          ),
                        ],
                        if (m.hasLinkedOrder)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: FounderPrecisionIcon(
                              FounderIconGlyph.chevronRight,
                              size: 15,
                              color: FounderSovereignTokens.mutedInk,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDreLine(
    String label,
    int signedCents,
    Color color, {
    bool bold = false,
    double? barRatio,
  }) {
    final prefix = signedCents < 0 ? '- ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                  fontSize: bold ? 14.5 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (barRatio != null && barRatio > 0) ...<Widget>[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: barRatio.clamp(0.02, 1.0),
                minHeight: 3.5,
                backgroundColor: FounderSovereignTokens.obsidianSurface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ABA 2: PEDIDOS (PEDIDOS E MAPA AO VIVO  |  BAIRROS E PROFISSÕES)
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
    final maxCatDemand = sortedCats.fold<int>(
      1,
      (prev, c) => math.max(prev, c.demandCount),
    );

    return <Widget>[
      _buildContextualPeriodBar(),
      const SizedBox(height: 12),
      AnimatedSlidingPillSwitch(
        labels: const <String>['Pedidos e Mapa', 'Bairros e Profissões'],
        precisionIcons: const <FounderIconGlyph>[
          FounderIconGlyph.radarPulse,
          FounderIconGlyph.navOrders,
        ],
        selectedIndex: _operationsSubView,
        onChanged: (idx) => setState(() => _operationsSubView = idx),
      ),
      const SizedBox(height: 14),
      if (_operationsSubView == 0) ...<Widget>[
        if (_snapshot.activeMediations.isNotEmpty) ...<Widget>[
          _buildActiveMediationsLiveCard(),
          const SizedBox(height: 14),
        ],
        StaggeredRevealItem(
          animation: anim,
          stageIndex: 0,
          child: FounderLiveGeoRadarCard(
            points: _snapshot.liveMapPoints,
            privacyBlurActive: _privacyBlurActive,
            externalStatusFilter: _ordersStatusFilter,
            onStatusFilterChanged: (next) =>
                setState(() => _ordersStatusFilter = next),
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
                Row(
                  children: <Widget>[
                    const FounderPrecisionBadge(
                      FounderIconGlyph.navOrders,
                      boxSize: 34,
                      iconSize: 16.5,
                      tintColor: FounderSovereignTokens.imperialGoldBright,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pedidos dos clientes (${filteredOrders.length})',
                        style: FounderSovereignTokens.titleStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Nenhum pedido nesta etapa no momento.',
                        textAlign: TextAlign.center,
                        style: FounderSovereignTokens.subtitleStyle(
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: <Widget>[
                      for (var i = 0;
                          i < filteredOrders.length && i < 30;
                          i++) ...<Widget>[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: FounderSovereignTokens.crispBorder,
                          ),
                        _ExecutiveOrderPipelineCard(
                          order: filteredOrders[i],
                          privacyBlurActive: _privacyBlurActive,
                          onTap: () => _openOrderForensics(
                            filteredOrders[i].jobId,
                            filteredOrders[i].orderCode,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 10),
              for (var i = 0; i < displayedCats.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(
                    height: 1,
                    color: FounderSovereignTokens.crispBorder,
                  ),
                Builder(
                  builder: (context) {
                    final c = displayedCats[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              CategoryBrandEmblem(
                                categoryName: c.categoryName,
                                size: 34,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      c.categoryName,
                                      style: const TextStyle(
                                        color: FounderSovereignTokens.primaryInk,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.demandCount} pedidos · ${c.activeProvidersCount} profissionais',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: c.isSupplyBottleneck
                                            ? FounderSovereignTokens.warmAmber
                                            : FounderSovereignTokens.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedMoneyOdometer(
                                cents: c.avgTicketCents,
                                privacyBlurActive: _privacyBlurActive,
                                style: FounderSovereignTokens.monoMetric(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: FounderSovereignTokens
                                      .imperialGoldBright,
                                ),
                              ),
                            ],
                          ),
                          if (c.demandCount > 0) ...<Widget>[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (c.demandCount / maxCatDemand)
                                    .clamp(0.05, 1.0),
                                minHeight: 4,
                                backgroundColor:
                                    FounderSovereignTokens.obsidianSurface,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  c.isSupplyBottleneck
                                      ? FounderSovereignTokens.warmAmber
                                      : FounderSovereignTokens
                                          .imperialGoldBright,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildOrderFilterChip(String code, String label) {
    final active = _ordersStatusFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _ordersStatusFilter = code);
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

  // ===========================================================================
  // ABA 3: PESSOAS (PARTIÇÃO DEMOGRÁFICA + DIRETÓRIO + AVALIAÇÕES + JORNADA)
  // ===========================================================================

  List<Widget> _buildTab3People(Animation<double> anim) {
    final d = _snapshot.demographics;
    final totalActiveModes = math.max(
      1,
      d.onlyClientsCount + d.onlyProvidersCount + d.dualModeBothCount,
    );

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'RESUMO DE PESSOAS NA PLATAFORMA',
                        style: FounderSovereignTokens.eyebrowStyle(
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.totalUsersCount} pessoas cadastradas no total',
                        style: FounderSovereignTokens.titleStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.solvencyEmeraldSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const FounderPrecisionIcon(
                          FounderIconGlyph.checkValid,
                          size: 13,
                          color: FounderSovereignTokens.solvencyEmerald,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            d.partitionInvariantOk
                                ? 'Contagem conferida'
                                : 'Revisar cadastros',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: FounderSovereignTokens.solvencyEmerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildThreeModePeopleBoxes(
                onlyClients: d.onlyClientsCount,
                onlyProviders: d.onlyProvidersCount,
                dualBoth: d.dualModeBothCount,
                total: d.totalUsersCount,
                showPercentages: true,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 7,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: math.max(
                          1,
                          ((d.onlyClientsCount * 100) / totalActiveModes)
                              .round(),
                        ),
                        child: Container(
                          color: FounderSovereignTokens.secondaryInk,
                        ),
                      ),
                      Expanded(
                        flex: math.max(
                          1,
                          ((d.onlyProvidersCount * 100) / totalActiveModes)
                              .round(),
                        ),
                        child: Container(
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      Expanded(
                        flex: math.max(
                          1,
                          ((d.dualModeBothCount * 100) / totalActiveModes)
                              .round(),
                        ),
                        child: Container(
                          color: FounderSovereignTokens.solvencyEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(
                      () => _peopleDirectoryRoleFilter = 'kyc_verified',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: FounderSovereignTokens.solvencyEmeraldSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: FounderSovereignTokens.solvencyEmerald
                              .withValues(alpha: 0.40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const FounderPrecisionIcon(
                            FounderIconGlyph.shieldVerified,
                            size: 13.5,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${d.kycVerifiedCount} documentos aprovados',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: FounderSovereignTokens.solvencyEmerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(
                      () => _peopleDirectoryRoleFilter = 'kyc_pending',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: d.kycPendingCount > 0
                            ? FounderSovereignTokens.warmAmberSoft
                            : FounderSovereignTokens.obsidianSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: d.kycPendingCount > 0
                                  ? FounderSovereignTokens.warmAmber
                                      .withValues(alpha: 0.45)
                                  : FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FounderPrecisionIcon(
                            FounderIconGlyph.clockSla,
                            size: 13.5,
                            color: d.kycPendingCount > 0
                                ? FounderSovereignTokens.warmAmber
                                : FounderSovereignTokens.mutedInk,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${d.kycPendingCount} aguardando análise ›',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: d.kycPendingCount > 0
                                    ? FounderSovereignTokens.warmAmber
                                    : FounderSovereignTokens.mutedInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (d.onboardingIncompleteCount > 0 ||
                  d.totalLgpdOffboardings > 0) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Cadastro inicial em aberto: ${d.onboardingIncompleteCount} · '
                  'Contas encerradas pelo usuário: ${d.totalLgpdOffboardings}',
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 11.5,
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
        child: FounderUsersCrmDirectoryCard(
          repository: _repo,
          privacyBlurActive: _privacyBlurActive,
          externalRoleFilter: _peopleDirectoryRoleFilter,
          onRoleFilterChanged: (next) =>
              setState(() => _peopleDirectoryRoleFilter = next),
        ),
      ),
      const SizedBox(height: 14),
      FounderGlassCard(
        key: const ValueKey<String>('ceo-real-reviews-feed-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const FounderPrecisionIcon(
                  FounderIconGlyph.starRating,
                  size: 17,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Avaliações dos atendimentos (${_snapshot.recentReviews.length})',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                ),
              ],
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
              for (var i = 0;
                  i < _snapshot.recentReviews.length && i < 15;
                  i++) ...<Widget>[
                if (i > 0)
                  const Divider(
                    height: 16,
                    color: FounderSovereignTokens.crispBorder,
                  ),
                Builder(
                  builder: (context) {
                    final rev = _snapshot.recentReviews[i];
                    return Column(
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
                    );
                  },
                ),
              ],
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
                for (var i = 0;
                    i < _snapshot.realConversionFunnel.length;
                    i++) ...<Widget>[
                  if (i > 0)
                    const Divider(
                      height: 12,
                      color: FounderSovereignTokens.crispBorder,
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _snapshot.realConversionFunnel[i].label,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${_snapshot.realConversionFunnel[i].usersCount}',
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                    ],
                  ),
                ],
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
  // ABA 4: CONTA (CARTÃO SOBERANO + AJUSTES LIMPOS + APARELHOS + SEGURANÇA)
  // ===========================================================================

  List<Widget> _buildTab4Account(Animation<double> anim) {
    final vm = _snapshot.vaultMetadata;
    final sw = _snapshot.securityWatch;

    return <Widget>[
      StaggeredRevealItem(
        animation: anim,
        stageIndex: 0,
        child: FounderCeoProfileCard(
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
      FounderSluGoLiveSemaphoreCard(
        repository: _repo,
        semaphore: _snapshot.sluGoLiveSemaphore,
        privacyBlurActive: _privacyBlurActive,
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
              Row(
                children: <Widget>[
                  const FounderPrecisionBadge(
                    FounderIconGlyph.screenCaptureShield,
                    boxSize: 34,
                    iconSize: 16.5,
                    tintColor: FounderSovereignTokens.imperialGoldBright,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Proteção da tela e atualizações',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  FounderPrecisionIcon(
                    _screenProtection.temporaryCaptureAllowed
                        ? FounderIconGlyph.vaultOpen
                        : FounderIconGlyph.shieldVerified,
                    size: 18,
                    color: _screenProtection.temporaryCaptureAllowed
                        ? FounderSovereignTokens.warmAmber
                        : FounderSovereignTokens.solvencyEmerald,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _screenProtection.temporaryCaptureAllowed
                          ? 'Prints liberados por ${_screenProtection.remainingCaptureSeconds}s'
                          : 'Bloqueio contra prints e gravações ativo',
                      style: const TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'ceo-toggle-flag-secure-btn',
                    ),
                    onPressed: _toggleTemporaryScreenCapture,
                    icon: FounderPrecisionIcon(
                      _screenProtection.temporaryCaptureAllowed
                          ? FounderIconGlyph.vaultLock
                          : FounderIconGlyph.screenCaptureShield,
                      size: 15.5,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                    label: Text(
                      _screenProtection.temporaryCaptureAllowed
                          ? 'Bloquear prints agora'
                          : 'Permitir print por 5 min',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>(
                      'ceo-manual-ota-check-btn',
                    ),
                    onPressed: _checkingOta ? null : _checkManualOtaUpdate,
                    icon: const FounderPrecisionIcon(
                      FounderIconGlyph.otaDirectUpdate,
                      size: 15.5,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                    label: Text(
                      _checkingOta
                          ? 'Procurando atualização…'
                          : 'Atualizar direto no celular',
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
                for (var i = 0; i < _snapshot.trustedDevices.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: FounderSovereignTokens.crispBorder,
                    ),
                  Builder(
                    builder: (context) {
                      final dev = _snapshot.trustedDevices[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: <Widget>[
                            FounderPrecisionIcon(
                              FounderIconGlyph.biometricId,
                              size: 19,
                              color: dev.isCurrentDevice
                                  ? FounderSovereignTokens.solvencyEmerald
                                  : FounderSovereignTokens.imperialGoldBright,
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
                                    color: FounderSovereignTokens.warmAmber,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
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
            const SizedBox(height: 8),
            _SecurityCheckRow(
              text: sw.intrusionCanariesCount == 0
                  ? 'Nenhuma tentativa de acesso indevido detectada'
                  : '${sw.intrusionCanariesCount} tentativa(s) de outro e-mail bloqueada(s)',
              ok: sw.intrusionCanariesCount == 0,
            ),
            const SizedBox(height: 8),
            _SecurityCheckRow(
              text: 'Endereços de clientes e profissionais protegidos',
              ok: sw.geoPrivacyLeakBps == 0,
            ),
            const SizedBox(height: 8),
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
                for (var i = 0;
                    i < _snapshot.recentAuditLog.length && i < 25;
                    i++) ...<Widget>[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: FounderSovereignTokens.crispBorder,
                    ),
                  Builder(
                    builder: (context) {
                      final a = _snapshot.recentAuditLog[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: <Widget>[
                            FounderPrecisionIcon(
                              a.isIntrusionCanary
                                  ? FounderIconGlyph.duressEmergencyShield
                                  : FounderIconGlyph.shieldVerified,
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
                      );
                    },
                  ),
                ],
            ],
          ),
        ),
      ],
    ];
  }
}

class _ExecutiveQuickActionPill extends StatelessWidget {
  const _ExecutiveQuickActionPill({
    required this.glyph,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final FounderIconGlyph glyph;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? FounderSovereignTokens.imperialGoldSoft
          : FounderSovereignTokens.obsidianSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: primary
                  ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.55)
                  : FounderSovereignTokens.crispBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FounderPrecisionIcon(
                glyph,
                size: 14.5,
                color: primary
                    ? FounderSovereignTokens.imperialGoldBright
                    : FounderSovereignTokens.secondaryInk,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary
                        ? FounderSovereignTokens.imperialGoldBright
                        : FounderSovereignTokens.secondaryInk,
                    fontSize: 12,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionIconBtn extends StatelessWidget {
  const _HeaderActionIconBtn({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.active = false,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? FounderSovereignTokens.imperialGoldSoft
            : FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.65)
                    : FounderSovereignTokens.crispBorder,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HeroDualColumnMetric extends StatelessWidget {
  const _HeroDualColumnMetric({
    required this.label,
    required this.cents,
    required this.valueColor,
    required this.privacyBlurActive,
    required this.caption,
    this.valueKey,
  });

  final String label;
  final int cents;
  final Color valueColor;
  final bool privacyBlurActive;
  final String caption;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FounderSovereignTokens.secondaryInk,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedMoneyOdometer(
          key: valueKey,
          cents: cents,
          privacyBlurActive: privacyBlurActive,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DemographicRoleTile extends StatelessWidget {
  const _DemographicRoleTile({
    required this.title,
    required this.count,
    required this.caption,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int count;
  final String caption;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? FounderSovereignTokens.imperialGoldSoft
          : FounderSovereignTokens.obsidianSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? FounderSovereignTokens.imperialGold
                  : FounderSovereignTokens.crispBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: FounderSovereignTokens.secondaryInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  maxLines: 1,
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveOrderPipelineCard extends StatelessWidget {
  const _ExecutiveOrderPipelineCard({
    required this.order,
    required this.privacyBlurActive,
    required this.onTap,
  });

  final OrderMicroPnlRecord order;
  final bool privacyBlurActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusCol = founderStatusColor(order.status);
    final profitCents =
        order.netMarginCents > 0 ? order.netMarginCents : order.platformFeeCents;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CategoryBrandEmblem(
                    categoryName: order.categoryName,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              order.categoryName,
                              style: const TextStyle(
                                color: FounderSovereignTokens.primaryInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                founderStatusLabelPt(order.status),
                                style: TextStyle(
                                  color: statusCol,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (order.title.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            order.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FounderSovereignTokens.secondaryInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${order.neighborhood} · ${order.orderCode} · Cliente: ${order.clientName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.providerName != null
                              ? 'Profissional: ${order.providerName}'
                              : 'Orçamentos recebidos: ${order.quotesCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    privacyBlurActive
                        ? 'Total pago: R\$ •••••'
                        : 'Total pago: ${Money.formatBrl(order.gmvCents)}'
                            '${order.materialsExemptCents > 0 ? " (${Money.formatBrl(order.materialsExemptCents)} em peças)" : ""}',
                    style: const TextStyle(
                      color: FounderSovereignTokens.secondaryInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          privacyBlurActive
                              ? 'Seu lucro: +R\$ •••'
                              : 'Seu lucro: +${Money.formatBrl(profitCents)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const FounderPrecisionIcon(
                        FounderIconGlyph.chevronRight,
                        size: 14,
                        color: FounderSovereignTokens.solvencyEmerald,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoSummaryTile extends StatelessWidget {
  const _BentoSummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.glyph,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final FounderIconGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FounderPrecisionIcon(
                  glyph,
                  size: 15,
                  color: accent,
                  accentColor: accent,
                ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: FounderSovereignTokens.monoMetric(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FounderSovereignTokens.primaryInk,
              ),
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
              FounderPrecisionIcon(
                expanded
                    ? FounderIconGlyph.chevronUp
                    : FounderIconGlyph.chevronDown,
                color: FounderSovereignTokens.imperialGoldBright,
                size: 18,
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
        FounderPrecisionIcon(
          ok ? FounderIconGlyph.checkValid : FounderIconGlyph.warningTriangle,
          size: 15.5,
          color: col,
          accentColor: col,
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

class _ConsultedDayStatPill extends StatelessWidget {
  const _ConsultedDayStatPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: FounderSovereignTokens.monoMetric(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

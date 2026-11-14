import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/utils/money.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';
import 'founder_charts_painters.dart';
import 'founder_innovations_widgets.dart';
import 'founder_sovereign_acl_panel.dart';

/// Tela Principal do Cockpit Executivo Soberano & War Room (`v2.12.0`).
///
/// Combina:
/// - Cofre Zero-Trust Step-Up no lançamento/bloqueio (`SOVEREIGN_CEO` + até 3 vagas);
/// - Auto-lock por inatividade de 10 minutos + modo Pânico/Blur (`Space` ou ícone de olho);
/// - Layout adaptativo com zero overflow em `320px @ 1.4x`, `480px` (Pocket 6 abas) e
///   `1440x900` (Widescreen Panorâmico de 3 colunas).
class FounderCockpitScreen extends StatefulWidget {
  const FounderCockpitScreen({
    super.key,
    this.repository,
    this.initialUnlockedSnapshot,
    this.inactivityTimeout = const Duration(minutes: 10),
  });

  final FounderCockpitRepository? repository;
  final FounderDashboardSnapshot? initialUnlockedSnapshot;
  final Duration inactivityTimeout;

  @override
  State<FounderCockpitScreen> createState() => _FounderCockpitScreenState();
}

class _FounderCockpitScreenState extends State<FounderCockpitScreen> {
  late final FounderCockpitRepository _repo;
  late FounderDashboardSnapshot _snapshot;
  final FocusNode _keyboardFocusNode = FocusNode();

  final TextEditingController _vaultEmailController = TextEditingController(
    text: 'wagner.ceo@desperrengue.com.br',
  );
  final TextEditingController _vaultPinController = TextEditingController(
    text: '202611',
  );

  bool _isUnlocked = false;
  bool _privacyBlurActive = false;
  int _selectedPocketTab = 0;
  String _stepUpSessionHex = 'stepup_initial_sovereign_ceo';
  String? _vaultError;
  String? _aclStatusMessage;
  Timer? _inactivityTimer;

  static const List<({String label, IconData icon})> _pocketTabs =
      <({String label, IconData icon})>[
    (label: 'Visão Geral', icon: Icons.space_dashboard_rounded),
    (label: 'DRE & Fluxo', icon: Icons.account_balance_rounded),
    (label: 'Gráficos 360°', icon: Icons.insights_rounded),
    (label: 'Inovações & IA', icon: Icons.auto_awesome_rounded),
    (label: 'Segurança & SEFAZ', icon: Icons.shield_rounded),
    (label: 'Soberania (3 Vagas)', icon: Icons.verified_user_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        FounderCockpitRepository(
          initialSnapshot: widget.initialUnlockedSnapshot,
        );
    _snapshot = widget.initialUnlockedSnapshot ?? _repo.currentSnapshot;
    _isUnlocked = widget.initialUnlockedSnapshot != null;
    if (_isUnlocked) {
      _resetInactivityTimer();
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _keyboardFocusNode.dispose();
    _vaultEmailController.dispose();
    _vaultPinController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_isUnlocked) return;
    _inactivityTimer = Timer(widget.inactivityTimeout, () {
      if (mounted && _isUnlocked) {
        setState(() {
          _isUnlocked = false;
          _vaultError = 'Sessão bloqueada automaticamente após 10 min de inatividade.';
        });
      }
    });
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    var insideEditable = false;
    ctx.visitAncestorElements((element) {
      if (element.widget is EditableText || element.widget is TextField) {
        insideEditable = true;
        return false;
      }
      return true;
    });
    return insideEditable;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _resetInactivityTimer();
    if (!_isUnlocked) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !_isEditableTextFocused()) {
      HapticFeedback.selectionClick();
      setState(() => _privacyBlurActive = !_privacyBlurActive);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _unlockVault() async {
    setState(() => _vaultError = null);
    try {
      HapticFeedback.mediumImpact();
      final session = await _repo.unlockStepUpVault(
        credentialEmail: _vaultEmailController.text,
        masterPin: _vaultPinController.text,
      );
      final fresh = await _repo.fetchCockpitSnapshot(
        stepUpCredentialHex: session.stepUpCredentialHex,
        daysWindow: _snapshot.daysWindow,
      );
      if (mounted) {
        setState(() {
          _stepUpSessionHex = session.stepUpCredentialHex;
          _snapshot = fresh;
          _isUnlocked = true;
        });
        _resetInactivityTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _vaultError = e.toString());
      }
    }
  }

  void _lockVaultNow() {
    HapticFeedback.mediumImpact();
    _inactivityTimer?.cancel();
    setState(() {
      _isUnlocked = false;
      _vaultError = null;
    });
  }

  Future<void> _handleAuthorizeDelegate({
    required String email,
    required FounderPermissionScope scope,
    required String initialPin,
  }) async {
    final updated = await _repo.authorizeDelegate(
      stepUpCredentialHex: _stepUpSessionHex,
      targetEmail: email,
      permissionScope: scope,
      initialPin: initialPin,
    );
    if (mounted) {
      setState(() {
        _snapshot = updated;
        _aclStatusMessage = 'Delegado autorizado com sucesso.';
      });
    }
  }

  Future<void> _handleRevokeDelegate(SovereignDelegateSlot slot) async {
    final updated = await _repo.revokeDelegate(
      stepUpCredentialHex: _stepUpSessionHex,
      targetUserId: slot.userId,
    );
    if (mounted) {
      setState(() {
        _snapshot = updated;
        _aclStatusMessage =
            'Kill-Switch executado na Vaga ${slot.slotIndex}/3.';
      });
    }
  }

  Future<void> _handleExecuteStrategicAction(
    String actionCode,
    Map<String, dynamic> payload,
  ) async {
    await _repo.executeStrategicAction(
      stepUpCredentialHex: _stepUpSessionHex,
      actionCode: actionCode,
      payload: payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FounderSovereignTokens.buildTheme(),
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: (_) => _resetInactivityTimer(),
          child: AppScaffold(
            backgroundColor: FounderSovereignTokens.obsidianBackground,
            body: SafeArea(
              child: _isUnlocked
                  ? _buildUnlockedCockpit(context)
                  : _buildStepUpVaultScreen(context),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ZERO-TRUST STEP-UP VAULT SCREEN
  // ==========================================================================

  Widget _buildStepUpVaultScreen(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: FounderGlassCard(
            key: const ValueKey<String>('founder-stepup-vault-card'),
            accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    const FounderSovereignCrest(size: 52, isSovereignCeo: true),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'DESPERRENGUE CEO · COFRE ZERO-TRUST',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'SOVEREIGN_CEO Vitalício + Máx. 3 Vagas Controladas',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey<String>('vault-email-field'),
                  controller: _vaultEmailController,
                  style: FounderSovereignTokens.monoMetric(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Credencial Autorizada (CEO ou Vaga 1..3)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>('vault-pin-field'),
                  controller: _vaultPinController,
                  obscureText: true,
                  style: FounderSovereignTokens.monoMetric(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'PIN Mestre Step-Up (6+ dígitos)',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _unlockVault(),
                ),
                if (_vaultError != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    key: const ValueKey<String>('vault-error-banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.crimsonAlertSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FounderSovereignTokens.crimsonAlert,
                      ),
                    ),
                    child: Text(
                      _vaultError!,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 11,
                        color: FounderSovereignTokens.crimsonAlert,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('vault-unlock-button'),
                    onPressed: _unlockVault,
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text(
                      'Desbloquear Cockpit Soberano',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ==========================================================================
  // UNLOCKED COCKPIT (WIDESCREEN >= 1180px OR POCKET 6-TAB < 1180px)
  // ==========================================================================

  Widget _buildUnlockedCockpit(BuildContext context) {
    return StaggeredEntranceOrchestrator(
      builder: (context, masterAnimation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWidescreen = constraints.maxWidth >= 1180;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildExecutiveTopBar(isWidescreen: isWidescreen),
                Expanded(
                  child: isWidescreen
                      ? _buildWidescreenThreeColumnBody(masterAnimation)
                      : _buildPocketSixTabBody(masterAnimation),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExecutiveTopBar({required bool isWidescreen}) {
    final reconOk = _snapshot.reconciliation.threeWayReconciliationOk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        border: Border(
          bottom: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FounderSovereignCrest(
                size: 32,
                isSovereignCeo: _snapshot.viewerSeatRole.isSovereignCeo,
              ),
              Text(
                'DESPERRENGUE CEO COCKPIT',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reconOk
                      ? FounderSovereignTokens.solvencyEmeraldSoft
                      : FounderSovereignTokens.crimsonAlertSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: reconOk
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.crimsonAlert,
                  ),
                ),
                child: Text(
                  reconOk
                      ? 'Conciliação Tripla: 0 centavos'
                      : 'ALERTA DIVERGÊNCIA: ${Money.formatBrl(_snapshot.reconciliation.discrepancyCents)}',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: reconOk
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.crimsonAlert,
                  ),
                ),
              ),
              if (_privacyBlurActive)
                Container(
                  key: const ValueKey<String>('founder-privacy-active-badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.crimsonAlertSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'MODO PRIVACIDADE ATIVO',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10,
                      color: FounderSovereignTokens.crimsonAlert,
                    ),
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('founder-privacy-blur-toggle'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _privacyBlurActive = !_privacyBlurActive);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _privacyBlurActive
                      ? FounderSovereignTokens.imperialGoldBright
                      : FounderSovereignTokens.primaryInk,
                  side: BorderSide(
                    color: _privacyBlurActive
                        ? FounderSovereignTokens.imperialGoldBright
                        : FounderSovereignTokens.crispBorder,
                  ),
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: Icon(
                  _privacyBlurActive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                ),
                label: Text(
                  _privacyBlurActive ? 'Mostrar Valores' : 'Blur (Space)',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('founder-lock-vault-button'),
                onPressed: _lockVaultNow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FounderSovereignTokens.crimsonAlert,
                  side: const BorderSide(
                    color: FounderSovereignTokens.crimsonAlert,
                  ),
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.lock_rounded, size: 15),
                label: const Text(
                  'Trancar',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveKpiStrip() {
    final d = _snapshot.dreCents;
    final p = _snapshot.actuarialPool;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiOdometerTile(
          title: 'GMV Bruto (${_snapshot.daysWindow}d)',
          cents: d.gmvTotalCents,
          subtitle: '${d.completedOrdersCount} OS concluídas',
          accent: FounderSovereignTokens.imperialGoldBright,
          privacyBlurActive: _privacyBlurActive,
        ),
        _KpiOdometerTile(
          title: 'Receita App (13,5% + SOS)',
          cents: d.platformGrossRevenueCents,
          subtitle: 'Base exclusiva CPC 47',
          accent: FounderSovereignTokens.cyberCyan,
          privacyBlurActive: _privacyBlurActive,
        ),
        _KpiOdometerTile(
          title: 'Lucro Líquido / EBITDA',
          cents: d.netProfitEbitdaCents,
          subtitle: d.stageGate40Reached
              ? 'Acima do Break-Even (40 OS/mês)'
              : 'Rumo a 40 OS/mês',
          accent: FounderSovereignTokens.solvencyEmerald,
          privacyBlurActive: _privacyBlurActive,
        ),
        _KpiOdometerTile(
          title: 'Fundo Garantia (1,5%)',
          cents: p.runningBalanceCents,
          subtitle:
              'ICA ${(p.icaRatioBps / 10000).toStringAsFixed(2)}x · FCR ${(p.fcrLayer1Bps / 100).toStringAsFixed(1)}%',
          accent: FounderSovereignTokens.imperialGold,
          privacyBlurActive: _privacyBlurActive,
        ),
      ],
    );
  }

  Widget _buildDreAndReconciliationCard() {
    final d = _snapshot.dreCents;
    final r = _snapshot.reconciliation;
    return FounderGlassCard(
      key: const ValueKey<String>('founder-dre-reconciliation-card'),
      accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DRE Auditada BIGINT (CPC 47 / IFRS 15) & Conciliação Tripla',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildDreLine(
            '(+) GMV Bruto Transacionado',
            d.gmvTotalCents,
            FounderSovereignTokens.imperialGoldBright,
          ),
          _buildDreLine(
            '(-) Repasse 85% Mão de Obra Técnico',
            -d.providerNetLaborCents,
            FounderSovereignTokens.royalIndigo,
          ),
          _buildDreLine(
            '(-) Reembolso 100% Peças Isento (0% Taxa c/ NF-e)',
            -d.materialsExemptCents,
            FounderSovereignTokens.cyberCyan,
          ),
          _buildDreLine(
            '(-) Destinação Pool Garantia (1,5%)',
            -d.warrantyPoolCarveoutCents,
            FounderSovereignTokens.warmAmber,
          ),
          _buildDreLine(
            '(=) Receita Bruta Tributável Plataforma (13,5% + SOS)',
            d.platformGrossRevenueCents,
            FounderSovereignTokens.imperialGold,
          ),
          _buildDreLine(
            '(-) Simples Nacional Anexo III (6% s/ 13,5%)',
            -d.simplesNacionalTaxCents,
            FounderSovereignTokens.crimsonAlert,
          ),
          _buildDreLine(
            '(-) Custos Variáveis PIX PSP & Cloud (R\$ 0,034/OS)',
            -d.variablePspAndCloudCents,
            FounderSovereignTokens.mutedInk,
          ),
          _buildDreLine(
            '(=) Margem de Contribuição Líquida',
            d.contributionMarginCents,
            FounderSovereignTokens.solvencyEmerald,
          ),
          _buildDreLine(
            '(-) OPEX Fixo Enxuto',
            -d.fixedOpexCents,
            FounderSovereignTokens.mutedInk,
          ),
          _buildDreLine(
            '(=) Lucro Líquido / EBITDA Real',
            d.netProfitEbitdaCents,
            FounderSovereignTokens.solvencyEmerald,
          ),
          const Divider(height: 16),
          Text(
            'Conciliação Tripla: PIX Confirmado (${Money.formatBrl(r.pixTopupsConfirmedCents)}) '
            '↔ Razão (${Money.formatBrl(r.ledgerNetSumCents)}) '
            '↔ Carteiras+Escrow (${Money.formatBrl(r.walletsAndEscrowTotalCents)}) · '
            'Discrepância: ${Money.formatBrl(r.discrepancyCents)}',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 11,
              color: r.threeWayReconciliationOk
                  ? FounderSovereignTokens.solvencyEmerald
                  : FounderSovereignTokens.crimsonAlert,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDreLine(String label, int signedCents, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        alignment: WrapAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: FounderSovereignTokens.primaryInk,
            ),
          ),
          AnimatedMoneyOdometer(
            cents: signedCents,
            privacyBlurActive: _privacyBlurActive,
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

  // ==========================================================================
  // WIDESCREEN 3-COLUMN EXECUTIVE COMMAND CENTER (>= 1180px)
  // ==========================================================================

  Widget _buildWidescreenThreeColumnBody(Animation<double> masterAnimation) {
    return SingleChildScrollView(
      key: const ValueKey<String>('founder-widescreen-3col-layout'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StaggeredRevealItem(
            animation: masterAnimation,
            stageIndex: 0,
            child: _buildExecutiveKpiStrip(),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Coluna 1: Finanças, DRE, Sankey, Curva-J, Custódia, Atuarial, Cascata
              Expanded(
                flex: 4,
                child: StaggeredRevealItem(
                  animation: masterAnimation,
                  stageIndex: 1,
                  child: Column(
                    children: <Widget>[
                      _buildDreAndReconciliationCard(),
                      const SizedBox(height: 14),
                      FounderSankeyMoneyFlowChart(
                        dre: _snapshot.dreCents,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderJCurveBreakEvenChart(
                        dailySeries: _snapshot.dailySeries,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderTreasuryEscrowHistogramChart(
                        treasury: _snapshot.treasury,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderActuarialSpeedometerChart(
                        pool: _snapshot.actuarialPool,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderTieredWaterfallMedalsChart(
                        waterfall: _snapshot.tieredWaterfall,
                        dre: _snapshot.dreCents,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderAccountantPackExporterWidget(
                        snapshot: _snapshot,
                        onExecuteStrategicAction: _handleExecuteStrategicAction,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Coluna 2: Demografia, AARRR, 33 Categorias, Coortes, KYC FinOps & Inovações 1..4
              Expanded(
                flex: 4,
                child: StaggeredRevealItem(
                  animation: masterAnimation,
                  stageIndex: 1,
                  child: Column(
                    children: <Widget>[
                      FounderDemographicsVennChart(
                        demographics: _snapshot.demographics,
                        animation: masterAnimation,
                      ),
                      const SizedBox(height: 14),
                      FounderPirateAarrrFunnelChart(
                        funnel: _snapshot.aarrrFunnel,
                        animation: masterAnimation,
                      ),
                      const SizedBox(height: 14),
                      FounderCategoryLiquidityBubbleChart(
                        categories: _snapshot.categoryLiquidity,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderCohortRetentionHeatmapChart(
                        cohorts: _snapshot.cohortRetention,
                        animation: masterAnimation,
                      ),
                      const SizedBox(height: 14),
                      FounderKycFinOpsThermometerChart(
                        kycFinOps: _snapshot.kycFinOps,
                        animation: masterAnimation,
                        privacyBlurActive: _privacyBlurActive,
                      ),
                      const SizedBox(height: 14),
                      FounderNeighborhoodBivariateHeatmapWidget(
                        snapshot: _snapshot,
                        privacyBlurActive: _privacyBlurActive,
                        onExecuteStrategicAction: _handleExecuteStrategicAction,
                      ),
                      const SizedBox(height: 14),
                      FounderMicroPnlOrderInspectorWidget(
                        orders: _snapshot.recentOrdersMicroPnl,
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
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Coluna 3: Segurança, SEFAZ, Sala de Guerra Silent Duress & Governança 3 Vagas
              Expanded(
                flex: 4,
                child: StaggeredRevealItem(
                  animation: masterAnimation,
                  stageIndex: 2,
                  child: Column(
                    children: <Widget>[
                      FounderSovereignAclPanel(
                        aclSummary: _snapshot.aclSeats,
                        viewerSeatRole: _snapshot.viewerSeatRole,
                        onAuthorizeDelegate: _handleAuthorizeDelegate,
                        onRevokeDelegate: _handleRevokeDelegate,
                        statusMessage: _aclStatusMessage,
                      ),
                      const SizedBox(height: 14),
                      FounderSilentDuressWarRoomWidget(
                        securityWatch: _snapshot.securityWatch,
                        onExecuteStrategicAction: _handleExecuteStrategicAction,
                      ),
                      const SizedBox(height: 14),
                      FounderAntiBypassAndSefazRadarWidget(
                        securityWatch: _snapshot.securityWatch,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // POCKET 6-TAB MODE (< 1180px — 480px MOBILE & 320px @ 1.4x TORTURE TEST)
  // ==========================================================================

  Widget _buildPocketSixTabBody(Animation<double> masterAnimation) {
    return Column(
      key: const ValueKey<String>('founder-pocket-6tab-layout'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: FounderSovereignTokens.obsidianSurface,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(_pocketTabs.length, (i) {
              final tab = _pocketTabs[i];
              final selected = _selectedPocketTab == i;
              return InkWell(
                key: ValueKey<String>('founder-tab-$i'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPocketTab = i);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? FounderSovereignTokens.imperialGold
                        : FounderSovereignTokens.obsidianCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? FounderSovereignTokens.imperialGoldBright
                          : FounderSovereignTokens.crispBorder,
                    ),
                  ),
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFF111827)
                          : FounderSovereignTokens.primaryInk,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _buildSelectedPocketTabContent(masterAnimation),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPocketTabContent(Animation<double> masterAnimation) {
    switch (_selectedPocketTab) {
      case 0:
        return Column(
          children: <Widget>[
            _buildExecutiveKpiStrip(),
            const SizedBox(height: 12),
            FounderSankeyMoneyFlowChart(
              dre: _snapshot.dreCents,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderJCurveBreakEvenChart(
              dailySeries: _snapshot.dailySeries,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderDemographicsVennChart(
              demographics: _snapshot.demographics,
              animation: masterAnimation,
            ),
          ],
        );
      case 1:
        return Column(
          children: <Widget>[
            _buildDreAndReconciliationCard(),
            const SizedBox(height: 12),
            FounderTreasuryEscrowHistogramChart(
              treasury: _snapshot.treasury,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderActuarialSpeedometerChart(
              pool: _snapshot.actuarialPool,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderAccountantPackExporterWidget(
              snapshot: _snapshot,
              onExecuteStrategicAction: _handleExecuteStrategicAction,
            ),
          ],
        );
      case 2:
        return Column(
          children: <Widget>[
            FounderSankeyMoneyFlowChart(
              dre: _snapshot.dreCents,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderJCurveBreakEvenChart(
              dailySeries: _snapshot.dailySeries,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderDemographicsVennChart(
              demographics: _snapshot.demographics,
              animation: masterAnimation,
            ),
            const SizedBox(height: 12),
            FounderPirateAarrrFunnelChart(
              funnel: _snapshot.aarrrFunnel,
              animation: masterAnimation,
            ),
            const SizedBox(height: 12),
            FounderCategoryLiquidityBubbleChart(
              categories: _snapshot.categoryLiquidity,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderTreasuryEscrowHistogramChart(
              treasury: _snapshot.treasury,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderActuarialSpeedometerChart(
              pool: _snapshot.actuarialPool,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderCohortRetentionHeatmapChart(
              cohorts: _snapshot.cohortRetention,
              animation: masterAnimation,
            ),
            const SizedBox(height: 12),
            FounderKycFinOpsThermometerChart(
              kycFinOps: _snapshot.kycFinOps,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderTieredWaterfallMedalsChart(
              waterfall: _snapshot.tieredWaterfall,
              dre: _snapshot.dreCents,
              animation: masterAnimation,
              privacyBlurActive: _privacyBlurActive,
            ),
          ],
        );
      case 3:
        return Column(
          children: <Widget>[
            FounderNeighborhoodBivariateHeatmapWidget(
              snapshot: _snapshot,
              privacyBlurActive: _privacyBlurActive,
              onExecuteStrategicAction: _handleExecuteStrategicAction,
            ),
            const SizedBox(height: 12),
            FounderMicroPnlOrderInspectorWidget(
              orders: _snapshot.recentOrdersMicroPnl,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderMonteCarloSimulatorWidget(
              snapshot: _snapshot,
              privacyBlurActive: _privacyBlurActive,
            ),
            const SizedBox(height: 12),
            FounderExecutiveCopilotWidget(snapshot: _snapshot),
          ],
        );
      case 4:
        return Column(
          children: <Widget>[
            FounderSilentDuressWarRoomWidget(
              securityWatch: _snapshot.securityWatch,
              onExecuteStrategicAction: _handleExecuteStrategicAction,
            ),
            const SizedBox(height: 12),
            FounderAntiBypassAndSefazRadarWidget(
              securityWatch: _snapshot.securityWatch,
            ),
            const SizedBox(height: 12),
            FounderAccountantPackExporterWidget(
              snapshot: _snapshot,
              onExecuteStrategicAction: _handleExecuteStrategicAction,
            ),
          ],
        );
      case 5:
      default:
        return FounderSovereignAclPanel(
          aclSummary: _snapshot.aclSeats,
          viewerSeatRole: _snapshot.viewerSeatRole,
          onAuthorizeDelegate: _handleAuthorizeDelegate,
          onRevokeDelegate: _handleRevokeDelegate,
          statusMessage: _aclStatusMessage,
        );
    }
  }
}

class _KpiOdometerTile extends StatelessWidget {
  const _KpiOdometerTile({
    required this.title,
    required this.cents,
    required this.subtitle,
    required this.accent,
    required this.privacyBlurActive,
  });

  final String title;
  final int cents;
  final String subtitle;
  final Color accent;
  final bool privacyBlurActive;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 135, maxWidth: 320),
      child: FounderGlassCard(
        padding: const EdgeInsets.all(12),
        accentTopBarColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FounderSovereignTokens.mutedInk,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedMoneyOdometer(
              cents: cents,
              privacyBlurActive: privacyBlurActive,
              style: FounderSovereignTokens.monoMetric(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: FounderSovereignTokens.primaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

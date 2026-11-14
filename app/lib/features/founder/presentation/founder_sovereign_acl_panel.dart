import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import 'founder_animations_and_shaders.dart';

/// Painel de Governança Soberana Zero-Trust (`1 CEO Vitalício + Máx. 3 Delegados`).
///
/// Espelha a trava física de kernel PostgreSQL (`private.trg_enforce_max_3_founder_delegates`
/// / `ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED`) e expõe o Kill-Switch imediato por vaga.
class FounderSovereignAclPanel extends StatefulWidget {
  const FounderSovereignAclPanel({
    super.key,
    required this.aclSummary,
    required this.viewerSeatRole,
    required this.onAuthorizeDelegate,
    required this.onRevokeDelegate,
    this.statusMessage,
  });

  final FounderSovereignAclSummary aclSummary;
  final FounderSeatRole viewerSeatRole;
  final Future<void> Function({
    required String email,
    required FounderPermissionScope scope,
    required String initialPin,
  }) onAuthorizeDelegate;
  final Future<void> Function(SovereignDelegateSlot slot) onRevokeDelegate;
  final String? statusMessage;

  @override
  State<FounderSovereignAclPanel> createState() =>
      _FounderSovereignAclPanelState();
}

class _FounderSovereignAclPanelState extends State<FounderSovereignAclPanel> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController =
      TextEditingController(text: '849201');
  FounderPermissionScope _selectedScope =
      FounderPermissionScope.readOnlyAnalytics;
  bool _busy = false;
  String? _localFeedback;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitAuthorization() async {
    if (_busy) return;
    if (!widget.viewerSeatRole.isSovereignCeo) {
      setState(() {
        _localFeedback =
            'Acesso negado: apenas SOVEREIGN_CEO pode conceder vagas.';
      });
      return;
    }
    if (widget.aclSummary.isAtHardCap) {
      setState(() {
        _localFeedback =
            'ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED: limite físico de 3 vagas atingido.';
      });
      return;
    }

    final rawEmail = _emailController.text.trim();
    final rawPin = _pinController.text.trim();
    if (rawEmail.isEmpty || !rawEmail.contains('@')) {
      setState(() {
        _localFeedback = 'Informe um endereço corporativo válido para a vaga.';
      });
      return;
    }
    if (rawPin.length < 6) {
      setState(() {
        _localFeedback = 'O PIN Mestre inicial deve conter no mínimo 6 dígitos.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _localFeedback = null;
    });
    try {
      HapticFeedback.selectionClick();
      await widget.onAuthorizeDelegate(
        email: rawEmail,
        scope: _selectedScope,
        initialPin: rawPin,
      );
      if (mounted) {
        _emailController.clear();
        setState(() {
          _localFeedback =
              'Credencial autorizada com sucesso na vaga selecionada.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFeedback = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _triggerKillSwitch(SovereignDelegateSlot slot) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _localFeedback = null;
    });
    try {
      HapticFeedback.heavyImpact();
      await widget.onRevokeDelegate(slot);
      if (mounted) {
        setState(() {
          _localFeedback =
              'Kill-Switch acionado: Vaga ${slot.slotIndex}/3 revogada imediatamente.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localFeedback = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final acl = widget.aclSummary;
    final ceo = acl.ceoSeat;
    final isCeo = widget.viewerSeatRole.isSovereignCeo;
    final atHardCap = acl.isAtHardCap;
    final effectiveBanner = _localFeedback ?? widget.statusMessage;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-sovereign-acl-panel'),
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Governança Soberana & Controle de Vagas (1 CEO + 3 Delegados)',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: atHardCap
                      ? FounderSovereignTokens.crimsonAlertSoft
                      : FounderSovereignTokens.imperialGoldSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: atHardCap
                        ? FounderSovereignTokens.crimsonAlert
                        : FounderSovereignTokens.imperialGold,
                  ),
                ),
                child: Text(
                  'Vagas Ocupadas: ${acl.activeDelegates.length}/${SovereignDelegateSlot.maxDelegates}',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: atHardCap
                        ? FounderSovereignTokens.crimsonAlert
                        : FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Sovereign CEO Card
          Container(
            key: const ValueKey<String>('acl-sovereign-ceo-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: FounderSovereignTokens.imperialGoldBright
                    .withValues(alpha: 0.65),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const FounderSovereignCrest(size: 42, isSovereignCeo: true),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      FounderSeatRole.sovereignCeo.labelPt,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ceo?.emailSnapshot ?? 'wagner.ceo@desperrengue.com.br',
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: FounderSovereignTokens.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Escopo: ${FounderPermissionScope.fullSovereign.labelPt} · Trava UNIQUE Kernel',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FounderSovereignTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Three Explicit Delegate Slot Cards (Vaga 1/3, Vaga 2/3, Vaga 3/3)
          for (var slotIdx = 1;
              slotIdx <= SovereignDelegateSlot.maxDelegates;
              slotIdx++) ...<Widget>[
            _buildDelegateSlotCard(
              slotIndex: slotIdx,
              occupant: acl.activeSlotAt(slotIdx),
              isCeoViewer: isCeo,
            ),
            const SizedBox(height: 8),
          ],

          // 3. Hard Cap Kernel Lock Banner when 3/3 occupied
          if (atHardCap) ...<Widget>[
            Container(
              key: const ValueKey<String>('acl-hard-cap-kernel-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.crimsonAlertSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crimsonAlert),
              ),
              child: Text(
                'MAX_DELEGATES = 3 · Trava Física PostgreSQL (ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED). '
                'Para autorizar outra pessoa, revogue antes uma das 3 vagas ativas via Kill-Switch.',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FounderSovereignTokens.crimsonAlert,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 4. Delegate Authorization Form (CEO only)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isCeo
                      ? 'Conceder Acesso a Vaga Disponível (${acl.remainingSlots} restante(s))'
                      : 'Modo Delegado: somente SOVEREIGN_CEO pode conceder ou revogar vagas',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isCeo
                        ? FounderSovereignTokens.primaryInk
                        : FounderSovereignTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>('acl-delegate-email-field'),
                  controller: _emailController,
                  enabled: isCeo && !atHardCap && !_busy,
                  style: FounderSovereignTokens.monoMetric(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'Credencial Corporativa do Delegado',
                    hintText: 'auditor@desperrengue.com.br',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey<String>('acl-delegate-pin-field'),
                  controller: _pinController,
                  enabled: isCeo && !atHardCap && !_busy,
                  obscureText: true,
                  style: FounderSovereignTokens.monoMetric(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'PIN Mestre Inicial (Step-Up 6+ dígitos)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: FounderPermissionScope.delegateAssignableScopes
                      .map((scope) {
                    final selected = _selectedScope == scope;
                    return InkWell(
                      key: ValueKey<String>('acl-scope-${scope.wire}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: (isCeo && !atHardCap && !_busy)
                          ? () => setState(() => _selectedScope = scope)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? FounderSovereignTokens.cyberCyanSoft
                              : FounderSovereignTokens.obsidianCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? FounderSovereignTokens.cyberCyan
                                : FounderSovereignTokens.crispBorder,
                          ),
                        ),
                        child: Text(
                          scope.labelPt,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? FounderSovereignTokens.cyberCyan
                                : FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('acl-authorize-button'),
                    onPressed: (isCeo && !atHardCap && !_busy)
                        ? _submitAuthorization
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text(
                      atHardCap
                          ? '3/3 Vagas Ocupadas (Trava Ativa)'
                          : 'Autorizar Delegado na Próxima Vaga Livre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (effectiveBanner != null && effectiveBanner.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey<String>('acl-feedback-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FounderSovereignTokens.cyberCyan),
              ),
              child: Text(
                effectiveBanner,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FounderSovereignTokens.cyberCyan,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDelegateSlotCard({
    required int slotIndex,
    required SovereignDelegateSlot? occupant,
    required bool isCeoViewer,
  }) {
    final occupied = occupant != null;
    return Container(
      key: ValueKey<String>('acl-slot-card-$slotIndex'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: occupied
              ? FounderSovereignTokens.cyberCyan.withValues(alpha: 0.6)
              : FounderSovereignTokens.crispBorder,
        ),
      ),
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
                'Vaga $slotIndex/${SovereignDelegateSlot.maxDelegates}',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: occupied
                      ? FounderSovereignTokens.cyberCyan
                      : FounderSovereignTokens.mutedInk,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: occupied
                      ? FounderSovereignTokens.solvencyEmeraldSoft
                      : FounderSovereignTokens.obsidianCard,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  occupied ? 'ATIVA' : 'LIVRE',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: occupied
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!occupied)
            const Text(
              'Assento disponível para delegação temporária ou permanente pelo CEO.',
              style: TextStyle(
                fontSize: 11.5,
                color: FounderSovereignTokens.mutedInk,
              ),
            )
          else ...<Widget>[
            Text(
              occupant.emailSnapshot,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FounderSovereignTokens.monoMetric(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: FounderSovereignTokens.primaryInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Escopo: ${occupant.permissionScope.labelPt}',
              style: const TextStyle(
                fontSize: 11.5,
                color: FounderSovereignTokens.mutedInk,
              ),
            ),
            if (isCeoViewer) ...<Widget>[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey<String>('acl-kill-switch-slot-$slotIndex'),
                  onPressed:
                      _busy ? null : () => _triggerKillSwitch(occupant),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FounderSovereignTokens.crimsonAlert,
                    side: const BorderSide(
                      color: FounderSovereignTokens.crimsonAlert,
                      width: 1.4,
                    ),
                    minimumSize: const Size.fromHeight(38),
                  ),
                  icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                  label: const Text(
                    'Revogar Acesso Agora (Kill-Switch)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

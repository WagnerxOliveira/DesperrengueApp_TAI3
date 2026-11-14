/// Painel e Modal de Perfil Soberano do CEO (`Wagner Oliveira` · `wagneroliveira2395@gmail.com`)
/// com a Cerimônia Exclusiva em 2 E-mails + Deep-Link para Troca de Senha Mestra.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../data/founder_cockpit_repository.dart';
import '../domain/ceo_smart_otp_formatter.dart';
import 'founder_animations_and_shaders.dart';

enum _ProfilePasswordChangeStep {
  idle,
  awaitingSixDigitCode,
  resetLinkEmailDispatched,
}

String _formatBrtDateTime(DateTime? utc) {
  if (utc == null) return 'Sessão atual';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  final yyyy = brt.year.toString();
  final hh = brt.hour.toString().padLeft(2, '0');
  final min = brt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy às $hh:$min BRT';
}

/// Modal executivo aberto pelo botão `Perfil CEO` no cabeçalho superior.
class FounderCeoProfileSheet extends StatelessWidget {
  const FounderCeoProfileSheet({
    super.key,
    required this.repository,
    required this.vaultMetadata,
    required this.onSignOutComplete,
  });

  final FounderCockpitRepository repository;
  final CeoVaultMetadata vaultMetadata;
  final Future<void> Function() onSignOutComplete;

  static Future<void> show(
    BuildContext context, {
    required FounderCockpitRepository repository,
    required CeoVaultMetadata vaultMetadata,
    required Future<void> Function() onSignOutComplete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.84,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.38),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.crispBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Perfil Soberano do CEO',
                            style: TextStyle(
                              color: FounderSovereignTokens.primaryInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar Perfil CEO',
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FounderCeoProfileCard(
                      repository: repository,
                      vaultMetadata: vaultMetadata,
                      onSignOutComplete: () async {
                        Navigator.of(ctx).pop();
                        await onSignOutComplete();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FounderCeoProfileCard(
      repository: repository,
      vaultMetadata: vaultMetadata,
      onSignOutComplete: onSignOutComplete,
    );
  }
}

/// Card interativo completo de Perfil do CEO + Troca de Senha Mestra em 2 E-mails.
class FounderCeoProfileCard extends StatefulWidget {
  const FounderCeoProfileCard({
    super.key,
    required this.repository,
    required this.vaultMetadata,
    required this.onSignOutComplete,
  });

  final FounderCockpitRepository repository;
  final CeoVaultMetadata vaultMetadata;
  final Future<void> Function() onSignOutComplete;

  @override
  State<FounderCeoProfileCard> createState() => _FounderCeoProfileCardState();
}

class _FounderCeoProfileCardState extends State<FounderCeoProfileCard> {
  final TextEditingController _otpController = TextEditingController();

  CeoProfileSecurityStatus? _profileStatus;
  _ProfilePasswordChangeStep _step = _ProfilePasswordChangeStep.idle;
  CeoOtpChallengeTicket? _activeOtpTicket;
  DateTime? _resetLinkExpiresAtUtc;
  int _cooldownSec = 0;
  Timer? _cooldownTimer;
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfileStatus());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.clear();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileStatus() async {
    try {
      final st = await widget.repository.fetchProfileSecurityStatus();
      if (!mounted) return;
      setState(() => _profileStatus = st);
    } catch (_) {}
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    _cooldownSec = seconds.clamp(0, 900);
    if (_cooldownSec <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldownSec <= 1) {
        t.cancel();
        setState(() => _cooldownSec = 0);
      } else {
        setState(() => _cooldownSec--);
      }
    });
  }

  Future<void> _requestFirstEmailOtp() async {
    if (_busy || _cooldownSec > 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final ticket = await widget.repository.requestProfilePasswordChangeOtp();
      if (!mounted) return;
      _otpController.clear();
      _startCooldown(ticket.nextCooldownSeconds);
      setState(() {
        _busy = false;
        _activeOtpTicket = ticket;
        _step = _ProfilePasswordChangeStep.awaitingSixDigitCode;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.retryAfterSeconds != null) {
        _startCooldown(e.retryAfterSeconds!);
      }
      setState(() {
        _busy = false;
        _errorMessage = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pasteOtpFromClipboard() async {
    if (_busy) return;
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clip?.text ?? '';
      final extracted = CeoSmartOtpExtractor.extractSixDigitClusterOrNull(raw) ??
          CeoSmartOtpExtractor.extractBestSixDigits(raw);
      if (!mounted || extracted.isEmpty) return;
      HapticFeedback.lightImpact();
      _otpController.text = extracted;
      _otpController.selection =
          TextSelection.collapsed(offset: extracted.length);
      setState(() {
        _errorMessage = null;
      });
    } catch (_) {}
  }

  Future<void> _verifyOtpAndSendSecondEmailLink() async {
    final ticket = _activeOtpTicket;
    final digits =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    if (_busy || ticket == null) return;
    if (digits.length != 6) {
      setState(() {
        _errorMessage =
            'Digite os 6 dígitos enviados para $kMonocraticCeoEmail.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    _otpController.clear();

    try {
      final expiresAt =
          await widget.repository.verifyProfileOtpAndDispatchResetLink(
        challengeId: ticket.challengeId,
        sixDigitCode: digits,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resetLinkExpiresAtUtc = expiresAt;
        _step = _ProfilePasswordChangeStep.resetLinkEmailDispatched;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _profileStatus;
    final version = st?.passwordVersion ?? 1;
    final updatedLabel = _formatBrtDateTime(
      st?.passwordUpdatedAtUtc ??
          widget.vaultMetadata.pinRotatedAt ??
          widget.vaultMetadata.pinConfiguredAt,
    );

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-monocratic-passport-card'),
      accentTopBarColor: FounderSovereignTokens.imperialGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const FounderSovereignCrest(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Wagner Oliveira · CEO Soberano',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kMonocraticCeoEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 12,
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
              _ProfilePill(
                label: 'Titularidade',
                value: 'Exclusiva 1/1 (Zero Terceiros)',
                accent: FounderSovereignTokens.solvencyEmerald,
              ),
              _ProfilePill(
                label: 'Senha Mestra Cofre',
                value: 'AES-256 · v$version',
                accent: FounderSovereignTokens.cyberCyan,
              ),
              _ProfilePill(
                label: 'Última Atualização',
                value: updatedLabel,
                accent: FounderSovereignTokens.imperialGoldBright,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_errorMessage != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.crimsonAlertSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FounderSovereignTokens.crimsonAlert),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_step == _ProfilePasswordChangeStep.idle) ...<Widget>[
            const Text(
              'Segurança da Senha de Administrador CEO: ao solicitar alteração, enviaremos um código exclusivo de 6 dígitos para o seu e-mail e, após validá-lo aqui, um segundo e-mail com botão direto que abre a tela segura de nova senha neste aplicativo.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>('ceo-profile-change-password-btn'),
                  onPressed: _busy ? null : _requestFirstEmailOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: FounderSovereignTokens.imperialGold,
                    foregroundColor: const Color(0xFF0B0F17),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0B0F17),
                          ),
                        )
                      : const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text(
                    'Alterar Minha Senha de Administrador CEO',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('ceo-signout-primary-btn'),
                  onPressed: _busy ? null : widget.onSignOutComplete,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Encerrar Sessão Completa'),
                ),
              ],
            ),
          ] else if (_step ==
              _ProfilePasswordChangeStep.awaitingSixDigitCode) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: FounderSovereignTokens.imperialGold
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _activeOtpTicket != null
                            ? 'ETAPA 1 DE 2 · PROTOCOLO #${_activeOtpTicket!.challengeRef} (10 MIN)'
                            : 'ETAPA 1 DE 2 · CÓDIGO DE 6 DÍGITOS ENVIADO',
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pasteOtpFromClipboard,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(
                          Icons.content_paste_go_rounded,
                          size: 14,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                        label: const Text(
                          'Colar código',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enviamos um código exclusivo de 6 dígitos para wagneroliveira2395@gmail.com. Digite ou cole os 6 dígitos abaixo para autorizar o envio do link seguro de troca de senha:',
                    style: TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>('ceo-profile-otp-input'),
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    inputFormatters: const <TextInputFormatter>[
                      CeoSmartSixDigitOtpInputFormatter(),
                    ],
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Código de 6 dígitos do e-mail',
                      counterText: '',
                      filled: true,
                      fillColor: FounderSovereignTokens.obsidianBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        key: const ValueKey<String>(
                          'ceo-profile-otp-verify-btn',
                        ),
                        onPressed: (_busy ||
                                CeoSmartOtpExtractor.extractBestSixDigits(
                                      _otpController.text,
                                    ).length !=
                                    6)
                            ? null
                            : _verifyOtpAndSendSecondEmailLink,
                        style: FilledButton.styleFrom(
                          backgroundColor: FounderSovereignTokens.imperialGold,
                          foregroundColor: const Color(0xFF0B0F17),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0B0F17),
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 17),
                        label: const Text(
                          'Validar 6 Dígitos e Enviar Link ao E-mail',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: (_busy || _cooldownSec > 0)
                            ? null
                            : _requestFirstEmailOtp,
                        child: Text(
                          _cooldownSec > 0
                              ? 'Reenviar em ${_cooldownSec}s'
                              : 'Reenviar código',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _otpController.clear();
                                setState(() {
                                  _step = _ProfilePasswordChangeStep.idle;
                                  _errorMessage = null;
                                });
                              },
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            Container(
              key: const ValueKey<String>('ceo-profile-link-dispatched-card'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.mark_email_read_rounded,
                        color: FounderSovereignTokens.solvencyEmerald,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ETAPA 2 DE 2 · LINK DE TROCA ENVIADO AO SEU E-MAIL',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acabamos de enviar para $kMonocraticCeoEmail o e-mail informando que a troca de senha está liberada (válido até ${_formatBrtDateTime(_resetLinkExpiresAtUtc)}). Toque no botão "Definir Nova Senha no Desperrengue CEO" dentro daquele e-mail: ele abrirá diretamente este aplicativo na tela segura de criação da sua nova Senha Mestra Forte.',
                    style: const TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12.5,
                      height: 1.48,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _step = _ProfilePasswordChangeStep.idle;
                        });
                      },
                      child: const Text('Concluído'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

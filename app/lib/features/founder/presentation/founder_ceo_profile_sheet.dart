/// Cartão e Modal de Conta Exclusiva do CEO (`Wagner Oliveira` · `wagneroliveira2395@gmail.com`)
/// — Design *Luxo Silencioso Executivo* com linguagem 100% simples e direta.
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

String _formatFriendlyBrtDate(DateTime? utc) {
  if (utc == null) return 'Ativa nesta sessão';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  final yyyy = brt.year.toString();
  final hh = brt.hour.toString().padLeft(2, '0');
  final min = brt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy às $hh:$min';
}

/// Folha deslizante aberta pelo atalho de Conta no cabeçalho superior.
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
          child: Container(
            decoration: const BoxDecoration(
              color: FounderSovereignTokens.obsidianBackground,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: FounderSovereignTokens.crispBorder),
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                FounderSovereignTokens.modalBottomSafeSpace(
                  ctx,
                  extraWhenKeyboardClosed: 24,
                ),
              ),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.crispBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Sua Conta de CEO',
                        style: FounderSovereignTokens.titleStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const FounderPrecisionIcon(
                        FounderIconGlyph.closeCross,
                        size: 18,
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

/// Cartão executivo metálico escovado de identidade do CEO + troca de senha em 2 passos.
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
      final extracted =
          CeoSmartOtpExtractor.extractSixDigitClusterOrNull(raw) ??
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
            'Digite os 6 números enviados para $kMonocraticCeoEmail.';
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

  Widget _buildTitularBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.solvencyEmeraldSoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: FounderSovereignTokens.solvencyEmerald.withValues(alpha: 0.42),
        ),
      ),
      child: const Text(
        'Titular Único',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: FounderSovereignTokens.solvencyEmerald,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = _profileStatus;
    final updatedLabel = _formatFriendlyBrtDate(
      st?.passwordUpdatedAtUtc ??
          widget.vaultMetadata.pinRotatedAt ??
          widget.vaultMetadata.pinConfiguredAt,
    );
    const passportKey = ValueKey<String>('ceo-monocratic-passport-card');

    return Container(
      key: widget.key == passportKey ? null : passportKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1C2330),
            Color(0xFF131822),
            Color(0xFF0E121A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.28),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x42000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
              final compactHeader =
                  constraints.maxWidth < 340 || textScale > 1.15;

              if (compactHeader) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const FounderSovereignCrest(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'DESPERRENGUE CEO',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FounderSovereignTokens.eyebrowStyle(
                              fontSize: 10,
                              color: FounderSovereignTokens.imperialGoldBright,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Wagner Oliveira',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FounderSovereignTokens.titleStyle(
                              fontSize: 17.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildTitularBadge(),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  const FounderSovereignCrest(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'DESPERRENGUE CEO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FounderSovereignTokens.eyebrowStyle(
                            fontSize: 10.5,
                            color: FounderSovereignTokens.imperialGoldBright,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Wagner Oliveira',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FounderSovereignTokens.titleStyle(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTitularBadge(),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            color: FounderSovereignTokens.crispBorder,
          ),
          const SizedBox(height: 12),
          const Text(
            'Fundador & CEO · Único acesso autorizado',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FounderSovereignTokens.secondaryInk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            kMonocraticCeoEmail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const FounderPrecisionIcon(
                FounderIconGlyph.shieldVerified,
                size: 14.5,
                color: FounderSovereignTokens.solvencyEmerald,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Última atualização de senha: $updatedLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: FounderSovereignTokens.crispBorder,
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.crimsonAlertSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FounderSovereignTokens.crimsonAlert
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_step == _ProfilePasswordChangeStep.idle) ...<Widget>[
            Text(
              'Confirmação rápida em 2 passos pelo seu e-mail exclusivo.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FounderSovereignTokens.subtitleStyle(fontSize: 12),
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
                    foregroundColor: const Color(0xFF0B0E14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0B0E14),
                          ),
                        )
                      : const FounderPrecisionIcon(
                          FounderIconGlyph.masterKey,
                          size: 16.5,
                          color: Color(0xFF0B0E14),
                          accentColor: Color(0xFF0B0E14),
                          duotoneAlpha: 0.14,
                        ),
                  label: const Text(
                    'Trocar minha senha',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('ceo-signout-primary-btn'),
                  onPressed: _busy ? null : widget.onSignOutComplete,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const FounderPrecisionIcon(
                    FounderIconGlyph.signOutDoor,
                    size: 16,
                    color: FounderSovereignTokens.secondaryInk,
                    accentColor: FounderSovereignTokens.mutedInk,
                  ),
                  label: const Text('Sair da conta'),
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
                      .withValues(alpha: 0.36),
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
                        'PASSO 1 DE 2 · CONFIRME SEU E-MAIL',
                        style: FounderSovereignTokens.eyebrowStyle(
                          fontSize: 10.5,
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
                        icon: const FounderPrecisionIcon(
                          FounderIconGlyph.clipboardOtp,
                          size: 14,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                        label: const Text(
                          'Colar código',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite abaixo os 6 números enviados para $kMonocraticCeoEmail:',
                    style: FounderSovereignTokens.subtitleStyle(
                      fontSize: 12.5,
                      color: FounderSovereignTokens.primaryInk,
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
                      color: FounderSovereignTokens.primaryInk,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Código de 6 números',
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
                      FilledButton(
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
                          foregroundColor: const Color(0xFF0B0E14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0B0E14),
                                ),
                              )
                            : const Text(
                                'Confirmar código',
                                style: TextStyle(
                                  fontSize: 13,
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
                              ? 'Enviar novo em ${_cooldownSec}s'
                              : 'Enviar novo código',
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
                color: FounderSovereignTokens.solvencyEmeraldSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const FounderPrecisionIcon(
                        FounderIconGlyph.mailDispatched,
                        size: 20,
                        color: FounderSovereignTokens.solvencyEmerald,
                        accentColor: FounderSovereignTokens.solvencyEmerald,
                        isActive: true,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PASSO 2 DE 2 · VERIFIQUE SEU E-MAIL',
                          style: FounderSovereignTokens.eyebrowStyle(
                            fontSize: 11,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos um e-mail para $kMonocraticCeoEmail (válido até ${_formatFriendlyBrtDate(_resetLinkExpiresAtUtc)}). Abra esse e-mail e toque no botão "Definir Nova Senha no Desperrengue CEO" — ele abrirá este aplicativo direto na tela da sua nova senha.',
                    style: const TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12.5,
                      height: 1.45,
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
                      child: const Text('Entendi'),
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

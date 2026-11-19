import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/ui/serene_route_transitions.dart';

/// Ações possíveis ao interagir com [ExistingAccountDetectedSheet].
enum ExistingAccountSheetAction {
  goToLogin,
  recoverPassword,
  useOtherEmail,
}

/// Ações possíveis ao interagir com [PendingVerificationDetectedSheet].
enum PendingVerificationSheetAction {
  resendAndVerify,
  back,
}

/// Ações possíveis ao interagir com [ExistingCpfAccountSheet].
enum ExistingCpfSheetAction {
  signOutAndGoLogin,
  reviewCpfDigits,
}

const Color _kDesperrenguePrimaryBlue = Color(0xFF003366);
const Color _kDesperrengueEmeraldInk = Color(0xFF047857);
const Color _kDesperrengueEmeraldSoft = Color(0xFFECFDF5);
const Color _kDesperrengueAmberInk = Color(0xFFB45309);
const Color _kDesperrengueAmberSoft = Color(0xFFFEF3C7);
const Color _kSheetDeepInk = Color(0xFF0F172A);
const Color _kSheetBodyInk = Color(0xFF334155);
const Color _kSheetSecondaryInk = Color(0xFF1E293B);
const Color _kSheetPillSurface = Color(0xFFF1F5F9);
const Color _kSheetPillBorder = Color(0xFFCBD5E1);
const Color _kSheetTopRim = Color(0xFFE2E8F0);
const Color _kSheetDragHandle = Color(0xFF94A3B8);

const Size _kMinTouchTarget = Size(44, 48);

ButtonStyle _primarySheetButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: _kDesperrenguePrimaryBlue,
    foregroundColor: Colors.white,
    minimumSize: _kMinTouchTarget,
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
  );
}

ButtonStyle _outlinedSheetButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _kDesperrenguePrimaryBlue,
    minimumSize: _kMinTouchTarget,
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
    side: const BorderSide(color: _kDesperrenguePrimaryBlue, width: 1.4),
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

ButtonStyle _textSheetButtonStyle() {
  return TextButton.styleFrom(
    foregroundColor: _kSheetSecondaryInk,
    minimumSize: _kMinTouchTarget,
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _SereneAccountSheetSurface extends StatelessWidget {
  const _SereneAccountSheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxSheetHeight = screenSize.height * 0.92;
    final compactWidth = screenSize.width < 360;
    const topRadius = BorderRadius.vertical(top: Radius.circular(28));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: topRadius,
            boxShadow: [
              BoxShadow(
                color: _kSheetDeepInk.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: topRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.white.withValues(alpha: 0.98),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: topRadius,
                    border: Border(
                      top: BorderSide(color: _kSheetTopRim, width: 1.2),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        compactWidth ? 18 : 24,
                        14,
                        compactWidth ? 18 : 24,
                        22,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _kSheetDragHandle.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetIdentifierPill extends StatelessWidget {
  const _SheetIdentifierPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _kSheetPillSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kSheetPillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: _kDesperrenguePrimaryBlue),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _kDesperrenguePrimaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet exibido quando o usuário tenta criar uma nova conta com um
/// e-mail que já possui cadastro confirmado no Desperrengue.
class ExistingAccountDetectedSheet extends StatelessWidget {
  const ExistingAccountDetectedSheet({
    super.key = const Key('existing-account-detected-sheet'),
    required this.email,
    this.onGoToLogin,
    this.onRecoverPassword,
    this.onUseOtherEmail,
  });

  final String email;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onRecoverPassword;
  final VoidCallback? onUseOtherEmail;

  static Future<ExistingAccountSheetAction?> show(
    BuildContext context, {
    required String email,
    VoidCallback? onGoToLogin,
    VoidCallback? onRecoverPassword,
    VoidCallback? onUseOtherEmail,
  }) {
    return showModalBottomSheet<ExistingAccountSheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: SereneModalSheetConfig.barrierColor,
      sheetAnimationStyle: SereneModalSheetConfig.sheetAnimationStyle,
      builder: (_) => ExistingAccountDetectedSheet(
        email: email,
        onGoToLogin: onGoToLogin,
        onRecoverPassword: onRecoverPassword,
        onUseOtherEmail: onUseOtherEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanEmail = email.trim();

    return _SereneAccountSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetDragHandle(),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.09),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.16),
                ),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: _kDesperrenguePrimaryBlue,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Você já possui uma conta no Desperrengue',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kDesperrenguePrimaryBlue,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          if (cleanEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SheetIdentifierPill(
              label: cleanEmail,
              icon: Icons.mail_outline_rounded,
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Este e-mail já está cadastrado na plataforma. Por segurança dos seus dados, não é possível criar um segundo cadastro para a mesma conta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _kSheetBodyInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const Key('existing-account-dual-mode-tip'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kDesperrengueEmeraldSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _kDesperrengueEmeraldInk.withValues(alpha: 0.28),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: _kDesperrengueEmeraldInk,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quer usar como Cliente e também como Profissional? Você não precisa criar outra conta! Entre na sua conta atual e alterne de perfil com apenas 1 toque.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kSheetDeepInk,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            key: const Key('btn-existing-account-go-login'),
            onPressed: () {
              if (onGoToLogin != null) {
                onGoToLogin!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(ExistingAccountSheetAction.goToLogin);
              }
            },
            style: _primarySheetButtonStyle(),
            child: const Text(
              'Entrar na minha conta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('btn-existing-account-recover-password'),
            onPressed: () {
              if (onRecoverPassword != null) {
                onRecoverPassword!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(ExistingAccountSheetAction.recoverPassword);
              }
            },
            style: _outlinedSheetButtonStyle(),
            child: const Text(
              'Esqueci minha senha',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const Key('btn-existing-account-use-other-email'),
            onPressed: () {
              if (onUseOtherEmail != null) {
                onUseOtherEmail!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(ExistingAccountSheetAction.useOtherEmail);
              }
            },
            style: _textSheetButtonStyle(),
            child: const Text(
              'Usar outro e-mail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kSheetSecondaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet exibido quando o e-mail informado já iniciou cadastro, mas
/// ainda aguarda confirmação do código de 6 dígitos (OTP).
class PendingVerificationDetectedSheet extends StatelessWidget {
  const PendingVerificationDetectedSheet({
    super.key = const Key('pending-verification-detected-sheet'),
    required this.email,
    this.onResendAndVerify,
    this.onBack,
  });

  final String email;
  final VoidCallback? onResendAndVerify;
  final VoidCallback? onBack;

  static Future<PendingVerificationSheetAction?> show(
    BuildContext context, {
    required String email,
    VoidCallback? onResendAndVerify,
    VoidCallback? onBack,
  }) {
    return showModalBottomSheet<PendingVerificationSheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: SereneModalSheetConfig.barrierColor,
      sheetAnimationStyle: SereneModalSheetConfig.sheetAnimationStyle,
      builder: (_) => PendingVerificationDetectedSheet(
        email: email,
        onResendAndVerify: onResendAndVerify,
        onBack: onBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanEmail = email.trim();

    return _SereneAccountSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetDragHandle(),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _kDesperrengueAmberSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kDesperrengueAmberInk.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.mark_email_unread_rounded,
                color: _kDesperrengueAmberInk,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confirmação de e-mail pendente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kDesperrenguePrimaryBlue,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          if (cleanEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SheetIdentifierPill(
              label: cleanEmail,
              icon: Icons.mail_outline_rounded,
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Você já iniciou seu cadastro com este e-mail, mas falta confirmar o código de 6 dígitos enviado para sua caixa de entrada.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _kSheetBodyInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            key: const Key('btn-pending-resend-and-verify'),
            onPressed: () {
              if (onResendAndVerify != null) {
                onResendAndVerify!();
              } else {
                Navigator.of(context).maybePop(
                  PendingVerificationSheetAction.resendAndVerify,
                );
              }
            },
            style: _primarySheetButtonStyle(),
            child: const Text(
              'Enviar novo código e confirmar agora',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('btn-pending-verification-back'),
            onPressed: () {
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(PendingVerificationSheetAction.back);
              }
            },
            style: _textSheetButtonStyle(),
            child: const Text(
              'Voltar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kSheetSecondaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet exibido quando um usuário autenticado com um novo e-mail
/// informa um CPF que já pertence a uma conta existente na plataforma.
class ExistingCpfAccountSheet extends StatelessWidget {
  const ExistingCpfAccountSheet({
    super.key = const Key('existing-cpf-account-sheet'),
    this.cpfMasked,
    this.onSignOutAndGoLogin,
    this.onReviewDigits,
  });

  final String? cpfMasked;
  final VoidCallback? onSignOutAndGoLogin;
  final VoidCallback? onReviewDigits;

  static Future<ExistingCpfSheetAction?> show(
    BuildContext context, {
    String? cpfMasked,
    VoidCallback? onSignOutAndGoLogin,
    VoidCallback? onReviewDigits,
  }) {
    return showModalBottomSheet<ExistingCpfSheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: SereneModalSheetConfig.barrierColor,
      sheetAnimationStyle: SereneModalSheetConfig.sheetAnimationStyle,
      builder: (_) => ExistingCpfAccountSheet(
        cpfMasked: cpfMasked,
        onSignOutAndGoLogin: onSignOutAndGoLogin,
        onReviewDigits: onReviewDigits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanCpf = cpfMasked?.trim() ?? '';

    return _SereneAccountSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetDragHandle(),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.09),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.16),
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: _kDesperrenguePrimaryBlue,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CPF já vinculado a uma conta existente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kDesperrenguePrimaryBlue,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          if (cleanCpf.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SheetIdentifierPill(
              label: 'CPF: $cleanCpf',
              icon: Icons.badge_outlined,
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Identificamos que este CPF já possui cadastro no Desperrengue. Para sua proteção contra fraudes, cada pessoa mantém uma única conta — que já libera tanto o modo Cliente quanto o modo Profissional.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _kSheetBodyInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            key: const Key('btn-cpf-conflict-go-login'),
            onPressed: () {
              if (onSignOutAndGoLogin != null) {
                onSignOutAndGoLogin!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(ExistingCpfSheetAction.signOutAndGoLogin);
              }
            },
            style: _primarySheetButtonStyle(),
            child: const Text(
              'Sair e entrar na minha conta principal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('btn-cpf-conflict-review-digits'),
            onPressed: () {
              if (onReviewDigits != null) {
                onReviewDigits!();
              } else {
                Navigator.of(
                  context,
                ).maybePop(ExistingCpfSheetAction.reviewCpfDigits);
              }
            },
            style: _outlinedSheetButtonStyle(),
            child: const Text(
              'Conferir dígitos do CPF',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

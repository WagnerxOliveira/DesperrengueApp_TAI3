import 'package:flutter/material.dart';

import '../../../core/ui/design_system/design_system.dart';

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

class _SheetIdentifierPill extends StatelessWidget {
  const _SheetIdentifierPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
          border: Border.all(color: tk.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: tk.accentInk),
              const SizedBox(width: AppSpace.s8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppType.tabular(AppType.bodySm).copyWith(
                  fontWeight: FontWeight.w700,
                  color: tk.accentInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetBadgeIcon extends StatelessWidget {
  const _SheetBadgeIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: foreground.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, color: foreground, size: 30),
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
    return AppSheet.show<ExistingAccountSheetAction>(
      context,
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
    final tk = context.tk;
    final cleanEmail = email.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        _SheetBadgeIcon(
          icon: Icons.verified_user_rounded,
          background: tk.accentSoft,
          foreground: tk.accentInk,
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          'Você já possui uma conta no Desperrengue',
          textAlign: TextAlign.center,
          style: AppType.headline.copyWith(color: tk.accentInk),
        ),
        if (cleanEmail.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          _SheetIdentifierPill(
            label: cleanEmail,
            icon: Icons.mail_outline_rounded,
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        Text(
          'Este e-mail já está cadastrado na plataforma. Por segurança dos seus dados, não é possível criar um segundo cadastro para a mesma conta.',
          textAlign: TextAlign.center,
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          key: const Key('existing-account-dual-mode-tip'),
          variant: AppCardVariant.tonal,
          color: tk.successSoft,
          borderColor: tk.successInk.withValues(alpha: 0.28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: tk.successInk,
                size: 22,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  'Quer usar como Cliente e também como Profissional? Você não precisa criar outra conta! Entre na sua conta atual e alterne de perfil com apenas 1 toque.',
                  style: AppType.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        AppButton(
          key: const Key('btn-existing-account-go-login'),
          label: 'Entrar na minha conta',
          onPressed: () {
            if (onGoToLogin != null) {
              onGoToLogin!();
            } else {
              Navigator.of(
                context,
              ).maybePop(ExistingAccountSheetAction.goToLogin);
            }
          },
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          key: const Key('btn-existing-account-recover-password'),
          label: 'Esqueci minha senha',
          variant: AppButtonVariant.secondary,
          onPressed: () {
            if (onRecoverPassword != null) {
              onRecoverPassword!();
            } else {
              Navigator.of(
                context,
              ).maybePop(ExistingAccountSheetAction.recoverPassword);
            }
          },
        ),
        const SizedBox(height: AppSpace.s8),
        AppPressScale(
          child: TextButton(
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
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, AppGeometry.minTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppGeometry.buttonRadius),
              ),
              foregroundColor: tk.accentInk,
            ),
            child: Text(
              'Usar outro e-mail',
              textAlign: TextAlign.center,
              style: AppType.button.copyWith(color: tk.accentInk),
            ),
          ),
        ),
      ],
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
    return AppSheet.show<PendingVerificationSheetAction>(
      context,
      builder: (_) => PendingVerificationDetectedSheet(
        email: email,
        onResendAndVerify: onResendAndVerify,
        onBack: onBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cleanEmail = email.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        _SheetBadgeIcon(
          icon: Icons.mark_email_unread_rounded,
          background: tk.warningSoft,
          foreground: tk.warningInk,
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          'Confirmação de e-mail pendente',
          textAlign: TextAlign.center,
          style: AppType.headline.copyWith(color: tk.accentInk),
        ),
        if (cleanEmail.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          _SheetIdentifierPill(
            label: cleanEmail,
            icon: Icons.mail_outline_rounded,
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        Text(
          'Você já iniciou seu cadastro com este e-mail, mas falta confirmar o código de 6 dígitos enviado para sua caixa de entrada.',
          textAlign: TextAlign.center,
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s24),
        AppButton(
          key: const Key('btn-pending-resend-and-verify'),
          label: 'Enviar novo código e confirmar agora',
          onPressed: () {
            if (onResendAndVerify != null) {
              onResendAndVerify!();
            } else {
              Navigator.of(context).maybePop(
                PendingVerificationSheetAction.resendAndVerify,
              );
            }
          },
        ),
        const SizedBox(height: AppSpace.s8),
        AppButton(
          key: const Key('btn-pending-verification-back'),
          label: 'Voltar',
          variant: AppButtonVariant.tertiary,
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.of(
                context,
              ).maybePop(PendingVerificationSheetAction.back);
            }
          },
        ),
      ],
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
    return AppSheet.show<ExistingCpfSheetAction>(
      context,
      builder: (_) => ExistingCpfAccountSheet(
        cpfMasked: cpfMasked,
        onSignOutAndGoLogin: onSignOutAndGoLogin,
        onReviewDigits: onReviewDigits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cleanCpf = cpfMasked?.trim() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        _SheetBadgeIcon(
          icon: Icons.shield_rounded,
          background: tk.accentSoft,
          foreground: tk.accentInk,
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          'CPF já vinculado a uma conta existente',
          textAlign: TextAlign.center,
          style: AppType.headline.copyWith(color: tk.accentInk),
        ),
        if (cleanCpf.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          _SheetIdentifierPill(
            label: 'CPF: $cleanCpf',
            icon: Icons.badge_outlined,
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        Text(
          'Identificamos que este CPF já possui cadastro no Desperrengue. Para sua proteção contra fraudes, cada pessoa mantém uma única conta — que já libera tanto o modo Cliente quanto o modo Profissional.',
          textAlign: TextAlign.center,
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s24),
        AppButton(
          key: const Key('btn-cpf-conflict-go-login'),
          label: 'Sair e entrar na minha conta principal',
          onPressed: () {
            if (onSignOutAndGoLogin != null) {
              onSignOutAndGoLogin!();
            } else {
              Navigator.of(
                context,
              ).maybePop(ExistingCpfSheetAction.signOutAndGoLogin);
            }
          },
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          key: const Key('btn-cpf-conflict-review-digits'),
          label: 'Conferir dígitos do CPF',
          variant: AppButtonVariant.secondary,
          onPressed: () {
            if (onReviewDigits != null) {
              onReviewDigits!();
            } else {
              Navigator.of(
                context,
              ).maybePop(ExistingCpfSheetAction.reviewCpfDigits);
            }
          },
        ),
      ],
    );
  }
}

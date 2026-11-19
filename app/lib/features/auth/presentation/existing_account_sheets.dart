import 'package:flutter/material.dart';

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
const Color _kDesperrengueEmerald = Color(0xFF10B981);
const Color _kDesperrengueAmber = Color(0xFFD97706);

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
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;
    final cleanEmail = email.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: _kDesperrenguePrimaryBlue,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Você já possui uma conta no Desperrengue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kDesperrenguePrimaryBlue,
                    height: 1.25,
                  ),
                ),
                if (cleanEmail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 16,
                            color: _kDesperrenguePrimaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cleanEmail,
                              overflow: TextOverflow.ellipsis,
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
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Este e-mail já está cadastrado na plataforma. Por segurança dos seus dados, não é possível criar um segundo cadastro para a mesma conta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  key: const Key('existing-account-dual-mode-tip'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kDesperrengueEmerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _kDesperrengueEmerald.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        color: _kDesperrengueEmerald,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Quer usar como Cliente e também como Profissional? Você não precisa criar outra conta! Entre na sua conta atual e alterne de perfil com apenas 1 toque.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDesperrenguePrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kDesperrenguePrimaryBlue,
                    side: const BorderSide(
                      color: _kDesperrenguePrimaryBlue,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                  ),
                  child: const Text(
                    'Usar outro e-mail',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
      builder: (_) => PendingVerificationDetectedSheet(
        email: email,
        onResendAndVerify: onResendAndVerify,
        onBack: onBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;
    final cleanEmail = email.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kDesperrengueAmber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: _kDesperrengueAmber,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Confirmação de e-mail pendente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kDesperrenguePrimaryBlue,
                    height: 1.25,
                  ),
                ),
                if (cleanEmail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    cleanEmail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kDesperrenguePrimaryBlue,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Você já iniciou seu cadastro com este e-mail, mas falta confirmar o código de 6 dígitos enviado para sua caixa de entrada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDesperrenguePrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                  ),
                  child: const Text(
                    'Voltar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
      builder: (_) => ExistingCpfAccountSheet(
        cpfMasked: cpfMasked,
        onSignOutAndGoLogin: onSignOutAndGoLogin,
        onReviewDigits: onReviewDigits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kDesperrenguePrimaryBlue.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: _kDesperrenguePrimaryBlue,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'CPF já vinculado a uma conta existente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kDesperrenguePrimaryBlue,
                    height: 1.25,
                  ),
                ),
                if (cpfMasked != null && cpfMasked!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'CPF: ${cpfMasked!.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kDesperrenguePrimaryBlue,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Identificamos que este CPF já possui cadastro no Desperrengue. Para sua proteção contra fraudes, cada pessoa mantém uma única conta — que já libera tanto o modo Cliente quanto o modo Profissional.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDesperrenguePrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kDesperrenguePrimaryBlue,
                    side: const BorderSide(
                      color: _kDesperrenguePrimaryBlue,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/welcome_cinema_tracker.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import '../../../core/ui/widgets.dart';
import '../../client/presentation/client_setup_screen.dart';
import '../../client/presentation/client_shell.dart';
import '../../home/presentation/home_screens.dart';
import '../../provider/presentation/provider_setup_screens.dart';
import '../../provider/presentation/provider_shell.dart';
import '../../shared/presentation/role_terms_acceptance_screen.dart';
import 'auth_gate.dart';
import 'account_activated_welcome_screen.dart';
import 'desperrengue_welcome_cinema_screen.dart';
import 'role_selection_screen.dart';
import 'verificacao_step6_feedback.dart';
import 'verify_approval_email_screen.dart';

/// Carrega o perfil do usuário autenticado e mostra a tela correta
/// (ver [destinationFor]), considerando o MODO escolhido na sessão
/// (o mesmo usuário pode ser cliente e profissional).
class PostAuthRouter extends StatefulWidget {
  const PostAuthRouter({super.key});

  @override
  State<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<PostAuthRouter> {
  final _session = AppSession.instance;
  UserProfile? _profile;
  UserMode? _preferred;
  bool _showPostSignupCinema = false;
  UserMode? _activationWelcomeMode;
  bool _loading = true;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _session.profileTick.addListener(_load);
  }

  @override
  void dispose() {
    _session.profileTick.removeListener(_load);
    super.dispose();
  }

  User? _safeAuthUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Recarrega o perfil sem apagar a tela atual (evita "piscar" a navegação).
  /// Offline-first: sem rede, abre com a última versão salva (se houver).
  Future<void> _load() async {
    // Cada chamada ganha um número; só a MAIS RECENTE aplica o resultado. Sem isso,
    // dois refresh seguidos (profileTick + deep link) podiam terminar fora de ordem
    // e a resposta velha sobrescrever o perfil novo.
    final ticket = ++_loadSeq;
    final user = _safeAuthUser();
    final uid = user?.id;
    final preferred = uid == null ? null : await LocalPrefs.lastProfile(uid);
    UserProfile? p;
    try {
      p = await ProfileService().fetchCurrent();
    } catch (_) {
      p = await ProfileService().cachedProfile();
    }
    var showCinema = false;
    UserMode? activationWelcome;
    if (p != null) {
      showCinema = await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
        profile: p,
        authCreatedAt: DateTime.tryParse(user?.createdAt ?? ''),
        forceSelection: _session.forceSelection.value,
      );
      // Boas-vindas pendentes: marcadas quando a tela "Verifique seu e-mail" apareceu.
      if (uid != null) {
        activationWelcome = await LocalPrefs.pendingActivationWelcome(uid);
      }
    }
    if (!mounted || ticket != _loadSeq) return;
    setState(() {
      _profile = p;
      _preferred = preferred;
      _showPostSignupCinema = showCinema;
      _activationWelcomeMode = activationWelcome;
      _loading = false;
    });
  }

  Future<void> _finishActivationWelcome() async {
    final uid = _safeAuthUser()?.id;
    if (uid != null) await LocalPrefs.clearActivationWelcome(uid);
    if (mounted) setState(() => _activationWelcomeMode = null);
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      AppRoute<void>(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      if (_loading) {
        final authUser = _safeAuthUser();
        final holdDarkCinemaBridge =
            !_session.forceSelection.value &&
            WelcomeCinemaTracker.isLikelyFreshAuthInMemory(
              userId: authUser?.id,
              authCreatedAt: DateTime.tryParse(authUser?.createdAt ?? ''),
            );
        if (holdDarkCinemaBridge) {
          return AppScaffold(
            key: const Key('post-auth-cinema-dark-bridge'),
            backgroundColor: DesperrengueBrandLogoPainter.navyDeep,
            body: Center(
              child: AppProgressRing(
                value: 0.72,
                size: 28,
                strokeWidth: 2.6,
                color: AppTokens.dark.success,
                semanticLabel: 'Preparando apresentação',
              ),
            ),
          );
        }
        return const AppScaffold(body: AppLoading());
      }
      return AppScaffold(
        body: AppErrorState(
          message:
              'Não foi possível carregar o seu perfil.\nVerifique a conexão e tente novamente.',
          retryLabel: 'Tentar novamente',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s8,
            ),
            child: AppButton(
              label: 'Sair da conta',
              variant: AppButtonVariant.tertiary,
              onPressed: _signOut,
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([_session.mode, _session.forceSelection]),
      builder: (context, _) {
        final dest = destinationFor(
          profile,
          mode: _session.mode.value,
          forceSelection: _session.forceSelection.value,
          preferred: _preferred,
        );
        return _screenFor(dest, profile);
      },
    );
  }

  Widget _screenFor(AppDestination dest, UserProfile profile) {
    final renewalTargetMode =
        _session.mode.value ??
        (profile.isProvider && !profile.isClient
            ? UserMode.provider
            : UserMode.client);
    // Sincroniza o tema do MaterialApp com o modo da tela atual.
    final wanted = switch (dest) {
      AppDestination.clientSetup ||
      AppDestination.clientTermsGate ||
      AppDestination.clientHome => UserMode.client,
      AppDestination.providerSetup ||
      AppDestination.providerTermsAndReuseGate ||
      AppDestination.kycStart ||
      AppDestination.providerHome => UserMode.provider,
      AppDestination.kycSixMonthRenewal => renewalTargetMode,
      _ => null,
    };
    if (_session.theme.value != wanted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _session.theme.value = wanted,
      );
    }
    // Boas-vindas depois de ativar a conta pelo e-mail: só quando o servidor já
    // liberou o acesso (portão aberto) e o destino é uma tela de entrada no app.
    final welcomeMode = _activationWelcomeMode;
    if (welcomeMode != null &&
        !profile.requiresApprovalEmailGate &&
        profile.verificationStatus != VerificationStatus.approvedPendingEmail &&
        (dest == AppDestination.clientHome ||
            dest == AppDestination.providerHome ||
            dest == AppDestination.providerSetup ||
            dest == AppDestination.modeSelection)) {
      return AccountActivatedWelcomeScreen(
        key: const ValueKey('account-activated-welcome'),
        profile: profile,
        mode: welcomeMode,
        onContinue: _finishActivationWelcome,
      );
    }
    switch (dest) {
      case AppDestination.modeSelection:
        final showCinema =
            _showPostSignupCinema && !_session.forceSelection.value;
        return ColoredBox(
          color: DesperrengueBrandLogoPainter.navyDeep,
          child: AnimatedSwitcher(
            duration: AppMotion.d(context, AppMotion.page),
            reverseDuration: AppMotion.d(context, AppMotion.pageReverse),
            switchInCurve: AppMotion.pageCurve,
            switchOutCurve: AppMotion.pageReverseCurve,
            transitionBuilder: (child, animation) =>
                AppRoute.buildSwitcherTransition(
                  context: context,
                  animation: animation,
                  child: child,
                ),
            child: showCinema
                ? DesperrengueWelcomeCinemaScreen(
                    key: const ValueKey('post-signup-welcome-cinema'),
                    userFirstName:
                        profile.firstName == 'você' ? '' : profile.firstName,
                    onCompleted: () async {
                      await WelcomeCinemaTracker.markCompleted(profile.id);
                      if (mounted) {
                        setState(() => _showPostSignupCinema = false);
                      }
                    },
                  )
                : RoleSelectionScreen(
                    key: const ValueKey('post-signup-role-selection'),
                    profile: profile,
                  ),
          ),
        );
      case AppDestination.clientEnroll:
        return _EnrollRunner(
          mode: UserMode.client,
          key: const ValueKey('enroll-client'),
        );
      case AppDestination.providerEnroll:
        return _EnrollRunner(
          mode: UserMode.provider,
          key: const ValueKey('enroll-provider'),
        );
      case AppDestination.clientTermsGate:
        return _onboardingThemed(
          RoleTermsAcceptanceScreen(
            profile: profile,
            mode: UserMode.client,
            isReuseFastTrack: true,
          ),
        );
      case AppDestination.providerTermsAndReuseGate:
        return _onboardingThemed(
          RoleTermsAcceptanceScreen(
            profile: profile,
            mode: UserMode.provider,
            isReuseFastTrack: true,
          ),
        );
      case AppDestination.kycSixMonthRenewal:
        return _onboardingThemed(
          ClientSetupScreen(
            profile: profile,
            targetMode: renewalTargetMode,
            isSixMonthRenewal: true,
          ),
        );
      case AppDestination.clientSetup:
        return _onboardingThemed(
          ClientSetupScreen(
            profile: profile,
            initialTermsAccepted: profile.clientTermsAccepted,
          ),
        );
      case AppDestination.clientHome:
        return _themed(UserMode.client, ClientShell(profile: profile));
      case AppDestination.kycStart:
        return _onboardingThemed(
          ClientSetupScreen(
            profile: profile,
            targetMode: UserMode.provider,
            initialTermsAccepted: profile.providerTermsAccepted,
          ),
        );
      case AppDestination.kycInReview:
        return const VerificacaoStep6FeedbackScreen();
      case AppDestination.kycApproved:
        return VerifyApprovalEmailScreen(
          profile: profile,
          mode: UserMode.provider,
          autoTriggerInitialSend: true,
        );
      case AppDestination.approvalEmailVerification:
        return VerifyApprovalEmailScreen(
          profile: profile,
          mode: renewalTargetMode,
          autoTriggerInitialSend: true,
        );
      case AppDestination.providerSetup:
        return _themed(UserMode.provider, ProviderSetupFlow(profile: profile));
      case AppDestination.providerHome:
        return _themed(UserMode.provider, ProviderShell(profile: profile));
      case AppDestination.adminHome:
        return const HomeAdminScreen();
    }
  }

  Widget _themed(UserMode mode, Widget child) => Theme(
    data: AppTheme.resolve(mode, Theme.of(context).brightness),
    child: child,
  );

  Widget _onboardingThemed(Widget child) => Theme(
    data: AppTheme.onboarding(Theme.of(context).brightness),
    child: child,
  );
}

/// Cadastra o usuário no modo escolhido e recarrega o perfil.
class _EnrollRunner extends StatefulWidget {
  const _EnrollRunner({super.key, required this.mode});

  final UserMode mode;

  @override
  State<_EnrollRunner> createState() => _EnrollRunnerState();
}

class _EnrollRunnerState extends State<_EnrollRunner> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  bool _running = false; // duplo-toque em Tentar novamente não dispara 2 cadastros

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    if (mounted && _error != null) setState(() => _error = null);
    try {
      await ProfileService().enrollMode(widget.mode);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppScaffold(
        body: AppErrorState(
          message: _error!,
          retryLabel: 'Tentar novamente',
          onRetry: _run,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s8,
            ),
            child: AppButton(
              label: 'Voltar',
              variant: AppButtonVariant.tertiary,
              onPressed: AppSession.instance.switchMode,
            ),
          ),
        ),
      );
    }
    return const AppScaffold(
      body: AppLoading(message: 'Preparando sua conta...'),
    );
  }
}

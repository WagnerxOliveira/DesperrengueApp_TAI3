import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/utils/person_name_formatter.dart';
import 'auth_gate.dart';
import 'desperrengue_welcome_cinema_screen.dart';

/// Seleção de perfil (Módulo 4): visual limpo, respiração generosa e cartões
/// com contraste AA em modo claro e escuro.
///
/// * Header mínimo: seta `<` (volta ao Login, com confirmação de saída), "Olá, [Nome]"
///   e "Como você deseja usar o Desperrengue hoje?".
/// * Dois cartões grandes, clicáveis por inteiro (InkWell + AppPressScale), sem clip-art.
/// * Selos de estado: Perfil Ativo · Criar Perfil · Termine o seu cadastro · Em análise.
/// * Tema claro/escuro via tokens (`context.tk`); sem sombra no escuro.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, this.profile});

  /// Perfil carregado (para saudação e para mostrar em quais modos já há cadastro).
  final UserProfile? profile;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _nomeUsuario = '';

  @override
  void initState() {
    super.initState();
    _obterNomeUsuario();
  }

  void _obterNomeUsuario() {
    final p = widget.profile;
    if (p != null) {
      _nomeUsuario = p.firstName;
      return;
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final fullName = user?.userMetadata?['full_name'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        _nomeUsuario = PersonNameFormatter.firstName(fullName);
      }
    } catch (_) {
      // Ambiente de teste sem Supabase inicializado.
    }
  }

  void _abrirReplayWelcomeCinema() {
    final firstName = _nomeUsuario == 'você' ? '' : _nomeUsuario;
    Navigator.of(context).push(
      AppRoute<void>(
        builder: (routeContext) => DesperrengueWelcomeCinemaScreen(
          userFirstName: firstName,
          isReplay: true,
          onCompleted: () {
            if (Navigator.of(routeContext).canPop()) {
              Navigator.of(routeContext).pop();
            }
          },
        ),
      ),
    );
  }

  // O cadastro no modo (enroll_mode) é feito pelo PostAuthRouter; aqui só
  // registramos a escolha desta sessão. Um mesmo usuário pode ser cliente
  // e profissional e alternar quando quiser.
  Future<void> _escolher(UserMode modo) async {
    AppSession.instance.choose(modo);
    ProfileService().setLastMode(modo);
  }

  void _mostrarModalSair() {
    AppSheet.show<void>(
      context,
      title: 'Deseja sair da conta?',
      subtitle:
          'Você precisará fazer login novamente com seu e-mail ou Google para acessar o Desperrengue.',
      builder: (sheetContext) {
        final tk = sheetContext.tk;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tk.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                size: 28,
                color: tk.dangerInk,
              ),
            ),
          ),
        );
      },
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        Builder(
          builder: (ctx) => AppButton(
            label: 'Sair da Conta',
            variant: AppButtonVariant.destructive,
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(ctx);
              await ProfileService().signOut();
              navigator.pushAndRemoveUntil(
                AppRoute<void>(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
          ),
        ),
      ],
    );
  }

  ModeStage _stage(UserMode mode) =>
      widget.profile?.stageOf(mode) ?? ModeStage.notEnrolled;

  /// Texto de apoio conforme o momento do usuário (primeiro acesso x já cadastrado).
  String get _intro {
    final c = _stage(UserMode.client);
    final p = _stage(UserMode.provider);
    if (c == ModeStage.notEnrolled && p == ModeStage.notEnrolled) {
      return 'Escolha como quer começar. Com o mesmo e-mail você pode ter os dois perfis e alternar quando quiser.';
    }
    if (c == ModeStage.incomplete || p == ModeStage.incomplete) {
      return 'Seu cadastro ficou pela metade. Continue de onde parou: o que você já preencheu foi salvo.';
    }
    return 'Escolha o perfil para entrar agora ou crie o que ainda não tem.';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _mostrarModalSair();
      },
      child: AppScaffold(
        backgroundColor: tk.background,
        body: Stack(
          children: [
            Positioned.fill(child: _AmbientBackground(tk: tk)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      layout.margin,
                      AppSpace.s8,
                      layout.margin,
                      AppSpace.s24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - AppSpace.s32)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  AppIconButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    tooltip: 'Voltar',
                                    color: tk.text,
                                    size: 20,
                                    onPressed: _mostrarModalSair,
                                  ),
                                  Flexible(
                                    child: AppPressScale(
                                      child: TextButton(
                                        key: const Key(
                                          'btn-replay-welcome-cinema',
                                        ),
                                        onPressed: _abrirReplayWelcomeCinema,
                                        style: TextButton.styleFrom(
                                          foregroundColor: tk.text,
                                          backgroundColor: tk.isDark
                                              ? tk.surface.withValues(
                                                  alpha: 0.9,
                                                )
                                              : tk.surface,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s16,
                                            vertical: AppSpace.s8,
                                          ),
                                          minimumSize: const Size(
                                            AppGeometry.minTarget,
                                            AppGeometry.minTarget,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppGeometry.pillRadius,
                                            ),
                                            side: BorderSide(color: tk.border),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.play_circle_outline_rounded,
                                              size: 18,
                                              color: tk.isDark
                                                  ? tk.clientAccentInk
                                                  : tk.accentInk,
                                            ),
                                            const SizedBox(width: AppSpace.s8),
                                            Flexible(
                                              child: Text(
                                                'Rever apresentação',
                                                style: AppType.caption.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: tk.text,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.s20),
                              Text(
                                _nomeUsuario.isEmpty
                                    ? 'Olá!'
                                    : 'Olá, $_nomeUsuario',
                                style: AppType.display.copyWith(color: tk.text),
                              ),
                              const SizedBox(height: AppSpace.s8),
                              Text(
                                'Como você deseja usar o Desperrengue hoje?',
                                style: AppType.title.copyWith(
                                  color: tk.textMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpace.s8),
                              Text(
                                _intro,
                                style: AppType.bodySm.copyWith(
                                  color: tk.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s24),
                          AppStagger(
                            spacing: AppSpace.s16,
                            children: [
                              _RoleCard(
                                mode: UserMode.client,
                                icon: Icons.manage_search_rounded,
                                title: 'Preciso de um serviço',
                                subtitle:
                                    'Encontre profissionais para resolver seu problema',
                                stage: _stage(UserMode.client),
                                onTap: () => _escolher(UserMode.client),
                              ),
                              _RoleCard(
                                mode: UserMode.provider,
                                icon: Icons.handyman_rounded,
                                title: 'Quero trabalhar',
                                subtitle:
                                    'Acesse seu painel, veja pedidos e gerencie ganhos',
                                stage: _stage(UserMode.provider),
                                onTap: () => _escolher(UserMode.provider),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo com dois "halos" de cor desfocados (estático: custo zero por frame).
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.tk});

  final AppTokens tk;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tk.background, tk.surface],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _Halo(
                color: tk.clientAccent.withValues(alpha: 0.14),
                size: 260,
              ),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: _Halo(
                color: tk.providerAccent.withValues(
                  alpha: tk.isDark ? 0.16 : 0.12,
                ),
                size: 300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stage,
    required this.onTap,
  });

  final UserMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final ModeStage stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final isClient = mode == UserMode.client;
    final accentFill = isClient ? tk.clientAccent : tk.providerAccent;
    final accentInk = isClient ? tk.clientAccentInk : tk.providerAccentInk;
    final onAccent = AppTokens.onColor(accentFill);
    final incomplete = stage == ModeStage.incomplete;

    final (String cta, IconData ctaIcon) = switch (stage) {
      ModeStage.notEnrolled => (
        isClient ? 'Criar conta de cliente' : 'Criar conta de profissional',
        Icons.add_circle_outline_rounded,
      ),
      ModeStage.incomplete => ('Continuar cadastro', Icons.edit_note_rounded),
      ModeStage.awaitingReview => (
        'Ver andamento',
        Icons.hourglass_top_rounded,
      ),
      ModeStage.ready => (
        isClient ? 'Entrar como cliente' : 'Entrar como profissional',
        Icons.arrow_forward_rounded,
      ),
    };

    final glass = tk.isDark
        ? tk.card.withValues(alpha: 0.82)
        : tk.card.withValues(alpha: 0.86);
    final rim = incomplete
        ? tk.warning
        : (tk.isDark ? tk.border : tk.border.withValues(alpha: 0.85));

    return Semantics(
      button: true,
      label: '$title. $cta',
      child: AppPressScale(
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppGeometry.heroRadius),
              boxShadow: tk.elevation(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppGeometry.heroRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: glass,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(AppGeometry.heroRadius),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppGeometry.heroRadius,
                        ),
                        border: Border.all(
                          color: rim,
                          width: incomplete ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpace.cardLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: AppSpace.s12,
                            runSpacing: AppSpace.s8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppGeometry.itemRadius,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentFill,
                                      Color.lerp(
                                        accentFill,
                                        tk.isDark ? tk.text : tk.brand,
                                        0.20,
                                      )!,
                                    ],
                                  ),
                                ),
                                child: Icon(icon, size: 28, color: onAccent),
                              ),
                              _StagePill(stage: stage),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s20),
                          Text(
                            title,
                            style: AppType.headline.copyWith(color: tk.text),
                          ),
                          const SizedBox(height: AppSpace.s4),
                          Text(
                            subtitle,
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                          const SizedBox(height: AppSpace.s16),
                          Row(
                            children: [
                              Icon(ctaIcon, size: 18, color: accentInk),
                              const SizedBox(width: AppSpace.s8),
                              Expanded(
                                child: Text(
                                  cta,
                                  style: AppType.bodyStrong.copyWith(
                                    color: accentInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

/// Selo de estado do perfil usando o sistema de tons do DS.
class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final ModeStage stage;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      ModeStage.ready => const AppStatusChip(
        'Perfil Ativo',
        tone: AppTone.success,
        icon: Icons.check_circle_rounded,
      ),
      ModeStage.notEnrolled => const AppStatusChip(
        'Criar Perfil',
        tone: AppTone.neutral,
        icon: Icons.radio_button_unchecked_rounded,
      ),
      ModeStage.incomplete => const AppStatusChip(
        'Termine o seu cadastro',
        tone: AppTone.warning,
        icon: Icons.edit_rounded,
      ),
      ModeStage.awaitingReview => const AppStatusChip(
        'Em análise',
        tone: AppTone.info,
        icon: Icons.schedule_rounded,
      ),
    };
  }
}

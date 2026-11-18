import '../../../core/ui/app_scaffold.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_tokens.dart';
import 'auth_gate.dart';
import 'desperrengue_welcome_cinema_screen.dart';

/// Seleção de perfil (Módulo 4): visual "clean / glassmorphism".
///
/// * Header mínimo: seta `<` (volta ao Login, com confirmação de saída), "Olá, [Nome]"
///   e "Como você deseja usar o Desperrengue hoje?".
/// * Dois cartões grandes, clicáveis por inteiro (InkWell), sem clip-art.
/// * Pílulas flutuantes no canto: 🟢 Perfil Ativo · ⚪ Criar Perfil — e, para o
///   cadastro pela metade, "Termine o seu cadastro" / "Em análise".
/// * Tema claro/escuro via tokens (`context.tk`); sem sombra no escuro.
///
/// Performance: o desfoque (BackdropFilter) fica só nos 2 cartões, cada um num
/// RepaintBoundary; o fundo é gradiente estático (não anima).
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, this.profile});

  /// Perfil carregado (para saudação e para mostrar em quais modos já há cadastro).
  final UserProfile? profile;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _nomeUsuario = '';
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _obterNomeUsuario();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
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
        _nomeUsuario = fullName.split(' ')[0];
      }
    } catch (_) {
      // Ambiente de teste sem Supabase inicializado.
    }
  }

  void _abrirReplayWelcomeCinema() {
    final firstName = _nomeUsuario == 'você' ? '' : _nomeUsuario;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            DesperrengueWelcomeCinemaScreen(
              userFirstName: firstName,
              isReplay: true,
              onCompleted: () {
                if (Navigator.of(routeContext).canPop()) {
                  Navigator.of(routeContext).pop();
                }
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
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
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final tk = sheetContext.tk;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: tk.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(Icons.logout_rounded, size: 48, color: tk.danger),
                const SizedBox(height: 16),
                Text(
                  'Deseja sair da conta?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tk.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Você precisará fazer login novamente com seu e-mail ou Google para acessar o Desperrengue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: tk.textMuted),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: tk.text,
                          side: BorderSide(color: tk.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          Navigator.pop(sheetContext);
                          await ProfileService().signOut();
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AuthGate()),
                            (route) => false,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: tk.danger,
                          foregroundColor: AppTokens.onColor(tk.danger),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sair da Conta',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
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
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final compact =
                      constraints.maxHeight < 720 || textScale > 1.2;
                  return AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, _) {
                      final rawT = disableAnimations
                          ? 1.0
                          : _entryController.value.clamp(0.0, 1.0);
                      final clientT = disableAnimations
                          ? 1.0
                          : const Interval(
                              0.0,
                              0.82,
                              curve: Curves.easeOutCubic,
                            ).transform(rawT);
                      final providerT = disableAnimations
                          ? 1.0
                          : const Interval(
                              0.18,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ).transform(rawT);

                      final clientOpacity = 0.92 + 0.08 * clientT;
                      final clientScale = 0.985 + 0.015 * clientT;
                      final providerOpacity = 0.92 + 0.08 * providerT;
                      final providerScale = 0.985 + 0.015 * providerT;

                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 16 : 20,
                          compact ? 2 : 4,
                          compact ? 16 : 20,
                          compact ? 10 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Voltar',
                                  onPressed: _mostrarModalSair,
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: tk.text,
                                  ),
                                ),
                                Flexible(
                                  child: TextButton.icon(
                                    key: const Key('btn-replay-welcome-cinema'),
                                    onPressed: _abrirReplayWelcomeCinema,
                                    style: TextButton.styleFrom(
                                      foregroundColor: tk.text,
                                      backgroundColor: tk.isDark
                                          ? tk.surface.withValues(alpha: 0.80)
                                          : tk.clientSoft
                                                .withValues(alpha: 0.55),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 10 : 12,
                                        vertical: compact ? 6 : 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        side: BorderSide(
                                          color: tk.clientAccent.withValues(
                                            alpha: tk.isDark ? 0.38 : 0.28,
                                          ),
                                        ),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: compact ? 15 : 16,
                                      color: tk.clientAccent,
                                    ),
                                    label: Text(
                                      'Como funciona',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: compact ? 11.5 : 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tk.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 2 : 4),
                            Text(
                              _nomeUsuario.isEmpty
                                  ? 'Olá!'
                                  : 'Olá, $_nomeUsuario',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 22 : 32,
                                fontWeight: FontWeight.w800,
                                color: tk.text,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: compact ? 3 : 6),
                            Text(
                              'Como você deseja usar o Desperrengue hoje?',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 14.5 : 18,
                                fontWeight: FontWeight.w600,
                                color: tk.textMuted,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 8),
                            Text(
                              _intro,
                              maxLines: compact ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11.5 : 13,
                                color: tk.textMuted,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 18),
                            Expanded(
                              child: Opacity(
                                opacity: clientOpacity,
                                child: Transform.scale(
                                  scale: clientScale,
                                  child: _RoleCard(
                                    mode: UserMode.client,
                                    icon: Icons.manage_search_rounded,
                                    title: 'Preciso de um serviço',
                                    subtitle:
                                        'Encontre profissionais para resolver seu problema',
                                    stage: _stage(UserMode.client),
                                    onTap: () => _escolher(UserMode.client),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 14),
                            Expanded(
                              child: Opacity(
                                opacity: providerOpacity,
                                child: Transform.scale(
                                  scale: providerScale,
                                  child: _RoleCard(
                                    mode: UserMode.provider,
                                    icon: Icons.handyman_rounded,
                                    title: 'Quero trabalhar',
                                    subtitle:
                                        'Acesse seu painel, veja pedidos e gerencie ganhos',
                                    stage: _stage(UserMode.provider),
                                    onTap: () => _escolher(UserMode.provider),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
            colors: [
              tk.background,
              tk.isDark ? tk.surface : const Color(0xFFF1F5FC),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _Halo(
                color: tk.clientAccent.withValues(
                  alpha: tk.isDark ? 0.16 : 0.16,
                ),
                size: 260,
              ),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: _Halo(
                color: tk.providerAccent.withValues(
                  alpha: tk.isDark ? 0.18 : 0.14,
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
    final accent = isClient ? tk.clientAccent : tk.providerAccent;
    final onAccent = AppTokens.onColor(accent);
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

    // Vidro: superfície translúcida + borda de luz. No escuro, sem sombra (elevação tonal).
    final glass = tk.isDark
        ? tk.card.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.66);
    final rim = incomplete
        ? tk.warning
        : (tk.isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.9));

    return Semantics(
      button: true,
      label: '$title. $cta',
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: tk.cardShadow(blur: 24, dy: 10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: glass,
                child: InkWell(
                  onTap: onTap,
                  child: LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final cardCompact = cardConstraints.maxHeight < 235;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: rim,
                            width: incomplete ? 1.6 : 1.2,
                          ),
                        ),
                        padding: cardCompact
                            ? const EdgeInsets.fromLTRB(16, 10, 16, 10)
                            : const EdgeInsets.fromLTRB(22, 20, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: cardCompact ? 40 : 60,
                                  height: cardCompact ? 40 : 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      cardCompact ? 12 : 18,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accent,
                                        Color.lerp(
                                          accent,
                                          tk.isDark
                                              ? Colors.white
                                              : Colors.black,
                                          0.22,
                                        )!,
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: cardCompact ? 22 : 32,
                                    color: onAccent,
                                  ),
                                ),
                                const Spacer(),
                                _StagePill(stage: stage),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: cardCompact ? 17.5 : 24,
                                fontWeight: FontWeight.w800,
                                color: tk.text,
                                height: 1.1,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: cardCompact ? 3 : 6),
                            Text(
                              subtitle,
                              maxLines: cardCompact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: cardCompact ? 11.5 : 14,
                                color: tk.textMuted,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: cardCompact ? 4 : 14),
                            Row(
                              children: [
                                Icon(
                                  ctaIcon,
                                  size: cardCompact ? 15 : 18,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    cta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: cardCompact ? 12 : 14,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

/// Pílula flutuante de estado do perfil.
class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final ModeStage stage;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (String text, Color fg, Color bg, Widget lead) = switch (stage) {
      ModeStage.ready => (
        'Perfil Ativo',
        tk.successInk,
        tk.successSoft,
        _Dot(tk.success),
      ),
      ModeStage.notEnrolled => (
        'Criar Perfil',
        tk.textMuted,
        tk.surface,
        _Dot(tk.textMuted.withValues(alpha: 0.55), ring: true),
      ),
      ModeStage.incomplete => (
        'Termine o seu cadastro',
        tk.warningInk,
        tk.warningSoft,
        Icon(Icons.edit_rounded, size: 12, color: tk.warningInk),
      ),
      ModeStage.awaitingReview => (
        'Em análise',
        tk.info,
        tk.infoSoft,
        Icon(Icons.schedule_rounded, size: 12, color: tk.info),
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lead,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.ring = false});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: ring ? Colors.transparent : color,
      border: ring ? Border.all(color: color, width: 1.6) : null,
    ),
  );
}

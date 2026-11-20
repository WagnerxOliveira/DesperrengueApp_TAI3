import 'dart:async';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/achievements.dart';
import '../../../core/models/client_achievements.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/profile_and_achievement_emblems.dart';

export '../../../core/ui/profile_and_achievement_emblems.dart';

/// Ícone semântico de cada categoria de conquista do profissional (sem colisões visuais).
IconData achievementIcon(String categoryCode) => switch (categoryCode) {
      'services' => Icons.build_circle_rounded,
      'five_star' => Icons.star_rounded,
      'punctual' => Icons.timer_rounded,
      'tidy' => Icons.business_center_rounded,
      'fair_price' => Icons.balance_rounded,
      'skilled' => Icons.diamond_rounded,
      'courteous' => Icons.volunteer_activism_rounded,
      'emergency' => Icons.crisis_alert_rounded,
      'repeat_clients' => Icons.people_alt_rounded,
      _ => Icons.emoji_events_rounded,
    };

String _resolveTrackCodeFromIcon(IconData icon) {
  if (icon == Icons.build_circle_rounded) return 'services';
  if (icon == Icons.star_rounded) return 'five_star';
  if (icon == Icons.alarm_on_rounded || icon == Icons.timer_rounded) return 'punctual';
  if (icon == Icons.cleaning_services_rounded || icon == Icons.business_center_rounded) return 'tidy';
  if (icon == Icons.handshake_rounded || icon == Icons.balance_rounded) return 'fair_price';
  if (icon == Icons.diamond_rounded) return 'skilled';
  if (icon == Icons.sentiment_satisfied_alt_rounded || icon == Icons.volunteer_activism_rounded) return 'courteous';
  if (icon == Icons.bolt_rounded || icon == Icons.crisis_alert_rounded) return 'emergency';
  if (icon == Icons.favorite_rounded || icon == Icons.people_alt_rounded) return 'repeat_clients';
  if (icon == Icons.rocket_launch_rounded) return 'firstOrder';
  if (icon == Icons.verified_user_rounded) return 'verifiedClient';
  if (icon == Icons.rate_review_rounded) return 'collaborativeReviewer';
  if (icon == Icons.home_work_rounded || icon == Icons.apartment_rounded) return 'homeMaster';
  if (icon == Icons.shield_rounded || icon == Icons.enhanced_encryption_rounded) return 'secureWallet';
  if (icon == Icons.workspace_premium_rounded) return 'loyalClient';
  return 'services';
}

/// Paleta de cada metal: (topo do degradê, base do degradê, cor do ícone), derivada dos tokens.
({Color top, Color bottom, Color ink}) tierPalette(AchievementTier t) {
  const tk = AppTokens.light;
  return switch (t) {
    AchievementTier.bronze => (
        top: Color.lerp(tk.clientAccent, tk.card, 0.35)!,
        bottom: tk.warningInk,
        ink: tk.clientAccentInk,
      ),
    AchievementTier.silver => (
        top: tk.surface,
        bottom: tk.textMuted,
        ink: tk.text,
      ),
    AchievementTier.gold => (
        top: tk.warningSoft,
        bottom: tk.star,
        ink: tk.warningInk,
      ),
    AchievementTier.platinum => (
        top: tk.securitySoft,
        bottom: tk.security,
        ink: tk.brand,
      ),
    AchievementTier.diamond => (
        top: tk.infoSoft,
        bottom: tk.info,
        ink: tk.providerAccent,
      ),
  };
}

/// Medalha vetorial forjada nativamente via GPU (`AchievementMedalForge`).
///
/// - **Bloqueada (`locked: true`)**: Padrão *Cinza Claro Prateado*, despertando o Efeito Zeigarnik.
/// - **Desbloqueada (`locked: false`)**: Medalha colorida viva com evolução geométrica
///   por nível (`Bronze` -> `Prata Viva` -> `Ouro com Louros` -> `Platina Octogonal` -> `Diamante Coroado`).
class MedalBadge extends StatelessWidget {
  const MedalBadge({
    super.key,
    required this.icon,
    required this.tier,
    this.trackCode,
    this.level = 1,
    this.size = 64,
    this.locked = false,
  });

  final IconData icon;
  final AchievementTier tier;
  final String? trackCode;
  final int level;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final code = trackCode ?? _resolveTrackCodeFromIcon(icon);
    return AchievementMedalForge(
      trackCode: code,
      tier: tier,
      level: level,
      size: size,
      locked: locked,
    );
  }
}

/// Medalha de uma conquista do profissional.
class AchievementMedal extends StatelessWidget {
  const AchievementMedal({super.key, required this.achievement, this.size = 64, this.locked = false});

  final Achievement achievement;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) => MedalBadge(
        icon: achievementIcon(achievement.category.code),
        tier: achievement.tier,
        trackCode: achievement.category.code,
        level: achievement.level,
        size: size,
        locked: locked,
      );
}

/// Medalha + título curto (listas horizontais).
class MedalTile extends StatelessWidget {
  const MedalTile({
    super.key,
    required this.icon,
    required this.tier,
    required this.title,
    this.trackCode,
    this.level = 1,
    this.size = 64,
    this.locked = false,
    this.onTap,
    this.width = 96,
  });

  final IconData icon;
  final AchievementTier tier;
  final String title;
  final String? trackCode;
  final int level;
  final double size;
  final double width;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final labelColor = locked ? tk.textMuted : tk.text;
    return Semantics(
      button: onTap != null,
      label: '$title, ${locked ? "bloqueada" : "desbloqueada"}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MedalBadge(
                  icon: icon,
                  tier: tier,
                  trackCode: trackCode,
                  level: level,
                  size: size,
                  locked: locked,
                ),
                const SizedBox(height: AppSpace.s8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(
                      fontWeight: locked ? FontWeight.w500 : FontWeight.w700,
                      height: 1.2,
                      color: labelColor,
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

/// Medalha + título de uma conquista do profissional (usada no perfil público e na trilha).
class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement, this.size = 64, this.locked = false, this.onTap, this.width = 96});

  final Achievement achievement;
  final double size;
  final double width;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MedalTile(
        icon: achievementIcon(achievement.category.code),
        tier: achievement.tier,
        trackCode: achievement.category.code,
        level: achievement.level,
        title: achievement.title,
        size: size,
        width: width,
        locked: locked,
        onTap: onTap,
      );
}

/// Carrossel horizontal com suavização lateral (`ShaderMask`) para nunca cortar
/// medalhas ou sílabas de forma brusca nas extremidades.
class _EdgeFadeMedalCarousel extends StatelessWidget {
  const _EdgeFadeMedalCarousel({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final effectiveHeight = height + ((textScale - 1.0) * 84.0).clamp(0.0, 48.0);
    final opaque = tk.background;
    final clear = opaque.withValues(alpha: 0.0);
    return SizedBox(
      height: effectiveHeight,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [clear, opaque, opaque, clear],
          stops: const [0.0, 0.03, 0.97, 1.0],
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

/// Detalhe da conquista (bottom sheet interativo ao tocar em qualquer medalha).
Future<void> showAchievementDetail(BuildContext context, Achievement a, {DateTime? unlockedAt, int? count}) {
  unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
  final unlocked = unlockedAt != null;
  return AppSheet.show<void>(
    context,
    builder: (ctx) {
      final tk = ctx.tk;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AchievementMedal(achievement: a, size: 112, locked: !unlocked),
          const SizedBox(height: AppSpace.s16),
          Text(a.title, textAlign: TextAlign.center, style: AppType.headline.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s8),
          AppStatusChip(
            '${a.category.name} • ${a.tier.label} • nível ${a.level}/10',
            tone: unlocked ? AppTone.accent : AppTone.neutral,
          ),
          const SizedBox(height: AppSpace.s12),
          Text(a.description, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
          const SizedBox(height: AppSpace.s16),
          if (unlocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: tk.successInk, size: 20),
                const SizedBox(width: AppSpace.s8),
                Flexible(
                  child: Text(
                    'Desbloqueada em ${_date(unlockedAt)}',
                    style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.successInk),
                  ),
                ),
              ],
            )
          else if (count != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpace.s8),
              child: LinearProgressIndicator(
                value: (count / a.threshold).clamp(0.0, 1.0),
                minHeight: 8,
                color: tk.accent,
                backgroundColor: tk.border,
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Faltam ${(a.threshold - count).clamp(0, a.threshold)} para desbloquear',
              style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
            ),
          ] else
            Text('Ainda não desbloqueada', style: AppType.bodyStrong.copyWith(color: tk.textMuted)),
        ],
      );
    },
  );
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Seção "Conquistas" do perfil público do profissional: melhores medalhas + botão "Ver todas".
class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.providerId, required this.providerName});

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return FutureBuilder<List<({String code, DateTime unlockedAt})>>(
      future: ProviderService().achievements(providerId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const AppSkeletonCard(height: 96);
        final list = snap.data ?? const [];
        final progress = buildProgress(list.map((e) => e.code));
        final best = [for (final c in progress) if (c.highest != null) c.highest!]..sort((a, b) => b.level.compareTo(a.level));
        final total = list.length;
        if (total == 0) {
          return Text(
            'Este profissional ainda não desbloqueou conquistas.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EdgeFadeMedalCarousel(
              height: 136,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                scrollDirection: Axis.horizontal,
                itemCount: best.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
                itemBuilder: (_, i) => AchievementTile(
                  achievement: best[i],
                  size: 58,
                  width: 96,
                  onTap: () => showAchievementDetail(context, best[i], unlockedAt: list.firstWhere((e) => e.code == best[i].code).unlockedAt),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            AppButton(
              label: 'Ver todas as conquistas ($total de ${allAchievements().length})',
              icon: Icons.emoji_events_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).push(
                AppRoute(builder: (_) => AchievementsScreen(providerId: providerId, providerName: providerName)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Todas as conquistas. [isOwner] mostra contadores e barras de progresso.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.providerId, required this.providerName, this.isOwner = false});

  final String providerId;
  final String providerName;
  final bool isOwner;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = ProviderService();
  late Future<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})> _future = _load();

  Future<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})> _load() async {
    final unlocked = await _service.achievements(widget.providerId);
    Map<String, int>? counts;
    if (widget.isOwner) {
      try {
        counts = await _service.myAchievementCounts();
      } catch (_) {}
    }
    return (unlocked: unlocked, counts: counts);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: AppAppBar(title: widget.isOwner ? 'Minhas conquistas' : 'Conquistas de ${widget.providerName.split(' ').first}'),
      body: FutureBuilder<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 4);
          if (snap.hasError) {
            return AppErrorState(message: 'Não foi possível carregar as conquistas.', onRetry: _reload);
          }
          final unlocked = snap.data!.unlocked;
          final counts = snap.data!.counts;
          final dates = {for (final u in unlocked) u.code: u.unlockedAt};
          final progress = buildProgress(dates.keys, counts: counts);
          final total = allAchievements().length;
          final last = unlocked.isEmpty ? null : achievementFromCode(unlocked.first.code);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
              children: [
                _Summary(unlocked: unlocked.length, total: total, last: last),
                const SizedBox(height: AppSpace.s16),
                for (final cp in progress) _CategoryCard(cp: cp, dates: dates, isOwner: widget.isOwner),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.unlocked, required this.total, this.last, this.lastTitle, this.emptyHint});

  final int unlocked;
  final int total;
  final Achievement? last;
  final String? lastTitle;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Row(
        children: [
          AppProgressRing(
            value: total == 0 ? 0 : unlocked / total,
            size: 86,
            strokeWidth: 8,
            color: tk.accent,
            semanticLabel: 'Conquistas desbloqueadas: $unlocked de $total',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$unlocked',
                  style: AppType.tabular(AppType.headline).copyWith(color: tk.text, height: 1.0),
                ),
                Text(
                  'de $total',
                  style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conquistas desbloqueadas', style: AppType.titleSm.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s4),
                Text(
                  (last == null && lastTitle == null)
                      ? (emptyHint ?? 'Conclua serviços e receba avaliações para desbloquear as primeiras.')
                      : 'Mais recente: ${last?.title ?? lastTitle}',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cp, required this.dates, required this.isOwner});

  final CategoryProgress cp;
  final Map<String, DateTime> dates;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final next = cp.next;
    final progress = cp.progressToNext;
    final hasAny = cp.unlockedLevels.isNotEmpty;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementTrackHeaderEmblem(trackCode: cp.category.code, size: 30),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: Text(cp.category.name, style: AppType.titleSm.copyWith(color: tk.text))),
              const SizedBox(width: AppSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                decoration: BoxDecoration(
                  color: hasAny ? tk.accentSoft : tk.surface,
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                ),
                child: Text(
                  '${cp.unlockedLevels.length}/${kAchievementThresholds.length}',
                  style: AppType.tabular(AppType.caption).copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasAny ? tk.accentInk : tk.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          _EdgeFadeMedalCarousel(
            height: 136,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
              scrollDirection: Axis.horizontal,
              itemCount: kAchievementThresholds.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (_, i) {
                final a = Achievement(cp.category, kAchievementThresholds[i]);
                final isUnlocked = cp.unlockedLevels.contains(a.threshold);
                return AchievementTile(
                  achievement: a,
                  size: 56,
                  width: 92,
                  locked: !isUnlocked,
                  onTap: () => showAchievementDetail(context, a, unlockedAt: dates[a.code], count: cp.count),
                );
              },
            ),
          ),
          if (isOwner && next != null) ...[
            const SizedBox(height: AppSpace.s12),
            Text('Próxima: ${next.title}', style: AppType.bodySm.copyWith(fontWeight: FontWeight.w700, color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpace.s8),
              child: LinearProgressIndicator(
                value: progress ?? 0,
                minHeight: 8,
                color: tk.accent,
                backgroundColor: tk.border,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              cp.count == null ? '' : '${Achievement.formatCount(cp.count!)} / ${Achievement.formatCount(next.threshold)}',
              style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
            ),
          ] else if (isOwner && next == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s12),
              child: Text('Categoria completa!', style: AppType.bodyStrong.copyWith(color: tk.successInk)),
            ),
        ],
      ),
    );
  }
}

/// Cores do cartão "Conquista desbloqueada". Escuro: superfície #1E1E24 com rótulo
/// âmbar #F5B041, título branco e subtítulo nos tokens; claro: superfície creme com
/// rótulo âmbar escuro #8A5A00 e textos dos tokens. Todos os pares >= 4,5:1 (WCAG),
/// verificado em `test/completion_redesign_test.dart`.
typedef AchievementCardColors = ({Color surface, Color label, Color title, Color subtitle});

AchievementCardColors achievementCardColors(AppTokens tk) {
  if (tk.isDark) {
    const surface = Color(0xFF1E1E24);
    return (
      surface: surface,
      label: const Color(0xFFF5B041),
      title: AppTokens.onColor(surface),
      subtitle: tk.textMuted,
    );
  }
  return (
    surface: Color.lerp(tk.warningSoft, tk.card, 0.65)!,
    label: const Color(0xFF8A5A00),
    title: tk.text,
    subtitle: tk.textMuted,
  );
}

/// Borda em degradê bronze/dourado metálico do cartão de conquista, derivada dos tokens.
final List<Color> kAchievementBorderGradient = [
  Color.lerp(AppTokens.light.clientAccent, AppTokens.light.card, 0.35)!,
  AppTokens.light.warning,
  AppTokens.light.warningInk,
  AppTokens.light.star,
];

/// Hero de sucesso: halo suave em degradê verde-esmeralda → azul com o ícone no centro.
/// Estático (sem animação).
class SuccessHeroHalo extends StatelessWidget {
  const SuccessHeroHalo({super.key, this.icon = Icons.verified_rounded, this.size = 128});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final core = size * 0.66;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tk.success.withValues(alpha: 0.28), tk.info.withValues(alpha: 0.18)],
              ),
            ),
          ),
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tk.success.withValues(alpha: 0.30), tk.info.withValues(alpha: 0.26)],
              ),
            ),
          ),
          Container(
            width: core,
            height: core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tk.success, tk.info],
              ),
            ),
            child: Icon(icon, size: core * 0.58, color: AppTokens.onColor(tk.info)),
          ),
        ],
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * dx, 0, 0);
}

/// Cartão "CONQUISTA DESBLOQUEADA": superfície elevada com borda em degradê metálico,
/// entrada discreta (escala + fade, 600 ms `easeOutBack`), UM brilho passando sobre a
/// medalha e um único `mediumImpact`. Sem loops. Animação reduzida → sem entrada nem brilho.
class AchievementUnlockedCard extends StatefulWidget {
  const AchievementUnlockedCard({super.key, required this.achievement});

  final Achievement achievement;

  @override
  State<AchievementUnlockedCard> createState() => _AchievementUnlockedCardState();
}

class _AchievementUnlockedCardState extends State<AchievementUnlockedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  static const _shineWindow = Interval(0.3, 1.0, curve: Curves.easeInOut);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !AppMotion.reduced(context)) {
      _started = true;
      _shine.forward();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final tk = context.tk;
    final c = achievementCardColors(tk);
    final reduce = AppMotion.reduced(context);
    final shine = AppTokens.light.card;

    final medal = AnimatedBuilder(
      animation: _shine,
      child: AchievementMedal(achievement: a, size: 56),
      builder: (context, child) {
        if (reduce || _shine.isDismissed || _shine.isCompleted) return child!;
        final t = _shineWindow.transform(_shine.value);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [shine.withValues(alpha: 0.0), shine.withValues(alpha: 0.85), shine.withValues(alpha: 0.0)],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(1.4 * t - 0.7),
          ).createShader(rect),
          child: child,
        );
      },
    );

    final card = Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kAchievementBorderGradient),
        boxShadow: tk.elevation(1),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AppGeometry.cardRadius - 1.6)),
        child: Row(
          children: [
            medal,
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONQUISTA DESBLOQUEADA', style: AppType.overline.copyWith(color: c.label)),
                  const SizedBox(height: AppSpace.s4),
                  Text(a.title, style: AppType.titleSm.copyWith(color: c.title)),
                  const SizedBox(height: AppSpace.s2),
                  Text('${a.category.name} • Nível ${a.tier.label}', style: AppType.caption.copyWith(color: c.subtitle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1.0 : 0.0, end: 1.0),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      child: card,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
      ),
    );
  }
}

/// Cartões "Conquista desbloqueada!" (tela de serviço finalizado do profissional).
class NewAchievementsBanner extends StatelessWidget {
  const NewAchievementsBanner({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final a in achievements)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: AchievementUnlockedCard(key: ValueKey(a.code), achievement: a),
          ),
      ],
    );
  }
}

// ============================================================================
// Conquistas do CLIENTE — mesmo estilo das conquistas do profissional
// ============================================================================

/// Carrega o que as conquistas do cliente precisam (produção: pedidos + avaliações dadas +
/// contestações). Falhas parciais viram "vazio" para nunca derrubar a tela.
typedef ClientAchievementsLoader = Future<ClientAchievementInput> Function();

Future<ClientAchievementInput> loadClientAchievementInput(UserProfile profile) async {
  final jobs = JobService();
  final list = await jobs.fetchMyJobs();
  Future<Set<String>> safe(Future<Set<String>> f) async {
    try {
      return await f;
    } catch (_) {
      return <String>{};
    }
  }

  final reviewed = await safe(jobs.myGivenReviewJobIds());
  final contested = await safe(jobs.myContestedJobIds());
  return ClientAchievementInput(
    jobs: list,
    profileSteps: profileCompletionSteps(profile),
    reviewedJobIds: reviewed,
    contestedJobIds: contested,
  );
}

IconData clientAchievementIcon(ClientAchievementCode c) => switch (c) {
      ClientAchievementCode.firstOrder => Icons.rocket_launch_rounded,
      ClientAchievementCode.verifiedClient => Icons.verified_user_rounded,
      ClientAchievementCode.collaborativeReviewer => Icons.rate_review_rounded,
      ClientAchievementCode.homeMaster => Icons.apartment_rounded,
      ClientAchievementCode.secureWallet => Icons.enhanced_encryption_rounded,
      ClientAchievementCode.loyalClient => Icons.workspace_premium_rounded,
    };

/// "Minhas conquistas" do CLIENTE: resumo + um cartão por conquista com as medalhas de cada
/// nível (bronze → diamante) e a barra rumo à próxima — igual à tela do profissional.
class ClientAchievementsScreen extends StatefulWidget {
  const ClientAchievementsScreen({super.key, required this.profile, @visibleForTesting this.loader});

  final UserProfile profile;
  final ClientAchievementsLoader? loader;

  @override
  State<ClientAchievementsScreen> createState() => _ClientAchievementsScreenState();
}

class _ClientAchievementsScreenState extends State<ClientAchievementsScreen> {
  late Future<ClientAchievementInput> _future = _load();

  Future<ClientAchievementInput> _load() => widget.loader != null ? widget.loader!() : loadClientAchievementInput(widget.profile);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Minhas conquistas'),
      body: FutureBuilder<ClientAchievementInput>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 4);
          if (snap.hasError) {
            return AppErrorState(message: 'Não foi possível carregar as conquistas.', onRetry: _reload);
          }
          final progress = computeClientAchievements(snap.data!);
          final unlocked = progress.fold<int>(0, (a, p) => a + p.unlockedCount);
          final last = progress.where((p) => p.highest != null).fold<ClientLevel?>(null, (best, p) {
            final h = p.highest!;
            return best == null || h.tier.index >= best.tier.index ? h : best;
          });
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
              children: [
                _Summary(
                  unlocked: unlocked,
                  total: kClientMedalTotal,
                  last: null,
                  lastTitle: last?.title,
                  emptyHint: 'Faça pedidos, avalie e complete o perfil para desbloquear as primeiras.',
                ),
                const SizedBox(height: AppSpace.s16),
                for (final p in progress) ClientAchievementCard(progress: p),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Cartão de uma conquista do cliente: emblema, nome, "x/y níveis", medalhas e a próxima meta.
class ClientAchievementCard extends StatelessWidget {
  const ClientAchievementCard({super.key, required this.progress});

  final ClientAchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final def = progress.def;
    final tk = context.tk;
    final next = progress.next;
    final hasAny = progress.unlockedCount > 0;
    return AppCard(
      key: ValueKey('client-ach:${def.code.name}'),
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementTrackHeaderEmblem(trackCode: def.code.name, size: 30),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: Text(def.name, style: AppType.titleSm.copyWith(color: tk.text))),
              const SizedBox(width: AppSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                decoration: BoxDecoration(
                  color: hasAny ? tk.accentSoft : tk.surface,
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                ),
                child: Text(
                  '${progress.unlockedCount}/${def.levels.length}',
                  style: AppType.tabular(AppType.caption).copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasAny ? tk.accentInk : tk.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(def.title, style: AppType.bodySm.copyWith(fontWeight: FontWeight.w600, color: tk.textMuted)),
          const SizedBox(height: AppSpace.s12),
          _EdgeFadeMedalCarousel(
            height: 136,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
              scrollDirection: Axis.horizontal,
              itemCount: def.levels.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (_, i) {
                final l = def.levels[i];
                final isUnlocked = progress.current >= l.threshold;
                return MedalTile(
                  icon: clientAchievementIcon(def.code),
                  tier: l.tier,
                  trackCode: def.code.name,
                  level: i + 1,
                  title: l.title,
                  size: 56,
                  width: 92,
                  locked: !isUnlocked,
                  onTap: () => _showLevelDetail(context, progress, l, i + 1, isUnlocked),
                );
              },
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpace.s12),
            Text('Próxima: ${next.title}', style: AppType.bodySm.copyWith(fontWeight: FontWeight.w700, color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpace.s8),
              child: LinearProgressIndicator(
                value: progress.fractionToNext,
                minHeight: 8,
                color: tk.accent,
                backgroundColor: tk.border,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              '${progress.current} / ${next.threshold} ${def.unit}',
              style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s12),
              child: Text('Categoria completa!', style: AppType.bodyStrong.copyWith(color: tk.successInk)),
            ),
        ],
      ),
    );
  }

  void _showLevelDetail(BuildContext context, ClientAchievementProgress p, ClientLevel l, int levelIndex, bool unlocked) {
    unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
    final def = p.def;
    AppSheet.show<void>(
      context,
      builder: (ctx) {
        final tk = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MedalBadge(
              icon: clientAchievementIcon(def.code),
              tier: l.tier,
              trackCode: def.code.name,
              level: levelIndex,
              size: 112,
              locked: !unlocked,
            ),
            const SizedBox(height: AppSpace.s16),
            Text(l.title, textAlign: TextAlign.center, style: AppType.headline.copyWith(color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            AppStatusChip('${def.name} • ${l.tier.label}', tone: unlocked ? AppTone.accent : AppTone.neutral),
            const SizedBox(height: AppSpace.s12),
            Text(def.description, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
            const SizedBox(height: AppSpace.s16),
            if (unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: tk.successInk, size: 20),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: Text('Conquista desbloqueada!', style: AppType.bodyStrong.copyWith(color: tk.successInk)),
                  ),
                ],
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpace.s8),
                child: LinearProgressIndicator(
                  value: (p.current / l.threshold).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: tk.accent,
                  backgroundColor: tk.border,
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Progresso: ${p.current}/${l.threshold} ${def.unit}',
                style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
              ),
            ],
          ],
        );
      },
    );
  }
}

import '../../../core/ui/app_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/achievements.dart';
import '../../../core/models/client_achievements.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/profile_and_achievement_emblems.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/ui/app_tokens.dart';

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

/// Paleta de cada metal: (topo do degradê, base do degradê, cor do ícone).
({Color top, Color bottom, Color ink}) tierPalette(AchievementTier t) => switch (t) {
      AchievementTier.bronze => (top: const Color(0xFFE2AE78), bottom: const Color(0xFF9A5B2B), ink: const Color(0xFF6E3C17)),
      AchievementTier.silver => (top: const Color(0xFFEDF0F5), bottom: const Color(0xFF9AA3B2), ink: const Color(0xFF515C6D)),
      AchievementTier.gold => (top: const Color(0xFFFFE07A), bottom: const Color(0xFFD59A0A), ink: const Color(0xFF7A5300)),
      AchievementTier.platinum => (top: const Color(0xFFD7F1F8), bottom: const Color(0xFF63AFC9), ink: const Color(0xFF245F76)),
      AchievementTier.diamond => (top: const Color(0xFFB4EAFF), bottom: const Color(0xFF3F86FF), ink: const Color(0xFF1B49B3)),
    };

/// Medalha vetorial forjada nativamente via GPU (`AchievementMedalForge`).
///
/// - **Bloqueada (`locked: true`)**: Padrão *Cinza Claro Prateado* (`#CBD5E1` sobre `#1E293B`
///   com aro `#94A3B8` e cadeado `#E2E8F0`), despertando o Efeito Zeigarnik.
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
    final isDark = context.tk.isDark;
    final labelColor = locked
        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
        : context.tk.text;
    return Semantics(
      button: onTap != null,
      label: '$title, ${locked ? "bloqueada" : "desbloqueada"}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
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
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: locked ? FontWeight.w600 : FontWeight.w800,
                      height: 1.15,
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

/// Carrossel horizontal com suavização lateral (`ShaderMask` de 16px) para nunca cortar
/// medalhas ou sílabas de forma brusca nas extremidades.
class _EdgeFadeMedalCarousel extends StatelessWidget {
  const _EdgeFadeMedalCarousel({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.45);
    final effectiveHeight = height + ((textScale - 1.0) * 68.0).clamp(0.0, 34.0);
    return SizedBox(
      height: effectiveHeight,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.03, 0.97, 1.0],
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
  final spec = resolveAchievementTrackSpec(a.category.code);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: a, size: 112, locked: !unlocked),
            const SizedBox(height: 14),
            Text(a.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            StatusChip(
              '${a.category.name} • ${a.tier.label} • nível ${a.level}/10',
              color: unlocked ? spec.primaryColor : context.tk.textMuted,
            ),
            const SizedBox(height: 12),
            Text(a.description, textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            if (unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: context.tk.success, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Desbloqueada em ${_date(unlockedAt)}', style: TextStyle(fontWeight: FontWeight.w800, color: context.tk.successInk)),
                  ),
                ],
              )
            else if (count != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (count / a.threshold).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: spec.primaryColor,
                  backgroundColor: context.tk.border,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Faltam ${(a.threshold - count).clamp(0, a.threshold)} para desbloquear',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ] else
              Text('Ainda não desbloqueada', style: TextStyle(fontWeight: FontWeight.w800, color: context.tk.textMuted)),
          ],
        ),
      ),
    ),
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
    return FutureBuilder<List<({String code, DateTime unlockedAt})>>(
      future: ProviderService().achievements(providerId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 60, child: LoadingView());
        final list = snap.data ?? const [];
        final progress = buildProgress(list.map((e) => e.code));
        final best = [for (final c in progress) if (c.highest != null) c.highest!]..sort((a, b) => b.level.compareTo(a.level));
        final total = list.length;
        if (total == 0) {
          return Text('Este profissional ainda não desbloqueou conquistas.', style: TextStyle(color: context.tk.textMuted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EdgeFadeMedalCarousel(
              height: 128,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                scrollDirection: Axis.horizontal,
                itemCount: best.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => AchievementTile(
                  achievement: best[i],
                  size: 58,
                  width: 92,
                  onTap: () => showAchievementDetail(context, best[i], unlockedAt: list.firstWhere((e) => e.code == best[i].code).unlockedAt),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SecondaryButton(
              label: 'Ver todas as conquistas ($total de ${allAchievements().length})',
              icon: Icons.emoji_events_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AchievementsScreen(providerId: providerId, providerName: providerName)),
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
    return AppScaffold(
      appBar: AppBar(title: Text(widget.isOwner ? 'Minhas conquistas' : 'Conquistas de ${widget.providerName.split(' ').first}')),
      body: FutureBuilder<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível carregar as conquistas.', onRetry: _reload);
          final unlocked = snap.data!.unlocked;
          final counts = snap.data!.counts;
          final dates = {for (final u in unlocked) u.code: u.unlockedAt};
          final progress = buildProgress(dates.keys, counts: counts);
          final total = allAchievements().length;
          final last = unlocked.isEmpty ? null : achievementFromCode(unlocked.first.code);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _Summary(unlocked: unlocked.length, total: total, last: last),
                const SizedBox(height: 14),
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
    final accent = Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(value: total == 0 ? 0 : unlocked / total, strokeWidth: 8, color: accent, backgroundColor: context.tk.border),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$unlocked', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                    Text('de $total', style: TextStyle(fontSize: 11, color: context.tk.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conquistas desbloqueadas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  (last == null && lastTitle == null) ? (emptyHint ?? 'Conclua serviços e receba avaliações para desbloquear as primeiras.') : 'Mais recente: ${last?.title ?? lastTitle}',
                  style: TextStyle(color: context.tk.textMuted, height: 1.35, fontSize: 13),
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
    final next = cp.next;
    final progress = cp.progressToNext;
    final spec = resolveAchievementTrackSpec(cp.category.code);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementTrackHeaderEmblem(trackCode: cp.category.code, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(cp.category.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: spec.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: spec.primaryColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${cp.unlockedLevels.length}/${kAchievementThresholds.length}',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: spec.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EdgeFadeMedalCarousel(
            height: 128,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              scrollDirection: Axis.horizontal,
              itemCount: kAchievementThresholds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = Achievement(cp.category, kAchievementThresholds[i]);
                final isUnlocked = cp.unlockedLevels.contains(a.threshold);
                return AchievementTile(
                  achievement: a,
                  size: 56,
                  width: 88,
                  locked: !isUnlocked,
                  onTap: () => showAchievementDetail(context, a, unlockedAt: dates[a.code], count: cp.count),
                );
              },
            ),
          ),
          if (isOwner && next != null) ...[
            const SizedBox(height: 10),
            Text('Próxima: ${next.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress ?? 0,
                minHeight: 8,
                color: spec.primaryColor,
                backgroundColor: context.tk.border,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cp.count == null ? '' : '${Achievement.formatCount(cp.count!)} / ${Achievement.formatCount(next.threshold)}',
              style: TextStyle(fontSize: 12, color: context.tk.textMuted),
            ),
          ] else if (isOwner && next == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Categoria completa!', style: TextStyle(fontWeight: FontWeight.w900, color: context.tk.successInk)),
            ),
        ],
      ),
    );
  }
}

/// Cores do cartão "Conquista desbloqueada". Escuro: superfície #1E1E24 com rótulo
/// âmbar #F5B041, título branco e subtítulo cinza claro; claro: superfície creme com
/// rótulo âmbar escuro #8A5A00 e textos dos tokens. Todos os pares >= 4,5:1 (WCAG),
/// verificado em `test/completion_redesign_test.dart`.
typedef AchievementCardColors = ({Color surface, Color label, Color title, Color subtitle});

AchievementCardColors achievementCardColors(AppTokens tk) => tk.isDark
    ? (surface: const Color(0xFF1E1E24), label: const Color(0xFFF5B041), title: const Color(0xFFFFFFFF), subtitle: const Color(0xFFC4C8D0))
    : (surface: const Color(0xFFFFF7E8), label: const Color(0xFF8A5A00), title: tk.text, subtitle: tk.textMuted);

/// Borda em degradê bronze/dourado metálico do cartão de conquista.
const List<Color> kAchievementBorderGradient = [
  Color(0xFFE2AE78),
  Color(0xFFF7D774),
  Color(0xFF9A5B2B),
  Color(0xFFD59A0A),
];

/// Hero de sucesso: halo suave em degradê verde-esmeralda → azul com o ícone no centro.
/// Estático (sem animação).
class SuccessHeroHalo extends StatelessWidget {
  const SuccessHeroHalo({super.key, this.icon = Icons.verified_rounded, this.size = 128});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
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
                colors: [const Color(0xFF10B981).withValues(alpha: 0.28), const Color(0xFF3B82F6).withValues(alpha: 0.18)],
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
                colors: [const Color(0xFF10B981).withValues(alpha: 0.30), const Color(0xFF3B82F6).withValues(alpha: 0.26)],
              ),
            ),
          ),
          Container(
            width: core,
            height: core,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E9F6E), Color(0xFF2563EB)]),
            ),
            child: Icon(icon, size: core * 0.58, color: Colors.white),
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
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
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
    final reduce = MediaQuery.disableAnimationsOf(context);

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
            colors: const [Color(0x00FFFFFF), Color(0xD9FFFFFF), Color(0x00FFFFFF)],
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
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kAchievementBorderGradient),
        boxShadow: tk.cardShadow(blur: 14, dy: 5),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18.4)),
        child: Row(
          children: [
            medal,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONQUISTA DESBLOQUEADA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.label)),
                  const SizedBox(height: 3),
                  Text(a.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1.2, color: c.title)),
                  const SizedBox(height: 2),
                  Text('${a.category.name} • Nível ${a.tier.label}', style: TextStyle(fontSize: 12.5, color: c.subtitle)),
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
            padding: const EdgeInsets.only(bottom: 10),
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
    return AppScaffold(
      appBar: AppBar(title: const Text('Minhas conquistas')),
      body: FutureBuilder<ClientAchievementInput>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível carregar as conquistas.', onRetry: _reload);
          final progress = computeClientAchievements(snap.data!);
          final unlocked = progress.fold<int>(0, (a, p) => a + p.unlockedCount);
          final last = progress.where((p) => p.highest != null).fold<ClientLevel?>(null, (best, p) {
            final h = p.highest!;
            return best == null || h.tier.index >= best.tier.index ? h : best;
          });
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _Summary(unlocked: unlocked, total: kClientMedalTotal, last: null, lastTitle: last?.title, emptyHint: 'Faça pedidos, avalie e complete o perfil para desbloquear as primeiras.'),
                const SizedBox(height: 14),
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
    final spec = resolveAchievementTrackSpec(def.code.name);
    return AppCard(
      key: ValueKey('client-ach:${def.code.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementTrackHeaderEmblem(trackCode: def.code.name, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(def.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: spec.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: spec.primaryColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${progress.unlockedCount}/${def.levels.length}',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: spec.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(def.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tk.textMuted)),
          const SizedBox(height: 12),
          _EdgeFadeMedalCarousel(
            height: 128,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              scrollDirection: Axis.horizontal,
              itemCount: def.levels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                  width: 88,
                  locked: !isUnlocked,
                  onTap: () => _showLevelDetail(context, progress, l, i + 1, isUnlocked),
                );
              },
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Text('Próxima: ${next.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress.fractionToNext, minHeight: 8, color: spec.primaryColor, backgroundColor: tk.border),
            ),
            const SizedBox(height: 4),
            Text('${progress.current} / ${next.threshold} ${def.unit}', style: TextStyle(fontSize: 12, color: tk.textMuted)),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Categoria completa!', style: TextStyle(fontWeight: FontWeight.w900, color: tk.successInk)),
            ),
        ],
      ),
    );
  }

  void _showLevelDetail(BuildContext context, ClientAchievementProgress p, ClientLevel l, int levelIndex, bool unlocked) {
    unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
    final def = p.def;
    final spec = resolveAchievementTrackSpec(def.code.name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
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
              const SizedBox(height: 14),
              Text(l.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              StatusChip('${def.name} • ${l.tier.label}', color: unlocked ? spec.primaryColor : ctx.tk.textMuted),
              const SizedBox(height: 12),
              Text(def.description, textAlign: TextAlign.center, style: TextStyle(color: ctx.tk.textMuted, height: 1.4)),
              const SizedBox(height: 14),
              if (unlocked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: ctx.tk.success, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Conquista desbloqueada!', style: TextStyle(fontWeight: FontWeight.w800, color: ctx.tk.successInk)),
                    ),
                  ],
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (p.current / l.threshold).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: spec.primaryColor,
                    backgroundColor: ctx.tk.border,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Progresso: ${p.current}/${l.threshold} ${def.unit}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

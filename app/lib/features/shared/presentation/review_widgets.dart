import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart' show BannerTone, InfoBanner;
import '../../../core/utils/format.dart';

/// Seletor interativo de estrelas com *pop* escalonado de 40 ms por estrela
/// até a nota selecionada. Alvos >= 48×48 e respeito total a [AppMotion.reduced].
class InteractiveReviewStars extends StatefulWidget {
  const InteractiveReviewStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  State<InteractiveReviewStars> createState() => _InteractiveReviewStarsState();
}

class _InteractiveReviewStarsState extends State<InteractiveReviewStars> {
  static const Duration _staggerStep = Duration(milliseconds: 40);
  static const Duration _popDuration = Duration(milliseconds: 140);

  final List<double> _scales = List<double>.filled(5, 1.0);
  final List<Timer> _timers = <Timer>[];

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _triggerPop(int star) {
    HapticFeedback.selectionClick();
    widget.onChanged(star);
    if (AppMotion.reduced(context)) return;
    _clearTimers();
    for (var i = 0; i < star; i++) {
      final idx = i;
      _timers.add(
        Timer(_staggerStep * idx, () {
          if (!mounted) return;
          setState(() => _scales[idx] = 1.18);
          _timers.add(
            Timer(_popDuration, () {
              if (!mounted) return;
              setState(() => _scales[idx] = 1.0);
            }),
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dur = AppMotion.d(context, _popDuration);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpace.s4,
      runSpacing: AppSpace.s4,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: widget.value >= i,
            label: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
            child: InkResponse(
              onTap: () => _triggerPop(i),
              radius: AppGeometry.minTarget / 2,
              child: SizedBox(
                width: AppGeometry.minTarget,
                height: AppGeometry.minTarget,
                child: Center(
                  child: AnimatedScale(
                    scale: _scales[i - 1],
                    duration: dur,
                    curve: Curves.easeOutBack,
                    child: Icon(
                      widget.value >= i
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: widget.size,
                      color: widget.value >= i ? tk.star : tk.border,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ícone e cor de cada selo automático (cores com contraste >= 4,5:1).
({IconData icon, Color color}) badgeStyle(
  BuildContext context,
  ProviderBadge b,
) =>
    switch (b) {
      ProviderBadge.superPro => (
          icon: Icons.local_fire_department_rounded,
          color: context.tk.clientAccentInk,
        ),
      ProviderBadge.organizacao => (
          icon: Icons.cleaning_services_rounded,
          color: context.tk.security,
        ),
      ProviderBadge.pontual => (
          icon: Icons.alarm_on_rounded,
          color: context.tk.info,
        ),
      ProviderBadge.mestre => (
          icon: Icons.workspace_premium_rounded,
          color: context.tk.providerAccentInk,
        ),
      ProviderBadge.honesto => (
          icon: Icons.handshake_rounded,
          color: context.tk.successInk,
        ),
      ProviderBadge.confiavel => (
          icon: Icons.verified_user_rounded,
          color: context.tk.info,
        ),
    };

/// Selos conquistados (códigos vindos do banco), em chips.
class BadgeChips extends StatelessWidget {
  const BadgeChips(this.codes, {super.key, this.max});

  final List<String> codes;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final badges = [for (final c in codes) ?ProviderBadge.parse(c)];
    final shown = max == null ? badges : badges.take(max!).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      children: [
        for (final b in shown)
          AppStatusChip(
            b.label,
            color: badgeStyle(context, b).color,
            icon: badgeStyle(context, b).icon,
          ),
      ],
    );
  }
}

/// Metadados educativos e dicas práticas de conquista para cada um dos 6 selos.
({String howToEarn, List<String> tips, String benefit}) badgeGuide(
  ProviderBadge b,
) =>
    switch (b) {
      ProviderBadge.superPro => (
          howToEarn:
              'Receba nota máxima (5 estrelas) nos seus últimos 20 serviços concluídos.',
          tips: const <String>[
            'Alinhe o que será feito pelo chat antes de iniciar e cumpra o horário combinado.',
            'Registre fotos nítidas do antes e depois e revise o funcionamento junto com o cliente.',
          ],
          benefit:
              'Destaca seu perfil com o selo máximo de excelência, aumentando a preferência dos clientes pelos seus orçamentos.',
        ),
      ProviderBadge.organizacao => (
          howToEarn:
              'Receba o elogio "Limpou tudo depois" de 15 clientes ao finalizar seus atendimentos.',
          tips: const <String>[
            'Proteja a área de trabalho antes de começar e recolha embalagens ou resíduos ao terminar.',
            'Registre a última foto mostrando o local limpo e organizado na entrega.',
          ],
          benefit:
              'Transmite tranquilidade para clientes que valorizam cuidado e capricho dentro de casa.',
        ),
      ProviderBadge.pontual => (
          howToEarn:
              'Receba o elogio "Super pontual" de 15 clientes por chegar no horário combinado.',
          tips: const <String>[
            'Avise pelo chat assim que sair a caminho do endereço do cliente.',
            'Caso surja qualquer imprevisto no trânsito, comunique com antecedência pelo chat.',
          ],
          benefit:
              'Aumenta sua conversão em pedidos com horário agendado e emergências.',
        ),
      ProviderBadge.mestre => (
          howToEarn:
              'Receba o elogio "Mestre no que faz" de 15 clientes pela qualidade técnica do serviço.',
          tips: const <String>[
            'Explique de forma simples e clara a causa do problema e a solução aplicada.',
            'Teste o serviço na frente do cliente antes de pedir o código PIN de conclusão.',
          ],
          benefit:
              'Comprova seu domínio técnico no perfil público, valorizando sua mão de obra.',
        ),
      ProviderBadge.honesto => (
          howToEarn:
              'Receba o elogio "Preço honesto" de 15 clientes pela transparência nos seus orçamentos.',
          tips: const <String>[
            'Detalhe no orçamento o que é mão de obra e o que são peças ou materiais.',
            'Mantenha o valor combinado sem cobranças surpresa fora do aplicativo.',
          ],
          benefit:
              'Reduz a hesitação do cliente na hora de aprovar o seu orçamento.',
        ),
      ProviderBadge.confiavel => (
          howToEarn:
              'Receba o elogio "Educado e confiável" de 15 clientes pelo atendimento respeitoso e seguro.',
          tips: const <String>[
            'Apresente-se com cordialidade ao chegar e respeite as regras da residência ou condomínio.',
            'Esclareça dúvidas com paciência e mantenha toda a comunicação registrada no chat.',
          ],
          benefit:
              'Gera confiança imediata para famílias e moradores contratarem você.',
        ),
    };

/// Abre o modal informativo elegante explicando como conquistar o selo [badge].
Future<void> showProviderBadgeInfoSheet(
  BuildContext context,
  ProviderBadge badge, {
  required int currentCount,
  required bool isEarned,
}) {
  final style = badgeStyle(context, badge);
  final guide = badgeGuide(badge);
  final clamped = currentCount.clamp(0, badge.goal);
  final progress = isEarned ? 1.0 : (clamped / badge.goal).clamp(0.0, 1.0);

  return AppSheet.show<void>(
    context,
    actions: [
      Builder(
        builder: (sheetCtx) => AppButton(
          key: const ValueKey('btn-badge-sheet-close'),
          label: 'Entendi',
          onPressed: () => Navigator.of(sheetCtx).pop(),
        ),
      ),
    ],
    builder: (ctx) {
      final tk = ctx.tk;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                  border: Border.all(
                    color: style.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(style.icon, color: style.color, size: 30),
              ),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.label,
                      key: ValueKey('badge-sheet-title-${badge.code}'),
                      style: AppType.title.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    if (isEarned)
                      const AppStatusChip(
                        'Selo conquistado',
                        tone: AppTone.success,
                        icon: Icons.check_circle_rounded,
                      )
                    else
                      AppStatusChip(
                        'Progresso: $clamped de ${badge.goal}',
                        color: style.color,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: isEarned ? tk.success : style.color,
              backgroundColor: tk.border,
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          AppCard(
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 18, color: style.color),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'Como conquistar',
                        style: AppType.titleSm.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  guide.howToEarn,
                  style: AppType.bodySm.copyWith(color: tk.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.item),
          AppCard(
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 18,
                      color: tk.providerAccentInk,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'Dicas práticas no dia a dia',
                        style: AppType.titleSm.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                for (final tip in guide.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s2),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: tk.successInk,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.item),
          AppCard(
            variant: AppCardVariant.tonal,
            color: style.color.withValues(alpha: 0.08),
            borderColor: style.color.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: style.color),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'Vantagem real no perfil',
                        style: AppType.titleSm.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  guide.benefit,
                  style: AppType.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Mural de selos no perfil: conquistados em destaque e os próximos com progresso.
/// Todos os 6 selos são clicáveis e abrem um informativo elegante explicando como conquistá-los.
class BadgeWall extends StatelessWidget {
  const BadgeWall({
    super.key,
    required this.earned,
    this.tagCounts = const {},
    this.fiveStarCount = 0,
    this.showProgress = false,
  });

  final List<String> earned;

  /// Contagem de cada pílula nas avaliações reveladas (para o progresso).
  final Map<String, int> tagCounts;

  /// Contagem de avaliações 5 estrelas recentes (para o progresso de Super Profissional 0/20).
  final int fiveStarCount;
  final bool showProgress;

  int _countFor(ProviderBadge b) {
    if (earned.contains(b.code)) return b.goal;
    if (b == ProviderBadge.superPro) return fiveStarCount.clamp(0, b.goal);
    return (b.tag == null ? 0 : (tagCounts[b.tag] ?? 0)).clamp(0, b.goal);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final locked = [
      for (final b in ProviderBadge.values)
        if (!earned.contains(b.code)) b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earned.isEmpty)
          Text(
            'Nenhum selo conquistado ainda. Toque em qualquer selo abaixo para ver como conquistá-lo.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          )
        else
          Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s12,
            children: [
              for (final c in earned) _tile(context, ProviderBadge.parse(c)),
            ],
          ),
        if (showProgress && locked.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s16),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Próximos selos',
                style: AppType.titleSm.copyWith(color: tk.text),
              ),
              Text(
                'Toque para saber como ganhar',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tk.providerAccentInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          for (final b in locked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.item),
              child: _progressCard(context, b),
            ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, ProviderBadge? b) {
    if (b == null) return const SizedBox.shrink();
    final s = badgeStyle(context, b);
    return SizedBox(
      width: 156,
      child: AppCard(
        key: ValueKey('badge-item-${b.code}'),
        variant: AppCardVariant.tonal,
        color: s.color.withValues(alpha: 0.10),
        borderColor: s.color.withValues(alpha: 0.35),
        radius: AppGeometry.itemRadius,
        padding: const EdgeInsets.all(AppSpace.s12),
        semanticLabel: 'Detalhes do selo ${b.label}',
        onTap: () => showProviderBadgeInfoSheet(
          context,
          b,
          currentCount: b.goal,
          isEarned: true,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(s.icon, color: s.color, size: 26),
                Icon(Icons.info_outline_rounded, size: 16, color: s.color),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              b.label,
              style: AppType.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
                color: s.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(BuildContext context, ProviderBadge b) {
    final tk = context.tk;
    final s = badgeStyle(context, b);
    final count = _countFor(b);
    final frac = (count / b.goal).clamp(0.0, 1.0);

    return AppCard(
      key: ValueKey('badge-item-${b.code}'),
      variant: AppCardVariant.outlined,
      radius: AppGeometry.itemRadius,
      padding: const EdgeInsets.all(AppSpace.s12),
      semanticLabel: 'Detalhes do selo ${b.label}',
      onTap: () => showProviderBadgeInfoSheet(
        context,
        b,
        currentCount: count,
        isEarned: false,
      ),
      child: Row(
        children: [
          Container(
            width: AppGeometry.iconTileSize,
            height: AppGeometry.iconTileSize,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            ),
            child: Icon(s.icon, size: 20, color: s.color),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.label,
                        style: AppType.bodyStrong.copyWith(color: tk.text),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Text(
                      '$count/${b.goal}',
                      style: AppType.tabular(AppType.caption).copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  b.description,
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: AppSpace.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    color: s.color,
                    backgroundColor: tk.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Icon(Icons.chevron_right_rounded, size: 20, color: tk.textMuted),
        ],
      ),
    );
  }
}

/// Pílulas de contexto (Quick Tags): trocam de conjunto conforme a nota.
class ReviewTagPills extends StatelessWidget {
  const ReviewTagPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.negative,
  });

  final List<String> options;
  final Set<String> selected;
  final void Function(String tag, bool on) onToggle;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final tone = negative ? tk.danger : tk.clientAccent;
    final onTone = AppTokens.onColor(tone);
    return AnimatedSwitcher(
      duration: AppMotion.d(context, AppMotion.sheet),
      child: Wrap(
        key: ValueKey(negative),
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          for (final t in options)
            FilterChip(
              label: Text(t),
              selected: selected.contains(t),
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              avatar: selected.contains(t)
                  ? Icon(Icons.check_rounded, size: 16, color: onTone)
                  : null,
              selectedColor: tone,
              backgroundColor: tone.withValues(alpha: 0.08),
              side: BorderSide(
                color: tone.withValues(alpha: selected.contains(t) ? 1 : 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
              ),
              labelStyle: AppType.bodySm.copyWith(
                color: selected.contains(t) ? onTone : tk.text,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (v) => onToggle(t, v),
            ),
        ],
      ),
    );
  }
}

/// Aviso da avaliação cega.
class BlindReviewBanner extends StatelessWidget {
  const BlindReviewBanner({super.key, this.who = 'a outra parte'});

  final String who;

  @override
  Widget build(BuildContext context) => InfoBanner(
        'Sua avaliação é confidencial. Ninguém vê a nota que recebeu até que $who também avalie, ou até 48 horas depois. Isso evita avaliações por vingança.',
        tone: BannerTone.security,
        icon: Icons.visibility_off_rounded,
        title: 'Avaliação cega',
      );
}

/// Faixa de fotos do serviço com o selo "Serviço verificado".
class ReviewPhotoStrip extends StatelessWidget {
  const ReviewPhotoStrip(this.paths, {super.key, this.size = 92});

  final List<String> paths;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final tk = context.tk;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
        itemBuilder: (_, i) => Stack(
          children: [
            PublicImage(
              path: paths[i],
              width: size,
              height: size,
              radius: AppGeometry.iconTileRadius,
            ),
            Positioned(
              left: AppSpace.s4,
              bottom: AppSpace.s4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s8,
                  vertical: AppSpace.s2,
                ),
                decoration: BoxDecoration(
                  color: tk.successSoft,
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: tk.successInk,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Text(
                      'Verificado',
                      style: AppType.caption.copyWith(
                        color: tk.successInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de avaliação pública: estrelas, pílulas, comentário, fotos e resposta.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onReply,
    this.onOpenDetails,
    this.ownerHint,
  });

  /// Texto padrão da dica mostrada ao dono (quando [onOpenDetails] é informado).
  /// Mantém o glifo exigido literalmente por `test/dossier_test.dart`.
  static const String defaultOwnerHint =
      'Toque para ver detalhes financeiros e do serviço ➔';

  /// Só o profissional DONO passa isto (abre o dossiê interno). Na visão pública fica
  /// null: o card não é tocável e não revela que existem detalhes financeiros.
  final VoidCallback? onOpenDetails;

  /// Texto da dica ao dono; ignorado quando [onOpenDetails] é null (nunca aparece no público).
  final String? ownerHint;

  final PublicReview review;

  /// Quando informado (profissional dono do perfil), mostra o botão "Responder".
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final r = review;
    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpace.item),
      onTap: onOpenDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: r.reviewerName, radius: 20),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  r.reviewerName,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                relativeTime(r.createdAt),
                style: AppType.tabular(AppType.caption)
                    .copyWith(color: tk.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AppRating(value: r.rating.toDouble(), size: 16),
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final t in r.tags)
                  AppStatusChip(
                    t,
                    tone: ReviewTags.isNegative(r.rating)
                        ? AppTone.danger
                        : AppTone.accent,
                    color: ReviewTags.isNegative(r.rating)
                        ? tk.dangerInk
                        : tk.clientAccentInk,
                  ),
              ],
            ),
          ],
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(r.comment!, style: AppType.body.copyWith(color: tk.text)),
          ],
          if (r.photoPaths.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            ReviewPhotoStrip(r.photoPaths),
          ],
          if (r.hasReply) ...[
            const SizedBox(height: AppSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                border: Border(
                  left: BorderSide(color: tk.providerAccent, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: tk.providerAccentInk,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'Resposta do profissional',
                          style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(r.reply!, style: AppType.bodySm.copyWith(color: tk.text)),
                ],
              ),
            ),
          ] else if (onReply != null) ...[
            const SizedBox(height: AppSpace.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Responder',
                icon: Icons.reply_rounded,
                variant: AppButtonVariant.tertiary,
                expand: false,
                compact: true,
                onPressed: onReply,
              ),
            ),
          ],
          if (onOpenDetails != null) ...[
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: tk.providerAccentInk,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    ownerHint ?? defaultOwnerHint,
                    style: AppType.caption.copyWith(
                      color: tk.providerAccentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

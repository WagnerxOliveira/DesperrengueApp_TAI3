import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/ui/app_tokens.dart';

/// Ícone e cor de cada selo automático.
({IconData icon, Color color}) badgeStyle(BuildContext context, ProviderBadge b) => switch (b) {
      ProviderBadge.superPro => (icon: Icons.local_fire_department_rounded, color: context.tk.clientAccent),
      ProviderBadge.organizacao => (icon: Icons.cleaning_services_rounded, color: context.tk.security),
      ProviderBadge.pontual => (icon: Icons.alarm_on_rounded, color: context.tk.info),
      ProviderBadge.mestre => (icon: Icons.workspace_premium_rounded, color: context.tk.providerAccent),
      ProviderBadge.honesto => (icon: Icons.handshake_rounded, color: context.tk.success),
      ProviderBadge.confiavel => (icon: Icons.verified_user_rounded, color: context.tk.info),
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
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in shown) StatusChip(b.label, color: badgeStyle(context, b).color, icon: badgeStyle(context, b).icon),
      ],
    );
  }
}

/// Metadados educativos e dicas práticas de conquista para cada um dos 6 selos.
({String howToEarn, List<String> tips, String benefit}) badgeGuide(ProviderBadge b) => switch (b) {
      ProviderBadge.superPro => (
          howToEarn: 'Receba nota máxima (5 estrelas) nos seus últimos 20 serviços concluídos.',
          tips: const <String>[
            'Alinhe o que será feito pelo chat antes de iniciar e cumpra o horário combinado.',
            'Registre fotos nítidas do antes e depois e revise o funcionamento junto com o cliente.',
          ],
          benefit: 'Destaca seu perfil com o selo máximo de excelência, aumentando a preferência dos clientes pelos seus orçamentos.',
        ),
      ProviderBadge.organizacao => (
          howToEarn: 'Receba o elogio "Limpou tudo depois" de 15 clientes ao finalizar seus atendimentos.',
          tips: const <String>[
            'Proteja a área de trabalho antes de começar e recolha embalagens ou resíduos ao terminar.',
            'Registre a última foto mostrando o local limpo e organizado na entrega.',
          ],
          benefit: 'Transmite tranquilidade para clientes que valorizam cuidado e capricho dentro de casa.',
        ),
      ProviderBadge.pontual => (
          howToEarn: 'Receba o elogio "Super pontual" de 15 clientes por chegar no horário combinado.',
          tips: const <String>[
            'Avise pelo chat assim que sair a caminho do endereço do cliente.',
            'Caso surja qualquer imprevisto no trânsito, comunique com antecedência pelo chat.',
          ],
          benefit: 'Aumenta sua conversão em pedidos com horário agendado e emergências.',
        ),
      ProviderBadge.mestre => (
          howToEarn: 'Receba o elogio "Mestre no que faz" de 15 clientes pela qualidade técnica do serviço.',
          tips: const <String>[
            'Explique de forma simples e clara a causa do problema e a solução aplicada.',
            'Teste o serviço na frente do cliente antes de pedir o código PIN de conclusão.',
          ],
          benefit: 'Comprova seu domínio técnico no perfil público, valorizando sua mão de obra.',
        ),
      ProviderBadge.honesto => (
          howToEarn: 'Receba o elogio "Preço honesto" de 15 clientes pela transparência nos seus orçamentos.',
          tips: const <String>[
            'Detalhe no orçamento o que é mão de obra e o que são peças ou materiais.',
            'Mantenha o valor combinado sem cobranças surpresa fora do aplicativo.',
          ],
          benefit: 'Reduz a hesitação do cliente na hora de aprovar o seu orçamento.',
        ),
      ProviderBadge.confiavel => (
          howToEarn: 'Receba o elogio "Educado e confiável" de 15 clientes pelo atendimento respeitoso e seguro.',
          tips: const <String>[
            'Apresente-se com cordialidade ao chegar e respeite as regras da residência ou condomínio.',
            'Esclareça dúvidas com paciência e mantenha toda a comunicação registrada no chat.',
          ],
          benefit: 'Gera confiança imediata para famílias e moradores contratarem você.',
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

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final tk = ctx.tk;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
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
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: style.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(style.icon, color: style.color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.label,
                          key: ValueKey('badge-sheet-title-${badge.code}'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: tk.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isEarned
                                ? tk.successSoft
                                : style.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isEarned
                                ? 'Selo conquistado ✓'
                                : 'Progresso: $clamped de ${badge.goal}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isEarned ? tk.successInk : style.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: isEarned ? tk.success : style.color,
                  backgroundColor: tk.border,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tk.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 18,
                          color: style.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Como conquistar',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: tk.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.howToEarn,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: tk.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tk.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          size: 18,
                          color: tk.providerAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Dicas práticas no dia a dia',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: tk.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final tip in guide.tips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: tk.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.38,
                                  color: tk.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: style.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 18, color: style.color),
                        const SizedBox(width: 8),
                        Text(
                          'Vantagem real no perfil',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: tk.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.benefit,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: tk.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('btn-badge-sheet-close'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendi'),
                ),
              ),
            ],
          ),
        ),
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
    final locked = [for (final b in ProviderBadge.values) if (!earned.contains(b.code)) b];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earned.isEmpty)
          Text(
            'Nenhum selo conquistado ainda. Toque em qualquer selo abaixo para ver como conquistá-lo.',
            style: TextStyle(color: context.tk.textMuted, height: 1.4),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in earned)
                _tile(context, ProviderBadge.parse(c)),
            ],
          ),
        if (showProgress && locked.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Próximos selos',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'Toque para saber como ganhar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.tk.providerAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final b in locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _progressCard(context, b),
            ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, ProviderBadge? b) {
    if (b == null) return const SizedBox.shrink();
    final s = badgeStyle(context, b);
    return Material(
      color: s.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('badge-item-${b.code}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => showProviderBadgeInfoSheet(
          context,
          b,
          currentCount: b.goal,
          isEarned: true,
        ),
        child: Container(
          width: 155,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: s.color.withValues(alpha: 0.35)),
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
              const SizedBox(height: 6),
              Text(
                b.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: s.color,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard(BuildContext context, ProviderBadge b) {
    final tk = context.tk;
    final s = badgeStyle(context, b);
    final count = _countFor(b);
    final frac = (count / b.goal).clamp(0.0, 1.0);

    return Material(
      color: tk.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('badge-item-${b.code}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => showProviderBadgeInfoSheet(
          context,
          b,
          currentCount: count,
          isEarned: false,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tk.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s.icon, size: 20, color: s.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '$count/${b.goal}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: tk.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.description,
                      style: TextStyle(color: tk.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tk.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílulas de contexto (Quick Tags): trocam de conjunto conforme a nota.
class ReviewTagPills extends StatelessWidget {
  const ReviewTagPills({super.key, required this.options, required this.selected, required this.onToggle, required this.negative});

  final List<String> options;
  final Set<String> selected;
  final void Function(String tag, bool on) onToggle;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final tone = negative ? context.tk.danger : context.tk.clientAccent;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Wrap(
        key: ValueKey(negative),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in options)
            FilterChip(
              label: Text(t),
              selected: selected.contains(t),
              showCheckmark: false,
              avatar: selected.contains(t) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              selectedColor: tone,
              backgroundColor: tone.withValues(alpha: 0.07),
              side: BorderSide(color: tone.withValues(alpha: selected.contains(t) ? 1 : 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              labelStyle: TextStyle(color: selected.contains(t) ? Theme.of(context).colorScheme.onPrimary : context.tk.text, fontWeight: FontWeight.w700),
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
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          children: [
            PublicImage(path: paths[i], width: size, height: size, radius: 12),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: context.tk.success, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 2),
                    Text('Verificado', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
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
  const ReviewCard({super.key, required this.review, this.onReply, this.onOpenDetails, this.ownerHint});

  /// Texto padrão da dica mostrada ao dono (quando [onOpenDetails] é informado).
  static const String defaultOwnerHint = 'Toque para ver detalhes financeiros e do serviço ➔';

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
    final r = review;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onOpenDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: r.reviewerName, radius: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(r.reviewerName, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(relativeTime(r.createdAt), style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          RatingStars(value: r.rating.toDouble(), size: 16),
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in r.tags)
                  StatusChip(t, color: ReviewTags.isNegative(r.rating) ? context.tk.danger : context.tk.clientAccent),
              ],
            ),
          ],
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment!, style: const TextStyle(height: 1.4)),
          ],
          if (r.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            ReviewPhotoStrip(r.photoPaths),
          ],
          if (r.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.tk.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: context.tk.providerAccent, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded, size: 16, color: context.tk.providerAccent),
                      SizedBox(width: 6),
                      Flexible(child: Text('Resposta do profissional', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.reply!, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ] else if (onReply != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: onReply, icon: const Icon(Icons.reply_rounded, size: 18), label: const Text('Responder')),
            ),
          ],
          if (onOpenDetails != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: context.tk.providerAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ownerHint ?? defaultOwnerHint,
                    style: TextStyle(color: context.tk.providerAccent, fontSize: 12.5, fontWeight: FontWeight.w800),
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

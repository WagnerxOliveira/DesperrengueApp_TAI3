import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart' show BannerTone, BrandLogo, InfoBanner, friendlyError;
import '../../../core/utils/format.dart';
import '../../shared/presentation/fintech_warranty_widgets.dart';
import '../../shared/presentation/review_thanks_view.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/support_screens.dart';

/// "Serviço Concluído!" (protótipo 06): momento "pico-fim" caloroso com check
/// Lottie breve, resumo e próximo passo útil (avaliar / relatar problema).
class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key, required this.job});

  final Job job;

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  ProviderCard? _provider;
  Payment? _payment;
  String _reviewStatus = 'none';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final job = widget.job;
    try {
      final results = await Future.wait([
        job.providerId == null ? Future.value(null) : ProviderService().byId(job.providerId!),
        JobService().fetchPayment(job.id),
        SocialService().reviewStatus(job.id),
      ]);
      if (!mounted) return;
      setState(() {
        _provider = results[0] as ProviderCard?;
        _payment = results[1] as Payment?;
        _reviewStatus = results[2] as String;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _method(String? m) => switch (m) {
        'wallet' => 'Saldo da carteira',
        'pix' => 'Pix (pelo app)',
        'credit_card' => 'Cartão de crédito (simulado)',
        'debit_card' => 'Cartão de débito (simulado)',
        _ => '—',
      };

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final job = widget.job;
    final margin = context.layout.margin;
    final totalAmount = _payment?.amount ?? job.agreedPrice;

    return AppScaffold(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: AppSkeletonSwitcher(
        loading: !_loaded,
        skeleton: AppSkeletonList(
          count: 3,
          padding: EdgeInsets.all(margin),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            margin,
            AppSpace.s12,
            margin,
            AppSpace.s24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const Center(child: _PeakEndCheckHero()),
            const SizedBox(height: AppSpace.s16),
            Text(
              'Serviço Concluído!',
              textAlign: TextAlign.center,
              style: AppType.display.copyWith(color: tk.brand),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              'Seu desperrengue foi resolvido!',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: AppSpace.s20),
            if (_provider != null) ...[
              AppCard(
                variant: AppCardVariant.elevated,
                child: Row(
                  children: [
                    AppHero(
                      tag: 'provider-avatar-${_provider!.id}',
                      child: AppAvatar(
                        url: _provider!.avatarUrl,
                        name: _provider!.fullName,
                        radius: 32,
                        verified: true,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _provider!.fullName,
                            style: AppType.titleSm.copyWith(color: tk.text),
                          ),
                          const SizedBox(height: AppSpace.s2),
                          Text(
                            _provider!.title,
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                          const SizedBox(height: AppSpace.s8),
                          const AppStatusChip(
                            'Verificado',
                            tone: AppTone.success,
                            icon: Icons.verified_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s20),
            ],
            AppSection(
              title: 'Resumo do serviço',
              child: AppCard(
                variant: AppCardVariant.tonal,
                color: tk.infoSoft,
                borderColor: tk.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInfoRow(
                      label: job.title,
                      valueWidget: Text(
                        brl(totalAmount),
                        style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                      ),
                    ),
                    Divider(height: AppSpace.s16, color: tk.border),
                    AppInfoRow(
                      label: 'Total pago',
                      strong: true,
                      valueWidget: totalAmount != null
                          ? AppPrice(value: totalAmount, size: AppPriceSize.sm)
                          : Text(
                              brl(totalAmount),
                              style: AppType.tabular(AppType.title).copyWith(color: tk.text),
                            ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    AppInfoRow(
                      label: 'Forma de pagamento',
                      value: _method(_payment?.method),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s20),
            ValueListenableBuilder(
              valueListenable: FintechLedgerStore.instance,
              builder: (context, _, _) {
                final dossier = FintechLedgerStore.instance.resolveForJob(job);
                return Column(
                  children: [
                    ForensicCheckInOutCard(
                      dossier: dossier,
                      onOpenThreeLayerWarranty: () =>
                          WarrantyThreeLayerResolutionSheet.show(context, orderId: job.id),
                    ),
                    const SizedBox(height: AppSpace.s16),
                  ],
                );
              },
            ),
            if (_reviewStatus == 'revealed')
              const InfoBanner(
                'Obrigado! Sua avaliação ajuda toda a comunidade.',
                tone: BannerTone.success,
                title: 'Avaliação enviada',
              )
            else if (_reviewStatus == 'waiting')
              const InfoBanner(
                'Ela será revelada quando o profissional também avaliar, ou em até 48 horas.',
                tone: BannerTone.security,
                icon: Icons.hourglass_top_rounded,
                title: 'Avaliação enviada (cega)',
              )
            else
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Próximo passo',
                      style: AppType.overline.copyWith(color: tk.accentInk),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      'Conte como foi o atendimento para ajudar outros clientes.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s12),
                    AppButton(
                      label: 'Avaliar serviço',
                      icon: Icons.star_rounded,
                      onPressed: _provider == null
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                AppRoute(
                                  builder: (_) => RatingScreen(job: job, provider: _provider!),
                                ),
                              );
                              _load();
                            },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.s12),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.s4,
                children: [
                  Text(
                    'Houve algum problema?',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                  AppButton(
                    label: 'Relatar um problema',
                    variant: AppButtonVariant.tertiary,
                    expand: false,
                    compact: true,
                    onPressed: () => Navigator.of(context).push(
                      AppRoute(
                        builder: (_) => ReportProblemScreen(job: job, asProvider: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: 'Voltar para o início',
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

/// Check breve com Lottie (`check_burst.json`) para o momento pico-fim;
/// respeita `disableAnimations` e tem fallback vetorial imediato.
class _PeakEndCheckHero extends StatelessWidget {
  const _PeakEndCheckHero();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final staticCheck = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tk.successSoft,
        border: Border.all(color: tk.success, width: 2),
      ),
      child: Icon(Icons.check_rounded, size: 52, color: tk.successInk),
    );
    if (reduced) {
      return Semantics(
        label: 'Serviço concluído com sucesso',
        child: staticCheck,
      );
    }
    return Semantics(
      label: 'Serviço concluído com sucesso',
      child: SizedBox(
        width: 112,
        height: 112,
        child: Lottie.asset(
          'assets/lottie/check_burst.json',
          width: 112,
          height: 112,
          repeat: false,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(child: staticCheck),
        ),
      ),
    );
  }
}

/// Avaliação guiada (protótipo 07): estrelas -> pílulas de contexto que mudam com
/// a nota -> comentário -> foto do serviço ("Antes e Depois") -> gorjeta.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.job, required this.provider});

  final Job job;
  final ProviderCard provider;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  Set<String> _tags = <String>{};
  final _comment = TextEditingController();
  final _photos = <PickedImage>[];
  double _tip = 0;
  bool _busy = false;
  bool _crisisShown = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final img = await pickImage(context);
    if (img != null && mounted) setState(() => _photos.add(img));
  }

  /// Trava de retenção de crise: antes de publicar uma nota baixa com "Problema
  /// não resolvido", oferece a garantia ou o suporte. Devolve true para seguir
  /// com o envio da avaliação.
  Future<bool> _crisisCheck() async {
    if (_crisisShown || !ReviewTags.shouldOfferGuarantee(_rating, _tags)) return true;
    _crisisShown = true;
    final choice = await AppSheet.show<String>(
      context,
      title: 'Sentimos muito por isso!',
      builder: (ctx) {
        final tk = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: tk.successSoft),
                  child: Icon(Icons.verified_user_rounded, color: tk.successInk),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    'Antes de publicar, podemos resolver isso agora. Você prefere acionar a Garantia Desperrengue ou falar com o nosso suporte?',
                    style: AppType.body.copyWith(color: tk.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s20),
            AppButton(
              label: 'Acionar a garantia do serviço',
              icon: Icons.verified_user_rounded,
              onPressed: () => Navigator.of(ctx).pop('guarantee'),
            ),
            const SizedBox(height: AppSpace.s12),
            AppButton(
              label: 'Falar com o suporte agora',
              icon: Icons.support_agent_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop('support'),
            ),
            const SizedBox(height: AppSpace.s8),
            AppButton(
              label: 'Enviar a avaliação mesmo assim',
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.of(ctx).pop('send'),
            ),
          ],
        );
      },
    );
    if (!mounted) return false;
    switch (choice) {
      case 'guarantee':
        await Navigator.of(context).push(
          AppRoute(
            builder: (_) => ReportProblemScreen(
              job: widget.job,
              asProvider: false,
              initialReason: 'O serviço não foi finalizado',
            ),
          ),
        );
        return false;
      case 'support':
        await Navigator.of(context).push(
          AppRoute(builder: (_) => const SupportCenterScreen()),
        );
        return false;
      case 'send':
        return true;
      default:
        return false; // fechou o painel: continua editando
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppSnackbar.show(
        context,
        'Toque nas estrelas para dar uma nota.',
        kind: AppSnackKind.warning,
      );
      return;
    }
    if (!await _crisisCheck()) return;
    setState(() => _busy = true);
    try {
      final media = MediaService();
      final paths = <String>[];
      for (final p in _photos) {
        paths.add(await media.uploadPublicPath(p.bytes, p.ext, prefix: 'review'));
      }
      await SocialService().submitReview(
        jobId: widget.job.id,
        rating: _rating,
        comment: _comment.text,
        tags: _tags.toList(),
        tip: _tip,
        photoPaths: paths,
      );
      // Sincroniza reativamente a avaliação do cliente tanto no Meu Portfólio
      // quanto no Histórico de Serviços Prestados do profissional.
      ProviderPortfolioStore.instance.syncClientEvaluationToHistoryAndPortfolio(
        orderId: widget.job.id,
        rating: _rating.toDouble(),
        comment: _comment.text,
        praiseTags: _tags.toList(),
      );
      final status = await SocialService().reviewStatus(widget.job.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppRoute(builder: (_) => RatingSuccessScreen(revealed: status == 'revealed')),
      );
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = widget.provider;
    final negative = ReviewTags.isNegative(_rating);
    final options = ReviewTags.options(_rating, byClient: true);
    final margin = context.layout.margin;

    return AppScaffold(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        children: [
          AppCard(
            variant: AppCardVariant.outlined,
            child: Row(
              children: [
                AppAvatar(
                  url: p.avatarUrl,
                  name: p.fullName,
                  radius: 30,
                  verified: true,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.fullName, style: AppType.titleSm.copyWith(color: tk.text)),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        '${p.title} • ${widget.job.category}',
                        style: AppType.bodySm.copyWith(color: tk.textMuted),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        'OS ${widget.job.code}',
                        style: AppType.tabular(AppType.caption).copyWith(
                          fontWeight: FontWeight.w600,
                          color: tk.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          Text(
            'Como foi o serviço do ${firstName(p.fullName)}?',
            textAlign: TextAlign.center,
            style: AppType.headline.copyWith(color: tk.brand),
          ),
          const SizedBox(height: AppSpace.s12),
          Center(
            child: AppRating(
              value: _rating.toDouble(),
              size: 40,
              onChanged: (v) => setState(() {
                _rating = v;
                _tags = ReviewTags.keepValid(_tags, v, byClient: true);
              }),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.d(context, AppMotion.page),
            alignment: Alignment.topCenter,
            child: _rating == 0
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s12),
                    child: Text(
                      'Toque numa estrela para começar',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: tk.textMuted),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpace.s24),
                      Text(
                        ReviewTags.title(_rating),
                        style: AppType.title.copyWith(color: tk.text),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        'Escolha quantas quiser (opcional).',
                        style: AppType.caption.copyWith(color: tk.textMuted),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      ReviewTagPills(
                        options: options,
                        selected: _tags,
                        negative: negative,
                        onToggle: (t, on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Deixe um comentário (opcional)',
            child: AppTextField(
              controller: _comment,
              hint: 'Conte em poucas palavras como foi a sua experiência...',
              maxLines: 4,
              minLines: 3,
              maxLength: 1000,
            ),
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Foto do serviço (opcional)',
            subtitle:
                'Mostre o resultado: fotos reais de "antes e depois" ajudam outros clientes e ganham o selo "Serviço verificado".',
            child: MediaPickerRow(
              images: _photos,
              onAdd: _addPhoto,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
              max: 3,
            ),
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Quer deixar uma gorjeta para o ${firstName(p.fullName)}?',
            subtitle: 'Simulada no MVP: registramos a intenção, sem cobrança.',
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final v in [0.0, 5.0, 10.0, 20.0])
                  ChoiceChip(
                    label: Text(v == 0 ? 'Não' : brl(v).replaceAll(',00', '')),
                    selected: _tip == v,
                    showCheckmark: false,
                    selectedColor: tk.accent,
                    labelStyle: AppType.tabular(AppType.bodySm).copyWith(
                      color: _tip == v ? tk.onAccent : tk.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _tip = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          const BlindReviewBanner(who: 'o profissional'),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Enviar avaliação',
          loading: _busy,
          onPressed: _submit,
        ),
      ),
    );
  }
}

/// Confirmação do envio. Explica a avaliação cega: se a outra parte ainda não
/// avaliou, a nota fica guardada até as duas serem reveladas (ou 48 h).
class RatingSuccessScreen extends StatelessWidget {
  const RatingSuccessScreen({super.key, this.revealed = false});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const AppAppBar(
        automaticallyImplyLeading: false,
        titleWidget: BrandLogo(),
      ),
      body: ReviewThanksView(
        isProvider: false,
        revealed: revealed,
        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'media_widgets.dart';
import 'widgets.dart';

/// Categorias semânticas de ícones executivos no padrão *Quiet Luxury Dark Glass Squircle Duotone*.
enum ServiceMetaIconKind {
  serviceId,
  category,
  createdAt,
  scheduledFor,
  startedAt,
  finishedAt,
  quotes,
  location,
  requestDescription,
  photos,
  provider,
  paymentAmount,
  paymentStatus,
  canceled,
  security,
  routeEta,
  traffic,
}

extension ServiceMetaIconKindX on ServiceMetaIconKind {
  IconData get primaryIcon => switch (this) {
        ServiceMetaIconKind.serviceId => Icons.tag_rounded,
        ServiceMetaIconKind.category => Icons.handyman_rounded,
        ServiceMetaIconKind.createdAt => Icons.add_task_rounded,
        ServiceMetaIconKind.scheduledFor => Icons.schedule_rounded,
        ServiceMetaIconKind.startedAt => Icons.play_circle_outline_rounded,
        ServiceMetaIconKind.finishedAt => Icons.event_available_outlined,
        ServiceMetaIconKind.quotes => Icons.request_quote_rounded,
        ServiceMetaIconKind.location => Icons.place_rounded,
        ServiceMetaIconKind.requestDescription => Icons.description_rounded,
        ServiceMetaIconKind.photos => Icons.photo_library_rounded,
        ServiceMetaIconKind.provider => Icons.engineering_rounded,
        ServiceMetaIconKind.paymentAmount => Icons.payments_outlined,
        ServiceMetaIconKind.paymentStatus => Icons.verified_outlined,
        ServiceMetaIconKind.canceled => Icons.event_busy_outlined,
        ServiceMetaIconKind.security => Icons.lock_rounded,
        ServiceMetaIconKind.routeEta => Icons.route_rounded,
        ServiceMetaIconKind.traffic => Icons.traffic_rounded,
      };

  IconData? get secondaryIcon => switch (this) {
        ServiceMetaIconKind.serviceId => Icons.verified_rounded,
        ServiceMetaIconKind.category => Icons.auto_awesome_rounded,
        ServiceMetaIconKind.createdAt => Icons.check_circle_rounded,
        ServiceMetaIconKind.scheduledFor => Icons.calendar_today_rounded,
        ServiceMetaIconKind.startedAt => Icons.bolt_rounded,
        ServiceMetaIconKind.finishedAt => Icons.check_circle_rounded,
        ServiceMetaIconKind.quotes => Icons.hourglass_top_rounded,
        ServiceMetaIconKind.location => Icons.navigation_rounded,
        ServiceMetaIconKind.requestDescription => Icons.notes_rounded,
        ServiceMetaIconKind.photos => Icons.zoom_in_rounded,
        ServiceMetaIconKind.provider => Icons.verified_user_rounded,
        ServiceMetaIconKind.paymentAmount => Icons.account_balance_wallet_rounded,
        ServiceMetaIconKind.paymentStatus => Icons.shield_rounded,
        ServiceMetaIconKind.canceled => Icons.cancel_rounded,
        ServiceMetaIconKind.security => Icons.gavel_rounded,
        ServiceMetaIconKind.routeEta => Icons.timer_rounded,
        ServiceMetaIconKind.traffic => Icons.speed_rounded,
      };

  Color resolveColor(AppTokens tk) => switch (this) {
        ServiceMetaIconKind.serviceId => tk.info,
        ServiceMetaIconKind.category => tk.clientAccent,
        ServiceMetaIconKind.createdAt => tk.info,
        ServiceMetaIconKind.scheduledFor => tk.clientAccent,
        ServiceMetaIconKind.startedAt => tk.success,
        ServiceMetaIconKind.finishedAt => tk.success,
        ServiceMetaIconKind.quotes => tk.info,
        ServiceMetaIconKind.location => tk.clientAccent,
        ServiceMetaIconKind.requestDescription => tk.brand,
        ServiceMetaIconKind.photos => tk.clientAccent,
        ServiceMetaIconKind.provider => tk.providerAccent,
        ServiceMetaIconKind.paymentAmount => tk.success,
        ServiceMetaIconKind.paymentStatus => tk.security,
        ServiceMetaIconKind.canceled => tk.danger,
        ServiceMetaIconKind.security => tk.security,
        ServiceMetaIconKind.routeEta => tk.info,
        ServiceMetaIconKind.traffic => tk.warning,
      };
}

/// Emblema *Quiet Luxury Dark Glass Squircle Duotone* (`38x38 dp` por padrão).
///
/// Apresenta:
/// - Container Squircle (`BorderRadius.circular(radius)`, `radius = 12`);
/// - Fundo em gradiente translúcido sutil (`0.16 -> 0.08` no dark; calibrado com alto contraste no claro);
/// - Borda fina de `1px` (`accentColor.withValues(alpha: 0.34)`);
/// - Dupla camada vetorial *Duotone* (halo/sombra interna + glifo principal nítido + micro-badge opcional).
class DarkGlassDuotoneBadge extends StatelessWidget {
  const DarkGlassDuotoneBadge({
    super.key,
    this.icon,
    this.kind,
    this.secondaryIcon,
    this.accentColor,
    this.secondaryColor,
    this.size = 38,
    this.radius = 12,
    this.showSecondaryBadge = true,
  });

  const DarkGlassDuotoneBadge.kind(
    ServiceMetaIconKind this.kind, {
    super.key,
    this.icon,
    this.secondaryIcon,
    this.accentColor,
    this.secondaryColor,
    this.size = 38,
    this.radius = 12,
    this.showSecondaryBadge = true,
  });

  const DarkGlassDuotoneBadge.fromKind(
    ServiceMetaIconKind this.kind, {
    super.key,
    this.icon,
    this.secondaryIcon,
    this.accentColor,
    this.secondaryColor,
    this.size = 38,
    this.radius = 12,
    this.showSecondaryBadge = true,
  });

  const DarkGlassDuotoneBadge.preset(
    ServiceMetaIconKind this.kind, {
    super.key,
    this.icon,
    this.secondaryIcon,
    this.accentColor,
    this.secondaryColor,
    this.size = 38,
    this.radius = 12,
    this.showSecondaryBadge = true,
  });

  final IconData? icon;
  final ServiceMetaIconKind? kind;
  final IconData? secondaryIcon;
  final Color? accentColor;
  final Color? secondaryColor;
  final double size;
  final double radius;
  final bool showSecondaryBadge;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final resolvedKind = kind;
    final effectiveIcon = icon ?? resolvedKind?.primaryIcon ?? Icons.circle_rounded;
    final effectiveSecondary = secondaryIcon ?? (showSecondaryBadge ? resolvedKind?.secondaryIcon : null);
    final primary = accentColor ?? resolvedKind?.resolveColor(tk) ?? tk.clientAccent;
    final secondary = secondaryColor ?? primary;

    final startAlpha = tk.isDark ? 0.16 : 0.14;
    final endAlpha = tk.isDark ? 0.08 : 0.06;
    final borderAlpha = tk.isDark ? 0.34 : 0.28;
    final mainIconSize = (size * 0.50).clamp(14.0, 28.0);
    final haloIconSize = (size * 0.62).clamp(16.0, 34.0);
    final microSize = (size * 0.36).clamp(11.0, 16.0);

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: startAlpha),
              secondary.withValues(alpha: endAlpha),
            ],
          ),
          border: Border.all(
            color: primary.withValues(alpha: borderAlpha),
            width: 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Camada 1 Duotone: halo geométrico translúcido suave ao fundo
            Positioned(
              left: size * 0.12,
              top: size * 0.10,
              child: IgnorePointer(
                child: Container(
                  width: haloIconSize * 0.72,
                  height: haloIconSize * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: secondary.withValues(alpha: tk.isDark ? 0.20 : 0.16),
                  ),
                ),
              ),
            ),
            // Camada 2 Duotone: glifo principal nítido
            Icon(
              effectiveIcon,
              size: mainIconSize,
              color: primary,
            ),
            // Camada 3: micro-badge secundário opcional no canto inferior direito
            if (effectiveSecondary != null && showSecondaryBadge && size >= 32)
              Positioned(
                right: 2,
                bottom: 2,
                child: IgnorePointer(
                  child: Container(
                    width: microSize,
                    height: microSize,
                    decoration: BoxDecoration(
                      color: tk.isDark ? const Color(0xFF141B26) : tk.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.42),
                        width: 0.9,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        effectiveSecondary,
                        size: microSize * 0.62,
                        color: secondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Linha executiva de metadado de alto padrão substituindo o antigo `_InfoRow`.
///
/// Exibe `DarkGlassDuotoneBadge` `38x38` à esquerda + `label` legível + `value` alinhado à
/// direita em layout 100% responsivo (zero `RenderFlex overflow` mesmo em telas de `320px`
/// com datas longas) + suporte opcional a `trailingAction` ou cópia em 1 toque.
class ExecutiveMetaTile extends StatelessWidget {
  const ExecutiveMetaTile({
    super.key,
    required this.label,
    required this.value,
    this.kind,
    this.icon,
    this.secondaryIcon,
    this.accentColor,
    this.strong = false,
    this.valueColor,
    this.trailingAction,
    this.trailing,
    this.copyable = false,
    this.copyMessage,
    this.onTap,
    this.badgeSize = 38,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.appendColon = true,
  });

  final String label;
  final String value;
  final ServiceMetaIconKind? kind;
  final IconData? icon;
  final IconData? secondaryIcon;
  final Color? accentColor;
  final bool strong;
  final Color? valueColor;
  final Widget? trailingAction;
  final Widget? trailing;
  final bool copyable;
  final String? copyMessage;
  final VoidCallback? onTap;
  final double badgeSize;
  final EdgeInsetsGeometry padding;
  final bool appendColon;

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    await HapticFeedback.lightImpact();
    if (context.mounted) {
      showSnack(context, copyMessage ?? 'Código $value copiado!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cleanLabel = label.trim().endsWith(':')
        ? label.trim().substring(0, label.trim().length - 1)
        : label.trim();
    final formattedLabel = appendColon ? '$cleanLabel: ' : cleanLabel;
    final effectiveTrailing = trailingAction ??
        trailing ??
        (copyable
            ? IconButton(
                key: ValueKey('copy-meta-$cleanLabel'),
                tooltip: 'Copiar $cleanLabel',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                icon: Icon(Icons.copy_rounded, size: 16, color: accentColor ?? tk.clientAccent),
                onPressed: () => _copyValue(context),
              )
            : null);

    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DarkGlassDuotoneBadge(
            kind: kind,
            icon: icon,
            secondaryIcon: secondaryIcon,
            accentColor: accentColor,
            size: badgeSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 5,
                  child: Text(
                    formattedLabel,
                    style: TextStyle(
                      color: tk.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: valueColor ?? tk.text,
                      fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                      fontSize: strong ? 16 : 14,
                      height: 1.28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (effectiveTrailing != null) ...[
            const SizedBox(width: 6),
            effectiveTrailing,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: row,
    );
  }
}

/// Formatador inteligente de títulos executivos para cards e cabeçalhos de pedidos.
///
/// Remove saudações conversacionais cruas no início (ex.: `"Olá Wagner, boa noite, tudo bem ?"`),
/// colapsa quebras de linha e produz um título executivo conciso para caber em até 2 linhas
/// horizontais sem esmagamento, preservando 100% da descrição integral para `"O que você pediu"`.
class SmartOrderHeadlineFormatter {
  const SmartOrderHeadlineFormatter._();

  static final List<RegExp> _leadingGreetingPatterns = [
    // Ex.: "Olá Wagner, boa noite, tudo bem ?" / "Oi tudo bem?" / "Bom dia!"
    RegExp(
      r'^(?:ol[aá]|oi+|opa|e\s+a[ií])(?:\s+(?:dr\.?|doutor|amigo|pessoal|mestre|[a-zA-ZÀ-ÿ]{2,18}))?[\s,.;:!?-]*',
      caseSensitive: false,
    ),
    RegExp(
      r'^(?:bom\s+dia|boa\s+tarde|boa\s+noite)(?:\s+[a-zA-ZÀ-ÿ]{2,18})?[\s,.;:!?-]*',
      caseSensitive: false,
    ),
    RegExp(
      r'^(?:tudo\s+(?:bem|bom|certo|joia|ótimo|otimo)|como\s+vai(?:\s+voc[eê])?)(?:\s+com\s+voc[eê])?[\s,.;:!?-]*',
      caseSensitive: false,
    ),
  ];

  static final RegExp _incompleteTailStub = RegExp(
    r'^(?:(?:ol[aá]|oi+|bom|boa|tudo)\b.*|(?:preciso|gostaria|quero)(?:\s+de(?:\s+um[a]?)?)?)[\s.…]*$',
    caseSensitive: false,
  );

  static String formatHeadline(
    String rawTitleOrDescription, {
    String? category,
    String? fallbackDescription,
    int maxChars = 68,
  }) {
    final primaryCleaned = _stripGreetingsAndNormalize(rawTitleOrDescription);

    String candidate = primaryCleaned;
    if ((candidate.isEmpty || _incompleteTailStub.hasMatch(candidate)) &&
        fallbackDescription != null &&
        fallbackDescription.trim().isNotEmpty) {
      final fromDesc = _stripGreetingsAndNormalize(fallbackDescription);
      if (fromDesc.isNotEmpty && !_incompleteTailStub.hasMatch(fromDesc)) {
        candidate = fromDesc;
      }
    }

    if (candidate.isEmpty || _incompleteTailStub.hasMatch(candidate)) {
      final cat = (category ?? '').trim();
      if (cat.isNotEmpty) {
        return 'Atendimento de $cat';
      }
      final fallbackRaw = rawTitleOrDescription.replaceAll(RegExp(r'\s+'), ' ').trim();
      return fallbackRaw.isEmpty ? 'Solicitação de serviço' : _truncateCleanly(fallbackRaw, maxChars);
    }

    // Capitaliza a primeira letra caso a remoção da saudação tenha exposto letra minúscula.
    final capitalized = _capitalizeFirst(candidate);
    return _truncateCleanly(capitalized, maxChars);
  }

  static String _stripGreetingsAndNormalize(String input) {
    // Remove blocos de anotação de fotos ("📷 Foto 1: ...") do headline se presentes
    final withoutPhotoNotes = input.split('\n\n📷').first;
    var text = withoutPhotoNotes.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    var changed = true;
    var guard = 0;
    while (changed && guard < 6) {
      changed = false;
      guard++;
      for (final pattern in _leadingGreetingPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.start == 0 && match.end > 0) {
          final rest = text.substring(match.end).trimLeft();
          // Só consome se sobrar texto significativo ou se todo o texto era apenas saudação truncada
          if (rest.isNotEmpty) {
            text = rest;
            changed = true;
          } else {
            text = '';
            changed = false;
            break;
          }
        }
      }
    }
    return text.trim();
  }

  static String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    final first = s[0];
    final upper = first.toUpperCase();
    if (first == upper) return s;
    return '$upper${s.substring(1)}';
  }

  static String _truncateCleanly(String s, int maxChars) {
    if (maxChars <= 4 || s.length <= maxChars) return s;
    final limit = maxChars - 1;
    final slice = s.substring(0, limit);
    final lastSpace = slice.lastIndexOf(' ');
    if (lastSpace >= (limit * 0.6).floor()) {
      final cleanWord = slice.substring(0, lastSpace).replaceAll(RegExp(r'[,;:\s]+$'), '');
      return '$cleanWord…';
    }
    return '${slice.trimRight()}…';
  }
}

/// Galeria em tela cheia deslizável (`PageView.builder`) com zoom/pan (`InteractiveViewer`),
/// contador elegante no topo (`1 / 4`), legenda da foto e renderização instantânea `0 ms`.
class FullscreenSwipePhotoGallery extends StatefulWidget {
  const FullscreenSwipePhotoGallery({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.imageBuilder,
  });

  final List<({String path, String label})> items;
  final int initialIndex;
  final Widget Function(BuildContext context, String path, BoxFit fit)? imageBuilder;

  static Future<void> show(
    BuildContext context, {
    required List<({String path, String label})> items,
    int initialIndex = 0,
    Widget Function(BuildContext, String, BoxFit)? imageBuilder,
  }) {
    if (items.isEmpty) return Future<void>.value();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => FullscreenSwipePhotoGallery(
        items: items,
        initialIndex: initialIndex,
        imageBuilder: imageBuilder,
      ),
    );
  }

  @override
  State<FullscreenSwipePhotoGallery> createState() => _FullscreenSwipePhotoGalleryState();
}

class _FullscreenSwipePhotoGalleryState extends State<FullscreenSwipePhotoGallery> {
  late int _currentIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
  late final PageController _pageController = PageController(initialPage: _currentIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPhoto(BuildContext context, String path) {
    if (widget.imageBuilder != null) {
      return widget.imageBuilder!(context, path, BoxFit.contain);
    }
    if (path.startsWith('http')) {
      return InstantCachedImage(
        url: path,
        fit: BoxFit.contain,
        radius: 0,
      );
    }
    return InstantCachedImage(
      storagePath: path,
      fit: BoxFit.contain,
      radius: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final current = widget.items[_currentIndex];

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF070B12),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey('fullscreen-gallery-pageview'),
              controller: _pageController,
              itemCount: total,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (ctx, index) {
                final item = widget.items[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: _buildPhoto(ctx, item.path),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: IconButton(
                      key: const ValueKey('fullscreen-gallery-close'),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      current.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    key: const ValueKey('fullscreen-gallery-counter'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < total; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentIndex ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _currentIndex ? Colors.white : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

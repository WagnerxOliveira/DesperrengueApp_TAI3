import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/utils/tag_normalizer.dart';

/// Quantas categorias aparecem direto no painel; o resto fica em "Ver todas" (com busca).
const int kHomeCategoryCount = 11;

double _categoryGridAspectRatio(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final scale = MediaQuery.textScalerOf(context).scale(12.5) / 12.5;
  final base = width < 360 ? 0.82 : 0.90;
  final extraScale = (scale - 1.0).clamp(0.0, 0.6);
  return (base - extraScale * 0.22).clamp(0.64, 0.92);
}

/// Categorias cujo nome OU sinônimo contém [query] ("eletricista" → Elétrica).
/// Passagem única sobre as categorias + `Set` com os slugs encontrados nos sinônimos.
List<ServiceCategory> searchCategories(
  String query, {
  List<ServiceCategory> from = kCategories,
  CategoryColorFamily family = CategoryColorFamily.all,
}) {
  final filteredByFamily = filterCategoriesByFamily(from, family);
  final q = normalizeTag(query);
  if (q.isEmpty) return List.of(filteredByFamily);
  final bySynonym = <String>{
    for (final e in kTagAliases.entries)
      if (e.key.contains(q)) e.value,
  };
  return [
    for (final c in filteredByFamily)
      if (normalizeTag(c.name).contains(q) || bySynonym.contains(canonicalTag(c.name))) c,
  ];
}

/// Filtra categorias por Família Cromática Semântica (Lei de Hick).
List<ServiceCategory> filterCategoriesByFamily(
  List<ServiceCategory> from,
  CategoryColorFamily family,
) {
  if (family == CategoryColorFamily.all) return List.of(from);
  if (family == CategoryColorFamily.urgent) {
    return [
      for (final c in from)
        if (resolveCategoryBrandSpec(c.name).isUrgent) c,
    ];
  }
  return [
    for (final c in from)
      if (resolveCategoryBrandSpec(c.name).family == family) c,
  ];
}

/// Grade de categorias do painel: as principais + "Ver todas (N)".
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.onPick, this.count = kHomeCategoryCount});

  final ValueChanged<String> onPick;
  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = kCategories.take(count).toList();
    final hasMore = kCategories.length > count;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: _categoryGridAspectRatio(context),
      children: [
        for (final c in shown) CategoryTile(category: c, onTap: () => onPick(c.name)),
        if (hasMore) _MoreTile(total: kCategories.length, onTap: () => showAllCategoriesSheet(context, onPick: onPick)),
      ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  static double _measureWordWidth(
    String word,
    TextStyle style,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      maxLines: 1,
      textScaler: textScaler,
      textDirection: textDirection,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = category.name.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    final isSingleWord = words.length <= 1;
    const singleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      letterSpacing: -0.2,
      height: 1.15,
    );
    const multiStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12.2,
      letterSpacing: -0.2,
      height: 1.15,
    );

    return Semantics(
      button: true,
      label: 'Categoria ${category.name}',
      child: InkWell(
        key: ValueKey('category:${category.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryBrandEmblem(
                categoryName: category.name,
                size: 64,
              ),
              const SizedBox(height: 6),
              Flexible(
                child: isSingleWord
                    ? SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            category.name,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: singleStyle,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final scaler = MediaQuery.textScalerOf(context);
                          final dir = Directionality.of(context);
                          double longestWord = 0;
                          for (final w in words) {
                            final ww = _measureWordWidth(w, multiStyle, scaler, dir);
                            if (ww > longestWord) longestWord = ww;
                          }
                          final availW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                              ? constraints.maxWidth
                              : 96.0;
                          final boxWidth = math.max(availW, longestWord + 4.0);
                          return SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: boxWidth,
                                child: Text(
                                  category.name,
                                  maxLines: 2,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: multiStyle,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      label: 'Ver todas as $total categorias',
      child: InkWell(
        key: const ValueKey('categories-see-all'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A273D), Color(0xFF0E1525)],
                  ),
                  border: Border.all(
                    color: tk.clientAccent.withValues(alpha: 0.48),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF020617).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.grid_view_rounded, size: 28, color: tk.clientAccent),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Ver todas ($total)',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tk.clientAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Todas as categorias, com busca (por nome ou profissão) e filtro rápido por Família Cromática.
Future<void> showAllCategoriesSheet(BuildContext context, {required ValueChanged<String> onPick}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _AllCategories(
        scroll: scroll,
        onPick: (name) {
          Navigator.of(ctx).pop();
          onPick(name);
        },
      ),
    ),
  );
}

class _AllCategories extends StatefulWidget {
  const _AllCategories({required this.scroll, required this.onPick});

  final ScrollController scroll;
  final ValueChanged<String> onPick;

  @override
  State<_AllCategories> createState() => _AllCategoriesState();
}

class _AllCategoriesState extends State<_AllCategories> {
  final _q = TextEditingController();
  CategoryColorFamily _selectedFamily = CategoryColorFamily.all;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final list = searchCategories(_q.text, family: _selectedFamily);
    final filterBarHeight = MediaQuery.textScalerOf(context).scale(40).clamp(40.0, 56.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            key: const ValueKey('category-search'),
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar categoria ou profissão (ex.: jardineiro)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_q.clear),
                    ),
            ),
          ),
        ),
        // Faixa horizontal de Filtro Rápido por Família Cromática (Lei de Hick)
        SizedBox(
          height: filterBarHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: CategoryColorFamily.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final fam = CategoryColorFamily.values[idx];
              final selected = _selectedFamily == fam;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Filtro ${fam.label}',
                child: GestureDetector(
                  key: ValueKey('category-family:${fam.id}'),
                  onTap: () => setState(() => _selectedFamily = fam),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? fam.primary.withValues(alpha: 0.20)
                          : tk.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? fam.primary
                            : tk.border,
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fam.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fam.label,
                          style: TextStyle(
                            fontSize: 12.2,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? tk.text : tk.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Nenhuma categoria encontrada.', style: TextStyle(color: tk.textMuted)))
              : GridView.count(
                  controller: widget.scroll,
                  crossAxisCount: 3,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: _categoryGridAspectRatio(context),
                  children: [for (final c in list) CategoryTile(category: c, onTap: () => widget.onPick(c.name))],
                ),
        ),
      ],
    );
  }
}

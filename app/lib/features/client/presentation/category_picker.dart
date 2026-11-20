import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/utils/tag_normalizer.dart';

/// Quantas categorias aparecem direto no painel; o resto fica em "Ver todas" (com busca).
const int kHomeCategoryCount = 11;

double _categoryGridAspectRatio(BuildContext context) {
  final layout = context.layout;
  final cols = _categoryColumns(context);
  final base = cols == 2 ? 1.12 : (layout.isWide ? 0.96 : 0.88);
  final extraScale = (layout.textScale - 1.0).clamp(0.0, 0.6);
  return (base - extraScale * 0.24).clamp(0.68, 1.15);
}

int _categoryColumns(BuildContext context) {
  final layout = context.layout;
  if (layout.isCompact || (!layout.isWide && layout.isLargeText)) return 2;
  if (layout.isWide) return 4;
  return 3;
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
      crossAxisCount: _categoryColumns(context),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.s16,
      crossAxisSpacing: AppSpace.s8,
      childAspectRatio: _categoryGridAspectRatio(context),
      children: [
        for (var i = 0; i < shown.length; i++)
          AppStaggerItem(
            index: i,
            scope: 'home-categories',
            child: CategoryTile(category: shown[i], onTap: () => onPick(shown[i].name)),
          ),
        if (hasMore)
          _MoreTile(
            total: kCategories.length,
            onTap: () => showAllCategoriesSheet(context, onPick: onPick),
          ),
      ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final labelStyle = AppType.caption.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      height: 1.2,
      color: tk.text,
    );

    return AppPressable(
      key: ValueKey('category:${category.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius + 2),
      semanticLabel: 'Categoria ${category.name}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryBrandEmblem(
              categoryName: category.name,
              size: 64,
            ),
            const SizedBox(height: AppSpace.s8 - 2),
            Flexible(
              child: Text(
                category.name,
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
          ],
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
    return AppPressable(
      key: const ValueKey('categories-see-all'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius + 2),
      semanticLabel: 'Ver todas as $total categorias',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: AppSpace.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppGeometry.itemRadius + 2),
                color: tk.accentSoft,
                border: Border.all(
                  color: tk.accent.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: tk.elevation(1),
              ),
              child: Icon(Icons.grid_view_rounded, size: 28, color: tk.accentInk),
            ),
            const SizedBox(height: AppSpace.s8 - 2),
            Flexible(
              child: Text(
                'Ver todas ($total)',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: AppType.tabular(AppType.caption).copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: tk.accentInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Todas as categorias, com busca (por nome ou profissão) e filtro rápido por Família Cromática.
Future<void> showAllCategoriesSheet(BuildContext context, {required ValueChanged<String> onPick}) {
  return AppSheet.show<void>(
    context,
    title: 'Todas as categorias',
    maxHeightFactor: 0.92,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxSheetHeight = math.max(
        280.0,
        media.size.height * 0.74 - media.viewInsets.bottom,
      );
      return SizedBox(
        height: maxSheetHeight,
        child: DraggableScrollableSheet(
          expand: true,
          initialChildSize: 1.0,
          minChildSize: 0.85,
          maxChildSize: 1.0,
          builder: (sheetCtx, scroll) => _AllCategories(
            scroll: scroll,
            onPick: (name) {
              Navigator.of(sheetCtx).pop();
              onPick(name);
            },
          ),
        ),
      );
    },
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
    final filterBarHeight = MediaQuery.textScalerOf(context).scale(48).clamp(48.0, 64.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const ValueKey('category-search'),
          controller: _q,
          hint: 'Buscar categoria ou profissão (ex.: jardineiro)',
          prefixIcon: Icons.search_rounded,
          onChanged: (_) => setState(() {}),
          suffix: _q.text.isEmpty
              ? null
              : AppIconButton(
                  tooltip: 'Limpar busca',
                  icon: Icons.close_rounded,
                  onPressed: () => setState(_q.clear),
                ),
        ),
        const SizedBox(height: AppSpace.s8),
        // Faixa horizontal de Filtro Rápido por Família Cromática (Lei de Hick)
        SizedBox(
          height: filterBarHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CategoryColorFamily.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s4 + 2),
            itemBuilder: (context, idx) {
              final fam = CategoryColorFamily.values[idx];
              final selected = _selectedFamily == fam;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Filtro ${fam.label}',
                child: AppPressable(
                  key: ValueKey('category-family:${fam.id}'),
                  onTap: () => setState(() => _selectedFamily = fam),
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                  isButton: false,
                  child: AnimatedContainer(
                    duration: AppMotion.d(context, AppMotion.fadeShort),
                    curve: AppMotion.fadeCurve,
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s8),
                    decoration: BoxDecoration(
                      color: selected
                          ? fam.primary.withValues(alpha: tk.isDark ? 0.24 : 0.16)
                          : tk.surface,
                      borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                      border: Border.all(
                        color: selected ? fam.primary : tk.border,
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fam.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s4),
                        Text(
                          fam.label,
                          style: AppType.caption.copyWith(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
        const SizedBox(height: AppSpace.s8),
        Expanded(
          child: list.isEmpty
              ? const AppEmptyState(
                  icon: Icons.category_outlined,
                  title: 'Nenhuma categoria encontrada.',
                  padding: EdgeInsets.all(AppSpace.s24),
                )
              : GridView.count(
                  controller: widget.scroll,
                  crossAxisCount: _categoryColumns(context),
                  padding: EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s24 + MediaQuery.paddingOf(context).bottom),
                  mainAxisSpacing: AppSpace.s16,
                  crossAxisSpacing: AppSpace.s8,
                  childAspectRatio: _categoryGridAspectRatio(context),
                  children: [for (final c in list) CategoryTile(category: c, onTap: () => widget.onPick(c.name))],
                ),
        ),
      ],
    );
  }
}

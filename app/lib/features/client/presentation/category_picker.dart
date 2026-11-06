import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/utils/tag_normalizer.dart';

/// Quantas categorias aparecem direto no painel; o resto fica em "Ver todas" (com busca).
const int kHomeCategoryCount = 11;

/// Categorias cujo nome OU sinônimo contém [query] ("eletricista" → Elétrica).
/// Passagem única sobre as categorias + `Set` com os slugs encontrados nos sinônimos.
List<ServiceCategory> searchCategories(String query, {List<ServiceCategory> from = kCategories}) {
  final q = normalizeTag(query);
  if (q.isEmpty) return List.of(from);
  final bySynonym = <String>{
    for (final e in kTagAliases.entries)
      if (e.key.contains(q)) e.value,
  };
  return [
    for (final c in from)
      if (normalizeTag(c.name).contains(q) || bySynonym.contains(canonicalTag(c.name))) c,
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
      childAspectRatio: 0.92,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('category:${category.name}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 33,
            backgroundColor: Color(category.colorValue),
            child: Icon(categoryIcon(category.name), size: 30, color: AppColors.ink.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.15),
          ),
        ],
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
    return InkWell(
      key: const ValueKey('categories-see-all'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 33, backgroundColor: tk.clientSoft, child: Icon(Icons.apps_rounded, size: 30, color: tk.clientAccent)),
          const SizedBox(height: 8),
          Text('Ver todas ($total)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tk.clientAccent)),
        ],
      ),
    );
  }
}

/// Todas as categorias, com busca (por nome ou profissão).
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

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = searchCategories(_q.text);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            key: const ValueKey('category-search'),
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar categoria ou profissão (ex.: jardineiro)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_q.clear)),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Nenhuma categoria encontrada.', style: TextStyle(color: context.tk.textMuted)))
              : GridView.count(
                  controller: widget.scroll,
                  crossAxisCount: 3,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.92,
                  children: [for (final c in list) CategoryTile(category: c, onTap: () => widget.onPick(c.name))],
                ),
        ),
      ],
    );
  }
}

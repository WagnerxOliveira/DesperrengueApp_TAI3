import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'category_picker.dart';

/// Categorias mais pedidas, exibidas direto no seletor (nomes existentes em
/// [kCategories]; o resto fica atrás de "Ver todas" e da busca).
const List<String> kPopularCategoryNames = <String>[
  'Elétrica',
  'Encanador',
  'Limpeza',
  'Pintura',
  'Montagem',
  'Ar-condicionado',
  'Chaveiro',
  'Pequenos Reparos',
];

/// Quantos resultados de busca aparecem inline antes de pedir para refinar.
const int kCategorySearchInlineLimit = 8;

/// Seletor de categoria do pedido ("1 de 3: O que precisa ser feito?").
///
/// Estratégia (Lei de Hick + Lei de Fitts + economia de rolagem):
///  * **Busca primeiro**: quem sabe o que quer digita ("eletricista", "pintor") e vê
///    no máximo 8 resultados; sinônimos funcionam (mesma busca da tela inicial).
///  * **Só 8 "mais pedidos"** em 2 colunas (1 em telas apertadas/fonte grande), cada
///    um um alvo de toque de >= 56 dp com o emblema oficial da categoria — em vez de
///    32 pílulas empilhadas que exigiam rolar a tela inteira.
///  * **"Ver todas as N categorias"** abre a folha com busca e filtros por família,
///    rolando dentro dela (a página não cresce).
///  * **Ao escolher, o seletor encolhe** para um cartão de 1 linha ("Categoria
///    escolhida" + "Trocar"): o campo de descrição sobe e o usuário não rola nada.
class RequestCategoryChooser extends StatefulWidget {
  const RequestCategoryChooser({
    super.key,
    required this.selected,
    required this.onSelected,
    this.allowed,
  });

  /// Categoria atualmente escolhida (null = ainda não escolheu).
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Restringe às especialidades de um profissional específico (pedido direto).
  final List<ServiceCategory>? allowed;

  @override
  State<RequestCategoryChooser> createState() => _RequestCategoryChooserState();
}

class _RequestCategoryChooserState extends State<RequestCategoryChooser> {
  final TextEditingController _query = TextEditingController();
  bool _changing = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _collapsed => widget.selected != null && !_changing;

  List<ServiceCategory> get _base {
    final allowed = widget.allowed;
    return (allowed != null && allowed.isNotEmpty) ? allowed : kCategories;
  }

  bool get _restricted => widget.allowed != null && widget.allowed!.isNotEmpty;

  List<ServiceCategory> get _popular {
    if (_restricted) return _base;
    return [
      for (final name in kPopularCategoryNames)
        for (final c in kCategories)
          if (c.name == name) c,
    ];
  }

  void _pick(String name) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _changing = false;
      _query.clear();
    });
    widget.onSelected(name);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.d(context, AppMotion.page),
      curve: AppMotion.pageCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.d(context, AppMotion.fadeShort),
        switchInCurve: AppMotion.fadeCurve,
        switchOutCurve: AppMotion.fadeCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: _collapsed
            ? _SelectedCategoryCard(
                key: const ValueKey('category-selected-card'),
                name: widget.selected!,
                onChange: () => setState(() => _changing = true),
              )
            : _buildPicker(context),
      ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final tk = context.tk;
    final base = _base;
    final q = _query.text.trim();
    final searching = q.isNotEmpty;
    final showSearch = !_restricted || base.length > kPopularCategoryNames.length;
    final results = searching ? searchCategories(q, from: base) : const <ServiceCategory>[];

    return Column(
      key: const ValueKey('category-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Qual serviço você precisa?',
          style: AppType.titleSm.copyWith(color: tk.text),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          _restricted
              ? 'Escolha a especialidade para este profissional.'
              : 'Toque na categoria ou busque pelo nome da profissão.',
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s12),
        if (showSearch) ...[
          AppTextField(
            key: const ValueKey('category-search-inline'),
            controller: _query,
            hint: 'Buscar (ex.: eletricista, pintor)',
            semanticLabel: 'Buscar categoria ou profissão',
            prefixIcon: Icons.search_rounded,
            onChanged: (_) => setState(() {}),
            suffix: searching
                ? AppIconButton(
                    tooltip: 'Limpar busca',
                    icon: Icons.close_rounded,
                    onPressed: () => setState(_query.clear),
                  )
                : null,
          ),
          const SizedBox(height: AppSpace.s12),
        ],
        if (searching)
          _buildResults(context, results)
        else ...[
          if (!_restricted) ...[
            Text(
              'Mais pedidos',
              style: AppType.bodyStrong.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s8),
          ],
          _ChoiceGrid(
            categories: _popular,
            selected: widget.selected,
            onPick: _pick,
          ),
          if (!_restricted && kCategories.length > _popular.length) ...[
            const SizedBox(height: AppSpace.s12),
            AppButton(
              key: const ValueKey('category-choice-see-all'),
              label: 'Ver todas as ${kCategories.length} categorias',
              icon: Icons.grid_view_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => showAllCategoriesSheet(context, onPick: _pick),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildResults(BuildContext context, List<ServiceCategory> results) {
    final tk = context.tk;
    if (results.isEmpty) {
      return AppCard(
        key: const ValueKey('category-search-empty'),
        variant: AppCardVariant.tonal,
        color: tk.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nenhuma categoria encontrada.',
              style: AppType.bodyStrong.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              'Tente outro nome ou veja a lista completa.',
              style: AppType.bodySm.copyWith(color: tk.textMuted),
            ),
            if (!_restricted) ...[
              const SizedBox(height: AppSpace.s12),
              AppButton(
                label: 'Ver todas as ${kCategories.length} categorias',
                icon: Icons.grid_view_rounded,
                variant: AppButtonVariant.secondary,
                compact: true,
                onPressed: () => showAllCategoriesSheet(context, onPick: _pick),
              ),
            ],
          ],
        ),
      );
    }
    final shown = results.take(kCategorySearchInlineLimit).toList();
    return Column(
      key: const ValueKey('category-search-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceGrid(
          categories: shown,
          selected: widget.selected,
          onPick: _pick,
        ),
        if (results.length > shown.length) ...[
          const SizedBox(height: AppSpace.s8),
          Text(
            'Mostrando ${shown.length} de ${results.length}. Digite mais letras para refinar.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Grade de escolhas em linhas de altura igual (1 coluna em telas apertadas ou com
/// fonte grande, para o nome da categoria nunca quebrar no meio da palavra).
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.categories,
    required this.selected,
    required this.onPick,
  });

  final List<ServiceCategory> categories;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scale = math.max(1.0, context.layout.textScale);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTile = 150.0 * scale;
        final cols = (constraints.maxWidth / (minTile + AppSpace.s8))
            .floor()
            .clamp(1, 4);
        final rows = <Widget>[];
        for (var i = 0; i < categories.length; i += cols) {
          final slice = categories.skip(i).take(cols).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: j < slice.length
                          ? _ChoiceTile(
                              category: slice[j],
                              selected: selected == slice[j].name,
                              onTap: () => onPick(slice[j].name),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + cols < categories.length) {
            rows.add(const SizedBox(height: AppSpace.s8));
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ServiceCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final radius = BorderRadius.circular(AppGeometry.itemRadius);
    return AppPressable(
      key: ValueKey('category-choice:${category.name}'),
      onTap: onTap,
      borderRadius: radius,
      semanticLabel:
          selected ? '${category.name}, selecionada' : 'Categoria ${category.name}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.d(context, AppMotion.fade),
        curve: AppMotion.fadeCurve,
        constraints: const BoxConstraints(minHeight: AppGeometry.itemMinHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? tk.accentSoft : tk.card,
          borderRadius: radius,
          border: Border.all(
            color: selected ? tk.accent : tk.border,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CategoryBrandEmblem(categoryName: category.name, size: 40),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                category.name,
                style: AppType.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: tk.text,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpace.s4),
              Icon(Icons.check_circle_rounded, size: 20, color: tk.accentInk),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resumo de 1 linha depois que a categoria é escolhida (libera a tela para o
/// campo de descrição, sem rolagem extra).
class _SelectedCategoryCard extends StatelessWidget {
  const _SelectedCategoryCard({
    super.key,
    required this.name,
    required this.onChange,
  });

  final String name;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final stacked = context.layout.isLargeText;
    final info = Row(
      children: [
        CategoryBrandEmblem(categoryName: name, size: 48),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categoria escolhida',
                style: AppType.bodySm.copyWith(
                  color: tk.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(name, style: AppType.titleSm.copyWith(color: tk.text)),
            ],
          ),
        ),
      ],
    );
    final changeButton = AppButton(
      key: const ValueKey('btn-change-category'),
      label: 'Trocar',
      icon: Icons.swap_horiz_rounded,
      variant: AppButtonVariant.tertiary,
      compact: true,
      expand: stacked,
      onPressed: onChange,
    );
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.accentSoft,
      borderColor: tk.accent.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpace.s12),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: AppSpace.s8),
                changeButton,
              ],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: AppSpace.s8),
                changeButton,
              ],
            ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_service.dart';
import 'design_system/design_system.dart';

/// Evidência fotográfica selecionada pelo cliente, enriquecida com:
/// - [caption]: descrição breve do que a foto mostra;
/// - [actionSuggestion]: sugestão do cliente sobre o que pode/deve ser feito;
/// - [focalPoint]: coordenada normalizada (0..1, 0..1) onde o cliente tocou para apontar o defeito.
class PickedImage {
  const PickedImage(
    this.bytes,
    this.ext,
    this.name, {
    this.caption,
    this.actionSuggestion,
    this.focalPoint,
  });

  final Uint8List bytes;
  final String ext;
  final String name;
  final String? caption;
  final String? actionSuggestion;
  final Offset? focalPoint;

  bool get hasContextAnnotation =>
      (caption != null && caption!.trim().isNotEmpty) ||
      (actionSuggestion != null && actionSuggestion!.trim().isNotEmpty) ||
      focalPoint != null;

  String get combinedSummary {
    final c = (caption ?? '').trim();
    final s = (actionSuggestion ?? '').trim();
    if (c.isNotEmpty && s.isNotEmpty) return '$c — Sugestão: $s';
    if (c.isNotEmpty) return c;
    if (s.isNotEmpty) return 'Sugestão: $s';
    return '';
  }

  PickedImage copyWith({
    Uint8List? bytes,
    String? ext,
    String? name,
    String? caption,
    String? actionSuggestion,
    Offset? focalPoint,
    bool clearFocalPoint = false,
  }) {
    return PickedImage(
      bytes ?? this.bytes,
      ext ?? this.ext,
      name ?? this.name,
      caption: caption ?? this.caption,
      actionSuggestion: actionSuggestion ?? this.actionSuggestion,
      focalPoint: clearFocalPoint ? null : (focalPoint ?? this.focalPoint),
    );
  }

  Map<String, dynamic> toAnnotationMap({
    required int index,
    String? path,
    String? storagePath,
  }) =>
      {
        'photo_index': index + 1,
        'file_name': name,
        'storage_path': ?(path ?? storagePath),
        'caption': (caption ?? '').trim(),
        'action_suggestion': (actionSuggestion ?? '').trim(),
        if (focalPoint != null) ...{
          'focal_x': double.parse(focalPoint!.dx.toStringAsFixed(3)),
          'focal_y': double.parse(focalPoint!.dy.toStringAsFixed(3)),
        },
      };
}

final ImagePicker _picker = ImagePicker();

/// Abre câmera ou galeria e devolve a imagem capturada.
/// Quando [promptContextStudio] é true, abre automaticamente após o "OK" da câmera
/// o Estúdio de Contexto da Foto para o cliente adicionar uma descrição breve e/ou sugestão.
Future<PickedImage?> pickImage(
  BuildContext context, {
  ImageSource? source,
  bool promptContextStudio = false,
  String? categoryName,
  int photoIndex = 0,
}) async {
  var src = source;
  src ??= await AppSheet.show<ImageSource>(
    context,
    title: 'Adicionar foto',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppListTile(
          leadingIcon: Icons.photo_camera_rounded,
          title: 'Tirar foto',
          subtitle: 'Fotografe o local e adicione uma breve explicação',
          showChevron: true,
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        const SizedBox(height: AppSpace.s8),
        AppListTile(
          leadingIcon: Icons.photo_library_rounded,
          title: 'Escolher da galeria',
          subtitle: 'Selecione uma imagem existente e descreva o ponto',
          showChevron: true,
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ],
    ),
  );
  if (src == null) return null;
  try {
    final file = await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final rawPicked = PickedImage(bytes, MediaService.extOf(file.name), file.name);
    if (!promptContextStudio || !context.mounted) {
      return rawPicked;
    }
    final annotated = await showPhotoContextStudioSheet(
      context,
      image: rawPicked,
      photoIndex: photoIndex,
      categoryName: categoryName,
    );
    return annotated ?? rawPicked;
  } catch (e) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        'Não foi possível acessar a câmera/galeria. Verifique as permissões.',
        kind: AppSnackKind.error,
      );
    }
    return null;
  }
}

/// Sugestões rápidas contextualizadas por categoria para que o cliente possa
/// descrever a foto ou sugerir o reparo com 1 toque.
List<({String caption, String suggestion})> photoQuickPresetsForCategory(
  String? categoryName,
) {
  final cat = (categoryName ?? '').toLowerCase();
  if (cat.contains('elétr') || cat.contains('eletr')) {
    return const [
      (
        caption: 'Disjuntor desarmando / aquecendo no quadro',
        suggestion: 'Substituir disjuntor e revisar aperto dos cabos',
      ),
      (
        caption: 'Tomada ou interruptor com mau contato / derretido',
        suggestion: 'Trocar módulo da tomada e isolar fiação',
      ),
      (
        caption: 'Ponto elétrico do chuveiro / luminária',
        suggestion: 'Instalar equipamento novo e testar aterramento',
      ),
    ];
  }
  if (cat.contains('encan') || cat.contains('hidr') || cat.contains('desentup')) {
    return const [
      (
        caption: 'Vazamento visível na conexão / tubulação',
        suggestion: 'Refazer vedação ou substituir conexão trincada',
      ),
      (
        caption: 'Torneira, registro ou válvula pingando',
        suggestion: 'Trocar reparo interno ou instalar peça nova',
      ),
      (
        caption: 'Mancha de umidade / infiltração na parede',
        suggestion: 'Localizar origem do vazamento e estancar',
      ),
    ];
  }
  if (cat.contains('ar') || cat.contains('clim') || cat.contains('geladeira') || cat.contains('eletro')) {
    return const [
      (
        caption: 'Aparelho ligando mas sem gelar / sem funcionar',
        suggestion: 'Testar capacitor, gás ou placa e substituir componente',
      ),
      (
        caption: 'Etiqueta de modelo e série do equipamento',
        suggestion: 'Conferir compatibilidade da peça para reposição',
      ),
      (
        caption: 'Vazamento de água / ruído anormal no aparelho',
        suggestion: 'Higienizar dreno e revisar conjunto mecânico',
      ),
    ];
  }
  return const [
    (
      caption: 'Ponto exato onde está o defeito / problema',
      suggestion: 'Avaliar reparo ou substituição da parte danificada',
    ),
    (
      caption: 'Visão geral do local do serviço',
      suggestion: 'Trazer ferramentas adequadas para este acesso',
    ),
    (
      caption: 'Peça ou material atual que precisa de troca',
      suggestion: 'Substituir pelo modelo compatível e dar acabamento',
    ),
  ];
}

/// Abre o Estúdio Pós-Captura da Foto (Bottom Sheet) permitindo ao cliente:
/// 1. Tocar na foto para marcar o ponto exato do problema (Pino Focal);
/// 2. Escolher um chip inteligente ou digitar uma breve descrição do que a foto significa;
/// 3. Informar uma sugestão do que pode/deve ser feito.
Future<PickedImage?> showPhotoContextStudioSheet(
  BuildContext context, {
  required PickedImage image,
  required int photoIndex,
  String? categoryName,
}) {
  return AppSheet.show<PickedImage>(
    context,
    builder: (ctx) => PhotoContextStudioSheet(
      image: image,
      photoIndex: photoIndex,
      categoryName: categoryName,
    ),
  );
}

class PhotoContextStudioSheet extends StatefulWidget {
  const PhotoContextStudioSheet({
    super.key,
    required this.image,
    required this.photoIndex,
    this.categoryName,
  });

  final PickedImage image;
  final int photoIndex;
  final String? categoryName;

  @override
  State<PhotoContextStudioSheet> createState() => _PhotoContextStudioSheetState();
}

class _PhotoContextStudioSheetState extends State<PhotoContextStudioSheet> {
  late final TextEditingController _captionCtrl = TextEditingController(
    text: widget.image.caption ?? '',
  );
  late final TextEditingController _suggestionCtrl = TextEditingController(
    text: widget.image.actionSuggestion ?? '',
  );
  Offset? _focalPoint;

  @override
  void initState() {
    super.initState();
    _focalPoint = widget.image.focalPoint;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _suggestionCtrl.dispose();
    super.dispose();
  }

  void _saveWithAnnotations() {
    final cap = _captionCtrl.text.trim();
    final sug = _suggestionCtrl.text.trim();
    Navigator.of(context).pop(
      PickedImage(
        widget.image.bytes,
        widget.image.ext,
        widget.image.name,
        caption: cap.isEmpty ? null : cap,
        actionSuggestion: sug.isEmpty ? null : sug,
        focalPoint: _focalPoint,
      ),
    );
  }

  void _skipAnnotations() {
    Navigator.of(context).pop(widget.image);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final presets = photoQuickPresetsForCategory(widget.categoryName);
    final compact = context.layout.isCompact || context.layout.isLargeText;

    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('photo-context-studio-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppGeometry.iconTileSize,
              height: AppGeometry.iconTileSize,
              decoration: BoxDecoration(
                color: tk.accentSoft,
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                color: tk.accentInk,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto ${widget.photoIndex + 1} Confirmada • Detalhar Evidência',
                    style: AppType.titleSm.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Explique brevemente o que a foto mostra ou sugira o que deve ser feito.',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        // Preview interativo com toque para marcar o Pino Focal (x, y)
        LayoutBuilder(
          builder: (context, constraints) {
            final previewW = constraints.maxWidth;
            const previewH = 180.0;
            return GestureDetector(
              key: const ValueKey('photo-studio-preview'),
              onTapDown: (details) {
                final dx = (details.localPosition.dx / previewW).clamp(0.05, 0.95);
                final dy = (details.localPosition.dy / previewH).clamp(0.08, 0.92);
                setState(() => _focalPoint = Offset(dx, dy));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                child: SizedBox(
                  width: previewW,
                  height: previewH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(widget.image.bytes, fit: BoxFit.cover),
                      Positioned(
                        left: AppSpace.s8,
                        top: AppSpace.s8,
                        right: AppSpace.s8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s12,
                                  vertical: AppSpace.s4 + 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppShellColors.brandBackdrop.withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                      color: AppShellColors.benefitAccent,
                                    ),
                                    const SizedBox(width: AppSpace.s8),
                                    Flexible(
                                      child: Text(
                                        _focalPoint == null
                                            ? 'Toque no ponto da foto para destacar o defeito (opcional)'
                                            : 'Ponto de atenção marcado na foto ✓',
                                        maxLines: 2,
                                        style: AppType.bodySm.copyWith(
                                          color: AppShellColors.onBrand,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_focalPoint != null) ...[
                              const SizedBox(width: AppSpace.s8),
                              AppPressable(
                                semanticLabel: 'Limpar pino',
                                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                                onTap: () => setState(() => _focalPoint = null),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: AppGeometry.minTarget,
                                    minHeight: AppGeometry.minTarget,
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpace.s12,
                                        vertical: AppSpace.s8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppShellColors.brandBackdrop.withValues(alpha: 0.90),
                                        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                                      ),
                                      child: Text(
                                        'Limpar pino',
                                        style: AppType.caption.copyWith(
                                          color: AppShellColors.onBrand,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_focalPoint != null)
                        Positioned(
                          left: (_focalPoint!.dx * previewW) - 18,
                          top: (_focalPoint!.dy * previewH) - 18,
                          child: IgnorePointer(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tk.accent.withValues(alpha: 0.28),
                                border: Border.all(
                                  color: AppShellColors.onBrand,
                                  width: 2.2,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tk.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          'Sugestões rápidas (toque para preencher em 1 segundo):',
          style: AppType.bodySm.copyWith(
            fontWeight: FontWeight.w600,
            color: tk.textMuted,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        SingleChildScrollView(
          key: const ValueKey('photo-studio-quick-chips'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < presets.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s8),
                  child: ActionChip(
                    key: ValueKey('photo-preset-chip-$i'),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    avatar: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: tk.accentInk,
                    ),
                    label: Text(
                      presets[i].caption,
                      style: AppType.bodySm.copyWith(
                        color: tk.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _captionCtrl.text = presets[i].caption;
                        if (_suggestionCtrl.text.trim().isEmpty) {
                          _suggestionCtrl.text = presets[i].suggestion;
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        AppTextField(
          key: const ValueKey('photo-studio-caption-field'),
          controller: _captionCtrl,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          label: 'O que esta foto mostra? (Descrição breve)',
          hint: 'Ex.: Registro pingando atrás da pia / Disjuntor queimado',
          prefixIcon: Icons.chat_bubble_outline_rounded,
        ),
        const SizedBox(height: AppSpace.s12),
        AppTextField(
          key: const ValueKey('photo-studio-suggestion-field'),
          controller: _suggestionCtrl,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          label: 'Sugestão do que pode ser feito (Opcional)',
          hint: 'Ex.: Acho que precisa trocar a vedação ou substituir a peça',
          prefixIcon: Icons.lightbulb_outline_rounded,
        ),
        const SizedBox(height: AppSpace.s20),
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                key: const ValueKey('photo-studio-save-btn'),
                label: 'Salvar Foto e Descrição',
                icon: Icons.check_circle_rounded,
                onPressed: _saveWithAnnotations,
              ),
              const SizedBox(height: AppSpace.s8),
              AppButton(
                key: const ValueKey('photo-studio-skip-btn'),
                label: 'Pular descrição',
                variant: AppButtonVariant.tertiary,
                onPressed: _skipAnnotations,
              ),
            ],
          )
        else
          Row(
            children: [
              AppButton(
                key: const ValueKey('photo-studio-skip-btn'),
                label: 'Pular descrição',
                variant: AppButtonVariant.tertiary,
                expand: false,
                onPressed: _skipAnnotations,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: AppButton(
                  key: const ValueKey('photo-studio-save-btn'),
                  label: 'Salvar Foto e Descrição',
                  icon: Icons.check_circle_rounded,
                  onPressed: _saveWithAnnotations,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grade "+ Adicionar" com miniaturas interativas (toque na foto para editar sua descrição/sugestão).
class MediaPickerRow extends StatelessWidget {
  const MediaPickerRow({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.onEdit,
    this.max = 4,
  });

  final List<PickedImage> images;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index)? onEdit;
  final int max;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final tileHeight = context.layout.isLargeText ? 136.0 : 120.0;
    final tileWidth = context.layout.isLargeText ? 132.0 : 120.0;

    return SizedBox(
      height: tileHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (images.length < max)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s12),
              child: AppPressable(
                key: const ValueKey('media-picker-add-tile'),
                semanticLabel: 'Adicionar foto e nota',
                borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                onTap: onAdd,
                child: Container(
                  width: tileWidth,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: tk.accentInk, size: 24),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        'Adicionar',
                        textAlign: TextAlign.center,
                        style: AppType.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tk.text,
                        ),
                      ),
                      Text(
                        'Foto + nota',
                        textAlign: TextAlign.center,
                        style: AppType.caption.copyWith(color: tk.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (var i = 0; i < images.length; i++)
            Builder(
              builder: (context) {
                final item = images[i];
                final hasNote = item.hasContextAnnotation;
                final badgeText = item.combinedSummary.isNotEmpty
                    ? item.combinedSummary
                    : (item.focalPoint != null ? 'Ponto marcado' : 'Toque p/ descrever');
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s12),
                  child: SizedBox(
                    width: tileWidth,
                    height: tileHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AppPressable(
                            key: ValueKey('media-picker-thumb-$i'),
                            semanticLabel: 'Foto ${i + 1}: $badgeText',
                            borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                            onTap: onEdit != null ? () => onEdit!(i) : null,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                                border: Border.all(
                                  color: hasNote
                                      ? tk.accent.withValues(alpha: 0.75)
                                      : tk.border,
                                  width: hasNote ? 1.6 : 1.0,
                                ),
                                image: DecorationImage(
                                  image: MemoryImage(item.bytes),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s8,
                                    vertical: AppSpace.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppShellColors.brandBackdrop.withValues(alpha: 0.84),
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(AppGeometry.fieldRadius - 2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasNote
                                            ? Icons.check_circle_rounded
                                            : Icons.edit_note_rounded,
                                        size: 14,
                                        color: hasNote
                                            ? AppShellColors.benefitTrust
                                            : AppShellColors.onBrand,
                                      ),
                                      const SizedBox(width: AppSpace.s4),
                                      Expanded(
                                        child: Text(
                                          badgeText,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.fade,
                                          style: AppType.bodySm.copyWith(
                                            color: AppShellColors.onBrand,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: AppPressable(
                            key: ValueKey('media-picker-remove-$i'),
                            semanticLabel: 'Remover foto ${i + 1}',
                            excludeSemantics: true,
                            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                            onTap: () => onRemove(i),
                            child: SizedBox(
                              width: AppGeometry.minTarget,
                              height: AppGeometry.minTarget,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpace.s4),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppShellColors.brandBackdrop.withValues(alpha: 0.88),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppShellColors.onBrand,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

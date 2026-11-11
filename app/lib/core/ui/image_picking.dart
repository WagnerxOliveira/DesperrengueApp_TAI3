import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_service.dart';
import './app_tokens.dart';
import 'widgets.dart';

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
  src ??= await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Tirar foto'),
            subtitle: const Text('Fotografe o local e adicione uma breve explicação'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Escolher da galeria'),
            subtitle: const Text('Selecione uma imagem existente e descreva o ponto'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
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
      showSnack(
        context,
        'Não foi possível acessar a câmera/galeria. Verifique as permissões.',
        error: true,
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
  return showModalBottomSheet<PickedImage>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const ValueKey('photo-context-studio-sheet'),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: tk.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tk.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tk.clientSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      color: tk.clientAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Foto ${widget.photoIndex + 1} Confirmada • Detalhar Evidência',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Explique brevemente o que a foto mostra ou sugira o que deve ser feito.',
                          style: TextStyle(fontSize: 12, color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Preview interativo com toque para marcar o Pino Focal (x, y)
              LayoutBuilder(
                builder: (context, constraints) {
                  final previewW = constraints.maxWidth;
                  const previewH = 176.0;
                  return GestureDetector(
                    key: const ValueKey('photo-studio-preview'),
                    onTapDown: (details) {
                      final dx = (details.localPosition.dx / previewW).clamp(0.05, 0.95);
                      final dy = (details.localPosition.dy / previewH).clamp(0.08, 0.92);
                      setState(() => _focalPoint = Offset(dx, dy));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(widget.image.bytes, fit: BoxFit.cover),
                            Positioned(
                              left: 10,
                              top: 10,
                              right: 10,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.68),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.touch_app_rounded,
                                            size: 14,
                                            color: tk.clientAccent,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              _focalPoint == null
                                                  ? 'Toque no ponto da foto para destacar o defeito (opcional)'
                                                  : 'Ponto de atenção marcado na foto ✓',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_focalPoint != null) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => setState(() => _focalPoint = null),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: const Text(
                                          'Limpar pino',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
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
                                      color: tk.clientAccent.withValues(alpha: 0.28),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: tk.clientAccent,
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
              const SizedBox(height: 12),
              Text(
                'Sugestões rápidas (toque para preencher em 1 segundo):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tk.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                key: const ValueKey('photo-studio-quick-chips'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < presets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          key: ValueKey('photo-preset-chip-$i'),
                          avatar: Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: tk.clientAccent,
                          ),
                          label: Text(
                            presets[i].caption,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('photo-studio-caption-field'),
                controller: _captionCtrl,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'O que esta foto mostra? (Descrição breve)',
                  hintText: 'Ex.: Registro pingando atrás da pia / Disjuntor queimado',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('photo-studio-suggestion-field'),
                controller: _suggestionCtrl,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sugestão do que pode ser feito (Opcional)',
                  hintText: 'Ex.: Acho que precisa trocar a vedação ou substituir a peça',
                  prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('photo-studio-skip-btn'),
                    onPressed: _skipAnnotations,
                    child: const Text('Pular descrição'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('photo-studio-save-btn'),
                      onPressed: _saveWithAnnotations,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Salvar Foto e Descrição'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (images.length < max)
            GestureDetector(
              key: const ValueKey('media-picker-add-tile'),
              onTap: onAdd,
              child: Container(
                width: 104,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tk.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: tk.clientAccent),
                    const SizedBox(height: 4),
                    Text(
                      'Adicionar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tk.text,
                      ),
                    ),
                    Text(
                      'Foto + nota',
                      style: TextStyle(fontSize: 10.5, color: tk.textMuted),
                    ),
                  ],
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
                return Stack(
                  children: [
                    GestureDetector(
                      key: ValueKey('media-picker-thumb-$i'),
                      onTap: onEdit != null ? () => onEdit!(i) : null,
                      child: Container(
                        width: 112,
                        height: 108,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasNote
                                ? tk.clientAccent.withValues(alpha: 0.75)
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
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasNote
                                      ? Icons.check_circle_rounded
                                      : Icons.edit_note_rounded,
                                  size: 12,
                                  color: hasNote ? Colors.greenAccent : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    badgeText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 4,
                      child: GestureDetector(
                        key: ValueKey('media-picker-remove-$i'),
                        onTap: () => onRemove(i),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

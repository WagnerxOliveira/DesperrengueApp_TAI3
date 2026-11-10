import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/ui/category_brand_emblem.dart';

/// Pipeline Automatizado de Coleta Vetorial (Iconify REST API) e Compilação
/// do Catálogo dos 33 Logos Exclusivos de Categoria do Desperrengue.
///
/// Execução:
///   flutter test tool/fetch_category_vectors.dart
void main() {
  test('Busca os 33 vetores na API Iconify e compila a prancha oficial dos 33 Logos de Categoria', () async {
    final outDir = Directory('assets/category_logos');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final manifest = <Map<String, dynamic>>[];

    for (final spec in kCategoryBrandSpecs) {
      final slug = spec.index.toString().padLeft(2, '0');
      final parts = spec.primaryIconifyId.split(':');
      final prefix = parts.first;
      final iconName = parts.last;
      final url = Uri.parse('https://api.iconify.design/$prefix/$iconName.svg');

      String? fetchedSvg;
      try {
        final req = await client.getUrl(url);
        final res = await req.close();
        if (res.statusCode == 200) {
          fetchedSvg = await utf8.decoder.bind(res).join();
          File('${outDir.path}/cat_${slug}_$iconName.svg').writeAsStringSync(fetchedSvg);
        }
      } catch (_) {
        // Offline fallback seguro: preserva compilação determinística sem bloquear CI
      }

      manifest.add({
        'index': spec.index,
        'name': spec.name,
        'family': spec.family.id,
        'familyLabel': spec.family.label,
        'primaryColor': '#${spec.primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        'secondaryColor': '#${spec.secondaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        'primaryIconifyId': spec.primaryIconifyId,
        'badgeIconifyId': spec.badgeIconifyId,
        'iconifyEndpoint': url.toString(),
        'svgSynced': fetchedSvg != null && fetchedSvg.contains('<svg'),
      });
    }
    client.close();

    File('${outDir.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'version': '2.8.3',
        'totalCategories': kCategoryBrandSpecs.length,
        'architecture': '3-Layer Squircle Dark Glass Duotone + Corner Insignia',
        'categories': manifest,
      }),
    );

    // Renderiza a prancha de inspeção visual dos 33 emblemas em alta resolução (1080 x 1920)
    const width = 1080.0;
    const height = 2120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Fundo Dark do App (#0E1218)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF0E1218),
    );

    const cols = 3;
    const cellW = width / cols;
    const cellH = 180.0;
    const topOffset = 60.0;

    for (var i = 0; i < kCategoryBrandSpecs.length; i++) {
      final spec = kCategoryBrandSpecs[i];
      final col = i % cols;
      final row = i ~/ cols;
      final cx = col * cellW + cellW / 2;
      final cy = topOffset + row * cellH + 58;

      const logoSize = 96.0;
      canvas.save();
      canvas.translate(cx - logoSize / 2, cy - logoSize / 2);
      CategoryEmblemCustomPainter(spec: spec, showCornerBadge: true).paint(
        canvas,
        const Size(logoSize, logoSize),
      );
      canvas.restore();

      final tp = TextPainter(
        text: TextSpan(
          text: '${spec.index.toString().padLeft(2, '0')}. ${spec.name}',
          style: const TextStyle(
            color: Color(0xFFF1F5F9),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: cellW - 16);
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + logoSize / 2 + 10));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    File('${outDir.path}/category_logos_showcase.png').writeAsBytesSync(
      byteData!.buffer.asUint8List(),
    );

    expect(kCategoryBrandSpecs.length, 33);
  });
}

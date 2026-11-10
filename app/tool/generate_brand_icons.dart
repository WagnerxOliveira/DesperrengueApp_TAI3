import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desperrengue_app/core/ui/desperrengue_brand_logo.dart';

/// Renderizador Vetorial Headless (Skia/Impeller Canvas) do **Desperrengue**.
///
/// Executar via:
/// ```bash
/// flutter test tool/generate_brand_icons.dart
/// ```
///
/// Gera com super-amostragem vetorial em memória (`PictureRecorder -> toImage`):
/// 1. `assets/icons/desperrengue_logo.svg` (Vetor matemático SVG editável)
/// 2. `assets/icons/app_icon_foreground.png` (1024x1024 transparente, Sweet Spot 48% = 492x492 px)
/// 3. `assets/icons/app_icon_background.png` (1024x1024 Quiet Luxury Navy `#0F172A`)
/// 4. `assets/icons/app_icon_monochrome.png` (1024x1024 silhueta branca para Android 13-16 Themed Icons)
/// 5. `assets/icons/app_icon_padded.png` (1024x1024 composto para iOS, Web/PWA e Desktop)
/// 6. `assets/icons/app_icon_raw.png` (1024x1024 master)
/// 7. `assets/icons/play_store_512.png` (512x512 sRGB oficial Google Play Console)
/// 8. `assets/splash/logo.png` (1024x1024 símbolo da Splash nativa Android 12+)
/// 9. `android/app/src/main/res/drawable-*dpi/ic_launcher_monochrome.png` (108px a 432px)
Future<Uint8List> _renderVectorToPng({
  required int dimension,
  required CustomPainter painter,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, dimension.toDouble(), dimension.toDouble()),
  );
  painter.paint(canvas, Size(dimension.toDouble(), dimension.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(dimension, dimension);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

class _BackgroundOnlyPainter extends CustomPainter {
  const _BackgroundOnlyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.45, size.height * 0.38),
        size.width * 0.75,
        const [
          DesperrengueBrandLogoPainter.navyCenterGlow,
          DesperrengueBrandLogoPainter.navyDeep,
        ],
      );
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _buildOfficialBrandSvg() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <radialGradient id="navyBg" cx="45%" cy="38%" r="75%">
      <stop offset="0%" stop-color="#1A2E52"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </radialGradient>
    <linearGradient id="orangeAccent" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#FF6D00"/>
      <stop offset="100%" stop-color="#FF8524"/>
    </linearGradient>
  </defs>
  <!-- Background Quiet Luxury Fintech Navy -->
  <rect width="1024" height="1024" rx="224" fill="url(#navyBg)"/>
  <!-- Monograma Arquitetônico Casa-Escudo "D" (Sweet Spot 48% - Tangência G1 Exata) -->
  <g transform="translate(266, 266)">
    <path d="M 103.3 292.7 L 103.3 413.3 Q 103.3 447.7 137.8 447.7 L 241.1 447.7 A 172.2 172.2 0 0 0 362.9 153.8 L 273.1 64.0 Q 241.1 32.0 209.1 64.0 L 51.7 221.4"
          fill="none"
          stroke="#FFFFFF"
          stroke-width="64.0"
          stroke-linecap="round"
          stroke-linejoin="round"/>
    <!-- Check de Resolução em Espaço Negativo Central -->
    <path d="M 187.0 273.1 L 231.2 317.3 L 307.5 223.9"
          fill="none"
          stroke="url(#orangeAccent)"
          stroke-width="60.0"
          stroke-linecap="round"
          stroke-linejoin="round"/>
  </g>
</svg>
''';
}

void main() {
  test('Gera todos os ativos vetoriais e PNGs mestres do Desperrengue (1024px, 512px, Adaptive & Monochrome)', () async {
    final iconsDir = Directory('assets/icons');
    if (!iconsDir.existsSync()) {
      iconsDir.createSync(recursive: true);
    }
    final splashDir = Directory('assets/splash');
    if (!splashDir.existsSync()) {
      splashDir.createSync(recursive: true);
    }

    // 1. Salva o SVG vetorial puro oficial
    File('assets/icons/desperrengue_logo.svg')
        .writeAsStringSync(_buildOfficialBrandSvg());

    // 2. Foreground 1024x1024 (Fundo 100% transparente, Sweet Spot 48% = 492x492 px)
    final fgBytes = await _renderVectorToPng(
      dimension: 1024,
      painter: const DesperrengueBrandLogoPainter(
        variant: DesperrengueLogoVariant.quietLuxuryNavy,
        includeBackground: false,
        adaptiveSafeZoneScale: 0.48,
      ),
    );
    File('assets/icons/app_icon_foreground.png').writeAsBytesSync(fgBytes);
    File('assets/icons/icon_foreground.png').writeAsBytesSync(fgBytes);

    // 3. Background 1024x1024 (Quiet Luxury Navy #0F172A com iluminação radial sutil)
    final bgBytes = await _renderVectorToPng(
      dimension: 1024,
      painter: const _BackgroundOnlyPainter(),
    );
    File('assets/icons/app_icon_background.png').writeAsBytesSync(bgBytes);
    File('assets/icons/icon_background.png').writeAsBytesSync(bgBytes);

    // 4. Monochrome 1024x1024 (Silhueta branca pura + canal alfa para Android 13-16)
    final monoBytes = await _renderVectorToPng(
      dimension: 1024,
      painter: const DesperrengueBrandLogoPainter(
        variant: DesperrengueLogoVariant.monochrome,
        includeBackground: false,
        adaptiveSafeZoneScale: 0.48,
      ),
    );
    File('assets/icons/app_icon_monochrome.png').writeAsBytesSync(monoBytes);
    File('assets/icons/icon_monochrome.png').writeAsBytesSync(monoBytes);

    // 5. Composto Padded 1024x1024 (para iOS, Web/PWA, Windows, macOS)
    final paddedBytes = await _renderVectorToPng(
      dimension: 1024,
      painter: const DesperrengueBrandLogoPainter(
        variant: DesperrengueLogoVariant.quietLuxuryNavy,
        includeBackground: true,
        adaptiveSafeZoneScale: 0.58,
      ),
    );
    File('assets/icons/app_icon_padded.png').writeAsBytesSync(paddedBytes);
    File('assets/icons/app_icon_raw.png').writeAsBytesSync(paddedBytes);

    // 6. Play Store 512x512 sRGB quadrado cheio
    final playStoreBytes = await _renderVectorToPng(
      dimension: 512,
      painter: const DesperrengueBrandLogoPainter(
        variant: DesperrengueLogoVariant.quietLuxuryNavy,
        includeBackground: true,
        adaptiveSafeZoneScale: 0.60,
      ),
    );
    File('assets/icons/play_store_512.png').writeAsBytesSync(playStoreBytes);

    // 7. Splash Logo 1024x1024 (transparente para Android 12+ Splash Screen API)
    final splashBytes = await _renderVectorToPng(
      dimension: 1024,
      painter: const DesperrengueBrandLogoPainter(
        variant: DesperrengueLogoVariant.quietLuxuryNavy,
        includeBackground: false,
        adaptiveSafeZoneScale: 0.56,
      ),
    );
    File('assets/splash/logo.png').writeAsBytesSync(splashBytes);

    // 8. Densidades Android Monochrome (mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432)
    final monoDensities = <String, int>{
      'drawable-mdpi': 108,
      'drawable-hdpi': 162,
      'drawable-xhdpi': 216,
      'drawable-xxhdpi': 324,
      'drawable-xxxhdpi': 432,
    };
    for (final entry in monoDensities.entries) {
      final dir = Directory('android/app/src/main/res/${entry.key}');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final bytes = await _renderVectorToPng(
        dimension: entry.value,
        painter: const DesperrengueBrandLogoPainter(
          variant: DesperrengueLogoVariant.monochrome,
          includeBackground: false,
          adaptiveSafeZoneScale: 0.48,
        ),
      );
      File('${dir.path}/ic_launcher_monochrome.png').writeAsBytesSync(bytes);
    }

    // 9. Garante que mipmap-anydpi-v26/ic_launcher.xml use o Sweet Spot de 48%
    // sem duplo inset (evita encolhimento de 16% adicional) e registre o layer
    // <monochrome> para Android 13–16 Themed Icons:
    final adaptiveXmlFile = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    if (adaptiveXmlFile.parent.existsSync()) {
      adaptiveXmlFile.writeAsStringSync(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n',
      );
    }

    expect(fgBytes.length, greaterThan(1000));
    expect(paddedBytes.length, greaterThan(1000));
    expect(monoBytes.length, greaterThan(1000));
    expect(playStoreBytes.length, greaterThan(1000));
  });
}

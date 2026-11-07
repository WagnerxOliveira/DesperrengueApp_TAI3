import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  final rawFile = File('assets/icons/app_icon_raw.png');
  if (!rawFile.existsSync()) {
    stderr.writeln('ERRO: assets/icons/app_icon_raw.png nao encontrado.');
    exit(1);
  }

  final rawImage = img.decodeImage(rawFile.readAsBytesSync());
  if (rawImage == null) {
    stderr.writeln('ERRO: Falha ao decodificar app_icon_raw.png.');
    exit(1);
  }

  const int canvasSize = 1024;
  const int contentSize = 580; // 56.6% Safe-Zone para nunca cortar no One UI / Android / iOS
  final int offset = (canvasSize - contentSize) ~/ 2;

  // Cor de fundo oficial (#0C1424)
  const int bgR = 12;
  const int bgG = 20;
  const int bgB = 36;
  final bgColor = img.ColorRgba8(bgR, bgG, bgB, 255);

  // Redimensiona a imagem original com interpolacao cubica de alta qualidade
  final resized = img.copyResize(
    rawImage,
    width: contentSize,
    height: contentSize,
    interpolation: img.Interpolation.cubic,
  );

  // Suavizacao radial + normalizacao do tom de fundo nas extremidades do 580x580
  // para eliminar 100% qualquer costura quadrada ou halo circular contra #0C1424
  // preservando 100% da nitidez e brilho do emblema (D + chave + telhado + check cobre).
  final double center = contentSize / 2.0;
  final double maxRadius = center;
  final double fadeStart = maxRadius * 0.72;

  final featheredForeground = img.Image(
    width: contentSize,
    height: contentSize,
    numChannels: 4,
  );

  for (int y = 0; y < contentSize; y++) {
    for (int x = 0; x < contentSize; x++) {
      final pixel = resized.getPixel(x, y);
      final int r = pixel.r.toInt();
      final int g = pixel.g.toInt();
      final int b = pixel.b.toInt();

      final double dx = (x - center).abs();
      final double dy = (y - center).abs();
      // Distancia supereliptica (squircle) + radial para acompanhar a geometria do icone
      final double radialDist = math.sqrt(dx * dx + dy * dy);
      final double boxDist = math.max(dx, dy);
      final double dist = 0.55 * radialDist + 0.45 * boxDist;

      // Detecta o quanto o pixel pertence ao emblema vs ao fundo azul-marinho
      final int luma = ((r * 299 + g * 587 + b * 114) ~/ 1000);
      final double emblemStrength = ((luma - 38) / 36.0).clamp(0.0, 1.0);

      double edgeFade = 1.0;
      if (dist > fadeStart) {
        final double t = ((dist - fadeStart) / (maxRadius - fadeStart)).clamp(0.0, 1.0);
        // Curva hermite suave (smoothstep)
        final double smooth = t * t * (3.0 - 2.0 * t);
        edgeFade = (1.0 - smooth).clamp(0.0, 1.0);
      }

      // Nos pixels de fundo, mescla suavemente para #0C1424 e reduz alpha nas bordas;
      // nos pixels do emblema, preserva 100% da cor e nitidez dentro da Safe-Zone.
      final double effectiveAlphaFactor =
          (edgeFade * (1.0 - emblemStrength) + emblemStrength * (boxDist > maxRadius * 0.96 ? 0.0 : 1.0))
              .clamp(0.0, 1.0);

      final double bgBlend = (1.0 - emblemStrength) * (1.0 - edgeFade * 0.65);
      final int outR = (r * (1.0 - bgBlend) + bgR * bgBlend).round().clamp(0, 255);
      final int outG = (g * (1.0 - bgBlend) + bgG * bgBlend).round().clamp(0, 255);
      final int outB = (b * (1.0 - bgBlend) + bgB * bgBlend).round().clamp(0, 255);
      final int newAlpha = (pixel.a * effectiveAlphaFactor).round().clamp(0, 255);

      featheredForeground.setPixelRgba(x, y, outR, outG, outB, newAlpha);
    }
  }

  // 1. Gera app_icon_foreground.png (Transparente com Safe-Zone para Android Adaptive)
  final foregroundCanvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(foregroundCanvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    foregroundCanvas,
    featheredForeground,
    dstX: offset,
    dstY: offset,
  );
  File('assets/icons/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foregroundCanvas));

  // 2. Gera app_icon_padded.png (Fundo solido #0C1424 + Safe-Zone para iOS, Web e Legacy)
  final paddedCanvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(paddedCanvas, color: bgColor);
  img.compositeImage(
    paddedCanvas,
    featheredForeground,
    dstX: offset,
    dstY: offset,
  );
  File('assets/icons/app_icon_padded.png')
      .writeAsBytesSync(img.encodePng(paddedCanvas));

  stdout.writeln('SUCESSO: app_icon_foreground.png e app_icon_padded.png gerados com Safe-Zone!');
}

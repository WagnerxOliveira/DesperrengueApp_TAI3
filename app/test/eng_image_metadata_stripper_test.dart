import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/services/media_service.dart';
import 'package:desperrengue_app/core/utils/image_metadata_stripper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Segmento APP1 EXIF com GPS "falso" + orientaÃ§Ã£o (big-endian), como uma
/// cÃ¢mera real gravaria.
Uint8List _exifSegment({required int orientation, required String gpsMarker}) {
  final gps = utf8.encode(gpsMarker);
  final tiff = BytesBuilder()
    ..add([0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08])
    ..add([0x00, 0x01])
    ..add([0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, orientation, 0x00, 0x00])
    ..add([0x00, 0x00, 0x00, 0x00])
    ..add(gps);
  final payload = BytesBuilder()
    ..add(utf8.encode('Exif'))
    ..add([0x00, 0x00])
    ..add(tiff.toBytes());
  final data = payload.toBytes();
  final len = data.length + 2;
  return Uint8List.fromList([0xFF, 0xE1, (len >> 8) & 0xFF, len & 0xFF, ...data]);
}

Uint8List _xmpSegment(String text) {
  final data = [...utf8.encode('http://ns.adobe.com/xap/1.0/'), 0x00, ...utf8.encode(text)];
  final len = data.length + 2;
  return Uint8List.fromList([0xFF, 0xE1, (len >> 8) & 0xFF, len & 0xFF, ...data]);
}

Uint8List _comSegment(String text) {
  final data = utf8.encode(text);
  final len = data.length + 2;
  return Uint8List.fromList([0xFF, 0xFE, (len >> 8) & 0xFF, len & 0xFF, ...data]);
}

/// Insere [segments] logo apÃ³s o SOI (e apÃ³s o JFIF, se existir).
Uint8List _injectJpeg(Uint8List jpeg, List<Uint8List> segments) {
  final b = BytesBuilder()..add(jpeg.sublist(0, 2));
  for (final s in segments) {
    b.add(s);
  }
  b.add(jpeg.sublist(2));
  return b.toBytes();
}

Uint8List _baseJpeg() {
  final image = img.Image(width: 16, height: 12);
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

bool _contains(Uint8List hay, String needle) =>
    latin1.decode(hay, allowInvalid: true).contains(needle);

void main() {
  const gps = 'GPS-LAT-21.7854-LNG-46.5617';

  group('JPEG', () {
    test('remove EXIF/GPS, XMP e comentÃ¡rio; imagem continua decodificÃ¡vel', () {
      final tainted = _injectJpeg(_baseJpeg(), [
        _exifSegment(orientation: 1, gpsMarker: gps),
        _xmpSegment('<x:xmpmeta>-21.7854,-46.5617</x:xmpmeta>'),
        _comSegment('Rua das Flores 123'),
      ]);
      expect(_contains(tainted, gps), isTrue, reason: 'prÃ©-condiÃ§Ã£o');
      expect(ImageMetadataStripper.hasSensitiveMetadata(tainted), isTrue);

      final clean = ImageMetadataStripper.strip(tainted);

      expect(_contains(clean, gps), isFalse);
      expect(_contains(clean, 'Exif'), isFalse);
      expect(_contains(clean, 'xmpmeta'), isFalse);
      expect(_contains(clean, 'Rua das Flores'), isFalse);
      expect(ImageMetadataStripper.hasSensitiveMetadata(clean), isFalse);
      final decoded = img.decodeJpg(clean);
      expect(decoded, isNotNull);
      expect(decoded!.width, 16);
      expect(decoded.height, 12);
    });

    test('preserva a orientaÃ§Ã£o EXIF (sÃ³ a tag Orientation sobrevive)', () {
      final tainted = _injectJpeg(_baseJpeg(), [
        _exifSegment(orientation: 6, gpsMarker: gps),
      ]);
      final clean = ImageMetadataStripper.strip(tainted);

      expect(_contains(clean, gps), isFalse);
      expect(ImageMetadataStripper.jpegOrientation(tainted), 6, reason: 'pré-condição');
      expect(ImageMetadataStripper.jpegOrientation(clean), 6);
      final decoded = img.decodeJpg(clean)!;
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
    });

    test('sem recompressÃ£o: os bytes de entropia sÃ£o idÃªnticos', () {
      final base = _baseJpeg();
      final clean = ImageMetadataStripper.strip(
        _injectJpeg(base, [_exifSegment(orientation: 1, gpsMarker: gps)]),
      );
      // A imagem original (sem EXIF) tem exatamente o mesmo scan.
      final sosOriginal = _indexOfSos(base);
      final sosClean = _indexOfSos(clean);
      expect(clean.sublist(sosClean), base.sublist(sosOriginal));
    });

    test('zera miniatura embutida no JFIF', () {
      final base = _baseJpeg();
      // JFIF com miniatura 2x1 (6 bytes de RGB).
      const thumbBytes = [255, 0, 0, 0, 255, 0];
      final jfif = <int>[
        0xFF, 0xE0, 0x00, 0x16, // len = 22
        0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
        0x00, 0x48, 0x00, 0x48, 0x02, 0x01, ...thumbBytes,
      ];
      final withThumb = BytesBuilder()
        ..add([0xFF, 0xD8])
        ..add(jfif)
        ..add(base.sublist(2));
      final clean = ImageMetadataStripper.strip(withThumb.toBytes());
      expect(clean[2], 0xFF);
      expect(clean[3], 0xE0);
      expect(clean[18], 0); // xthumb
      expect(clean[19], 0); // ythumb
      expect(img.decodeJpg(clean), isNotNull);
    });

    test('JPEG truncado/corrompido falha fechado', () {
      final tainted = _injectJpeg(_baseJpeg(), [_exifSegment(orientation: 1, gpsMarker: gps)]);
      expect(
        () => ImageMetadataStripper.strip(Uint8List.sublistView(tainted, 0, 20)),
        throwsA(isA<ImageMetadataException>()),
      );
    });
  });

  group('PNG', () {
    test('remove eXIf/tEXt/tIME e mantÃ©m pixels', () {
      final image = img.Image(width: 5, height: 5);
      img.fill(image, color: img.ColorRgb8(10, 200, 10));
      final png = Uint8List.fromList(img.encodePng(image));
      // injeta tEXt e eXIf antes de IEND
      final iend = png.length - 12;
      Uint8List chunk(String type, List<int> data) {
        final b = BytesBuilder()
          ..add([0, 0, (data.length >> 8) & 0xFF, data.length & 0xFF])
          ..add(ascii.encode(type))
          ..add(data)
          ..add([0, 0, 0, 0]); // CRC dummy (nÃ£o validamos)
        return b.toBytes();
      }

      final tainted = BytesBuilder()
        ..add(png.sublist(0, iend))
        ..add(chunk('tEXt', utf8.encode('Comment\u0000$gps')))
        ..add(chunk('eXIf', utf8.encode(gps)))
        ..add(chunk('tIME', [7, 0xE9, 1, 1, 0, 0, 0]))
        ..add(png.sublist(iend));
      final t = tainted.toBytes();
      expect(_contains(t, gps), isTrue);
      expect(ImageMetadataStripper.hasSensitiveMetadata(t), isTrue);

      final clean = ImageMetadataStripper.strip(t);
      expect(_contains(clean, gps), isFalse);
      expect(_contains(clean, 'tIME'), isFalse);
      final decoded = img.decodePng(clean);
      expect(decoded, isNotNull);
      expect(decoded!.getPixel(2, 2).g, 200);
    });
  });

  group('WebP', () {
    test('remove EXIF/XMP, ajusta RIFF size e flags VP8X', () {
      // Container mÃ­nimo: VP8X + VP8L(falso) + EXIF + XMP.
      Uint8List chunk(String t, List<int> d) {
        final pad = d.length.isOdd ? [0] : <int>[];
        return Uint8List.fromList([
          ...ascii.encode(t),
          d.length & 0xFF, (d.length >> 8) & 0xFF, 0, 0,
          ...d,
          ...pad,
        ]);
      }

      final vp8x = chunk('VP8X', [0x0C, 0, 0, 0, 3, 0, 0, 3, 0, 0]);
      final body = BytesBuilder()
        ..add(ascii.encode('WEBP'))
        ..add(vp8x)
        ..add(chunk('VP8L', [0x2F, 1, 2, 3, 4, 5, 6]))
        ..add(chunk('EXIF', utf8.encode(gps)))
        ..add(chunk('XMP ', utf8.encode('<x>$gps</x>')));
      final bodyBytes = body.toBytes();
      final riff = BytesBuilder()
        ..add(ascii.encode('RIFF'))
        ..add([bodyBytes.length & 0xFF, (bodyBytes.length >> 8) & 0xFF, 0, 0])
        ..add(bodyBytes);
      final tainted = riff.toBytes();
      expect(ImageMetadataStripper.hasSensitiveMetadata(tainted), isTrue);

      final clean = ImageMetadataStripper.strip(tainted);
      expect(_contains(clean, gps), isFalse);
      expect(_contains(clean, 'EXIF'), isFalse);
      expect(_contains(clean, 'XMP '), isFalse);
      expect(ImageMetadataStripper.hasSensitiveMetadata(clean), isFalse);
      final size = clean[4] | (clean[5] << 8) | (clean[6] << 16) | (clean[7] << 24);
      expect(size, clean.length - 8);
      // VP8X comeÃ§a em 12; flags no byte 20.
      expect(clean[20] & 0x0C, 0);
    });
  });

  group('desconhecido', () {
    test('bytes aleatÃ³rios/HEIC lanÃ§am ImageMetadataException', () {
      expect(
        () => ImageMetadataStripper.strip(Uint8List.fromList(List<int>.generate(64, (i) => i))),
        throwsA(isA<ImageMetadataException>()),
      );
      expect(ImageMetadataStripper.sniff(Uint8List(0)), ImageContainer.unknown);
    });
  });

  group('MediaService.sanitizeForUpload', () {
    test('devolve ext/mime reais e bytes sem GPS (nome diz .png, conteÃºdo Ã© JPEG)', () async {
      final tainted = _injectJpeg(_baseJpeg(), [_exifSegment(orientation: 1, gpsMarker: gps)]);
      final r = await MediaService.sanitizeForUpload(tainted, 'png');
      expect(r.ext, 'jpg');
      expect(r.mime, 'image/jpeg');
      expect(_contains(r.bytes, gps), isFalse);
    });

    test('imagem grande usa o caminho de isolate e continua sem GPS', () async {
      // Enche o JPEG com um COM gigante (descartado) para passar do limiar.
      final big = _injectJpeg(_baseJpeg(), [
        _exifSegment(orientation: 1, gpsMarker: gps),
        for (var i = 0; i < 30; i++) _comSegment('x' * 60000),
      ]);
      expect(big.lengthInBytes, greaterThan(MediaService.isolateThresholdBytes));
      final r = await MediaService.sanitizeForUpload(big, 'jpg');
      expect(r.bytes.lengthInBytes, lessThan(big.lengthInBytes ~/ 10));
      expect(_contains(r.bytes, gps), isFalse);
    });

    test('formato nÃ£o suportado falha fechado (nunca envia sem higienizar)', () async {
      await expectLater(
        MediaService.sanitizeForUpload(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), 'jpg'),
        throwsA(isA<ImageMetadataException>()),
      );
    });

    test('vÃ­deo passa direto', () async {
      final v = Uint8List.fromList([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70]);
      final r = await MediaService.sanitizeForUpload(v, 'mp4');
      expect(r.mime, 'video/mp4');
      expect(r.bytes, v);
    });

    test('extensÃ£o maliciosa Ã© saneada', () async {
      final r = await MediaService.sanitizeForUpload(_baseJpeg(), '../../x');
      expect(r.ext, 'jpg');
    });
  });
}

int _indexOfSos(Uint8List b) {
  var i = 2;
  while (i + 4 <= b.length) {
    final m = b[i + 1];
    if (m == 0xDA) return i;
    final len = (b[i + 2] << 8) | b[i + 3];
    i += 2 + len;
  }
  fail('SOS nÃ£o encontrado');
}

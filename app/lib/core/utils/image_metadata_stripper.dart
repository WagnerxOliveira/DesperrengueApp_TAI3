/// Remoção de metadados (EXIF/GPS/XMP/IPTC/comentários) de imagens, em Dart
/// puro (sem `dart:io`, sem Flutter): roda em Android, iOS, Web, testes e
/// isolates.
///
/// LGPD / contrato B.3: fotos do pedido podem trazer a coordenada GPS exata da
/// casa do cliente no EXIF. Antes de qualquer upload, os bytes passam por
/// [ImageMetadataStripper.strip], que:
///
///  * JPEG: remove APP1 (EXIF/XMP), APP2 não-ICC (FlashPix/MPF), APP3–APP15
///    (exceto Adobe APP14 e ICC), COM e a miniatura embutida do JFIF. Se o
///    original tinha orientação EXIF ≠ 1, grava um EXIF mínimo contendo
///    SOMENTE a tag Orientation (a foto continua em pé). Sem recompressão =
///    zero perda de qualidade e custo O(n) de cópia.
///  * PNG: mantém apenas chunks necessários à renderização (IHDR, PLTE, IDAT,
///    IEND, tRNS, gAMA, cHRM, sRGB, iCCP, sBIT, pHYs, bKGD, APNG).
///    Remove eXIf, tEXt, zTXt, iTXt, tIME e privados.
///  * WebP: remove chunks EXIF e XMP e limpa as flags no VP8X.
///
/// Formato desconhecido/corrompido → [ImageMetadataException] (falha
/// fechada: nunca enviar bytes que não conseguimos higienizar).
library;

import 'dart:typed_data';

class ImageMetadataException implements Exception {
  const ImageMetadataException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ImageContainer { jpeg, png, webp, unknown }

class ImageMetadataStripper {
  const ImageMetadataStripper._();

  /// Detecta o container pelos magic bytes (ignora a extensão do arquivo).
  static ImageContainer sniff(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return ImageContainer.jpeg;
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return ImageContainer.png;
    }
    if (b.length >= 12 &&
        _fourcc(b, 0) == 'RIFF' &&
        _fourcc(b, 8) == 'WEBP') {
      return ImageContainer.webp;
    }
    return ImageContainer.unknown;
  }

  /// Devolve uma cópia de [input] sem metadados de privacidade.
  static Uint8List strip(Uint8List input) {
    switch (sniff(input)) {
      case ImageContainer.jpeg:
        return _stripJpeg(input);
      case ImageContainer.png:
        return _stripPng(input);
      case ImageContainer.webp:
        return _stripWebp(input);
      case ImageContainer.unknown:
        throw const ImageMetadataException(
          'Formato de imagem não suportado. Use JPG, PNG ou WebP.',
        );
    }
  }

  /// `true` se [input] ainda carrega GPS/EXIF/XMP detectável (usado em testes
  /// e como verificação defensiva pós-strip).
  static bool hasSensitiveMetadata(Uint8List input) {
    try {
      switch (sniff(input)) {
        case ImageContainer.jpeg:
          var i = 2;
          while (i + 4 <= input.length) {
            if (input[i] != 0xFF) return false;
            final m = input[i + 1];
            if (m == 0xFF) {
              i++;
              continue;
            }
            if (m == 0xDA || m == 0xD9) return false;
            if (m == 0x01 || (m >= 0xD0 && m <= 0xD8)) {
              i += 2;
              continue;
            }
            final len = (input[i + 2] << 8) | input[i + 3];
            if (m == 0xE1 && _isGpsOrXmp(input, i + 4, len - 2)) return true;
            if (m == 0xED || m == 0xFE) return true;
            i += 2 + len;
          }
          return false;
        case ImageContainer.png:
          var i = 8;
          while (i + 8 <= input.length) {
            final len = _be32(input, i);
            final t = _fourcc(input, i + 4);
            if (t == 'eXIf' || t == 'tEXt' || t == 'zTXt' || t == 'iTXt') return true;
            i += 12 + len;
          }
          return false;
        case ImageContainer.webp:
          var i = 12;
          while (i + 8 <= input.length) {
            final t = _fourcc(input, i);
            if (t == 'EXIF' || t == 'XMP ') return true;
            final len = _le32(input, i + 4);
            i += 8 + len + (len & 1);
          }
          return false;
        case ImageContainer.unknown:
          return true;
      }
    } catch (_) {
      return true;
    }
  }

  /// Orientação EXIF (1–8) de um JPEG; 1 se ausente. Útil para testes e para
  /// quem precisa decidir rotação sem decodificar a imagem.
  static int jpegOrientation(Uint8List b) {
    if (sniff(b) != ImageContainer.jpeg) return 1;
    var i = 2;
    while (i + 4 <= b.length) {
      if (b[i] != 0xFF) return 1;
      final m = b[i + 1];
      if (m == 0xFF) {
        i++;
        continue;
      }
      if (m == 0xDA || m == 0xD9) return 1;
      if (m == 0x01 || (m >= 0xD0 && m <= 0xD8)) {
        i += 2;
        continue;
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      if (len < 2 || i + 2 + len > b.length) return 1;
      if (m == 0xE1 && len >= 10 && _fourcc(b, i + 4) == 'Exif') {
        return _readExifOrientation(b, i + 10, len - 8);
      }
      i += 2 + len;
    }
    return 1;
  }

  static bool _isGpsOrXmp(Uint8List b, int start, int len) {
    if (len <= 0 || start + len > b.length) return false;
    // "Exif\0\0" ou "http://ns.adobe.com/xap/1.0/"
    return (len >= 6 && _fourcc(b, start) == 'Exif') ||
        (len >= 28 && _fourcc(b, start) == 'http');
  }

  // ---------------------------------------------------------------- JPEG --

  static Uint8List _stripJpeg(Uint8List b) {
    final out = BytesBuilder(copy: false);
    out.add(const [0xFF, 0xD8]);
    var orientation = 1;
    final kept = BytesBuilder(copy: false);
    final jfif = BytesBuilder(copy: false);

    var i = 2;
    var sawSos = false;
    while (i < b.length) {
      if (b[i] != 0xFF) {
        throw const ImageMetadataException('Imagem JPEG inválida.');
      }
      // Preenchimento 0xFF repetido.
      while (i < b.length && b[i] == 0xFF) {
        i++;
      }
      if (i >= b.length) {
        throw const ImageMetadataException('Imagem JPEG inválida.');
      }
      final marker = b[i];
      i++;

      if (marker == 0xD9) {
        // EOI antes de SOS: JPEG sem imagem.
        throw const ImageMetadataException('Imagem JPEG inválida.');
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
        kept.add([0xFF, marker]);
        continue;
      }
      if (i + 2 > b.length) {
        throw const ImageMetadataException('Imagem JPEG inválida.');
      }
      final len = (b[i] << 8) | b[i + 1];
      if (len < 2 || i + len > b.length) {
        throw const ImageMetadataException('Imagem JPEG inválida.');
      }
      final dataStart = i + 2;
      final dataLen = len - 2;

      if (marker == 0xDA) {
        // Start Of Scan: tudo a partir daqui é entropia + EOI, copiado como está.
        kept.add([0xFF, marker]);
        kept.add(Uint8List.sublistView(b, i));
        sawSos = true;
        break;
      }

      if (marker == 0xE1 && dataLen >= 8 && _fourcc(b, dataStart) == 'Exif') {
        final o = _readExifOrientation(b, dataStart + 6, dataLen - 6);
        if (o >= 1 && o <= 8) orientation = o;
        // descarta o segmento
      } else if (marker == 0xE0) {
        // JFIF: mantém cabeçalho padrão e zera a miniatura embutida.
        if (dataLen >= 14 && _fourcc(b, dataStart) == 'JFIF') {
          final seg = Uint8List.fromList(b.sublist(i - 2, i + 16));
          seg[0] = 0xFF;
          seg[1] = 0xE0;
          // len = 16
          seg[2] = 0x00;
          seg[3] = 0x10;
          seg[16] = 0; // xthumbnail
          seg[17] = 0; // ythumbnail
          jfif.add(seg);
        }
      } else if (marker == 0xE2) {
        // ICC é necessário para cor correta; o resto (FlashPix/MPF) sai.
        if (dataLen >= 12 && _startsWithAscii(b, dataStart, 'ICC_PROFILE')) {
          kept.add(Uint8List.sublistView(b, i - 2, i + len));
        }
      } else if (marker == 0xEE) {
        // Adobe APP14 (transformada de cor): mantém.
        if (dataLen >= 5 && _startsWithAscii(b, dataStart, 'Adobe')) {
          kept.add(Uint8List.sublistView(b, i - 2, i + len));
        }
      } else if ((marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE) {
        // APP1 não-EXIF (XMP), APP3–15 (IPTC/Photoshop/Ducky...), COM → removidos.
      } else {
        // DQT/SOF/DHT/DRI etc.: essenciais.
        kept.add(Uint8List.sublistView(b, i - 2, i + len));
      }
      i += len;
    }

    if (!sawSos) {
      throw const ImageMetadataException('Imagem JPEG inválida.');
    }
    out.add(jfif.takeBytes());
    if (orientation != 1) {
      out.add(_minimalOrientationExif(orientation));
    }
    out.add(kept.takeBytes());
    return out.takeBytes();
  }

  /// Lê só a tag Orientation (0x0112) do IFD0. 1 se ausente/ilegível.
  static int _readExifOrientation(Uint8List b, int tiff, int len) {
    try {
      if (len < 12 || tiff + len > b.length) return 1;
      final bigEndian = b[tiff] == 0x4D && b[tiff + 1] == 0x4D;
      final littleEndian = b[tiff] == 0x49 && b[tiff + 1] == 0x49;
      if (!bigEndian && !littleEndian) return 1;
      int u16(int o) => bigEndian
          ? (b[tiff + o] << 8) | b[tiff + o + 1]
          : (b[tiff + o + 1] << 8) | b[tiff + o];
      int u32(int o) => bigEndian
          ? b[tiff + o] * 16777216 + b[tiff + o + 1] * 65536 + b[tiff + o + 2] * 256 + b[tiff + o + 3]
          : b[tiff + o + 3] * 16777216 + b[tiff + o + 2] * 65536 + b[tiff + o + 1] * 256 + b[tiff + o];
      if (u16(2) != 42) return 1;
      final ifd = u32(4);
      if (ifd < 8 || ifd + 2 > len) return 1;
      final n = u16(ifd);
      for (var k = 0; k < n; k++) {
        final e = ifd + 2 + k * 12;
        if (e + 12 > len) return 1;
        if (u16(e) == 0x0112) {
          final v = u16(e + 8);
          return (v >= 1 && v <= 8) ? v : 1;
        }
      }
    } catch (_) {
      // ilegível → sem rotação
    }
    return 1;
  }

  /// APP1 com um único IFD e uma única tag (Orientation).
  static Uint8List _minimalOrientationExif(int orientation) {
    return Uint8List.fromList([
      0xFF, 0xE1, 0x00, 0x22, // marker + length (34)
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // TIFF header (big-endian)
      0x00, 0x01, // 1 entrada
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // tag, SHORT, count 1
      0x00, orientation, 0x00, 0x00, // valor
      0x00, 0x00, 0x00, 0x00, // sem próximo IFD
    ]);
  }

  // ----------------------------------------------------------------- PNG --

  static const Set<String> _pngKeep = {
    'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'gAMA', 'cHRM', 'sRGB', 'iCCP',
    'sBIT', 'pHYs', 'bKGD', 'hIST', 'sPLT', 'acTL', 'fcTL', 'fdAT',
  };

  static Uint8List _stripPng(Uint8List b) {
    final out = BytesBuilder(copy: false);
    out.add(Uint8List.sublistView(b, 0, 8));
    var i = 8;
    var sawIend = false;
    var sawIdat = false;
    while (i + 12 <= b.length) {
      final len = _be32(b, i);
      final type = _fourcc(b, i + 4);
      final end = i + 12 + len;
      if (len < 0 || end > b.length) {
        throw const ImageMetadataException('Imagem PNG inválida.');
      }
      if (_pngKeep.contains(type)) {
        out.add(Uint8List.sublistView(b, i, end));
        if (type == 'IDAT') sawIdat = true;
      }
      i = end;
      if (type == 'IEND') {
        sawIend = true;
        break;
      }
    }
    if (!sawIend || !sawIdat) {
      throw const ImageMetadataException('Imagem PNG inválida.');
    }
    return out.takeBytes();
  }

  // ---------------------------------------------------------------- WebP --

  static Uint8List _stripWebp(Uint8List b) {
    final out = BytesBuilder(copy: false);
    out.add(Uint8List.sublistView(b, 0, 12)); // RIFF + size + WEBP (size ajustado depois)
    var i = 12;
    var kept = 0;
    while (i + 8 <= b.length) {
      final type = _fourcc(b, i);
      final len = _le32(b, i + 4);
      final padded = len + (len & 1);
      final end = i + 8 + padded;
      if (len < 0 || i + 8 + len > b.length) {
        throw const ImageMetadataException('Imagem WebP inválida.');
      }
      final chunkEnd = end > b.length ? b.length : end;
      if (type == 'EXIF' || type == 'XMP ') {
        // descarta
      } else if (type == 'VP8X' && len >= 10) {
        final chunk = Uint8List.fromList(b.sublist(i, chunkEnd));
        chunk[8] = chunk[8] & ~0x0C; // limpa flags EXIF (0x08) e XMP (0x04)
        out.add(chunk);
        kept++;
      } else {
        out.add(Uint8List.sublistView(b, i, chunkEnd));
        kept++;
      }
      i = end;
    }
    if (kept == 0) {
      throw const ImageMetadataException('Imagem WebP inválida.');
    }
    final bytes = out.takeBytes();
    final riffSize = bytes.length - 8;
    bytes[4] = riffSize & 0xFF;
    bytes[5] = (riffSize >> 8) & 0xFF;
    bytes[6] = (riffSize >> 16) & 0xFF;
    bytes[7] = (riffSize >> 24) & 0xFF;
    return bytes;
  }

  // ------------------------------------------------------------- helpers --

  static String _fourcc(Uint8List b, int o) =>
      String.fromCharCodes(b.sublist(o, o + 4));

  static bool _startsWithAscii(Uint8List b, int o, String s) {
    if (o + s.length > b.length) return false;
    for (var k = 0; k < s.length; k++) {
      if (b[o + k] != s.codeUnitAt(k)) return false;
    }
    return true;
  }

  static int _be32(Uint8List b, int o) =>
      b[o] * 16777216 + b[o + 1] * 65536 + b[o + 2] * 256 + b[o + 3];

  static int _le32(Uint8List b, int o) =>
      b[o + 3] * 16777216 + b[o + 2] * 65536 + b[o + 1] * 256 + b[o];
}

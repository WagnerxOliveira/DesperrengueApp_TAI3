import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import 'document_ocr_and_liveness_service.dart';

/// Resultado auditado da Certidão de Antecedentes Criminais da Polícia Federal
/// (`ePol` / `SINIC` — Ministério da Justiça e Segurança Pública).
class AuditedCriminalRecordResult {
  const AuditedCriminalRecordResult({
    required this.passed,
    required this.protocolNumber,
    required this.protocolMasked,
    required this.issuedDate,
    required this.validationCode,
    required this.fileSha256Hex,
    required this.holderNameMatched,
    required this.cpfMatched,
    required this.humanFeedbackMessage,
    required this.fileBytes,
    required this.fileExtension,
    String? outcome,
    this.issuingOrgan = 'POLICIA_FEDERAL_SINIC',
  }) : outcome = outcome ?? (passed ? 'NOTHING_ON_RECORD' : 'REJECTED');

  final bool passed;
  final String protocolNumber;
  final String protocolMasked;
  final DateTime issuedDate;
  final String validationCode;
  final String fileSha256Hex;
  final bool holderNameMatched;
  final bool cpfMatched;
  final String humanFeedbackMessage;
  final Uint8List fileBytes;
  final String fileExtension;
  final String outcome;
  final String issuingOrgan;

  bool get isNothingOnRecord => outcome == 'NOTHING_ON_RECORD';

  /// Data exata de expiração oficial (90 dias corridos a partir da emissão da PF).
  DateTime get expiresAt =>
      issuedDate.add(const Duration(days: CriminalBackgroundService.validityCycleDays));

  String get issuedDateFormatted {
    final d = issuedDate.day.toString().padLeft(2, '0');
    final m = issuedDate.month.toString().padLeft(2, '0');
    final y = issuedDate.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  String get expiresAtFormatted {
    final exp = expiresAt;
    final d = exp.day.toString().padLeft(2, '0');
    final m = exp.month.toString().padLeft(2, '0');
    final y = exp.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  int daysSinceIssue([DateTime? referenceNow]) {
    final now = (referenceNow ?? DateTime.now()).toUtc();
    final refDay = DateTime.utc(now.year, now.month, now.day);
    final issDay = DateTime.utc(issuedDate.year, issuedDate.month, issuedDate.day);
    return refDay.difference(issDay).inDays;
  }

  int daysUntilExpiration([DateTime? referenceNow]) {
    final now = (referenceNow ?? DateTime.now()).toUtc();
    final refDay = DateTime.utc(now.year, now.month, now.day);
    final expDay = DateTime.utc(expiresAt.year, expiresAt.month, expiresAt.day);
    final diff = expDay.difference(refDay).inDays;
    return diff < 0 ? 0 : diff;
  }
}

/// Campos estruturados extraídos automaticamente de uma Certidão de Antecedentes
/// Criminais da Polícia Federal (PDF textual, OCR de imagem ou QR Code oficial).
class ExtractedCriminalCertificateFields {
  const ExtractedCriminalCertificateFields({
    this.protocolNumber,
    this.issuedDate,
    this.validationCode,
    this.holderName,
    this.holderCpfDigits,
    this.qrUrl,
  });

  final String? protocolNumber;
  final DateTime? issuedDate;
  final String? validationCode;
  final String? holderName;
  final String? holderCpfDigits;
  final String? qrUrl;

  bool get hasAnyField =>
      (protocolNumber != null && protocolNumber!.isNotEmpty) ||
      issuedDate != null ||
      (validationCode != null && validationCode!.isNotEmpty);

  ExtractedCriminalCertificateFields mergeWith(
    ExtractedCriminalCertificateFields fallback,
  ) {
    return ExtractedCriminalCertificateFields(
      protocolNumber: (protocolNumber != null && protocolNumber!.isNotEmpty)
          ? protocolNumber
          : fallback.protocolNumber,
      issuedDate: issuedDate ?? fallback.issuedDate,
      validationCode: (validationCode != null && validationCode!.isNotEmpty)
          ? validationCode
          : fallback.validationCode,
      holderName: (holderName != null && holderName!.isNotEmpty)
          ? holderName
          : fallback.holderName,
      holderCpfDigits: (holderCpfDigits != null && holderCpfDigits!.isNotEmpty)
          ? holderCpfDigits
          : fallback.holderCpfDigits,
      qrUrl: (qrUrl != null && qrUrl!.isNotEmpty) ? qrUrl : fallback.qrUrl,
    );
  }
}

/// Motor forense Web-safe (zero `dart:io`) para leitura, descompactação `FlateDecode`
/// e validação de Certidões de Antecedentes Criminais da Polícia Federal (`ePol/SINIC`).
class CriminalBackgroundService {
  const CriminalBackgroundService._();

  /// Portal público oficial e gratuito da Polícia Federal para emissão imediata da certidão.
  static const String officialPoliciaFederalUrl =
      'https://servicos.pf.gov.br/epol-sinic-publico/';

  /// Prazo máximo legal de emissão da certidão da Polícia Federal (90 dias).
  static const int maxCertificateAgeDays = 90;

  /// Ciclo obrigatório de revalidação na plataforma alinhado ao prazo oficial da PF (90 dias).
  static const int validityCycleDays = 90;

  /// Antecedência do primeiro e-mail de aviso prévio de vencimento (15 dias antes).
  static const int expiryReminderLeadDays = 15;

  /// Equivalente em meses do ciclo de revalidação (3 meses = 90 dias).
  static const int validityCycleMonths = 3;

  static const Set<String> _connectives = <String>{
    'de',
    'da',
    'do',
    'das',
    'dos',
    'e',
  };

  static final RegExp _promptInjectionRe = RegExp(
    r'\b(?:ignore\s+(?:all\s+|as\s+)?(?:previous\s+|instru[cç][oõ]es)|system\s+override|jailbreak|aprove\s+est[ae]\s+(?:documento|certid[aã]o))\b',
    caseSensitive: false,
  );

  static const Map<String, int> _ptMonths = <String, int>{
    'janeiro': 1,
    'fevereiro': 2,
    'marco': 3,
    'abril': 4,
    'maio': 5,
    'junho': 6,
    'julho': 7,
    'agosto': 8,
    'setembro': 9,
    'outubro': 10,
    'novembro': 11,
    'dezembro': 12,
  };

  /// Calcula o digest `SHA-256` hexadecimal (64 caracteres minúsculos) dos bytes reais do arquivo.
  static String computeSha256Hex(Uint8List bytes) =>
      sha256.convert(bytes).toString().toLowerCase();

  /// Mascara o número da certidão/protocolo para exibição e persistência compatível com LGPD.
  static String maskProtocol(String rawProtocol) {
    final alnum = rawProtocol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (alnum.isEmpty) return 'PF-****';
    final suffix = alnum.length <= 4 ? alnum : alnum.substring(alnum.length - 4);
    return 'PF-***$suffix';
  }

  /// Detecta a extensão canônica (`pdf`, `jpg`, `png`, `webp`) combinando magic bytes e nome do arquivo.
  static String detectCanonicalExtension(Uint8List bytes, String fileName) {
    if (_startsWithPdfHeader(bytes)) return 'pdf';
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0 && dot < fileName.length - 1) {
      final ext = fileName.substring(dot + 1).trim().toLowerCase();
      if (ext == 'pdf') return 'pdf';
      if (ext == 'png') return 'png';
      if (ext == 'webp') return 'webp';
      if (ext == 'jpg' || ext == 'jpeg') return 'jpg';
    }
    return 'pdf';
  }

  static bool _startsWithPdfHeader(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // Permite até 16 bytes iniciais de whitespace antes de `%PDF-`
    final limit = math.min(bytes.length - 5, 16);
    for (int i = 0; i <= limit; i++) {
      if (bytes[i] == 0x25 && // %
          bytes[i + 1] == 0x50 && // P
          bytes[i + 2] == 0x44 && // D
          bytes[i + 3] == 0x46 && // F
          bytes[i + 4] == 0x2D) {
        return true;
      }
    }
    return false;
  }

  /// Extrai texto legível de arquivos PDF (incluindo streams compactados `FlateDecode` / Zlib,
  /// PNG Predictors `/Predictor 10..15`, Object Streams `/Type /ObjStm`, `ToUnicode CMap`
  /// `beginbfchar`/`beginbfrange` para fontes `Identity-H`/`CIDFontType2` da PF e literais PDF
  /// `(...)` / `<...>`) ou texto UTF-8/Latin-1 contido nos bytes.
  static String extractReadableTextFromPdfOrBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final chunks = <String>[];

    if (_startsWithPdfHeader(bytes)) {
      final rawLatin1 = latin1.decode(bytes, allowInvalid: true);
      final parsedStreams = <_PdfParsedStream>[];
      final cmapByObjNum = <int, _PdfToUnicodeCMap>{};
      final mergedCMap = _PdfToUnicodeCMap();
      final objStmBodies = <String>[];

      final streamRe = RegExp(r'(?<![A-Za-z])stream(?:\r\n|\n|\r)');
      int searchFrom = 0;
      while (searchFrom < rawLatin1.length) {
        final match = streamRe.firstMatch(rawLatin1.substring(searchFrom));
        if (match == null) break;
        final streamKwStart = searchFrom + match.start;
        final dataStart = searchFrom + match.end;
        final endIdx = rawLatin1.indexOf('endstream', dataStart);
        if (endIdx < 0) break;

        var dataEnd = endIdx;
        if (dataEnd > dataStart && rawLatin1.codeUnitAt(dataEnd - 1) == 0x0A) {
          dataEnd--;
          if (dataEnd > dataStart && rawLatin1.codeUnitAt(dataEnd - 1) == 0x0D) {
            dataEnd--;
          }
        } else if (dataEnd > dataStart && rawLatin1.codeUnitAt(dataEnd - 1) == 0x0D) {
          dataEnd--;
        }

        final headerInfo = _parseStreamHeaderBefore(rawLatin1, streamKwStart);
        if (!headerInfo.isImage && dataEnd > dataStart && dataEnd <= bytes.length) {
          final streamSlice = Uint8List.sublistView(bytes, dataStart, dataEnd);
          Uint8List? inflated = _tryInflateZlibOrDeflate(streamSlice);
          if (inflated != null && headerInfo.predictor >= 10 && headerInfo.predictor <= 15) {
            inflated = _undoPngPredictor(
              inflated,
              columns: headerInfo.columns,
              colors: headerInfo.colors,
              bitsPerComponent: headerInfo.bitsPerComponent,
            );
          } else if (inflated != null && headerInfo.predictor == 2) {
            inflated = _undoTiffPredictor(
              inflated,
              columns: headerInfo.columns,
              colors: headerInfo.colors,
              bitsPerComponent: headerInfo.bitsPerComponent,
            );
          }

          final effectiveBytes = inflated ?? streamSlice;
          final decodedStream = _decodeBytesUtf8OrLatin1(effectiveBytes);

          if (headerInfo.isObjStm) {
            final first = headerInfo.firstOffset;
            final objBody = (first > 0 && first < effectiveBytes.length)
                ? _decodeBytesUtf8OrLatin1(
                    Uint8List.sublistView(effectiveBytes, first),
                  )
                : decodedStream;
            objStmBodies.add(objBody);
          } else if (_looksLikeToUnicodeCMap(decodedStream)) {
            final cmap = _PdfToUnicodeCMap.parse(decodedStream);
            if (cmap.isNotEmpty) {
              if (headerInfo.objNum != null) {
                cmapByObjNum[headerInfo.objNum!] = cmap;
              }
              mergedCMap.mergeFrom(cmap);
            }
          } else {
            parsedStreams.add(
              _PdfParsedStream(
                decodedStream: decodedStream,
                wasInflated: inflated != null,
                objNum: headerInfo.objNum,
              ),
            );
          }
        }
        searchFrom = endIdx + 9;
      }

      // Mapeia nomes de fonte (/F1, /TT0, /C2_0...) para seus ToUnicode CMaps específicos
      final fullCatalogSource = objStmBodies.isEmpty
          ? rawLatin1
          : '$rawLatin1\n${objStmBodies.join('\n')}';
      final cmapByFontName = _resolveFontNameCMaps(fullCatalogSource, cmapByObjNum);

      // Passada 2: decodifica todos os content streams com suporte a ToUnicode CMap e kerning TJ
      for (final st in parsedStreams) {
        final pdfText = _extractPdfContentStreamStrings(
          st.decodedStream,
          cmapByFontName: cmapByFontName,
          fallbackCMap: mergedCMap.isNotEmpty ? mergedCMap : null,
        );
        if (pdfText.isNotEmpty) {
          chunks.add(pdfText);
        } else if (st.wasInflated) {
          final printable = _extractPrintableRuns(st.decodedStream);
          if (printable.isNotEmpty) {
            chunks.add(printable);
          }
        }
      }

      // Extrai literais e URIs de Object Streams (/Type /ObjStm)
      for (final body in objStmBodies) {
        final objText = _extractPdfContentStreamStrings(
          body,
          cmapByFontName: cmapByFontName,
          fallbackCMap: mergedCMap.isNotEmpty ? mergedCMap : null,
        );
        if (objText.isNotEmpty) {
          chunks.add(objText);
        }
      }

      // Captura também strings PDF diretas fora de streams compactados (ex.: anotações /URI)
      final directPdfStrings = _extractPdfContentStreamStrings(
        rawLatin1,
        cmapByFontName: cmapByFontName,
        fallbackCMap: mergedCMap.isNotEmpty ? mergedCMap : null,
      );
      if (directPdfStrings.isNotEmpty) {
        chunks.add(directPdfStrings);
      }
    }

    // Fallback para PDFs com texto plano ou strings legíveis diretas
    final plain = _decodeBytesUtf8OrLatin1(bytes);
    final printableRuns = _extractPrintableRuns(plain);
    if (printableRuns.isNotEmpty) {
      chunks.add(printableRuns);
    }

    return chunks.join('\n').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _extractPrintableRuns(String raw) {
    return RegExp(r'[A-Za-zÀ-ÿ0-9.,:/\-ºª°()\s?=&_]{8,}')
        .allMatches(raw)
        .map((m) => m.group(0)!)
        .join(' ')
        .trim();
  }

  static bool _looksLikeToUnicodeCMap(String s) {
    return s.contains('beginbfchar') ||
        s.contains('beginbfrange') ||
        (s.contains('begincmap') && s.contains('endcmap'));
  }

  static _PdfStreamHeaderInfo _parseStreamHeaderBefore(
    String rawLatin1,
    int streamKwStart,
  ) {
    final lookbackStart = math.max(0, streamKwStart - 4096);
    var headerSlice = rawLatin1.substring(lookbackStart, streamKwStart);
    final prevEndObj = headerSlice.lastIndexOf('endobj');
    if (prevEndObj >= 0) {
      headerSlice = headerSlice.substring(prevEndObj + 6);
    }
    final prevEndStream = headerSlice.lastIndexOf('endstream');
    if (prevEndStream >= 0) {
      headerSlice = headerSlice.substring(prevEndStream + 9);
    }

    // Localiza o dicionário `<< ... >>` imediatamente anterior à palavra-chave `stream`
    final lastClose = headerSlice.lastIndexOf('>>');
    String dict = '';
    int dictStartInSlice = headerSlice.length;
    if (lastClose >= 0) {
      int depth = 0;
      for (int i = lastClose + 1; i >= 1; i--) {
        if (headerSlice.codeUnitAt(i) == 0x3E &&
            headerSlice.codeUnitAt(i - 1) == 0x3E) {
          depth++;
          i--;
        } else if (headerSlice.codeUnitAt(i) == 0x3C &&
            headerSlice.codeUnitAt(i - 1) == 0x3C) {
          depth--;
          if (depth == 0) {
            dictStartInSlice = i - 1;
            dict = headerSlice.substring(dictStartInSlice, lastClose + 2);
            break;
          }
          i--;
        }
      }
    }

    int? objNum;
    final prefixBeforeDict = headerSlice.substring(0, dictStartInSlice);
    final objMatches = RegExp(r'(\d+)\s+\d+\s+obj\b').allMatches(prefixBeforeDict).toList();
    if (objMatches.isNotEmpty) {
      objNum = int.tryParse(objMatches.last.group(1)!);
    }

    final isImage = RegExp(r'/Subtype\s*/Image\b').hasMatch(dict);
    final isObjStm = RegExp(r'/Type\s*/ObjStm\b').hasMatch(dict);
    final firstMatch = RegExp(r'/First\s+(\d+)').firstMatch(dict);
    final predMatch = RegExp(r'/Predictor\s+(\d+)').firstMatch(dict);
    final colMatch = RegExp(r'/Columns\s+(\d+)').firstMatch(dict);
    final colorMatch = RegExp(r'/Colors\s+(\d+)').firstMatch(dict);
    final bpcMatch = RegExp(r'/BitsPerComponent\s+(\d+)').firstMatch(dict);

    return _PdfStreamHeaderInfo(
      objNum: objNum,
      isImage: isImage,
      isObjStm: isObjStm,
      firstOffset: int.tryParse(firstMatch?.group(1) ?? '') ?? 0,
      predictor: int.tryParse(predMatch?.group(1) ?? '') ?? 1,
      columns: math.max(1, int.tryParse(colMatch?.group(1) ?? '') ?? 1),
      colors: math.max(1, int.tryParse(colorMatch?.group(1) ?? '') ?? 1),
      bitsPerComponent: math.max(1, int.tryParse(bpcMatch?.group(1) ?? '') ?? 8),
    );
  }

  static Map<String, _PdfToUnicodeCMap> _resolveFontNameCMaps(
    String pdfText,
    Map<int, _PdfToUnicodeCMap> cmapByObjNum,
  ) {
    final result = <String, _PdfToUnicodeCMap>{};
    if (cmapByObjNum.isEmpty) return result;

    // 1. Mapeia objeto de fonte N -> objeto ToUnicode M
    final fontObjToCMap = <int, _PdfToUnicodeCMap>{};
    final objRe = RegExp(r'(\d+)\s+\d+\s+obj\b([\s\S]*?)endobj');
    for (final m in objRe.allMatches(pdfText)) {
      final body = m.group(2)!;
      if (!body.contains('/ToUnicode')) continue;
      final tuMatch = RegExp(r'/ToUnicode\s+(\d+)\s+\d+\s+R').firstMatch(body);
      if (tuMatch != null) {
        final cmapId = int.tryParse(tuMatch.group(1)!);
        final cmap = cmapId == null ? null : cmapByObjNum[cmapId];
        final fontId = int.tryParse(m.group(1)!);
        if (cmap != null && fontId != null) {
          fontObjToCMap[fontId] = cmap;
        }
      }
    }

    // 2. Associa nomes de recursos (/F1 12 0 R, /TT0 15 0 R) ao CMap correspondente
    if (fontObjToCMap.isNotEmpty) {
      final fontRefRe = RegExp(r'/([A-Za-z0-9_+\-]+)\s+(\d+)\s+\d+\s+R');
      for (final m in fontRefRe.allMatches(pdfText)) {
        final name = m.group(1)!;
        final refId = int.tryParse(m.group(2)!);
        final cmap = refId == null ? null : fontObjToCMap[refId];
        if (cmap != null) {
          result[name] = cmap;
        }
      }
    }
    return result;
  }

  static Uint8List _undoPngPredictor(
    Uint8List data, {
    required int columns,
    required int colors,
    required int bitsPerComponent,
  }) {
    final bpp = math.max(1, (colors * bitsPerComponent + 7) ~/ 8);
    final rowBytes = math.max(1, (columns * colors * bitsPerComponent + 7) ~/ 8);
    final stride = rowBytes + 1;
    if (data.length < stride) return data;

    final rowCount = data.length ~/ stride;
    final out = Uint8List(rowCount * rowBytes);
    var prevRow = Uint8List(rowBytes);

    int paeth(int a, int b, int c) {
      final p = a + b - c;
      final pa = (p - a).abs();
      final pb = (p - b).abs();
      final pc = (p - c).abs();
      if (pa <= pb && pa <= pc) return a;
      if (pb <= pc) return b;
      return c;
    }

    for (int r = 0; r < rowCount; r++) {
      final srcOff = r * stride;
      final filter = data[srcOff];
      final dstOff = r * rowBytes;
      final curRow = Uint8List(rowBytes);

      for (int i = 0; i < rowBytes; i++) {
        final raw = data[srcOff + 1 + i];
        final left = i >= bpp ? curRow[i - bpp] : 0;
        final up = prevRow[i];
        final upLeft = i >= bpp ? prevRow[i - bpp] : 0;
        final int val;
        switch (filter) {
          case 0:
            val = raw;
            break;
          case 1:
            val = (raw + left) & 0xFF;
            break;
          case 2:
            val = (raw + up) & 0xFF;
            break;
          case 3:
            val = (raw + ((left + up) >> 1)) & 0xFF;
            break;
          case 4:
            val = (raw + paeth(left, up, upLeft)) & 0xFF;
            break;
          default:
            val = raw;
        }
        curRow[i] = val;
        out[dstOff + i] = val;
      }
      prevRow = curRow;
    }
    return out;
  }

  static Uint8List _undoTiffPredictor(
    Uint8List data, {
    required int columns,
    required int colors,
    required int bitsPerComponent,
  }) {
    if (bitsPerComponent != 8) return data;
    final rowBytes = math.max(1, columns * colors);
    final out = Uint8List.fromList(data);
    for (int r = 0; r + rowBytes <= out.length; r += rowBytes) {
      for (int i = colors; i < rowBytes; i++) {
        out[r + i] = (out[r + i] + out[r + i - colors]) & 0xFF;
      }
    }
    return out;
  }

  static String _decodeBytesUtf8OrLatin1(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String _extractPdfContentStreamStrings(
    String content, {
    Map<String, _PdfToUnicodeCMap> cmapByFontName = const <String, _PdfToUnicodeCMap>{},
    _PdfToUnicodeCMap? fallbackCMap,
  }) {
    final out = StringBuffer();
    int i = 0;
    final n = content.length;
    _PdfToUnicodeCMap? activeCMap = fallbackCMap;
    bool inTjArray = false;

    String decodeHexToken(String hexRaw) {
      if (activeCMap != null && activeCMap.isNotEmpty) {
        final mapped = activeCMap.decodeHex(hexRaw);
        if (mapped != null && mapped.isNotEmpty) {
          return mapped;
        }
      }
      if (fallbackCMap != null &&
          !identical(fallbackCMap, activeCMap) &&
          fallbackCMap.isNotEmpty) {
        final mapped = fallbackCMap.decodeHex(hexRaw);
        if (mapped != null && mapped.isNotEmpty) {
          return mapped;
        }
      }
      final padded = hexRaw.length.isOdd ? '${hexRaw}0' : hexRaw;
      final bytes = <int>[];
      for (int k = 0; k < padded.length; k += 2) {
        bytes.add(int.parse(padded.substring(k, k + 2), radix: 16));
      }
      return _decodePdfStringBytes(bytes);
    }

    while (i < n) {
      final ch = content.codeUnitAt(i);

      // Rastreamento de fonte ativa: `/F1 11 Tf`
      if (ch == 0x2F && !inTjArray) {
        final tfMatch = RegExp(r'^/([A-Za-z0-9_+\-]+)\s+[+\-]?\d+(?:\.\d+)?\s+Tf\b')
            .firstMatch(content.substring(i, math.min(n, i + 64)));
        if (tfMatch != null) {
          final fontName = tfMatch.group(1)!;
          activeCMap = cmapByFontName[fontName] ?? fallbackCMap;
          i += tfMatch.end;
          continue;
        }
      }

      // Início de array TJ `[...]`
      if (ch == 0x5B) {
        inTjArray = true;
        i++;
        continue;
      }

      // Fim de array TJ `]`
      if (ch == 0x5D && inTjArray) {
        inTjArray = false;
        out.write(' ');
        i++;
        continue;
      }

      // Ajuste de kerning numérico dentro de array TJ: deslocamento <= -120 equivale a espaço
      if (inTjArray &&
          (ch == 0x2D || ch == 0x2B || (ch >= 0x30 && ch <= 0x39))) {
        final numMatch = RegExp(r'^[+\-]?\d+(?:\.\d+)?')
            .firstMatch(content.substring(i, math.min(n, i + 24)));
        if (numMatch != null) {
          final numVal = double.tryParse(numMatch.group(0)!);
          if (numVal != null && numVal <= -120.0) {
            out.write(' ');
          }
          i += numMatch.end;
          continue;
        }
      }

      // PDF literal string `(...)`
      if (ch == 0x28) {
        i++;
        int depth = 1;
        final bytes = <int>[];
        while (i < n && depth > 0) {
          final c = content.codeUnitAt(i);
          if (c == 0x5C && i + 1 < n) {
            final next = content.codeUnitAt(i + 1);
            if (next >= 0x30 && next <= 0x37) {
              var oct = content.substring(i + 1, math.min(n, i + 4));
              oct = RegExp(r'^[0-7]{1,3}').stringMatch(oct) ?? '';
              if (oct.isNotEmpty) {
                bytes.add(int.parse(oct, radix: 8) & 0xFF);
                i += 1 + oct.length;
                continue;
              }
            }
            switch (next) {
              case 0x6E: // \n
                bytes.add(0x20);
                break;
              case 0x72: // \r
                bytes.add(0x20);
                break;
              case 0x74: // \t
                bytes.add(0x20);
                break;
              default:
                bytes.add(next & 0xFF);
            }
            i += 2;
            continue;
          }
          if (c == 0x28) {
            depth++;
            bytes.add(c);
          } else if (c == 0x29) {
            depth--;
            if (depth > 0) bytes.add(c);
          } else {
            bytes.add(c & 0xFF);
          }
          i++;
        }
        if (bytes.isNotEmpty) {
          final cmapDecoded = (activeCMap != null && activeCMap.hasSingleByteEntries)
              ? activeCMap.decodeBytes(bytes)
              : null;
          out.write(cmapDecoded ?? _decodePdfStringBytes(bytes));
          if (!inTjArray) {
            out.write(' ');
          }
        }
        continue;
      }

      // Ignora delimitadores de dicionário `<<` e `>>`
      if (ch == 0x3C && i + 1 < n && content.codeUnitAt(i + 1) == 0x3C) {
        i += 2;
        continue;
      }
      if (ch == 0x3E && i + 1 < n && content.codeUnitAt(i + 1) == 0x3E) {
        i += 2;
        continue;
      }

      // PDF hex string `<...>`
      if (ch == 0x3C) {
        final close = content.indexOf('>', i + 1);
        if (close > i + 1 && close - i <= 8192) {
          final hexRaw = content.substring(i + 1, close).replaceAll(RegExp(r'\s+'), '');
          if (hexRaw.isNotEmpty && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hexRaw)) {
            out.write(decodeHexToken(hexRaw));
            if (!inTjArray) {
              out.write(' ');
            }
          }
          i = close + 1;
          continue;
        }
      }
      i++;
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodePdfStringBytes(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final codeUnits = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(codeUnits);
    }
    return _decodeBytesUtf8OrLatin1(Uint8List.fromList(bytes));
  }

  /// Analisa e valida de forma determinística a Certidão de Antecedentes Criminais da Polícia Federal.
  static Future<AuditedCriminalRecordResult> analyzeAndValidateCertificate({
    required Uint8List fileBytes,
    required String fileName,
    required String expectedFullName,
    required String expectedCpfRaw,
    String? manualProtocol,
    DateTime? manualIssuedDate,
    String? manualValidationCode,
    String? rawExtractedTextOverride,
    String? qrPayload,
    DateTime? referenceNow,
  }) async {
    final nowUtc = (referenceNow ?? DateTime.now()).toUtc();
    final fallbackDate = manualIssuedDate ?? DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final ext = detectCanonicalExtension(fileBytes, fileName);
    final fileHash = fileBytes.isEmpty ? ('0' * 64) : computeSha256Hex(fileBytes);
    final rawProtoInput = (manualProtocol ?? '').trim();
    final rawValInput = (manualValidationCode ?? '').trim();

    AuditedCriminalRecordResult reject(
      String message, {
      String? protocol,
      DateTime? issued,
      String? valCode,
      bool nameOk = false,
      bool cpfOk = false,
    }) {
      final p = (protocol ?? rawProtoInput).trim();
      return AuditedCriminalRecordResult(
        passed: false,
        protocolNumber: p,
        protocolMasked: maskProtocol(p),
        issuedDate: issued ?? fallbackDate,
        validationCode: (valCode ?? rawValInput).trim(),
        fileSha256Hex: fileHash,
        holderNameMatched: nameOk,
        cpfMatched: cpfOk,
        humanFeedbackMessage: message,
        fileBytes: fileBytes,
        fileExtension: ext,
        outcome: 'REJECTED',
      );
    }

    if (fileBytes.length < 24) {
      return reject(
        'O arquivo enviado está vazio ou incompleto. Selecione o PDF oficial ou uma foto nítida da Certidão da Polícia Federal.',
      );
    }

    final expectedCpfDigits = DocumentOcrAndLivenessService.digitsOnly(expectedCpfRaw);
    if (!DocumentOcrAndLivenessService.isValidCpfMod11(expectedCpfDigits)) {
      return reject(
        'Informe um CPF válido do titular antes de validar a Certidão de Antecedentes Criminais.',
      );
    }

    final expectedNameTokens = _normalizeCivilTokens(expectedFullName);
    if (expectedNameTokens.length < 2) {
      return reject(
        'Informe seu nome completo (nome e sobrenome) para conferir a titularidade da certidão.',
      );
    }

    final extractedText = (rawExtractedTextOverride != null &&
            rawExtractedTextOverride.trim().isNotEmpty)
        ? rawExtractedTextOverride.trim()
        : (ext == 'pdf' ? extractReadableTextFromPdfOrBytes(fileBytes) : '');

    if (extractedText.isNotEmpty && _promptInjectionRe.hasMatch(extractedText)) {
      return reject(
        'Não foi possível autenticar o documento enviado. Emita a certidão diretamente no portal oficial da Polícia Federal (gov.br).',
      );
    }

    final extractedFields = extractCertificateFieldsFromText(
      extractedText,
      qrPayload: qrPayload,
    );
    final effectiveProtocol = rawProtoInput.isNotEmpty
        ? rawProtoInput
        : (extractedFields.protocolNumber ?? '');
    final effectiveDate = manualIssuedDate ?? extractedFields.issuedDate;
    final effectiveValCode = rawValInput.isNotEmpty
        ? rawValInput
        : (extractedFields.validationCode ?? '');

    // Caminho A: Texto estrutural disponível (PDF da Polícia Federal ou transcrição de texto)
    final normText = _normalizeAscii(extractedText);
    final hasSubstantialCertText = normText.length >= 40 &&
        (normText.contains('policia federal') ||
            normText.contains('antecedentes criminais') ||
            normText.contains('sinic') ||
            normText.contains('ministerio da justica') ||
            normText.contains('certidao') ||
            normText.contains('consta'));

    if (hasSubstantialCertText) {
      final hasOfficialAuthority = normText.contains('policia federal') ||
          normText.contains('sinic') ||
          normText.contains('ministerio da justica') ||
          normText.contains('antecedentes criminais');
      if (!hasOfficialAuthority) {
        return reject(
          'O arquivo enviado não parece ser uma Certidão de Antecedentes Criminais da Polícia Federal. Emita gratuitamente no portal oficial gov.br/pf.',
          protocol: effectiveProtocol,
          issued: effectiveDate,
          valCode: effectiveValCode,
        );
      }

      final nameOk = _matchesHolderNameInCertificateText(
        expectedFullName: expectedFullName,
        rawCertText: extractedText,
        normCertText: normText,
      );
      final cpfOk = _matchesCpfInCertificateText(
        expectedCpfDigits: expectedCpfDigits,
        rawCertText: extractedText,
      );

      if (!cpfOk) {
        return reject(
          'O CPF constante na certidão não confere com o CPF da sua conta. Emita a certidão utilizando seu próprio CPF.',
          protocol: effectiveProtocol,
          issued: effectiveDate,
          valCode: effectiveValCode,
          nameOk: nameOk,
          cpfOk: false,
        );
      }

      if (!nameOk) {
        return reject(
          'O nome do titular na certidão não confere com o seu nome civil cadastrado. Confira seus dados e envie a certidão em seu nome.',
          protocol: effectiveProtocol,
          issued: effectiveDate,
          valCode: effectiveValCode,
          nameOk: false,
          cpfOk: true,
        );
      }

      // Avaliação determinística de NADA CONSTA / NÃO CONSTA vs CONSTA positivo
      final strippedNegations = normText.replaceAll(
        RegExp(r'\b(?:nao|nada)\s+consta(?:m)?\b'),
        ' ',
      );
      final hasPositiveConsta = RegExp(r'\bconsta(?:m)?\b').hasMatch(strippedNegations);
      final hasClearNegation = RegExp(
        r'\b(?:nao\s+consta(?:m)?|nada\s+consta|inexistencia\s+de\s+registros)\b',
      ).hasMatch(normText);

      if (hasPositiveConsta || !hasClearNegation) {
        return reject(
          'Para segurança da comunidade Desperrengue, é necessária Certidão Negativa vigente ("NÃO CONSTA" / "NADA CONSTA") emitida pela Polícia Federal.',
          protocol: effectiveProtocol,
          issued: effectiveDate,
          valCode: effectiveValCode,
          nameOk: true,
          cpfOk: true,
        );
      }

      // Validação real e rigorosa da data de emissão (JAMAIS assumir "hoje" se ilegível!).
      if (effectiveDate == null) {
        return reject(
          'Não foi possível identificar a data de emissão na certidão enviada. Envie o PDF original baixado no portal da Polícia Federal (gov.br) ou uma foto nítida de página inteira mostrando a data de emissão.',
          protocol: effectiveProtocol,
          valCode: effectiveValCode,
          nameOk: true,
          cpfOk: true,
        );
      }

      final resolvedDate = effectiveDate;
      final ageDays = _ageInDays(resolvedDate, nowUtc);
      if (ageDays < -1) {
        return reject(
          'A data de emissão identificada na certidão está no futuro. Emita a certidão diretamente no portal oficial da Polícia Federal e tente novamente.',
          protocol: effectiveProtocol,
          issued: resolvedDate,
          valCode: effectiveValCode,
          nameOk: true,
          cpfOk: true,
        );
      }
      if (ageDays > maxCertificateAgeDays) {
        return reject(
          'Esta certidão foi emitida há mais de 90 dias (prazo máximo oficial da Polícia Federal). Emita gratuitamente uma nova certidão no site da PF e envie novamente.',
          protocol: effectiveProtocol,
          issued: resolvedDate,
          valCode: effectiveValCode,
          nameOk: true,
          cpfOk: true,
        );
      }

      final cleanProtocol = effectiveProtocol.replaceAll(RegExp(r'[^A-Za-z0-9./\-]'), '');
      final finalProtocol = cleanProtocol.length >= 6
          ? cleanProtocol
          : 'PF-${fileHash.substring(0, 10).toUpperCase()}';
      final finalValCode = effectiveValCode.trim().length >= 4
          ? effectiveValCode.trim()
          : 'SINIC-${fileHash.substring(10, 18).toUpperCase()}';

      final validUntil = resolvedDate.add(const Duration(days: validityCycleDays));
      final validUntilBr =
          '${validUntil.day.toString().padLeft(2, '0')}/${validUntil.month.toString().padLeft(2, '0')}/${validUntil.year.toString().padLeft(4, '0')}';

      return AuditedCriminalRecordResult(
        passed: true,
        protocolNumber: finalProtocol,
        protocolMasked: maskProtocol(finalProtocol),
        issuedDate: resolvedDate,
        validationCode: finalValCode,
        fileSha256Hex: fileHash,
        holderNameMatched: true,
        cpfMatched: true,
        humanFeedbackMessage:
            'Certidão Negativa da Polícia Federal validada! Vigência de 90 dias (válida até $validUntilBr).',
        fileBytes: fileBytes,
        fileExtension: ext,
        outcome: 'NOTHING_ON_RECORD',
      );
    }

    // Caminho B: Upload de Imagem (foto/captura da certidão impressa) ou PDF escaneado em imagem
    // sem texto estrutural legível.
    if (ext == 'pdf') {
      if (!_startsWithPdfHeader(fileBytes)) {
        return reject(
          'O arquivo PDF selecionado parece estar corrompido. Baixe novamente o PDF oficial no portal da Polícia Federal.',
        );
      }
    } else {
      final decodedImg = img.decodeImage(fileBytes);
      if (decodedImg == null || decodedImg.width < 80 || decodedImg.height < 80) {
        return reject(
          'Não foi possível ler a imagem enviada. Envie o PDF original da Polícia Federal ou tire uma foto nítida de página inteira.',
        );
      }
      if (!_hasSufficientDocumentContrast(decodedImg)) {
        return reject(
          'A foto da certidão está muito escura ou sem foco. Posicione a certidão em local iluminado e tire uma nova foto nítida.',
        );
      }
    }

    // Sem campos manuais preenchidos (fluxo automático padrão da UI): solicita PDF original
    // ou foto mais nítida em vez de pedir digitação manual ao usuário.
    final bool hasAnyManualMetadata =
        rawProtoInput.isNotEmpty || manualIssuedDate != null || rawValInput.isNotEmpty;
    if (!hasAnyManualMetadata) {
      return reject(
        'Não conseguimos ler automaticamente os dados da Polícia Federal neste arquivo. Envie o PDF original baixado no gov.br ou uma foto bem iluminada de página inteira.',
      );
    }

    final cleanManualProto = effectiveProtocol.replaceAll(RegExp(r'[^A-Za-z0-9./\-]'), '');
    if (cleanManualProto.length < 6) {
      return reject(
        'Não foi possível identificar o número da certidão da Polícia Federal (mínimo 6 dígitos).',
        protocol: effectiveProtocol,
        issued: effectiveDate,
        valCode: effectiveValCode,
      );
    }

    if (effectiveDate == null) {
      return reject(
        'Não foi possível identificar a data de emissão da Certidão de Antecedentes Criminais.',
        protocol: cleanManualProto,
        valCode: effectiveValCode,
      );
    }

    final ageDays = _ageInDays(effectiveDate, nowUtc);
    if (ageDays < -1) {
      return reject(
        'A data de emissão da certidão está no futuro. Emita uma nova certidão no portal oficial da Polícia Federal.',
        protocol: cleanManualProto,
        issued: effectiveDate,
        valCode: effectiveValCode,
      );
    }
    if (ageDays > maxCertificateAgeDays) {
      return reject(
        'Esta certidão foi emitida há mais de 90 dias. Emita gratuitamente uma certidão atualizada no portal da Polícia Federal.',
        protocol: cleanManualProto,
        issued: effectiveDate,
        valCode: effectiveValCode,
      );
    }

    if (effectiveValCode.trim().length < 4) {
      return reject(
        'Não foi possível identificar o código de autenticidade eletrônica da Polícia Federal.',
        protocol: cleanManualProto,
        issued: effectiveDate,
        valCode: effectiveValCode,
      );
    }

    return AuditedCriminalRecordResult(
      passed: true,
      protocolNumber: cleanManualProto,
      protocolMasked: maskProtocol(cleanManualProto),
      issuedDate: effectiveDate,
      validationCode: effectiveValCode.trim(),
      fileSha256Hex: fileHash,
      holderNameMatched: true,
      cpfMatched: true,
      humanFeedbackMessage:
          'Certidão Negativa de Antecedentes Criminais validada com vigência oficial de 90 dias.',
      fileBytes: fileBytes,
      fileExtension: ext,
      outcome: 'NOTHING_ON_RECORD',
    );
  }

  static bool _hasSufficientDocumentContrast(img.Image image) {
    final stepX = math.max(1, image.width ~/ 32);
    final stepY = math.max(1, image.height ~/ 32);
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sum += lum;
        sumSq += lum * lum;
        count++;
      }
    }
    if (count < 4) return false;
    final mean = sum / count;
    final variance = math.max(0.0, (sumSq / count) - (mean * mean));
    return math.sqrt(variance) >= 8.0;
  }

  static int _ageInDays(DateTime issuedDate, DateTime nowUtc) {
    final refDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final issDay = DateTime.utc(issuedDate.year, issuedDate.month, issuedDate.day);
    return refDay.difference(issDay).inDays;
  }

  static String _normalizeAscii(String raw) {
    if (raw.isEmpty) return '';
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const to = 'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn';
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch.toLowerCase());
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _normalizeCivilTokens(String raw) {
    final clean = _normalizeAscii(raw).replaceAll(RegExp(r'[^a-z\s]'), ' ');
    return clean
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_connectives.contains(t))
        .toList(growable: false);
  }

  static bool _matchesHolderNameInCertificateText({
    required String expectedFullName,
    required String rawCertText,
    required String normCertText,
  }) {
    // 1. Se houver marcador explícito ("EM NOME DE <NOME>", "NOME: <NOME>"), valida compatibilidade direta
    final spanMatch = RegExp(
      r'(?:em\s+nome\s+de|nome(?:\s+completo)?\s*:)\s*([a-z\s]{5,90}?)(?:,|\bcpf\b|\bnascid|\bfilh|\brg\b|\bportador|\bcidadao|\bdad[oa]s|\bemiti|$)',
    ).firstMatch(normCertText);

    if (spanMatch != null) {
      final extractedSpan = spanMatch.group(1)!.trim();
      final spanTokens = _normalizeCivilTokens(extractedSpan);
      if (spanTokens.length >= 2) {
        final score = DocumentOcrAndLivenessService.computeCivilNameCompatibility(
          expectedFullName,
          extractedSpan,
        );
        return score >= 0.80;
      }
    }

    // 2. Fallback: verifica presença ordenada dos tokens civis do titular no corpo da certidão
    final expectedTokens = _normalizeCivilTokens(expectedFullName);
    final bodyTokens = _normalizeCivilTokens(rawCertText);
    if (expectedTokens.length < 2 || bodyTokens.length < 2) return false;

    int searchIdx = 0;
    int matchedInOrder = 0;
    for (final tok in expectedTokens) {
      while (searchIdx < bodyTokens.length) {
        if (bodyTokens[searchIdx] == tok) {
          matchedInOrder++;
          searchIdx++;
          break;
        }
        searchIdx++;
      }
    }
    return matchedInOrder >= 2 && (matchedInOrder / expectedTokens.length) >= 0.80;
  }

  static bool _matchesCpfInCertificateText({
    required String expectedCpfDigits,
    required String rawCertText,
  }) {
    final foundValidCpfs = <String>{};
    for (final m in RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}[\-.]?\d{2}\b').allMatches(rawCertText)) {
      final d = DocumentOcrAndLivenessService.digitsOnly(m.group(0)!);
      if (d.length == 11 && DocumentOcrAndLivenessService.isValidCpfMod11(d)) {
        foundValidCpfs.add(d);
      }
    }
    if (foundValidCpfs.isEmpty) {
      // Certidões que omitem ou mascaram parcialmente o CPF permanecem válidas se não houver CPF divergente
      final maskedMid = '${expectedCpfDigits.substring(3, 6)}.${expectedCpfDigits.substring(6, 9)}';
      if (rawCertText.contains('***') && !rawCertText.contains(maskedMid)) {
        return false;
      }
      return true;
    }
    return foundValidCpfs.contains(expectedCpfDigits);
  }

  static const Set<String> _validationCodeStopWords = <String>{
    'desta',
    'deste',
    'certidao',
    'devera',
    'pode',
    'poder',
    'sera',
    'pela',
    'pelo',
    'pagina',
    'portal',
    'policia',
    'federal',
    'confirmada',
    'verificada',
    'eletronica',
    'digital',
    'online',
    'site',
    'endereco',
    'atraves',
    'para',
    'com',
  };

  /// Extrai campos oficiais (protocolo/nº da certidão, data de emissão, código de
  /// validação eletrônica, titular e CPF) a partir do texto da certidão e/ou da
  /// URL/payload do QR Code oficial da Polícia Federal (layouts 2023–2026).
  static ExtractedCriminalCertificateFields extractCertificateFieldsFromText(
    String text, {
    String? qrPayload,
  }) {
    final trimmedText = text.trim();
    final embeddedQrUrl = _extractPfValidationUrlFromText(trimmedText);
    final effectiveQr = (qrPayload != null && qrPayload.trim().isNotEmpty)
        ? qrPayload.trim()
        : embeddedQrUrl;

    final qrFields = effectiveQr != null && effectiveQr.isNotEmpty
        ? _extractFieldsFromQrPayload(effectiveQr)
        : const ExtractedCriminalCertificateFields();

    final textProtocol = _extractProtocolFromText(trimmedText);
    final textDate = _extractDateFromText(trimmedText);
    final textValCode = _extractValidationCodeFromText(trimmedText);
    final textName = _extractHolderNameFromText(trimmedText);
    final textCpf = _extractFirstValidCpfFromText(trimmedText);

    final protocol = (textProtocol != null && textProtocol.isNotEmpty)
        ? textProtocol
        : qrFields.protocolNumber;
    final issuedDate = textDate ?? qrFields.issuedDate;

    var validationCode = (textValCode != null && textValCode.isNotEmpty)
        ? textValCode
        : qrFields.validationCode;

    // Layout novo ePol-SINIC (2024–2026): a chave de autenticação em `validar-cac`
    // pode ser o próprio número/código da certidão acompanhado do QR oficial da PF.
    final isPfSinicContext = _isOfficialPfSinicContext(trimmedText, effectiveQr);
    if ((validationCode == null || validationCode.isEmpty) &&
        isPfSinicContext &&
        protocol != null &&
        protocol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 6) {
      validationCode = protocol;
    }

    return ExtractedCriminalCertificateFields(
      protocolNumber: protocol,
      issuedDate: issuedDate,
      validationCode: validationCode,
      holderName: textName ?? qrFields.holderName,
      holderCpfDigits: textCpf ?? qrFields.holderCpfDigits,
      qrUrl: qrFields.qrUrl ?? embeddedQrUrl,
    );
  }

  static bool _isOfficialPfSinicContext(String text, String? qrPayload) {
    final normText = _normalizeAscii(text);
    final qrLower = (qrPayload ?? '').toLowerCase();
    return qrLower.contains('servicos.pf.gov.br') ||
        qrLower.contains('epol-sinic') ||
        qrLower.contains('validar-cac') ||
        normText.contains('validar-cac') ||
        normText.contains('epol-sinic') ||
        normText.contains('servicos.pf.gov.br') ||
        (normText.contains('policia federal') &&
            (normText.contains('sinic') ||
                normText.contains('antecedentes criminais')));
  }

  static String? _extractPfValidationUrlFromText(String text) {
    if (text.isEmpty) return null;
    final m = RegExp(
      r'https?://[^\s"<>)\]]*(?:pf\.gov\.br|epol-sinic|validar-cac)[^\s"<>)\]]*',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.replaceAll(RegExp(r'[.,;]+$'), '').trim();
  }

  static ExtractedCriminalCertificateFields _extractFieldsFromQrPayload(
    String rawQr,
  ) {
    final trimmed = rawQr.trim();
    if (trimmed.isEmpty) return const ExtractedCriminalCertificateFields();

    final uri = Uri.tryParse(trimmed);
    String? protocol;
    String? validationCode;
    DateTime? issuedDate;
    String? cpfDigits;
    String? qrUrl;

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      qrUrl = trimmed;
      final qpLower = <String, String>{};
      uri.queryParameters.forEach((k, v) {
        final cleanVal = v.trim();
        if (cleanVal.isNotEmpty) {
          qpLower[k.toLowerCase()] = cleanVal;
        }
      });

      const protoKeys = <String>[
        'numerocertidao',
        'numero_certidao',
        'numcertidao',
        'certidao',
        'numero',
        'protocolo',
        'cac',
        'id',
      ];
      for (final k in protoKeys) {
        final v = qpLower[k];
        if (v != null && _looksLikeProtocolToken(v)) {
          protocol = v;
          break;
        }
      }

      const codeKeys = <String>[
        'codigovalidacao',
        'codigo_validacao',
        'codigoautenticacao',
        'codigo_autenticacao',
        'codigocontrole',
        'codigo_controle',
        'codigo',
        'autenticacao',
        'autenticidade',
        'chave',
        'token',
        'hash',
        'verificador',
        'validador',
      ];
      for (final k in codeKeys) {
        final v = qpLower[k];
        if (v != null && _looksLikeValidationCodeToken(v)) {
          validationCode = v;
          break;
        }
      }

      const dateKeys = <String>[
        'dataemissao',
        'data_emissao',
        'dtemissao',
        'emissao',
        'data',
        'issueddate',
      ];
      for (final k in dateKeys) {
        final v = qpLower[k];
        if (v != null) {
          final parsed = _parseFlexibleDate(v);
          if (parsed != null) {
            issuedDate = parsed;
            break;
          }
        }
      }

      final rawCpf = qpLower['cpf'];
      if (rawCpf != null) {
        final digits = DocumentOcrAndLivenessService.digitsOnly(rawCpf);
        if (digits.length == 11 &&
            DocumentOcrAndLivenessService.isValidCpfMod11(digits)) {
          cpfDigits = digits;
        }
      }

      // Caminho REST: .../validar-cac/<numeroCertidao>[/<codigo>]
      final segs = uri.pathSegments
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final idxValidar = segs.indexWhere(
        (s) => s.toLowerCase().contains('validar'),
      );
      if (idxValidar >= 0) {
        for (int i = idxValidar + 1; i < segs.length; i++) {
          final seg = segs[i];
          if (protocol == null && _looksLikeProtocolToken(seg)) {
            protocol = seg;
          } else if (validationCode == null &&
              _looksLikeValidationCodeToken(seg)) {
            validationCode = seg;
          }
        }
      }
    }

    // Caso o QR contenha texto estruturado (não apenas URL)
    protocol ??= _extractProtocolFromText(trimmed);
    issuedDate ??= _extractDateFromText(trimmed);
    validationCode ??= _extractValidationCodeFromText(trimmed);
    cpfDigits ??= _extractFirstValidCpfFromText(trimmed);

    final isPfUrl = (qrUrl ?? '').toLowerCase().contains('validar-cac') ||
        (qrUrl ?? '').toLowerCase().contains('epol-sinic') ||
        (qrUrl ?? '').toLowerCase().contains('servicos.pf.gov.br');
    if (validationCode == null && isPfUrl && protocol != null) {
      validationCode = protocol;
    }

    return ExtractedCriminalCertificateFields(
      protocolNumber: protocol,
      issuedDate: issuedDate,
      validationCode: validationCode,
      holderCpfDigits: cpfDigits,
      qrUrl: qrUrl,
    );
  }

  static bool _looksLikeProtocolToken(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9./\-]'), '');
    if (cleaned.length < 6 || cleaned.length > 32) return false;
    final digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 4;
  }

  static bool _looksLikeValidationCodeToken(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9.\-/]'), '');
    if (cleaned.length < 4 || cleaned.length > 40) return false;
    final lower = cleaned.toLowerCase();
    if (_validationCodeStopWords.contains(lower)) return false;
    // Evita palavras comuns do português sem dígitos ou separadores de código
    final hasDigit = RegExp(r'\d').hasMatch(cleaned);
    final hasCodeSeparator = cleaned.contains('.') || cleaned.contains('-');
    return hasDigit || (hasCodeSeparator && cleaned.length >= 8);
  }

  static String? _extractProtocolFromText(String text) {
    if (text.isEmpty) return null;
    final norm = _normalizeAscii(text);

    // 1. Formatos rotulados oficiais PF 2023–2026:
    //    "Certidão nº 195290532026", "Certidão de Antecedentes Criminais nº 2026.0192837465",
    //    "Número da Certidão: ...", "Protocolo: ..."
    final labeledPatterns = <RegExp>[
      RegExp(
        r'certidao\s+(?:de\s+antecedentes\s+criminais\s+)?(?:n[\s.º°o]*|numero(?:\s+da\s+certidao)?)\s*[:\-]?\s*([a-z0-9][a-z0-9./\-]{5,28})',
      ),
      RegExp(
        r'numero\s+da\s+certidao\s*[:\-]?\s*([a-z0-9][a-z0-9./\-]{5,28})',
      ),
      RegExp(
        r'protocolo(?:\s*(?:pf|sinic|epol))?(?:\s*n[\s.º°o]*)?\s*[:\-]?\s*([a-z0-9][a-z0-9./\-]{5,28})',
      ),
    ];
    for (final re in labeledPatterns) {
      for (final m in re.allMatches(norm)) {
        final rawTok = m.group(1)!.replaceAll(RegExp(r'[.,;:\-]+$'), '').trim();
        if (_looksLikeProtocolToken(rawTok) && !_isFormattedCpf(rawTok)) {
          return rawTok.toUpperCase();
        }
      }
    }

    // 2. Formato PF com ano no prefixo (ex.: 2026.0192837465 ou 20260192837465)
    for (final m in RegExp(r'\b(20\d{2}[./\-]?\d{6,16})\b').allMatches(norm)) {
      final candidate = m.group(1)!.trim();
      if (!_isPrecededByCpf(norm, m.start) && !_isFormattedCpf(candidate)) {
        return candidate;
      }
    }

    // 3. Formato PF ePol-SINIC com ano no sufixo (ex.: 195290532026 = 8 dígitos + 2026)
    for (final m in RegExp(r'\b(\d{6,12}20\d{2})\b').allMatches(norm)) {
      final candidate = m.group(1)!.trim();
      if (!_isPrecededByCpf(norm, m.start) && !_isValidCpfString(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  static bool _isFormattedCpf(String token) {
    return RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$').hasMatch(token);
  }

  static bool _isValidCpfString(String token) {
    final digits = DocumentOcrAndLivenessService.digitsOnly(token);
    return digits.length == 11 &&
        DocumentOcrAndLivenessService.isValidCpfMod11(digits);
  }

  static bool _isPrecededByCpf(String norm, int startIdx) {
    final prefix = norm.substring(math.max(0, startIdx - 12), startIdx);
    return prefix.contains('cpf');
  }

  static DateTime? _extractDateFromText(String text) {
    if (text.isEmpty) return null;
    final norm = _normalizeAscii(text);

    // 1. Prioriza datas em contexto explícito de emissão ("Emitida às HH:mm do dia dd/MM/yyyy",
    //    "Data de emissão: ...", "Expedida em ...") para nunca confundir com data de nascimento.
    final emissionContexts = <RegExp>[
      RegExp(
        r'(?:emitid[ao]|expedid[ao]|gerad[ao]|assinad[ao])\s+(?:as\s+\d{1,2}[:h]\d{2}(?::\d{2})?\s+)?(?:do\s+dia\s+|em\s+)?([^\n,;]{8,36})',
      ),
      RegExp(
        r'(?:data\s+de\s+emiss[ao]{2}|emiss[ao]{2})\s*[:\-]?\s*([^\n,;]{8,36})',
      ),
      RegExp(
        r'as\s+\d{1,2}[:h]\d{2}(?::\d{2})?\s+(?:horas?\s+)?do\s+dia\s+([^\n,;]{8,36})',
      ),
    ];
    for (final re in emissionContexts) {
      for (final m in re.allMatches(norm)) {
        final parsed = _parseFlexibleDate(m.group(1)!);
        if (parsed != null) return parsed;
      }
    }

    // 2. Fallback geral: dd/MM/yyyy, yyyy-MM-dd ou "dd de <mês> de yyyy" (ignorando nascimento)
    // Preferimos a data não-nascimento MAIS RECENTE (para nunca confundir nascimento em 200x com emissão atual).
    bool isBirthContext(String src, int idx) {
      final before = src.substring(math.max(0, idx - 42), idx);
      return before.contains('nascid') ||
          before.contains('nascimento') ||
          before.contains('dt nasc') ||
          before.contains('data nasc');
    }

    final List<DateTime> fallbackDates = <DateTime>[];

    for (final m in RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])/(0?[1-9]|1[0-2])/(20\d{2})\b',
    ).allMatches(norm)) {
      if (isBirthContext(norm, m.start)) continue;
      final dt = _tryBuildUtcDate(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
      if (dt != null) fallbackDates.add(dt);
    }

    for (final m in RegExp(
      r'\b(20\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])\b',
    ).allMatches(norm)) {
      if (isBirthContext(norm, m.start)) continue;
      final dt = _tryBuildUtcDate(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
      if (dt != null) fallbackDates.add(dt);
    }

    for (final m in RegExp(
      r'\b([0-3]?\d)\s+de\s+(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+(20\d{2})\b',
    ).allMatches(norm)) {
      if (isBirthContext(norm, m.start)) continue;
      final d = int.parse(m.group(1)!);
      final month = _ptMonths[m.group(2)!] ?? 0;
      final y = int.parse(m.group(3)!);
      final dt = _tryBuildUtcDate(y, month, d);
      if (dt != null) fallbackDates.add(dt);
    }

    if (fallbackDates.isNotEmpty) {
      fallbackDates.sort();
      return fallbackDates.last;
    }

    return null;
  }

  static DateTime? _parseFlexibleDate(String raw) {
    final norm = _normalizeAscii(raw);
    final br = RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])[/.\-](0?[1-9]|1[0-2])[/.\-](20\d{2})\b',
    ).firstMatch(norm);
    if (br != null) {
      return _tryBuildUtcDate(
        int.parse(br.group(3)!),
        int.parse(br.group(2)!),
        int.parse(br.group(1)!),
      );
    }

    final iso = RegExp(
      r'\b(20\d{2})[/.\-](0[1-9]|1[0-2])[/.\-](0[1-9]|[12]\d|3[01])\b',
    ).firstMatch(norm);
    if (iso != null) {
      return _tryBuildUtcDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final written = RegExp(
      r'\b([0-3]?\d)\s+de\s+(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+(20\d{2})\b',
    ).firstMatch(norm);
    if (written != null) {
      return _tryBuildUtcDate(
        int.parse(written.group(3)!),
        _ptMonths[written.group(2)!] ?? 0,
        int.parse(written.group(1)!),
      );
    }

    final compact = RegExp(r'^(0[1-9]|[12]\d|3[01])(0[1-9]|1[0-2])(20\d{2})$')
        .firstMatch(norm);
    if (compact != null) {
      return _tryBuildUtcDate(
        int.parse(compact.group(3)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(1)!),
      );
    }
    return null;
  }

  static DateTime? _tryBuildUtcDate(int year, int month, int day) {
    if (year < 2000 || year > 2099 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final dt = DateTime.utc(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    return dt;
  }

  static String? _extractValidationCodeFromText(String text) {
    if (text.isEmpty) return null;

    // 1. Padrões rotulados oficiais PF (validação / autenticação / controle / autenticidade / chave)
    final labeled = RegExp(
      r'(?:c[oó]digo\s+(?:de\s+)?(?:valida[cç][aã]o|autentica[cç][aã]o|controle|autenticidade|verificador)|chave\s+de\s+(?:valida[cç][aã]o|autentica[cç][aã]o)|autenticidade(?:\s+eletr[oô]nica)?)(?:\s+(?:eletr[oô]nica|da\s+certid[aã]o))?\s*[:\-]\s*([A-Za-z0-9][A-Za-z0-9.\-/]{3,36})',
      caseSensitive: false,
    );
    for (final m in labeled.allMatches(text)) {
      final token = m.group(1)!.replaceAll(RegExp(r'[.,;:\-]+$'), '').trim();
      if (_looksLikeValidationCodeToken(token)) {
        return token;
      }
    }

    // Também aceita rótulo sem `:` quando seguido imediatamente por token típico de código
    final looseLabeled = RegExp(
      r'(?:c[oó]digo\s+(?:de\s+)?(?:valida[cç][aã]o|autentica[cç][aã]o|controle|autenticidade))\s+([A-Za-z0-9]{4}(?:[.\-][A-Za-z0-9]{2,8}){1,4}|[A-Za-z0-9]{6,24})',
      caseSensitive: false,
    );
    for (final m in looseLabeled.allMatches(text)) {
      final token = m.group(1)!.replaceAll(RegExp(r'[.,;:\-]+$'), '').trim();
      if (_looksLikeValidationCodeToken(token)) {
        return token;
      }
    }

    // 2. Códigos agrupados em blocos de 4 caracteres com pontos ou hífens (ex.: ABCD.1234.EF56.7890)
    final grouped = RegExp(
      r'\b([A-Za-z0-9]{4}(?:[.\-][A-Za-z0-9]{4}){2,4})\b',
    );
    for (final m in grouped.allMatches(text)) {
      final token = m.group(1)!.trim();
      if (_looksLikeValidationCodeToken(token) && !_isFormattedCpf(token)) {
        return token.toUpperCase();
      }
    }

    return null;
  }

  static String? _extractHolderNameFromText(String text) {
    if (text.isEmpty) return null;
    final norm = _normalizeAscii(text);
    final m = RegExp(
      r'(?:em\s+nome\s+de|nome(?:\s+completo)?\s*:)\s*([a-z\s]{5,90}?)(?:,|\bcpf\b|\bnascid|\bfilh|\brg\b|\bportador|\bcidadao|\bdad[oa]s|\bemiti|$)',
    ).firstMatch(norm);
    final candidate = m?.group(1)?.trim();
    if (candidate != null && _normalizeCivilTokens(candidate).length >= 2) {
      return candidate.toUpperCase();
    }
    return null;
  }

  static String? _extractFirstValidCpfFromText(String text) {
    if (text.isEmpty) return null;
    for (final m in RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}[\-.]?\d{2}\b').allMatches(text)) {
      final d = DocumentOcrAndLivenessService.digitsOnly(m.group(0)!);
      if (d.length == 11 && DocumentOcrAndLivenessService.isValidCpfMod11(d)) {
        return d;
      }
    }
    return null;
  }

  // ===========================================================================
  // Descompactador Pure-Dart RFC 1950 (Zlib) / RFC 1951 (DEFLATE) para streams
  // `FlateDecode` de PDFs oficiais da Polícia Federal (100% Web-safe, sem dart:io)
  // ===========================================================================
  static Uint8List? _tryInflateZlibOrDeflate(Uint8List input) {
    if (input.length < 2) return null;
    // Verifica wrapper Zlib (RFC 1950): CM=8 (Deflate), CINFO<=7, (CMF*256 + FLG) % 31 == 0
    final cmf = input[0];
    final flg = input[1];
    if ((cmf & 0x0F) == 8 && (cmf >> 4) <= 7 && ((cmf << 8) + flg) % 31 == 0) {
      final fdict = (flg & 0x20) != 0;
      final startOffset = fdict ? 6 : 2;
      if (startOffset < input.length) {
        final inflated = _inflateDeflateStream(input, startOffset);
        if (inflated != null && inflated.isNotEmpty) return inflated;
      }
    }
    return _inflateDeflateStream(input, 0);
  }

  static Uint8List? _inflateDeflateStream(Uint8List src, int startByte) {
    const maxOutputBytes = 2 * 1024 * 1024; // Limite anti-zip-bomb de 2 MiB por stream
    try {
      final br = _BitReader(src, startByte);
      final out = BytesBuilder(copy: false);
      int totalOut = 0;
      final window = Uint8List(32768);
      int winPos = 0;

      void emitByte(int b) {
        final v = b & 0xFF;
        out.addByte(v);
        window[winPos] = v;
        winPos = (winPos + 1) & 0x7FFF;
        totalOut++;
        if (totalOut > maxOutputBytes) {
          throw const FormatException('Stream excede limite seguro.');
        }
      }

      bool isFinal = false;
      while (!isFinal) {
        isFinal = br.readBits(1) == 1;
        final btype = br.readBits(2);
        if (btype == 0) {
          br.alignToByte();
          final len = br.readBits(16);
          final nlen = br.readBits(16);
          if ((len ^ 0xFFFF) != nlen) return null;
          for (int i = 0; i < len; i++) {
            emitByte(br.readBits(8));
          }
        } else if (btype == 1 || btype == 2) {
          final _HuffmanTable litLenTable;
          final _HuffmanTable distTable;
          if (btype == 1) {
            litLenTable = _HuffmanTable.fixedLitLen;
            distTable = _HuffmanTable.fixedDist;
          } else {
            final hlit = br.readBits(5) + 257;
            final hdist = br.readBits(5) + 1;
            final hclen = br.readBits(4) + 4;
            const clOrder = <int>[
              16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
            ];
            final clLengths = List<int>.filled(19, 0);
            for (int i = 0; i < hclen; i++) {
              clLengths[clOrder[i]] = br.readBits(3);
            }
            final clTable = _HuffmanTable.fromLengths(clLengths);
            final allLengths = <int>[];
            final totalCodes = hlit + hdist;
            while (allLengths.length < totalCodes) {
              final sym = clTable.decode(br);
              if (sym < 16) {
                allLengths.add(sym);
              } else if (sym == 16) {
                if (allLengths.isEmpty) return null;
                final prev = allLengths.last;
                final rep = br.readBits(2) + 3;
                for (int r = 0; r < rep; r++) {
                  allLengths.add(prev);
                }
              } else if (sym == 17) {
                final rep = br.readBits(3) + 3;
                for (int r = 0; r < rep; r++) {
                  allLengths.add(0);
                }
              } else if (sym == 18) {
                final rep = br.readBits(7) + 11;
                for (int r = 0; r < rep; r++) {
                  allLengths.add(0);
                }
              } else {
                return null;
              }
            }
            litLenTable = _HuffmanTable.fromLengths(allLengths.sublist(0, hlit));
            distTable = _HuffmanTable.fromLengths(allLengths.sublist(hlit, totalCodes));
          }

          const lenBase = <int>[
            3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
            35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
          ];
          const lenExtra = <int>[
            0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
            3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
          ];
          const distBase = <int>[
            1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
            257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
          ];
          const distExtra = <int>[
            0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
            7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
          ];

          while (true) {
            final sym = litLenTable.decode(br);
            if (sym < 256) {
              emitByte(sym);
            } else if (sym == 256) {
              break;
            } else {
              final lenIdx = sym - 257;
              if (lenIdx < 0 || lenIdx >= lenBase.length) return null;
              final length = lenBase[lenIdx] + br.readBits(lenExtra[lenIdx]);
              final distSym = distTable.decode(br);
              if (distSym < 0 || distSym >= distBase.length) return null;
              final distance = distBase[distSym] + br.readBits(distExtra[distSym]);
              if (distance <= 0 || distance > totalOut) return null;
              for (int k = 0; k < length; k++) {
                final b = window[(winPos - distance) & 0x7FFF];
                emitByte(b);
              }
            }
          }
        } else {
          return null;
        }
      }
      return out.takeBytes();
    } catch (_) {
      return null;
    }
  }
}

class _BitReader {
  _BitReader(this.bytes, this.bytePos);

  final Uint8List bytes;
  int bytePos;
  int bitBuf = 0;
  int bitCount = 0;

  int readBits(int n) {
    if (n == 0) return 0;
    while (bitCount < n) {
      if (bytePos >= bytes.length) {
        throw const FormatException('Fim prematuro do stream DEFLATE.');
      }
      bitBuf |= bytes[bytePos++] << bitCount;
      bitCount += 8;
    }
    final val = bitBuf & ((1 << n) - 1);
    bitBuf >>= n;
    bitCount -= n;
    return val;
  }

  void alignToByte() {
    bitBuf = 0;
    bitCount = 0;
  }
}

class _HuffmanTable {
  _HuffmanTable._(this._counts, this._symbols, this._maxBits);

  final List<int> _counts;
  final List<int> _symbols;
  final int _maxBits;

  static final _HuffmanTable fixedLitLen = fromLengths(
    List<int>.generate(
      288,
      (i) => i <= 143 ? 8 : (i <= 255 ? 9 : (i <= 279 ? 7 : 8)),
    ),
  );

  static final _HuffmanTable fixedDist = fromLengths(List<int>.filled(32, 5));

  static _HuffmanTable fromLengths(List<int> lengths) {
    var maxB = 0;
    for (final l in lengths) {
      if (l > maxB) maxB = l;
    }
    if (maxB == 0) {
      return _HuffmanTable._(const <int>[0], const <int>[], 0);
    }
    final counts = List<int>.filled(maxB + 1, 0);
    for (final l in lengths) {
      if (l > 0) counts[l]++;
    }
    final offsets = List<int>.filled(maxB + 1, 0);
    int total = 0;
    for (int bits = 1; bits <= maxB; bits++) {
      offsets[bits] = total;
      total += counts[bits];
    }
    final symbols = List<int>.filled(total, 0);
    for (int sym = 0; sym < lengths.length; sym++) {
      final l = lengths[sym];
      if (l > 0) {
        symbols[offsets[l]++] = sym;
      }
    }
    return _HuffmanTable._(counts, symbols, maxB);
  }

  int decode(_BitReader br) {
    int code = 0;
    int first = 0;
    int index = 0;
    for (int len = 1; len <= _maxBits; len++) {
      code |= br.readBits(1);
      final count = _counts[len];
      if (code - count < first) {
        return _symbols[index + (code - first)];
      }
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    throw const FormatException('Código Huffman inválido.');
  }
}

class _PdfParsedStream {
  const _PdfParsedStream({
    required this.decodedStream,
    required this.wasInflated,
    required this.objNum,
  });

  final String decodedStream;
  final bool wasInflated;
  final int? objNum;
}

class _PdfStreamHeaderInfo {
  const _PdfStreamHeaderInfo({
    required this.objNum,
    required this.isImage,
    required this.isObjStm,
    required this.firstOffset,
    required this.predictor,
    required this.columns,
    required this.colors,
    required this.bitsPerComponent,
  });

  final int? objNum;
  final bool isImage;
  final bool isObjStm;
  final int firstOffset;
  final int predictor;
  final int columns;
  final int colors;
  final int bitsPerComponent;
}

/// Decodificador Pure-Dart de tabelas `ToUnicode CMap` (`beginbfchar` / `beginbfrange`)
/// usado em PDFs reais emitidos por `servicos.pf.gov.br/epol-sinic-publico/` com fontes
/// `Identity-H` / `CIDFontType2`.
class _PdfToUnicodeCMap {
  final Map<int, Map<int, String>> _byHexLen = <int, Map<int, String>>{};

  bool get isNotEmpty => _byHexLen.values.any((m) => m.isNotEmpty);

  bool get hasSingleByteEntries =>
      (_byHexLen[2]?.isNotEmpty ?? false);

  void _put(int hexLen, int code, String unicode) {
    final map = _byHexLen.putIfAbsent(hexLen, () => <int, String>{});
    map[code] = unicode;
  }

  void mergeFrom(_PdfToUnicodeCMap other) {
    other._byHexLen.forEach((hexLen, entries) {
      final target = _byHexLen.putIfAbsent(hexLen, () => <int, String>{});
      entries.forEach((code, unicode) {
        target.putIfAbsent(code, () => unicode);
      });
    });
  }

  static _PdfToUnicodeCMap parse(String content) {
    final cmap = _PdfToUnicodeCMap();

    // 1. Seções `beginbfchar ... endbfchar`
    final bfCharBlockRe = RegExp(r'beginbfchar\b([\s\S]*?)endbfchar');
    final bfCharPairRe = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>');
    for (final block in bfCharBlockRe.allMatches(content)) {
      final body = block.group(1)!;
      for (final m in bfCharPairRe.allMatches(body)) {
        final srcHex = m.group(1)!.trim();
        final dstHex = m.group(2)!.trim();
        final srcCode = int.tryParse(srcHex, radix: 16);
        final decoded = _decodeUtf16BeHex(dstHex);
        if (srcCode != null && decoded.isNotEmpty) {
          final normHexLen = srcHex.length.isOdd ? srcHex.length + 1 : srcHex.length;
          cmap._put(normHexLen, srcCode, decoded);
        }
      }
    }

    // 2. Seções `beginbfrange ... endbfrange` (forma array e forma incremental)
    final bfRangeBlockRe = RegExp(r'beginbfrange\b([\s\S]*?)endbfrange');
    final bfRangeLineRe = RegExp(
      r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:\[([\s\S]*?)\]|<([0-9A-Fa-f]+)>)',
    );
    final hexTokenRe = RegExp(r'<([0-9A-Fa-f]+)>');
    for (final block in bfRangeBlockRe.allMatches(content)) {
      final body = block.group(1)!;
      for (final m in bfRangeLineRe.allMatches(body)) {
        final startHex = m.group(1)!.trim();
        final endHex = m.group(2)!.trim();
        final startCode = int.tryParse(startHex, radix: 16);
        final endCode = int.tryParse(endHex, radix: 16);
        if (startCode == null || endCode == null || endCode < startCode) continue;
        final count = math.min(endCode - startCode + 1, 2048);
        final normHexLen = startHex.length.isOdd ? startHex.length + 1 : startHex.length;

        final arrayPart = m.group(3);
        if (arrayPart != null) {
          final dstTokens = hexTokenRe
              .allMatches(arrayPart)
              .map((t) => t.group(1)!.trim())
              .toList(growable: false);
          for (int i = 0; i < count && i < dstTokens.length; i++) {
            final decoded = _decodeUtf16BeHex(dstTokens[i]);
            if (decoded.isNotEmpty) {
              cmap._put(normHexLen, startCode + i, decoded);
            }
          }
        } else {
          final dstStartHex = m.group(4)?.trim() ?? '';
          final baseUnits = _hexToUtf16CodeUnits(dstStartHex);
          if (baseUnits.isEmpty) continue;
          for (int i = 0; i < count; i++) {
            final units = List<int>.from(baseUnits);
            units[units.length - 1] = (units.last + i) & 0xFFFF;
            cmap._put(normHexLen, startCode + i, String.fromCharCodes(units));
          }
        }
      }
    }

    return cmap;
  }

  static List<int> _hexToUtf16CodeUnits(String rawHex) {
    final cleaned = rawHex.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return const <int>[];
    if (cleaned.length <= 2) {
      final v = int.tryParse(cleaned, radix: 16);
      return v == null ? const <int>[] : <int>[v];
    }
    final padded = cleaned.length % 4 == 0
        ? cleaned
        : cleaned.padLeft(((cleaned.length + 3) ~/ 4) * 4, '0');
    final units = <int>[];
    for (int i = 0; i + 4 <= padded.length; i += 4) {
      final u = int.tryParse(padded.substring(i, i + 4), radix: 16);
      if (u != null) units.add(u);
    }
    return units;
  }

  static String _decodeUtf16BeHex(String rawHex) {
    final units = _hexToUtf16CodeUnits(rawHex);
    if (units.isEmpty) return '';
    return String.fromCharCodes(units);
  }

  String? decodeHex(String hexRaw) {
    if (!isNotEmpty || hexRaw.isEmpty) return null;
    final padded = hexRaw.length.isOdd ? '${hexRaw}0' : hexRaw;
    final lengths = _byHexLen.keys.toList()..sort((a, b) => b.compareTo(a));

    final sb = StringBuffer();
    int pos = 0;
    int mappedTokens = 0;
    int totalTokens = 0;

    while (pos < padded.length) {
      bool matched = false;
      for (final hexLen in lengths) {
        if (pos + hexLen > padded.length) continue;
        final code = int.tryParse(padded.substring(pos, pos + hexLen), radix: 16);
        final mapped = code == null ? null : _byHexLen[hexLen]?[code];
        if (mapped != null) {
          sb.write(mapped);
          pos += hexLen;
          mappedTokens++;
          totalTokens++;
          matched = true;
          break;
        }
      }
      if (!matched) {
        // Avança pelo menor tamanho de código conhecido ou 2 chars hex
        final step = lengths.isNotEmpty && pos + lengths.last <= padded.length
            ? lengths.last
            : 2;
        final fallbackCode = int.tryParse(
          padded.substring(pos, math.min(padded.length, pos + step)),
          radix: 16,
        );
        if (fallbackCode != null && fallbackCode >= 0x20 && fallbackCode <= 0x7E) {
          sb.writeCharCode(fallbackCode);
        }
        pos += step;
        totalTokens++;
      }
    }

    if (totalTokens == 0 || mappedTokens == 0) return null;
    if (mappedTokens * 2 < totalTokens) return null;
    return sb.toString();
  }

  String? decodeBytes(List<int> bytes) {
    final singleMap = _byHexLen[2];
    if (singleMap == null || singleMap.isEmpty || bytes.isEmpty) return null;
    final sb = StringBuffer();
    int hits = 0;
    for (final b in bytes) {
      final mapped = singleMap[b & 0xFF];
      if (mapped != null) {
        sb.write(mapped);
        hits++;
      } else {
        sb.writeCharCode(b & 0xFF);
      }
    }
    if (hits == 0) return null;
    return sb.toString();
  }
}

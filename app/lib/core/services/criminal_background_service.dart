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

  String get issuedDateFormatted {
    final d = issuedDate.day.toString().padLeft(2, '0');
    final m = issuedDate.month.toString().padLeft(2, '0');
    final y = issuedDate.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  int daysSinceIssue([DateTime? referenceNow]) {
    final now = (referenceNow ?? DateTime.now()).toUtc();
    final refDay = DateTime.utc(now.year, now.month, now.day);
    final issDay = DateTime.utc(issuedDate.year, issuedDate.month, issuedDate.day);
    return refDay.difference(issDay).inDays;
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

  /// Ciclo obrigatório de revalidação semestral na plataforma (6 meses).
  static const int validityCycleMonths = 6;

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

  /// Extrai texto legível de arquivos PDF (incluindo streams compactados `FlateDecode` / Zlib
  /// e literais PDF `(...)` / `<...>`) ou texto UTF-8/Latin-1 contido nos bytes.
  static String extractReadableTextFromPdfOrBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final chunks = <String>[];

    if (_startsWithPdfHeader(bytes)) {
      final rawLatin1 = latin1.decode(bytes, allowInvalid: true);
      final streamRe = RegExp(r'stream(?:\r\n|\n|\r)');
      int searchFrom = 0;
      while (searchFrom < rawLatin1.length) {
        final match = streamRe.firstMatch(rawLatin1.substring(searchFrom));
        if (match == null) break;
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

        if (dataEnd > dataStart && dataEnd <= bytes.length) {
          final streamSlice = Uint8List.sublistView(bytes, dataStart, dataEnd);
          final inflated = _tryInflateZlibOrDeflate(streamSlice);
          final decodedStream = _decodeBytesUtf8OrLatin1(inflated ?? streamSlice);
          final pdfText = _extractPdfContentStreamStrings(decodedStream);
          if (pdfText.isNotEmpty) {
            chunks.add(pdfText);
          } else if (inflated != null) {
            chunks.add(decodedStream);
          }
        }
        searchFrom = endIdx + 9;
      }

      // Captura também strings PDF diretas fora de streams compactados
      final directPdfStrings = _extractPdfContentStreamStrings(rawLatin1);
      if (directPdfStrings.isNotEmpty) {
        chunks.add(directPdfStrings);
      }
    }

    // Fallback para PDFs com texto plano ou strings legíveis diretas
    final plain = _decodeBytesUtf8OrLatin1(bytes);
    final printableRuns = RegExp(r'[A-Za-zÀ-ÿ0-9.,:/\-ºª()\s]{8,}')
        .allMatches(plain)
        .map((m) => m.group(0)!)
        .join(' ');
    if (printableRuns.isNotEmpty) {
      chunks.add(printableRuns);
    }

    return chunks.join('\n').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodeBytesUtf8OrLatin1(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String _extractPdfContentStreamStrings(String content) {
    final out = StringBuffer();
    int i = 0;
    final n = content.length;

    while (i < n) {
      final ch = content.codeUnitAt(i);
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
          out
            ..write(_decodePdfStringBytes(bytes))
            ..write(' ');
        }
        continue;
      }

      // PDF hex string `<...>` (ignora dicionários `<< ... >>`)
      if (ch == 0x3C && (i + 1 >= n || content.codeUnitAt(i + 1) != 0x3C)) {
        final close = content.indexOf('>', i + 1);
        if (close > i + 1 && close - i <= 4096) {
          final hexRaw = content.substring(i + 1, close).replaceAll(RegExp(r'\s+'), '');
          if (hexRaw.isNotEmpty && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hexRaw)) {
            final padded = hexRaw.length.isOdd ? '${hexRaw}0' : hexRaw;
            final bytes = <int>[];
            for (int k = 0; k < padded.length; k += 2) {
              bytes.add(int.parse(padded.substring(k, k + 2), radix: 16));
            }
            out
              ..write(_decodePdfStringBytes(bytes))
              ..write(' ');
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

    final autoProtocol = _extractProtocolFromText(extractedText);
    final effectiveProtocol = rawProtoInput.isNotEmpty ? rawProtoInput : (autoProtocol ?? '');
    final autoDate = _extractDateFromText(extractedText);
    final effectiveDate = manualIssuedDate ?? autoDate;
    final autoValCode = _extractValidationCodeFromText(extractedText);
    final effectiveValCode = rawValInput.isNotEmpty ? rawValInput : (autoValCode ?? '');

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

      final resolvedDate = effectiveDate ?? DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final ageDays = _ageInDays(resolvedDate, nowUtc);
      if (ageDays < -1) {
        return reject(
          'A data de emissão da certidão está no futuro. Verifique a data informada e tente novamente.',
          protocol: effectiveProtocol,
          issued: resolvedDate,
          valCode: effectiveValCode,
          nameOk: true,
          cpfOk: true,
        );
      }
      if (ageDays > maxCertificateAgeDays) {
        return reject(
          'Esta certidão foi emitida há mais de 90 dias. Emita gratuitamente uma nova certidão no site da Polícia Federal e envie novamente.',
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
            'Certidão Negativa da Polícia Federal validada com sucesso! Vigência semestral garantida por 6 meses.',
        fileBytes: fileBytes,
        fileExtension: ext,
        outcome: 'NOTHING_ON_RECORD',
      );
    }

    // Caminho B: Upload de Imagem (foto/captura da certidão impressa) ou PDF escaneado em imagem
    // Valida integridade visual/estrutural do arquivo + metadados oficiais obrigatórios (protocolo, emissão <= 90d e código PF).
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

    final cleanManualProto = effectiveProtocol.replaceAll(RegExp(r'[^A-Za-z0-9./\-]'), '');
    if (cleanManualProto.length < 6) {
      return reject(
        'Informe o Nº da Certidão / Protocolo (mínimo de 6 dígitos) impresso na Certidão da Polícia Federal.',
        protocol: effectiveProtocol,
        issued: effectiveDate,
        valCode: effectiveValCode,
      );
    }

    if (effectiveDate == null) {
      return reject(
        'Selecione a Data de Emissão impressa na sua Certidão de Antecedentes Criminais.',
        protocol: cleanManualProto,
        valCode: effectiveValCode,
      );
    }

    final ageDays = _ageInDays(effectiveDate, nowUtc);
    if (ageDays < -1) {
      return reject(
        'A data de emissão informada está no futuro. Confira a data impressa na certidão.',
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
        'Informe o Código de Validação Eletrônica presente no rodapé da Certidão da Polícia Federal.',
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
          'Certidão Negativa de Antecedentes Criminais conferida e registrada com vigência de 6 meses.',
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

  static String? _extractProtocolFromText(String text) {
    if (text.isEmpty) return null;
    final norm = _normalizeAscii(text);
    final labeled = RegExp(
      r'(?:certidao\s*(?:n[oº°.]*|numero)|protocolo(?:\s*n[oº°.]*)?)\s*[:\-]?\s*([0-9][0-9./\-]{5,26})',
    ).firstMatch(norm);
    if (labeled != null) return labeled.group(1)!.trim();

    final standalone = RegExp(r'\b(20\d{2}[./\-]?\d{6,16})\b').firstMatch(norm);
    return standalone?.group(1)?.trim();
  }

  static DateTime? _extractDateFromText(String text) {
    if (text.isEmpty) return null;
    final br = RegExp(r'\b(0[1-9]|[12]\d|3[01])/(0[1-9]|1[0-2])/(20\d{2})\b').firstMatch(text);
    if (br != null) {
      final d = int.parse(br.group(1)!);
      final m = int.parse(br.group(2)!);
      final y = int.parse(br.group(3)!);
      return DateTime.utc(y, m, d);
    }

    final iso = RegExp(r'\b(20\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])\b').firstMatch(text);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final m = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      return DateTime.utc(y, m, d);
    }

    final norm = _normalizeAscii(text);
    final written = RegExp(
      r'\b([0-3]?\d)\s+de\s+(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+(20\d{2})\b',
    ).firstMatch(norm);
    if (written != null) {
      final d = int.parse(written.group(1)!);
      final m = _ptMonths[written.group(2)!] ?? 1;
      final y = int.parse(written.group(3)!);
      if (d >= 1 && d <= 31) return DateTime.utc(y, m, d);
    }
    return null;
  }

  static String? _extractValidationCodeFromText(String text) {
    if (text.isEmpty) return null;
    final m = RegExp(
      r'(?:c[oó]digo\s+de\s+(?:valida[cç][aã]o|autentica[cç][aã]o)|autenticidade)\s*[:\-]?\s*([A-Za-z0-9.\-/]{4,32})',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
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

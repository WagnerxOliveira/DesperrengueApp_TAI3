import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_ocr_and_liveness_service.dart';
import 'document_real_ocr_engine_stub.dart'
    if (dart.library.io) 'document_real_ocr_engine_mobile.dart' as platform_ocr;
import 'ocr_text_geometry.dart';

export 'ocr_text_geometry.dart';

/// Resultado bruto retornado pela leitura óptica (ML Kit on-device, override de teste ou Edge).
class RawDocumentOcrExtraction {
  const RawDocumentOcrExtraction({
    required this.frontText,
    required this.backText,
    required this.qrPayloads,
    required this.frontRotationDegrees,
    required this.backRotationDegrees,
    required this.sourceEngine,
    this.frontLines = const <OcrTextLineBox>[],
    this.backLines = const <OcrTextLineBox>[],
  });

  final String frontText;
  final String backText;
  final List<String> qrPayloads;
  final int frontRotationDegrees;
  final int backRotationDegrees;
  final String sourceEngine;
  final List<OcrTextLineBox> frontLines;
  final List<OcrTextLineBox> backLines;

  bool get hasAnyText =>
      frontText.trim().isNotEmpty ||
      backText.trim().isNotEmpty ||
      qrPayloads.isNotEmpty;
}

/// Dados estruturados extraídos de forma honesta e determinística de documentos
/// oficiais brasileiros (CNH clássica, CNH 2022+, CIN, RG e Comprovante CPF).
///
/// Nenhum campo civil (nome, CPF, data de nascimento) é inventado quando não lido do documento real.
class ParsedBrazilianDocumentOcr {
  const ParsedBrazilianDocumentOcr({
    required this.detectedDocumentType,
    required this.fullName,
    required this.cpfDigits,
    required this.documentNumber,
    required this.birthDate,
    required this.issuingAuthority,
    required this.renach,
    required this.cnhSecurityCode11,
    required this.mrzLines,
    required this.mrzChecksumValid,
    required this.mrzOrQrPresent,
    required this.qrCodeDetected,
    required this.qrCodeRawPayload,
    required this.officialHeaderDetected,
    required this.estimatedConfidence,
    required this.rawFrontText,
    required this.rawBackText,
    this.birthDateConfidence = 0.0,
    this.sourceEngine = 'mlkit_on_device',
    this.detectedRotationDegrees = 0,
  });

  final OfficialDocumentType detectedDocumentType;
  final String? fullName;
  final String? cpfDigits;
  final String? documentNumber;
  final DateTime? birthDate;
  final double birthDateConfidence;
  final String? issuingAuthority;
  final String? renach;
  final String? cnhSecurityCode11;
  final List<String> mrzLines;
  final bool mrzChecksumValid;
  final bool mrzOrQrPresent;
  final bool qrCodeDetected;
  final String? qrCodeRawPayload;
  final bool officialHeaderDetected;
  final double estimatedConfidence;
  final String rawFrontText;
  final String rawBackText;
  final String sourceEngine;
  final int detectedRotationDegrees;

  /// `true` somente quando o OCR extraiu de fato um Nome Civil válido e um CPF válido Mod-11.
  bool get hasRequiredIdentityFields =>
      fullName != null &&
      DocumentOcrAndLivenessService.isValidCivilFullName(fullName!) &&
      cpfDigits != null &&
      DocumentOcrAndLivenessService.isValidCpfMod11(cpfDigits!);

  /// `true` quando todos os campos críticos (incluindo Data de Nascimento confiável
  /// em CNH/CIN/RG) foram lidos sem necessidade de escalonamento para Vision AI em nuvem.
  bool get hasHighConfidenceCoreFields {
    if (!hasRequiredIdentityFields) return false;
    if (detectedDocumentType == OfficialDocumentType.cpf) return true;
    return birthDate != null && birthDateConfidence >= 0.85;
  }

  /// Verifica se os códigos de segurança (MRZ/QR/RENACH/Cód. Segurança) estão íntegros.
  /// Se linhas completas de MRZ foram detectadas com dígito verificador adulterado, retorna `false`.
  bool get securityCodesIntegrityOk {
    if (mrzLines.length == 3 || mrzLines.length == 2) {
      return mrzChecksumValid;
    }
    if (mrzOrQrPresent || qrCodeDetected) {
      return true;
    }
    if (renach != null &&
        DocumentOcrAndLivenessService.isValidCnhRenach(renach!)) {
      return true;
    }
    if (cnhSecurityCode11 != null &&
        DocumentOcrAndLivenessService.isValidCnhSecurityCode11(
          cnhSecurityCode11!,
        )) {
      return true;
    }
    // RG estadual antigo e Comprovante CPF podem não conter MRZ/QR impresso.
    if (detectedDocumentType == OfficialDocumentType.rg ||
        detectedDocumentType == OfficialDocumentType.cpf) {
      return officialHeaderDetected && hasRequiredIdentityFields;
    }
    // CNH clássica/2022+ ou CIN sem QR/MRZ: ainda aceita se cabeçalho oficial + nº registro + identidade lidos.
    return officialHeaderDetected &&
        hasRequiredIdentityFields &&
        (documentNumber != null && documentNumber!.trim().length >= 5);
  }
}

/// Parser determinístico para documentos oficiais brasileiros (CNH clássica,
/// CNH 2022+, CIN, RG estadual e Comprovante CPF da Receita Federal).
class BrazilianDocumentOcrParser {
  BrazilianDocumentOcrParser._();

  static const Set<String> _ufCodes = <String>{
    'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
    'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
  };

  static const Set<String> _nonNameKeywords = <String>{
    'REPUBLICA',
    'FEDERATIVA',
    'BRASIL',
    'MINISTERIO',
    'INFRAESTRUTURA',
    'TRANSPORTES',
    'FAZENDA',
    'JUSTICA',
    'CARTEIRA',
    'NACIONAL',
    'HABILITACAO',
    'IDENTIDADE',
    'SECRETARIA',
    'SEGURANCA',
    'PUBLICA',
    'POLICIA',
    'CIVIL',
    'FEDERAL',
    'INSTITUTO',
    'IDENTIFICACAO',
    'CADASTRO',
    'PESSOAS',
    'FISICAS',
    'RECEITA',
    'COMPROVANTE',
    'INSCRICAO',
    'FILIACAO',
    'OBSERVACOES',
    'ASSINATURA',
    'PORTADOR',
    'TITULAR',
    'VALIDA',
    'TERRITORIO',
    'PROIBIDO',
    'PLASTIFICAR',
    'DETRAN',
    'SENATRAN',
    'DENATRAN',
    'SERPRO',
    'PERMISSAO',
    'CATEGORIA',
    'VALIDADE',
    'EMISSAO',
    'EXPEDICAO',
    'NASCIMENTO',
    'NATURALIDADE',
    'NACIONALIDADE',
    'REGISTRO',
    'GERAL',
    'ORGAO',
    'EXPEDIDOR',
    'EMISSOR',
    'CPF',
    'RENACH',
    'CODIGO',
    'DOCUMENTO',
    'NOME',
    'SOBRENOME',
    'DATA',
    'LOCAL',
    'PAI',
    'MAE',
    'ACC',
    'CAT',
    'HAB',
    'OBS',
    'DOC',
    'SITUACAO',
    'CADASTRAL',
    'REGULAR',
  };

  /// Interpreta texto OCR bruto da Frente, do Verso e eventuais payloads de QR Code.
  /// Nunca inventa Nome ou CPF quando ausentes no texto lido.
  static ParsedBrazilianDocumentOcr parse({
    required String frontText,
    required String backText,
    OfficialDocumentType? expectedDocumentType,
    List<String> qrPayloads = const <String>[],
    List<OcrTextLineBox> frontLines = const <OcrTextLineBox>[],
    List<OcrTextLineBox> backLines = const <OcrTextLineBox>[],
    String sourceEngine = 'mlkit_on_device',
    int detectedRotationDegrees = 0,
  }) {
    final String qrCombined = qrPayloads.join('\n').trim();
    final String combined = [
      frontText.trim(),
      backText.trim(),
      qrCombined,
    ].where((s) => s.isNotEmpty).join('\n');

    final String asciiUpper = _toAsciiUpper(combined);
    final OfficialDocumentType detectedType = _detectDocumentType(
      asciiUpper: asciiUpper,
      fallback: expectedDocumentType ?? OfficialDocumentType.cnh,
    );

    // 1. Extração e validação de linhas MRZ ICAO 9303 (TD1 3x30 / TD3 2x44)
    final List<String> mrzLines = _extractMrzLines(combined);
    final bool mrzValid = mrzLines.isNotEmpty
        ? DocumentOcrAndLivenessService.validateIcaoMrzLines(mrzLines)
        : false;
    final bool hasQr = qrPayloads.isNotEmpty ||
        asciiUpper.contains('SERPRO') ||
        asciiUpper.contains('VIO-QR') ||
        asciiUpper.contains('VIO.SERPRO') ||
        asciiUpper.contains('VALIDA.GOV.BR');
    final bool hasMrzMarker =
        mrzLines.isNotEmpty || asciiUpper.contains('IDBRA') || asciiUpper.contains('<<<');

    // 2. Cabeçalho oficial brasileiro
    final bool officialHeader = _hasOfficialBrazilianHeader(
      asciiUpper: asciiUpper,
      mrzValid: mrzValid,
      hasQr: hasQr,
    );

    // 3. CPF real (validado matematicamente Mod-11)
    final String? cpfDigits = _extractValidCpfMod11(
      frontText: frontText,
      backText: backText,
      qrText: qrCombined,
    );

    // 4. RENACH & Código de Segurança da CNH (11 dígitos)
    final String? renach = _extractRenach(asciiUpper);

    // 5. Número do documento / registro
    final String? docNumber = _extractDocumentNumber(
      combinedRaw: combined,
      asciiUpper: asciiUpper,
      docType: detectedType,
      cpfDigits: cpfDigits,
      mrzLines: mrzLines,
    );

    final String? cnhSecCode = _extractCnhSecurityCode(
      combinedRaw: combined,
      cpfDigits: cpfDigits,
      docNumber: docNumber,
    );

    // 6. Nome Civil Completo (Frente -> Verso -> MRZ TD1 linha 3)
    final String? fullName = _extractCivilFullName(
      frontText: frontText,
      backText: backText,
      mrzLines: mrzLines,
    );

    // 7. Data de Nascimento (5 camadas: MRZ/QR -> Âncora Espacial 2D -> Reparo OCR -> Rótulo -> Cronologia CNH)
    final ({DateTime? date, double confidence}) birthResult =
        _extractBirthDateWithConfidence(
      frontRaw: frontText,
      combinedRaw: combined,
      mrzLines: mrzLines,
      qrPayloads: qrPayloads,
      frontLines: frontLines,
      backLines: backLines,
      docType: detectedType,
    );
    final DateTime? birthDate = birthResult.date;
    final double birthDateConfidence = birthResult.confidence;

    // 8. Órgão Emissor / UF
    final String? issuingAuthority = _extractIssuingAuthority(
      combinedRaw: combined,
      asciiUpper: asciiUpper,
      docType: detectedType,
    );

    // 9. Confiança estimada honesta baseada nos campos realmente lidos
    double confidence = 0.0;
    if (officialHeader) confidence += 20.0;
    if (fullName != null) confidence += 28.0;
    if (cpfDigits != null) confidence += 28.0;
    if (docNumber != null) confidence += 8.0;
    if (birthDate != null) confidence += 7.0;
    if (issuingAuthority != null) confidence += 4.0;
    if (mrzValid || hasQr || renach != null || cnhSecCode != null) {
      confidence += 5.0;
    }
    confidence = confidence.clamp(0.0, 99.5);

    return ParsedBrazilianDocumentOcr(
      detectedDocumentType: detectedType,
      fullName: fullName,
      cpfDigits: cpfDigits,
      documentNumber: docNumber,
      birthDate: birthDate,
      birthDateConfidence: birthDateConfidence,
      issuingAuthority: issuingAuthority,
      renach: renach,
      cnhSecurityCode11: cnhSecCode,
      mrzLines: mrzLines,
      mrzChecksumValid: mrzValid,
      mrzOrQrPresent: hasMrzMarker || hasQr,
      qrCodeDetected: hasQr,
      qrCodeRawPayload: qrPayloads.isNotEmpty ? qrPayloads.first : null,
      officialHeaderDetected: officialHeader,
      estimatedConfidence: double.parse(confidence.toStringAsFixed(1)),
      rawFrontText: frontText,
      rawBackText: backText,
      sourceEngine: sourceEngine,
      detectedRotationDegrees: detectedRotationDegrees,
    );
  }

  static String _toAsciiUpper(String raw) {
    const Map<String, String> map = <String, String>{
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };
    final String upper = raw.toUpperCase();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < upper.length; i++) {
      final String ch = upper[i];
      out.write(map[ch] ?? ch);
    }
    return out.toString();
  }

  static OfficialDocumentType _detectDocumentType({
    required String asciiUpper,
    required OfficialDocumentType fallback,
  }) {
    if (asciiUpper.contains('CARTEIRA NACIONAL DE HABILITACAO') ||
        asciiUpper.contains('SENATRAN') ||
        asciiUpper.contains('DENATRAN') ||
        asciiUpper.contains('RENACH') ||
        asciiUpper.contains('CAT. HAB') ||
        asciiUpper.contains('PERMISSAO') && asciiUpper.contains('ACC')) {
      return OfficialDocumentType.cnh;
    }
    if (asciiUpper.contains('CARTEIRA DE IDENTIDADE NACIONAL') ||
        (asciiUpper.contains('IDENTIDADE NACIONAL') &&
            asciiUpper.contains('IDBRA'))) {
      return OfficialDocumentType.cin;
    }
    if (asciiUpper.contains('CADASTRO DE PESSOAS FISICAS') ||
        asciiUpper.contains('COMPROVANTE DE INSCRICAO NO CPF') ||
        asciiUpper.contains('RECEITA FEDERAL')) {
      return OfficialDocumentType.cpf;
    }
    if (asciiUpper.contains('CARTEIRA DE IDENTIDADE') ||
        asciiUpper.contains('REGISTRO GERAL') ||
        asciiUpper.contains('SECRETARIA DE SEGURANCA') ||
        asciiUpper.contains('INSTITUTO DE IDENTIFICACAO')) {
      return OfficialDocumentType.rg;
    }
    return fallback;
  }

  static bool _hasOfficialBrazilianHeader({
    required String asciiUpper,
    required bool mrzValid,
    required bool hasQr,
  }) {
    if (mrzValid) return true;
    const List<String> markers = <String>[
      'REPUBLICA FEDERATIVA DO BRASIL',
      'CARTEIRA NACIONAL DE HABILITACAO',
      'CARTEIRA DE IDENTIDADE',
      'SECRETARIA DE SEGURANCA',
      'INSTITUTO DE IDENTIFICACAO',
      'POLICIA CIVIL',
      'CADASTRO DE PESSOAS FISICAS',
      'COMPROVANTE DE INSCRICAO NO CPF',
      'RECEITA FEDERAL',
      'MINISTERIO DA FAZENDA',
      'MINISTERIO DA INFRAESTRUTURA',
      'MINISTERIO DOS TRANSPORTES',
      'SENATRAN',
      'DENATRAN',
      'DETRAN',
      'SERPRO',
      'GOV.BR',
      'REGISTRO GERAL',
      'VALIDA EM TODO O TERRITORIO NACIONAL',
    ];
    for (final m in markers) {
      if (asciiUpper.contains(m)) return true;
    }
    return hasQr && asciiUpper.contains('BRASIL');
  }

  static List<String> _extractMrzLines(String rawText) {
    final List<String> rawLines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map(
          (l) => _toAsciiUpper(l)
              .replaceAll('«', '<<')
              .replaceAll(' ', '')
              .replaceAll(RegExp(r'[^A-Z0-9<]'), ''),
        )
        .where((l) => l.length >= 26)
        .toList(growable: false);

    // Procura 3 linhas consecutivas TD1 (30 chars, iniciando com IDBRA/I<BRA/C<BRA)
    for (int i = 0; i <= rawLines.length - 3; i++) {
      final String l1 = rawLines[i];
      final String l2 = rawLines[i + 1];
      final String l3 = rawLines[i + 2];
      if ((l1.startsWith('IDBRA') ||
              l1.startsWith('I<BRA') ||
              l1.startsWith('C<BRA')) &&
          l1.length == 30 &&
          l2.length == 30 &&
          l3.length == 30) {
        return <String>[l1, l2, l3];
      }
    }

    // Procura 2 linhas consecutivas TD3 (44 chars, passaporte)
    for (int i = 0; i <= rawLines.length - 2; i++) {
      final String l1 = rawLines[i];
      final String l2 = rawLines[i + 1];
      if (l1.startsWith('P<BRA') && l1.length == 44 && l2.length == 44) {
        return <String>[l1, l2];
      }
    }

    return const <String>[];
  }

  static String? _extractValidCpfMod11({
    required String frontText,
    required String backText,
    required String qrText,
  }) {
    final List<String> sources = <String>[frontText, backText, qrText];
    final RegExp cpfLabeled = RegExp(
      r'(?:4D\s*)?CPF[^\d\n]{0,18}(\d{3}\.?\d{3}\.?\d{3}[\-\s]?\d{2})',
      caseSensitive: false,
    );
    final RegExp cpfNextLine = RegExp(
      r'(?:^|\n)\s*(?:4D\s*)?CPF\s*[:\-]?\s*\n\s*(\d{3}\.?\d{3}\.?\d{3}[\-\s]?\d{2})',
      caseSensitive: false,
    );
    final RegExp cpfFormatted = RegExp(r'\b(\d{3}\.\d{3}\.\d{3}-\d{2})\b');
    final RegExp cpfAny11 = RegExp(r'(?<!\d)(\d{3}\.?\d{3}\.?\d{3}[\-\s]?\d{2})(?!\d)');

    // 1. Prioridade máxima: explicitamente rotulado com CPF ou 4d CPF
    for (final src in sources) {
      if (src.trim().isEmpty) continue;
      for (final regex in <RegExp>[cpfLabeled, cpfNextLine]) {
        for (final m in regex.allMatches(src)) {
          final String d = DocumentOcrAndLivenessService.digitsOnly(m.group(1) ?? '');
          if (DocumentOcrAndLivenessService.isValidCpfMod11(d)) {
            return d;
          }
        }
      }
    }

    // 2. Segunda prioridade: CPF formatado `###.###.###-##`
    for (final src in sources) {
      if (src.trim().isEmpty) continue;
      for (final m in cpfFormatted.allMatches(src)) {
        final String d = DocumentOcrAndLivenessService.digitsOnly(m.group(1) ?? '');
        if (DocumentOcrAndLivenessService.isValidCpfMod11(d)) {
          return d;
        }
      }
    }

    // 3. Terceira prioridade: qualquer sequência de 11 dígitos válida Mod-11 fora de linhas de registro/segurança
    for (final src in sources) {
      if (src.trim().isEmpty) continue;
      for (final rawLine in src.split(RegExp(r'[\r\n]+'))) {
        final String up = _toAsciiUpper(rawLine);
        if (up.contains('REGISTRO') && !up.contains('CPF')) continue;
        if (up.contains('SEGURANCA') && !up.contains('CPF')) continue;
        for (final m in cpfAny11.allMatches(rawLine)) {
          final String d = DocumentOcrAndLivenessService.digitsOnly(m.group(1) ?? '');
          if (DocumentOcrAndLivenessService.isValidCpfMod11(d)) {
            return d;
          }
        }
      }
    }

    return null;
  }

  static String? _extractRenach(String asciiUpper) {
    final RegExp renachRegex = RegExp(r'\b([A-Z]{2}\d{9})\b');
    for (final m in renachRegex.allMatches(asciiUpper)) {
      final String candidate = m.group(1)!;
      if (DocumentOcrAndLivenessService.isValidCnhRenach(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static String? _extractDocumentNumber({
    required String combinedRaw,
    required String asciiUpper,
    required OfficialDocumentType docType,
    required String? cpfDigits,
    required List<String> mrzLines,
  }) {
    if (docType == OfficialDocumentType.cpf && cpfDigits != null) {
      return DocumentOcrAndLivenessService.formatCpf(cpfDigits);
    }

    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r'(?:N[º°O.]?\s*REGISTRO|5\s*N?[º°O.]?\s*REGISTRO|REGISTRO)\s*[:\-]?\s*([0-9]{9,12})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:RG|REGISTRO\s+GERAL|DOC\.?\s*IDENTIDADE|4C\s*DOC\.?\s*IDENTIDADE|CNH|DOC)\s*[:\-]\s*([0-9A-Z.\-]{5,18})',
        caseSensitive: false,
      ),
    ];

    for (final regex in patterns) {
      for (final m in regex.allMatches(combinedRaw)) {
        final String candidate = (m.group(1) ?? '').trim();
        final String digits = DocumentOcrAndLivenessService.digitsOnly(candidate);
        if (candidate.length >= 5 &&
            digits.length >= 5 &&
            (cpfDigits == null || digits != cpfDigits)) {
          return candidate;
        }
      }
    }

    // Checa linha seguinte após rótulo "Nº REGISTRO" ou "REGISTRO GERAL"
    final List<String> lines = combinedRaw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    for (int i = 0; i < lines.length - 1; i++) {
      final String up = _toAsciiUpper(lines[i]);
      if (up.contains('REGISTRO') ||
          up == 'RG' ||
          up.contains('DOC. IDENTIDADE') ||
          up.contains('DOC IDENTIDADE')) {
        final RegExpMatch? numMatch =
            RegExp(r'\b([0-9][0-9A-Z.\-]{4,16})\b').firstMatch(lines[i + 1]);
        if (numMatch != null) {
          final String cand = numMatch.group(1)!;
          final String d = DocumentOcrAndLivenessService.digitsOnly(cand);
          if (d.length >= 5 && (cpfDigits == null || d != cpfDigits)) {
            return cand;
          }
        }
      }
    }

    // Fallback via MRZ TD1 linha 1 (pos 5..14)
    if (mrzLines.length == 3 && mrzLines[0].length == 30) {
      final String mrzDoc = mrzLines[0].substring(5, 14).replaceAll('<', '').trim();
      if (mrzDoc.length >= 5) return mrzDoc;
    }

    // Na CIN, o número oficial de identificação nacional é o próprio CPF
    if (docType == OfficialDocumentType.cin && cpfDigits != null) {
      return DocumentOcrAndLivenessService.formatCpf(cpfDigits);
    }

    return null;
  }

  static String? _extractCnhSecurityCode({
    required String combinedRaw,
    required String? cpfDigits,
    required String? docNumber,
  }) {
    final String docDigits =
        docNumber != null ? DocumentOcrAndLivenessService.digitsOnly(docNumber) : '';
    final RegExp labeled = RegExp(
      r'(?:SEGURAN[CÇ]A|C[ÓO]D(?:IGO)?\.?\s*(?:DE\s*)?SEG)\s*[:\-]?\s*(\d{11})',
      caseSensitive: false,
    );
    final RegExpMatch? m = labeled.firstMatch(combinedRaw);
    if (m != null) {
      final String cand = m.group(1)!;
      if (cand != cpfDigits &&
          cand != docDigits &&
          DocumentOcrAndLivenessService.isValidCnhSecurityCode11(cand)) {
        return cand;
      }
    }
    return null;
  }

  static String? _extractCivilFullName({
    required String frontText,
    required String backText,
    required List<String> mrzLines,
  }) {
    final List<String> sources = <String>[frontText, backText];

    // 1. Mesmo linha: "NOME: FULANO DE TAL", "2 e 1 NOME E SOBRENOME: FULANO DE TAL"
    final RegExp sameLine = RegExp(
      r'(?:^|\n)\s*(?:2\s*E\s*1\s*)?NOME(?:\s+E\s+SOBRENOME|\s+COMPLETO|\s+CIVIL)?\s*[:\-]\s*([A-ZÀ-Ÿa-zà-ÿ\s]{5,80})',
      caseSensitive: false,
    );
    for (final src in sources) {
      for (final m in sameLine.allMatches(src)) {
        final String cand = _cleanNameCandidate(m.group(1) ?? '');
        if (_isPlausibleCivilName(cand)) {
          return cand;
        }
      }
    }

    // 2. Próxima linha após rótulo "NOME" / "2 e 1 NOME E SOBRENOME"
    for (final src in sources) {
      final List<String> lines = src
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);

      String? cnh2022Surname;
      String? cnh2022Given;

      for (int i = 0; i < lines.length; i++) {
        final String up = _toAsciiUpper(lines[i]);

        // CNH 2022+ campos separados "1 SOBRENOME" e "2 NOME"
        if (RegExp(r'^1\s*\.?\s*SOBRENOME\b').hasMatch(up) && i + 1 < lines.length) {
          final String s = _cleanNameCandidate(lines[i + 1]);
          if (s.length >= 2 && !_containsNonNameKeyword(s)) {
            cnh2022Surname = s;
          }
        }
        if (RegExp(r'^2\s*\.?\s*NOME\b').hasMatch(up) &&
            !up.contains('SOBRENOME') &&
            i + 1 < lines.length) {
          final String g = _cleanNameCandidate(lines[i + 1]);
          if (g.length >= 2 && !_containsNonNameKeyword(g)) {
            cnh2022Given = g;
          }
        }

        final bool isNameLabel =
            RegExp(r'^(?:2\s*E\s*1\s*)?NOME(?:\s+E\s+SOBRENOME|\s+COMPLETO|\s+CIVIL)?\s*[:\-]?$')
                .hasMatch(up);
        if (isNameLabel && i + 1 < lines.length) {
          final String cand = _cleanNameCandidate(lines[i + 1]);
          if (_isPlausibleCivilName(cand)) {
            return cand;
          }
        }
      }

      if (cnh2022Given != null && cnh2022Surname != null) {
        final String merged = '$cnh2022Given $cnh2022Surname'.trim();
        if (_isPlausibleCivilName(merged)) {
          return merged;
        }
      }
    }

    // 3. Fallback via MRZ TD1 linha 3 ("CLAUDIANO<<WAGNER<OLIVEIRA<<<<")
    if (mrzLines.length == 3 && mrzLines[2].contains('<<')) {
      final List<String> parts = mrzLines[2].split('<<');
      if (parts.length >= 2) {
        final String surname = parts[0].replaceAll('<', ' ').trim();
        final String given = parts[1].replaceAll('<', ' ').trim();
        final String reconstructed =
            '$given $surname'.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (_isPlausibleCivilName(reconstructed)) {
          return reconstructed;
        }
      }
    }

    return null;
  }

  static String _cleanNameCandidate(String raw) {
    final String firstLine = raw.split(RegExp(r'[\r\n]')).first;
    final String stripped = firstLine
        .replaceAll(RegExp(r"[^A-Za-zÀ-ÿ\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    return stripped;
  }

  static bool _containsNonNameKeyword(String cleanUpper) {
    final List<String> tokens = _toAsciiUpper(cleanUpper)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return true;
    int badHits = 0;
    for (final t in tokens) {
      if (_nonNameKeywords.contains(t)) badHits++;
    }
    return badHits > 0;
  }

  static bool _isPlausibleCivilName(String cleanUpper) {
    if (!DocumentOcrAndLivenessService.isValidCivilFullName(cleanUpper)) {
      return false;
    }
    if (RegExp(r'\d').hasMatch(cleanUpper)) return false;
    if (_containsNonNameKeyword(cleanUpper)) return false;
    final List<String> words = cleanUpper.split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 8) return false;
    return true;
  }

  /// Extração cirúrgica de Data de Nascimento em 5 prioridades com score de confiança:
  ///  1. MRZ ICAO 9303 TD1 (linha 2 com dígito verificador) ou payload estruturado de QR Code;
  ///  2. Âncora Espacial 2D (`frontLines` / `backLines` com `OcrTextLineBox`) — resolve o layout
  ///     tabular da CNH Clássica (`CPF` à esquerda, `DATA NASCIMENTO` à direita) e CNH 2022
  ///     (Campo `3 DATA, LOCAL E UF DE NASCIMENTO`) sem confundir com Emissão/Validade/1ª Hab.;
  ///  3. Reparo conservador de confusão óptica OCR (`O↔0`, `I/l↔1`, `S↔5`, `B↔8`, `Z↔2`, espaços);
  ///  4. Rótulo textual com janela tolerante (excluindo rótulos de validade/emissão/1ª hab.);
  ///  5. Desambiguação cronológica forense da CNH ($D_{\text{nasc}} \le D_{\text{1hab}} - 17.5\text{a} < D_{\text{val}}$).
  static ({DateTime? date, double confidence}) _extractBirthDateWithConfidence({
    required String frontRaw,
    required String combinedRaw,
    required List<String> mrzLines,
    required List<String> qrPayloads,
    required List<OcrTextLineBox> frontLines,
    required List<OcrTextLineBox> backLines,
    required OfficialDocumentType docType,
  }) {
    final int currentYear = DateTime.now().year;
    final int minAgeYears = docType == OfficialDocumentType.cnh ? 17 : 10;

    DateTime? parsePlausibleBirthDate(int? d, int? m, int? y) {
      if (d == null || m == null || y == null) return null;
      if (y < 1915 || y > currentYear - minAgeYears) return null;
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      try {
        final DateTime dt = DateTime.utc(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
      } catch (_) {}
      return null;
    }

    // Repara confusão clássica de OCR dentro de tokens numéricos de data.
    String repairDateDigits(String raw) {
      final StringBuffer out = StringBuffer();
      for (int i = 0; i < raw.length; i++) {
        final String ch = raw[i];
        out.write(switch (ch) {
          'O' || 'o' || 'Q' || 'D' => '0',
          'I' || 'l' || '|' || '!' => '1',
          'Z' || 'z' => '2',
          'S' || 's' => '5',
          'B' => '8',
          'g' || 'q' => '9',
          _ => ch,
        });
      }
      return out.toString();
    }

    List<DateTime> extractAllValidDatesInText(
      String text, {
      required bool restrictToBirthAge,
    }) {
      final List<DateTime> found = <DateTime>[];
      final RegExp sepRe = RegExp(
        r'(?<![0-9A-Za-z])([0-9OoQDIl|!ZzSsBgq]{2})[/.\-\s]+([0-9OoQDIl|!ZzSsBgq]{2})[/.\-\s]+([0-9OoQDIl|!ZzSsBgq]{4})(?![0-9A-Za-z])',
      );
      for (final m in sepRe.allMatches(text)) {
        final int? d = int.tryParse(repairDateDigits(m.group(1)!));
        final int? mo = int.tryParse(repairDateDigits(m.group(2)!));
        final int? y = int.tryParse(repairDateDigits(m.group(3)!));
        if (d == null || mo == null || y == null) continue;
        if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;
        if (y < 1915 || y > currentYear + 20) continue;
        if (restrictToBirthAge && y > currentYear - minAgeYears) continue;
        try {
          final dt = DateTime.utc(y, mo, d);
          if (dt.year == y && dt.month == mo && dt.day == d && !found.contains(dt)) {
            found.add(dt);
          }
        } catch (_) {}
      }

      // Fallback para barras fundidas ao fundo guilloché (8 dígitos colados: DDMMAAAA)
      if (found.isEmpty) {
        final RegExp compactRe = RegExp(r'(?<!\d)(\d{2})(\d{2})((?:19|20)\d{2})(?!\d)');
        for (final m in compactRe.allMatches(text)) {
          final int? d = int.tryParse(m.group(1)!);
          final int? mo = int.tryParse(m.group(2)!);
          final int? y = int.tryParse(m.group(3)!);
          final DateTime? dt = restrictToBirthAge
              ? parsePlausibleBirthDate(d, mo, y)
              : (d != null && mo != null && y != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31
                  ? DateTime.utc(y, mo, d)
                  : null);
          if (dt != null && !found.contains(dt)) {
            found.add(dt);
          }
        }
      }
      return found;
    }

    bool isBirthAnchorLabel(String upperAscii) {
      if (upperAscii.contains('DATA NASCIMENTO') ||
          upperAscii.contains('DATA DE NASCIMENTO') ||
          upperAscii.contains('DATA NASC') ||
          upperAscii.contains('DT NASC') ||
          upperAscii.contains('DT. NASC')) {
        return true;
      }
      // CNH 2022 Padrão Viena: Campo "3 DATA, LOCAL E UF DE NASCIMENTO"
      if (RegExp(r'\b3\s*\.?\s*DATA\b').hasMatch(upperAscii) ||
          (upperAscii.contains('NASCIMENTO') && !upperAscii.contains('MUNICIPIO DE NASCIMENTO'))) {
        return true;
      }
      return false;
    }

    bool isNonBirthDateLabel(String upperAscii) {
      return upperAscii.contains('VALIDADE') ||
          upperAscii.contains('4B') ||
          upperAscii.contains('EMISSAO') ||
          upperAscii.contains('4A') ||
          upperAscii.contains('EXPEDICAO') ||
          upperAscii.contains('VENCIMENTO') ||
          upperAscii.contains('1A HAB') ||
          upperAscii.contains('1ª HAB') ||
          upperAscii.contains('PRIMEIRA HAB') ||
          upperAscii.contains('PRIMEIRA');
    }

    // -------------------------------------------------------------------------
    // PRIORIDADE 1: MRZ TD1 linha 2 com check digit validado / QR estruturado
    // -------------------------------------------------------------------------
    if (mrzLines.length == 3 && mrzLines[1].length >= 7) {
      final String yymmdd = mrzLines[1].substring(0, 6);
      final int? checkDigit = int.tryParse(mrzLines[1][6]);
      if (RegExp(r'^\d{6}$').hasMatch(yymmdd) &&
          checkDigit != null &&
          DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(yymmdd) == checkDigit) {
        final int yy = int.parse(yymmdd.substring(0, 2));
        final int mm = int.parse(yymmdd.substring(2, 4));
        final int dd = int.parse(yymmdd.substring(4, 6));
        final int pivot = currentYear % 100;
        final int fullYear = (yy <= pivot - minAgeYears) ? (2000 + yy) : (1900 + yy);
        final DateTime? dt = parsePlausibleBirthDate(dd, mm, fullYear);
        if (dt != null) {
          return (date: dt, confidence: 0.99);
        }
      }
    }

    // Verifica QR payloads com data de nascimento explícita (ex.: query/JSON)
    for (final qr in qrPayloads) {
      final m = RegExp(
        r'(?:birth|nascimento|dtNasc|dataNascimento)[^0-9]{0,12}(\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ).firstMatch(qr);
      if (m != null) {
        final raw = m.group(1)!;
        if (raw.contains('-')) {
          final p = raw.split('-');
          final dt = parsePlausibleBirthDate(
            int.tryParse(p[2]),
            int.tryParse(p[1]),
            int.tryParse(p[0]),
          );
          if (dt != null) return (date: dt, confidence: 0.99);
        } else {
          final p = raw.split('/');
          final dt = parsePlausibleBirthDate(
            int.tryParse(p[0]),
            int.tryParse(p[1]),
            int.tryParse(p[2]),
          );
          if (dt != null) return (date: dt, confidence: 0.99);
        }
      }
    }

    // -------------------------------------------------------------------------
    // PRIORIDADE 2: ÂNCORA ESPACIAL 2D (BoundingBox do Google ML Kit)
    // -------------------------------------------------------------------------
    final List<OcrTextLineBox> allGeoLines = <OcrTextLineBox>[
      ...frontLines,
      ...backLines,
    ];
    if (allGeoLines.isNotEmpty) {
      final List<OcrTextLineBox> birthAnchors = <OcrTextLineBox>[];
      final List<OcrTextLineBox> nonBirthAnchors = <OcrTextLineBox>[];

      for (final line in allGeoLines) {
        final String up = _toAsciiUpper(line.text);
        if (isBirthAnchorLabel(up)) {
          // Se a própria linha da âncora já contém a data (ex.: "DATA NASCIMENTO 03/01/1995")
          final inlineDates = extractAllValidDatesInText(
            line.text,
            restrictToBirthAge: true,
          );
          if (inlineDates.isNotEmpty) {
            return (date: inlineDates.first, confidence: 0.97);
          }
          birthAnchors.add(line);
        } else if (isNonBirthDateLabel(up)) {
          nonBirthAnchors.add(line);
        }
      }

      DateTime? bestSpatialDate;
      double bestSpatialScore = double.infinity;

      for (final anchor in birthAnchors) {
        final double anchorH = math.max(anchor.normHeight, 0.018);
        for (final cand in allGeoLines) {
          if (identical(cand, anchor)) continue;
          final String candUp = _toAsciiUpper(cand.text);
          if (isNonBirthDateLabel(candUp)) continue;

          final dates = extractAllValidDatesInText(
            cand.text,
            restrictToBirthAge: true,
          );
          if (dates.isEmpty) continue;

          // Zona A: diretamente ABAIXO da âncora (padrão CNH Clássica e CNH 2022)
          final double dyBelow = cand.normTop - anchor.normBottom;
          final bool inBelowBand =
              dyBelow >= -0.45 * anchorH && dyBelow <= 3.2 * anchorH;
          final bool xAlignedBelow =
              cand.normCenterX >= anchor.normLeft - 0.14 &&
              cand.normCenterX <= anchor.normRight + 0.22;

          // Zona B: à DIREITA na mesma linha horizontal
          final double dySameLine = (cand.normCenterY - anchor.normCenterY).abs();
          final bool inRightBand =
              dySameLine <= 0.90 * anchorH &&
              cand.normLeft >= anchor.normRight - 0.03 &&
              cand.normLeft <= anchor.normRight + 0.35;

          if (!((inBelowBand && xAlignedBelow) || inRightBand)) continue;

          final double dx = (cand.normCenterX - anchor.normCenterX).abs();
          final double dy = inBelowBand
              ? math.max(0.0, dyBelow)
              : dySameLine;
          final double distToBirth = (dx * 0.85) + (dy * 1.4);

          // Proteção anti-contaminação: garante que a data não pertença a um
          // rótulo vizinho (ex.: VALIDADE ou 1ª HABILITAÇÃO mais próximo acima).
          bool closerToNonBirth = false;
          for (final bad in nonBirthAnchors) {
            final double badDy = cand.normTop - bad.normBottom;
            final double badDx = (cand.normCenterX - bad.normCenterX).abs();
            if (badDy >= -0.35 * anchorH && badDy <= 2.4 * anchorH) {
              final double distToBad = (badDx * 0.85) + (math.max(0.0, badDy) * 1.4);
              if (distToBad < distToBirth * 0.92) {
                closerToNonBirth = true;
                break;
              }
            }
          }
          if (closerToNonBirth) continue;

          if (distToBirth < bestSpatialScore) {
            bestSpatialScore = distToBirth;
            bestSpatialDate = dates.first;
          }
        }
      }

      if (bestSpatialDate != null) {
        return (date: bestSpatialDate, confidence: 0.96);
      }
    }

    // -------------------------------------------------------------------------
    // PRIORIDADE 3 & 4: Rótulo Textual com Reparo OCR + Janela Tolerante
    // -------------------------------------------------------------------------
    final List<String> lines = (frontRaw.trim().isNotEmpty ? frontRaw : combinedRaw)
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

    for (int i = 0; i < lines.length; i++) {
      final String up = _toAsciiUpper(lines[i]);
      if (!isBirthAnchorLabel(up)) continue;

      // Mesma linha do rótulo
      final sameLineDates = extractAllValidDatesInText(
        lines[i],
        restrictToBirthAge: true,
      );
      if (sameLineDates.isNotEmpty) {
        return (date: sameLineDates.first, confidence: 0.94);
      }

      // Até 3 linhas adiante (no ML Kit linearizado, CPF ou RG pode aparecer
      // entre o rótulo "DATA NASCIMENTO" e o valor da data!)
      for (int offset = 1; offset <= 3 && (i + offset) < lines.length; offset++) {
        final String nextLine = lines[i + offset];
        final String nextUp = _toAsciiUpper(nextLine);
        if (isNonBirthDateLabel(nextUp)) break;
        final nextDates = extractAllValidDatesInText(
          nextLine,
          restrictToBirthAge: true,
        );
        if (nextDates.isNotEmpty) {
          return (date: nextDates.first, confidence: offset == 1 ? 0.93 : 0.89);
        }
      }
    }

    // Regex direta no texto combinado (compatibilidade com formatos corridos)
    final RegExp labeledDate = RegExp(
      r'(?:DATA\s*(?:DE\s*)?NASCIMENTO|NASCIMENTO|DATA\s*NASC\.?|3\s*\.?\s*DATA[^\n]{0,30})[^\d]{0,32}([0-9OoQDIl|!ZzSsBgq]{2})[/.\-\s]+([0-9OoQDIl|!ZzSsBgq]{2})[/.\-\s]+([0-9OoQDIl|!ZzSsBgq]{4})',
      caseSensitive: false,
    );
    final RegExpMatch? lm = labeledDate.firstMatch(combinedRaw);
    if (lm != null) {
      final DateTime? dt = parsePlausibleBirthDate(
        int.tryParse(repairDateDigits(lm.group(1)!)),
        int.tryParse(repairDateDigits(lm.group(2)!)),
        int.tryParse(repairDateDigits(lm.group(3)!)),
      );
      if (dt != null) {
        return (date: dt, confidence: 0.92);
      }
    }

    // -------------------------------------------------------------------------
    // PRIORIDADE 5: Desambiguação Cronológica Forense da CNH
    // -------------------------------------------------------------------------
    final List<DateTime> allDatesOnDoc = <DateTime>[];
    final List<DateTime> nonBadLineBirthCandidates = <DateTime>[];

    for (final rawLine in combinedRaw.split(RegExp(r'[\r\n]+'))) {
      final String up = _toAsciiUpper(rawLine);
      final lineAll = extractAllValidDatesInText(rawLine, restrictToBirthAge: false);
      for (final d in lineAll) {
        if (!allDatesOnDoc.contains(d)) allDatesOnDoc.add(d);
      }
      if (isNonBirthDateLabel(up)) continue;
      final lineBirths = extractAllValidDatesInText(rawLine, restrictToBirthAge: true);
      for (final d in lineBirths) {
        if (!nonBadLineBirthCandidates.contains(d)) {
          nonBadLineBirthCandidates.add(d);
        }
      }
    }

    if (nonBadLineBirthCandidates.isEmpty) {
      return (date: null, confidence: 0.0);
    }

    nonBadLineBirthCandidates.sort();
    allDatesOnDoc.sort();
    final DateTime earliest = nonBadLineBirthCandidates.first;

    // Se é uma CNH com múltiplas datas (ex.: Nascimento + 1ª Hab. + Emissão + Validade),
    // a data mais antiga separada por >= 17,5 anos da próxima data mais antiga (1ª Hab.)
    // tem altíssima certeza matemática de ser a Data de Nascimento!
    if (docType == OfficialDocumentType.cnh && allDatesOnDoc.length >= 2) {
      final DateTime? secondDate = allDatesOnDoc
          .where((d) => d.isAfter(earliest))
          .firstOrNull;
      if (secondDate != null) {
        final int gapDays = secondDate.difference(earliest).inDays;
        if (gapDays >= 6380) {
          // >= ~17.5 anos entre Nascimento e 1ª Habilitação/Emissão
          return (date: earliest, confidence: 0.90);
        }
        // Ambiguidade (ex.: só leu 1ª Hab. e Emissão, sem ler o Nascimento!) ->
        // confiança baixa para obrigar o escalonamento ao Vision AI em nuvem!
        return (date: earliest, confidence: 0.55);
      }
    }

    // Documento não-CNH ou apenas 1 data isolada sem rótulo explícito:
    // confiança moderada (0.72) para escalonar ao Vision AI se online, mas nunca inventar 1990!
    return (date: earliest, confidence: 0.72);
  }

  static String? _extractIssuingAuthority({
    required String combinedRaw,
    required String asciiUpper,
    required OfficialDocumentType docType,
  }) {
    final RegExp labeled = RegExp(
      r'(?:[ÓO]RG[ÃA]O\s*(?:EMISSOR|EXPEDIDOR)|EMISSOR|EXPEDIDOR)\s*[:\-]\s*([A-Z0-9/\-\s]{3,28})',
      caseSensitive: false,
    );
    final RegExpMatch? lm = labeled.firstMatch(combinedRaw);
    if (lm != null) {
      final String val = lm.group(1)!.split(RegExp(r'[\r\n]')).first.trim();
      if (val.length >= 3) return val;
    }

    final RegExp knownAgencyWithUf = RegExp(
      r'\b(DETRAN|SSP|SESP|SDS|PC|IIPM|IFP|IGP|ITEP|SEJUSP|SENATRAN)\s*[/\-\s]?\s*([A-Z]{2})\b',
    );
    String? firstAgencyMatch;
    for (final m in knownAgencyWithUf.allMatches(asciiUpper)) {
      final String agency = m.group(1)!;
      final String uf = m.group(2)!;
      if (_ufCodes.contains(uf)) {
        final String formatted = '$agency/$uf';
        // Na CNH, prioriza DETRAN/UF ou SENATRAN sobre o órgão emissor do RG listado no campo 4c
        if (docType == OfficialDocumentType.cnh &&
            (agency == 'DETRAN' || agency == 'SENATRAN')) {
          return formatted;
        }
        firstAgencyMatch ??= formatted;
      }
    }
    if (firstAgencyMatch != null) return firstAgencyMatch;

    if (asciiUpper.contains('RECEITA FEDERAL')) {
      return 'Receita Federal';
    }
    if (asciiUpper.contains('SENATRAN')) {
      return 'SENATRAN';
    }
    if (asciiUpper.contains('DETRAN')) {
      return 'DETRAN';
    }
    if (asciiUpper.contains('POLICIA CIVIL')) {
      return 'Polícia Civil';
    }
    if (asciiUpper.contains('SECRETARIA DE SEGURANCA')) {
      return 'SSP';
    }
    return docType == OfficialDocumentType.cpf ? 'Receita Federal' : null;
  }
}

/// Orquestrador de OCR Real (On-Device via Google ML Kit no Mobile + reforço online
/// opcional na Edge Function `kyc-argon-vision-gate` quando necessário, como na Web).
class DocumentRealOcrEngine {
  DocumentRealOcrEngine._();

  /// Executa a leitura bruta on-device (ou usa overrides em testes unitários).
  static Future<RawDocumentOcrExtraction> extractRawFromImages({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    String? rawOcrFrontTextOverride,
    String? rawOcrBackTextOverride,
    List<String>? qrPayloadsOverride,
  }) async {
    if (rawOcrFrontTextOverride != null || rawOcrBackTextOverride != null) {
      return RawDocumentOcrExtraction(
        frontText: rawOcrFrontTextOverride ?? '',
        backText: rawOcrBackTextOverride ?? '',
        qrPayloads: qrPayloadsOverride ?? const <String>[],
        frontRotationDegrees: 0,
        backRotationDegrees: 0,
        sourceEngine: 'override',
      );
    }

    final platform_ocr.PlatformDocumentOcrOutput onDevice =
        await platform_ocr.extractDocumentOcrOnDevice(
      frontImageBytes: frontImageBytes,
      backImageBytes: backImageBytes,
    );

    return RawDocumentOcrExtraction(
      frontText: onDevice.frontText,
      backText: onDevice.backText,
      qrPayloads: qrPayloadsOverride ?? onDevice.qrPayloads,
      frontRotationDegrees: onDevice.frontRotationDegrees,
      backRotationDegrees: onDevice.backRotationDegrees,
      sourceEngine:
          onDevice.availableOnPlatform ? 'mlkit_on_device' : 'unavailable',
      frontLines: onDevice.frontLines,
      backLines: onDevice.backLines,
    );
  }

  /// Extrai e interpreta os campos reais do documento (Frente + Verso).
  /// Se o motor on-device não conseguir ler todos os campos críticos com alta
  /// confiança (incluindo Data de Nascimento na CNH/CIN/RG) e houver reforço
  /// online autenticado (`kyc-argon-vision-gate`), consulta a Edge Function e
  /// preenche exclusivamente com os campos extraídos reais retornados pelo servidor.
  /// **NUNCA fabrica dados sintéticos (jamais inventa 01/01/1990).**
  static Future<ParsedBrazilianDocumentOcr> extractAndParse({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    required OfficialDocumentType expectedDocumentType,
    String? rawOcrFrontTextOverride,
    String? rawOcrBackTextOverride,
    List<String>? qrPayloadsOverride,
    List<OcrTextLineBox>? frontLinesOverride,
    List<OcrTextLineBox>? backLinesOverride,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
        edgeVisionGateInvoker,
    String? typedFullNameHint,
    String? typedCpfHint,
    bool allowSupabaseEdgeFallback = true,
  }) async {
    final RawDocumentOcrExtraction raw = await extractRawFromImages(
      frontImageBytes: frontImageBytes,
      backImageBytes: backImageBytes,
      rawOcrFrontTextOverride: rawOcrFrontTextOverride,
      rawOcrBackTextOverride: rawOcrBackTextOverride,
      qrPayloadsOverride: qrPayloadsOverride,
    );

    final ParsedBrazilianDocumentOcr parsed = BrazilianDocumentOcrParser.parse(
      frontText: raw.frontText,
      backText: raw.backText,
      expectedDocumentType: expectedDocumentType,
      qrPayloads: raw.qrPayloads,
      frontLines: frontLinesOverride ?? raw.frontLines,
      backLines: backLinesOverride ?? raw.backLines,
      sourceEngine: raw.sourceEngine,
      detectedRotationDegrees: raw.frontRotationDegrees,
    );

    if (parsed.hasHighConfidenceCoreFields) {
      return parsed;
    }

    // Se o OCR local veio incompleto OU sem Data de Nascimento de alta confiança,
    // aciona o reforço Vision AI (`kyc-argon-vision-gate`) para precisão bancária.
    final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? invoker =
        edgeVisionGateInvoker ??
            (allowSupabaseEdgeFallback ? _defaultSupabaseEdgeInvoker() : null);

    final bool canUseEdge = invoker != null &&
        (edgeVisionGateInvoker != null ||
            (rawOcrFrontTextOverride == null && rawOcrBackTextOverride == null));

    if (canUseEdge) {
      try {
        final Map<String, dynamic> payload = <String, dynamic>{
          'mode': 'kyc_document',
          'frontBase64': base64Encode(frontImageBytes),
          'backBase64': base64Encode(backImageBytes),
          'typedCpf': DocumentOcrAndLivenessService.digitsOnly(typedCpfHint ?? ''),
          'typedFullName': (typedFullNameHint ?? '').trim(),
          'document_type': expectedDocumentType.code,
          'persistSubmission': false,
        };
        final Map<String, dynamic> resp = await invoker(payload);
        final ParsedBrazilianDocumentOcr? fromEdge = _parseFromEdgeResponse(
          resp: resp,
          fallbackType: expectedDocumentType,
          existing: parsed,
        );
        if (fromEdge != null && fromEdge.hasRequiredIdentityFields) {
          return fromEdge;
        }
      } catch (_) {
        // Sem conexão ou Edge indisponível: retorna o resultado local honesto
      }
    }

    return parsed;
  }

  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _defaultSupabaseEdgeInvoker() {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;
      return (Map<String, dynamic> payload) async {
        final res = await client.functions.invoke(
          'kyc-argon-vision-gate',
          body: payload,
        );
        final dynamic data = res.data;
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return const <String, dynamic>{};
      };
    } catch (_) {
      return null;
    }
  }

  static ParsedBrazilianDocumentOcr? _parseFromEdgeResponse({
    required Map<String, dynamic> resp,
    required OfficialDocumentType fallbackType,
    required ParsedBrazilianDocumentOcr existing,
  }) {
    final Object? qgObj = resp['quality_gate'];
    final Map<String, dynamic> qg =
        qgObj is Map ? Map<String, dynamic>.from(qgObj) : const <String, dynamic>{};
    if (qg['is_readable'] == false || resp['ready_for_serpro_and_carbon'] == false) {
      return null;
    }

    final String edgeName = (resp['extracted_full_name'] ?? '').toString().trim();
    final String edgeCpf = DocumentOcrAndLivenessService.digitsOnly(
      (resp['extracted_cpf_11_digits'] ?? '').toString(),
    );
    final String edgeBirthIso =
        (resp['extracted_birth_date_iso'] ?? '').toString().trim();
    final String edgeDocNum =
        (resp['extracted_document_number'] ?? '').toString().trim();
    final String edgeIssuer =
        (resp['extracted_issuing_authority'] ?? '').toString().trim();
    final String edgeTypeCode =
        (qg['detected_document_type'] ?? fallbackType.code).toString();

    final String? finalName =
        DocumentOcrAndLivenessService.isValidCivilFullName(edgeName)
            ? edgeName.toUpperCase()
            : existing.fullName;
    final String? finalCpf =
        DocumentOcrAndLivenessService.isValidCpfMod11(edgeCpf)
            ? edgeCpf
            : existing.cpfDigits;

    if (finalName == null || finalCpf == null) return null;

    DateTime? parsedBirth = existing.birthDate;
    double birthConf = existing.birthDateConfidence;
    final String effectiveBirthIso = edgeBirthIso.isNotEmpty
        ? edgeBirthIso
        : ((resp['dossier'] is Map ? (resp['dossier'] as Map)['birth_date_iso'] : null) ?? '')
            .toString()
            .trim();
    if (effectiveBirthIso.isNotEmpty) {
      final DateTime? iso = DateTime.tryParse(effectiveBirthIso);
      if (iso != null && iso.year >= 1915 && iso.year <= DateTime.now().year - 10) {
        parsedBirth = DateTime.utc(iso.year, iso.month, iso.day);
        birthConf = 0.98;
      }
    }

    final int rot = (qg['canonical_rotation_deg'] is num)
        ? (qg['canonical_rotation_deg'] as num).toInt()
        : existing.detectedRotationDegrees;

    return ParsedBrazilianDocumentOcr(
      detectedDocumentType: OfficialDocumentType.fromCode(edgeTypeCode),
      fullName: finalName,
      cpfDigits: finalCpf,
      documentNumber: edgeDocNum.isNotEmpty ? edgeDocNum : existing.documentNumber,
      birthDate: parsedBirth,
      birthDateConfidence: birthConf,
      issuingAuthority:
          edgeIssuer.isNotEmpty ? edgeIssuer : existing.issuingAuthority,
      renach: existing.renach,
      cnhSecurityCode11: existing.cnhSecurityCode11,
      mrzLines: existing.mrzLines,
      mrzChecksumValid: resp['mrz_checksums_valid'] == true || existing.mrzChecksumValid,
      mrzOrQrPresent:
          resp['mrz_checksums_valid'] == true || existing.mrzOrQrPresent,
      qrCodeDetected: existing.qrCodeDetected,
      qrCodeRawPayload: existing.qrCodeRawPayload,
      officialHeaderDetected: true,
      estimatedConfidence: math.max(existing.estimatedConfidence, 94.0),
      rawFrontText: existing.rawFrontText,
      rawBackText: existing.rawBackText,
      sourceEngine: 'edge_vision_gate',
      detectedRotationDegrees: rot,
    );
  }
}

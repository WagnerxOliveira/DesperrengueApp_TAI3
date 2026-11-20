import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_ocr_and_liveness_service.dart';
import 'document_real_ocr_engine_stub.dart'
    if (dart.library.io) 'document_real_ocr_engine_mobile.dart' as platform_ocr;

/// Resultado bruto retornado pela leitura óptica (ML Kit on-device, override de teste ou Edge).
class RawDocumentOcrExtraction {
  const RawDocumentOcrExtraction({
    required this.frontText,
    required this.backText,
    required this.qrPayloads,
    required this.frontRotationDegrees,
    required this.backRotationDegrees,
    required this.sourceEngine,
  });

  final String frontText;
  final String backText;
  final List<String> qrPayloads;
  final int frontRotationDegrees;
  final int backRotationDegrees;
  final String sourceEngine;

  bool get hasAnyText =>
      frontText.trim().isNotEmpty ||
      backText.trim().isNotEmpty ||
      qrPayloads.isNotEmpty;
}

/// Dados estruturados extraídos de forma honesta e determinística de documentos
/// oficiais brasileiros (CNH clássica, CNH 2022+, CIN, RG e Comprovante CPF).
///
/// Nenhum campo civil (nome, CPF) é inventado quando não lido do documento real.
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
    this.sourceEngine = 'mlkit_on_device',
    this.detectedRotationDegrees = 0,
  });

  final OfficialDocumentType detectedDocumentType;
  final String? fullName;
  final String? cpfDigits;
  final String? documentNumber;
  final DateTime? birthDate;
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

    // 7. Data de Nascimento (rótulo NASCIMENTO -> MRZ TD1 linha 2 -> heurística segura)
    final DateTime? birthDate = _extractBirthDate(
      combinedRaw: combined,
      mrzLines: mrzLines,
    );

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

  static DateTime? _extractBirthDate({
    required String combinedRaw,
    required List<String> mrzLines,
  }) {
    final int currentYear = DateTime.now().year;

    DateTime? parseBrDate(String rawD, String rawM, String rawY) {
      final int? d = int.tryParse(rawD);
      final int? m = int.tryParse(rawM);
      final int? y = int.tryParse(rawY);
      if (d == null || m == null || y == null) return null;
      if (y < 1915 || y > currentYear - 10) return null;
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      try {
        final DateTime dt = DateTime.utc(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
      } catch (_) {}
      return null;
    }

    // 1. Mesmo linha ou próxima linha após rótulo NASCIMENTO / DATA NASC / 3 DATA
    final RegExp labeledDate = RegExp(
      r'(?:DATA\s*(?:DE\s*)?NASCIMENTO|NASCIMENTO|DATA\s*NASC\.?|3\s*DATA[^\n]{0,25})[^\d]{0,24}(\d{2})[/.\-](\d{2})[/.\-](\d{4})',
      caseSensitive: false,
    );
    final RegExpMatch? lm = labeledDate.firstMatch(combinedRaw);
    if (lm != null) {
      final DateTime? dt = parseBrDate(lm.group(1)!, lm.group(2)!, lm.group(3)!);
      if (dt != null) return dt;
    }

    // 2. MRZ TD1 linha 2 (YYMMDD nas posições 0..6)
    if (mrzLines.length == 3 && mrzLines[1].length >= 7) {
      final String yymmdd = mrzLines[1].substring(0, 6);
      if (RegExp(r'^\d{6}$').hasMatch(yymmdd)) {
        final int yy = int.parse(yymmdd.substring(0, 2));
        final int mm = int.parse(yymmdd.substring(2, 4));
        final int dd = int.parse(yymmdd.substring(4, 6));
        final int pivot = currentYear % 100;
        final int fullYear = (yy <= pivot - 10) ? (2000 + yy) : (1900 + yy);
        final DateTime? dt = parseBrDate(
          dd.toString().padLeft(2, '0'),
          mm.toString().padLeft(2, '0'),
          fullYear.toString(),
        );
        if (dt != null) return dt;
      }
    }

    // 3. Heurística segura: datas DD/MM/AAAA que não estejam em linhas de validade/emissão
    final RegExp dateRe = RegExp(r'\b(\d{2})[/.\-](\d{2})[/.\-](\d{4})\b');
    DateTime? earliestPlausible;
    for (final rawLine in combinedRaw.split(RegExp(r'[\r\n]+'))) {
      final String up = _toAsciiUpper(rawLine);
      if (up.contains('VALIDADE') ||
          up.contains('EMISSAO') ||
          up.contains('EXPEDICAO') ||
          up.contains('VENCIMENTO') ||
          up.contains('1A HAB') ||
          up.contains('PRIMEIRA')) {
        continue;
      }
      for (final m in dateRe.allMatches(rawLine)) {
        final DateTime? dt = parseBrDate(m.group(1)!, m.group(2)!, m.group(3)!);
        if (dt != null &&
            (earliestPlausible == null || dt.isBefore(earliestPlausible))) {
          earliestPlausible = dt;
        }
      }
    }

    return earliestPlausible;
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
    );
  }

  /// Extrai e interpreta os campos reais do documento (Frente + Verso).
  /// Se o motor on-device não conseguir ler (ex.: navegador Web) e houver reforço
  /// online autenticado (`kyc-argon-vision-gate`), consulta a Edge Function e
  /// preenche exclusivamente com os campos extraídos reais retornados pelo servidor.
  /// **NUNCA fabrica dados sintéticos.**
  static Future<ParsedBrazilianDocumentOcr> extractAndParse({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    required OfficialDocumentType expectedDocumentType,
    String? rawOcrFrontTextOverride,
    String? rawOcrBackTextOverride,
    List<String>? qrPayloadsOverride,
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

    ParsedBrazilianDocumentOcr parsed = BrazilianDocumentOcrParser.parse(
      frontText: raw.frontText,
      backText: raw.backText,
      expectedDocumentType: expectedDocumentType,
      qrPayloads: raw.qrPayloads,
      sourceEngine: raw.sourceEngine,
      detectedRotationDegrees: raw.frontRotationDegrees,
    );

    if (parsed.hasRequiredIdentityFields) {
      return parsed;
    }

    // Se o OCR local veio incompleto (ex.: Web ou foto desafiadora), tenta reforço online
    final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? invoker =
        edgeVisionGateInvoker ??
            (allowSupabaseEdgeFallback ? _defaultSupabaseEdgeInvoker() : null);

    if (invoker != null &&
        rawOcrFrontTextOverride == null &&
        rawOcrBackTextOverride == null) {
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
    if (edgeBirthIso.isNotEmpty) {
      final DateTime? iso = DateTime.tryParse(edgeBirthIso);
      if (iso != null) {
        parsedBirth = DateTime.utc(iso.year, iso.month, iso.day);
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

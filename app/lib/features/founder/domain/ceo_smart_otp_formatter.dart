import 'package:flutter/services.dart';

/// Extrator e formatador determinístico de códigos OTP de 6 dígitos para o
/// Cofre Soberano do Desperrengue CEO (`NIST SP 800-63B` / UX Fintech AAL3).
///
/// Resolve integralmente falhas de colagem e teclado em Android/Samsung One UI:
/// - Códigos copiados com espaços não-quebráveis (`686\u00A0415`) ou hifens;
/// - Códigos copiados com quebra de linha mobile (`686 41\n5`);
/// - Trechos inteiros do e-mail copiados junto com números vizinhos
///   (`"Digite os 6 dígitos... 686 415 · Validade de 10 minutos"`);
/// - Colagem sobre campo parcialmente preenchido sem truncamento em 6 chars
///   brutos antes da higienização.
abstract final class CeoSmartOtpExtractor {
  static final RegExp _tier1ContiguousSix = RegExp(r'(?<!\d)(\d{6})(?!\d)');

  static final RegExp _tier2GroupedThreeByThree = RegExp(
    r'(?<!\d)(\d{3}[ \t\u00A0\u2000-\u200B\-]+\d{3})(?!\d)',
  );

  static final RegExp _tier3WrappedSix = RegExp(
    r'(?<!\d)(\d(?:[ \t\u00A0\u2000-\u200B\-]*\r?\n?[ \t\u00A0\u2000-\u200B\-]*\d){5})(?!\d)',
  );

  static final RegExp _nonAsciiDigits = RegExp(r'[^0-9]');

  /// Localiza um agrupamento isolado de exatos 6 dígitos em [raw], ignorando
  /// números periféricos do texto (ex.: `"6 dígitos"`, `"10 minutos"`, `"#80ED"`).
  /// Retorna `null` caso não exista um cluster completo de 6 dígitos.
  static String? extractSixDigitClusterOrNull(String raw) {
    if (raw.isEmpty) return null;

    final m1 = _tier1ContiguousSix.firstMatch(raw);
    if (m1 != null) {
      return m1.group(1)!;
    }

    final m2 = _tier2GroupedThreeByThree.firstMatch(raw);
    if (m2 != null) {
      return m2.group(1)!.replaceAll(_nonAsciiDigits, '');
    }

    final m3 = _tier3WrappedSix.firstMatch(raw);
    if (m3 != null) {
      final cleaned = m3.group(1)!.replaceAll(_nonAsciiDigits, '');
      if (cleaned.length == 6) {
        return cleaned;
      }
    }

    return null;
  }

  /// Extrai os melhores até 6 dígitos numéricos de [raw], priorizando clusters
  /// completos de 6 dígitos em colagens de e-mail e preservando digitação manual
  /// progressiva de 1 a 5 dígitos.
  static String extractBestSixDigits(String raw) {
    if (raw.isEmpty) return '';

    final cluster = extractSixDigitClusterOrNull(raw);
    if (cluster != null) {
      return cluster;
    }

    final digitsOnly = raw.replaceAll(_nonAsciiDigits, '');
    if (digitsOnly.length <= 6) {
      return digitsOnly;
    }
    return digitsOnly.substring(0, 6);
  }
}

/// Formatador inteligente para campos de OTP de 6 dígitos sem `maxLength: 6`
/// nativo no `TextField` (evitando que o IME do Android corte `"686\u00A0415"`
/// em `"686\u00A041"` antes do `TextInputFormatter` atuar).
class CeoSmartSixDigitOtpInputFormatter extends TextInputFormatter {
  const CeoSmartSixDigitOtpInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final inserted = _extractInsertedSlice(oldValue.text, newText);

    // Se o usuário colou/autocompletou múltiplos caracteres contendo os 6 dígitos,
    // substitui integralmente o campo pelos 6 dígitos extraídos.
    if (inserted.length > 1) {
      final pastedCluster =
          CeoSmartOtpExtractor.extractSixDigitClusterOrNull(inserted);
      if (pastedCluster != null) {
        return TextEditingValue(
          text: pastedCluster,
          selection: TextSelection.collapsed(offset: pastedCluster.length),
        );
      }
    }

    final fullCluster =
        CeoSmartOtpExtractor.extractSixDigitClusterOrNull(newText);
    if (fullCluster != null &&
        (inserted.length > 1 || oldValue.text.length < 6)) {
      return TextEditingValue(
        text: fullCluster,
        selection: TextSelection.collapsed(offset: fullCluster.length),
      );
    }

    final digitsOnly = CeoSmartOtpExtractor.extractBestSixDigits(newText);

    // Se já havia 6 dígitos e o usuário tentou digitar um 7º dígito solto, mantém o valor anterior.
    if (oldValue.text.length == 6 &&
        inserted.length == 1 &&
        newText.length > oldValue.text.length) {
      return oldValue;
    }

    final clampedOffset = newValue.selection.end < 0
        ? digitsOnly.length
        : (newValue.selection.end > digitsOnly.length
            ? digitsOnly.length
            : newValue.selection.end);

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: clampedOffset),
    );
  }

  static String _extractInsertedSlice(String oldText, String newText) {
    var prefix = 0;
    final minLen =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (prefix < minLen &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    if (newSuffix <= prefix) return '';
    return newText.substring(prefix, newSuffix);
  }
}

/// Motor Puro de Validação Matemática de Senha Forte Soberana do `Desperrengue CEO`
/// (`NIST SP 800-63B AAL3` / `OWASP ASVS v4.0.3 L3`).
///
/// Espelho determinístico 1:1 da política aplicada no servidor em
/// `supabase/functions/ceo-vault-authority/index.ts`.
library;

import 'dart:convert';
import 'dart:math' as math;

enum CeoPasswordStrengthTier {
  empty,
  insufficient,
  strong,
  sovereignMaximum,
}

class CeoPasswordEvaluation {
  const CeoPasswordEvaluation({
    required this.charCount,
    required this.utf8ByteCount,
    required this.lengthInRange,
    required this.noWhitespaceOrControl,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialSymbol,
    required this.hasSufficientEntropy,
    required this.noQuadRepeat,
    required this.noSequentialOrWalk,
    required this.noForbiddenContextWord,
    required this.shannonBitsPerChar,
    required this.totalEntropyBits,
    required this.failedRuleCodes,
  });

  static const int minChars = 12;
  static const int maxChars = 64;
  static const int maxUtf8Bytes = 256;
  static const double minBitsPerChar = 3.50;
  static const double minTotalEntropyBits = 60.0;

  final int charCount;
  final int utf8ByteCount;
  final bool lengthInRange;
  final bool noWhitespaceOrControl;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialSymbol;
  final bool hasSufficientEntropy;
  final bool noQuadRepeat;
  final bool noSequentialOrWalk;
  final bool noForbiddenContextWord;
  final double shannonBitsPerChar;
  final double totalEntropyBits;
  final List<String> failedRuleCodes;

  bool get isApproved => failedRuleCodes.isEmpty;

  bool get antiPatternApproved =>
      noWhitespaceOrControl &&
      hasSufficientEntropy &&
      noQuadRepeat &&
      noSequentialOrWalk &&
      noForbiddenContextWord;

  CeoPasswordStrengthTier get strengthTier {
    if (charCount == 0) return CeoPasswordStrengthTier.empty;
    if (!isApproved) return CeoPasswordStrengthTier.insufficient;
    if (totalEntropyBits >= 82.0 && charCount >= 16) {
      return CeoPasswordStrengthTier.sovereignMaximum;
    }
    return CeoPasswordStrengthTier.strong;
  }

  double get normalizedProgress {
    if (charCount == 0) return 0.0;
    final entropyFactor = (totalEntropyBits / 90.0).clamp(0.08, 1.0);
    if (!isApproved) {
      return (entropyFactor * 0.68).clamp(0.10, 0.68);
    }
    return entropyFactor.clamp(0.76, 1.0);
  }

  String get tierLabelPt {
    switch (strengthTier) {
      case CeoPasswordStrengthTier.empty:
        return 'Aguardando criação da Senha Mestra (12 a 64 caracteres)';
      case CeoPasswordStrengthTier.insufficient:
        return 'Senha abaixo do padrão soberano exigido';
      case CeoPasswordStrengthTier.strong:
        return 'Senha Forte Aprovada (${totalEntropyBits.toStringAsFixed(0)} bits)';
      case CeoPasswordStrengthTier.sovereignMaximum:
        return 'Blindagem Máxima Soberana (${totalEntropyBits.toStringAsFixed(0)} bits)';
    }
  }

  String? get primaryRejectionMessagePt {
    if (isApproved) return null;
    if (!lengthInRange) {
      return 'A Senha Mestra deve ter estritamente entre 12 e 64 caracteres.';
    }
    if (!noWhitespaceOrControl) {
      return 'A Senha Mestra não pode conter espaços em branco ou caracteres de controle.';
    }
    if (!hasUppercase) {
      return 'Inclua pelo menos 1 letra maiúscula (A–Z).';
    }
    if (!hasLowercase) {
      return 'Inclua pelo menos 1 letra minúscula (a–z).';
    }
    if (!hasDigit) {
      return 'Inclua pelo menos 1 número (0–9).';
    }
    if (!hasSpecialSymbol) {
      return 'Inclua pelo menos 1 caractere especial (ex.: ! @ # \$ % & * - _ + = ?).';
    }
    if (!noForbiddenContextWord) {
      return 'Por segurança extrema, não inclua nomes próprios, números do e-mail ou termos do aplicativo na senha.';
    }
    if (!noQuadRepeat) {
      return 'Evite repetir o mesmo caractere 4 ou mais vezes seguidas.';
    }
    if (!noSequentialOrWalk) {
      return 'Sequências contínuas (ex.: 1234, abcd, qwerty) são bloqueadas.';
    }
    if (!hasSufficientEntropy) {
      return 'Aumente a variedade de caracteres para atingir entropia mínima de 60 bits.';
    }
    return 'A senha informada não atende aos critérios de segurança soberana.';
  }
}

class CeoStrongPasswordPolicy {
  const CeoStrongPasswordPolicy._();

  static const int minLength = CeoPasswordEvaluation.minChars;
  static const int maxLength = CeoPasswordEvaluation.maxChars;

  static const List<String> forbiddenSubstrings = <String>[
    'wagner',
    'oliveira',
    '2395',
    'desperrengue',
    'founder',
    'cockpit',
    'warroom',
    'admin',
    'ceo',
    'root',
    'senha',
    'password',
    'supabase',
    'brasil',
  ];

  static const List<String> _keyboardWalks = <String>[
    'qwer',
    'wert',
    'erty',
    'rtyu',
    'tyui',
    'yuio',
    'uiop',
    'asdf',
    'sdfg',
    'dfgh',
    'fghj',
    'ghjk',
    'hjkl',
    'zxcv',
    'xcvb',
    'cvbn',
    'vbnm',
    'rewq',
    'fdsa',
    'vcxz',
    '1qaz',
    '2wsx',
    '3edc',
  ];

  static CeoPasswordEvaluation evaluate(String candidate) {
    final runes = candidate.runes.toList(growable: false);
    final charCount = runes.length;
    final utf8Bytes = utf8.encode(candidate);
    final byteCount = utf8Bytes.length;

    final lengthOk = charCount >= CeoPasswordEvaluation.minChars &&
        charCount <= CeoPasswordEvaluation.maxChars &&
        byteCount <= CeoPasswordEvaluation.maxUtf8Bytes;

    final noWhitespaceOrControl =
        !RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(candidate);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(candidate);
    final hasLower = RegExp(r'[a-z]').hasMatch(candidate);
    final hasDigit = RegExp(r'[0-9]').hasMatch(candidate);
    final hasSpecial = RegExp(r'[^A-Za-z0-9\s]').hasMatch(candidate);

    final h = _computeShannonBitsPerRune(runes);
    final totalBits = h * charCount;
    final entropyOk = h >= CeoPasswordEvaluation.minBitsPerChar &&
        totalBits >= CeoPasswordEvaluation.minTotalEntropyBits;

    final noQuadRepeat = !_hasQuadRepeat(runes);
    final noSeqOrWalk = !_hasSequentialRunOrKeyboardWalk(candidate);
    final noForbidden = !_containsForbiddenSubstring(candidate);

    final failed = <String>[
      if (!lengthOk) 'LENGTH_12_TO_64',
      if (!noWhitespaceOrControl) 'NO_WHITESPACE_OR_CONTROL',
      if (!hasUpper) 'REQUIRE_UPPERCASE',
      if (!hasLower) 'REQUIRE_LOWERCASE',
      if (!hasDigit) 'REQUIRE_DIGIT',
      if (!hasSpecial) 'REQUIRE_SPECIAL_SYMBOL',
      if (!entropyOk) 'SHANNON_ENTROPY_MIN_60_BITS',
      if (!noQuadRepeat) 'NO_REPEATED_QUAD',
      if (!noSeqOrWalk) 'NO_SEQUENTIAL_OR_KEYBOARD_WALK',
      if (!noForbidden) 'NO_PERSONAL_OR_CONTEXT_TERMS',
    ];

    return CeoPasswordEvaluation(
      charCount: charCount,
      utf8ByteCount: byteCount,
      lengthInRange: lengthOk,
      noWhitespaceOrControl: noWhitespaceOrControl,
      hasUppercase: hasUpper,
      hasLowercase: hasLower,
      hasDigit: hasDigit,
      hasSpecialSymbol: hasSpecial,
      hasSufficientEntropy: entropyOk,
      noQuadRepeat: noQuadRepeat,
      noSequentialOrWalk: noSeqOrWalk,
      noForbiddenContextWord: noForbidden,
      shannonBitsPerChar: double.parse(h.toStringAsFixed(2)),
      totalEntropyBits: double.parse(totalBits.toStringAsFixed(1)),
      failedRuleCodes: List<String>.unmodifiable(failed),
    );
  }

  static double _computeShannonBitsPerRune(List<int> runes) {
    if (runes.isEmpty) return 0.0;
    final counts = <int, int>{};
    for (final r in runes) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final n = runes.length.toDouble();
    final ln2 = math.log(2.0);
    var entropy = 0.0;
    for (final c in counts.values) {
      final p = c / n;
      entropy -= p * (math.log(p) / ln2);
    }
    return entropy;
  }

  static bool _hasQuadRepeat(List<int> runes) {
    if (runes.length < 4) return false;
    var streak = 1;
    for (var i = 1; i < runes.length; i++) {
      if (runes[i] == runes[i - 1]) {
        streak++;
        if (streak >= 4) return true;
      } else {
        streak = 1;
      }
    }
    return false;
  }

  static bool _hasSequentialRunOrKeyboardWalk(String input) {
    final lower = input.toLowerCase();
    if (lower.length < 4) return false;

    for (var i = 0; i <= lower.length - 4; i++) {
      final c0 = lower.codeUnitAt(i);
      final c1 = lower.codeUnitAt(i + 1);
      final c2 = lower.codeUnitAt(i + 2);
      final c3 = lower.codeUnitAt(i + 3);
      final allAlpha = c0 >= 97 &&
          c0 <= 122 &&
          c1 >= 97 &&
          c1 <= 122 &&
          c2 >= 97 &&
          c2 <= 122 &&
          c3 >= 97 &&
          c3 <= 122;
      final allDigits = c0 >= 48 &&
          c0 <= 57 &&
          c1 >= 48 &&
          c1 <= 57 &&
          c2 >= 48 &&
          c2 <= 57 &&
          c3 >= 48 &&
          c3 <= 57;
      if (allAlpha || allDigits) {
        if (c1 == c0 + 1 && c2 == c1 + 1 && c3 == c2 + 1) return true;
        if (c1 == c0 - 1 && c2 == c1 - 1 && c3 == c2 - 1) return true;
      }
    }

    for (final walk in _keyboardWalks) {
      if (lower.contains(walk)) return true;
    }
    return false;
  }

  static bool _containsForbiddenSubstring(String input) {
    final lower = input.toLowerCase();
    final leet = _normalizeLeetspeak(input);
    for (final word in forbiddenSubstrings) {
      if (lower.contains(word) || leet.contains(word)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeLeetspeak(String input) {
    return input
        .toLowerCase()
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('@', 'a')
        .replaceAll('5', 's')
        .replaceAll('\$', 's')
        .replaceAll('7', 't');
  }
}

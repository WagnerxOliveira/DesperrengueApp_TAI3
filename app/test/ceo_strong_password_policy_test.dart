import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/domain/ceo_strong_password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CeoStrongPasswordPolicy — Strict 12..64 Char & Shannon Entropy Policy', () {
    test('Rejects empty, < 12 chars, and > 64 chars (65 chars)', () {
      expect(CeoStrongPasswordPolicy.evaluate('').isApproved, isFalse);

      final tooShort = CeoStrongPasswordPolicy.evaluate('K9#vM2\$pQ7!');
      expect(tooShort.charCount, equals(11));
      expect(tooShort.lengthInRange, isFalse);
      expect(tooShort.isApproved, isFalse);
      expect(tooShort.failedRuleCodes, contains('LENGTH_12_TO_64'));

      // 65 caracteres distintos/mistos -> estoura o teto máximo de 64
      const sixtyFiveChars =
          'K9#vM2\$pQ7!xR4&zL8*wB5%nF3^tG6@hJ1_yC0+dS9#vM2\$pQ7!xR4&zL8*wB5%nF';
      expect(sixtyFiveChars.runes.length, equals(65));
      final tooLong = CeoStrongPasswordPolicy.evaluate(sixtyFiveChars);
      expect(tooLong.lengthInRange, isFalse);
      expect(tooLong.isApproved, isFalse);
      expect(tooLong.failedRuleCodes, contains('LENGTH_12_TO_64'));
    });

    test('Rejects spaces, control chars, or missing character classes', () {
      final withSpace =
          CeoStrongPasswordPolicy.evaluate('K9#vM2\$p Q7!xR4&z');
      expect(withSpace.noWhitespaceOrControl, isFalse);
      expect(withSpace.isApproved, isFalse);
      expect(withSpace.failedRuleCodes, contains('NO_WHITESPACE_OR_CONTROL'));

      final noUpper = CeoStrongPasswordPolicy.evaluate('k9#vm2\$pq7!xr4&z');
      expect(noUpper.hasUppercase, isFalse);
      expect(noUpper.failedRuleCodes, contains('REQUIRE_UPPERCASE'));

      final noLower = CeoStrongPasswordPolicy.evaluate('K9#VM2\$PQ7!XR4&Z');
      expect(noLower.hasLowercase, isFalse);
      expect(noLower.failedRuleCodes, contains('REQUIRE_LOWERCASE'));

      final noDigit = CeoStrongPasswordPolicy.evaluate('Kp#vMz\$pQr!xRt&z');
      expect(noDigit.hasDigit, isFalse);
      expect(noDigit.failedRuleCodes, contains('REQUIRE_DIGIT'));

      final noSpecial = CeoStrongPasswordPolicy.evaluate('K9avM2bpQ7cxR4dz');
      expect(noSpecial.hasSpecialSymbol, isFalse);
      expect(noSpecial.failedRuleCodes, contains('REQUIRE_SPECIAL_SYMBOL'));
    });

    test('Rejects 4+ repeated chars, linear sequences, keyboard walks, and leetspeak owner/app terms', () {
      final repeated = CeoStrongPasswordPolicy.evaluate('K9#vAAAApQ7!xR4&');
      expect(repeated.noQuadRepeat, isFalse);
      expect(repeated.isApproved, isFalse);
      expect(repeated.failedRuleCodes, contains('NO_REPEATED_QUAD'));

      final seqNum = CeoStrongPasswordPolicy.evaluate('K9#v1234pQ7!xR4&');
      expect(seqNum.noSequentialOrWalk, isFalse);
      expect(seqNum.failedRuleCodes, contains('NO_SEQUENTIAL_OR_KEYBOARD_WALK'));

      final seqAlpha = CeoStrongPasswordPolicy.evaluate('K9#vAbCdpQ7!xR4&');
      expect(seqAlpha.noSequentialOrWalk, isFalse);

      final qwertyWalk = CeoStrongPasswordPolicy.evaluate('K9#vqwerpQ7!xR4&');
      expect(qwertyWalk.noSequentialOrWalk, isFalse);

      for (final blacklisted in const <String>[
        'W4gn3r#92\$Kp7!xR',
        '0l1v31r4#9\$Kp7!x',
        'Kp7!xR#2395\$vM9&',
        'D3sp3rr3ngu3#9!K',
        'C30#Kp7!xR9\$vM2&',
        '4dm1n#Kp7!xR9\$vM',
      ]) {
        final ev = CeoStrongPasswordPolicy.evaluate(blacklisted);
        expect(
          ev.noForbiddenContextWord,
          isFalse,
          reason: 'Termo pessoal/contextual em leetspeak deve ser barrado: $blacklisted',
        );
        expect(ev.isApproved, isFalse);
        expect(ev.failedRuleCodes, contains('NO_PERSONAL_OR_CONTEXT_TERMS'));
      }
    });

    test('Approves high-entropy 16..64 char Master Passwords & matches deterministic RFC 8018 PBKDF2-HMAC-SHA256', () {
      const strong18 = 'K9#vM2\$pQ7!xR4&zL8';
      final ev18 = CeoStrongPasswordPolicy.evaluate(strong18);
      expect(ev18.isApproved, isTrue, reason: 'Falhas inesperadas: ${ev18.failedRuleCodes}');
      expect(ev18.totalEntropyBits, greaterThanOrEqualTo(60.0));
      expect(ev18.shannonBitsPerChar, greaterThanOrEqualTo(3.5));

      const strong64 =
          'K9#vM2\$pQ7!xR4&zL8*wB5%nF3^tG6@hJ1_yC0+dS9#vM2\$pQ7!xR4&zL8*wB5%n';
      expect(strong64.runes.length, equals(64));
      final ev64 = CeoStrongPasswordPolicy.evaluate(strong64);
      expect(ev64.isApproved, isTrue);

      final ck1 = CeoMasterPasswordCryptoEngine.deriveClientKeySync(
        strong18,
        iterations: 2000,
      );
      final ck2 = CeoMasterPasswordCryptoEngine.deriveClientKeySync(
        strong18,
        iterations: 2000,
      );
      final ckDifferent = CeoMasterPasswordCryptoEngine.deriveClientKeySync(
        strong64,
        iterations: 2000,
      );
      expect(ck1.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(ck1), isTrue);
      expect(ck1, equals(ck2));
      expect(ck1, isNot(equals(ckDifferent)));
    });
  });
}

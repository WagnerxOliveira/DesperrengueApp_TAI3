import 'package:desperrengue_app/features/founder/domain/founder_deep_link_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FounderDeepLinkPolicy — Ephemeral Password Reset URI Isolation & Anti-Replay', () {
    const validUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
    final validGrantHex =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

    test('Accepts canonical desperrengue-founder://vault/reset-password?lid=...&gt=... once and blocks replay', () {
      final policy = FounderDeepLinkPolicy();
      final uri = Uri.parse(
        'desperrengue-founder://vault/reset-password?lid=$validUuid&gt=$validGrantHex',
      );

      final first = policy.parseAndValidate(uri);
      expect(first, isNotNull);
      expect(first!.linkId, equals(validUuid));
      expect(first.grantTokenHex, equals(validGrantHex));

      // Replay na mesma sessão deve ser bloqueado imediatamente
      final replay = policy.parseAndValidate(uri);
      expect(replay, isNull);

      // Se liberado explicitamente após cancelamento, pode ser lido uma vez
      policy.releaseUnconsumedLinkId(validUuid);
      final retried = policy.parseAndValidate(uri);
      expect(retried, isNotNull);
    });

    test('Rejects Marketplace schemes, OAuth callbacks, malformed UUID/hex, and oversized URIs', () {
      final policy = FounderDeepLinkPolicy();

      final rejectedUris = <String>[
        // Esquema do app público Marketplace -> jamais aceito
        'desperrengue://vault/reset-password?lid=$validUuid&gt=$validGrantHex',
        'br.com.desperrengue.app://login-callback?code=12345',
        'br.com.desperrengue.app.founder://login-callback?code=12345',
        // Host ou path incorretos
        'desperrengue-founder://onboarding/return?lid=$validUuid&gt=$validGrantHex',
        'desperrengue-founder://vault/other?lid=$validUuid&gt=$validGrantHex',
        // UUID inválido ou grant != 64 hex
        'desperrengue-founder://vault/reset-password?lid=not-a-uuid&gt=$validGrantHex',
        'desperrengue-founder://vault/reset-password?lid=$validUuid&gt=123456',
        'desperrengue-founder://vault/reset-password?lid=$validUuid&gt=${validGrantHex.substring(0, 63)}z',
        // URI acima de 320 caracteres
        'desperrengue-founder://vault/reset-password?lid=$validUuid&gt=$validGrantHex&pad=${"x" * 260}',
      ];

      for (final raw in rejectedUris) {
        expect(
          policy.parseAndValidate(Uri.parse(raw)),
          isNull,
          reason: 'URI inválida ou cross-app deveria ser rejeitada: $raw',
        );
      }
    });
  });
}

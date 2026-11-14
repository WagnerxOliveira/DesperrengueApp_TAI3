/// Política Determinística Zero-Trust para Deep-Links Exclusivos do `Desperrengue CEO`
/// (`br.com.desperrengue.app.founder`).
///
/// Regras:
/// - Aceita APENAS `desperrengue-founder://vault/reset-password?lid=<uuid>&gt=<64-hex>`.
/// - Rejeita sumariamente qualquer esquema público (`desperrengue://`,
///   `br.com.desperrengue.app://`), qualquer outro host/path, URIs acima de 320 chars
///   ou tokens fora do padrão hexadecimal de 256 bits.
library;

class FounderResetLinkGrant {
  const FounderResetLinkGrant({
    required this.linkId,
    required this.grantTokenHex,
    required this.receivedAtUtc,
  });

  final String linkId;
  final String grantTokenHex;
  final DateTime receivedAtUtc;
}

class FounderDeepLinkPolicy {
  FounderDeepLinkPolicy();

  static const String expectedScheme = 'desperrengue-founder';
  static const String expectedHost = 'vault';
  static const String expectedPath = '/reset-password';
  static const int maxUriLength = 320;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _hex64Regex = RegExp(r'^[0-9a-f]{64}$');

  final Set<String> _processedLinkIds = <String>{};

  /// Analisa e valida [uri] sem vazar tokens em exceções ou logs.
  /// Retorna `null` se o URI não for um deep-link legítimo e inédito do Cofre CEO.
  FounderResetLinkGrant? parseAndValidate(Uri? uri, {DateTime? nowUtc}) {
    if (uri == null) return null;
    final raw = uri.toString();
    if (raw.isEmpty || raw.length > maxUriLength) return null;

    if (uri.scheme.toLowerCase() != expectedScheme) return null;
    if (uri.host.toLowerCase() != expectedHost) return null;

    final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    if (normalizedPath != expectedPath) return null;

    final lid = (uri.queryParameters['lid'] ?? '').trim().toLowerCase();
    final gt = (uri.queryParameters['gt'] ?? '').trim().toLowerCase();

    if (!_uuidRegex.hasMatch(lid)) return null;
    if (!_hex64Regex.hasMatch(gt)) return null;

    if (_processedLinkIds.contains(lid)) {
      return null;
    }
    _processedLinkIds.add(lid);

    return FounderResetLinkGrant(
      linkId: lid,
      grantTokenHex: gt,
      receivedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    );
  }

  /// Permite liberar manualmente um `linkId` caso o CEO cancele a tela sem concluir
  /// e clique novamente no mesmo e-mail dentro dos 10 minutos de validade.
  void releaseUnconsumedLinkId(String linkId) {
    _processedLinkIds.remove(linkId.trim().toLowerCase());
  }
}

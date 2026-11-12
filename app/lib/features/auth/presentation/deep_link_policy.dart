/// Política de deep links do app (defesa contra link malicioso).
///
/// O único link interno aceito é `desperrengue://onboarding[/<segmento>...]`,
/// vindo do e-mail de aprovação do cadastro. Ele NÃO carrega credencial: só
/// faz o app reconsultar o status no servidor. Qualquer outra coisa é ignorada
/// silenciosamente (sem log do conteúdo: URLs podem conter tokens/PII).
///
/// Dart puro: testável sem Flutter.
library;

class DeepLinkPolicy {
  const DeepLinkPolicy._();

  static const String scheme = 'desperrengue';
  static const String onboardingHost = 'onboarding';

  /// Máximo de segmentos de caminho aceitos.
  static const int maxPathSegments = 4;

  /// Tamanho máximo da URL textual (links gigantes = tentativa de abuso).
  static const int maxLength = 512;

  /// Intervalo mínimo entre dois refreshes disparados por link: impede que um
  /// app hostil faça o roteador recarregar o perfil em loop (DoS/bateria).
  static const Duration minRefreshInterval = Duration(seconds: 2);

  static final RegExp _safeSegment = RegExp(r'^[A-Za-z0-9._~-]{1,64}$');

  /// Parâmetros de query que jamais devem chegar por link interno.
  static const Set<String> _forbiddenQueryKeys = {
    'access_token',
    'refresh_token',
    'token',
    'password',
    'senha',
    'code',
    'jwt',
    'cpf',
  };

  /// `true` se [uri] é um link de onboarding legítimo.
  static bool isTrustedOnboardingLink(Uri uri) {
    if (uri.toString().length > maxLength) return false;
    if (uri.scheme.toLowerCase() != scheme) return false;
    if (uri.host.toLowerCase() != onboardingHost) return false;
    if (uri.userInfo.isNotEmpty || uri.hasPort) return false;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length > maxPathSegments) return false;
    if (segments.any((s) => s == '.' || s == '..')) return false;
    if (!segments.every(_safeSegment.hasMatch)) return false;
    for (final key in uri.queryParameters.keys) {
      if (_forbiddenQueryKeys.contains(key.toLowerCase())) return false;
    }
    if (uri.hasFragment && uri.fragment.length > 64) return false;
    return true;
  }

  /// Decide se um refresh por link deve ocorrer agora (throttle).
  static bool shouldRefresh({required DateTime? lastRefresh, required DateTime now}) {
    if (lastRefresh == null) return true;
    return now.difference(lastRefresh) >= minRefreshInterval;
  }
}

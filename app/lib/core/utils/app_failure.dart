/// Erros tipados e humanos (pt-BR) para a camada de serviços/UI.
///
/// Regras:
///  * a mensagem exibida ao usuário NUNCA contém SQL, stack trace, nome de
///    tabela/constraint, token, CPF, telefone, e-mail ou coordenadas;
///  * o detalhe técnico (já sanitizado) fica em [AppFailure.debugCode], seguro
///    para log.
///
/// Este arquivo é Dart puro (sem `dart:io`/Flutter): roda em Web, testes e
/// isolates.
library;

/// Categoria do erro, útil para a UI decidir entre "tentar de novo", "entrar
/// de novo" ou apenas informar.
enum AppFailureKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  business,
  media,
  server,
  unknown,
}

/// Falha tipada. [message] é sempre segura para exibir.
class AppFailure implements Exception {
  const AppFailure(this.kind, this.message, {this.debugCode});

  /// Converte qualquer [Object] (Postgrest/Auth/Storage/Socket/Timeout/...)
  /// em uma [AppFailure] humana e sanitizada.
  factory AppFailure.from(Object error) => _classify(error);

  final AppFailureKind kind;

  /// Texto em pt-BR, sem PII/stack/SQL.
  final String message;

  /// Código técnico curto e sanitizado (ex.: `23505`, `PIN_LOCKED`).
  final String? debugCode;

  /// Vale a pena oferecer "tentar novamente"?
  bool get isRetryable =>
      kind == AppFailureKind.network ||
      kind == AppFailureKind.timeout ||
      kind == AppFailureKind.server ||
      kind == AppFailureKind.rateLimited;

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      other is AppFailure &&
      other.kind == kind &&
      other.message == message &&
      other.debugCode == debugCode;

  @override
  int get hashCode => Object.hash(kind, message, debugCode);
}

/// Resultado de uma operação: sucesso com valor ou [AppFailure].
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.fail(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isFailure => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) fail,
  }) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => fail(failure),
      };

  Result<R> map<R>(R Function(T value) f) => switch (this) {
        Ok<T>(:final value) => Result<R>.ok(f(value)),
        Err<T>(:final failure) => Result<R>.fail(failure),
      };

  /// Executa [body] convertendo qualquer exceção em [Err] humano.
  static Future<Result<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Result<T>.ok(await body());
    } catch (e) {
      return Result<T>.fail(AppFailure.from(e));
    }
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// Mensagem humana para qualquer erro; nunca vaza SQL/stack/PII.
///
/// Substituto seguro para `friendlyError` (que deve delegar aqui).
String humanizeError(Object error) => AppFailure.from(error).message;

/// Mensagem genérica final.
const String kGenericFailureMessage =
    'Algo deu errado. Tente novamente em instantes.';

/// Códigos de negócio levantados pelas RPCs/triggers do banco (`raise
/// exception 'CODIGO'`) → texto humano. Prefixos são casados por `contains`.
const Map<String, String> _kBusinessMessages = {
  'QUOTE_LIMIT_REACHED': 'Esta demanda já recebeu 3 orçamentos.',
  'PIN_LOCKED': 'Muitas tentativas. Use "Tive um problema".',
  'INSUFFICIENT_FUNDS': 'Saldo insuficiente para concluir esta ação.',
  'JOB_NOT_OPEN': 'Este pedido não está mais aberto.',
  'JOB_ALREADY_ASSIGNED': 'Este pedido já foi atribuído a outro profissional.',
  'INVALID_STATE': 'Esta ação não está mais disponível para o estado atual do pedido.',
  'INVALID_TRANSITION': 'Esta ação não está mais disponível para o estado atual do pedido.',
  'NOT_AUTHORIZED': 'Você não tem permissão para esta ação.',
  'ALREADY_REVIEWED': 'Você já avaliou este serviço.',
  'DUPLICATE_REQUEST': 'Esta solicitação já foi enviada.',
};

final RegExp _kBusinessCode = RegExp(r'\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b');
final RegExp _kPinInvalid = RegExp(r'PIN_INVALID(?::\s*(\d+))?');

/// Constrói a falha a partir do texto de [error] sem depender dos tipos do
/// Supabase (mantém este arquivo livre de pacotes e testável).
AppFailure _classify(Object error) {
  if (error is AppFailure) return error;
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // Dart/HTTP de rede (nomes de tipo, sem importar dart:io).
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection closed') ||
      lower.contains('connection reset') ||
      lower.contains('handshakeexception') ||
      lower.contains('xmlhttprequest error')) {
    return const AppFailure(
      AppFailureKind.network,
      'Sem conexão. Verifique sua internet e tente novamente.',
      debugCode: 'NETWORK',
    );
  }
  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return const AppFailure(
      AppFailureKind.timeout,
      'A conexão demorou demais. Tente novamente.',
      debugCode: 'TIMEOUT',
    );
  }

  // PIN com contagem de tentativas.
  final pin = _kPinInvalid.firstMatch(raw);
  if (pin != null) {
    final left = pin.group(1);
    return AppFailure(
      AppFailureKind.business,
      left == null || left.isEmpty
          ? 'PIN incorreto.'
          : 'PIN incorreto. Restam $left tentativa(s).',
      debugCode: 'PIN_INVALID',
    );
  }

  // Códigos de negócio conhecidos.
  for (final entry in _kBusinessMessages.entries) {
    if (raw.contains(entry.key)) {
      return AppFailure(AppFailureKind.business, entry.value, debugCode: entry.key);
    }
  }

  // Auth.
  if (lower.contains('invalid login credentials')) {
    return const AppFailure(
      AppFailureKind.unauthenticated,
      'E-mail ou senha incorretos.',
      debugCode: 'AUTH_INVALID_CREDENTIALS',
    );
  }
  if (lower.contains('email not confirmed')) {
    return const AppFailure(
      AppFailureKind.unauthenticated,
      'Confirme seu e-mail para entrar.',
      debugCode: 'AUTH_EMAIL_NOT_CONFIRMED',
    );
  }
  if (lower.contains('jwt expired') ||
      lower.contains('sessão expirada') ||
      lower.contains('session expired') ||
      lower.contains('not authenticated') ||
      lower.contains('invalid jwt') ||
      lower.contains('refresh_token')) {
    return const AppFailure(
      AppFailureKind.unauthenticated,
      'Sua sessão expirou. Entre novamente.',
      debugCode: 'AUTH_EXPIRED',
    );
  }
  if (lower.contains('too many requests') ||
      lower.contains('rate limit') ||
      lower.contains('over_email_send_rate_limit') ||
      RegExp(r'status(?:code)?[:=]\s*429').hasMatch(lower)) {
    return const AppFailure(
      AppFailureKind.rateLimited,
      'Muitas tentativas seguidas. Aguarde um instante e tente de novo.',
      debugCode: 'RATE_LIMITED',
    );
  }

  // Postgres SQLSTATE (code: 23505 etc.).
  final sqlState = RegExp(r'code[:=]\s*[\x27"]?([0-9A-Z]{5})\b').firstMatch(raw)?.group(1);
  switch (sqlState) {
    case '23505':
      return const AppFailure(
        AppFailureKind.conflict,
        'Esse registro já existe.',
        debugCode: '23505',
      );
    case '23503':
      return const AppFailure(
        AppFailureKind.conflict,
        'Não foi possível concluir: há informações relacionadas pendentes.',
        debugCode: '23503',
      );
    case '23514':
    case '23502':
    case '22P02':
    case '22001':
      return AppFailure(
        AppFailureKind.validation,
        'Alguma informação enviada é inválida. Confira os campos e tente de novo.',
        debugCode: sqlState,
      );
    case '42501':
      return const AppFailure(
        AppFailureKind.forbidden,
        'Você não tem permissão para esta ação.',
        debugCode: '42501',
      );
  }
  if (lower.contains('row-level security') || lower.contains('permission denied')) {
    return const AppFailure(
      AppFailureKind.forbidden,
      'Você não tem permissão para esta ação.',
      debugCode: 'RLS',
    );
  }
  if (RegExp(r'status(?:code)?[:=]\s*404').hasMatch(lower)) {
    return const AppFailure(
      AppFailureKind.notFound,
      'Não encontramos o que você procurava.',
      debugCode: 'NOT_FOUND',
    );
  }
  if (lower.contains('storageexception') || lower.contains('bucket')) {
    return const AppFailure(
      AppFailureKind.media,
      'Não foi possível enviar o arquivo. Tente novamente.',
      debugCode: 'STORAGE',
    );
  }

  // Qualquer coisa com cara de SQL/stack/infra → genérico.
  // Exceções do Supabase (`PostgrestException(message: X, code: P0001 ...)`):
  // só o `message` interessa, e só se for texto humano (RAISE EXCEPTION do
  // nosso banco, em pt-BR). Detalhes/hints/SQL jamais saem daqui.
  final extracted = _kSupabaseMessage.firstMatch(raw)?.group(1)?.trim();
  final candidate = _stripPrefix(extracted ?? raw);

  if (_looksTechnical(candidate)) {
    return AppFailure(
      AppFailureKind.server,
      kGenericFailureMessage,
      debugCode: _kBusinessCode.firstMatch(candidate)?.group(0),
    );
  }

  // Mensagem curta, escrita por nós em pt-BR (ex.: `Exception('Informe o CEP')`).
  if (candidate.isNotEmpty && candidate.length <= 140 && !_containsPii(candidate)) {
    return AppFailure(AppFailureKind.unknown, candidate);
  }
  return const AppFailure(AppFailureKind.unknown, kGenericFailureMessage);
}

final RegExp _kSupabaseMessage = RegExp(r'message[:=]\s*([^,}\n)]+)');

String _stripPrefix(String raw) {
  var s = raw.trim();
  for (final p in const ['Exception: ', 'Bad state: ', 'Invalid argument(s): ', 'FormatException: ']) {
    if (s.startsWith(p)) s = s.substring(p.length);
  }
  return s.trim();
}

bool _looksTechnical(String raw) {
  final l = raw.toLowerCase();
  return raw.contains('\n#0') ||
      raw.contains('package:') ||
      raw.contains('dart:') ||
      l.contains('postgrestexception') ||
      l.contains('authexception') ||
      l.contains('authapiexception') ||
      l.contains('functionexception') ||
      l.contains('realtimesubscribeexception') ||
      l.contains('violates') ||
      l.contains('syntax error') ||
      l.contains('relation "') ||
      l.contains('column "') ||
      l.contains('constraint') ||
      l.contains('select ') ||
      l.contains('insert into') ||
      (l.contains('update ') && l.contains(' set ')) ||
      l.contains('pgrst') ||
      l.contains('typeerror') ||
      l.contains('nosuchmethod') ||
      l.contains('null check operator') ||
      l.contains('is not a subtype') ||
      l.contains('instance of ') ||
      l.contains('http://') ||
      l.contains('https://') ||
      l.contains('eyj'); // prefixo base64 de JWT
}

final RegExp _kEmail = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final RegExp _kLongDigits = RegExp(r'\d{3}[.\s-]?\d{3}[.\s-]?\d{3}[.\s-]?\d{2}|\(?\d{2}\)?\s?9?\d{4}[-\s]?\d{4}');

bool _containsPii(String s) => _kEmail.hasMatch(s) || _kLongDigits.hasMatch(s);

/// Remove PII/segredos de um texto antes de logar.
///
/// Mascara e-mails, CPF, telefones, JWT/Bearer e pares lat/lng com ≥4 casas.
String redactForLog(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), 'Bearer [token]');
  s = s.replaceAll(RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*'), '[jwt]');
  s = s.replaceAll(_kEmail, '[email]');
  s = s.replaceAll(RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'), '[cpf]');
  s = s.replaceAll(RegExp(r'\(?\b\d{2}\)?\s?9?\d{4}[-\s]?\d{4}\b'), '[tel]');
  s = s.replaceAll(RegExp(r'-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}'), '[coord]');
  return s;
}

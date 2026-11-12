import 'dart:async';
import 'dart:math' as math;

/// Backoff exponencial com jitter: 1s, 2s, 4s, 8s, 16s, 30s, 30s...
///
/// O jitter (±20%) evita que milhares de aparelhos reconectem no mesmo
/// instante após uma queda do Realtime (thundering herd).
Duration defaultReconnectBackoff(int attempt, [math.Random? random]) {
  final capped = math.min(attempt, 5);
  final baseMs = math.min(1000 * (1 << capped), 30000);
  final r = random ?? _rng;
  final jitter = 0.8 + r.nextDouble() * 0.4;
  return Duration(milliseconds: (baseMs * jitter).round());
}

final math.Random _rng = math.Random();

/// Envolve um stream "frágil" (Supabase Realtime) com reconexão automática.
///
/// * Se o stream emitir erro ou fechar sozinho, reassina após backoff
///   exponencial ([defaultReconnectBackoff]); o contador zera ao receber um
///   evento de dados.
/// * Erros são repassados ao ouvinte (a UI pode mostrar "reconectando"), mas o
///   stream continua vivo.
/// * Sem ouvintes = sem assinatura e sem timer (zero leak): ao cancelar o
///   último ouvinte, assinatura e timer pendente são encerrados.
/// * Se [factory] lançar de forma síncrona, também conta como falha e retenta.
Stream<T> resilientStream<T>(
  Stream<T> Function() factory, {
  Duration Function(int attempt)? backoff,
  bool broadcast = true,
  int? maxConsecutiveFailures,
}) {
  final delayFor = backoff ?? defaultReconnectBackoff;
  late StreamController<T> controller;
  StreamSubscription<T>? sub;
  Timer? timer;
  var attempt = 0;
  var active = false;

  late void Function() scheduleRetry;

  void connect() {
    if (!active || controller.isClosed) return;
    try {
      sub = factory().listen(
        (event) {
          attempt = 0;
          if (!controller.isClosed) controller.add(event);
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
          scheduleRetry();
        },
        onDone: scheduleRetry,
        cancelOnError: true,
      );
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
      scheduleRetry();
    }
  }

  scheduleRetry = () {
    final old = sub;
    sub = null;
    if (old != null) unawaited(old.cancel());
    if (!active || controller.isClosed) return;
    if (timer?.isActive ?? false) return; // já agendado (erro + done juntos)
    if (maxConsecutiveFailures != null && attempt >= maxConsecutiveFailures) {
      unawaited(controller.close());
      return;
    }
    final d = delayFor(attempt);
    attempt++;
    timer = Timer(d, connect);
  };

  Future<void> teardown() async {
    active = false;
    timer?.cancel();
    timer = null;
    final s = sub;
    sub = null;
    await s?.cancel();
  }

  void start() {
    active = true;
    attempt = 0;
    connect();
  }

  controller = broadcast
      ? StreamController<T>.broadcast(onListen: start, onCancel: teardown)
      : StreamController<T>(onListen: start, onCancel: teardown);
  return controller.stream;
}

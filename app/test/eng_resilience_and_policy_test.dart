import 'dart:async';

import 'package:desperrengue_app/core/services/draft_store.dart';
import 'package:desperrengue_app/core/utils/resilient_stream.dart';
import 'package:desperrengue_app/features/auth/presentation/deep_link_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resilientStream (reconexão com backoff)', () {
    test('reassina após erro e continua entregando eventos', () async {
      var subscriptions = 0;
      final attempts = <int>[];
      final s = resilientStream<int>(
        () {
          subscriptions++;
          if (subscriptions == 1) {
            return Stream<int>.error(StateError('realtime caiu'));
          }
          return Stream<int>.fromIterable([1, 2, 3]);
        },
        backoff: (a) {
          attempts.add(a);
          return const Duration(milliseconds: 5);
        },
      );
      final got = <int>[];
      final errors = <Object>[];
      final done = Completer<void>();
      final sub = s.listen(got.add, onError: errors.add);
      Timer(const Duration(milliseconds: 200), () => done.complete());
      await done.future;
      await sub.cancel();
      expect(errors, hasLength(1));
      expect(got.take(3), [1, 2, 3]);
      expect(attempts.first, 0);
    });

    test('reassina quando o stream fecha sozinho e zera o contador ao receber dado', () async {
      var n = 0;
      final attempts = <int>[];
      final s = resilientStream<int>(
        () => Stream<int>.fromIterable([++n]),
        backoff: (a) {
          attempts.add(a);
          return const Duration(milliseconds: 3);
        },
      );
      final got = <int>[];
      final sub = s.listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await sub.cancel();
      expect(got.length, greaterThan(3));
      expect(attempts.every((a) => a == 0), isTrue, reason: 'dado recebido zera o backoff');
    });

    test('backoff cresce exponencialmente com teto de 30s', () {
      final ms = [for (var i = 0; i < 9; i++) defaultReconnectBackoff(i).inMilliseconds];
      expect(ms[0], inInclusiveRange(800, 1200));
      expect(ms[1], inInclusiveRange(1600, 2400));
      expect(ms[2], inInclusiveRange(3200, 4800));
      for (final v in ms.skip(5)) {
        expect(v, inInclusiveRange(24000, 36000));
      }
    });

    test('cancelar o último ouvinte encerra assinatura e timer (sem leak)', () async {
      var live = 0;
      var created = 0;
      late StreamController<int> inner;
      final s = resilientStream<int>(
        () {
          created++;
          inner = StreamController<int>(
            onListen: () => live++,
            onCancel: () => live--,
          );
          return inner.stream;
        },
        backoff: (_) => const Duration(milliseconds: 5),
      );
      final sub = s.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(live, 1);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(live, 0);
      expect(created, 1, reason: 'nenhuma reconexão após cancelar');
    });

    test('factory que lança é tratada como falha e retentada', () async {
      var calls = 0;
      final s = resilientStream<int>(
        () {
          calls++;
          if (calls < 3) throw StateError('boom');
          return Stream<int>.value(42);
        },
        backoff: (_) => const Duration(milliseconds: 3),
      );
      final first = Completer<int>();
      final sub = s.listen(first.complete, onError: (_) {});
      expect(await first.future.timeout(const Duration(seconds: 2)), 42);
      await sub.cancel();
      expect(calls, greaterThanOrEqualTo(3));
    });

    test('maxConsecutiveFailures fecha o stream', () async {
      final s = resilientStream<int>(
        () => Stream<int>.error(StateError('x')),
        backoff: (_) => const Duration(milliseconds: 2),
        maxConsecutiveFailures: 3,
      );
      final done = Completer<void>();
      s.listen((_) {}, onError: (_) {}, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 2));
    });
  });

  group('DeepLinkPolicy', () {
    test('aceita só desperrengue://onboarding', () {
      expect(DeepLinkPolicy.isTrustedOnboardingLink(Uri.parse('desperrengue://onboarding')), isTrue);
      expect(DeepLinkPolicy.isTrustedOnboardingLink(Uri.parse('desperrengue://onboarding/approved')), isTrue);
      expect(DeepLinkPolicy.isTrustedOnboardingLink(Uri.parse('DESPERRENGUE://Onboarding/x?ref=email')), isTrue);
    });

    test('rejeita outros esquemas, hosts, userinfo, porta e caminhos suspeitos', () {
      for (final u in [
        'https://onboarding/x',
        'desperrengue://admin',
        'desperrengue://onboarding.evil.com',
        'desperrengue://user:pw@onboarding',
        'desperrengue://onboarding:8080/x',
        'desperrengue://onboarding/a/b/c/d/e',
        'desperrengue://onboarding/%3Cscript%3E',
        'desperrengue://onboarding/x?access_token=abc',
        'desperrengue://onboarding/x?CPF=123',
        'javascript:alert(1)',
      ]) {
        expect(DeepLinkPolicy.isTrustedOnboardingLink(Uri.parse(u)), isFalse, reason: u);
      }
      expect(
        DeepLinkPolicy.isTrustedOnboardingLink(Uri.parse('desperrengue://onboarding/${'a' * 600}')),
        isFalse,
      );
    });

    test('throttle de refresh', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(DeepLinkPolicy.shouldRefresh(lastRefresh: null, now: t0), isTrue);
      expect(DeepLinkPolicy.shouldRefresh(lastRefresh: t0, now: t0.add(const Duration(milliseconds: 500))), isFalse);
      expect(DeepLinkPolicy.shouldRefresh(lastRefresh: t0, now: t0.add(const Duration(seconds: 2))), isTrue);
    });
  });

  group('DraftStore (LGPD)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DraftStore.now = DateTime.now;
    });

    test('rascunho expira em 7 dias e é apagado ao ler', () async {
      final key = DraftStore.keyFor('client_setup', userId: 'u1');
      final t0 = DateTime(2026, 5, 1, 10);
      DraftStore.now = () => t0;
      await DraftStore.write(key, {'cpf': '123', 'step': 2});
      DraftStore.now = () => t0.add(const Duration(days: 6, hours: 23));
      final fresh = await DraftStore.read(key);
      expect(fresh, {'cpf': '123', 'step': 2}, reason: 'carimbo interno não vaza para o chamador');
      DraftStore.now = () => t0.add(const Duration(days: 7, minutes: 1));
      expect(await DraftStore.read(key), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(key), isFalse);
    });

    test('clearAllForUser apaga só os rascunhos daquele usuário', () async {
      final a1 = DraftStore.keyFor('client_setup', userId: 'a');
      final a2 = DraftStore.keyFor('kyc_registro', userId: 'a');
      final b1 = DraftStore.keyFor('client_setup', userId: 'b');
      await DraftStore.write(a1, {'x': 1});
      await DraftStore.write(a2, {'x': 2});
      await DraftStore.write(b1, {'x': 3});
      await DraftStore.clearAllForUser('a');
      expect(await DraftStore.read(a1), isNull);
      expect(await DraftStore.read(a2), isNull);
      expect(await DraftStore.read(b1), {'x': 3});
    });

    test('rascunho legado (sem carimbo) continua legível', () async {
      final key = DraftStore.keyFor('legacy', userId: 'u');
      SharedPreferences.setMockInitialValues({key: '{"name":"Wagner"}'});
      expect(await DraftStore.read(key), {'name': 'Wagner'});
    });
  });
}

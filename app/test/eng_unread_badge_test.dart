import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/state/unread_orders_badge_controller.dart';
import 'package:desperrengue_app/core/utils/order_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Job _job(String id, {JobStatus status = JobStatus.completed}) => Job(
      id: id,
      clientId: 'c',
      title: 't',
      description: 'd',
      category: 'x',
      status: status,
      paymentStatus: 'none',
      urgency: 'normal',
      visibility: 'public',
      addressSummary: 'Centro',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rajada de markViewed persiste TODAS as assinaturas (escritas coalescidas)', () async {
    final c = UnreadOrdersBadgeController(currentUserIdResolver: () => 'u1');
    final jobs = [for (var i = 0; i < 60; i++) _job('job-$i')];
    final futures = [for (final j in jobs) c.markViewed(j)];
    // O badge cai de forma síncrona, antes de qualquer I/O.
    expect(c.countUnread(OrderTab.completed, jobs), 0);
    await Future.wait(futures);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('carbon_viewed_orders_v1_u1')!;
    expect(stored.length, 60);

    // Novo controller (cold start) hidrata o mesmo estado.
    final c2 = UnreadOrdersBadgeController(currentUserIdResolver: () => 'u1');
    await c2.ensureLoaded();
    expect(c2.countUnread(OrderTab.completed, jobs), 0);
  });

  test('memória e disco ficam limitados a 1000 assinaturas por usuário', () async {
    final c = UnreadOrdersBadgeController(currentUserIdResolver: () => 'u2');
    final futures = [
      for (var i = 0; i < 1100; i++) c.markViewed(_job('j$i')),
    ];
    await Future.wait(futures);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('carbon_viewed_orders_v1_u2')!.length, 1000);
    // As mais antigas foram descartadas (voltam a ser "não lidas"), as novas seguem lidas.
    expect(c.isUnread(_job('j0')), isTrue);
    expect(c.isUnread(_job('j1099')), isFalse);
  });

  test('usuários diferentes não compartilham leituras', () async {
    final a = UnreadOrdersBadgeController(currentUserIdResolver: () => 'a');
    final j = _job('x1');
    await a.markViewed(j);
    expect(a.isUnread(j), isFalse);
    expect(a.isUnread(j, userId: 'b'), isTrue);
  });

  test('mudança de status/preço volta a notificar', () async {
    final c = UnreadOrdersBadgeController(currentUserIdResolver: () => 'u3');
    final open = _job('p1', status: JobStatus.open);
    await c.markViewed(open);
    expect(c.isUnread(open), isFalse);
    expect(c.isUnread(_job('p1', status: JobStatus.scheduled)), isTrue);
  });
}

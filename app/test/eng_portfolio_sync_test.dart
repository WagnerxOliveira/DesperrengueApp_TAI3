import 'dart:async';
import 'dart:convert';

import 'package:desperrengue_app/core/state/provider_portfolio_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

String _b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

String _jwt() {
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.${_b64({'sub': 'u1', 'exp': exp, 'role': 'authenticated'})}.sig';
}

class _SlowRpcClient extends http.BaseClient {
  int rpcCalls = 0;
  int concurrent = 0;
  int peak = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('provider_full_service_history')) {
      rpcCalls++;
      concurrent++;
      if (concurrent > peak) peak = concurrent;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      concurrent--;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('syncFromSupabase concorrente é coalescido (1 em voo + no máximo 1 repetição)', () async {
    final fake = _SlowRpcClient();
    final client = SupabaseClient('http://localhost:54321', 'anon', httpClient: fake);
    final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    await client.auth.recoverSession(jsonEncode({
      'access_token': _jwt(),
      'token_type': 'bearer',
      'expires_in': 7200,
      'expires_at': exp,
      'refresh_token': 'r',
      'user': {
        'id': 'u1',
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    }));
    expect(client.auth.currentUser?.id, 'u1');

    final store = ProviderPortfolioStore.instance;
    final calls = <Future<void>>[for (var i = 0; i < 10; i++) store.syncFromSupabase(client)];
    expect(store.isSyncing, isTrue);
    await Future.wait(calls);

    expect(fake.peak, 1, reason: 'nunca duas sincronizações simultâneas');
    expect(fake.rpcCalls, lessThanOrEqualTo(2), reason: '10 pedidos => 1 execução + 1 repetição');
    expect(store.isSyncing, isFalse);

    // Depois de terminar, uma nova chamada volta a executar normalmente.
    await store.syncFromSupabase(client);
    expect(fake.rpcCalls, greaterThanOrEqualTo(2));
    await client.dispose();
  });
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rascunhos locais de cadastro: o que o usuário já digitou fica salvo neste
/// aparelho (por conta) para ele continuar de onde parou. Nunca guarda fotos
/// nem documentos — só texto simples dos formulários.
///
/// LGPD: rascunhos podem conter CPF/telefone/endereço digitados. Por isso:
///  * expiram sozinhos em [maxAge] (7 dias) — ao ler, expirado é apagado;
///  * são apagados ao sair da conta ([clearAllForUser], chamado pelo AuthGate);
///  * conteúdo antigo sem carimbo de data continua legível (compatibilidade).
class DraftStore {
  DraftStore._();

  static const _prefix = 'draft.v1';
  static const _stampKey = '_savedAt';

  /// Validade do rascunho.
  static const Duration maxAge = Duration(days: 7);

  /// Relógio injetável para testes.
  static DateTime Function() now = DateTime.now;

  /// Chave por usuário autenticado (rascunhos de contas diferentes não se misturam).
  static String keyFor(String name, {String? userId}) {
    final uid = userId ?? Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return '$_prefix.$uid.$name';
  }

  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final v = jsonDecode(raw);
      if (v is! Map<String, dynamic>) return null;
      final stamp = v[_stampKey];
      if (stamp is int) {
        final age = now().millisecondsSinceEpoch - stamp;
        if (age > maxAge.inMilliseconds) {
          await prefs.remove(key);
          return null;
        }
      }
      return Map<String, dynamic>.of(v)..remove(_stampKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Map<String, dynamic> data) async {
    try {
      final stamped = <String, dynamic>{...data, _stampKey: now().millisecondsSinceEpoch};
      await (await SharedPreferences.getInstance()).setString(key, jsonEncode(stamped));
    } catch (_) {
      // Rascunho é conveniência: falhar não pode atrapalhar o cadastro.
    }
  }

  static Future<void> clear(String key) async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }

  /// Apaga todos os rascunhos de [userId] (logout / exclusão de conta).
  static Future<void> clearAllForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final start = '$_prefix.$userId.';
      for (final k in prefs.getKeys().where((k) => k.startsWith(start)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

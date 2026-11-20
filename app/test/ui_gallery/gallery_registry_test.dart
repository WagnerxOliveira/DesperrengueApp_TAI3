import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'gallery_registry.dart';
import 'golden_gallery_test.dart' show kGoldenScreenIds;

/// Sanidade do registro: ids únicos e estáveis, `source` existente em `lib/`,
/// onda 0–6, dono conhecido. Imprime o resumo por onda/dono (contagem de telas).
void main() {
  const owners = <String>{'auth_ui', 'client_core_ui', 'client_orders_ui', 'provider_ui', 'shared_ui', 'foundation'};

  test('registro: ids únicos, source existente, onda e dono válidos', () {
    final screens = galleryScreens();
    final ids = <String>{};
    for (final s in screens) {
      expect(ids.add(s.id), isTrue, reason: 'id duplicado: ${s.id}');
      expect(
        RegExp(r'^[a-z0-9_]+/[a-z0-9_]+$').hasMatch(s.id),
        isTrue,
        reason: 'id fora do padrão grupo/nome: ${s.id}',
      );
      expect(s.wave, inInclusiveRange(0, 6), reason: '${s.id}: onda inválida');
      expect(owners.contains(s.owner), isTrue, reason: '${s.id}: dono desconhecido ${s.owner}');
      expect(s.modes, isNotEmpty, reason: '${s.id}: sem modos');
      expect(File('lib/${s.source}').existsSync(), isTrue, reason: '${s.id}: source inexistente ${s.source}');
    }
    final byWave = <int, int>{};
    final byOwner = <String, int>{};
    for (final s in screens) {
      byWave[s.wave] = (byWave[s.wave] ?? 0) + 1;
      byOwner[s.owner] = (byOwner[s.owner] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('GALERIA registro: ${screens.length} entradas | por onda $byWave | por dono $byOwner');

    for (final gid in kGoldenScreenIds) {
      expect(ids.contains(gid), isTrue, reason: 'golden id inexistente no registro: $gid');
    }
  });
}

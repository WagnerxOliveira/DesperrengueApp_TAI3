import 'package:flutter_test/flutter_test.dart';

import 'checks.dart';
import 'fakes.dart';
import 'pump.dart';
import 'ratchet.dart';
import 'viewports.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';

/// Define uma suíte da galeria: UM `testWidgets` por tela registrada; cada um
/// monta a tela em todas as variantes de [variants], roda [check] e confere o
/// ratchet (`test/ui_design_audit/baseline/<suite>.json`).
void defineGallerySuite({
  required String suite,
  required List<GalleryScreen> screens,
  required List<GalleryVariant> Function(UserMode? mode) variants,
  required List<String> rules,
  required void Function(GalleryRun run, ViolationLog log) check,
  String label = '',
}) {
  final ratchet = Ratchet(suite);
  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);
  tearDownAll(ratchet.finish);

  for (final screen in screens) {
    if (screen.skipRules.length >= rules.length && rules.every(screen.skipRules.contains)) continue;
    testWidgets('${label.isEmpty ? suite : label} · ${screen.id}', (tester) async {
      final log = ViolationLog();
      for (final mode in screen.modes) {
        for (final variant in variants(mode)) {
          await withGalleryRun(tester, screen, variant, (run) async {
            check(run, log);
          });
        }
      }
      ratchet.verify(screen.id, log, rules.where((r) => !screen.skipRules.contains(r)));
    });
  }
}

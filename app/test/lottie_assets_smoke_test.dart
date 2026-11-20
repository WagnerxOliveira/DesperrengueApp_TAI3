import 'package:desperrengue_app/core/ui/typography/font_licenses.dart';
import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const _lotties = <String>[
  'assets/lottie/check_burst.json',
  'assets/lottie/lock_close.json',
  'assets/lottie/sparkle_soft.json',
];

const _fonts = <String>[
  'assets/fonts/PlusJakartaSans-Bold.ttf',
  'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  'assets/fonts/Inter-Regular.ttf',
  'assets/fonts/Inter-Medium.ttf',
  'assets/fonts/Inter-SemiBold.ttf',
  'assets/fonts/Inter-Bold.ttf',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final asset in _lotties) {
    test('$asset: <= 25 KB, 60 fps, nao-loop e parseavel', () async {
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      expect(bytes.lengthInBytes, lessThanOrEqualTo(25 * 1024));
      final comp = await LottieComposition.fromBytes(bytes);
      expect(comp.frameRate, 60);
      expect(comp.duration.inMilliseconds, inInclusiveRange(1100, 1700));
      expect(comp.layers, isNotEmpty);
    });

    testWidgets('$asset: Lottie.asset renderiza com controller sem erro', (tester) async {
      final controller = AnimationController(vsync: tester, duration: const Duration(milliseconds: 1400));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Lottie.asset(asset, controller: controller, repeat: false),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final v in <double>[0, 0.25, 0.5, 0.75, 1]) {
        controller.value = v;
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(LottieBuilder), findsOneWidget);
    });
  }

  test('fontes embarcadas existem e somam <= 450 KB', () async {
    var total = 0;
    for (final f in _fonts) {
      final data = await rootBundle.load(f);
      expect(data.lengthInBytes, greaterThan(10000), reason: f);
      total += data.lengthInBytes;
    }
    expect(total, lessThanOrEqualTo(450 * 1024));
  });

  test('licencas OFL embarcadas e registradas no LicenseRegistry', () async {
    registerCinemaFontLicenses();
    registerCinemaFontLicenses(); // idempotente
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }
    expect(packages, containsAll(<String>['Plus Jakarta Sans', 'Inter']));
    for (final path in cinemaFontLicenseAssets.values) {
      expect(await rootBundle.loadString(path), contains('SIL OPEN FONT LICENSE'));
    }
  });
}

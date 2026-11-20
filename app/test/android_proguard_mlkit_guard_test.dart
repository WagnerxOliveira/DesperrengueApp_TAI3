import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guarda Estático R8 / ProGuard — Google ML Kit & CameraX em APKs release', () {
    test('android/app/proguard-rules.pro preserva ML Kit Face, Text, Barcode, ComponentRegistrar e CameraX', () {
      final File proguardFile = File('android/app/proguard-rules.pro');
      expect(
        proguardFile.existsSync(),
        isTrue,
        reason: 'Arquivo android/app/proguard-rules.pro não encontrado.',
      );

      final String content = proguardFile.readAsStringSync();
      const List<String> requiredDirectives = <String>[
        '-keep class com.google.mlkit.** { *; }',
        '-keep class * implements com.google.firebase.components.ComponentRegistrar',
        'public <init>();',
        '-keep class com.google.android.gms.vision.** { *; }',
        '-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }',
        '-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }',
        '-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }',
        '-keep class com.google.android.gms.internal.mlkit_common.** { *; }',
        '-keep class com.google_mlkit_face_detection.** { *; }',
        '-keep class com.google_mlkit_commons.** { *; }',
        '-keep class androidx.camera.** { *; }',
        '-keep class io.flutter.plugins.camerax.** { *; }',
      ];

      for (final directive in requiredDirectives) {
        expect(
          content,
          contains(directive),
          reason:
              'Regra R8/ProGuard obrigatória ausente em android/app/proguard-rules.pro: "$directive". '
              'Sem ela o Google ML Kit falha silenciosamente em builds APK --release!',
        );
      }
    });

    test('android/app/build.gradle.kts referencia proguard-rules.pro no buildType release', () {
      final File gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final String content = gradleFile.readAsStringSync();
      expect(content, contains('proguard-rules.pro'));
      expect(content, contains('proguard-android-optimize.txt'));
    });
  });
}

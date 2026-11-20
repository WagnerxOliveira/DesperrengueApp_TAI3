# Google ML Kit Text Recognition (usamos apenas TextRecognitionScript.latin no Brasil).
# Os scripts opcionais CJK/Devanagari nao sao empacotados no APK para manter o binario leve,
# mas com.google_mlkit_text_recognition.TextRecognizer.initialize() referencia suas classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- Google ML Kit (Face Detection, Text Recognition Latin, Barcode Scanning) ---
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Preserva todos os ComponentRegistrars do ML Kit / Firebase (evita NoSuchMethodException em R8 Full Mode)
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
-keep class com.google.firebase.components.** { *; }

# Preserva classes internas JNI / Vision / modelos embarcados do ML Kit
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_bundled_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.libraries.vision.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_barcode_scanning.** { *; }

-dontwarn com.google.android.gms.internal.mlkit_**
-dontwarn com.google.android.libraries.vision.**

# CameraX & Flutter Camera Plugin
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.camerax.** { *; }

# Atributos necessarios para reflection / JNI / Pigeon
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

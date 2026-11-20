# Google ML Kit Text Recognition (usamos apenas TextRecognitionScript.latin no Brasil).
# Os scripts opcionais CJK/Devanagari nao sao empacotados no APK para manter o binario leve,
# mas com.google_mlkit_text_recognition.TextRecognizer.initialize() referencia suas classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

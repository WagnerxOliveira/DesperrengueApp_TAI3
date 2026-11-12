import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Executa [task] fora da thread de UI quando a plataforma permite.
///
/// * Android/iOS/desktop: `Isolate.run` (decodificação, dHash, PDF, OCR
///   matemático ficam longe do raster/UI thread → 120 FPS).
/// * Web (`kIsWeb`) ou plataforma sem isolates: executa inline (equivalente ao
///   `compute` do Flutter na Web) em vez de explodir com `UnsupportedError`.
///
/// O [task] deve capturar apenas dados enviáveis entre isolates (bytes,
/// números, strings, records, listas) — nada de BuildContext/controllers.
Future<T> runOffMainThread<T>(FutureOr<T> Function() task) async {
  if (kIsWeb) return task();
  try {
    return await Isolate.run<T>(task);
  } on UnsupportedError {
    return task();
  }
}

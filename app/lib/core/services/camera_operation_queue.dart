import 'dart:async';

import 'package:camera/camera.dart';

/// Fila FIFO estritamente serializada para comandos nativos do [CameraController].
///
/// Evita chamadas concorrentes entre `startImageStream`, `stopImageStream`,
/// `takePicture`, `setFlashMode` e `dispose`, eliminando deadlocks e atrasos
/// documentados na renegociação de `CaptureSession` em Android CameraX
/// (Motorola, Xiaomi/MIUI/HyperOS, Pixel, Samsung, Oppo/Realme) e iOS
/// `AVCaptureSession`.
class CameraOperationQueue {
  Future<void> _tail = Future<void>.value();

  /// Enfileira [operation] para execução exclusiva em ordem FIFO.
  /// Erros em uma operação jamais travam as operações subsequentes da fila.
  Future<T> enqueue<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        final T result = await operation();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }

  /// Para o stream de vídeo de forma serializada, aguarda [graceDelay] para
  /// drenar os buffers nativos do pipeline CameraX / AVFoundation e captura a
  /// foto com guarda de [timeout] (evitando travamento infinito em drivers OEM).
  Future<XFile> capturePhotoAfterStreamStop(
    CameraController controller, {
    Duration graceDelay = const Duration(milliseconds: 180),
    Duration timeout = const Duration(seconds: 4),
    bool stopStreamIfActive = true,
  }) {
    return enqueue<XFile>(() async {
      if (stopStreamIfActive && controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
        if (graceDelay > Duration.zero) {
          await Future<void>.delayed(graceDelay);
        }
      }
      return controller.takePicture().timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'ERR_CAMERA_CAPTURE_TIMEOUT: Camera takePicture timed out after '
              '${timeout.inMilliseconds}ms.',
            ),
          );
    });
  }
}

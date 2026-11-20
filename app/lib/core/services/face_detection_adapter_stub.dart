import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'face_detection_adapter.dart';

/// Adaptador stub para ambientes sem câmera/motor biométrico (ex.: testes headless).
/// Jamais aprova ou simula detecção facial sem observações reais injetadas.
class StubFaceDetectionAdapter implements FaceDetectionAdapter {
  @override
  bool get isSupported => false;

  @override
  bool get isInitialized => false;

  @override
  String? get unavailableReason =>
      'A verificação facial ao vivo não está disponível neste dispositivo.';

  @override
  Future<bool> initialize() async => false;

  @override
  Future<LiveFaceObservation?> analyzeCameraImage(
    CameraImage image, {
    required int sensorOrientation,
    required bool isFrontCamera,
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) async {
    return LiveFaceObservation.unavailable(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      reason: unavailableReason!,
      sourceEngine: 'stub',
    );
  }

  @override
  Future<LiveFaceObservation?> analyzeWebVideoFrame({
    bool mirrorHorizontal = true,
  }) async {
    return LiveFaceObservation.unavailable(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      reason: unavailableReason!,
      sourceEngine: 'stub',
    );
  }

  @override
  Future<void> dispose() async {}
}

FaceDetectionAdapter createPlatformFaceDetectionAdapter() =>
    StubFaceDetectionAdapter();

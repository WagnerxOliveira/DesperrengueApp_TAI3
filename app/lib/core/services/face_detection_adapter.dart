import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show DeviceOrientation;

import 'face_detection_adapter_stub.dart'
    if (dart.library.js_interop) 'face_detection_adapter_web.dart'
    if (dart.library.io) 'face_detection_adapter_mobile.dart' as impl;

/// Observação biométrica unificada de um quadro ao vivo da câmera frontal.
///
/// Produzida tanto pelo motor nativo (Google ML Kit Face Detection no Android/iOS)
/// quanto pelo motor Web (MediaPipe FaceLandmarker via `kyc_vision_bridge.js`).
///
/// Convenção de ângulos de Euler (em graus) na perspectiva do usuário (espelhada):
/// - [headEulerAngleY] (yaw): positivo (`> 0`) = usuário girou o rosto para a **direita**;
///   negativo (`< 0`) = usuário girou o rosto para a **esquerda**.
/// - [headEulerAngleX] (pitch): positivo = cabeça inclinada para cima; negativo = para baixo.
/// - [headEulerAngleZ] (roll): inclinação lateral da cabeça.
@immutable
class LiveFaceObservation {
  const LiveFaceObservation({
    required this.faceCount,
    required this.trackingId,
    required this.normalizedBox,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.headEulerAngleX,
    required this.headEulerAngleY,
    required this.headEulerAngleZ,
    required this.meanLuminance,
    required this.sharpness,
    required this.blueMonitorRatio,
    required this.textureMotionDelta,
    required this.timestampMs,
    this.sourceEngine = 'unknown',
    this.unavailableReason,
  });

  /// Quantidade de rostos detectados no quadro (`0`, `1`, `2+`).
  final int faceCount;

  /// Identificador contínuo do rosto rastreado entre quadros consecutivos.
  final int? trackingId;

  /// Caixa delimitadora normalizada `[0..1]` em coordenadas de visualização (espelhadas na frontal).
  final Rect normalizedBox;

  /// Probabilidade de abertura do olho esquerdo `[0..1]`, ou `null` se não classificado.
  final double? leftEyeOpenProbability;

  /// Probabilidade de abertura do olho direito `[0..1]`, ou `null` se não classificado.
  final double? rightEyeOpenProbability;

  /// Ângulo de inclinação vertical da cabeça (pitch) em graus.
  final double headEulerAngleX;

  /// Ângulo de rotação horizontal da cabeça (yaw) em graus.
  /// Positivo = giro para a direita do usuário; negativo = giro para a esquerda.
  final double headEulerAngleY;

  /// Ângulo de inclinação lateral da cabeça (roll) em graus.
  final double headEulerAngleZ;

  /// Luminância média da região facial / oval `[0..255]`.
  final double meanLuminance;

  /// Métrica de nitidez (gradiente / contraste local) da região facial.
  final double sharpness;

  /// Fração `[0..1]` de pixels compatíveis com emissão azulada/escura de monitor ou tela.
  final double blueMonitorRatio;

  /// Variação média de textura (luma) entre quadros consecutivos na região facial,
  /// usada para detectar fotos impressas ou imagens congeladas.
  final double textureMotionDelta;

  /// Carimbo de tempo monotônico do quadro em milissegundos.
  final int timestampMs;

  /// Identificador do motor de visão (`'mlkit'`, `'mediapipe'`, `'stub'`, `'test'`).
  final String sourceEngine;

  /// Motivo humano quando o motor de detecção não estiver disponível no dispositivo.
  final String? unavailableReason;

  bool get hasSingleFace => faceCount == 1;

  double? get averageEyeOpenProbability {
    final left = leftEyeOpenProbability;
    final right = rightEyeOpenProbability;
    if (left == null || right == null) return null;
    return (left + right) * 0.5;
  }

  /// Observação sem rosto detectado.
  factory LiveFaceObservation.noFace({
    required int timestampMs,
    double meanLuminance = 0.0,
    double sharpness = 0.0,
    double blueMonitorRatio = 0.0,
    double textureMotionDelta = 0.0,
    String sourceEngine = 'unknown',
  }) {
    return LiveFaceObservation(
      faceCount: 0,
      trackingId: null,
      normalizedBox: Rect.zero,
      leftEyeOpenProbability: null,
      rightEyeOpenProbability: null,
      headEulerAngleX: 0.0,
      headEulerAngleY: 0.0,
      headEulerAngleZ: 0.0,
      meanLuminance: meanLuminance,
      sharpness: sharpness,
      blueMonitorRatio: blueMonitorRatio,
      textureMotionDelta: textureMotionDelta,
      timestampMs: timestampMs,
      sourceEngine: sourceEngine,
    );
  }

  /// Observação quando o motor biométrico está indisponível (jamais aprova!).
  factory LiveFaceObservation.unavailable({
    required int timestampMs,
    required String reason,
    String sourceEngine = 'unavailable',
  }) {
    return LiveFaceObservation(
      faceCount: 0,
      trackingId: null,
      normalizedBox: Rect.zero,
      leftEyeOpenProbability: null,
      rightEyeOpenProbability: null,
      headEulerAngleX: 0.0,
      headEulerAngleY: 0.0,
      headEulerAngleZ: 0.0,
      meanLuminance: 0.0,
      sharpness: 0.0,
      blueMonitorRatio: 0.0,
      textureMotionDelta: 0.0,
      timestampMs: timestampMs,
      sourceEngine: sourceEngine,
      unavailableReason: reason,
    );
  }
}

/// Contrato multiplataforma para detecção facial biométrica em tempo real.
abstract class FaceDetectionAdapter {
  /// Indica se a plataforma atual suporta detecção facial biométrica real.
  bool get isSupported;

  /// Indica se o motor foi inicializado com sucesso.
  bool get isInitialized;

  /// Motivo amigável caso a inicialização tenha falhado (sem jargão técnico).
  String? get unavailableReason;

  /// Inicializa o motor de visão (ML Kit no Mobile ou MediaPipe sob demanda na Web).
  Future<bool> initialize();

  /// Analisa um [CameraImage] nativo proveniente do `CameraController.startImageStream`.
  Future<LiveFaceObservation?> analyzeCameraImage(
    CameraImage image, {
    required int sensorOrientation,
    required bool isFrontCamera,
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  });

  /// Analisa o quadro atual do elemento `<video>` ativo na Web via MediaPipe.
  Future<LiveFaceObservation?> analyzeWebVideoFrame({
    bool mirrorHorizontal = true,
  });

  /// Libera todos os recursos nativos / WebGL (`FaceDetector.close()`, etc.).
  Future<void> dispose();
}

/// Cria o adaptador de detecção facial adequado para a plataforma atual:
/// - Android / iOS: Google ML Kit Face Detection (`face_detection_adapter_mobile.dart`)
/// - Web / PWA: MediaPipe FaceLandmarker (`face_detection_adapter_web.dart`)
/// - Demais ambientes: Stub seguro (`face_detection_adapter_stub.dart`)
FaceDetectionAdapter createFaceDetectionAdapter() => impl.createPlatformFaceDetectionAdapter();

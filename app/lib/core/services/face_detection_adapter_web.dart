import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'face_detection_adapter.dart';

@JS('eval')
external JSPromise<JSString?> _evalWebVisionAsync(JSString script);

/// Adaptador Web / PWA usando MediaPipe FaceLandmarker carregado sob demanda
/// via `app/web/kyc_vision_bridge.js` (lazy load, sem modificar `index.html`).
class WebFaceDetectionAdapter implements FaceDetectionAdapter {
  bool _initialized = false;
  bool _disposed = false;
  bool _busy = false;
  String? _unavailableReason;

  @override
  bool get isSupported => true;

  @override
  bool get isInitialized => _initialized && !_disposed;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  Future<bool> initialize() async {
    if (_disposed) return false;
    if (_initialized) return true;

    const String bootstrapScript = r'''
      (async function() {
        try {
          if (!window.DesperrengueKycVision) {
            await new Promise((resolve, reject) => {
              const existing = document.querySelector('script[data-kyc-vision-bridge="1"]');
              if (existing && window.DesperrengueKycVision) {
                resolve();
                return;
              }
              const onReady = () => {
                window.removeEventListener('desperrengue:kyc-vision-ready', onReady);
                resolve();
              };
              window.addEventListener('desperrengue:kyc-vision-ready', onReady, { once: true });

              const script = existing || document.createElement('script');
              if (!existing) {
                script.type = 'module';
                script.async = true;
                script.dataset.kycVisionBridge = '1';
                script.src = new URL('kyc_vision_bridge.js', document.baseURI).href;
                script.onerror = () => {
                  window.removeEventListener('desperrengue:kyc-vision-ready', onReady);
                  reject(new Error('BRIDGE_SCRIPT_LOAD_FAILED'));
                };
                document.head.appendChild(script);
              }
              setTimeout(() => {
                if (window.DesperrengueKycVision) {
                  resolve();
                } else {
                  window.removeEventListener('desperrengue:kyc-vision-ready', onReady);
                  reject(new Error('BRIDGE_SCRIPT_TIMEOUT'));
                }
              }, 12000);
            });
          }

          if (!window.DesperrengueKycVision || typeof window.DesperrengueKycVision.init !== 'function') {
            return JSON.stringify({
              ok: false,
              reason: 'Não foi possível preparar a verificação facial neste navegador.'
            });
          }

          const initResult = await window.DesperrengueKycVision.init();
          return JSON.stringify(initResult || { ok: false, reason: 'Falha ao iniciar câmera facial.' });
        } catch (err) {
          return JSON.stringify({
            ok: false,
            reason: 'Não foi possível carregar a verificação facial neste navegador. Verifique sua conexão e tente novamente.'
          });
        }
      })()
    ''';

    try {
      final JSString? raw = await _evalWebVisionAsync(bootstrapScript.toJS).toDart;
      final String payload = raw?.toDart ?? '';
      if (payload.isEmpty) {
        _unavailableReason =
            'Não foi possível iniciar a verificação facial neste navegador.';
        return false;
      }
      final dynamic decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
        _initialized = true;
        _unavailableReason = null;
        return true;
      }
      _unavailableReason = (decoded is Map<String, dynamic> &&
              decoded['reason'] is String &&
              (decoded['reason'] as String).trim().isNotEmpty)
          ? (decoded['reason'] as String).trim()
          : 'Seu navegador não suportou o leitor facial em tempo real. Tente no celular ou atualize o navegador.';
      return false;
    } catch (_) {
      _unavailableReason =
          'Não foi possível iniciar a verificação facial neste navegador.';
      return false;
    }
  }

  @override
  Future<LiveFaceObservation?> analyzeCameraImage(
    CameraImage image, {
    required int sensorOrientation,
    required bool isFrontCamera,
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) async {
    return analyzeWebVideoFrame(mirrorHorizontal: isFrontCamera);
  }

  @override
  Future<LiveFaceObservation?> analyzeWebVideoFrame({
    bool mirrorHorizontal = true,
  }) async {
    if (!isInitialized || _busy || _disposed) return null;
    _busy = true;
    final String mirrorJs = mirrorHorizontal ? 'true' : 'false';
    final String script = '''
      (async function() {
        try {
          if (!window.DesperrengueKycVision || typeof window.DesperrengueKycVision.detectFromActiveVideo !== 'function') {
            return null;
          }
          const obs = window.DesperrengueKycVision.detectFromActiveVideo($mirrorJs);
          return obs ? JSON.stringify(obs) : null;
        } catch (_) {
          return null;
        }
      })()
    ''';

    try {
      final JSString? raw = await _evalWebVisionAsync(script.toJS).toDart;
      final String? payload = raw?.toDart;
      if (payload == null || payload.isEmpty) return null;
      final dynamic parsed = jsonDecode(payload);
      if (parsed is! Map<String, dynamic>) return null;

      if (parsed['unavailable'] == true) {
        final reason = (parsed['reason'] as String?) ??
            'Não foi possível analisar o vídeo ao vivo neste navegador.';
        _unavailableReason = reason;
        return LiveFaceObservation.unavailable(
          timestampMs: _toInt(parsed['timestampMs']) ??
              DateTime.now().millisecondsSinceEpoch,
          reason: reason,
          sourceEngine: 'mediapipe',
        );
      }

      final int faceCount = _toInt(parsed['faceCount']) ?? 0;
      final int ts = _toInt(parsed['timestampMs']) ??
          DateTime.now().millisecondsSinceEpoch;
      final double meanLum = _toDouble(parsed['meanLuminance']) ?? 0.0;
      final double sharpness = _toDouble(parsed['sharpness']) ?? 0.0;
      final double blueRatio = _toDouble(parsed['blueMonitorRatio']) ?? 0.0;
      final double motionDelta = _toDouble(parsed['textureMotionDelta']) ?? 0.0;

      if (faceCount <= 0) {
        return LiveFaceObservation.noFace(
          timestampMs: ts,
          meanLuminance: meanLum,
          sharpness: sharpness,
          blueMonitorRatio: blueRatio,
          textureMotionDelta: motionDelta,
          sourceEngine: 'mediapipe',
        );
      }

      final double left = (_toDouble(parsed['boxLeft']) ?? 0.0).clamp(0.0, 1.0);
      final double top = (_toDouble(parsed['boxTop']) ?? 0.0).clamp(0.0, 1.0);
      final double right = (_toDouble(parsed['boxRight']) ?? 0.0).clamp(0.0, 1.0);
      final double bottom = (_toDouble(parsed['boxBottom']) ?? 0.0).clamp(0.0, 1.0);

      final Rect box = (right > left && bottom > top)
          ? Rect.fromLTRB(left, top, right, bottom)
          : Rect.zero;

      return LiveFaceObservation(
        faceCount: faceCount,
        trackingId: _toInt(parsed['trackingId']),
        normalizedBox: box,
        leftEyeOpenProbability: _toNullableDouble(parsed['leftEyeOpenProbability']),
        rightEyeOpenProbability: _toNullableDouble(parsed['rightEyeOpenProbability']),
        headEulerAngleX: _toDouble(parsed['headEulerAngleX']) ?? 0.0,
        headEulerAngleY: _toDouble(parsed['headEulerAngleY']) ?? 0.0,
        headEulerAngleZ: _toDouble(parsed['headEulerAngleZ']) ?? 0.0,
        meanLuminance: meanLum,
        sharpness: sharpness,
        blueMonitorRatio: blueRatio,
        textureMotionDelta: motionDelta,
        timestampMs: ts,
        sourceEngine: 'mediapipe',
      );
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    const String disposeScript = '''
      (async function() {
        try {
          if (window.DesperrengueKycVision && typeof window.DesperrengueKycVision.dispose === 'function') {
            window.DesperrengueKycVision.dispose();
          }
        } catch (_) {}
        return 'OK';
      })()
    ''';
    try {
      await _evalWebVisionAsync(disposeScript.toJS).toDart;
    } catch (_) {}
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    return null;
  }
}

FaceDetectionAdapter createPlatformFaceDetectionAdapter() =>
    WebFaceDetectionAdapter();

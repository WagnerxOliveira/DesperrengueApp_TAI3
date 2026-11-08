import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

@JS('eval')
external JSPromise<JSString?> _evalWebCameraAsync(JSString script);

/// No Web/PWA, utiliza o stub de [convertCameraImageToUprightRgb] caso receba `CameraImage`.
img.Image? convertCameraImageToUprightRgb([
  CameraImage? positionalCameraImage,
  int? positionalSensorOrientation,
  bool? positionalIsFrontCamera,
  int targetWidth = 160,
  int targetHeight = 120,
]) {
  return null;
}

img.Image? convertCameraImageToUprightRgbNamed({
  CameraImage? image,
  required int sensorOrientation,
  required bool isFrontCamera,
  int targetWidth = 160,
  int targetHeight = 120,
  int? targetMaxDimension,
}) {
  return null;
}

/// Garante no navegador Web/PWA (`Chrome Android` / `Safari iOS`) que o elemento `<video>`
/// ativo dentro do `CameraPreview` esteja estritamente na lente solicitada:
/// - `frontCamera == true`  -> `facingMode: { exact: 'user' }` (fallback `{ ideal: 'user' }`)
/// - `frontCamera == false` -> `facingMode: { exact: 'environment' }` (fallback `{ ideal: 'environment' }`)
Future<bool> ensureWebVideoFacingMode({required bool frontCamera}) async {
  final desired = frontCamera ? 'user' : 'environment';
  final idealW = frontCamera ? 640 : 1280;
  final idealH = frontCamera ? 480 : 720;

  final jsCode = '''
    (async function() {
      try {
        const videos = Array.from(document.querySelectorAll('video'));
        const video = videos.length > 0 ? videos[videos.length - 1] : null;
        if (!video) return 'NO_VIDEO';
        video.setAttribute('playsinline', 'true');
        video.setAttribute('autoplay', 'true');
        video.muted = true;

        let currentFacing = '';
        if (video.srcObject && video.srcObject.getVideoTracks) {
          const tracks = video.srcObject.getVideoTracks();
          if (tracks.length > 0 && tracks[0].getSettings) {
            currentFacing = tracks[0].getSettings().facingMode || '';
          }
        }
        if (currentFacing === '$desired') {
          return 'ALREADY_OK';
        }

        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          let newStream = null;
          try {
            newStream = await navigator.mediaDevices.getUserMedia({
              video: {
                facingMode: { exact: '$desired' },
                width: { ideal: $idealW },
                height: { ideal: $idealH }
              },
              audio: false
            });
          } catch (_) {
            newStream = await navigator.mediaDevices.getUserMedia({
              video: {
                facingMode: '$desired',
                width: { ideal: $idealW },
                height: { ideal: $idealH }
              },
              audio: false
            });
          }
          if (newStream) {
            if (video.srcObject && video.srcObject.getTracks) {
              try {
                video.srcObject.getTracks().forEach(t => t.stop());
              } catch (_) {}
            }
            video.srcObject = newStream;
            await video.play();
            return 'SWITCHED_OK';
          }
        }
        return 'FALLBACK';
      } catch (e) {
        return 'ERR:' + String(e);
      }
    })()
  ''';

  try {
    final res = await _evalWebCameraAsync(jsCode.toJS).toDart;
    final str = res?.toDart ?? '';
    return str == 'ALREADY_OK' || str == 'SWITCHED_OK';
  } catch (_) {
    return false;
  }
}

/// Captura um frame instantâneo do `<video>` ao vivo no navegador Web/PWA usando um `<canvas>`
/// offscreen em memória e retorna os bytes JPEG/PNG sem interromper o stream de vídeo.
Future<Uint8List?> grabWebVideoFramePngBytes({
  int width = 160,
  int height = 120,
  int? maxWidth,
  int? maxHeight,
  bool mirrorHorizontal = false,
}) async {
  final effectiveW = maxWidth ?? width;
  final effectiveH = maxHeight ?? height;
  final mirrorJs = mirrorHorizontal ? 'true' : 'false';
  final jsCode = '''
    (async function() {
      try {
        const videos = Array.from(document.querySelectorAll('video'));
        const video = videos.length > 0 ? videos[videos.length - 1] : null;
        if (!video || video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
          return null;
        }
        const canvas = document.createElement('canvas');
        canvas.width = $effectiveW;
        canvas.height = $effectiveH;
        const ctx = canvas.getContext('2d');
        if (!ctx) return null;
        if ($mirrorJs) {
          ctx.translate($effectiveW, 0);
          ctx.scale(-1, 1);
        }
        ctx.drawImage(video, 0, 0, $effectiveW, $effectiveH);
        const dataUrl = canvas.toDataURL('image/jpeg', 0.88);
        const commaIdx = dataUrl.indexOf(',');
        return commaIdx >= 0 ? dataUrl.substring(commaIdx + 1) : null;
      } catch (e) {
        return null;
      }
    })()
  ''';

  try {
    final res = await _evalWebCameraAsync(jsCode.toJS).toDart;
    final b64 = res?.toDart;
    if (b64 == null || b64.isEmpty) return null;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

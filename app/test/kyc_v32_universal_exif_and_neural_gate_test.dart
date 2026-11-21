import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:desperrengue_app/core/services/camera_operation_queue.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Cria uma imagem sintética realista de rosto em ambiente interno escuro
/// (barba/cabelo escuros com luma < 20, fundo escuro e luz branca LED fria)
/// que anteriormente falhava no filtro legado YCbCr + `yLuma < 26.0`,
/// mas representa um rosto humano real validado pela rede neural.
Uint8List _buildCoolLedBeardedFaceBytes({
  int width = 180,
  int height = 240,
  int? exifOrientation,
}) {
  final img.Image canvas = img.Image(width: width, height: height);
  // Fundo interno escuro neutro (R=14, G=15, B=16 -> luma ~15, NÃO é monitor azul)
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      canvas.setPixelRgb(x, y, 14, 15, 16);
    }
  }

  // Rosto central com iluminação LED branca fria + textura facial real + barba escura
  final int fx0 = (width * 0.24).round();
  final int fx1 = (width * 0.76).round();
  final int fy0 = (height * 0.22).round();
  final int fy1 = (height * 0.78).round();

  for (int y = fy0; y < fy1; y++) {
    final double relY = (y - fy0) / (fy1 - fy0);
    for (int x = fx0; x < fx1; x++) {
      final int tex = ((x * 13 + y * 17) % 28) - 14;
      if (relY > 0.65) {
        // Região de barba cheia escura (luma ~18, neutra)
        canvas.setPixelRgb(x, y, (18 + (tex ~/ 3)).clamp(8, 35),
            (17 + (tex ~/ 3)).clamp(8, 35), (16 + (tex ~/ 3)).clamp(8, 35));
      } else if (relY > 0.28 && relY < 0.42) {
        // Faixa dos olhos (alto contraste natural)
        final int v = ((x + y) % 3 == 0) ? 45 : 152 + tex;
        canvas.setPixelRgb(x, y, v.clamp(20, 220), (v - 6).clamp(20, 220),
            (v - 10).clamp(20, 220));
      } else {
        // Pele sob luz branca LED fria (R≈G≈B levemente aquecida)
        canvas.setPixelRgb(
          x,
          y,
          (154 + tex).clamp(40, 230),
          (146 + tex).clamp(40, 230),
          (138 + tex).clamp(40, 230),
        );
      }
    }
  }

  if (exifOrientation != null) {
    canvas.exif.imageIfd.orientation = exifOrientation;
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

Uint8List _buildSolidImageBytes({
  required int r,
  required int g,
  required int b,
  int width = 120,
  int height = 160,
}) {
  final img.Image canvas = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      canvas.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

const List<double> _validEarTimeline = <double>[
  0.30,
  0.29,
  0.15,
  0.14,
  0.28,
  0.30,
];

const List<({double yawDeg, double pitchDeg})> _validPoseTimeline =
    <({double yawDeg, double pitchDeg})>[
  (yawDeg: 1.0, pitchDeg: 0.5),
  (yawDeg: 14.0, pitchDeg: 1.0),
  (yawDeg: 22.5, pitchDeg: 1.5),
  (yawDeg: 21.0, pitchDeg: 1.0),
  (yawDeg: 3.0, pitchDeg: 0.5),
  (yawDeg: 1.2, pitchDeg: 0.2),
];

void main() {
  group('CameraOperationQueue — Serialização FIFO cross-OEM', () {
    test('executa operações concorrentes estritamente em ordem FIFO sem overlap', () async {
      final CameraOperationQueue queue = CameraOperationQueue();
      final List<String> log = <String>[];

      final f1 = queue.enqueue<void>(() async {
        log.add('start-1');
        await Future<void>.delayed(const Duration(milliseconds: 25));
        log.add('end-1');
      });
      final f2 = queue.enqueue<void>(() async {
        log.add('start-2');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        log.add('end-2');
      });
      final f3 = queue.enqueue<int>(() async {
        log.add('start-3');
        return 42;
      });

      await Future.wait<Object?>(<Future<Object?>>[f1, f2, f3]);
      expect(log, equals(<String>['start-1', 'end-1', 'start-2', 'end-2', 'start-3']));
      expect(await f3, equals(42));
    });

    test('erro em uma operação não bloqueia operações subsequentes na fila', () async {
      final CameraOperationQueue queue = CameraOperationQueue();
      await expectLater(
        queue.enqueue<void>(() async => throw StateError('simulated OEM failure')),
        throwsStateError,
      );
      final String next = await queue.enqueue<String>(() async => 'recovered');
      expect(next, equals('recovered'));
    });
  });

  group('Normalização EXIF Canônica Universal (Todos os Celulares Android & iOS)', () {
    test('corrige JPEG deitado com EXIF Orientation = 8 (270°) para retrato em pé', () {
      final Uint8List rawLandscapeWithExif8 = _buildCoolLedBeardedFaceBytes(
        width: 240,
        height: 180,
        exifOrientation: 8,
      );

      final Uint8List normalized =
          DocumentOcrAndLivenessService.normalizeSelfieOrientationBytes(
        rawLandscapeWithExif8,
      );
      final img.Image? decoded = img.decodeImage(normalized);
      expect(decoded, isNotNull);
      expect(decoded!.height, equals(240));
      expect(decoded.width, equals(180));
      expect(
        !decoded.exif.imageIfd.hasOrientation ||
            decoded.exif.imageIfd.orientation == 1,
        isTrue,
      );
    });

    test('corrige JPEG deitado com EXIF Orientation = 6 (90° — iOS / Motorola / Pixel) para retrato em pé', () {
      final Uint8List rawLandscapeWithExif6 = _buildCoolLedBeardedFaceBytes(
        width: 240,
        height: 180,
        exifOrientation: 6,
      );

      final Uint8List normalized =
          DocumentOcrAndLivenessService.normalizeSelfieOrientationBytes(
        rawLandscapeWithExif6,
      );
      final img.Image? decoded = img.decodeImage(normalized);
      expect(decoded, isNotNull);
      expect(decoded!.height, equals(240));
      expect(decoded.width, equals(180));
    });

    test('corrige JPEG invertido com EXIF Orientation = 3 (180°) mantendo proporção', () {
      final Uint8List rawWithExif3 = _buildCoolLedBeardedFaceBytes(
        width: 180,
        height: 240,
        exifOrientation: 3,
      );

      final Uint8List normalized =
          DocumentOcrAndLivenessService.normalizeSelfieOrientationBytes(
        rawWithExif3,
      );
      final img.Image? decoded = img.decodeImage(normalized);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(180));
      expect(decoded.height, equals(240));
    });

    test('é idempotente para imagens já orientadas e compactas (Web/PNG)', () {
      final Uint8List uprightPng = _buildCoolLedBeardedFaceBytes(
        width: 180,
        height: 240,
      );
      final Uint8List normalized =
          DocumentOcrAndLivenessService.normalizeSelfieOrientationBytes(uprightPng);
      expect(identical(normalized, uprightPng), isTrue);
    });

    test('redimensiona foto gigante (> 1280px) preservando rigorosamente o aspect ratio retrato 3:4', () {
      final img.Image bigPortrait = img.Image(width: 1500, height: 2000);
      final Uint8List raw = Uint8List.fromList(img.encodeJpg(bigPortrait, quality: 75));

      final Uint8List normalized =
          DocumentOcrAndLivenessService.normalizeSelfieOrientationBytes(raw);
      final img.Image? decoded = img.decodeImage(normalized);
      expect(decoded, isNotNull);
      expect(decoded!.height, equals(1280));
      expect(decoded.width, equals(960));
    });
  });

  group('Validação Neural Pós-Captura (ISO/IEC 29794-5 & NIST FRVT — Zero Viés YCbCr)', () {
    test('aprova rosto real em luz LED fria com barba e fundo escuros sob auditoria neural real', () {
      final Uint8List challengingRealFace = _buildCoolLedBeardedFaceBytes(
        width: 180,
        height: 240,
      );

      final ActiveLivenessResult result =
          DocumentOcrAndLivenessService.verifyActiveLivenessSync(
        selfieBytes: challengingRealFace,
        cpfDigits: '52998224725',
        earTimeline: _validEarTimeline,
        poseTimeline: _validPoseTimeline,
        requireRealBiometricTelemetry: true,
        verifiedByNeuralFaceDetector: true,
        verifiedFaceBox: const Rect.fromLTRB(0.24, 0.22, 0.76, 0.78),
        neuralMeanLuminance: 122.0,
        neuralSharpness: 18.5,
      );

      expect(result.passed, isTrue);
      expect(result.livenessScore, inInclusiveRange(80.0, 99.5));
      expect(result.challengesPassed, contains('NEURAL_FACE_DETECTION_VERIFIED'));
      expect(result.faceEmbedding128.length, equals(128));
      expect(result.faceLivenessHash, startsWith('DSP-LIVE-SHA256-'));
    });

    test('aprova JPEG com EXIF Orientation = 8 (câmera frontal deitada) sob auditoria neural', () {
      final Uint8List exif8Jpeg = _buildCoolLedBeardedFaceBytes(
        width: 240,
        height: 180,
        exifOrientation: 8,
      );

      final ActiveLivenessResult result =
          DocumentOcrAndLivenessService.verifyActiveLivenessSync(
        selfieBytes: exif8Jpeg,
        cpfDigits: '52998224725',
        earTimeline: _validEarTimeline,
        poseTimeline: _validPoseTimeline,
        requireRealBiometricTelemetry: true,
        verifiedByNeuralFaceDetector: true,
        verifiedFaceBox: const Rect.fromLTRB(0.22, 0.24, 0.78, 0.76),
        neuralMeanLuminance: 120.0,
        neuralSharpness: 16.0,
      );

      expect(result.passed, isTrue);
      expect(result.faceEmbedding128.length, equals(128));
    });

    test('preserva 100% das barreiras anti-fraude sob auditoria neural (sem telemetria, sem piscada, sem giro, lente tampada, parede lisa e monitor azul)', () {
      final Uint8List validFace = _buildCoolLedBeardedFaceBytes();

      // 1. Sem telemetria real -> bloqueado
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: validFace,
          cpfDigits: '52998224725',
          verifiedByNeuralFaceDetector: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_MISSING_REAL_BIOMETRIC_TELEMETRY'),
        )),
      );

      // 2. Sem piscada bilateral real -> bloqueado
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: validFace,
          cpfDigits: '52998224725',
          earTimeline: const <double>[0.30, 0.30, 0.29, 0.30],
          poseTimeline: _validPoseTimeline,
          verifiedByNeuralFaceDetector: true,
          verifiedFaceBox: const Rect.fromLTRB(0.24, 0.22, 0.76, 0.78),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_LIVENESS_BLINK_NOT_DETECTED'),
        )),
      );

      // 3. Sem giro 3D >= 18° + retorno -> bloqueado
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: validFace,
          cpfDigits: '52998224725',
          earTimeline: _validEarTimeline,
          poseTimeline: const <({double yawDeg, double pitchDeg})>[
            (yawDeg: 1.0, pitchDeg: 0.0),
            (yawDeg: 4.0, pitchDeg: 0.0),
            (yawDeg: 2.0, pitchDeg: 0.0),
          ],
          verifiedByNeuralFaceDetector: true,
          verifiedFaceBox: const Rect.fromLTRB(0.24, 0.22, 0.76, 0.78),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_LIVENESS_YAW_NOT_DETECTED'),
        )),
      );

      // 4. Lente tampada (tudo preto) -> bloqueado por luminância
      final Uint8List blackLens = _buildSolidImageBytes(r: 4, g: 4, b: 4);
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: blackLens,
          cpfDigits: '52998224725',
          earTimeline: _validEarTimeline,
          poseTimeline: _validPoseTimeline,
          verifiedByNeuralFaceDetector: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_LIVENESS_LUMINANCE_OUT_OF_RANGE'),
        )),
      );

      // 5. Parede lisa uniforme (stdDev == 0) -> bloqueado
      final Uint8List flatWall = _buildSolidImageBytes(r: 140, g: 140, b: 140);
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: flatWall,
          cpfDigits: '52998224725',
          earTimeline: _validEarTimeline,
          poseTimeline: _validPoseTimeline,
          verifiedByNeuralFaceDetector: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_NO_HUMAN_FACE_IN_OVAL'),
        )),
      );

      // 6. Monitor azul brilhante -> bloqueado
      final Uint8List blueMonitor = _buildSolidImageBytes(r: 40, g: 95, b: 225);
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: blueMonitor,
          cpfDigits: '52998224725',
          earTimeline: _validEarTimeline,
          poseTimeline: _validPoseTimeline,
          verifiedByNeuralFaceDetector: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_NO_HUMAN_FACE_IN_OVAL'),
        )),
      );

      // 7. Modo legado (verifiedByNeuralFaceDetector: false) com Monitor VS Code -> continua 100% bloqueado!
      final Uint8List vsCodeMonitor =
          DocumentOcrAndLivenessService.createSyntheticMonitorScreenBytes();
      expect(
        DocumentOcrAndLivenessService.hasRealHumanFaceInOval(vsCodeMonitor),
        isFalse,
      );
      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: vsCodeMonitor,
          cpfDigits: '52998224725',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_NO_HUMAN_FACE_IN_OVAL'),
        )),
      );
    });
  });

  group('KycHumanFeedbackTranslator — Novos códigos específicos zero-jargão', () {
    test('traduz ERR_SELFIE_CAPTURE_MOVED, ERR_MULTIPLE_FACES_IN_SELFIE e ERR_CAMERA_CAPTURE_TIMEOUT em PT-BR claro', () {
      const List<String> codes = <String>[
        'ERR_SELFIE_CAPTURE_MOVED',
        'ERR_MULTIPLE_FACES_IN_SELFIE',
        'ERR_CAMERA_CAPTURE_TIMEOUT',
      ];
      for (final code in codes) {
        final String msg = KycHumanFeedbackTranslator.translateError(StateError(code));
        expect(msg, isNotEmpty);
        expect(msg, isNot(contains(code)));
        expect(msg.toLowerCase(), isNot(contains('fotos ou telas')));
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(msg),
          isFalse,
          reason: 'Jargão técnico vazou na tradução de $code: "$msg"',
        );
      }
    });
  });
}

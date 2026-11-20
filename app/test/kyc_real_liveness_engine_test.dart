import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:desperrengue_app/core/services/active_liveness_engine.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/face_detection_adapter.dart';
import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/active_liveness_fullscreen_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

LiveFaceObservation _validFrame({
  required int tsMs,
  int faceCount = 1,
  int? trackingId = 7,
  Rect box = const Rect.fromLTWH(0.30, 0.25, 0.40, 0.50),
  double? leftEye = 0.88,
  double? rightEye = 0.86,
  double pitch = 1.0,
  double yaw = 0.5,
  double roll = 0.5,
  double luminance = 132.0,
  double sharpness = 24.0,
  double blueMonitorRatio = 0.04,
  double textureMotionDelta = 1.4,
  String? unavailableReason,
}) {
  return LiveFaceObservation(
    faceCount: faceCount,
    trackingId: trackingId,
    normalizedBox: box,
    leftEyeOpenProbability: leftEye,
    rightEyeOpenProbability: rightEye,
    headEulerAngleX: pitch,
    headEulerAngleY: yaw,
    headEulerAngleZ: roll,
    meanLuminance: luminance,
    sharpness: sharpness,
    blueMonitorRatio: blueMonitorRatio,
    textureMotionDelta: textureMotionDelta,
    timestampMs: tsMs,
    sourceEngine: 'test',
    unavailableReason: unavailableReason,
  );
}

/// Gera uma selfie válida de teste com rosto humano real no oval usando a fábrica forense do serviço.
Uint8List _buildSyntheticHumanFacePng() {
  return DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
    variantSeed: 1,
  );
}

List<LiveFaceObservation> _buildCompleteSessionFrames({
  required LivenessTurnDirection direction,
  int startTsMs = 1000,
  int trackingId = 42,
}) {
  final List<LiveFaceObservation> frames = <LiveFaceObservation>[];
  int ts = startTsMs;

  // Etapa 1: 5 quadros consecutivos centralizados
  for (int i = 0; i < 5; i++) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId));
  }

  // Etapa 2: baseline aberto (2 frames) -> fechamento bilateral (2 frames) -> reabertura (2 frames)
  for (int i = 0; i < 2; i++) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId, leftEye: 0.90, rightEye: 0.89));
  }
  for (int i = 0; i < 2; i++) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId, leftEye: 0.14, rightEye: 0.16));
  }
  for (int i = 0; i < 2; i++) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId, leftEye: 0.88, rightEye: 0.90));
  }

  // Etapa 3A: giro 3D real na direção sorteada (>= 18° por >= 3 quadros)
  final double sign = direction == LivenessTurnDirection.right ? 1.0 : -1.0;
  for (final deg in <double>[11.0, 20.5, 23.0, 22.0]) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId, yaw: sign * deg, pitch: 2.0));
  }

  // Etapa 3B: retorno ao centro (|yaw| <= 8°, |pitch| <= 10°, olhos >= 0.65 por >= 3 quadros)
  for (final deg in <double>[4.0, 2.0, 1.0]) {
    ts += 90;
    frames.add(_validFrame(tsMs: ts, trackingId: trackingId, yaw: sign * deg, pitch: 1.0));
  }

  return frames;
}

void main() {
  group('ActiveLivenessStateMachine — Invariantes contínuos e anti-fraude', () {
    test('rejeita 0 faces com contorno vermelho e mensagem humana', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      final snap = engine.processObservation(
        LiveFaceObservation.noFace(timestampMs: 1000),
      );
      expect(snap.contourState, LivenessContourState.invalidRed);
      expect(snap.instruction, 'Posicione seu rosto dentro da moldura');
      expect(snap.progress, 0.0);
      expect(snap.readyToCapture, isFalse);
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(snap.instruction),
        isFalse,
      );
    });

    test('rejeita 2 ou mais faces simultâneas na câmera', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      final snap = engine.processObservation(
        _validFrame(tsMs: 1000, faceCount: 2),
      );
      expect(snap.contourState, LivenessContourState.invalidRed);
      expect(snap.instruction, 'Apenas você deve aparecer na câmera');
      expect(snap.progress, 0.0);
      expect(snap.readyToCapture, isFalse);
    });

    test('distingue rosto muito distante, muito próximo e fora do centro do oval', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );

      // Muito distante: largura 0.24 / 0.66 = 36.4% (< 42%)
      final tooFar = engine.processObservation(
        _validFrame(
          tsMs: 1000,
          box: const Rect.fromLTWH(0.38, 0.32, 0.24, 0.30),
        ),
      );
      expect(tooFar.contourState, LivenessContourState.invalidRed);
      expect(tooFar.instruction, 'Aproxime um pouco o rosto');

      // Muito próximo: largura 0.64 / 0.66 = 97.0% (> 94%)
      final tooClose = engine.processObservation(
        _validFrame(
          tsMs: 1100,
          box: const Rect.fromLTWH(0.18, 0.12, 0.64, 0.70),
        ),
      );
      expect(tooClose.contourState, LivenessContourState.invalidRed);
      expect(tooClose.instruction, 'Afaste um pouco o rosto');

      // Fora do centro (±15%): center.dx = 0.70 (dx = +0.20 > 0.15) -> mover para esquerda
      final offCenter = engine.processObservation(
        _validFrame(
          tsMs: 1200,
          box: const Rect.fromLTWH(0.50, 0.22, 0.40, 0.50),
        ),
      );
      expect(offCenter.contourState, LivenessContourState.invalidRed);
      expect(
        offCenter.instruction,
        'Centralize movendo o rosto um pouco para a esquerda',
      );
    });

    test('fornece instruções direcionais naturais alinhadas ao espelho (esquerda, direita, cima, baixo) e respeita calibração ergonômica', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      expect(engine.config.ovalCenterY, 0.47);
      expect(engine.config.maxCenterOffset, 0.15);
      expect(engine.config.minFaceWidthToOvalRatio, 0.42);
      expect(engine.config.maxFaceWidthToOvalRatio, 0.94);

      // 1. Rosto à esquerda na tela (center.dx = 0.30 => dx = -0.20 < -0.15) -> mover para a direita
      final shiftRight = engine.processObservation(
        _validFrame(
          tsMs: 1000,
          box: const Rect.fromLTWH(0.10, 0.22, 0.40, 0.50),
        ),
      );
      expect(shiftRight.contourState, LivenessContourState.invalidRed);
      expect(
        shiftRight.instruction,
        'Centralize movendo o rosto um pouco para a direita',
      );
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(
          shiftRight.instruction,
        ),
        isFalse,
      );

      // 2. Rosto à direita na tela (center.dx = 0.70 => dx = +0.20 > +0.15) -> mover para a esquerda
      final shiftLeft = engine.processObservation(
        _validFrame(
          tsMs: 1100,
          box: const Rect.fromLTWH(0.50, 0.22, 0.40, 0.50),
        ),
      );
      expect(shiftLeft.contourState, LivenessContourState.invalidRed);
      expect(
        shiftLeft.instruction,
        'Centralize movendo o rosto um pouco para a esquerda',
      );

      // 3. Rosto alto demais na moldura (center.dy = 0.27 => dy = -0.20 < -0.15) -> abaixar
      final moveDown = engine.processObservation(
        _validFrame(
          tsMs: 1200,
          box: const Rect.fromLTWH(0.30, 0.02, 0.40, 0.50),
        ),
      );
      expect(moveDown.contourState, LivenessContourState.invalidRed);
      expect(moveDown.instruction, 'Abaixe um pouco o rosto na moldura');

      // 4. Rosto baixo demais na moldura (center.dy = 0.67 => dy = +0.20 > +0.15) -> levantar
      final moveUp = engine.processObservation(
        _validFrame(
          tsMs: 1300,
          box: const Rect.fromLTWH(0.30, 0.42, 0.40, 0.50),
        ),
      );
      expect(moveUp.contourState, LivenessContourState.invalidRed);
      expect(moveUp.instruction, 'Levante um pouco o rosto na moldura');

      // 5. Dentro da tolerância ergonômica (dx = 0.14 <= 0.15, width ratio = 0.30/0.66 = 0.455 >= 0.42) -> válido
      final ergonomicValid = engine.processObservation(
        _validFrame(
          tsMs: 1400,
          box: const Rect.fromLTWH(0.49, 0.22, 0.30, 0.50),
        ),
      );
      expect(ergonomicValid.contourState, LivenessContourState.validGreen);

      // 6. Encaixe cheio natural no oval (86% da largura do oval, centerY = 0.47) -> válido!
      final naturalFullOval = engine.processObservation(
        _validFrame(
          tsMs: 1500,
          box: const Rect.fromLTRB(0.216, 0.22, 0.784, 0.72),
        ),
      );
      expect(naturalFullOval.contourState, LivenessContourState.validGreen);
    });

    test('rejeita monitor/tela azulada, baixa iluminação, pouca nitidez e foto estática parada', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );

      final monitor = engine.processObservation(
        _validFrame(tsMs: 1000, blueMonitorRatio: 0.28),
      );
      expect(monitor.contourState, LivenessContourState.invalidRed);
      expect(monitor.instruction, 'Posicione seu rosto real em frente à câmera');

      final dark = engine.processObservation(
        _validFrame(tsMs: 1100, luminance: 30.0),
      );
      expect(dark.contourState, LivenessContourState.invalidRed);
      expect(dark.instruction.toLowerCase(), contains('escuro'));

      final blurry = engine.processObservation(
        _validFrame(tsMs: 1200, sharpness: 3.0),
      );
      expect(blurry.contourState, LivenessContourState.invalidRed);
      expect(blurry.instruction.toLowerCase(), contains('nítida'));

      // Foto impressa parada: 4+ quadros seguidos sem micro-variação de textura
      ActiveLivenessSnapshot? staticSnap;
      for (int i = 0; i < 6; i++) {
        staticSnap = engine.processObservation(
          _validFrame(tsMs: 1300 + i * 80, textureMotionDelta: 0.01),
        );
      }
      expect(staticSnap!.contourState, LivenessContourState.invalidRed);
      expect(staticSnap.stage, LivenessStage.centerFaceInOval);
      expect(staticSnap.instruction, 'Posicione seu rosto real em frente à câmera');
    });

    test('troca de trackingId no meio da sessão reseta imediatamente para Etapa 1', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );

      // Completa Etapa 1 com trackingId = 10
      int ts = 1000;
      late ActiveLivenessSnapshot snap;
      for (int i = 0; i < 6; i++) {
        ts += 80;
        snap = engine.processObservation(_validFrame(tsMs: ts, trackingId: 10));
      }
      expect(snap.stage, LivenessStage.blinkBothEyesSlowly);

      // Outra pessoa assume a câmera (trackingId = 99) -> reset imediato para Etapa 1!
      ts += 80;
      snap = engine.processObservation(_validFrame(tsMs: ts, trackingId: 99));
      expect(snap.sessionWasReset, isTrue);
      expect(snap.stage, LivenessStage.centerFaceInOval);
      expect(snap.contourState, LivenessContourState.invalidRed);
      expect(snap.realEarTimeline, isEmpty);
      expect(snap.realPoseTimeline, isEmpty);
    });

    test('ausência superior a 1.200 ms reseta para Etapa 1', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      int ts = 1000;
      for (int i = 0; i < 6; i++) {
        ts += 80;
        engine.processObservation(_validFrame(tsMs: ts, trackingId: 5));
      }
      expect(engine.stage, LivenessStage.blinkBothEyesSlowly);

      // Salta 1.500 ms sem rosto válido
      final afterGap = engine.processObservation(
        _validFrame(tsMs: ts + 1500, trackingId: 5),
      );
      expect(afterGap.sessionWasReset, isTrue);
      expect(afterGap.stage, LivenessStage.centerFaceInOval);
    });
  });

  group('ActiveLivenessStateMachine — Desafios biométricos reais', () {
    test('anti-timeout na piscada: 120 quadros sem piscar JAMAIS aprovam Etapa 2', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      int ts = 1000;
      for (int i = 0; i < 6; i++) {
        ts += 90;
        engine.processObservation(_validFrame(tsMs: ts, trackingId: 1));
      }
      expect(engine.stage, LivenessStage.blinkBothEyesSlowly);

      // 120 quadros (~12 segundos) mantendo olhos abertos (ou piscando só um olho)
      late ActiveLivenessSnapshot snap;
      for (int i = 0; i < 120; i++) {
        ts += 100;
        final bool winkOnly = i == 40;
        snap = engine.processObservation(
          _validFrame(
            tsMs: ts,
            trackingId: 1,
            leftEye: winkOnly ? 0.10 : 0.90,
            rightEye: 0.90,
          ),
        );
      }
      expect(snap.stage, LivenessStage.blinkBothEyesSlowly);
      expect(snap.blinkSubState, BlinkSubState.awaitingClosure);
      expect(snap.readyToCapture, isFalse);
    });

    test('fechamento prolongado (> 1.500 ms) na Etapa 2 exige nova piscada natural', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      int ts = 1000;
      for (int i = 0; i < 6; i++) {
        ts += 90;
        engine.processObservation(_validFrame(tsMs: ts));
      }
      // Baseline aberto
      ts += 90;
      engine.processObservation(_validFrame(tsMs: ts, leftEye: 0.90, rightEye: 0.90));
      ts += 90;
      engine.processObservation(_validFrame(tsMs: ts, leftEye: 0.90, rightEye: 0.90));
      // Fecha olhos
      ts += 90;
      final closed = engine.processObservation(
        _validFrame(tsMs: ts, leftEye: 0.12, rightEye: 0.14),
      );
      expect(closed.blinkSubState, BlinkSubState.awaitingReopen);

      // Permanece fechado por > 1.800 ms (em pequenos passos para não disparar ausência de rosto)
      for (int i = 0; i < 20; i++) {
        ts += 100;
        engine.processObservation(
          _validFrame(tsMs: ts, leftEye: 0.12, rightEye: 0.14),
        );
      }
      expect(engine.stage, LivenessStage.blinkBothEyesSlowly);
      expect(engine.blinkSubState, BlinkSubState.awaitingOpenBaseline);
    });

    test('direção errada no giro 3D orienta em PT-BR e não avança', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );
      int ts = 1000;
      // Etapa 1 + Etapa 2
      for (int i = 0; i < 6; i++) {
        ts += 90;
        engine.processObservation(_validFrame(tsMs: ts));
      }
      for (final eye in <double>[0.90, 0.90, 0.15, 0.88, 0.90]) {
        ts += 90;
        engine.processObservation(
          _validFrame(tsMs: ts, leftEye: eye, rightEye: eye),
        );
      }
      expect(engine.stage, LivenessStage.turnHead);

      // Usuário vira para a esquerda (-22°) quando sorteado foi direita
      ts += 90;
      final wrong = engine.processObservation(
        _validFrame(tsMs: ts, yaw: -22.0),
      );
      expect(wrong.stage, LivenessStage.turnHead);
      expect(wrong.contourState, LivenessContourState.invalidRed);
      expect(
        wrong.instruction,
        'Para o outro lado — vire devagar para a direita',
      );
    });

    test('aprovação completa (direita e esquerda) produz telemetria real compatível com verifyActiveLiveness', () {
      for (final direction in LivenessTurnDirection.values) {
        final engine = ActiveLivenessStateMachine(forcedDirection: direction);
        final frames = _buildCompleteSessionFrames(direction: direction);

        late ActiveLivenessSnapshot snap;
        for (final f in frames) {
          snap = engine.processObservation(f);
          expect(
            KycHumanFeedbackTranslator.containsBannedTechnicalJargon(
              snap.instruction,
            ),
            isFalse,
            reason: 'Jargão técnico vazou na instrução: ${snap.instruction}',
          );
        }

        expect(snap.readyToCapture, isTrue);
        expect(snap.stage, LivenessStage.completed);
        expect(snap.contourState, LivenessContourState.completedGreen);
        expect(snap.progress, 1.0);
        expect(snap.chosenDirection, direction);
        expect(snap.computedLivenessScore, inInclusiveRange(82.0, 99.5));

        // Valida compatibilidade direta com os algoritmos forenses do serviço
        expect(
          DocumentOcrAndLivenessService.detectHumanBlinkSequence(
            snap.realEarTimeline,
          ),
          isTrue,
        );
        expect(
          DocumentOcrAndLivenessService.detectHeadYawChallengeSequence(
            snap.realPoseTimeline,
          ),
          isTrue,
        );
      }
    });

    test('direção aleatorizada sem override varia entre esquerda e direita', () {
      final seen = <LivenessTurnDirection>{};
      final rng = math.Random(2026);
      for (int i = 0; i < 20; i++) {
        seen.add(ActiveLivenessStateMachine(random: rng).chosenDirection);
      }
      expect(seen, containsAll(LivenessTurnDirection.values));
    });
  });

  group('ActiveLivenessFullscreenModal — Espelhamento, câmera frontal estrita e ausência de troca de câmera', () {
    test('shouldMirrorFrontPreview desativa flip manual no Android/iOS e ativa apenas na Web', () {
      expect(
        ActiveLivenessFullscreenModal.shouldMirrorFrontPreview(isWeb: false),
        isFalse,
      );
      expect(
        ActiveLivenessFullscreenModal.shouldMirrorFrontPreview(isWeb: true),
        isTrue,
      );
    });

    test('selectStrictFrontCamera trava na lente frontal e jamais faz fallback para câmera traseira', () {
      const backCam = CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );
      const frontCam = CameraDescription(
        name: '1',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );
      const namedSelfieCam = CameraDescription(
        name: 'Integrated User Selfie Camera',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      );

      expect(
        ActiveLivenessFullscreenModal.selectStrictFrontCamera(
          const <CameraDescription>[backCam, frontCam],
        ),
        equals(frontCam),
      );
      expect(
        ActiveLivenessFullscreenModal.selectStrictFrontCamera(
          const <CameraDescription>[backCam, namedSelfieCam],
        ),
        equals(namedSelfieCam),
      );
      expect(
        ActiveLivenessFullscreenModal.selectStrictFrontCamera(
          const <CameraDescription>[backCam],
        ),
        isNull,
      );
    });
  });

  group('ActiveLivenessFullscreenModal — Widget, responsividade, contorno e acessibilidade', () {
    Future<void> pumpModal(
      WidgetTester tester, {
      required Size surfaceSize,
      Stream<LiveFaceObservation>? stream,
      Future<Uint8List> Function()? captureOverride,
      LivenessTurnDirection? forcedDirection,
      bool disableAnimations = false,
      ValueChanged<ActiveLivenessModalOutput?>? onPopped,
    }) async {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: surfaceSize,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final out = await ActiveLivenessFullscreenModal.show(
                      context,
                      cpfDigits: '52998224725',
                      forcedDirection: forcedDirection,
                      testObservationStream: stream,
                      testCaptureOverride: captureOverride,
                    );
                    onPopped?.call(out);
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    ActiveLivenessOvalPainter findOvalPainter(WidgetTester tester) {
      final customPaintFinder = find.descendant(
        of: find.byKey(ActiveLivenessFullscreenModal.ovalOverlayKey),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      return customPaint.painter! as ActiveLivenessOvalPainter;
    }

    void assertNoBannedJargonVisible(WidgetTester tester) {
      for (final element in find.byType(Text).evaluate()) {
        final widget = element.widget as Text;
        final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(text),
          isFalse,
          reason: 'Texto com jargão técnico exibido na UI: "$text"',
        );
      }
    }

    testWidgets('contorno alterna de vermelho para verde conforme observações reais', (tester) async {
      final controller = StreamController<LiveFaceObservation>.broadcast(sync: true);
      addTearDown(controller.close);

      await pumpModal(
        tester,
        surfaceSize: const Size(390, 844),
        stream: controller.stream,
        forcedDirection: LivenessTurnDirection.right,
        disableAnimations: true,
      );

      // Estado inicial sem rosto -> vermelho
      expect(findOvalPainter(tester).contourColor, AppTokens.dark.danger);
      expect(find.text('Etapa 1 de 3'), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
      assertNoBannedJargonVisible(tester);

      // 2 faces -> continua vermelho com orientação curta
      controller.add(_validFrame(tsMs: 1000, faceCount: 2));
      await tester.pump();
      expect(findOvalPainter(tester).contourColor, AppTokens.dark.danger);
      expect(find.text('Apenas você deve aparecer na câmera'), findsOneWidget);
      assertNoBannedJargonVisible(tester);

      // Rosto centralizado válido -> contorno transita para verde
      controller.add(_validFrame(tsMs: 1100, faceCount: 1));
      await tester.pump();
      expect(findOvalPainter(tester).contourColor, AppTokens.dark.success);
      assertNoBannedJargonVisible(tester);
    });

    testWidgets('renderiza sem overflow em 320x640 e em 1280x800 (viewport desktop limitado a 520px)', (tester) async {
      final controllerCompact = StreamController<LiveFaceObservation>.broadcast();
      addTearDown(controllerCompact.close);

      // 320x640 (mobile compacto)
      await pumpModal(
        tester,
        surfaceSize: const Size(320, 640),
        stream: controllerCompact.stream,
        forcedDirection: LivenessTurnDirection.left,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(ActiveLivenessFullscreenModal.viewportFrameKey)).width,
        320.0,
      );
      expect(
        tester.getSize(find.byKey(ActiveLivenessFullscreenModal.closeButtonKey)).width,
        greaterThanOrEqualTo(48.0),
      );
      expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
      assertNoBannedJargonVisible(tester);

      // 1280x800 (desktop / Web — centralizado em <= 520px sem esticar webcam)
      final controllerDesktop = StreamController<LiveFaceObservation>.broadcast();
      addTearDown(controllerDesktop.close);

      await pumpModal(
        tester,
        surfaceSize: const Size(1280, 800),
        stream: controllerDesktop.stream,
        forcedDirection: LivenessTurnDirection.right,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(ActiveLivenessFullscreenModal.viewportFrameKey)).width,
        520.0,
      );
      expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
      assertNoBannedJargonVisible(tester);
    });

    testWidgets('tecla Esc fecha o modal fullscreen retornando null', (tester) async {
      final controller = StreamController<LiveFaceObservation>.broadcast();
      addTearDown(controller.close);
      bool poppedCalled = false;
      ActiveLivenessModalOutput? output;

      await pumpModal(
        tester,
        surfaceSize: const Size(1280, 800),
        stream: controller.stream,
        forcedDirection: LivenessTurnDirection.right,
        onPopped: (val) {
          poppedCalled = true;
          output = val;
        },
      );

      expect(find.byType(ActiveLivenessFullscreenModal), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(poppedCalled, isTrue);
      expect(output, isNull);
      expect(find.byType(ActiveLivenessFullscreenModal), findsNothing);
    });

    testWidgets('fluxo completo via stream retorna ActiveLivenessModalOutput com telemetria real verificada', (tester) async {
      final controller = StreamController<LiveFaceObservation>.broadcast(sync: true);
      addTearDown(controller.close);
      final Uint8List syntheticFace = _buildSyntheticHumanFacePng();
      expect(
        DocumentOcrAndLivenessService.hasRealHumanFaceInOval(syntheticFace),
        isTrue,
      );
      ActiveLivenessModalOutput? capturedOutput;

      await pumpModal(
        tester,
        surfaceSize: const Size(390, 844),
        stream: controller.stream,
        forcedDirection: LivenessTurnDirection.right,
        disableAnimations: true,
        captureOverride: () async => syntheticFace,
        onPopped: (val) => capturedOutput = val,
      );

      final frames = _buildCompleteSessionFrames(
        direction: LivenessTurnDirection.right,
      );
      for (final frame in frames) {
        controller.add(frame);
        await tester.pump();
      }

      // Aguarda verifyActiveLivenessInIsolate concluir e fechar o modal
      for (int i = 0; i < 40 && capturedOutput == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(capturedOutput, isNotNull);
      expect(capturedOutput!.selfieBytes, isNotEmpty);
      expect(capturedOutput!.livenessResult.passed, isTrue);
      expect(
        capturedOutput!.livenessResult.livenessScore,
        inInclusiveRange(82.0, 99.5),
      );
      expect(capturedOutput!.livenessResult.maxHeadYawDegrees, greaterThanOrEqualTo(18.0));
      expect(capturedOutput!.livenessResult.minEyeAspectRatio, lessThan(0.185));
      expect(capturedOutput!.livenessResult.maxEyeAspectRatio, greaterThan(0.24));
      expect(capturedOutput!.chosenDirection, LivenessTurnDirection.right);
    });

    testWidgets('erro nativo (LiveFaceObservation.unavailable) exibe orientação humana e botão Tentar novamente sem congelar', (tester) async {
      final controller = StreamController<LiveFaceObservation>.broadcast(sync: true);
      addTearDown(controller.close);

      await pumpModal(
        tester,
        surfaceSize: const Size(390, 844),
        stream: controller.stream,
        forcedDirection: LivenessTurnDirection.right,
        disableAnimations: true,
      );

      controller.add(
        LiveFaceObservation.unavailable(
          timestampMs: 1000,
          reason:
              'Não foi possível analisar seu rosto neste momento. Toque em "Tentar novamente" para reiniciar a câmera.',
          sourceEngine: 'mlkit',
        ),
      );
      await tester.pump();

      expect(findOvalPainter(tester).contourColor, AppTokens.dark.danger);
      expect(find.textContaining('Não foi possível analisar seu rosto'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      assertNoBannedJargonVisible(tester);
    });
  });
}

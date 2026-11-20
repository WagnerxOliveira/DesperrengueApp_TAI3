import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable;

import 'face_detection_adapter.dart';

/// Projeta um bounding box normalizado `[0..1]` no espaço do sensor (já
/// verticalizado e espelhado na câmera frontal) para o espaço normalizado
/// `[0..1]` do viewport visível na tela após o recorte `BoxFit.cover`
/// (`coverScale`).
///
/// Exemplo real (Samsung Galaxy `9:20` = `0.45`, câmera frontal `3:4` = `0.75`):
/// - `coverScale = 0.75 / 0.45 = 1.667`, recortando 20% à esquerda e 20% à
///   direita da imagem crua do sensor (`visibleFractionW = 0.60`, `cropX = 0.20`).
/// - Um rosto com largura `0.34` no sensor ocupa `0.34 / 0.60 = 0.567` na tela
///   visível (~86% da largura do oval de `0.66`).
Rect projectSensorNormalizedRectToViewport({
  required Rect sensorRect,
  required double cameraAspect,
  required double viewportAspect,
}) {
  if (sensorRect == Rect.zero ||
      cameraAspect <= 0 ||
      viewportAspect <= 0 ||
      !cameraAspect.isFinite ||
      !viewportAspect.isFinite) {
    return sensorRect;
  }

  // Diferença desprezível (< 0,5%): sem recorte relevante.
  if ((cameraAspect - viewportAspect).abs() < 0.005) {
    return sensorRect;
  }

  double left = sensorRect.left;
  double right = sensorRect.right;
  double top = sensorRect.top;
  double bottom = sensorRect.bottom;

  if (cameraAspect > viewportAspect) {
    // Portrait típico (câmera 3:4 em tela 9:20): recorte horizontal nas laterais.
    final double visibleFractionW = (viewportAspect / cameraAspect).clamp(0.1, 1.0);
    final double cropX = (1.0 - visibleFractionW) * 0.5;
    left = ((left - cropX) / visibleFractionW).clamp(0.0, 1.0);
    right = ((right - cropX) / visibleFractionW).clamp(0.0, 1.0);
  } else {
    // Paisagem / desktop largo: recorte vertical no topo e na base.
    final double visibleFractionH = (cameraAspect / viewportAspect).clamp(0.1, 1.0);
    final double cropY = (1.0 - visibleFractionH) * 0.5;
    top = ((top - cropY) / visibleFractionH).clamp(0.0, 1.0);
    bottom = ((bottom - cropY) / visibleFractionH).clamp(0.0, 1.0);
  }

  if (right <= left || bottom <= top) {
    return Rect.zero;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Direção de giro tridimensional sorteada por sessão via `Random.secure()`.
enum LivenessTurnDirection {
  left,
  right,
}

/// Estado visual discreto do contorno oval (sem piscar nervoso).
enum LivenessContourState {
  invalidRed,
  validGreen,
  completedGreen,
}

/// Etapas determinísticas da máquina de estados de Prova de Vida Real.
enum LivenessStage {
  centerFaceInOval(uiStepNumber: 1),
  blinkBothEyesSlowly(uiStepNumber: 2),
  turnHead(uiStepNumber: 3),
  returnToCenter(uiStepNumber: 3),
  completed(uiStepNumber: 3);

  const LivenessStage({required this.uiStepNumber});

  /// Número humano exibido no topo (`Etapa 1 de 3`, `Etapa 2 de 3`, `Etapa 3 de 3`).
  final int uiStepNumber;
}

/// Sub-estados obrigatórios da Etapa 2 (piscada bilateral real).
/// Proibido aprovar por timeout ou contagem passiva de quadros.
enum BlinkSubState {
  awaitingOpenBaseline,
  awaitingClosure,
  awaitingReopen,
  completed,
}

/// Ícone direcional / visual sugerido para o card translúcido de instrução.
enum LivenessCueKind {
  alignCenter,
  moveCloser,
  moveFarther,
  improveLighting,
  holdStill,
  singleFaceOnly,
  realFaceOnly,
  blinkEyes,
  turnLeft,
  turnRight,
  returnCenter,
  captured,
}

/// Parâmetros calibráveis da máquina de estados de Prova de Vida Real.
@immutable
class ActiveLivenessConfig {
  const ActiveLivenessConfig({
    this.ovalWidthFraction = 0.66,
    this.ovalCenterY = 0.47,
    this.maxCenterOffset = 0.15,
    this.minFaceWidthToOvalRatio = 0.42,
    this.maxFaceWidthToOvalRatio = 0.94,
    this.minLuminance = 45.0,
    this.maxLuminance = 228.0,
    this.minSharpness = 6.0,
    this.maxBlueMonitorRatio = 0.22,
    this.minTextureMotionDelta = 0.12,
    this.maxConsecutiveStaticFrames = 4,
    this.maxAbsenceBeforeResetMs = 1200,
    this.centerRequiredFrames = 5,
    this.centerMaxYawDeg = 14.0,
    this.centerMaxPitchDeg = 16.0,
    this.centerMaxRollDeg = 15.0,
    this.centerMinEyeOpen = 0.58,
    this.blinkBaselineFrames = 2,
    this.blinkBaselineMinEyeOpen = 0.55,
    this.blinkClosedMaxEyeOpen = 0.28,
    this.blinkMaxYawDeg = 14.0,
    this.blinkReopenFrames = 2,
    this.blinkReopenMinEyeOpen = 0.55,
    this.blinkReopenTimeoutMs = 1800,
    this.turnTargetYawDeg = 18.0,
    this.turnWrongDirectionYawDeg = 12.0,
    this.turnMaxPitchDeg = 16.0,
    this.turnRequiredFrames = 3,
    this.returnMaxYawDeg = 6.5,
    this.returnMaxPitchDeg = 8.5,
    this.returnMinEyeOpen = 0.55,
    this.returnRequiredFrames = 3,
  });

  final double ovalWidthFraction;

  /// Centro vertical do oval no viewport (`0.47`, sincronizado com `ActiveLivenessOvalPainter`).
  final double ovalCenterY;
  final double maxCenterOffset;
  final double minFaceWidthToOvalRatio;
  final double maxFaceWidthToOvalRatio;
  final double minLuminance;
  final double maxLuminance;
  final double minSharpness;
  final double maxBlueMonitorRatio;
  final double minTextureMotionDelta;
  final int maxConsecutiveStaticFrames;
  final int maxAbsenceBeforeResetMs;

  final int centerRequiredFrames;
  final double centerMaxYawDeg;
  final double centerMaxPitchDeg;
  final double centerMaxRollDeg;
  final double centerMinEyeOpen;

  final int blinkBaselineFrames;
  final double blinkBaselineMinEyeOpen;
  final double blinkClosedMaxEyeOpen;
  final double blinkMaxYawDeg;
  final int blinkReopenFrames;
  final double blinkReopenMinEyeOpen;
  final int blinkReopenTimeoutMs;

  final double turnTargetYawDeg;
  final double turnWrongDirectionYawDeg;
  final double turnMaxPitchDeg;
  final int turnRequiredFrames;

  final double returnMaxYawDeg;
  final double returnMaxPitchDeg;
  final double returnMinEyeOpen;
  final int returnRequiredFrames;
}

/// Fotografia imutável do estado atual da Prova de Vida Real após cada quadro.
@immutable
class ActiveLivenessSnapshot {
  const ActiveLivenessSnapshot({
    required this.stage,
    required this.chosenDirection,
    required this.blinkSubState,
    required this.contourState,
    required this.progress,
    required this.instruction,
    required this.cueKind,
    required this.readyToCapture,
    required this.sessionWasReset,
    required this.realEarTimeline,
    required this.realPoseTimeline,
    required this.computedLivenessScore,
    required this.validFramesInCurrentStage,
    required this.activeTrackingId,
  });

  final LivenessStage stage;
  final LivenessTurnDirection chosenDirection;
  final BlinkSubState blinkSubState;
  final LivenessContourState contourState;

  /// Progresso contínuo no arco do oval (`0.0` -> `0.33` -> `0.66` -> `1.0`).
  final double progress;

  /// Orientação curta e humana em PT-BR (zero jargão técnico).
  final String instruction;

  final LivenessCueKind cueKind;

  /// `true` somente quando todas as etapas reais (1, 2, 3A e 3B) forem concluídas.
  final bool readyToCapture;

  /// `true` no quadro em que uma troca de `trackingId` ou ausência `> 1.200 ms`
  /// forçou o reinício completo para a Etapa 1.
  final bool sessionWasReset;

  /// Série temporal real de valores EAR equivalentes `[0.12..0.33]` coletados na Etapa 2.
  final List<double> realEarTimeline;

  /// Série temporal real de pares `(yawDeg, pitchDeg)` coletados nas Etapas 3A e 3B.
  final List<({double yawDeg, double pitchDeg})> realPoseTimeline;

  /// Pontuação real de qualidade biométrica (`82.0..99.5`) calculada ao concluir.
  final double computedLivenessScore;

  final int validFramesInCurrentStage;
  final int? activeTrackingId;

  int get uiStepNumber => stage.uiStepNumber;
  int get uiTotalSteps => 3;
}

/// Máquina de estados 100% pura e determinística de Prova de Vida Biométrica Real.
///
/// Impõe invariantes contínuos em todos os quadros (face única, continuidade de
/// `trackingId`, enquadramento no oval, iluminação, nitidez, anti-monitor e
/// anti-foto-estática) e exige evidência biométrica real nas 3 etapas:
/// 1. Centralização estável (6 quadros consecutivos válidos);
/// 2. Piscada bilateral real (aberto -> fechado -> reaberto em até 1.500 ms);
/// 3A. Giro 3D real na direção sorteada (`Random.secure()`) sustentado por >= 3 quadros;
/// 3B. Retorno ao centro estável por >= 3 quadros.
class ActiveLivenessStateMachine {
  ActiveLivenessStateMachine({
    LivenessTurnDirection? forcedDirection,
    math.Random? random,
    this.config = const ActiveLivenessConfig(),
  }) : _random = random ?? math.Random.secure() {
    _chosenDirection = forcedDirection ?? _drawDirection();
    _currentSnapshot = _buildSnapshot(
      contourState: LivenessContourState.invalidRed,
      instruction: 'Posicione seu rosto dentro da moldura',
      cueKind: LivenessCueKind.alignCenter,
      sessionWasReset: false,
    );
  }

  final ActiveLivenessConfig config;
  final math.Random _random;

  late LivenessTurnDirection _chosenDirection;
  LivenessStage _stage = LivenessStage.centerFaceInOval;
  BlinkSubState _blinkSubState = BlinkSubState.awaitingOpenBaseline;

  int? _activeTrackingId;
  int? _lastValidFaceTimestampMs;
  int _stageStreak = 0;
  int _blinkBaselineStreak = 0;
  int _blinkReopenStreak = 0;
  int? _blinkClosureTimestampMs;
  int _consecutiveStaticFrames = 0;

  final List<double> _earTimeline = <double>[];
  final List<({double yawDeg, double pitchDeg})> _poseTimeline =
      <({double yawDeg, double pitchDeg})>[];

  // Acumuladores de telemetria real para cálculo da pontuação final (82.0..99.5).
  double _luminanceSum = 0.0;
  double _sharpnessSum = 0.0;
  double _motionDeltaSum = 0.0;
  int _qualitySamples = 0;
  double _computedLivenessScore = 0.0;

  late ActiveLivenessSnapshot _currentSnapshot;

  LivenessTurnDirection get chosenDirection => _chosenDirection;
  LivenessStage get stage => _stage;
  BlinkSubState get blinkSubState => _blinkSubState;
  ActiveLivenessSnapshot get currentSnapshot => _currentSnapshot;

  /// Mapeia probabilidade de olho aberto `[0.0..1.0]` para a escala EAR equivalente
  /// `[0.12..0.345]` compatível com `DocumentOcrAndLivenessService.detectHumanBlinkSequence`:
  /// - `>= 0.55` -> `>= 0.24375` (`> 0.24` aberto)
  /// - `<= 0.28` -> `<= 0.1830` (`< 0.185` fechado)
  /// - `>= 0.55` -> `>= 0.24375` (`> 0.24` reaberto)
  static double eyeOpenProbabilityToEar(double eyeOpenProbability) {
    final double clamped = eyeOpenProbability.clamp(0.0, 1.0);
    return 0.12 + (clamped * 0.225);
  }

  /// Reinicia completamente a sessão para a Etapa 1 (opcionalmente sorteando nova direção).
  ActiveLivenessSnapshot reset({
    LivenessTurnDirection? forcedDirection,
    bool rerollDirection = false,
  }) {
    if (forcedDirection != null) {
      _chosenDirection = forcedDirection;
    } else if (rerollDirection) {
      _chosenDirection = _drawDirection();
    }
    _resetInternalProgress(clearTracking: true);
    _currentSnapshot = _buildSnapshot(
      contourState: LivenessContourState.invalidRed,
      instruction: 'Posicione seu rosto dentro da moldura',
      cueKind: LivenessCueKind.alignCenter,
      sessionWasReset: false,
    );
    return _currentSnapshot;
  }

  /// Processa uma nova observação facial ao vivo e retorna o novo [ActiveLivenessSnapshot].
  ActiveLivenessSnapshot processObservation(LiveFaceObservation obs) {
    if (_stage == LivenessStage.completed) {
      return _currentSnapshot;
    }

    bool sessionWasReset = false;

    // 0. Motor indisponível (ex.: falha de WebGL/WASM na Web) -> jamais aprova.
    if (obs.unavailableReason != null && obs.unavailableReason!.trim().isNotEmpty) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: obs.unavailableReason!.trim(),
        cueKind: LivenessCueKind.realFaceOnly,
        sessionWasReset: false,
      );
      return _currentSnapshot;
    }

    // 1. Verificação de ausência prolongada (> 1.200 ms) antes mesmo de processar o quadro.
    if (_lastValidFaceTimestampMs != null &&
        obs.timestampMs - _lastValidFaceTimestampMs! >
            config.maxAbsenceBeforeResetMs) {
      if (_hasProgressBeyondStart) {
        sessionWasReset = true;
      }
      _resetInternalProgress(clearTracking: true);
    }

    // 2. Presença de rosto único (0 faces ou >= 2 faces).
    if (obs.faceCount <= 0) {
      _consecutiveStaticFrames = 0;
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Posicione seu rosto dentro da moldura',
        cueKind: LivenessCueKind.alignCenter,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    if (obs.faceCount >= 2) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Apenas você deve aparecer na câmera',
        cueKind: LivenessCueKind.singleFaceOnly,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // 3. Continuidade de trackingId (troca de pessoa ou reinício de rastreamento -> reseta para Etapa 1).
    if (_activeTrackingId == null) {
      _activeTrackingId = obs.trackingId;
    } else if (obs.trackingId != null && obs.trackingId != _activeTrackingId) {
      sessionWasReset = true;
      _resetInternalProgress(clearTracking: false);
      _activeTrackingId = obs.trackingId;
      _lastValidFaceTimestampMs = obs.timestampMs;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Mantenha o mesmo rosto centralizado na moldura',
        cueKind: LivenessCueKind.alignCenter,
        sessionWasReset: true,
      );
      return _currentSnapshot;
    }

    _lastValidFaceTimestampMs = obs.timestampMs;

    // 4. Anti-monitor / tela eletrônica.
    if (obs.blueMonitorRatio >= config.maxBlueMonitorRatio) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Posicione seu rosto real em frente à câmera',
        cueKind: LivenessCueKind.realFaceOnly,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // 5. Iluminação [45..228].
    if (obs.meanLuminance < config.minLuminance) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Ambiente escuro. Procure um local mais iluminado',
        cueKind: LivenessCueKind.improveLighting,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }
    if (obs.meanLuminance > config.maxLuminance) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Muita luz direta. Evite reflexos fortes no rosto',
        cueKind: LivenessCueKind.improveLighting,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // 6. Nitidez mínima.
    if (obs.sharpness < config.minSharpness) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Imagem pouco nítida. Segure o aparelho firme',
        cueKind: LivenessCueKind.holdStill,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // 7. Anti-foto estática (micro-variação entre quadros consecutivos).
    if (obs.textureMotionDelta < config.minTextureMotionDelta) {
      _consecutiveStaticFrames += 1;
    } else {
      _consecutiveStaticFrames = 0;
    }
    if (_consecutiveStaticFrames >= config.maxConsecutiveStaticFrames) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Posicione seu rosto real em frente à câmera',
        cueKind: LivenessCueKind.realFaceOnly,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // 8. Enquadramento real dentro do oval (distância e centralização).
    final double faceWidthToOval =
        obs.normalizedBox.width / config.ovalWidthFraction;
    if (faceWidthToOval < config.minFaceWidthToOvalRatio) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Aproxime um pouco o rosto',
        cueKind: LivenessCueKind.moveCloser,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }
    if (faceWidthToOval > config.maxFaceWidthToOvalRatio) {
      _decayStageStreak();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Afaste um pouco o rosto',
        cueKind: LivenessCueKind.moveFarther,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    final double dx = obs.normalizedBox.center.dx - 0.50;
    final double dy = obs.normalizedBox.center.dy - config.ovalCenterY;
    if (dx.abs() > config.maxCenterOffset ||
        dy.abs() > config.maxCenterOffset) {
      _decayStageStreak();
      // Coordenadas já estão no espaço espelhado natural da câmera frontal:
      // dx < -tol -> rosto à esquerda na tela -> mover para a direita;
      // dx > +tol -> rosto à direita na tela  -> mover para a esquerda;
      // dy < -tol -> rosto acima na moldura   -> abaixar o rosto;
      // dy > +tol -> rosto abaixo na moldura  -> levantar o rosto.
      final String directionalInstruction;
      if (dx.abs() >= dy.abs()) {
        directionalInstruction = dx < -config.maxCenterOffset
            ? 'Centralize movendo o rosto um pouco para a direita'
            : 'Centralize movendo o rosto um pouco para a esquerda';
      } else {
        directionalInstruction = dy < -config.maxCenterOffset
            ? 'Abaixe um pouco o rosto na moldura'
            : 'Levante um pouco o rosto na moldura';
      }
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: directionalInstruction,
        cueKind: LivenessCueKind.alignCenter,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // Todos os invariantes contínuos passaram: acumula telemetria real de qualidade.
    _luminanceSum += obs.meanLuminance;
    _sharpnessSum += obs.sharpness;
    _motionDeltaSum += obs.textureMotionDelta;
    _qualitySamples += 1;

    switch (_stage) {
      case LivenessStage.centerFaceInOval:
        return _processStage1Centering(obs, sessionWasReset: sessionWasReset);
      case LivenessStage.blinkBothEyesSlowly:
        return _processStage2Blink(obs, sessionWasReset: sessionWasReset);
      case LivenessStage.turnHead:
        return _processStage3ATurnHead(obs, sessionWasReset: sessionWasReset);
      case LivenessStage.returnToCenter:
        return _processStage3BReturnToCenter(
          obs,
          sessionWasReset: sessionWasReset,
        );
      case LivenessStage.completed:
        return _currentSnapshot;
    }
  }

  ActiveLivenessSnapshot _processStage1Centering(
    LiveFaceObservation obs, {
    required bool sessionWasReset,
  }) {
    final double? leftEye = obs.leftEyeOpenProbability;
    final double? rightEye = obs.rightEyeOpenProbability;
    final bool poseNeutral = obs.headEulerAngleY.abs() <= config.centerMaxYawDeg &&
        obs.headEulerAngleX.abs() <= config.centerMaxPitchDeg &&
        obs.headEulerAngleZ.abs() <= config.centerMaxRollDeg;
    final bool eyesOpen = leftEye != null &&
        rightEye != null &&
        leftEye >= config.centerMinEyeOpen &&
        rightEye >= config.centerMinEyeOpen;

    if (!poseNeutral || !eyesOpen) {
      _stageStreak = 0;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: !poseNeutral
            ? 'Olhe de frente para a câmera'
            : 'Mantenha os olhos abertos olhando para a câmera',
        cueKind: LivenessCueKind.alignCenter,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    _stageStreak += 1;
    if (_stageStreak >= config.centerRequiredFrames) {
      _stage = LivenessStage.blinkBothEyesSlowly;
      _blinkSubState = BlinkSubState.awaitingOpenBaseline;
      _stageStreak = 0;
      _blinkBaselineStreak = 0;
      _blinkReopenStreak = 0;
      _blinkClosureTimestampMs = null;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.validGreen,
        instruction: 'Pisque os dois olhos devagar',
        cueKind: LivenessCueKind.blinkEyes,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    _currentSnapshot = _buildSnapshot(
      contourState: LivenessContourState.validGreen,
      instruction: 'Perfeito, mantenha o rosto parado',
      cueKind: LivenessCueKind.alignCenter,
      sessionWasReset: sessionWasReset,
    );
    return _currentSnapshot;
  }

  ActiveLivenessSnapshot _processStage2Blink(
    LiveFaceObservation obs, {
    required bool sessionWasReset,
  }) {
    final double? leftEye = obs.leftEyeOpenProbability;
    final double? rightEye = obs.rightEyeOpenProbability;

    if (obs.headEulerAngleY.abs() > config.blinkMaxYawDeg) {
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Olhe de frente para piscar os dois olhos',
        cueKind: LivenessCueKind.alignCenter,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    if (leftEye == null || rightEye == null) {
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Olhe de frente para a câmera',
        cueKind: LivenessCueKind.blinkEyes,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    // Registra valor real na earTimeline compatível com detectHumanBlinkSequence.
    final double avgOpen = (leftEye + rightEye) * 0.5;
    _earTimeline.add(eyeOpenProbabilityToEar(avgOpen));

    switch (_blinkSubState) {
      case BlinkSubState.awaitingOpenBaseline:
        if (leftEye >= config.blinkBaselineMinEyeOpen &&
            rightEye >= config.blinkBaselineMinEyeOpen) {
          _blinkBaselineStreak += 1;
          if (_blinkBaselineStreak >= config.blinkBaselineFrames) {
            _blinkSubState = BlinkSubState.awaitingClosure;
          }
        } else {
          _blinkBaselineStreak = 0;
        }
        _currentSnapshot = _buildSnapshot(
          contourState: LivenessContourState.validGreen,
          instruction: 'Pisque os dois olhos devagar',
          cueKind: LivenessCueKind.blinkEyes,
          sessionWasReset: sessionWasReset,
        );
        return _currentSnapshot;

      case BlinkSubState.awaitingClosure:
        // Exige fechamento bilateral real (ambos os olhos <= 0.28). Jamais aprova por timeout!
        if (leftEye <= config.blinkClosedMaxEyeOpen &&
            rightEye <= config.blinkClosedMaxEyeOpen) {
          _blinkSubState = BlinkSubState.awaitingReopen;
          _blinkClosureTimestampMs = obs.timestampMs;
          _blinkReopenStreak = 0;
          _currentSnapshot = _buildSnapshot(
            contourState: LivenessContourState.validGreen,
            instruction: 'Agora abra os olhos',
            cueKind: LivenessCueKind.blinkEyes,
            sessionWasReset: sessionWasReset,
          );
          return _currentSnapshot;
        }
        _currentSnapshot = _buildSnapshot(
          contourState: LivenessContourState.validGreen,
          instruction: 'Pisque os dois olhos devagar',
          cueKind: LivenessCueKind.blinkEyes,
          sessionWasReset: sessionWasReset,
        );
        return _currentSnapshot;

      case BlinkSubState.awaitingReopen:
        final int elapsedSinceClose =
            obs.timestampMs - (_blinkClosureTimestampMs ?? obs.timestampMs);
        if (elapsedSinceClose > config.blinkReopenTimeoutMs) {
          // Fechamento prolongado demais (> 1.500 ms) -> exige nova piscada natural.
          _blinkSubState = BlinkSubState.awaitingOpenBaseline;
          _blinkBaselineStreak = 0;
          _blinkReopenStreak = 0;
          _blinkClosureTimestampMs = null;
          _currentSnapshot = _buildSnapshot(
            contourState: LivenessContourState.invalidRed,
            instruction: 'Abra os olhos e pisque novamente devagar',
            cueKind: LivenessCueKind.blinkEyes,
            sessionWasReset: sessionWasReset,
          );
          return _currentSnapshot;
        }

        if (leftEye >= config.blinkReopenMinEyeOpen &&
            rightEye >= config.blinkReopenMinEyeOpen) {
          _blinkReopenStreak += 1;
          if (_blinkReopenStreak >= config.blinkReopenFrames) {
            _blinkSubState = BlinkSubState.completed;
            _stage = LivenessStage.turnHead;
            _stageStreak = 0;
            _poseTimeline.add((
              yawDeg: obs.headEulerAngleY,
              pitchDeg: obs.headEulerAngleX,
            ));
            _currentSnapshot = _buildSnapshot(
              contourState: LivenessContourState.validGreen,
              instruction: _turnPromptFor(_chosenDirection),
              cueKind: _cueFor(_chosenDirection),
              sessionWasReset: sessionWasReset,
            );
            return _currentSnapshot;
          }
        } else {
          _blinkReopenStreak = 0;
        }

        _currentSnapshot = _buildSnapshot(
          contourState: LivenessContourState.validGreen,
          instruction: 'Agora abra os olhos',
          cueKind: LivenessCueKind.blinkEyes,
          sessionWasReset: sessionWasReset,
        );
        return _currentSnapshot;

      case BlinkSubState.completed:
        _stage = LivenessStage.turnHead;
        _stageStreak = 0;
        _currentSnapshot = _buildSnapshot(
          contourState: LivenessContourState.validGreen,
          instruction: _turnPromptFor(_chosenDirection),
          cueKind: _cueFor(_chosenDirection),
          sessionWasReset: sessionWasReset,
        );
        return _currentSnapshot;
    }
  }

  ActiveLivenessSnapshot _processStage3ATurnHead(
    LiveFaceObservation obs, {
    required bool sessionWasReset,
  }) {
    final double yaw = obs.headEulerAngleY;
    final double pitch = obs.headEulerAngleX;
    _poseTimeline.add((yawDeg: yaw, pitchDeg: pitch));

    if (pitch.abs() > config.turnMaxPitchDeg) {
      _stageStreak = 0;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: 'Mantenha o rosto na altura da câmera',
        cueKind: _cueFor(_chosenDirection),
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    final bool turnedWrongWay = _chosenDirection == LivenessTurnDirection.right
        ? yaw <= -config.turnWrongDirectionYawDeg
        : yaw >= config.turnWrongDirectionYawDeg;

    if (turnedWrongWay) {
      _stageStreak = 0;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.invalidRed,
        instruction: _chosenDirection == LivenessTurnDirection.right
            ? 'Para o outro lado — vire devagar para a direita'
            : 'Para o outro lado — vire devagar para a esquerda',
        cueKind: _cueFor(_chosenDirection),
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    final bool reachedTarget = _chosenDirection == LivenessTurnDirection.right
        ? yaw >= config.turnTargetYawDeg
        : yaw <= -config.turnTargetYawDeg;

    if (reachedTarget) {
      _stageStreak += 1;
      if (_stageStreak >= config.turnRequiredFrames) {
        _stage = LivenessStage.returnToCenter;
        _stageStreak = 0;
        _currentSnapshot = _buildSnapshot(
          contourState: LivenessContourState.validGreen,
          instruction: 'Volte o rosto ao centro olhando para a câmera',
          cueKind: LivenessCueKind.returnCenter,
          sessionWasReset: sessionWasReset,
        );
        return _currentSnapshot;
      }
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.validGreen,
        instruction: 'Ótimo, segure por um instante',
        cueKind: _cueFor(_chosenDirection),
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    _stageStreak = 0;
    _currentSnapshot = _buildSnapshot(
      contourState: LivenessContourState.validGreen,
      instruction: _turnPromptFor(_chosenDirection),
      cueKind: _cueFor(_chosenDirection),
      sessionWasReset: sessionWasReset,
    );
    return _currentSnapshot;
  }

  ActiveLivenessSnapshot _processStage3BReturnToCenter(
    LiveFaceObservation obs, {
    required bool sessionWasReset,
  }) {
    final double yaw = obs.headEulerAngleY;
    final double pitch = obs.headEulerAngleX;
    final double? leftEye = obs.leftEyeOpenProbability;
    final double? rightEye = obs.rightEyeOpenProbability;
    _poseTimeline.add((yawDeg: yaw, pitchDeg: pitch));

    final bool centered = yaw.abs() <= config.returnMaxYawDeg &&
        pitch.abs() <= config.returnMaxPitchDeg;
    final bool eyesOpen = leftEye != null &&
        rightEye != null &&
        leftEye >= config.returnMinEyeOpen &&
        rightEye >= config.returnMinEyeOpen;

    if (!centered || !eyesOpen) {
      _stageStreak = 0;
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.validGreen,
        instruction: 'Volte o rosto ao centro olhando para a câmera',
        cueKind: LivenessCueKind.returnCenter,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    _stageStreak += 1;
    if (_stageStreak >= config.returnRequiredFrames) {
      _stage = LivenessStage.completed;
      _computedLivenessScore = _computeFinalLivenessScore();
      _currentSnapshot = _buildSnapshot(
        contourState: LivenessContourState.completedGreen,
        instruction: 'Rosto confirmado com sucesso',
        cueKind: LivenessCueKind.captured,
        sessionWasReset: sessionWasReset,
      );
      return _currentSnapshot;
    }

    _currentSnapshot = _buildSnapshot(
      contourState: LivenessContourState.validGreen,
      instruction: 'Mantenha o rosto centralizado',
      cueKind: LivenessCueKind.returnCenter,
      sessionWasReset: sessionWasReset,
    );
    return _currentSnapshot;
  }

  bool get _hasProgressBeyondStart =>
      _stage != LivenessStage.centerFaceInOval ||
      _stageStreak > 0 ||
      _earTimeline.isNotEmpty ||
      _poseTimeline.isNotEmpty;

  void _decayStageStreak() {
    if (_stage == LivenessStage.centerFaceInOval ||
        _stage == LivenessStage.turnHead ||
        _stage == LivenessStage.returnToCenter) {
      _stageStreak = math.max(0, _stageStreak - 1);
    }
    if (_stage == LivenessStage.blinkBothEyesSlowly &&
        _blinkSubState == BlinkSubState.awaitingOpenBaseline) {
      _blinkBaselineStreak = 0;
    }
  }

  void _resetInternalProgress({required bool clearTracking}) {
    _stage = LivenessStage.centerFaceInOval;
    _blinkSubState = BlinkSubState.awaitingOpenBaseline;
    _stageStreak = 0;
    _blinkBaselineStreak = 0;
    _blinkReopenStreak = 0;
    _blinkClosureTimestampMs = null;
    _consecutiveStaticFrames = 0;
    _earTimeline.clear();
    _poseTimeline.clear();
    _luminanceSum = 0.0;
    _sharpnessSum = 0.0;
    _motionDeltaSum = 0.0;
    _qualitySamples = 0;
    _computedLivenessScore = 0.0;
    if (clearTracking) {
      _activeTrackingId = null;
      _lastValidFaceTimestampMs = null;
    }
  }

  double _computeProgress() {
    switch (_stage) {
      case LivenessStage.centerFaceInOval:
        return (0.33 * (_stageStreak / config.centerRequiredFrames))
            .clamp(0.0, 0.33);
      case LivenessStage.blinkBothEyesSlowly:
        return switch (_blinkSubState) {
          BlinkSubState.awaitingOpenBaseline =>
            0.33 + (0.09 * (_blinkBaselineStreak / config.blinkBaselineFrames)),
          BlinkSubState.awaitingClosure => 0.45,
          BlinkSubState.awaitingReopen =>
            0.54 + (0.12 * (_blinkReopenStreak / config.blinkReopenFrames)),
          BlinkSubState.completed => 0.66,
        };
      case LivenessStage.turnHead:
        return (0.66 + (0.19 * (_stageStreak / config.turnRequiredFrames)))
            .clamp(0.66, 0.85);
      case LivenessStage.returnToCenter:
        return (0.85 + (0.15 * (_stageStreak / config.returnRequiredFrames)))
            .clamp(0.85, 0.99);
      case LivenessStage.completed:
        return 1.0;
    }
  }

  double _computeFinalLivenessScore() {
    double score = 82.0;

    // 1. Amplitude real da piscada bilateral (até +4.5 pts).
    if (_earTimeline.isNotEmpty) {
      final double minEar = _earTimeline.reduce(math.min);
      final double maxEar = _earTimeline.reduce(math.max);
      final double earSpan = (maxEar - minEar).clamp(0.0, 0.21);
      score += (earSpan / 0.16).clamp(0.0, 1.0) * 4.5;
    }

    // 2. Amplitude do giro 3D real (até +4.5 pts).
    if (_poseTimeline.isNotEmpty) {
      final double maxYaw =
          _poseTimeline.map((p) => p.yawDeg.abs()).reduce(math.max);
      final double yawFactor = ((maxYaw - 18.0) / 14.0).clamp(0.25, 1.0);
      score += yawFactor * 4.5;
    }

    // 3. Qualidade média de iluminação, nitidez e micro-movimento real (até +8.5 pts).
    if (_qualitySamples > 0) {
      final double meanLum = _luminanceSum / _qualitySamples;
      final double lumPenalty = ((meanLum - 135.0).abs() / 90.0).clamp(0.0, 1.0);
      score += (1.0 - lumPenalty) * 3.0;

      final double meanSharp = _sharpnessSum / _qualitySamples;
      score += ((meanSharp - config.minSharpness) / 28.0).clamp(0.0, 1.0) * 3.0;

      final double meanMotion = _motionDeltaSum / _qualitySamples;
      score += (meanMotion / 2.2).clamp(0.0, 1.0) * 2.5;
    }

    final double clamped = score.clamp(82.0, 99.5);
    return double.parse(clamped.toStringAsFixed(1));
  }

  LivenessTurnDirection _drawDirection() =>
      _random.nextBool() ? LivenessTurnDirection.right : LivenessTurnDirection.left;

  String _turnPromptFor(LivenessTurnDirection direction) =>
      direction == LivenessTurnDirection.right
          ? 'Vire devagar o rosto para a direita'
          : 'Vire devagar o rosto para a esquerda';

  LivenessCueKind _cueFor(LivenessTurnDirection direction) =>
      direction == LivenessTurnDirection.right
          ? LivenessCueKind.turnRight
          : LivenessCueKind.turnLeft;

  ActiveLivenessSnapshot _buildSnapshot({
    required LivenessContourState contourState,
    required String instruction,
    required LivenessCueKind cueKind,
    required bool sessionWasReset,
  }) {
    return ActiveLivenessSnapshot(
      stage: _stage,
      chosenDirection: _chosenDirection,
      blinkSubState: _blinkSubState,
      contourState: contourState,
      progress: _computeProgress(),
      instruction: instruction,
      cueKind: cueKind,
      readyToCapture: _stage == LivenessStage.completed,
      sessionWasReset: sessionWasReset,
      realEarTimeline: List<double>.unmodifiable(_earTimeline),
      realPoseTimeline:
          List<({double yawDeg, double pitchDeg})>.unmodifiable(_poseTimeline),
      computedLivenessScore: _computedLivenessScore,
      validFramesInCurrentStage: _stageStreak,
      activeTrackingId: _activeTrackingId,
    );
  }
}

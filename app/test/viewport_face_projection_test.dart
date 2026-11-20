import 'dart:ui' show Rect;

import 'package:desperrengue_app/core/services/active_liveness_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectSensorNormalizedRectToViewport — Projeção exata BoxFit.cover', () {
    test('Samsung Galaxy portrait (9:20 = 0.45) exibindo sensor 3:4 (0.75): projeta largura e centro sem distorção', () {
      // Sensor 3:4 recortado para viewport 9:20 -> visibleFractionW = 0.45 / 0.75 = 0.60, cropX = 0.20.
      // Rosto centralizado no sensor com largura 0.34 ([0.33 .. 0.67]) e centro Y em 0.47:
      const Rect sensorFace = Rect.fromLTRB(0.33, 0.27, 0.67, 0.67);

      final Rect projected = projectSensorNormalizedRectToViewport(
        sensorRect: sensorFace,
        cameraAspect: 0.75,
        viewportAspect: 0.45,
      );

      // Centro X permanece exatamente em 0.50; largura cresce 1.667x para 0.34 / 0.60 = 0.5667 (~85.9% do oval 0.66).
      expect(projected.center.dx, closeTo(0.50, 0.001));
      expect(projected.center.dy, closeTo(0.47, 0.001));
      expect(projected.width, closeTo(0.34 / 0.60, 0.001));
      expect(projected.height, closeTo(0.40, 0.001));

      // Verifica que esse enquadramento real agora é aceito dentro do ActiveLivenessConfig!
      const ActiveLivenessConfig cfg = ActiveLivenessConfig();
      final double faceWidthToOval = projected.width / cfg.ovalWidthFraction;
      expect(faceWidthToOval, inInclusiveRange(cfg.minFaceWidthToOvalRatio, cfg.maxFaceWidthToOvalRatio));
    });

    test('rosto deslocado perto da borda do recorte lateral reflete deslocamento amplificado no viewport', () {
      // Sensor [0.22 .. 0.46] -> center 0.34 no sensor -> no viewport visível [0.20..0.80] fica bem à esquerda (~0.233)
      const Rect leftInSensor = Rect.fromLTRB(0.22, 0.27, 0.46, 0.67);
      final Rect projected = projectSensorNormalizedRectToViewport(
        sensorRect: leftInSensor,
        cameraAspect: 0.75,
        viewportAspect: 0.45,
      );

      expect(projected.left, closeTo((0.22 - 0.20) / 0.60, 0.001));
      expect(projected.right, closeTo((0.46 - 0.20) / 0.60, 0.001));
      expect(projected.center.dx, lessThan(0.35));
    });

    test('modo paisagem/desktop (viewportAspect > cameraAspect) projeta recorte vertical corretamente', () {
      // Câmera 3:4 (0.75) dentro de palco 1.50 -> visibleFractionH = 0.50, cropY = 0.25.
      const Rect sensorFace = Rect.fromLTRB(0.30, 0.35, 0.70, 0.65);
      final Rect projected = projectSensorNormalizedRectToViewport(
        sensorRect: sensorFace,
        cameraAspect: 0.75,
        viewportAspect: 1.50,
      );

      expect(projected.left, closeTo(0.30, 0.001));
      expect(projected.right, closeTo(0.70, 0.001));
      expect(projected.top, closeTo((0.35 - 0.25) / 0.50, 0.001));
      expect(projected.bottom, closeTo((0.65 - 0.25) / 0.50, 0.001));
    });

    test('retorna o retângulo original quando as proporções são equivalentes ou inválidas', () {
      const Rect original = Rect.fromLTRB(0.25, 0.25, 0.75, 0.75);
      expect(
        projectSensorNormalizedRectToViewport(
          sensorRect: original,
          cameraAspect: 0.75,
          viewportAspect: 0.75,
        ),
        equals(original),
      );
      expect(
        projectSensorNormalizedRectToViewport(
          sensorRect: original,
          cameraAspect: 0.0,
          viewportAspect: 0.45,
        ),
        equals(original),
      );
    });
  });
}

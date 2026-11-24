import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:desperrengue_app/core/services/document_frame_alignment_engine.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/features/client/presentation/document_guided_scanner_modal.dart';

/// Gera uma cena realista de mesa de madeira escura com um documento claro
/// (CNH/CIN/RG) contendo linhas impressas de alta frequência e borda nítida
/// nas coordenadas normalizadas [docRect] dentro de um quadro `width x height`.
Uint8List _renderDocumentOnWoodenTable({
  required int width,
  required int height,
  required Rect docRect,
  int seed = 1,
}) {
  final img.Image canvas = img.Image(width: width, height: height);
  final int dx0 = (docRect.left * width).round();
  final int dy0 = (docRect.top * height).round();
  final int dx1 = (docRect.right * width).round();
  final int dy1 = (docRect.bottom * height).round();

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final bool insideDoc = x >= dx0 && x <= dx1 && y >= dy0 && y <= dy1;
      if (!insideDoc) {
        // Mesa de madeira marrom escura com veio sutil (luma ~72..90)
        final int grain = (((y * 5 + (x ~/ 6) + seed * 3) % 14) - 7);
        canvas.setPixelRgb(
          x,
          y,
          (98 + grain).clamp(60, 125),
          (72 + grain).clamp(45, 100),
          (50 + grain).clamp(30, 80),
        );
      } else {
        // Fundo claro da CNH/CIN (luma ~195..220) com blocos impressos escuros
        final bool isOuterBorder = (x - dx0) <= 2 ||
            (dx1 - x) <= 2 ||
            (y - dy0) <= 2 ||
            (dy1 - y) <= 2;
        final int relX = x - dx0;
        final int relY = y - dy0;
        final bool isPrintedText = ((relY % 9) < 3) &&
            ((relX + seed * 7) % 7 < 4) &&
            relX > 6 &&
            relY > 6;
        final bool isPhotoOrQr = (seed == 1)
            ? (relX > 10 && relX < 52 && relY > 14 && relY < 62)
            : (relX > 80 && relX < 130 && relY > 14 && relY < 62);
        if (isOuterBorder) {
          canvas.setPixelRgb(x, y, 224, 232, 222);
        } else if (isPhotoOrQr && ((x + y) % 3 == 0)) {
          canvas.setPixelRgb(x, y, 52, 62, 74);
        } else if (isPrintedText) {
          canvas.setPixelRgb(x, y, 36, 48, 56);
        } else {
          canvas.setPixelRgb(x, y, 206, 218, 212);
        }
      }
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

void main() {
  group('v2.34.0 — Projeção exata Viewport -> Sensor do Scanner de Documento', () {
    test('projeção em celular portrait 9:20 (360x800) com câmera 3:4 (0.75) mapeia cutout 1:1', () {
      const Size viewport = Size(360, 800);
      final Rect cutout = DocumentScannerOverlayPainter.computeCutoutRect(
        viewport,
        isVertical: false,
      );
      final Rect sensorRect = projectViewportCutoutToSensorRect(
        viewportSize: viewport,
        cutoutRect: cutout,
        cameraAspect: 0.75,
      );

      // Em 9:20 exibindo 3:4 via BoxFit.cover, o recorte horizontal visível é
      // 0.45 / 0.75 = 60% do sensor (x = 0.20..0.80). O cutout de 88% da tela
      // ocupa ~52.8% da largura real do sensor, centralizado em x = 0.50!
      expect(sensorRect.center.dx, closeTo(0.50, 0.01));
      expect(sensorRect.center.dy, closeTo(0.50, 0.01));
      expect(sensorRect.width, closeTo(0.88 * (0.45 / 0.75), 0.015));
      expect(sensorRect.height, closeTo(cutout.height / viewport.height, 0.01));
    });

    test('projeção em desktop/Web paisagem (680x760) com câmera 4:3 (1.333) funciona sem deformar', () {
      const Size viewport = Size(680, 760);
      final Rect cutout = DocumentScannerOverlayPainter.computeCutoutRect(
        viewport,
        isVertical: false,
      );
      final Rect sensorRect = projectViewportCutoutToSensorRect(
        viewportSize: viewport,
        cutoutRect: cutout,
        cameraAspect: 4.0 / 3.0,
      );
      expect(sensorRect.left, greaterThan(0.05));
      expect(sensorRect.right, lessThan(0.95));
      expect(sensorRect.top, greaterThan(0.15));
      expect(sensorRect.bottom, lessThan(0.85));
    });
  });

  group('v2.34.0 — Bloqueio cirúrgico de documento cortado ou com faixa de mesa (Frente e Verso)', () {
    const Size phoneViewport = Size(360, 800);
    final Rect phoneCutout = DocumentScannerOverlayPainter.computeCutoutRect(
      phoneViewport,
      isVertical: false,
    );
    final Rect exactSensorRoi = projectViewportCutoutToSensorRect(
      viewportSize: phoneViewport,
      cutoutRect: phoneCutout,
      cameraAspect: 0.75,
    );

    test('APROVA documento bem enquadrado preenchendo os 4 lados do retângulo (Frente e Verso) e recorta sem mesa', () {
      final Uint8List frontBytes = _renderDocumentOnWoodenTable(
        width: 240,
        height: 320,
        docRect: exactSensorRoi,
        seed: 1,
      );
      final Uint8List backBytes = _renderDocumentOnWoodenTable(
        width: 240,
        height: 320,
        docRect: exactSensorRoi,
        seed: 2,
      );

      final frontEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: frontBytes,
        isFront: true,
        isVerticalOrientation: false,
        normalizedRoiRect: exactSensorRoi,
      );
      expect(
        frontEval.status,
        DocumentFrameStatus.aligned,
        reason: 'Frente perfeitamente encaixada no retângulo deve ser aprovada (${frontEval.humanHint})',
      );

      final backEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: backBytes,
        isFront: false,
        isVerticalOrientation: false,
        referenceFrontBytes: frontBytes,
        normalizedRoiRect: exactSensorRoi,
      );
      expect(
        backEval.status,
        DocumentFrameStatus.aligned,
        reason: 'Verso perfeitamente encaixado no retângulo deve ser aprovado (${backEval.humanHint})',
      );

      // Recorte com normalizedCropRect exato preserva 100% do documento e descarta a mesa
      final Uint8List cropped =
          DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: frontBytes,
        isVerticalOrientation: false,
        normalizedCropRect: exactSensorRoi,
      );
      final img.Image? croppedImg = img.decodeImage(cropped);
      expect(croppedImg, isNotNull);
      expect(croppedImg!.width, closeTo((exactSensorRoi.width * 240).round(), 3));
      expect(croppedImg.height, closeTo((exactSensorRoi.height * 320).round(), 3));
    });

    test('REJEITA CNH deslocada para cima (topo cortado + ~22% de mesa de madeira embaixo) na FRENTE e no VERSO', () {
      // Reproduz exatamente a foto do screenshot reportado:
      // documento sobe ~24% da altura do retângulo, cortando o cabeçalho no
      // topo e deixando ~24% de mesa marrom vazia dentro da base do retângulo.
      final double shiftUp = exactSensorRoi.height * 0.24;
      final Rect shiftedUpDoc = exactSensorRoi.shift(Offset(0, -shiftUp));

      final Uint8List frontShifted = _renderDocumentOnWoodenTable(
        width: 240,
        height: 320,
        docRect: shiftedUpDoc,
        seed: 1,
      );
      final Uint8List backShifted = _renderDocumentOnWoodenTable(
        width: 240,
        height: 320,
        docRect: shiftedUpDoc,
        seed: 2,
      );

      final frontEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: frontShifted,
        isFront: true,
        isVerticalOrientation: false,
        normalizedRoiRect: exactSensorRoi,
      );
      expect(frontEval.isValid, isFalse);
      expect(frontEval.status, DocumentFrameStatus.outOfBounds);

      final backEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: backShifted,
        isFront: false,
        isVerticalOrientation: false,
        normalizedRoiRect: exactSensorRoi,
      );
      expect(backEval.isValid, isFalse);
      expect(backEval.status, DocumentFrameStatus.outOfBounds);
    });

    test('REJEITA documento deslocado para baixo, esquerda ou direita deixando borda vazia na moldura (Frente e Verso)', () {
      final List<Offset> shifts = <Offset>[
        Offset(0, exactSensorRoi.height * 0.24), // baixo (topo vazio + base vazando)
        Offset(-exactSensorRoi.width * 0.22, 0), // esquerda (direita vazia)
        Offset(exactSensorRoi.width * 0.22, 0), // direita (esquerda vazia)
      ];

      for (final bool isFront in const <bool>[true, false]) {
        for (final Offset delta in shifts) {
          final Uint8List shiftedBytes = _renderDocumentOnWoodenTable(
            width: 240,
            height: 320,
            docRect: exactSensorRoi.shift(delta),
            seed: isFront ? 1 : 2,
          );
          final eval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
            frameBytes: shiftedBytes,
            isFront: isFront,
            isVerticalOrientation: false,
            normalizedRoiRect: exactSensorRoi,
          );
          expect(
            eval.isValid,
            isFalse,
            reason:
                'Lado ${isFront ? "Frente" : "Verso"} com deslocamento $delta não pode ser aprovado!',
          );
          expect(eval.status, DocumentFrameStatus.outOfBounds);
        }
      }
    });
  });
}

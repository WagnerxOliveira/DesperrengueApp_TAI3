import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../security/perceptual_hash_guard.dart';
import '../utils/off_thread.dart';
import 'document_ocr_and_liveness_service.dart';

/// Estado determinístico da validação óptica em tempo real de um quadro
/// da câmera dentro do retângulo guia ISO/IEC 7810 ID-1.
enum DocumentFrameStatus {
  /// Todas as 4 bordas alinhadas, nitidez >= 115, reflexo <= 7.5%,
  /// iluminação [55..228], conteúdo impresso presente e lado distinto da frente.
  aligned,

  /// Mesa vazia, parede, superfície uniforme ou documento ausente da moldura.
  noDocument,

  /// Documento cortado ou extrapolando para fora das margens da moldura.
  outOfBounds,

  /// Documento muito distante / pequeno dentro do retângulo guia.
  tooFar,

  /// Nitidez Laplaciana insuficiente no interior do documento (< 115.0).
  blurry,

  /// Reflexo especular de luz excessivo sobre o documento (> 7.5%).
  excessiveGlare,

  /// Iluminação ambiente muito escura (< 55) ou estourada (> 228).
  poorLighting,

  /// Superfície sem conteúdo impresso (ex.: folha/cartão em branco).
  blankOrLowDetail,

  /// O verso apresentado é visualmente idêntico à frente já capturada.
  duplicateOfFront,
}

/// Diagnóstico completo de um único quadro capturado pela câmera traseira.
class DocumentFrameAssessment {
  const DocumentFrameAssessment({
    required this.status,
    required this.humanHint,
    required this.edgeAlignmentScore,
    required this.interiorExteriorContrast,
    required this.laplacianSharpness,
    required this.glareRatioPct,
    required this.meanLuminance,
    required this.contentDensityScore,
    required this.edgesDetectedCount,
    this.isDuplicateOfFront = false,
  });

  final DocumentFrameStatus status;
  final String humanHint;
  final double edgeAlignmentScore;
  final double interiorExteriorContrast;
  final double laplacianSharpness;
  final double glareRatioPct;
  final double meanLuminance;
  final double contentDensityScore;
  final int edgesDetectedCount;
  final bool isDuplicateOfFront;

  /// Somente `true` quando todos os 5 critérios ópticos foram aprovados.
  bool get isValid => status == DocumentFrameStatus.aligned;

  /// Atalho para criar um diagnóstico alinhado e aprovado (útil em testes).
  factory DocumentFrameAssessment.aligned({
    double edgeAlignmentScore = 0.94,
    double interiorExteriorContrast = 48.0,
    double laplacianSharpness = 260.0,
    double glareRatioPct = 1.2,
    double meanLuminance = 148.0,
    double contentDensityScore = 0.72,
    int edgesDetectedCount = 4,
  }) {
    return DocumentFrameAssessment(
      status: DocumentFrameStatus.aligned,
      humanHint: 'Documento enquadrado! Pronto para capturar',
      edgeAlignmentScore: edgeAlignmentScore,
      interiorExteriorContrast: interiorExteriorContrast,
      laplacianSharpness: laplacianSharpness,
      glareRatioPct: glareRatioPct,
      meanLuminance: meanLuminance,
      contentDensityScore: contentDensityScore,
      edgesDetectedCount: edgesDetectedCount,
    );
  }
}

/// Estado agregado da estabilidade temporal (contagem de quadros consecutivos válidos).
class DocumentAlignmentSnapshot {
  const DocumentAlignmentSnapshot({
    required this.assessment,
    required this.consecutiveValidFrames,
    required this.requiredStableFrames,
    required this.requiredAutoCaptureFrames,
  });

  final DocumentFrameAssessment assessment;
  final int consecutiveValidFrames;
  final int requiredStableFrames;
  final int requiredAutoCaptureFrames;

  /// Fica VERDE apenas após [requiredStableFrames] (padrão 3) quadros válidos seguidos.
  bool get isAlignedAndReady =>
      assessment.isValid && consecutiveValidFrames >= requiredStableFrames;

  /// Dispara captura automática suave após [requiredAutoCaptureFrames] (padrão 5, ~1,0 s).
  bool get readyForAutoCapture =>
      assessment.isValid && consecutiveValidFrames >= requiredAutoCaptureFrames;

  /// Progresso normalizado [0.0..1.0] da estabilidade para captura automática.
  double get autoCaptureProgress {
    if (!assessment.isValid || requiredAutoCaptureFrames <= 0) return 0.0;
    return (consecutiveValidFrames / requiredAutoCaptureFrames).clamp(0.0, 1.0);
  }
}

/// Rastreador temporal anti-tremulação:
/// - Exige 3 quadros consecutivos válidos para confirmar contorno VERDE (`isAlignedAndReady`).
/// - Exige 5 quadros consecutivos válidos (~1,0 s) para captura automática (`readyForAutoCapture`).
/// - Qualquer quadro inválido reseta imediatamente para 0 (VERMELHO).
class DocumentAlignmentTracker {
  DocumentAlignmentTracker({
    this.requiredStableFrames = 3,
    this.requiredAutoCaptureFrames = 5,
  }) : assert(requiredStableFrames >= 1),
       assert(requiredAutoCaptureFrames >= requiredStableFrames);

  final int requiredStableFrames;
  final int requiredAutoCaptureFrames;

  int _consecutiveValidFrames = 0;
  DocumentFrameAssessment? _latest;

  int get consecutiveValidFrames => _consecutiveValidFrames;
  DocumentFrameAssessment? get latest => _latest;
  bool get isAlignedAndReady =>
      (_latest?.isValid ?? false) &&
      _consecutiveValidFrames >= requiredStableFrames;
  bool get readyForAutoCapture =>
      (_latest?.isValid ?? false) &&
      _consecutiveValidFrames >= requiredAutoCaptureFrames;

  DocumentAlignmentSnapshot push(DocumentFrameAssessment assessment) {
    _latest = assessment;
    if (assessment.isValid) {
      _consecutiveValidFrames++;
    } else {
      _consecutiveValidFrames = 0;
    }
    return DocumentAlignmentSnapshot(
      assessment: assessment,
      consecutiveValidFrames: _consecutiveValidFrames,
      requiredStableFrames: requiredStableFrames,
      requiredAutoCaptureFrames: requiredAutoCaptureFrames,
    );
  }

  void reset() {
    _consecutiveValidFrames = 0;
    _latest = null;
  }
}

/// Motor real de visão computacional on-device que valida se há um documento oficial
/// corretamente posicionado dentro do retângulo guia ISO/IEC 7810 ID-1.
///
/// Critérios reais avaliados em cada quadro:
/// 1. Presença e alinhamento das 4 bordas no retângulo (gradiente Sobel perpendicular,
///    contraste interior vs. exterior, detecção de corte/extravasamento e distância).
/// 2. Nitidez Laplaciana no interior do documento (`>= 115.0`).
/// 3. Reflexo especular máximo (`<= 7.5%`).
/// 4. Iluminação adequada (luminância média `[55.0..228.0]`).
/// 5. Densidade de conteúdo impresso (rejeita folha em branco) + Anti-Duplicidade
///    Frente vs. Verso via `PerceptualHashGuard.evaluateDocumentFrontBackDistinction`.
class DocumentFrameAlignmentEngine {
  DocumentFrameAlignmentEngine._();

  static const double minLaplacianSharpness = 115.0;
  static const double maxGlareRatioPct = 7.5;
  static const double minMeanLuminance = 55.0;
  static const double maxMeanLuminance = 228.0;

  /// Versão assíncrona em Isolate secundário para manter a UI em 120 FPS.
  static Future<DocumentFrameAssessment> evaluateFrameBytesInIsolate({
    required Uint8List frameBytes,
    required bool isFront,
    bool isVerticalOrientation = false,
    Uint8List? referenceFrontBytes,
  }) {
    return runOffMainThread(
      () => evaluateFrameBytes(
        frameBytes: frameBytes,
        isFront: isFront,
        isVerticalOrientation: isVerticalOrientation,
        referenceFrontBytes: referenceFrontBytes,
      ),
    );
  }

  /// Avalia um quadro codificado (JPEG/PNG) da câmera traseira.
  static DocumentFrameAssessment evaluateFrameBytes({
    required Uint8List frameBytes,
    required bool isFront,
    bool isVerticalOrientation = false,
    Uint8List? referenceFrontBytes,
  }) {
    if (frameBytes.isEmpty) {
      return const DocumentFrameAssessment(
        status: DocumentFrameStatus.noDocument,
        humanHint: 'Posicione o documento inteiro dentro do retângulo.',
        edgeAlignmentScore: 0.0,
        interiorExteriorContrast: 0.0,
        laplacianSharpness: 0.0,
        glareRatioPct: 0.0,
        meanLuminance: 0.0,
        contentDensityScore: 0.0,
        edgesDetectedCount: 0,
      );
    }

    final img.Image? decoded = img.decodeImage(frameBytes);
    if (decoded == null) {
      return const DocumentFrameAssessment(
        status: DocumentFrameStatus.noDocument,
        humanHint: 'Posicione o documento inteiro dentro do retângulo.',
        edgeAlignmentScore: 0.0,
        interiorExteriorContrast: 0.0,
        laplacianSharpness: 0.0,
        glareRatioPct: 0.0,
        meanLuminance: 0.0,
        contentDensityScore: 0.0,
        edgesDetectedCount: 0,
      );
    }

    return evaluateDecodedFrame(
      frame: decoded,
      isFront: isFront,
      isVerticalOrientation: isVerticalOrientation,
      referenceFrontBytes: referenceFrontBytes,
    );
  }

  /// Avalia um quadro já decodificado (`img.Image`) da câmera ao vivo.
  static DocumentFrameAssessment evaluateDecodedFrame({
    required img.Image frame,
    required bool isFront,
    bool isVerticalOrientation = false,
    Uint8List? referenceFrontBytes,
    img.Image? referenceFrontDecoded,
  }) {
    if (frame.width < 40 || frame.height < 40) {
      return const DocumentFrameAssessment(
        status: DocumentFrameStatus.noDocument,
        humanHint: 'Posicione o documento inteiro dentro do retângulo.',
        edgeAlignmentScore: 0.0,
        interiorExteriorContrast: 0.0,
        laplacianSharpness: 0.0,
        glareRatioPct: 0.0,
        meanLuminance: 0.0,
        contentDensityScore: 0.0,
        edgesDetectedCount: 0,
      );
    }

    // Redimensiona preservando proporção para processamento rápido (< 6 ms)
    final img.Image work;
    final int maxDim = math.max(frame.width, frame.height);
    if (maxDim > 240) {
      final double scale = 240.0 / maxDim;
      work = img.copyResize(
        frame,
        width: math.max(48, (frame.width * scale).round()),
        height: math.max(48, (frame.height * scale).round()),
        interpolation: img.Interpolation.linear,
      );
    } else {
      work = frame;
    }

    final int w = work.width;
    final int h = work.height;

    // Mesmas proporções da moldura ISO ID-1 usadas no recorte final
    final double leftRatio = isVerticalOrientation ? 0.13 : 0.06;
    final double topRatio = isVerticalOrientation ? 0.16 : 0.22;
    final double widthRatio = isVerticalOrientation ? 0.74 : 0.88;
    final double heightRatio = isVerticalOrientation ? 0.68 : 0.56;

    final int rx0 = (w * leftRatio).round().clamp(2, w - 10);
    final int ry0 = (h * topRatio).round().clamp(2, h - 10);
    final int rx1 = (rx0 + (w * widthRatio).round()).clamp(rx0 + 16, w - 2);
    final int ry1 = (ry0 + (h * heightRatio).round()).clamp(ry0 + 16, h - 2);
    final int roiW = rx1 - rx0;
    final int roiH = ry1 - ry0;

    // 1. Mapa de luminância [0..255] em ponto flutuante
    final Float64List gray = Float64List(w * h);
    for (int y = 0; y < h; y++) {
      final int rowOff = y * w;
      for (int x = 0; x < w; x++) {
        final p = work.getPixel(x, y);
        gray[rowOff + x] = (0.299 * p.r) + (0.587 * p.g) + (0.114 * p.b);
      }
    }

    // 2. Estatísticas do Interior (ROI) vs. Exterior (fora da moldura)
    double roiLumSum = 0.0;
    int roiCount = 0;
    int glareCount = 0;

    double extLumSum = 0.0;
    int extCount = 0;
    int extStrongGradCount = 0;
    int extGradSamples = 0;

    for (int y = 1; y < h - 1; y++) {
      final int row = y * w;
      for (int x = 1; x < w - 1; x++) {
        final double lum = gray[row + x];
        final bool insideRoi = x >= rx0 && x < rx1 && y >= ry0 && y < ry1;
        if (insideRoi) {
          roiCount++;
          roiLumSum += lum;
          if (lum > 248.0) glareCount++;
        } else {
          extCount++;
          extLumSum += lum;

          // Exclui faixa imediata de 3px adjacente à borda do ROI para medir apenas o fundo externo
          final bool outsideBorderBand =
              x < rx0 - 3 || x > rx1 + 3 || y < ry0 - 3 || y > ry1 + 3;
          if (outsideBorderBand) {
            final double gx = (gray[row + (x + 1)] - gray[row + (x - 1)]).abs();
            final double gy = (gray[(y + 1) * w + x] - gray[(y - 1) * w + x]).abs();
            if (gx + gy >= 26.0) extStrongGradCount++;
            extGradSamples++;
          }
        }
      }
    }

    final double meanLum = roiCount > 0 ? (roiLumSum / roiCount) : 0.0;
    final double glarePct = roiCount > 0 ? ((glareCount / roiCount) * 100.0) : 100.0;
    final double extMeanLum = extCount > 0 ? (extLumSum / extCount) : meanLum;
    final double interiorExteriorContrast = (meanLum - extMeanLum).abs();
    final double extEdgeDensity =
        extGradSamples > 0 ? (extStrongGradCount / extGradSamples) : 0.0;

    // 3. Núcleo interno (inset 10%) vs. Anel externo interno (para detectar folha em branco e documento longe)
    final int insetX = math.max(3, (roiW * 0.10).round());
    final int insetY = math.max(3, (roiH * 0.10).round());
    final int cx0 = (rx0 + insetX).clamp(2, rx1 - 4);
    final int cy0 = (ry0 + insetY).clamp(2, ry1 - 4);
    final int cx1 = (rx1 - insetX).clamp(cx0 + 4, w - 2);
    final int cy1 = (ry1 - insetY).clamp(cy0 + 4, h - 2);

    final List<int> hist16 = List<int>.filled(16, 0);
    double coreLumSum = 0.0;
    double coreLumSqSum = 0.0;
    int coreCount = 0;
    int coreStrongGradCount = 0;

    // Faixa central (55% do ROI) vs. anel periférico interno (15% externos dentro do ROI)
    final int farRingX = math.max(3, (roiW * 0.16).round());
    final int farRingY = math.max(3, (roiH * 0.16).round());
    final int midX0 = rx0 + farRingX;
    final int midY0 = ry0 + farRingY;
    final int midX1 = rx1 - farRingX;
    final int midY1 = ry1 - farRingY;

    double ringLumSum = 0.0;
    int ringCount = 0;
    int ringStrongGradCount = 0;

    double centerLumSum = 0.0;
    double centerLumSqSum = 0.0;
    int centerCount = 0;
    int centerStrongGradCount = 0;

    for (int y = ry0 + 2; y < ry1 - 2; y++) {
      final int row = y * w;
      for (int x = rx0 + 2; x < rx1 - 2; x++) {
        final double lum = gray[row + x];
        final double gx = (gray[row + (x + 1)] - gray[row + (x - 1)]).abs();
        final double gy = (gray[(y + 1) * w + x] - gray[(y - 1) * w + x]).abs();
        final double gradMag = gx + gy;

        if (x >= cx0 && x < cx1 && y >= cy0 && y < cy1) {
          coreCount++;
          coreLumSum += lum;
          coreLumSqSum += lum * lum;
          final int bin = (lum / 16.0).floor().clamp(0, 15);
          hist16[bin]++;
          if (gradMag >= 24.0) coreStrongGradCount++;
        }

        final bool inCenter = x >= midX0 && x < midX1 && y >= midY0 && y < midY1;
        if (inCenter) {
          centerCount++;
          centerLumSum += lum;
          centerLumSqSum += lum * lum;
          if (gradMag >= 24.0) centerStrongGradCount++;
        } else {
          ringCount++;
          ringLumSum += lum;
          if (gradMag >= 24.0) ringStrongGradCount++;
        }
      }
    }

    final double coreMean = coreCount > 0 ? (coreLumSum / coreCount) : meanLum;
    final double coreVar = coreCount > 0
        ? math.max(0.0, (coreLumSqSum / coreCount) - (coreMean * coreMean))
        : 0.0;
    final double coreStdDev = math.sqrt(coreVar);
    final double coreEdgeDensity =
        coreCount > 0 ? (coreStrongGradCount / coreCount) : 0.0;

    double entropy = 0.0;
    if (coreCount > 0) {
      for (final c in hist16) {
        if (c > 0) {
          final double p = c / coreCount;
          entropy -= p * (math.log(p) / math.ln2);
        }
      }
    }

    final double contentDensityScore = (
      ((coreEdgeDensity / 0.16).clamp(0.0, 1.0) * 0.45) +
      ((coreStdDev / 36.0).clamp(0.0, 1.0) * 0.30) +
      ((entropy / 3.0).clamp(0.0, 1.0) * 0.25)
    ).clamp(0.0, 1.0);

    final double ringMean = ringCount > 0 ? (ringLumSum / ringCount) : meanLum;
    final double ringEdgeDensity =
        ringCount > 0 ? (ringStrongGradCount / ringCount) : 0.0;
    final double centerMean =
        centerCount > 0 ? (centerLumSum / centerCount) : meanLum;
    final double centerStdDev = centerCount > 0
        ? math.sqrt(math.max(0.0, (centerLumSqSum / centerCount) - (centerMean * centerMean)))
        : 0.0;
    final double centerEdgeDensity =
        centerCount > 0 ? (centerStrongGradCount / centerCount) : 0.0;

    // 4. Gradiente Sobel perpendicular nas 4 margens da moldura
    final int bandY = math.max(4, (roiH * 0.08).round());
    final int bandX = math.max(4, (roiW * 0.08).round());

    final _BorderScan topEdge = _scanHorizontalBorder(
      gray: gray,
      w: w,
      h: h,
      targetY: ry0,
      band: bandY,
      xStart: rx0 + (roiW * 0.15).round(),
      xEnd: rx1 - (roiW * 0.15).round(),
    );
    final _BorderScan bottomEdge = _scanHorizontalBorder(
      gray: gray,
      w: w,
      h: h,
      targetY: ry1 - 1,
      band: bandY,
      xStart: rx0 + (roiW * 0.15).round(),
      xEnd: rx1 - (roiW * 0.15).round(),
    );
    final _BorderScan leftEdge = _scanVerticalBorder(
      gray: gray,
      w: w,
      h: h,
      targetX: rx0,
      band: bandX,
      yStart: ry0 + (roiH * 0.15).round(),
      yEnd: ry1 - (roiH * 0.15).round(),
    );
    final _BorderScan rightEdge = _scanVerticalBorder(
      gray: gray,
      w: w,
      h: h,
      targetX: rx1 - 1,
      band: bandX,
      yStart: ry0 + (roiH * 0.15).round(),
      yEnd: ry1 - (roiH * 0.15).round(),
    );

    final List<_BorderScan> edges = <_BorderScan>[
      topEdge,
      bottomEdge,
      leftEdge,
      rightEdge,
    ];
    final int edgesDetected = edges.where((e) => e.detected).length;
    final double edgeAlignmentScore = (
      edges.fold<double>(0.0, (sum, e) => sum + e.normalizedStrength) / 4.0
    ).clamp(0.0, 1.0);

    // 5. Nitidez Laplaciana estritamente no interior do ROI (escala 160x120)
    final double laplacian = _computeCoreRoiLaplacian(
      work: work,
      rx0: rx0,
      ry0: ry0,
      roiW: roiW,
      roiH: roiH,
    );

    // -------------------------------------------------------------------------
    // DECISÃO DETERMINÍSTICA DOS 5 CRITÉRIOS (priorizando orientação acionável)
    // -------------------------------------------------------------------------

    // A) Verifica se documento está muito longe (pequeno no centro do ROI, cercado pela mesa)
    final bool outerRingMatchesTable =
        (ringMean - extMeanLum).abs() <= 22.0 && ringEdgeDensity < 0.08;
    final bool centerHasDocumentContent =
        centerEdgeDensity >= 0.08 && centerStdDev >= 16.0;
    if (edgesDetected < 3 && outerRingMatchesTable && centerHasDocumentContent) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.tooFar,
        humanHint:
            'Documento muito distante. Aproxime a câmera até preencher o retângulo.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // B) Verifica se o documento está cortado / extrapolando para fora da moldura
    final bool hasRichRoiContent = coreEdgeDensity >= 0.05 || coreStdDev >= 15.0;
    final bool hasOverflowOutside =
        _detectOuterEdgeOverflow(
          gray: gray,
          w: w,
          h: h,
          rx0: rx0,
          ry0: ry0,
          rx1: rx1,
          ry1: ry1,
          topDetected: topEdge.detected,
          bottomDetected: bottomEdge.detected,
          leftDetected: leftEdge.detected,
          rightDetected: rightEdge.detected,
          coreMean: coreMean,
          extMean: extMeanLum,
        ) ||
        (edgesDetected >= 1 && edgesDetected < 4 && extEdgeDensity >= 0.08);

    if (edgesDetected < 4 && hasRichRoiContent && hasOverflowOutside) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.outOfBounds,
        humanHint:
            'Documento cortado nas bordas. Encaixe os 4 cantos dentro do retângulo.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // C) Presença das 4 bordas (rejeita mesa vazia, parede ou imagem uniforme),
    //    mas prioriza aviso de ambiente escuro se houver baixa luz com indício de conteúdo.
    if (meanLum < minMeanLuminance && (edgesDetected >= 2 || coreStdDev >= 10.0)) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.poorLighting,
        humanHint:
            'Ambiente escuro. Leve o documento para um local mais iluminado ou ligue a lanterna.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    if (edgesDetected < 4) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.noDocument,
        humanHint:
            'Posicione o documento inteiro sobre uma superfície firme dentro do retângulo.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // D) Iluminação ambiente no ROI ([55..228])
    if (meanLum < minMeanLuminance) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.poorLighting,
        humanHint:
            'Ambiente escuro. Leve o documento para um local mais iluminado ou ligue a lanterna.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }
    if (meanLum > maxMeanLuminance) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.poorLighting,
        humanHint:
            'Luz muito forte sobre o documento. Evite iluminação direta e ajuste o ângulo.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // E) Reflexo especular (Glare <= 7.5%)
    if (glarePct > maxGlareRatioPct) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.excessiveGlare,
        humanHint:
            'Há reflexo de luz no documento. Incline levemente o cartão para tirar o brilho.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // F) Densidade de conteúdo impresso (rejeita folha/cartão em branco com bordas nítidas)
    if (coreStdDev < 12.0 && coreEdgeDensity < 0.04) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.blankOrLowDetail,
        humanHint:
            'Não identificamos texto ou foto no documento. Posicione o lado impresso dentro da moldura.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // G) Nitidez Laplaciana no ROI (>= 115.0)
    if (laplacian < minLaplacianSharpness) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.blurry,
        humanHint:
            'Imagem um pouco desfocada. Segure o celular firme até a câmera focar.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // Rejeita conteúdo excessivamente pobre mesmo com ruído pontual
    // (permite documentos de alto contraste monocromáticos como QR/texto preto no papel claro)
    if (contentDensityScore < 0.22 ||
        (entropy < 1.0 && coreEdgeDensity < 0.06 && coreStdDev < 22.0)) {
      return DocumentFrameAssessment(
        status: DocumentFrameStatus.blankOrLowDetail,
        humanHint:
            'Não identificamos texto ou foto no documento. Posicione o lado impresso dentro da moldura.',
        edgeAlignmentScore: edgeAlignmentScore,
        interiorExteriorContrast: interiorExteriorContrast,
        laplacianSharpness: laplacian,
        glareRatioPct: glarePct,
        meanLuminance: meanLum,
        contentDensityScore: contentDensityScore,
        edgesDetectedCount: edgesDetected,
      );
    }

    // H) Anti-Duplicidade Frente != Verso (quando capturando o Verso)
    if (!isFront && (referenceFrontBytes != null || referenceFrontDecoded != null)) {
      final bool duplicate = _isDuplicateOfFrontSide(
        currentFrame: frame,
        isVerticalOrientation: isVerticalOrientation,
        referenceFrontBytes: referenceFrontBytes,
        referenceFrontDecoded: referenceFrontDecoded,
      );
      if (duplicate) {
        return DocumentFrameAssessment(
          status: DocumentFrameStatus.duplicateOfFront,
          humanHint:
              'Este lado parece ser a frente. Vire o documento para o verso.',
          edgeAlignmentScore: edgeAlignmentScore,
          interiorExteriorContrast: interiorExteriorContrast,
          laplacianSharpness: laplacian,
          glareRatioPct: glarePct,
          meanLuminance: meanLum,
          contentDensityScore: contentDensityScore,
          edgesDetectedCount: edgesDetected,
          isDuplicateOfFront: true,
        );
      }
    }

    return DocumentFrameAssessment(
      status: DocumentFrameStatus.aligned,
      humanHint: 'Documento enquadrado! Pronto para capturar',
      edgeAlignmentScore: edgeAlignmentScore,
      interiorExteriorContrast: interiorExteriorContrast,
      laplacianSharpness: laplacian,
      glareRatioPct: glarePct,
      meanLuminance: meanLum,
      contentDensityScore: contentDensityScore,
      edgesDetectedCount: edgesDetected,
    );
  }

  static _BorderScan _scanHorizontalBorder({
    required Float64List gray,
    required int w,
    required int h,
    required int targetY,
    required int band,
    required int xStart,
    required int xEnd,
  }) {
    final int minY = (targetY - band).clamp(1, h - 2);
    final int maxY = (targetY + band).clamp(1, h - 2);
    final int xs = xStart.clamp(1, w - 2);
    final int xe = xEnd.clamp(xs + 2, w - 2);
    final int span = xe - xs;
    if (span <= 0) {
      return const _BorderScan(detected: false, score: 0.0, coverage: 0.0);
    }

    double bestScore = 0.0;
    double bestCoverage = 0.0;
    for (int y = minY; y <= maxY; y++) {
      double gradSum = 0.0;
      int hits = 0;
      final int rowTop = (y - 1) * w;
      final int rowBot = (y + 1) * w;
      for (int x = xs; x < xe; x++) {
        final double top =
            gray[rowTop + x - 1] + (2.0 * gray[rowTop + x]) + gray[rowTop + x + 1];
        final double bot =
            gray[rowBot + x - 1] + (2.0 * gray[rowBot + x]) + gray[rowBot + x + 1];
        final double gy = (bot - top).abs() * 0.25;
        gradSum += gy;
        if (gy >= 10.0) hits++;
      }
      final double meanGrad = gradSum / span;
      final double coverage = hits / span;
      final double weighted = meanGrad * coverage;
      if (weighted > bestScore) {
        bestScore = weighted;
        bestCoverage = coverage;
      }
    }

    final bool detected = bestScore >= 11.5 && bestCoverage >= 0.45;
    return _BorderScan(
      detected: detected,
      score: bestScore,
      coverage: bestCoverage,
    );
  }

  static _BorderScan _scanVerticalBorder({
    required Float64List gray,
    required int w,
    required int h,
    required int targetX,
    required int band,
    required int yStart,
    required int yEnd,
  }) {
    final int minX = (targetX - band).clamp(1, w - 2);
    final int maxX = (targetX + band).clamp(1, w - 2);
    final int ys = yStart.clamp(1, h - 2);
    final int ye = yEnd.clamp(ys + 2, h - 2);
    final int span = ye - ys;
    if (span <= 0) {
      return const _BorderScan(detected: false, score: 0.0, coverage: 0.0);
    }

    double bestScore = 0.0;
    double bestCoverage = 0.0;
    for (int x = minX; x <= maxX; x++) {
      double gradSum = 0.0;
      int hits = 0;
      for (int y = ys; y < ye; y++) {
        final int rPrev = (y - 1) * w;
        final int rCurr = y * w;
        final int rNext = (y + 1) * w;
        final double left =
            gray[rPrev + x - 1] + (2.0 * gray[rCurr + x - 1]) + gray[rNext + x - 1];
        final double right =
            gray[rPrev + x + 1] + (2.0 * gray[rCurr + x + 1]) + gray[rNext + x + 1];
        final double gx = (right - left).abs() * 0.25;
        gradSum += gx;
        if (gx >= 10.0) hits++;
      }
      final double meanGrad = gradSum / span;
      final double coverage = hits / span;
      final double weighted = meanGrad * coverage;
      if (weighted > bestScore) {
        bestScore = weighted;
        bestCoverage = coverage;
      }
    }

    final bool detected = bestScore >= 11.5 && bestCoverage >= 0.45;
    return _BorderScan(
      detected: detected,
      score: bestScore,
      coverage: bestCoverage,
    );
  }

  static bool _detectOuterEdgeOverflow({
    required Float64List gray,
    required int w,
    required int h,
    required int rx0,
    required int ry0,
    required int rx1,
    required int ry1,
    required bool topDetected,
    required bool bottomDetected,
    required bool leftDetected,
    required bool rightDetected,
    required double coreMean,
    required double extMean,
  }) {
    // Se alguma borda não foi detectada, checa se o lado externo correspondente
    // tem textura ou luminância de documento extrapolando até a borda da câmera.
    bool stripMatchesDocument(int x0, int y0, int x1, int y1) {
      if (x1 <= x0 + 1 || y1 <= y0 + 1) return false;
      double sum = 0.0;
      int count = 0;
      int strongGrads = 0;
      for (int y = math.max(1, y0); y < math.min(h - 1, y1); y++) {
        final int row = y * w;
        for (int x = math.max(1, x0); x < math.min(w - 1, x1); x++) {
          sum += gray[row + x];
          count++;
          final double gx = (gray[row + x + 1] - gray[row + x - 1]).abs();
          final double gy = (gray[(y + 1) * w + x] - gray[(y - 1) * w + x]).abs();
          if (gx + gy >= 22.0) strongGrads++;
        }
      }
      if (count == 0) return false;
      final double stripMean = sum / count;
      final double stripGradRatio = strongGrads / count;
      final bool closerToDocThanBg =
          (coreMean - extMean).abs() >= 18.0 &&
          (stripMean - coreMean).abs() < (stripMean - extMean).abs();
      return stripGradRatio >= 0.08 || closerToDocThanBg;
    }

    if (!topDetected && stripMatchesDocument(rx0, 1, rx1, ry0)) return true;
    if (!bottomDetected && stripMatchesDocument(rx0, ry1, rx1, h - 1)) {
      return true;
    }
    if (!leftDetected && stripMatchesDocument(1, ry0, rx0, ry1)) return true;
    if (!rightDetected && stripMatchesDocument(rx1, ry0, w - 1, ry1)) {
      return true;
    }
    return false;
  }

  static double _computeCoreRoiLaplacian({
    required img.Image work,
    required int rx0,
    required int ry0,
    required int roiW,
    required int roiH,
  }) {
    final int padX = math.max(2, (roiW * 0.06).round());
    final int padY = math.max(2, (roiH * 0.06).round());
    final int x = (rx0 + padX).clamp(0, work.width - 4);
    final int y = (ry0 + padY).clamp(0, work.height - 4);
    final int cw = math.max(4, roiW - (2 * padX)).clamp(4, work.width - x);
    final int ch = math.max(4, roiH - (2 * padY)).clamp(4, work.height - y);

    final img.Image cropped = img.copyCrop(
      work,
      x: x,
      y: y,
      width: cw,
      height: ch,
    );
    final int targetW = math.min(cropped.width, 160);
    final int targetH = math.min(cropped.height, 120);
    final img.Image sample = (cropped.width != targetW || cropped.height != targetH)
        ? img.copyResize(cropped, width: targetW, height: targetH)
        : cropped;

    if (sample.width < 3 || sample.height < 3) return 0.0;
    final int sw = sample.width;
    final int sh = sample.height;
    final List<int> gray = List<int>.filled(sw * sh, 0);
    for (int py = 0; py < sh; py++) {
      for (int px = 0; px < sw; px++) {
        final p = sample.getPixel(px, py);
        gray[py * sw + px] =
            ((77 * p.r.toInt()) + (150 * p.g.toInt()) + (29 * p.b.toInt())) >> 8;
      }
    }

    double sum = 0.0;
    double sqSum = 0.0;
    int count = 0;
    for (int py = 1; py < sh - 1; py++) {
      for (int px = 1; px < sw - 1; px++) {
        final int c = gray[py * sw + px];
        final int top = gray[(py - 1) * sw + px];
        final int bottom = gray[(py + 1) * sw + px];
        final int left = gray[py * sw + (px - 1)];
        final int right = gray[py * sw + (px + 1)];
        final double v = (top + bottom + left + right - (4 * c)).toDouble();
        sum += v;
        sqSum += v * v;
        count++;
      }
    }
    if (count == 0) return 0.0;
    final double mean = sum / count;
    return math.max(0.0, (sqSum / count) - (mean * mean));
  }

  static bool _isDuplicateOfFrontSide({
    required img.Image currentFrame,
    required bool isVerticalOrientation,
    Uint8List? referenceFrontBytes,
    img.Image? referenceFrontDecoded,
  }) {
    try {
      final Uint8List? refBytes = referenceFrontBytes ??
          (referenceFrontDecoded != null
              ? Uint8List.fromList(img.encodeJpg(referenceFrontDecoded, quality: 90))
              : null);
      if (refBytes == null || refBytes.isEmpty) return false;

      // Recorta o quadro atual para a mesma janela ROI da frente capturada
      final Uint8List currentRaw =
          Uint8List.fromList(img.encodeJpg(currentFrame, quality: 90));
      final Uint8List currentRoi =
          DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: currentRaw,
        isVerticalOrientation: isVerticalOrientation,
      );

      final metricsRoi = PerceptualHashGuard.evaluateDocumentFrontBackDistinction(
        refBytes,
        currentRoi,
        0.12,
      );
      if (metricsRoi.isDuplicate) return true;

      // Também compara diretamente caso o chamador tenha passado o quadro inteiro como referência
      final metricsFull = PerceptualHashGuard.evaluateDocumentFrontBackDistinction(
        refBytes,
        currentRaw,
        0.12,
      );
      return metricsFull.isDuplicate;
    } catch (_) {
      return false;
    }
  }
}

class _BorderScan {
  const _BorderScan({
    required this.detected,
    required this.score,
    required this.coverage,
  });

  final bool detected;
  final double score;
  final double coverage;

  double get normalizedStrength =>
      ((score / 36.0).clamp(0.0, 1.0) * 0.65 + coverage.clamp(0.0, 1.0) * 0.35)
          .clamp(0.0, 1.0);
}

/**
 * Desperrengue KYC Real Vision Bridge (Web / PWA — v2.29.0)
 *
 * Carregado sob demanda (lazy load) pelo `face_detection_adapter_web.dart`
 * sem poluir `app/web/index.html`.
 *
 * Utiliza `@mediapipe/tasks-vision` `FaceLandmarker` com:
 * - `runningMode: "VIDEO"`
 * - `numFaces: 2` (para rejeitar múltiplas pessoas na câmera)
 * - `outputFaceBlendshapes: true` (eyeBlinkLeft / eyeBlinkRight com filtro EMA anti-flutter)
 * - `outputFacialTransformationMatrixes: true` (decomposição 4x4 real em Euler yaw/pitch/roll)
 * - `<canvas>` offscreen para luminância, nitidez, anti-monitor e micro-movimento anti-foto-parada
 * - Fallback gracioso GPU -> CPU; se indisponível, retorna `unavailable: true` (jamais aprova sem movimento real!).
 */

const MEDIAPIPE_VISION_ESM =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/vision_bundle.mjs';
const MEDIAPIPE_WASM_ROOT =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/wasm';
const FACE_LANDMARKER_MODEL =
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task';

const EMA_ALPHA = 0.55;
const ROI_GRID = 24;
const CANVAS_W = 128;
const CANVAS_H = 96;

class DesperrengueKycVisionBridge {
  constructor() {
    this.landmarker = null;
    this.initializing = null;
    this.unavailableReason = null;
    this.lastVideoTimestampMs = -1;

    // Estado EMA anti-flutter para piscada bilateral.
    this.emaBlinkLeft = null;
    this.emaBlinkRight = null;

    // Rastreamento sintético contínuo para trackingId (detecta troca de pessoa ou ausência > 1200ms).
    this.currentTrackingId = 1;
    this.lastFaceCenter = null;
    this.lastFaceSeenMs = 0;

    // Canvas offscreen e grade 24x24 anterior para qualidade óptica + micro-movimento.
    this.canvas = null;
    this.ctx = null;
    this.previousPatch = null;
  }

  async init() {
    if (this.landmarker) {
      return { ok: true };
    }
    if (this.initializing) {
      return this.initializing;
    }

    this.initializing = this._initInternal();
    try {
      return await this.initializing;
    } finally {
      this.initializing = null;
    }
  }

  async _initInternal() {
    try {
      const visionModule = await import(MEDIAPIPE_VISION_ESM);
      const { FilesetResolver, FaceLandmarker } = visionModule;
      if (!FilesetResolver || !FaceLandmarker) {
        this.unavailableReason =
          'Não foi possível preparar o leitor facial neste navegador.';
        return { ok: false, reason: this.unavailableReason };
      }

      const fileset = await FilesetResolver.forVisionTasks(MEDIAPIPE_WASM_ROOT);

      // Tenta GPU (WebGL) primeiro; em caso de falha de WebGL, tenta CPU de forma graciosa.
      const delegates = ['GPU', 'CPU'];
      let lastError = null;
      for (const delegate of delegates) {
        try {
          this.landmarker = await FaceLandmarker.createFromOptions(fileset, {
            baseOptions: {
              modelAssetPath: FACE_LANDMARKER_MODEL,
              delegate,
            },
            runningMode: 'VIDEO',
            numFaces: 2,
            outputFaceBlendshapes: true,
            outputFacialTransformationMatrixes: true,
            minFaceDetectionConfidence: 0.55,
            minFacePresenceConfidence: 0.55,
            minTrackingConfidence: 0.55,
          });
          this.unavailableReason = null;
          this.lastVideoTimestampMs = -1;
          return { ok: true, delegate };
        } catch (err) {
          lastError = err;
        }
      }

      this.unavailableReason =
        'Seu navegador não conseguiu iniciar a análise facial ao vivo. Tente atualizar o navegador ou usar o celular.';
      return {
        ok: false,
        reason: this.unavailableReason,
        detail: lastError ? String(lastError) : 'UNAVAILABLE',
      };
    } catch (err) {
      this.unavailableReason =
        'Não foi possível carregar o recurso de verificação facial. Verifique sua conexão e tente novamente.';
      return {
        ok: false,
        reason: this.unavailableReason,
        detail: String(err),
      };
    }
  }

  _findActiveVideo() {
    const videos = Array.from(document.querySelectorAll('video'));
    for (let i = videos.length - 1; i >= 0; i--) {
      const v = videos[i];
      if (v && v.readyState >= 2 && v.videoWidth > 0 && v.videoHeight > 0) {
        return v;
      }
    }
    return null;
  }

  _ensureCanvas() {
    if (!this.canvas) {
      this.canvas = document.createElement('canvas');
      this.canvas.width = CANVAS_W;
      this.canvas.height = CANVAS_H;
      this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });
    }
    return this.ctx;
  }

  /**
   * Decompõe a matriz 4x4 column-major do MediaPipe (`facialTransformationMatrixes[0].data`)
   * em ângulos de Euler reais (em graus):
   * - pitch (X), yaw (Y), roll (Z).
   * Na câmera frontal espelhada, positivo em yaw = giro para a direita do usuário.
   */
  _decomposeTransformationMatrix(matrixData, mirrorHorizontal) {
    if (!matrixData || matrixData.length < 16) {
      return { pitch: 0, yaw: 0, roll: 0 };
    }
    const r00 = matrixData[0];
    const r10 = matrixData[1];
    const r02 = matrixData[8];
    const r12 = matrixData[9];
    const r22 = matrixData[10];

    const radToDeg = 180 / Math.PI;
    const rawYaw = Math.atan2(r02, r22) * radToDeg;
    const pitch = Math.atan2(-r12, Math.hypot(r02, r22)) * radToDeg;
    const roll = Math.atan2(r10, r00) * radToDeg;

    const unifiedYaw = mirrorHorizontal ? -rawYaw : rawYaw;
    return {
      pitch: Number.isFinite(pitch) ? pitch : 0,
      yaw: Number.isFinite(unifiedYaw) ? unifiedYaw : 0,
      roll: Number.isFinite(roll) ? roll : 0,
    };
  }

  _computeBoxFromLandmarks(landmarks, mirrorHorizontal) {
    let minX = 1.0;
    let minY = 1.0;
    let maxX = 0.0;
    let maxY = 0.0;
    for (let i = 0; i < landmarks.length; i++) {
      const pt = landmarks[i];
      if (pt.x < minX) minX = pt.x;
      if (pt.y < minY) minY = pt.y;
      if (pt.x > maxX) maxX = pt.x;
      if (pt.y > maxY) maxY = pt.y;
    }

    let left = Math.max(0, Math.min(1, minX));
    let right = Math.max(0, Math.min(1, maxX));
    const top = Math.max(0, Math.min(1, minY));
    const bottom = Math.max(0, Math.min(1, maxY));

    if (mirrorHorizontal) {
      const mLeft = Math.max(0, Math.min(1, 1.0 - right));
      const mRight = Math.max(0, Math.min(1, 1.0 - left));
      left = mLeft;
      right = mRight;
    }

    return { left, top, right, bottom };
  }

  _computeCanvasRoiMetrics(video, box, mirrorHorizontal, updateBaseline) {
    const ctx = this._ensureCanvas();
    if (!ctx) {
      return {
        meanLuminance: 0,
        sharpness: 0,
        blueMonitorRatio: 0,
        textureMotionDelta: 0,
      };
    }

    ctx.save();
    if (mirrorHorizontal) {
      ctx.translate(CANVAS_W, 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(video, 0, 0, CANVAS_W, CANVAS_H);
    ctx.restore();

    const imgData = ctx.getImageData(0, 0, CANVAS_W, CANVAS_H).data;
    const rawW = Math.max(0.05, box.right - box.left);
    const rawH = Math.max(0.05, box.bottom - box.top);
    const insetX = rawW * 0.12;
    const insetY = rawH * 0.12;
    const innerLeft = Math.max(0, Math.min(0.95, box.left + insetX));
    const innerRight = Math.max(innerLeft + 0.05, Math.min(1, box.right - insetX));
    const innerTop = Math.max(0, Math.min(0.95, box.top + insetY));
    const innerBottom = Math.max(innerTop + 0.05, Math.min(1, box.bottom - insetY));

    const x0 = Math.max(1, Math.min(CANVAS_W - 2, Math.floor(innerLeft * CANVAS_W)));
    const y0 = Math.max(1, Math.min(CANVAS_H - 2, Math.floor(innerTop * CANVAS_H)));
    const x1 = Math.max(x0 + 2, Math.min(CANVAS_W - 1, Math.ceil(innerRight * CANVAS_W)));
    const y1 = Math.max(y0 + 2, Math.min(CANVAS_H - 1, Math.ceil(innerBottom * CANVAS_H)));

    let lumSum = 0;
    let gradSum = 0;
    let bluePixels = 0;
    let samples = 0;

    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        const idx = (y * CANVAS_W + x) * 4;
        const r = imgData[idx];
        const g = imgData[idx + 1];
        const b = imgData[idx + 2];
        const luma = 0.299 * r + 0.587 * g + 0.114 * b;
        lumSum += luma;

        // Assinatura real de brilho azulado de tela LCD/OLED (sem punir barba/cabelo escuro).
        if (b > r + 24 && b > g + 10 && luma >= 40) {
          bluePixels++;
        }

        const idxR = (y * CANVAS_W + (x + 1)) * 4;
        const idxD = ((y + 1) * CANVAS_W + x) * 4;
        const lumaR =
          0.299 * imgData[idxR] + 0.587 * imgData[idxR + 1] + 0.114 * imgData[idxR + 2];
        const lumaD =
          0.299 * imgData[idxD] + 0.587 * imgData[idxD + 1] + 0.114 * imgData[idxD + 2];
        gradSum += Math.abs(lumaR - luma) + Math.abs(lumaD - luma);
        samples++;
      }
    }

    if (samples === 0) {
      return {
        meanLuminance: 0,
        sharpness: 0,
        blueMonitorRatio: 0,
        textureMotionDelta: 0,
      };
    }

    const patch = new Float32Array(ROI_GRID * ROI_GRID);
    const roiW = Math.max(1, x1 - x0);
    const roiH = Math.max(1, y1 - y0);
    for (let gy = 0; gy < ROI_GRID; gy++) {
      const sy = Math.min(CANVAS_H - 1, y0 + Math.floor((gy * roiH) / ROI_GRID));
      for (let gx = 0; gx < ROI_GRID; gx++) {
        const sx = Math.min(CANVAS_W - 1, x0 + Math.floor((gx * roiW) / ROI_GRID));
        const idx = (sy * CANVAS_W + sx) * 4;
        patch[gy * ROI_GRID + gx] =
          0.299 * imgData[idx] + 0.587 * imgData[idx + 1] + 0.114 * imgData[idx + 2];
      }
    }

    let motionDelta = 1.0;
    if (this.previousPatch && this.previousPatch.length === patch.length) {
      let diffSum = 0;
      for (let i = 0; i < patch.length; i++) {
        diffSum += Math.abs(patch[i] - this.previousPatch[i]);
      }
      motionDelta = diffSum / patch.length;
    }

    if (updateBaseline) {
      this.previousPatch = patch;
    }

    return {
      meanLuminance: lumSum / samples,
      sharpness: (gradSum / samples) * 1.4,
      blueMonitorRatio: bluePixels / samples,
      textureMotionDelta: motionDelta,
    };
  }

  detectFromActiveVideo(mirrorHorizontal = true) {
    const nowEpochMs = Date.now();
    if (!this.landmarker) {
      return {
        unavailable: true,
        reason:
          this.unavailableReason ||
          'Leitor facial ao vivo indisponível neste navegador.',
        timestampMs: nowEpochMs,
      };
    }

    const video = this._findActiveVideo();
    if (!video) {
      return null;
    }

    // MediaPipe VIDEO mode exige timestamp estritamente crescente em ms.
    let perfMs = Math.floor(performance.now());
    if (perfMs <= this.lastVideoTimestampMs) {
      perfMs = this.lastVideoTimestampMs + 1;
    }
    this.lastVideoTimestampMs = perfMs;

    let result;
    try {
      result = this.landmarker.detectForVideo(video, perfMs);
    } catch (_) {
      return {
        unavailable: true,
        reason:
          'O navegador interrompeu a análise do vídeo ao vivo. Tente novamente.',
        timestampMs: nowEpochMs,
      };
    }

    const allLandmarks = (result && result.faceLandmarks) || [];
    const faceCount = allLandmarks.length;

    if (faceCount === 0) {
      this.emaBlinkLeft = null;
      this.emaBlinkRight = null;
      this.previousPatch = null;
      const metrics = this._computeCanvasRoiMetrics(
        video,
        { left: 0.18, top: 0.16, right: 0.82, bottom: 0.84 },
        mirrorHorizontal,
        false
      );
      return {
        faceCount: 0,
        trackingId: null,
        boxLeft: 0,
        boxTop: 0,
        boxRight: 0,
        boxBottom: 0,
        leftEyeOpenProbability: null,
        rightEyeOpenProbability: null,
        headEulerAngleX: 0,
        headEulerAngleY: 0,
        headEulerAngleZ: 0,
        meanLuminance: metrics.meanLuminance,
        sharpness: metrics.sharpness,
        blueMonitorRatio: metrics.blueMonitorRatio,
        textureMotionDelta: metrics.textureMotionDelta,
        timestampMs: nowEpochMs,
      };
    }

    // Seleciona o rosto principal (maior caixa delimitadora) preservando faceCount real.
    let primaryIdx = 0;
    let primaryBox = this._computeBoxFromLandmarks(allLandmarks[0], mirrorHorizontal);
    let largestArea =
      (primaryBox.right - primaryBox.left) * (primaryBox.bottom - primaryBox.top);
    for (let i = 1; i < faceCount; i++) {
      const candBox = this._computeBoxFromLandmarks(allLandmarks[i], mirrorHorizontal);
      const area = (candBox.right - candBox.left) * (candBox.bottom - candBox.top);
      if (area > largestArea) {
        primaryIdx = i;
        primaryBox = candBox;
        largestArea = area;
      }
    }

    // Atualiza trackingId sintético verificando continuidade temporal e espacial.
    const centerX = (primaryBox.left + primaryBox.right) * 0.5;
    const centerY = (primaryBox.top + primaryBox.bottom) * 0.5;
    if (
      this.lastFaceCenter === null ||
      nowEpochMs - this.lastFaceSeenMs > 1200 ||
      Math.hypot(centerX - this.lastFaceCenter.x, centerY - this.lastFaceCenter.y) > 0.28
    ) {
      this.currentTrackingId += 1;
      this.previousPatch = null;
      this.emaBlinkLeft = null;
      this.emaBlinkRight = null;
    }
    this.lastFaceCenter = { x: centerX, y: centerY };
    this.lastFaceSeenMs = nowEpochMs;

    // Extrai eyeBlinkLeft e eyeBlinkRight dos blendshapes com filtro EMA anti-flutter.
    let leftEyeOpen = null;
    let rightEyeOpen = null;
    const blendshapes =
      result.faceBlendshapes && result.faceBlendshapes[primaryIdx]
        ? result.faceBlendshapes[primaryIdx].categories || []
        : [];
    let rawBlinkLeft = null;
    let rawBlinkRight = null;
    for (let i = 0; i < blendshapes.length; i++) {
      const cat = blendshapes[i];
      if (cat.categoryName === 'eyeBlinkLeft') {
        rawBlinkLeft = cat.score;
      } else if (cat.categoryName === 'eyeBlinkRight') {
        rawBlinkRight = cat.score;
      }
    }

    if (typeof rawBlinkLeft === 'number' && typeof rawBlinkRight === 'number') {
      this.emaBlinkLeft =
        this.emaBlinkLeft === null
          ? rawBlinkLeft
          : EMA_ALPHA * rawBlinkLeft + (1 - EMA_ALPHA) * this.emaBlinkLeft;
      this.emaBlinkRight =
        this.emaBlinkRight === null
          ? rawBlinkRight
          : EMA_ALPHA * rawBlinkRight + (1 - EMA_ALPHA) * this.emaBlinkRight;

      leftEyeOpen = Math.max(0, Math.min(1, 1.0 - this.emaBlinkLeft));
      rightEyeOpen = Math.max(0, Math.min(1, 1.0 - this.emaBlinkRight));
    }

    // Decomposição 4x4 em Euler yaw/pitch/roll reais.
    const matrixObj =
      result.facialTransformationMatrixes &&
      result.facialTransformationMatrixes[primaryIdx];
    const euler = this._decomposeTransformationMatrix(
      matrixObj ? matrixObj.data : null,
      mirrorHorizontal
    );

    const metrics = this._computeCanvasRoiMetrics(
      video,
      primaryBox,
      mirrorHorizontal,
      true
    );

    return {
      faceCount,
      trackingId: this.currentTrackingId,
      boxLeft: primaryBox.left,
      boxTop: primaryBox.top,
      boxRight: primaryBox.right,
      boxBottom: primaryBox.bottom,
      leftEyeOpenProbability: leftEyeOpen,
      rightEyeOpenProbability: rightEyeOpen,
      headEulerAngleX: euler.pitch,
      headEulerAngleY: euler.yaw,
      headEulerAngleZ: euler.roll,
      meanLuminance: metrics.meanLuminance,
      sharpness: metrics.sharpness,
      blueMonitorRatio: metrics.blueMonitorRatio,
      textureMotionDelta: metrics.textureMotionDelta,
      timestampMs: nowEpochMs,
    };
  }

  dispose() {
    if (this.landmarker) {
      try {
        this.landmarker.close();
      } catch (_) {}
      this.landmarker = null;
    }
    this.emaBlinkLeft = null;
    this.emaBlinkRight = null;
    this.lastFaceCenter = null;
    this.previousPatch = null;
    this.canvas = null;
    this.ctx = null;
  }
}

window.DesperrengueKycVision = new DesperrengueKycVisionBridge();
window.dispatchEvent(new CustomEvent('desperrengue:kyc-vision-ready'));

export const aiPart5Html = `
<!-- ======================================================================= -->
<!-- APÊNDICE TÉCNICO — BLUEPRINTS DE CÓDIGO DART, EDGE FUNCTIONS E SCHEMAS  -->
<!-- ======================================================================= -->
<div class="page-break"></div>
<div class="section-header-banner">
  <span class="sh-tag">APÊNDICE DE ENGENHARIA DE SOFTWARE &bull; ESPECIFICAÇÃO DE CÓDIGO</span>
  <h2>BLUEPRINTS EXECUTÁVEIS: DART ISOLATE, EDGE FUNCTIONS E JSON SCHEMAS</h2>
  <p>Implementações de referência prontas para produção das camadas críticas de processamento espectral, homografia e orquestração multimodal.</p>
</div>

<h3>A.1. Blueprint Dart — Worker Isolate de Diagnóstico Espectral Acústico-Vibracional (<span class="mono">acoustic_spectral_analyzer.dart</span>)</h3>
<p>
  O módulo abaixo demonstra como o Desperrengue processa um buffer PCM de $44,1\text{ kHz}$ combinado com leituras triaxiais do acelerômetro a $200\text{ Hz}$ dentro de um <code>Isolate.run</code> sem bloquear um único frame de $8,33\text{ ms}$ da interface gráfica a 120 FPS:
</p>
<div class="info-card" style="margin-bottom:10px; font-family:'Cascadia Code','Consolas',monospace; font-size:7.3pt; line-height:1.34; background:#0F172A; color:#E2E8F0; border-top:3px solid #FF6D00;">
  <div style="color:#FF8A2B; font-weight:800; margin-bottom:4px;">// app/lib/core/ai/acoustic_spectral_analyzer.dart</div>
  import 'dart:isolate';<br/>
  import 'dart:math' as math;<br/>
  import 'dart:typed_data';<br/><br/>
  class AcousticDiagnosticReport {<br/>
  &nbsp;&nbsp;const AcousticDiagnosticReport({<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.faultCode,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.faultLabel,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.confidence,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.dominantFreqHz,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.harmonic120HzRatio,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;required this.suggestedSmartSplitMaterialCap,<br/>
  &nbsp;&nbsp;});<br/>
  &nbsp;&nbsp;final String faultCode;<br/>
  &nbsp;&nbsp;final String faultLabel;<br/>
  &nbsp;&nbsp;final double confidence;<br/>
  &nbsp;&nbsp;final double dominantFreqHz;<br/>
  &nbsp;&nbsp;final double harmonic120HzRatio;<br/>
  &nbsp;&nbsp;final double suggestedSmartSplitMaterialCap;<br/>
  }<br/><br/>
  Future&lt;AcousticDiagnosticReport&gt; analyzeApplianceSpectrumInIsolate({<br/>
  &nbsp;&nbsp;required Int16List pcm44kSamples,<br/>
  &nbsp;&nbsp;required Float32List imuTriaxialMagnitudes,<br/>
  &nbsp;&nbsp;required String categoryName,<br/>
  }) {<br/>
  &nbsp;&nbsp;final transferablePcm = TransferableTypedData.fromList([pcm44kSamples]);<br/>
  &nbsp;&nbsp;final transferableImu = TransferableTypedData.fromList([imuTriaxialMagnitudes]);<br/>
  &nbsp;&nbsp;return Isolate.run(() {<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final pcm = transferablePcm.materialize().asInt16List();<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final imu = transferableImu.materialize().asFloat32List();<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;// 1. Calcula energia em 60Hz/120Hz (zumbido magnético/capacitor) vs banda 2kHz-10kHz (arco elétrico)<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final e60 = _goertzelBandPower(pcm, targetHz: 60.0, sampleRate: 44100);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final e120 = _goertzelBandPower(pcm, targetHz: 120.0, sampleRate: 44100);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final eArc = _goertzelBandPower(pcm, targetHz: 4200.0, sampleRate: 44100);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final imuRms = _computeRms(imu);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final total = e60 + e120 + eArc + 1e-9;<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;final ratio120 = (e60 + e120) / total;<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;if (ratio120 &gt; 0.68 &amp;&amp; imuRms &lt; 1.8) {<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return AcousticDiagnosticReport(<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;faultCode: 'CAPACITOR_START_HUM_60_120HZ',<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;faultLabel: 'Capacitor de Partida Degradado (Zumbido 60/120Hz sem rotação)',<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;confidence: 0.92,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;dominantFreqHz: 120.0,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;harmonic120HzRatio: ratio120,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;suggestedSmartSplitMaterialCap: 85.00, // Trava teto de peça em R$ 85 (evita golpe do compressor)<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;}<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;return AcousticDiagnosticReport(<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;faultCode: 'ELECTRICAL_CORONA_OR_ARCING',<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;faultLabel: 'Centelhamento / Mau Contato Térmico em Terminal Elétrico',<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;confidence: 0.89,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;dominantFreqHz: 4200.0,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;harmonic120HzRatio: ratio120,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;suggestedSmartSplitMaterialCap: 140.00,<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;);<br/>
  &nbsp;&nbsp;});<br/>
  }
</div>

<h3>A.2. Blueprint Deno/TypeScript — Edge Function <span class="mono">sefaz-xml-auditor</span> e <span class="mono">actuarial-escrow-underwriter</span></h3>
<p>
  O código abaixo ilustra a estrutura da Edge Function que audita os itens da Nota Fiscal (filtrando ferramentas pessoais via código NCM) e executa a subscrição atuarial para liberar o <code>PIX D+0 Instantâneo</code> ou o <code>PIX-Insumo Garantido</code>:
</p>
<div class="info-card" style="margin-bottom:10px; font-family:'Cascadia Code','Consolas',monospace; font-size:7.3pt; line-height:1.34; background:#0F172A; color:#E2E8F0; border-top:3px solid #38BDF8;">
  <div style="color:#38BDF8; font-weight:800; margin-bottom:4px;">// supabase/functions/sefaz-xml-auditor/index.ts</div>
  import { serve } from "https://deno.land/std@0.224.0/http/server.ts";<br/>
  import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";<br/><br/>
  // Prefixos NCM de bens de capital / ferramentas permanentes (vedados na isenção de 0% de insumos)<br/>
  const FORBIDDEN_TOOL_NCM_PREFIXES = ["8203", "8204", "8205", "8207", "8467", "9030"];<br/>
  const ALLOWED_HARDWARE_STORE_MCCS = new Set(["5211", "5251", "5065", "5072", "5074"]);<br/><br/>
  serve(async (req: Request) =&gt; {<br/>
  &nbsp;&nbsp;const { jobId, accessKey44, pixPayeeCnpj, pixMerchantMcc, items } = await req.json();<br/>
  &nbsp;&nbsp;if (!/^\d{44}$/.test(accessKey44) || !validateMod11AccessKey(accessKey44)) {<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;return new Response(JSON.stringify({ error: "INVALID_SEFAZ_KEY_MOD11" }), { status: 400 });<br/>
  &nbsp;&nbsp;}<br/>
  &nbsp;&nbsp;const issuerCnpj = accessKey44.substring(6, 20);<br/>
  &nbsp;&nbsp;let approvedConsumables = 0;<br/>
  &nbsp;&nbsp;let rejectedTools = 0;<br/>
  &nbsp;&nbsp;for (const item of items) {<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;const isCapitalTool = FORBIDDEN_TOOL_NCM_PREFIXES.some((p) =&gt; item.ncm.startsWith(p));<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;if (isCapitalTool) rejectedTools += Number(item.vProd);<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;else approvedConsumables += Number(item.vProd);<br/>
  &nbsp;&nbsp;}<br/>
  &nbsp;&nbsp;// Trava PIX-Insumo Garantido: CNPJ do QR Code PIX deve ser idêntico ao CNPJ emissor da NFC-e na SEFAZ<br/>
  &nbsp;&nbsp;const canSettleDirectToMerchant = (pixPayeeCnpj === issuerCnpj) &amp;&amp; ALLOWED_HARDWARE_STORE_MCCS.has(pixMerchantMcc);<br/>
  &nbsp;&nbsp;return new Response(JSON.stringify({<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;jobId, issuerCnpj, approvedConsumables, rejectedTools, canSettleDirectToMerchant<br/>
  &nbsp;&nbsp;}), { headers: { "Content-Type": "application/json" } });<br/>
  });
</div>

<h3>A.3. Tabela de Governança de Prompts e Structured Schemas (JSON Schema Draft-07)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th style="width:24%">Agente de IA / Endpoint</th>
      <th style="width:20%">Modelo &amp; Temperatura</th>
      <th style="width:28%">Propriedades Obrigatórias do <code>responseSchema</code></th>
      <th style="width:28%">Invariante de Segurança / Fallback Determinístico</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>ai-multimodal-triage</code></td>
      <td>Gemini 2.5 Flash<br/><code>temp = 0.10</code></td>
      <td><code>probableCause</code>, <code>severityLevel</code>, <code>containmentSteps[]</code>, <code>bomItems[]</code>, <code>fairLaborMinMax</code></td>
      <td>Se latência &gt; <code>2.800 ms</code> ou offline, aciona instantaneamente o <code>SmartTriageService</code> determinístico local.</td>
    </tr>
    <tr>
      <td><code>sefaz-xml-auditor</code></td>
      <td>Regras NCM + Gemini 2.5 Flash (<code>temp = 0.0</code>)</td>
      <td><code>itemIndex</code>, <code>ncmCode</code>, <code>classification</code> (<code>CONSUMABLE</code> | <code>CAPITAL_TOOL</code>), <code>visualMatchScore</code></td>
      <td>Qualquer item sem código NCM válido de 8 dígitos ou divergente da categoria da OS cai em retenção manual.</td>
    </tr>
    <tr>
      <td><code>actuarial-escrow-underwriter</code></td>
      <td>ONNX LightGBM<br/>(Determinístico)</td>
      <td><code>reworkProbability90d</code>, <code>actuarialPremiumRate</code>, <code>settlementTier</code>, <code>shapTopFactors[]</code></td>
      <td>Nunca libera <code>PIX_D0_INSTANT</code> se a distância de check-in GPS exceder <code>150m</code> ou se <code>ransac_inlier_ratio &lt; 0.22</code>.</td>
    </tr>
    <tr>
      <td><code>ai-dispute-arbitrator</code></td>
      <td>Gemini 2.5 Pro<br/><code>temp = 0.05</code></td>
      <td><code>forensicSummary</code>, <code>providerFaultProb</code>, <code>nashRefundAmount</code>, <code>cdcArticlesApplied[]</code></td>
      <td>A sentença de IA é sempre proposta como acordo voluntário rápido; se recusada, escala com o dossiê pronto ao mediador.</td>
    </tr>
  </tbody>
</table>
`;

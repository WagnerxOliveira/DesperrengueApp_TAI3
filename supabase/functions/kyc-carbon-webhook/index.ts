// Edge Function: kyc-carbon-webhook
//
// Ponte Transacional Zero-Trust entre o microsserviço Python FastAPI (Carbon High)
// e o banco PostgreSQL do Supabase.
//
// Invariantes de Segurança:
//  1. Valida `X-KYC-Timestamp` contra janela anti-replay estrita (<= 300 segundos);
//  2. Calcula `HMAC-SHA256(SUPABASE_KYC_WEBHOOK_SECRET, "<timestamp>.<raw_body_bytes>")`
//     diretamente sobre os bytes brutos do body e compara em tempo constante
//     (`timingSafeEqual`) com `X-KYC-Signature`;
//  3. Invoca `public.apply_verified_carbon_kyc_verdict` exclusivamente com
//     `SUPABASE_SERVICE_ROLE_KEY`, preservando idempotência, Anti-Sybil por CPF Hash,
//     Unificação Multi-Modo (+30 pts RTS) e Same-Holder PIX Lock;
//  4. Jamais registra CPF ou segredos sem máscara LGPD nos logs.

import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const WEBHOOK_SECRET = Deno.env.get("SUPABASE_KYC_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MAX_SKEW_SECONDS = 300;

let cachedAdminClient: ReturnType<typeof createClient> | null = null;
function getAdminClient() {
  if (!cachedAdminClient) {
    cachedAdminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
  }
  return cachedAdminClient;
}

const JSON_HEADERS: Record<string, string> = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

const jsonResponse = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HEX_64_REGEX = /^[0-9a-f]{64}$/i;

function redactPiiForLog(text: string): string {
  return text
    .replace(/(?<!\d)(\d{3})\.?(\d{3})\.?(\d{3})-?(\d{2})(?!\d)/g, "***.$2.$3-**")
    .replace(/(x-kyc-signature\s*[=:]\s*)[A-Za-z0-9+/=_.-]+/gi, "$1[REDACTED]");
}

function hexToBytes(hex: string): Uint8Array | null {
  if (hex.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(hex)) {
    return null;
  }
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function computeWebhookHmacBytes(
  secret: string,
  timestampSec: number,
  rawBody: Uint8Array,
): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const prefix = enc.encode(`${timestampSec}.`);
  const signedInput = new Uint8Array(prefix.length + rawBody.length);
  signedInput.set(prefix, 0);
  signedInput.set(rawBody, prefix.length);
  const macBuffer = await crypto.subtle.sign("HMAC", key, signedInput);
  return new Uint8Array(macBuffer);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!WEBHOOK_SECRET || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("kyc-carbon-webhook: segredos obrigatórios de servidor ausentes.");
    return jsonResponse({ error: "Server configuration unavailable" }, 503);
  }

  const tsHeader = (req.headers.get("x-kyc-timestamp") ?? "").trim();
  const sigHeader = (req.headers.get("x-kyc-signature") ?? "").trim().toLowerCase();

  if (!/^\d{10,12}$/.test(tsHeader) || !HEX_64_REGEX.test(sigHeader)) {
    return jsonResponse({ error: "Missing or malformed webhook authentication headers" }, 401);
  }

  const timestampSec = Number(tsHeader);
  const nowSec = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(timestampSec) || Math.abs(nowSec - timestampSec) > MAX_SKEW_SECONDS) {
    return jsonResponse({ error: "Webhook timestamp outside anti-replay window" }, 401);
  }

  const rawBody = new Uint8Array(await req.arrayBuffer());
  if (rawBody.length === 0 || rawBody.length > 262_144) {
    return jsonResponse({ error: "Invalid webhook payload size" }, 400);
  }

  const providedSigBytes = hexToBytes(sigHeader);
  const expectedSigBytes = await computeWebhookHmacBytes(
    WEBHOOK_SECRET,
    timestampSec,
    rawBody,
  );
  if (
    !providedSigBytes ||
    providedSigBytes.length !== expectedSigBytes.length ||
    !timingSafeEqual(providedSigBytes, expectedSigBytes)
  ) {
    return jsonResponse({ error: "Invalid webhook HMAC signature" }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(new TextDecoder("utf-8").decode(rawBody));
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const eventId = typeof payload.event_id === "string" ? payload.event_id.trim() : "";
  const userId = typeof payload.user_id === "string" ? payload.user_id.trim() : "";
  const sessionNonceHash =
    typeof payload.session_nonce_hash === "string" ? payload.session_nonce_hash.trim() : "";
  const verdictStatus =
    typeof payload.verdict_status === "string" ? payload.verdict_status.trim() : "";
  const riskTier = typeof payload.risk_tier === "string" ? payload.risk_tier.trim() : "";
  const wormDigest =
    typeof payload.worm_evidence_digest === "string" ? payload.worm_evidence_digest.trim() : "";

  const cpfAntiSybilHash =
    typeof payload.cpf_anti_sybil_hash === "string" ? payload.cpf_anti_sybil_hash.trim() : "";
  const faceLivenessHash =
    typeof payload.face_liveness_hash === "string" ? payload.face_liveness_hash.trim() : "";
  const shapFactors = Array.isArray(payload.shap_top_3_factors)
    ? payload.shap_top_3_factors
        .slice(0, 3)
        .map((item) => redactPiiForLog(String(item).trim()))
        .filter((item) => item.length > 0)
    : [];

  if (
    !UUID_REGEX.test(eventId) ||
    !UUID_REGEX.test(userId) ||
    !HEX_64_REGEX.test(sessionNonceHash) ||
    !HEX_64_REGEX.test(wormDigest) ||
    !HEX_64_REGEX.test(cpfAntiSybilHash) ||
    !HEX_64_REGEX.test(faceLivenessHash) ||
    shapFactors.length !== 3 ||
    !["APPROVED", "MANUAL_REVIEW", "REJECTED"].includes(verdictStatus) ||
    !["LOW", "MEDIUM", "HIGH", "CRITICAL"].includes(riskTier)
  ) {
    return jsonResponse({ error: "Invalid forensic verdict contract" }, 422);
  }

  const birthDateIso =
    typeof payload.birth_date_iso === "string" && /^\d{4}-\d{2}-\d{2}$/.test(payload.birth_date_iso)
      ? payload.birth_date_iso
      : null;

  const admin = getAdminClient();
  const { data, error } = await admin.rpc("apply_verified_carbon_kyc_verdict", {
    p_event_id: eventId,
    p_user_id: userId,
    p_session_nonce_hash: sessionNonceHash,
    p_signature_timestamp: timestampSec,
    p_cpf_masked: redactPiiForLog(String(payload.cpf_masked ?? "***.***.***-**")),
    p_cpf_anti_sybil_hash: cpfAntiSybilHash,
    p_face_liveness_hash: faceLivenessHash,
    p_verified_full_name: String(payload.verified_full_name ?? "").slice(0, 160),
    p_document_type: String(payload.document_type ?? "CIN"),
    p_birth_date: birthDateIso,
    p_issuing_authority:
      typeof payload.issuing_authority_uf === "string"
        ? payload.issuing_authority_uf.slice(0, 40)
        : null,
    p_verdict_status: verdictStatus,
    p_confidence_score: Number(payload.confidence_score ?? 0),
    p_risk_tier: riskTier,
    p_alcada_restriction:
      typeof payload.alcada_restriction === "string" ? payload.alcada_restriction : null,
    p_hard_veto_code:
      typeof payload.hard_veto_code === "string" ? payload.hard_veto_code : null,
    p_shap_top_3_factors: shapFactors,
    p_vio_signature_verified: Boolean(payload.vio_signature_verified),
    p_nfc_passive_auth_verified: Boolean(payload.nfc_passive_auth_verified),
    p_serpro_similarity_score:
      typeof payload.serpro_similarity_score === "number"
        ? payload.serpro_similarity_score
        : null,
    p_device_integrity_verdict: String(payload.device_integrity_verdict ?? "UNKNOWN").slice(0, 64),
    p_liveness_score: Number(payload.liveness_score ?? 0),
    p_local_face_match_score: Number(payload.local_face_match_score ?? 0),
    p_worm_evidence_digest: wormDigest,
  });

  if (error) {
    const safeCode = redactPiiForLog(String(error.code ?? "RPC_ERR"));
    console.error(`kyc-carbon-webhook rpc failure event_id=${eventId} code=${safeCode}`);
    if (error.code === "23505") {
      return jsonResponse({ error: "Identity or session conflict detected", code: safeCode }, 409);
    }
    if (error.code === "P0002") {
      return jsonResponse({ error: "Target user profile not found", code: safeCode }, 404);
    }
    return jsonResponse({ error: "Transactional verdict persistence failed", code: safeCode }, 500);
  }

  return jsonResponse({ ok: true, result: data }, 200);
});

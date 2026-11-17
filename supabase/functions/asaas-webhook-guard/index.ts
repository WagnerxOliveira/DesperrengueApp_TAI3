// Edge Function: asaas-webhook-guard (v2.19.0 — Asaas Outbound Security Mechanism < 50ms)
//
// Guardião Síncrono de Autorização de Saques e Transferências do Asaas:
//   1. Validação em Tempo Constante do header `asaas-access-token` (>= 32 caracteres).
//   2. Proibição Estrita de Reúso de Chave: bloqueia caso `ASAAS_WEBHOOK_ACCESS_TOKEN` seja
//      idêntico a `ASAAS_SANDBOX_API_KEY` ou `ASAAS_PRODUCTION_API_KEY`.
//   3. Anti-Replay Criptográfico (`SHA-256` do corpo + deduplicação de `event_id` no banco).
//   4. Proteção Anti-Coação (`FROZEN_UNDER_DURESS`): responde `{"status":"REFUSED"}` em
//      tempo real, retendo 100% do saldo bancário real mesmo sob assalto/extorsão.

import { createClient } from "@supabase/supabase-js";

const MAX_WEBHOOK_BYTES = 65_536;

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SERVICE_ROLE_KEY = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
const WEBHOOK_SECRET = (Deno.env.get("ASAAS_WEBHOOK_ACCESS_TOKEN") ?? "").trim();
const ASAAS_SANDBOX_KEY = (Deno.env.get("ASAAS_SANDBOX_API_KEY") ?? "").trim();
const ASAAS_PROD_KEY = (Deno.env.get("ASAAS_PRODUCTION_API_KEY") ?? "").trim();

const supabaseAdmin = SUPABASE_URL.length > 0 && SERVICE_ROLE_KEY.length > 0
  ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  : null;

const HEADERS: Record<string, string> = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
  "X-Content-Type-Options": "nosniff",
};

function constantTimeEqualsAscii(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    const ca = i < a.length ? a.charCodeAt(i) : 0;
    const cb = i < b.length ? b.charCodeAt(i) : 0;
    diff |= ca ^ cb;
  }
  return diff === 0;
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const hashBuf = await crypto.subtle.digest("SHA-256", bytes);
  const arr = new Uint8Array(hashBuf);
  let hex = "";
  for (let i = 0; i < arr.length; i++) {
    hex += arr[i]!.toString(16).padStart(2, "0");
  }
  return hex;
}

function refusedResponse(reason: string, status = 200): Response {
  return new Response(
    JSON.stringify({ status: "REFUSED", refuseReason: reason }),
    { status, headers: HEADERS },
  );
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return refusedResponse("Método HTTP não permitido.", 405);
  }

  if (!supabaseAdmin) {
    return refusedResponse("Guardião de tesouraria indisponível.", 503);
  }

  // Exige segredo exclusivo >= 32 chars e estritamente distinto das chaves de API Asaas
  if (
    WEBHOOK_SECRET.length < 32 ||
    (ASAAS_SANDBOX_KEY.length > 0 && constantTimeEqualsAscii(WEBHOOK_SECRET, ASAAS_SANDBOX_KEY)) ||
    (ASAAS_PROD_KEY.length > 0 && constantTimeEqualsAscii(WEBHOOK_SECRET, ASAAS_PROD_KEY))
  ) {
    return refusedResponse("Configuração criptográfica do webhook pendente de segredo exclusivo.", 403);
  }

  const incomingToken = (req.headers.get("asaas-access-token") ?? "").trim();
  if (!incomingToken || !constantTimeEqualsAscii(incomingToken, WEBHOOK_SECRET)) {
    return refusedResponse("Credencial de webhook inválida.", 401);
  }

  const contentLengthHeader = Number(req.headers.get("content-length") ?? "0");
  if (contentLengthHeader > MAX_WEBHOOK_BYTES) {
    return refusedResponse("Payload excede o limite de segurança.", 413);
  }

  const rawBody = await req.text();
  if (rawBody.length === 0 || rawBody.length > MAX_WEBHOOK_BYTES) {
    return refusedResponse("Corpo da requisição fora dos limites permitidos.", 413);
  }

  let parsed: Record<string, unknown>;
  try {
    const obj = JSON.parse(rawBody);
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
      throw new Error("INVALID_ROOT");
    }
    parsed = obj as Record<string, unknown>;
  } catch {
    return refusedResponse("JSON malformado.", 400);
  }

  const payloadSha = await sha256Hex(rawBody);
  const transferObj = (
    parsed.transfer && typeof parsed.transfer === "object" && !Array.isArray(parsed.transfer)
      ? parsed.transfer
      : parsed
  ) as Record<string, unknown>;

  const bankAccount = (
    transferObj.bankAccount && typeof transferObj.bankAccount === "object"
      ? transferObj.bankAccount
      : {}
  ) as Record<string, unknown>;

  const transferId = String(transferObj.id ?? parsed.id ?? "").trim();
  const eventId = String(parsed.id ?? (transferId ? `tx:${transferId}` : `sha:${payloadSha.slice(0, 24)}`)).trim();
  const eventType = String(parsed.event ?? parsed.type ?? "TRANSFER_VALIDATION").trim();
  const rawVal = Number(transferObj.value ?? 0);
  const amountCents = Number.isFinite(rawVal) && rawVal > 0 ? Math.round(rawVal * 100) : 0;
  const targetDoc = String(
    bankAccount.cpfCnpj ??
      transferObj.pixAddressKey ??
      "",
  ).trim();
  const externalRef = String(transferObj.externalReference ?? "").trim();

  const { data, error } = await supabaseAdmin.rpc(
    "ceo_edge_authorize_asaas_webhook_transfer",
    {
      p_event_id: eventId,
      p_event_type: eventType,
      p_transfer_id: transferId,
      p_amount_cents: amountCents,
      p_target_cpf_cnpj: targetDoc,
      p_external_reference: externalRef,
      p_payload_sha256: payloadSha,
    },
  );

  if (error || !data) {
    return refusedResponse("Falha fechada na validação soberana de custódia.");
  }

  const verdict = data as Record<string, unknown>;
  if (verdict.status === "APPROVED") {
    return new Response(JSON.stringify({ status: "APPROVED" }), {
      status: 200,
      headers: HEADERS,
    });
  }

  return refusedResponse(
    String(verdict.refuseReason ?? "Operação recusada pelo cofre de tesouraria."),
  );
});

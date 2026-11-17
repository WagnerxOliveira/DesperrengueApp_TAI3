// Edge Function: ceo-treasury-authority (v2.19.0 — Deno v2 Native mTLS 1.3 + Asaas v3)
//
// Autoridade Soberana da Tesouraria Bivalente (`SANDBOX_PRE_CNPJ` vs `PRODUCTION_SLU`):
//   1. Autenticação Monocrática AAL3: JWT verificado + `wagneroliveira2395@gmail.com` +
//      validação criptográfica de `stepup_token` + `device_hash` no PostgreSQL 17.
//   2. Trava Física Zero-Digitação PIX: REJEITA imediatamente qualquer chave JSON não
//      listada na allowlist estrita (impossível injetar `pix_key`, `cpf`, `override_url`).
//   3. Equação de Teto Seguro em BIGINT: protege 100% dos 85% de prestadores, 0% peças NF-e,
//      1,5% fundo garantidor, 6% provisão DAS, despesas pagas/agendadas e colchão de segurança.
//   4. Adaptador Nativo mTLS 1.3 (`Deno.createHttpClient`) homologado para Banco Inter Empresas
//      e Efí Bank PIX + Integração Asaas v3 (`/v3/transfers` com `externalReference`).
//   5. Comprovante Falso Convincente Silencioso (`FROZEN_UNDER_DURESS`): piso temporal
//      constante de 380ms e payload externo indistinguível enquanto retém 100% do saldo real.

import { createClient } from "@supabase/supabase-js";

const MONOCRATIC_CEO_EMAIL = "wagneroliveira2395@gmail.com";
const MAX_PAYLOAD_BYTES = 16_384;
const CONSTANT_TIME_FLOOR_MS = 380;

const ALLOWED_BODY_KEYS = new Set<string>([
  "action",
  "stepup_token",
  "device_hash",
  "idempotency_key",
  "distribution_kind",
  "requested_cents",
]);

const PINNED_PSP_ORIGINS: Readonly<Record<string, string>> = Object.freeze({
  ASAAS_SANDBOX: "https://api-sandbox.asaas.com",
  ASAAS_PRODUCTION: "https://api.asaas.com",
  INTER_MTLS_SANDBOX: "https://cdpj-sandbox.partners.uatinter.co",
  INTER_MTLS_PRODUCTION: "https://cdpj.partners.bancointer.com.br",
  EFI_MTLS_SANDBOX: "https://pix-h.api.efipay.com.br",
  EFI_MTLS_PRODUCTION: "https://pix.api.efipay.com.br",
});

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SERVICE_ROLE_KEY = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();

const supabaseAdmin = SUPABASE_URL.length > 0 && SERVICE_ROLE_KEY.length > 0
  ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  : null;

const JSON_SECURITY_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store, no-cache, must-revalidate, private, max-age=0",
  "Pragma": "no-cache",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...JSON_SECURITY_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

async function enforceLatencyFloor(startedAtMs: number): Promise<void> {
  const elapsed = performance.now() - startedAtMs;
  const remaining = Math.ceil(CONSTANT_TIME_FLOOR_MS - elapsed);
  if (remaining > 0) {
    await new Promise((resolve) => setTimeout(resolve, remaining));
  }
}

function sanitizeErrorText(raw: string): string {
  // Jamais permite vazamento acidental de chaves PEM ou tokens de API em mensagens de erro.
  if (
    raw.includes("BEGIN ") ||
    raw.includes("PRIVATE KEY") ||
    raw.includes("$aact_") ||
    raw.includes("Bearer ")
  ) {
    return "ERR_PSP_SANITIZED_FAULT";
  }
  return raw.slice(0, 140);
}

function assertPinnedOriginUrl(pspCode: string, path: string): URL {
  const base = PINNED_PSP_ORIGINS[pspCode];
  if (!base) {
    throw new Error("ERR_UNTRUSTED_PSP_ADAPTER");
  }
  const url = new URL(path, base);
  if (url.protocol !== "https:" || url.origin !== base) {
    throw new Error("ERR_SSRF_ORIGIN_VIOLATION");
  }
  return url;
}

interface ExternalPayoutResult {
  succeeded: boolean;
  transferId?: string;
  failureReason?: string;
}

function decodePemSecret(envName: string): string {
  const raw = (Deno.env.get(envName) ?? "").trim();
  if (!raw) return "";
  if (raw.includes("-----BEGIN")) {
    return raw.replace(/\\n/g, "\n");
  }
  try {
    return atob(raw);
  } catch {
    return "";
  }
}

async function executeAsaasTransfer(
  pspCode: "ASAAS_SANDBOX" | "ASAAS_PRODUCTION",
  distributionId: string,
  requestedCents: number,
  solePartnerCpfDigits: string,
): Promise<ExternalPayoutResult> {
  const apiKey = (
    pspCode === "ASAAS_PRODUCTION"
      ? Deno.env.get("ASAAS_PRODUCTION_API_KEY")
      : Deno.env.get("ASAAS_SANDBOX_API_KEY")
  )?.trim() ?? "";

  if (!apiKey) {
    return {
      succeeded: false,
      failureReason: `MISSING_${pspCode}_API_KEY`,
    };
  }

  const endpoint = assertPinnedOriginUrl(pspCode, "/v3/transfers");
  const valueBrl = Number((requestedCents / 100).toFixed(2));

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": "Desperrengue-Sovereign-Treasury/2.19",
      "access_token": apiKey,
    },
    body: JSON.stringify({
      value: valueBrl,
      operationType: "PIX",
      pixAddressKey: solePartnerCpfDigits,
      pixAddressKeyType: "CPF",
      description: `Distribuicao Soberana SLU #${distributionId.slice(0, 8)}`,
      externalReference: distributionId,
    }),
  });

  const payload = await res.json().catch(() => ({} as Record<string, unknown>));
  if (!res.ok) {
    return {
      succeeded: false,
      failureReason: sanitizeErrorText(`ASAAS_HTTP_${res.status}`),
    };
  }

  const txId = typeof payload.id === "string" && payload.id.length > 0
    ? payload.id
    : `ASAAS-${distributionId.slice(0, 8)}`;

  return { succeeded: true, transferId: txId };
}

async function executeMtlsPixPayout(
  pspCode:
    | "INTER_MTLS_SANDBOX"
    | "INTER_MTLS_PRODUCTION"
    | "EFI_MTLS_SANDBOX"
    | "EFI_MTLS_PRODUCTION",
  distributionId: string,
  requestedCents: number,
  solePartnerCpfDigits: string,
): Promise<ExternalPayoutResult> {
  const isProd = pspCode.endsWith("_PRODUCTION");
  const isInter = pspCode.startsWith("INTER_");
  const prefix = `${isInter ? "INTER" : "EFI"}_${isProd ? "PROD" : "SANDBOX"}`;

  const certPem = decodePemSecret(`${prefix}_MTLS_CERT_PEM`);
  const keyPem = decodePemSecret(`${prefix}_MTLS_KEY_PEM`);
  const clientId = (Deno.env.get(`${prefix}_CLIENT_ID`) ?? "").trim();
  const clientSecret = (Deno.env.get(`${prefix}_CLIENT_SECRET`) ?? "").trim();

  if (
    !certPem.includes("BEGIN CERTIFICATE") ||
    !keyPem.includes("PRIVATE KEY") ||
    !clientId ||
    !clientSecret
  ) {
    return {
      succeeded: false,
      failureReason: `MISSING_${prefix}_MTLS_CREDENTIALS`,
    };
  }

  // Túnel nativo mTLS 1.3 no Deno Runtime v2 (`Deno.createHttpClient`)
  const mtlsClient = Deno.createHttpClient({
    cert: certPem,
    key: keyPem,
  });

  try {
    let accessToken = "";
    if (isInter) {
      const tokenUrl = assertPinnedOriginUrl(pspCode, "/oauth/v2/token");
      const form = new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: "client_credentials",
        scope: "pagamento-pix.write",
      });
      const tokRes = await fetch(tokenUrl, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form.toString(),
        client: mtlsClient,
      });
      if (!tokRes.ok) {
        return { succeeded: false, failureReason: `INTER_OAUTH_HTTP_${tokRes.status}` };
      }
      const tokJson = await tokRes.json() as Record<string, unknown>;
      accessToken = String(tokJson.access_token ?? "");
    } else {
      const tokenUrl = assertPinnedOriginUrl(pspCode, "/oauth/token");
      const basic = btoa(`${clientId}:${clientSecret}`);
      const tokRes = await fetch(tokenUrl, {
        method: "POST",
        headers: {
          "Authorization": `Basic ${basic}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ grant_type: "client_credentials" }),
        client: mtlsClient,
      });
      if (!tokRes.ok) {
        return { succeeded: false, failureReason: `EFI_OAUTH_HTTP_${tokRes.status}` };
      }
      const tokJson = await tokRes.json() as Record<string, unknown>;
      accessToken = String(tokJson.access_token ?? "");
    }

    if (!accessToken) {
      return { succeeded: false, failureReason: "EMPTY_MTLS_OAUTH_TOKEN" };
    }

    const valorStr = (requestedCents / 100).toFixed(2);
    if (isInter) {
      const pixUrl = assertPinnedOriginUrl(pspCode, "/banking/v2/pix");
      const payRes = await fetch(pixUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          "x-id-idempotente": distributionId,
        },
        body: JSON.stringify({
          valor: Number(valorStr),
          descricao: `Distribuicao Lucros SLU ${distributionId.slice(0, 8)}`,
          destinatario: {
            tipo: "CHAVE",
            chave: solePartnerCpfDigits,
          },
        }),
        client: mtlsClient,
      });
      if (!payRes.ok) {
        return { succeeded: false, failureReason: `INTER_PIX_HTTP_${payRes.status}` };
      }
      const payJson = await payRes.json().catch(() => ({} as Record<string, unknown>));
      return {
        succeeded: true,
        transferId: String(payJson.codigoSolicitacao ?? payJson.endToEndId ?? `INTER-${distributionId.slice(0, 8)}`),
      };
    } else {
      const idEnvio = distributionId.replace(/-/g, "").slice(0, 32);
      const payerPixKey = (Deno.env.get(`${prefix}_PAYER_PIX_KEY`) ?? "").trim();
      const pixUrl = assertPinnedOriginUrl(pspCode, `/v2/gn/pix/${idEnvio}`);
      const payRes = await fetch(pixUrl, {
        method: "PUT",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          valor: valorStr,
          pagador: {
            chave: payerPixKey,
            infoPagador: `SLU ${distributionId.slice(0, 8)}`,
          },
          favorecido: {
            chave: solePartnerCpfDigits,
          },
        }),
        client: mtlsClient,
      });
      if (!payRes.ok) {
        return { succeeded: false, failureReason: `EFI_PIX_HTTP_${payRes.status}` };
      }
      const payJson = await payRes.json().catch(() => ({} as Record<string, unknown>));
      return {
        succeeded: true,
        transferId: String(payJson.e2eId ?? payJson.idEnvio ?? `EFI-${idEnvio.slice(0, 10)}`),
      };
    }
  } finally {
    mtlsClient.close();
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const startedAt = performance.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: JSON_SECURITY_HEADERS });
  }

  if (req.method !== "POST") {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  if (!supabaseAdmin) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_BOOT_CONFIG_MISSING" }, 503);
  }

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_MISSING_BEARER_JWT" }, 401);
  }
  const jwt = authHeader.slice(7).trim();

  const rawText = await req.text();
  if (rawText.length === 0 || rawText.length > MAX_PAYLOAD_BYTES) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_PAYLOAD_BOUNDS" }, 413);
  }

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawText);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("NOT_OBJECT");
    }
    body = parsed as Record<string, unknown>;
  } catch {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_INVALID_JSON" }, 400);
  }

  // Trava Zero-Digitação PIX: qualquer chave fora da allowlist (ex.: `pix_key`, `destination`) é bloqueada!
  for (const key of Object.keys(body)) {
    if (!ALLOWED_BODY_KEYS.has(key)) {
      await enforceLatencyFloor(startedAt);
      return jsonResponse({
        ok: false,
        error_code: "ERR_FORBIDDEN_DESTINATION_OVERRIDE",
      }, 400);
    }
  }

  const { data: authData, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  const callerEmail = (authData?.user?.email ?? "").trim().toLowerCase();
  const callerUid = authData?.user?.id ?? "";
  if (authErr || !callerUid || callerEmail !== MONOCRATIC_CEO_EMAIL) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501" }, 403);
  }

  const action = String(body.action ?? "").trim();
  const stepupToken = String(body.stepup_token ?? "").trim().toLowerCase();
  const deviceHash = String(body.device_hash ?? "").trim().toLowerCase();

  if (!/^[0-9a-f]{64}$/.test(stepupToken) || !/^[0-9a-f]{64}$/.test(deviceHash)) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_STEPUP_TOKEN_INVALID" }, 401);
  }

  if (action === "verify_mtls_readiness") {
    const asaasSandboxReady = ((Deno.env.get("ASAAS_SANDBOX_API_KEY") ?? "").trim().length > 10);
    const asaasProdReady = ((Deno.env.get("ASAAS_PRODUCTION_API_KEY") ?? "").trim().length > 10);
    const efiSandboxMtlsReady = decodePemSecret("EFI_SANDBOX_MTLS_CERT_PEM").includes("BEGIN CERTIFICATE") &&
      decodePemSecret("EFI_SANDBOX_MTLS_KEY_PEM").includes("PRIVATE KEY");
    const interSandboxMtlsReady = decodePemSecret("INTER_SANDBOX_MTLS_CERT_PEM").includes("BEGIN CERTIFICATE") &&
      decodePemSecret("INTER_SANDBOX_MTLS_KEY_PEM").includes("PRIVATE KEY");
    const prodMtlsReady = (
      decodePemSecret("INTER_PROD_MTLS_CERT_PEM").includes("BEGIN CERTIFICATE") &&
      decodePemSecret("INTER_PROD_MTLS_KEY_PEM").includes("PRIVATE KEY")
    ) || (
      decodePemSecret("EFI_PROD_MTLS_CERT_PEM").includes("BEGIN CERTIFICATE") &&
      decodePemSecret("EFI_PROD_MTLS_KEY_PEM").includes("PRIVATE KEY")
    );

    await enforceLatencyFloor(startedAt);
    return jsonResponse({
      ok: true,
      deno_mtls_engine_available: typeof Deno.createHttpClient === "function",
      asaas_sandbox_configured: asaasSandboxReady,
      asaas_production_configured: asaasProdReady,
      efi_sandbox_mtls_configured: efiSandboxMtlsReady,
      inter_sandbox_mtls_configured: interSandboxMtlsReady,
      production_mtls_ecnpj_configured: prodMtlsReady,
      pinned_origins: Object.values(PINNED_PSP_ORIGINS),
    });
  }

  if (action !== "request_profit_distribution") {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_UNKNOWN_TREASURY_ACTION" }, 400);
  }

  const rawCents = body.requested_cents;
  if (
    typeof rawCents !== "number" ||
    !Number.isSafeInteger(rawCents) ||
    rawCents <= 0 ||
    rawCents > 1_000_000_000
  ) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({ ok: false, error_code: "ERR_INVALID_REQUESTED_CENTS" }, 400);
  }

  const idempotencyKey = String(body.idempotency_key ?? "").trim();
  const distributionKind = String(body.distribution_kind ?? "PROFIT_DISTRIBUTION").trim().toUpperCase();

  const { data: prepData, error: prepErr } = await supabaseAdmin.rpc(
    "ceo_edge_prepare_profit_distribution",
    {
      p_actor_uid: callerUid,
      p_stepup_token: stepupToken,
      p_device_hash: deviceHash,
      p_idempotency_key: idempotencyKey,
      p_distribution_kind: distributionKind,
      p_requested_cents: rawCents,
    },
  );

  if (prepErr || !prepData) {
    await enforceLatencyFloor(startedAt);
    const errMsg = sanitizeErrorText(prepErr?.message ?? "ERR_PREPARE_FAILED");
    const status = errMsg.includes("42501") || errMsg.includes("STEPUP") ? 403 : 422;
    return jsonResponse({ ok: false, error_code: errMsg }, status);
  }

  const prep = prepData as Record<string, unknown>;
  const distributionId = String(prep.distribution_id ?? "");
  const operatingMode = String(prep.operating_mode ?? "SANDBOX_PRE_CNPJ");
  const isDuressDecoy = prep.is_duress_decoy === true;

  // Resposta unificada sem nenhum marcador textual de coação (protege a vida sob ameaça!)
  if (isDuressDecoy || operatingMode === "SANDBOX_PRE_CNPJ" || prep.idempotent_replay === true) {
    await enforceLatencyFloor(startedAt);
    return jsonResponse({
      ok: true,
      distribution_id: distributionId,
      operating_mode: operatingMode,
      settlement_status: "COMPLETED",
      beneficiary_name: String(prep.beneficiary_full_name ?? "Wagner Oliveira"),
      amount_cents: rawCents,
      transfer_reference: String(prep.psp_transfer_id ?? ""),
      receipt_sha256: String(prep.receipt_sha256 ?? ""),
      processed_at: String(prep.created_at ?? new Date().toISOString()),
    });
  }

  // Modo `PRODUCTION_SLU`: executa túnel bancário real (Asaas Prod ou mTLS 1.3 Inter/Efí)
  const pspProvider = String(prep.psp_provider ?? "ASAAS_PRODUCTION");
  const solePartnerCpf = String(prep.sole_partner_cpf_digits ?? "");
  let payoutResult: ExternalPayoutResult;

  try {
    if (pspProvider === "ASAAS_PRODUCTION" || pspProvider === "ASAAS_SANDBOX") {
      payoutResult = await executeAsaasTransfer(
        pspProvider,
        distributionId,
        rawCents,
        solePartnerCpf,
      );
    } else if (
      pspProvider === "INTER_MTLS_PRODUCTION" ||
      pspProvider === "INTER_MTLS_SANDBOX" ||
      pspProvider === "EFI_MTLS_PRODUCTION" ||
      pspProvider === "EFI_MTLS_SANDBOX"
    ) {
      payoutResult = await executeMtlsPixPayout(
        pspProvider,
        distributionId,
        rawCents,
        solePartnerCpf,
      );
    } else {
      payoutResult = { succeeded: false, failureReason: "UNSUPPORTED_PRODUCTION_PSP" };
    }
  } catch (err) {
    payoutResult = {
      succeeded: false,
      failureReason: sanitizeErrorText(err instanceof Error ? err.message : "MTLS_TRANSPORT_ERROR"),
    };
  }

  await supabaseAdmin.rpc("ceo_edge_finalize_profit_distribution", {
    p_distribution_id: distributionId,
    p_succeeded: payoutResult.succeeded,
    p_psp_transfer_id: payoutResult.transferId ?? null,
    p_failure_reason: payoutResult.failureReason ?? null,
  });

  await enforceLatencyFloor(startedAt);
  if (!payoutResult.succeeded) {
    return jsonResponse({
      ok: false,
      error_code: payoutResult.failureReason ?? "ERR_PSP_TRANSFER_REJECTED",
    }, 502);
  }

  return jsonResponse({
    ok: true,
    distribution_id: distributionId,
    operating_mode: operatingMode,
    settlement_status: "COMPLETED",
    beneficiary_name: String(prep.beneficiary_full_name ?? "Wagner Oliveira"),
    amount_cents: rawCents,
    transfer_reference: payoutResult.transferId ?? "",
    receipt_sha256: String(prep.receipt_sha256 ?? ""),
    processed_at: new Date().toISOString(),
  });
});

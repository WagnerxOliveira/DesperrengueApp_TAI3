// Edge Function: signup-eligibility-guard
//
// Escudo Zero-Trust de Elegibilidade de Cadastro (Anti-GoTrue Silent Obfuscation &
// Anti-Enumeration Side-Channel Guard):
//   1. Recebe `POST { email: string, client_nonce?: string }` com CORS restrito de API.
//   2. Extrai o primeiro IP real (`x-forwarded-for` -> `cf-connecting-ip` -> `'unknown'`)
//      combinado com `client_nonce` higienizado, derivando `rate_key` via `SHA-256` hex.
//   3. Invoca `public.service_evaluate_signup_email_guard` exclusivamente via `service_role`.
//   4. Impõe piso temporal constante mínimo de `180ms` (`Math.max(0, 180 - elapsed)`) em
//      todos os caminhos de saída para mitigar ataques de enumeração por canal lateral de tempo.
//   5. Retorna exclusivamente `{ status }` sem jamais vazar `id`, `nome`, `CPF`, `telefone` ou `role`.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();

const TIMING_FLOOR_MS = 180;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store, no-cache, must-revalidate, private, max-age=0",
  "X-Content-Type-Options": "nosniff",
  "Content-Type": "application/json; charset=utf-8",
};

type SignupEligibilityStatus =
  | "AVAILABLE"
  | "ALREADY_REGISTERED_CONFIRMED"
  | "PENDING_EMAIL_VERIFICATION"
  | "RATE_LIMITED";

const ALLOWED_STATUSES = new Set<SignupEligibilityStatus>([
  "AVAILABLE",
  "ALREADY_REGISTERED_CONFIRMED",
  "PENDING_EMAIL_VERIFICATION",
  "RATE_LIMITED",
]);

const supabaseAdmin =
  SUPABASE_URL.length > 0 && SUPABASE_SERVICE_ROLE_KEY.length > 0
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      })
    : null;

function jsonResponse(body: { status: SignupEligibilityStatus } | { error: string }, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: CORS_HEADERS,
  });
}

function bytesToHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i]!.toString(16).padStart(2, "0");
  }
  return out;
}

async function sha256HexUtf8(input: string): Promise<string> {
  const encoded = new TextEncoder().encode(input);
  try {
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", encoded));
    const hex = bytesToHex(digest);
    digest.fill(0);
    return hex;
  } finally {
    encoded.fill(0);
  }
}

function extractClientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff && xff.trim().length > 0) {
    const firstIp = xff.split(",")[0]?.trim();
    if (firstIp && firstIp.length <= 64) {
      return firstIp;
    }
  }
  const cfIp = req.headers.get("cf-connecting-ip")?.trim();
  if (cfIp && cfIp.length > 0 && cfIp.length <= 64) {
    return cfIp;
  }
  return "unknown";
}

function sanitizeClientNonce(rawNonce: unknown): string {
  if (typeof rawNonce !== "string") return "";
  return rawNonce.trim().replace(/[^A-Za-z0-9_\-:.]/g, "").slice(0, 64);
}

async function enforceConstantTimingFloor(startedAtMs: number): Promise<void> {
  const elapsed = Date.now() - startedAtMs;
  const waitMs = Math.max(0, TIMING_FLOOR_MS - elapsed);
  if (waitMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const startedAtMs = Date.now();

  try {
    if (!supabaseAdmin) {
      await enforceConstantTimingFloor(startedAtMs);
      return jsonResponse({ error: "Service unavailable" }, 503);
    }

    const rawText = await req.text();
    if (rawText.length > 4096) {
      await enforceConstantTimingFloor(startedAtMs);
      return jsonResponse({ status: "AVAILABLE" }, 200);
    }

    let payload: Record<string, unknown> = {};
    if (rawText.trim().length > 0) {
      try {
        const parsed = JSON.parse(rawText);
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
          payload = parsed as Record<string, unknown>;
        }
      } catch {
        await enforceConstantTimingFloor(startedAtMs);
        return jsonResponse({ status: "AVAILABLE" }, 200);
      }
    }

    const email = typeof payload.email === "string"
      ? payload.email.trim().toLowerCase().slice(0, 254)
      : "";
    const clientNonce = sanitizeClientNonce(payload.client_nonce);
    const clientIp = extractClientIp(req);
    const sessionKey = await sha256HexUtf8(`DSP_SIGNUP_GUARD_V1|${clientIp}|${clientNonce}`);
    const ipKey = await sha256HexUtf8(`DSP_SIGNUP_GUARD_IP_V1|${clientIp}`);
    const rateKey = `${sessionKey}.${ipKey}`;

    const { data, error } = await supabaseAdmin.rpc("service_evaluate_signup_email_guard", {
      p_email: email,
      p_rate_key: rateKey,
    });

    await enforceConstantTimingFloor(startedAtMs);

    if (error) {
      return jsonResponse({ error: "Guard evaluation unavailable" }, 503);
    }

    const rawStatus =
      data && typeof data === "object" && "status" in (data as Record<string, unknown>)
        ? String((data as Record<string, unknown>).status ?? "")
        : "";

    const safeStatus: SignupEligibilityStatus = ALLOWED_STATUSES.has(rawStatus as SignupEligibilityStatus)
      ? (rawStatus as SignupEligibilityStatus)
      : "AVAILABLE";

    if (safeStatus === "RATE_LIMITED") {
      return jsonResponse({ status: "RATE_LIMITED" }, 429);
    }

    return jsonResponse({ status: safeStatus }, 200);
  } catch {
    await enforceConstantTimingFloor(startedAtMs);
    return jsonResponse({ error: "Internal guard error" }, 503);
  }
});

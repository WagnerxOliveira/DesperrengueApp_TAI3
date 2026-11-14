// Edge Function: ceo-vault-authority (v2.14.0)
//
// Autoridade Soberana Exclusiva de Identidade Monocrática do `Desperrengue CEO`
// (`br.com.desperrengue.app.founder`) — 100% isolada do GoTrue/OAuth público do
// aplicativo `Desperrengue` (`br.com.desperrengue.app`).
//
// GARANTIAS DE CIBERDEFESA EXTREMA (NIST SP 800-63B AAL3 / OWASP ASVS L3):
//   1. Titular Único Inviolável: APENAS `wagneroliveira2395@gmail.com` é aceito.
//      Qualquer outro e-mail dispara `INTRUSION_CANARY` na cadeia WORM SHA-256 e
//      recebe `403 ERR_MONOCRATIC_OWNER_ONLY_42501` com piso temporal mascarado.
//   2. Zero Cross-App Redirect: nenhum fluxo abre navegador OAuth nem toca em
//      `auth.users.encrypted_password`. As sessões JWT são emitidas no servidor
//      (`generateLink('magiclink')` + `verifyOtp(token_hash)`) e hidratadas in-app.
//   3. Custódia Dividida (Split-Pepper) + Zeroização de Buffers RAM:
//      `CK = PBKDF2-HMAC-SHA256(P, domain_salt, 210000, 32)` ->
//      `EK = HMAC-SHA256(CEO_VAULT_EDGE_PEPPER, CK)` -> PostgreSQL `HMAC-SHA512 x 25.000`
//      + `pgp_sym_encrypt_bytea` (`AES-256`).
//   4. Cerimônia em 2 E-mails + Ponte HTTPS -> Intent Android Fixado ao Pacote:
//      E-mail #1 envia o código de 6 dígitos solicitado no Perfil CEO.
//      Após validar os 6 dígitos, E-mail #2 envia o botão clicável HTTPS com `Cache-Control:
//      no-store`, `Referrer-Policy: no-referrer`, inspeção `GET` idempotente (imune a
//      prefetchers Gmail/antivírus) e salto `intent://...package=br.com.desperrengue.app.founder`.

import { createClient } from "@supabase/supabase-js";

const MONOCRATIC_CEO_EMAIL = "wagneroliveira2395@gmail.com";
const CEO_EMAIL_RECIPIENTS: readonly string[] = Object.freeze([MONOCRATIC_CEO_EMAIL]);
const MASKED_CEO_EMAIL = "wagneroliveira2395@gmail.com";
const DOMAIN_KDF_SALT = "DESPERRENGUE_CEO_MASTER_PW_V2:wagneroliveira2395@gmail.com";
const PBKDF2_ITERATIONS = 210_000;

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SERVICE_ROLE_KEY = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
const ANON_KEY = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
const RESEND_API_KEY = (Deno.env.get("RESEND_API_KEY") ?? "").trim();
const EDGE_PEPPER_HEX = (Deno.env.get("CEO_VAULT_EDGE_PEPPER") ?? "").trim().toLowerCase();
const EMAIL_FROM = (
  Deno.env.get("CEO_SECURITY_EMAIL_FROM") ??
  Deno.env.get("EMAIL_FROM") ??
  "Desperrengue CEO Security <onboarding@desperrengue.tech>"
).trim();

const IS_BOOT_VALID =
  SUPABASE_URL.length > 0 &&
  SERVICE_ROLE_KEY.length > 0 &&
  ANON_KEY.length > 0 &&
  /^[0-9a-f]{64}$/.test(EDGE_PEPPER_HEX);

const supabaseAdmin = IS_BOOT_VALID
  ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  : null;

const JSON_SECURITY_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
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

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim().toLowerCase();
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i]!.toString(16).padStart(2, "0");
  }
  return out;
}

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

function generateCsprngHex(byteLength = 32): string {
  const buf = new Uint8Array(byteLength);
  crypto.getRandomValues(buf);
  const hex = bytesToHex(buf);
  buf.fill(0);
  return hex;
}

function generateCsprngBase64Nonce(byteLength = 18): string {
  const buf = new Uint8Array(byteLength);
  crypto.getRandomValues(buf);
  let bin = "";
  for (let i = 0; i < buf.length; i++) {
    bin += String.fromCharCode(buf[i]!);
  }
  buf.fill(0);
  return btoa(bin);
}

/** Gera código numérico de 6 dígitos via CSPRNG sem viés modular (rejection sampling). */
function generateCsprngSixDigitCode(): string {
  const buf = new Uint32Array(1);
  const limit = 4_294_000_000;
  while (true) {
    crypto.getRandomValues(buf);
    const val = buf[0]!;
    if (val < limit) {
      buf[0] = 0;
      return String(val % 1_000_000).padStart(6, "0");
    }
  }
}

function randomJitterMs(maxExclusive = 91): number {
  const buf = new Uint8Array(1);
  crypto.getRandomValues(buf);
  return buf[0]! % maxExclusive;
}

async function enforceTimingFloorWithJitter(startedAtMs: number, baseFloorMs = 400): Promise<void> {
  const target = baseFloorMs + randomJitterMs(91);
  const elapsed = Date.now() - startedAtMs;
  if (elapsed < target) {
    await new Promise((resolve) => setTimeout(resolve, target - elapsed));
  }
}

async function sha256HexUtf8(value: string): Promise<string> {
  const enc = new TextEncoder().encode(value);
  try {
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc));
    const hex = bytesToHex(digest);
    digest.fill(0);
    return hex;
  } finally {
    enc.fill(0);
  }
}

async function extractIpSha256(req: Request): Promise<string> {
  const xff = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "0.0.0.0";
  const firstIp = xff.split(",")[0]?.trim() || "0.0.0.0";
  return await sha256HexUtf8(`CEO_IP_V2:${EDGE_PEPPER_HEX.slice(0, 16)}:${firstIp}`);
}

function formatSaoPauloTimestamp(): string {
  try {
    return new Intl.DateTimeFormat("pt-BR", {
      timeZone: "America/Sao_Paulo",
      dateStyle: "short",
      timeStyle: "medium",
    }).format(new Date());
  } catch {
    return new Date().toISOString();
  }
}

// -----------------------------------------------------------------------------
// Política Matemática de Senha Forte Soberana (espelho exato de CeoStrongPasswordPolicy)
// -----------------------------------------------------------------------------
const FORBIDDEN_SUBSTRINGS: readonly string[] = [
  "wagner",
  "oliveira",
  "2395",
  "desperrengue",
  "founder",
  "cockpit",
  "warroom",
  "admin",
  "ceo",
  "root",
  "senha",
  "password",
  "supabase",
  "brasil",
];

const KEYBOARD_WALKS: readonly string[] = [
  "qwer",
  "wert",
  "erty",
  "rtyu",
  "tyui",
  "yuio",
  "uiop",
  "asdf",
  "sdfg",
  "dfgh",
  "fghj",
  "ghjk",
  "hjkl",
  "zxcv",
  "xcvb",
  "cvbn",
  "vbnm",
  "rewq",
  "fdsa",
  "vcxz",
  "1qaz",
  "2wsx",
  "3edc",
];

function normalizeLeetspeak(input: string): string {
  return input
    .toLowerCase()
    .replaceAll("0", "o")
    .replaceAll("1", "i")
    .replaceAll("!", "i")
    .replaceAll("3", "e")
    .replaceAll("4", "a")
    .replaceAll("@", "a")
    .replaceAll("5", "s")
    .replaceAll("$", "s")
    .replaceAll("7", "t");
}

function hasSequentialRunOfFour(input: string): boolean {
  const lower = input.toLowerCase();
  if (lower.length < 4) return false;
  for (let i = 0; i <= lower.length - 4; i++) {
    const c0 = lower.charCodeAt(i);
    const c1 = lower.charCodeAt(i + 1);
    const c2 = lower.charCodeAt(i + 2);
    const c3 = lower.charCodeAt(i + 3);
    const allAlpha =
      c0 >= 97 && c0 <= 122 &&
      c1 >= 97 && c1 <= 122 &&
      c2 >= 97 && c2 <= 122 &&
      c3 >= 97 && c3 <= 122;
    const allDigits =
      c0 >= 48 && c0 <= 57 &&
      c1 >= 48 && c1 <= 57 &&
      c2 >= 48 && c2 <= 57 &&
      c3 >= 48 && c3 <= 57;
    if (allAlpha || allDigits) {
      if (c1 === c0 + 1 && c2 === c1 + 1 && c3 === c2 + 1) return true;
      if (c1 === c0 - 1 && c2 === c1 - 1 && c3 === c2 - 1) return true;
    }
  }
  for (const walk of KEYBOARD_WALKS) {
    if (lower.includes(walk)) return true;
  }
  return false;
}

function computeShannonBitsPerChar(chars: string[]): number {
  if (chars.length === 0) return 0;
  const freq = new Map<string, number>();
  for (const ch of chars) {
    freq.set(ch, (freq.get(ch) ?? 0) + 1);
  }
  let h = 0;
  const n = chars.length;
  for (const count of freq.values()) {
    const p = count / n;
    h -= p * Math.log2(p);
  }
  return h;
}

interface PasswordPolicyCheck {
  valid: boolean;
  failedRules: string[];
  shannonBitsPerChar: number;
  totalEntropyBits: number;
}

function evaluateCeoStrongPassword(password: string): PasswordPolicyCheck {
  const chars = Array.from(password);
  const len = chars.length;
  const byteLen = new TextEncoder().encode(password).length;
  const failed: string[] = [];

  if (len < 12 || len > 64 || byteLen > 256) {
    failed.push("LENGTH_12_TO_64");
  }
  if (/[\s\x00-\x1F\x7F]/.test(password)) {
    failed.push("NO_WHITESPACE_OR_CONTROL");
  }
  if (!/[A-Z]/.test(password)) {
    failed.push("REQUIRE_UPPERCASE");
  }
  if (!/[a-z]/.test(password)) {
    failed.push("REQUIRE_LOWERCASE");
  }
  if (!/[0-9]/.test(password)) {
    failed.push("REQUIRE_DIGIT");
  }
  if (!/[^A-Za-z0-9\s]/.test(password)) {
    failed.push("REQUIRE_SPECIAL_SYMBOL");
  }

  const h = computeShannonBitsPerChar(chars);
  const totalBits = h * len;
  if (h < 3.5 || totalBits < 60.0) {
    failed.push("SHANNON_ENTROPY_MIN_60_BITS");
  }
  if (/(.)\1{3,}/u.test(password)) {
    failed.push("NO_REPEATED_QUAD");
  }
  if (hasSequentialRunOfFour(password)) {
    failed.push("NO_SEQUENTIAL_OR_KEYBOARD_WALK");
  }

  const lowerRaw = password.toLowerCase();
  const normalizedLeet = normalizeLeetspeak(password);
  for (const word of FORBIDDEN_SUBSTRINGS) {
    if (lowerRaw.includes(word) || normalizedLeet.includes(word)) {
      failed.push("NO_PERSONAL_OR_CONTEXT_TERMS");
      break;
    }
  }

  return {
    valid: failed.length === 0,
    failedRules: failed,
    shannonBitsPerChar: Number(h.toFixed(2)),
    totalEntropyBits: Number(totalBits.toFixed(1)),
  };
}

// -----------------------------------------------------------------------------
// Derivação Criptográfica Split-Custody + Zeroização Determinística de RAM
// -----------------------------------------------------------------------------
async function deriveClientKeyFromPassword(password: string): Promise<string> {
  const enc = new TextEncoder();
  const pwBytes = enc.encode(password);
  const saltBytes = enc.encode(DOMAIN_KDF_SALT);
  try {
    const baseKey = await crypto.subtle.importKey("raw", pwBytes, "PBKDF2", false, ["deriveBits"]);
    const bits = await crypto.subtle.deriveBits(
      {
        name: "PBKDF2",
        hash: "SHA-256",
        salt: saltBytes,
        iterations: PBKDF2_ITERATIONS,
      },
      baseKey,
      256,
    );
    const ckBytes = new Uint8Array(bits);
    try {
      return bytesToHex(ckBytes);
    } finally {
      ckBytes.fill(0);
    }
  } finally {
    pwBytes.fill(0);
    saltBytes.fill(0);
  }
}

async function blindClientKeyWithEdgePepper(clientKeyHex: string): Promise<string> {
  const pepperBytes = hexToBytes(EDGE_PEPPER_HEX);
  const ckBytes = hexToBytes(clientKeyHex);
  try {
    const hmacKey = await crypto.subtle.importKey(
      "raw",
      pepperBytes,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const sig = new Uint8Array(await crypto.subtle.sign("HMAC", hmacKey, ckBytes));
    try {
      return bytesToHex(sig);
    } finally {
      sig.fill(0);
    }
  } finally {
    pepperBytes.fill(0);
    ckBytes.fill(0);
  }
}

// -----------------------------------------------------------------------------
// Resolução O(log N) do Titular Único & Emissão In-App de Sessão JWT (Zero Browser)
// -----------------------------------------------------------------------------
async function ensureCanonicalCeoAuthUser(): Promise<string> {
  if (!supabaseAdmin) throw new Error("ERR_VAULT_MISCONFIGURED");

  const { data: resolved, error: resolveErr } = await supabaseAdmin.rpc("ceo_edge_resolve_owner_uid");
  if (!resolveErr && resolved && typeof (resolved as Record<string, unknown>).owner_user_id === "string") {
    const existingUid = String((resolved as Record<string, unknown>).owner_user_id);
    if (existingUid.length === 36) {
      return existingUid;
    }
  }

  const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
    email: MONOCRATIC_CEO_EMAIL,
    email_confirm: true,
    user_metadata: {
      sovereign_ceo_only: true,
      display_name: "Wagner Oliveira (CEO)",
    },
  });

  if (!createErr && created?.user?.id) {
    await supabaseAdmin.rpc("ceo_edge_bind_owner_uid", { p_user_id: created.user.id });
    return created.user.id;
  }

  const { data: retryResolved } = await supabaseAdmin.rpc("ceo_edge_resolve_owner_uid");
  const retryUid = retryResolved ? (retryResolved as Record<string, unknown>).owner_user_id : null;
  if (typeof retryUid === "string" && retryUid.length === 36) {
    return retryUid;
  }

  throw new Error("ERR_CEO_OWNER_PROVISION_FAILED");
}

async function mintInAppSovereignJwtSession(): Promise<{
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  userId: string;
}> {
  if (!supabaseAdmin) throw new Error("ERR_VAULT_MISCONFIGURED");

  const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
    type: "magiclink",
    email: MONOCRATIC_CEO_EMAIL,
  });

  const tokenHash = linkData?.properties?.hashed_token ?? "";
  if (linkErr || !tokenHash) {
    throw new Error("ERR_SOVEREIGN_SESSION_LINK_MINT_FAILED");
  }

  const ephemeralAnon = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  const { data: verified, error: verifyErr } = await ephemeralAnon.auth.verifyOtp({
    token_hash: tokenHash,
    type: "magiclink",
  });

  const session = verified?.session;
  const user = verified?.user;
  const verifiedEmail = (user?.email ?? "").trim().toLowerCase();

  if (
    verifyErr ||
    !session?.access_token ||
    !session?.refresh_token ||
    !user?.id ||
    !constantTimeEqualsAscii(verifiedEmail, MONOCRATIC_CEO_EMAIL)
  ) {
    throw new Error("ERR_SOVEREIGN_SESSION_EXCHANGE_FAILED");
  }

  await supabaseAdmin.rpc("ceo_edge_bind_owner_uid", { p_user_id: user.id });

  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresIn: session.expires_in ?? 3600,
    userId: user.id,
  };
}

async function authenticateBearerCeoOwner(req: Request): Promise<
  | { ok: true; userId: string }
  | { ok: false; status: number; errorCode: string }
> {
  if (!supabaseAdmin) {
    return { ok: false, status: 503, errorCode: "ERR_VAULT_MISCONFIGURED" };
  }
  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const jwt = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (!jwt) {
    return { ok: false, status: 401, errorCode: "ERR_MISSING_BEARER_TOKEN" };
  }

  const { data: authData, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  const user = authData?.user;
  if (authErr || !user) {
    return { ok: false, status: 401, errorCode: "ERR_INVALID_OR_EXPIRED_JWT" };
  }

  const email = (user.email ?? "").trim().toLowerCase();
  if (!constantTimeEqualsAscii(email, MONOCRATIC_CEO_EMAIL)) {
    try {
      await supabaseAdmin.rpc("ceo_edge_log_intrusion_canary", {
        p_actor_uid: user.id,
        p_attempted_email: email,
        p_reason: "CEO_VAULT_AUTHORITY_NON_OWNER_JWT",
        p_meta: {},
      });
    } catch {
      // Preserva bloqueio 403
    }
    return { ok: false, status: 403, errorCode: "ERR_MONOCRATIC_OWNER_ONLY_42501" };
  }

  return { ok: true, userId: user.id };
}

// -----------------------------------------------------------------------------
// Templates Exclusivos de E-mail (Obsidian & Ouro 24k — 100% Isolados do Marketplace)
// -----------------------------------------------------------------------------
async function sendStrictCeoEmail(subject: string, html: string): Promise<boolean> {
  if (!RESEND_API_KEY) return false;
  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: EMAIL_FROM,
      to: CEO_EMAIL_RECIPIENTS,
      subject,
      html,
    }),
  });
  return resp.ok;
}

function buildSixDigitOtpEmailHtml(params: {
  otpCode: string;
  badgeText: string;
  headline: string;
  subtitle: string;
  instruction: string;
  deviceLabel: string;
  deviceHashPrefix: string;
  timestampSp: string;
}): string {
  const codeLeft = escapeHtml(params.otpCode.slice(0, 3));
  const codeRight = escapeHtml(params.otpCode.slice(3, 6));
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(params.headline)}</title>
</head>
<body style="margin:0;padding:24px 12px;background:#05070B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#F8FAFC;">
  <div style="max-width:540px;margin:0 auto;background:#0C111B;border:1px solid #2A3446;border-radius:20px;overflow:hidden;">
    <div style="padding:28px 24px 20px;background:linear-gradient(135deg,#090D16 0%,#161F30 100%);border-bottom:1px solid rgba(245,158,11,0.34);text-align:center;">
      <div style="display:inline-block;padding:5px 14px;border-radius:999px;background:rgba(245,158,11,0.15);border:1px solid rgba(253,224,71,0.48);color:#FDE047;font-size:11px;font-weight:800;letter-spacing:1.7px;text-transform:uppercase;">
        ${escapeHtml(params.badgeText)}
      </div>
      <h1 style="margin:14px 0 4px;font-size:22px;font-weight:800;color:#FFFFFF;letter-spacing:-0.3px;">
        ${escapeHtml(params.headline)}
      </h1>
      <p style="margin:0;font-size:13px;color:#94A3B8;">
        ${escapeHtml(params.subtitle)}
      </p>
    </div>
    <div style="padding:28px 24px;">
      <p style="margin:0 0 18px;font-size:14px;line-height:1.6;color:#CBD5E1;">
        Olá, <strong style="color:#FFFFFF;">Wagner</strong>. ${escapeHtml(params.instruction)}
      </p>
      <div style="margin:22px 0;padding:22px 16px;background:#06090F;border:1px solid rgba(253,224,71,0.45);border-radius:16px;text-align:center;">
        <div style="font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace;font-size:38px;font-weight:800;letter-spacing:8px;color:#FDE047;">
          ${codeLeft}&nbsp;${codeRight}
        </div>
        <div style="margin-top:10px;font-size:12px;color:#94A3B8;">
          Validade estrita de <strong style="color:#E2E8F0;">5 minutos</strong> · Uso único · Canal exclusivo Desperrengue CEO
        </div>
      </div>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:18px 0;background:#101725;border-radius:12px;border:1px solid #1E293B;">
        <tr>
          <td style="padding:11px 16px;font-size:12px;color:#94A3B8;border-bottom:1px solid #1E293B;">Aparelho autorizado</td>
          <td style="padding:11px 16px;font-size:12px;color:#F1F5F9;font-weight:600;text-align:right;border-bottom:1px solid #1E293B;">${escapeHtml(params.deviceLabel)}</td>
        </tr>
        <tr>
          <td style="padding:11px 16px;font-size:12px;color:#94A3B8;border-bottom:1px solid #1E293B;">Assinatura Hardware SHA-256</td>
          <td style="padding:11px 16px;font-family:monospace;font-size:12px;color:#67E8F9;text-align:right;border-bottom:1px solid #1E293B;">${escapeHtml(params.deviceHashPrefix.toUpperCase())}…</td>
        </tr>
        <tr>
          <td style="padding:11px 16px;font-size:12px;color:#94A3B8;">Horário (Brasília)</td>
          <td style="padding:11px 16px;font-size:12px;color:#E2E8F0;text-align:right;">${escapeHtml(params.timestampSp)}</td>
        </tr>
      </table>
      <p style="margin:16px 0 0;font-size:12px;line-height:1.55;color:#94A3B8;">
        <strong style="color:#F87171;">Blindagem Monocrática:</strong> Este canal é 100% isolado do aplicativo público do Marketplace e pertence exclusivamente a <strong style="color:#E2E8F0;">wagneroliveira2395@gmail.com</strong>.
      </p>
    </div>
    <div style="padding:14px 24px;background:#070A10;border-top:1px solid #1E293B;text-align:center;font-size:11px;color:#64748B;">
      Autoridade Soberana Criptográfica · Desperrengue CEO (AES-256 + Split-Pepper)
    </div>
  </div>
</body>
</html>`;
}

function buildPasswordResetLinkUnlockedEmailHtml(params: {
  bridgeUrl: string;
  deviceLabel: string;
  deviceHashPrefix: string;
  timestampSp: string;
}): string {
  const safeUrl = escapeHtml(params.bridgeUrl);
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Troca de Senha Liberada — Desperrengue CEO</title>
</head>
<body style="margin:0;padding:24px 12px;background:#05070B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#F8FAFC;">
  <div style="max-width:540px;margin:0 auto;background:#0C111B;border:1px solid #2A3446;border-radius:20px;overflow:hidden;">
    <div style="padding:28px 24px 20px;background:linear-gradient(135deg,#090D16 0%,#1A2336 100%);border-bottom:1px solid rgba(245,158,11,0.38);text-align:center;">
      <div style="display:inline-block;padding:5px 14px;border-radius:999px;background:rgba(16,185,129,0.16);border:1px solid rgba(52,211,153,0.48);color:#6EE7B7;font-size:11px;font-weight:800;letter-spacing:1.6px;text-transform:uppercase;">
        CÓDIGO DE 6 DÍGITOS CONFIRMADO · TROCA LIBERADA
      </div>
      <h1 style="margin:14px 0 4px;font-size:22px;font-weight:800;color:#FFFFFF;letter-spacing:-0.3px;">
        Redefinição de Senha Mestra Liberada
      </h1>
      <p style="margin:0;font-size:13px;color:#94A3B8;">
        Toque no botão abaixo no seu celular para abrir diretamente a tela segura no Desperrengue CEO
      </p>
    </div>
    <div style="padding:28px 24px;">
      <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#CBD5E1;">
        Olá, <strong style="color:#FFFFFF;">Wagner</strong>. Sua validação de 6 dígitos no <strong style="color:#FDE047;">Perfil CEO</strong> foi aprovada com sucesso. A criação da sua nova Senha Mestra de Administrador CEO está liberada pelos próximos <strong style="color:#FFFFFF;">10 minutos</strong>:
      </p>
      <div style="margin:26px 0;text-align:center;">
        <a href="${safeUrl}" style="display:inline-block;padding:16px 28px;border-radius:14px;background:linear-gradient(135deg,#F59E0B 0%,#FDE047 100%);color:#07090E;font-size:14px;font-weight:900;letter-spacing:0.6px;text-decoration:none;text-transform:uppercase;">
          Definir Nova Senha no Desperrengue CEO
        </a>
      </div>
      <p style="margin:0 0 18px;font-size:12px;line-height:1.55;color:#94A3B8;text-align:center;">
        Link criptográfico de <strong>uso único</strong>, vinculado exclusivamente ao aparelho onde você iniciou a solicitação (${escapeHtml(params.deviceLabel)} · <span style="font-family:monospace;color:#67E8F9;">${escapeHtml(params.deviceHashPrefix.toUpperCase())}…</span> em ${escapeHtml(params.timestampSp)}).
      </p>
      <div style="padding:14px 16px;background:#101725;border:1px solid #1E293B;border-radius:12px;font-size:12px;line-height:1.55;color:#CBD5E1;">
        Assim que você confirmar a nova Senha Mestra Forte dentro do aplicativo <strong style="color:#FDE047;">Desperrengue CEO</strong>, todas as sessões anteriores serão encerradas e você fará login com sua <strong>nova senha + código de 6 dígitos</strong>.
      </div>
    </div>
    <div style="padding:14px 24px;background:#070A10;border-top:1px solid #1E293B;text-align:center;font-size:11px;color:#64748B;">
      Pacote Exclusivo Fixado: br.com.desperrengue.app.founder · Zero Redirecionamento ao Marketplace
    </div>
  </div>
</body>
</html>`;
}

function buildSecurityNoticeEmailHtml(params: {
  badgeText: string;
  headline: string;
  bodyHtml: string;
  timestampSp: string;
  deviceLabel: string;
}): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(params.headline)}</title>
</head>
<body style="margin:0;padding:24px 12px;background:#05070B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#F8FAFC;">
  <div style="max-width:540px;margin:0 auto;background:#0C111B;border:1px solid #2A3446;border-radius:20px;overflow:hidden;">
    <div style="padding:26px 24px 18px;background:#0B101B;border-bottom:1px solid rgba(245,158,11,0.30);text-align:center;">
      <div style="display:inline-block;padding:5px 14px;border-radius:999px;background:rgba(245,158,11,0.15);border:1px solid rgba(253,224,71,0.45);color:#FDE047;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;">
        ${escapeHtml(params.badgeText)}
      </div>
      <h1 style="margin:12px 0 0;font-size:20px;font-weight:800;color:#FFFFFF;">
        ${escapeHtml(params.headline)}
      </h1>
    </div>
    <div style="padding:24px;font-size:14px;line-height:1.6;color:#CBD5E1;">
      ${params.bodyHtml}
      <p style="margin:18px 0 0;font-size:12px;color:#94A3B8;">
        Aparelho registrado: <strong style="color:#E2E8F0;">${escapeHtml(params.deviceLabel)}</strong> · Horário (Brasília): <strong style="color:#E2E8F0;">${escapeHtml(params.timestampSp)}</strong>
      </p>
    </div>
  </div>
</body>
</html>`;
}

// -----------------------------------------------------------------------------
// Ponte HTTPS Blindada (`GET ?bridge=reset-password&lid=<uuid>&gt=<64-hex>`)
// -----------------------------------------------------------------------------
function buildBridgeHtmlResponse(params: {
  valid: boolean;
  lid: string;
  gt: string;
}): Response {
  const nonce = generateCsprngBase64Nonce(18);
  const headers: Record<string, string> = {
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store, no-cache, must-revalidate, private, max-age=0",
    "Pragma": "no-cache",
    "Referrer-Policy": "no-referrer",
    "X-Robots-Tag": "noindex, nofollow, noarchive, nosnippet",
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy":
      `default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
  };

  if (!params.valid) {
    const expiredHtml = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Link Expirado ou Já Utilizado — Desperrengue CEO</title>
</head>
<body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;background:#05070B;color:#F8FAFC;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:440px;width:100%;padding:28px 24px;background:#0D131F;border:1px solid rgba(248,113,113,0.42);border-radius:20px;text-align:center;">
    <div style="display:inline-block;padding:5px 12px;border-radius:999px;background:rgba(239,68,68,0.16);color:#FCA5A5;font-size:11px;font-weight:800;letter-spacing:1.4px;text-transform:uppercase;">
      DESPERRENGUE CEO · LINK ENCERRADO
    </div>
    <h1 style="margin:16px 0 8px;font-size:20px;font-weight:800;color:#FFFFFF;">
      Este link único expirou ou já foi utilizado
    </h1>
    <p style="margin:0;font-size:14px;line-height:1.6;color:#94A3B8;">
      Por segurança extrema, cada autorização de troca de Senha Mestra expira em 10 minutos e vale apenas uma única vez. Abra o aplicativo <strong style="color:#FDE047;">Desperrengue CEO</strong> e solicite um novo código em <strong>Perfil CEO</strong>.
    </p>
  </div>
  <script nonce="${nonce}">
    try { history.replaceState(null, "", "/functions/v1/ceo-vault-authority?bridge=expired"); } catch (_) {}
  </script>
</body>
</html>`;
    return new Response(expiredHtml, { status: 410, headers });
  }

  const fallbackSelf = `${SUPABASE_URL}/functions/v1/ceo-vault-authority?bridge=expired`;
  const deepLinkScheme = `desperrengue-founder://vault/reset-password?lid=${encodeURIComponent(params.lid)}&gt=${encodeURIComponent(params.gt)}`;
  const androidPinnedIntent =
    `intent://vault/reset-password?lid=${encodeURIComponent(params.lid)}&gt=${encodeURIComponent(params.gt)}` +
    `#Intent;scheme=desperrengue-founder;package=br.com.desperrengue.app.founder;S.browser_fallback_url=${encodeURIComponent(fallbackSelf)};end`;

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Abrindo Desperrengue CEO…</title>
</head>
<body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;background:#05070B;color:#F8FAFC;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:460px;width:100%;padding:30px 24px;background:#0D131F;border:1px solid rgba(253,224,71,0.38);border-radius:22px;text-align:center;box-shadow:0 24px 60px rgba(0,0,0,0.65);">
    <div style="display:inline-block;padding:5px 14px;border-radius:999px;background:rgba(245,158,11,0.16);border:1px solid rgba(253,224,71,0.45);color:#FDE047;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;">
      DESPERRENGUE CEO · COFRE SOBERANO
    </div>
    <h1 style="margin:16px 0 8px;font-size:21px;font-weight:800;color:#FFFFFF;">
      Redirecionando para o Aplicativo Desperrengue CEO
    </h1>
    <p style="margin:0 0 22px;font-size:14px;line-height:1.55;color:#94A3B8;">
      Toque no botão dourado abaixo caso a tela de criação da nova Senha Mestra Forte não abra automaticamente em 1 segundo:
    </p>
    <a id="ceo-open-intent" href="${escapeHtml(androidPinnedIntent)}" style="display:block;padding:16px 20px;border-radius:14px;background:linear-gradient(135deg,#F59E0B 0%,#FDE047 100%);color:#07090E;font-size:14px;font-weight:900;letter-spacing:0.5px;text-decoration:none;text-transform:uppercase;">
      Abrir no Desperrengue CEO
    </a>
    <a href="${escapeHtml(deepLinkScheme)}" style="display:inline-block;margin-top:14px;font-size:12px;color:#67E8F9;text-decoration:underline;">
      Acionar protocolo direto desperrengue-founder://
    </a>
  </div>
  <script nonce="${nonce}">
    (function () {
      var intentUrl = ${JSON.stringify(androidPinnedIntent)};
      var schemeUrl = ${JSON.stringify(deepLinkScheme)};
      try {
        history.replaceState(null, "", "/functions/v1/ceo-vault-authority?bridge=ready");
      } catch (_) {}
      var ua = navigator.userAgent || "";
      setTimeout(function () {
        if (/Android/i.test(ua)) {
          window.location.replace(intentUrl);
        } else {
          window.location.replace(schemeUrl);
        }
      }, 120);
    })();
  </script>
</body>
</html>`;

  return new Response(html, { status: 200, headers });
}

// -----------------------------------------------------------------------------
// Servidor Principal `Deno.serve`
// -----------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  const startedAt = Date.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: JSON_SECURITY_HEADERS });
  }

  if (req.method === "HEAD") {
    return new Response(null, { status: 200, headers: JSON_SECURITY_HEADERS });
  }

  if (!IS_BOOT_VALID || !supabaseAdmin) {
    return jsonResponse(
      {
        ok: false,
        error_code: "ERR_VAULT_MISCONFIGURED",
        message: "Cofre Soberano indisponível: segredos criptográficos obrigatórios ausentes.",
      },
      503,
    );
  }

  const url = new URL(req.url);

  // ---------------------------------------------------------------------------
  // Rota GET: Ponte HTTPS -> Intent Fixado `br.com.desperrengue.app.founder`
  // ---------------------------------------------------------------------------
  if (req.method === "GET") {
    const bridgeMode = (url.searchParams.get("bridge") ?? "").trim().toLowerCase();
    if (bridgeMode === "expired") {
      return buildBridgeHtmlResponse({ valid: false, lid: "", gt: "" });
    }
    if (bridgeMode === "reset-password") {
      const lid = (url.searchParams.get("lid") ?? "").trim();
      const gt = (url.searchParams.get("gt") ?? "").trim().toLowerCase();

      if (!/^[0-9a-fA-F-]{36}$/.test(lid) || !/^[0-9a-f]{64}$/.test(gt)) {
        await enforceTimingFloorWithJitter(startedAt, 220);
        return buildBridgeHtmlResponse({ valid: false, lid: "", gt: "" });
      }

      const { data: inspectRes, error: inspectErr } = await supabaseAdmin.rpc(
        "ceo_edge_inspect_reset_link_bridge",
        {
          p_link_id: lid,
          p_raw_grant_hex: gt,
        },
      );

      const isValid = !inspectErr && (inspectRes as Record<string, unknown> | null)?.ok === true;
      return buildBridgeHtmlResponse({ valid: isValid, lid, gt });
    }

    return jsonResponse({ ok: false, error_code: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  if (req.method !== "POST") {
    return jsonResponse({ ok: false, error_code: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const action = typeof body.action === "string" ? body.action.trim().toLowerCase() : "";
  const deviceHash = typeof body.device_hash === "string" ? body.device_hash.trim().toLowerCase() : "";
  const deviceLabel = typeof body.device_label === "string" && body.device_label.trim().length > 0
    ? body.device_label.trim().slice(0, 80)
    : "Desperrengue CEO · Android Blindado";

  if (!/^[0-9a-f]{64}$/.test(deviceHash)) {
    await enforceTimingFloorWithJitter(startedAt, 280);
    return jsonResponse({ ok: false, error_code: "ERR_INVALID_DEVICE_HASH" }, 400);
  }

  const ipHash = await extractIpSha256(req);

  // ---------------------------------------------------------------------------
  // 1. `inspect_gate` — Consulta soberana do estado inicial (Zero envio de e-mail)
  // ---------------------------------------------------------------------------
  if (action === "inspect_gate") {
    const rawEmail = typeof body.email === "string" && body.email.trim().length > 0
      ? body.email.trim().toLowerCase()
      : MONOCRATIC_CEO_EMAIL;

    const { data, error } = await supabaseAdmin.rpc("ceo_edge_inspect_vault_gate", {
      p_attempted_email: rawEmail,
      p_device_hash: deviceHash,
      p_ip_hash: ipHash,
    });

    await enforceTimingFloorWithJitter(startedAt, 380);

    if (error || !data) {
      return jsonResponse({ ok: false, error_code: "ERR_GATE_INSPECT_FAILED" }, 500);
    }

    const resJson = data as Record<string, unknown>;
    if (resJson.ok !== true) {
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501",
          message: "Acesso exclusivo ao titular monocrático wagneroliveira2395@gmail.com.",
        },
        403,
      );
    }

    return jsonResponse({
      ok: true,
      owner_email: MONOCRATIC_CEO_EMAIL,
      password_configured: Boolean(resJson.password_configured),
      password_version: Number(resJson.password_version ?? 0),
      password_updated_at: resJson.password_updated_at ?? null,
      locked_until: resJson.locked_until ?? null,
    });
  }

  // ---------------------------------------------------------------------------
  // 2. `request_initial_bootstrap_otp` — E-mail 6 dígitos para 1º Acesso absoluto
  // ---------------------------------------------------------------------------
  if (action === "request_initial_bootstrap_otp") {
    const attemptedEmail = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    if (!constantTimeEqualsAscii(attemptedEmail, MONOCRATIC_CEO_EMAIL)) {
      await supabaseAdmin.rpc("ceo_edge_inspect_vault_gate", {
        p_attempted_email: attemptedEmail,
        p_device_hash: deviceHash,
        p_ip_hash: ipHash,
      });
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501",
          message: "Acesso restrito exclusivamente a wagneroliveira2395@gmail.com.",
        },
        403,
      );
    }

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const ownerUid = await ensureCanonicalCeoAuthUser();
    const otpCode = generateCsprngSixDigitCode();

    const { data: issueData, error: issueErr } = await supabaseAdmin.rpc("ceo_edge_issue_bootstrap_otp", {
      p_user_id: ownerUid,
      p_device_hash: deviceHash,
      p_ip_hash: ipHash,
      p_otp_code: otpCode,
    });

    if (issueErr || !issueData) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_OTP_CHALLENGE_PERSIST_FAILED" }, 500);
    }

    const issueJson = issueData as Record<string, unknown>;
    if (issueJson.ok !== true) {
      const code = String(issueJson.error_code ?? "ERR_OTP_REQUEST_DENIED");
      const status = code === "ERR_OTP_COOLDOWN_ACTIVE" ? 429 : 409;
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse(issueJson, status);
    }

    const html = buildSixDigitOtpEmailHtml({
      otpCode,
      badgeText: "DESPERRENGUE CEO · PRIMEIRO ACESSO SOBERANO",
      headline: "Código para Criar Sua Senha Mestra CEO",
      subtitle: "Autorização exclusiva de inicialização do Cofre Soberano",
      instruction:
        "Digite os 6 dígitos abaixo no aplicativo Desperrengue CEO para habilitar a criação da sua Senha Mestra Forte de Administrador:",
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    const delivered = await sendStrictCeoEmail(
      `[Desperrengue CEO] Código de Primeiro Acesso: ${otpCode.slice(0, 3)} ${otpCode.slice(3, 6)}`,
      html,
    );

    await enforceTimingFloorWithJitter(startedAt, 420);

    if (!delivered) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_DELIVERY_FAILED" }, 502);
    }

    return jsonResponse({
      ok: true,
      challenge_id: issueJson.challenge_id,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: issueJson.expires_at,
      next_cooldown_seconds: issueJson.next_cooldown_seconds ?? 30,
    });
  }

  // ---------------------------------------------------------------------------
  // 3. `verify_initial_bootstrap_otp` — Valida 6 dígitos e emite `enrollment_ticket`
  // ---------------------------------------------------------------------------
  if (action === "verify_initial_bootstrap_otp") {
    const challengeId = typeof body.challenge_id === "string" ? body.challenge_id.trim() : "";
    const otpCode = typeof body.otp_code === "string" ? body.otp_code.replace(/\D/g, "") : "";

    if (!/^[0-9a-fA-F-]{36}$/.test(challengeId) || !/^[0-9]{6}$/.test(otpCode)) {
      await enforceTimingFloorWithJitter(startedAt, 380);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_OTP_INPUT" }, 400);
    }

    const ownerUid = await ensureCanonicalCeoAuthUser();
    const { data: verifyData, error: verifyErr } = await supabaseAdmin.rpc("ceo_edge_verify_bootstrap_otp", {
      p_user_id: ownerUid,
      p_challenge_id: challengeId,
      p_otp_code: otpCode,
      p_device_hash: deviceHash,
    });

    await enforceTimingFloorWithJitter(startedAt, 400);

    if (verifyErr || !verifyData) {
      return jsonResponse({ ok: false, error_code: "ERR_OTP_VERIFICATION_FAILED" }, 500);
    }

    const verifyJson = verifyData as Record<string, unknown>;
    return jsonResponse(verifyJson, verifyJson.ok === true ? 200 : 400);
  }

  // ---------------------------------------------------------------------------
  // 4. `set_initial_password` — Política Forte (HTTP 422) + AES-256 + Sessão In-App
  // ---------------------------------------------------------------------------
  if (action === "set_initial_password") {
    const enrollmentTicket = typeof body.enrollment_ticket === "string"
      ? body.enrollment_ticket.trim().toLowerCase()
      : "";
    const rawPassword = typeof body.password === "string" ? body.password : "";
    const providedCk = typeof body.client_key_hex === "string"
      ? body.client_key_hex.trim().toLowerCase()
      : "";

    const policy = evaluateCeoStrongPassword(rawPassword);
    if (!policy.valid) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_WEAK_PASSWORD_POLICY",
          failed_rules: policy.failedRules,
          shannon_bits_per_char: policy.shannonBitsPerChar,
          total_entropy_bits: policy.totalEntropyBits,
          message:
            "A Senha Mestra deve conter entre 12 e 64 caracteres, letras maiúsculas, minúsculas, números, símbolos especiais, alta entropia e nenhum nome ou sequência previsível.",
        },
        422,
      );
    }

    if (!/^[0-9a-f]{64}$/.test(enrollmentTicket)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED" }, 400);
    }

    const derivedCk = await deriveClientKeyFromPassword(rawPassword);
    if (providedCk.length > 0 && !constantTimeEqualsAscii(derivedCk, providedCk)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_KDF_INTEGRITY_MISMATCH" }, 400);
    }

    const edgeKeyHex = await blindClientKeyWithEdgePepper(derivedCk);
    const ownerUid = await ensureCanonicalCeoAuthUser();

    const { data: saveData, error: saveErr } = await supabaseAdmin.rpc("ceo_edge_set_initial_master_password", {
      p_user_id: ownerUid,
      p_enrollment_ticket: enrollmentTicket,
      p_edge_key_hex: edgeKeyHex,
      p_device_hash: deviceHash,
      p_device_label: deviceLabel,
    });

    if (saveErr || !saveData) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_VAULT_SEAL_FAILED" }, 500);
    }

    const saveJson = saveData as Record<string, unknown>;
    if (saveJson.ok !== true) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse(saveJson, 400);
    }

    let jwtSession;
    try {
      jwtSession = await mintInAppSovereignJwtSession();
    } catch {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_SOVEREIGN_SESSION_MINT_FAILED" }, 500);
    }

    await enforceTimingFloorWithJitter(startedAt, 420);
    return jsonResponse({
      ok: true,
      owner_email: MONOCRATIC_CEO_EMAIL,
      access_token: jwtSession.accessToken,
      refresh_token: jwtSession.refreshToken,
      expires_in: jwtSession.expiresIn,
      stepup_token: saveJson.stepup_token,
      stepup_expires_at: saveJson.stepup_expires_at,
      password_version: saveJson.password_version,
      password_updated_at: saveJson.password_updated_at,
    });
  }

  // ---------------------------------------------------------------------------
  // 5. `verify_password_and_send_login_otp` — Valida Senha AES-256 ANTES do E-mail 6d
  // ---------------------------------------------------------------------------
  if (action === "verify_password_and_send_login_otp") {
    const attemptedEmail = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    if (!constantTimeEqualsAscii(attemptedEmail, MONOCRATIC_CEO_EMAIL)) {
      await supabaseAdmin.rpc("ceo_edge_inspect_vault_gate", {
        p_attempted_email: attemptedEmail,
        p_device_hash: deviceHash,
        p_ip_hash: ipHash,
      });
      await enforceTimingFloorWithJitter(startedAt, 440);
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501",
          message: "Acesso restrito exclusivamente a wagneroliveira2395@gmail.com.",
        },
        403,
      );
    }

    let clientKeyHex = typeof body.client_key_hex === "string"
      ? body.client_key_hex.trim().toLowerCase()
      : "";
    if (!/^[0-9a-f]{64}$/.test(clientKeyHex) && typeof body.password === "string" && body.password.length > 0) {
      clientKeyHex = await deriveClientKeyFromPassword(body.password);
    }
    if (!/^[0-9a-f]{64}$/.test(clientKeyHex)) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_MASTER_PASSWORD" }, 401);
    }

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const edgeKeyHex = await blindClientKeyWithEdgePepper(clientKeyHex);
    const ownerUid = await ensureCanonicalCeoAuthUser();
    const otpCode = generateCsprngSixDigitCode();

    const { data: loginStep1, error: loginErr } = await supabaseAdmin.rpc(
      "ceo_edge_verify_password_and_issue_login_otp",
      {
        p_user_id: ownerUid,
        p_edge_key_hex: edgeKeyHex,
        p_device_hash: deviceHash,
        p_ip_hash: ipHash,
        p_otp_code: otpCode,
        p_is_resend: false,
      },
    );

    if (loginErr || !loginStep1) {
      await enforceTimingFloorWithJitter(startedAt, 440);
      return jsonResponse({ ok: false, error_code: "ERR_LOGIN_VERIFICATION_FAILED" }, 500);
    }

    const step1Json = loginStep1 as Record<string, unknown>;
    if (step1Json.ok !== true) {
      if (step1Json.send_lockout_security_alert === true) {
        const alertHtml = buildSecurityNoticeEmailHtml({
          badgeText: "ALERTA DE DEFESA ATIVA · COFRE BLOQUEADO TEMPORARIAMENTE",
          headline: "5 Tentativas Incorretas de Senha Detectadas",
          bodyHtml:
            "<p style=\"margin:0;\">O Cofre Soberano do <strong style=\"color:#FDE047;\">Desperrengue CEO</strong> ativou bloqueio temporário automático após 5 tentativas consecutivas de Senha Mestra incorreta. Se não foi você, nenhuma ação adicional é necessária — seu cofre permanece criptograficamente selado.</p>",
          timestampSp: formatSaoPauloTimestamp(),
          deviceLabel,
        });
        await sendStrictCeoEmail("[Desperrengue CEO] Alerta de Bloqueio Automático do Cofre", alertHtml);
      }

      const code = String(step1Json.error_code ?? "ERR_INVALID_MASTER_PASSWORD");
      const status = code === "ERR_VAULT_LOCKED_BACKOFF" || code === "ERR_OTP_COOLDOWN_ACTIVE" ? 429 : 401;
      await enforceTimingFloorWithJitter(startedAt, 440);
      return jsonResponse(step1Json, status);
    }

    const html = buildSixDigitOtpEmailHtml({
      otpCode,
      badgeText: "DESPERRENGUE CEO · VALIDAÇÃO DE ENTRADA 2FA",
      headline: "Código de 6 Dígitos para Abrir o Cofre CEO",
      subtitle: "2º Fator Criptográfico Obrigatório (Senha Mestra já validada)",
      instruction:
        "Sua Senha Mestra foi verificada com sucesso. Digite agora os 6 dígitos abaixo no Desperrengue CEO para concluir sua entrada:",
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    const delivered = await sendStrictCeoEmail(
      `[Desperrengue CEO] Código de Acesso: ${otpCode.slice(0, 3)} ${otpCode.slice(3, 6)}`,
      html,
    );

    await enforceTimingFloorWithJitter(startedAt, 440);

    if (!delivered) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_DELIVERY_FAILED" }, 502);
    }

    return jsonResponse({
      ok: true,
      challenge_id: step1Json.challenge_id,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: step1Json.expires_at,
      next_cooldown_seconds: step1Json.next_cooldown_seconds ?? 30,
    });
  }

  // ---------------------------------------------------------------------------
  // 6. `resend_login_otp` — Reenvia 6 dígitos sem reter senha na RAM do aparelho
  // ---------------------------------------------------------------------------
  if (action === "resend_login_otp") {
    const prevChallengeId = typeof body.previous_challenge_id === "string"
      ? body.previous_challenge_id.trim()
      : "";
    if (!/^[0-9a-fA-F-]{36}$/.test(prevChallengeId)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_OTP_INPUT" }, 400);
    }

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const ownerUid = await ensureCanonicalCeoAuthUser();
    const otpCode = generateCsprngSixDigitCode();

    const { data: resendData, error: resendErr } = await supabaseAdmin.rpc("ceo_edge_resend_login_otp", {
      p_user_id: ownerUid,
      p_previous_challenge_id: prevChallengeId,
      p_device_hash: deviceHash,
      p_ip_hash: ipHash,
      p_new_otp_code: otpCode,
    });

    if (resendErr || !resendData) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_OTP_RESEND_FAILED" }, 500);
    }

    const resendJson = resendData as Record<string, unknown>;
    if (resendJson.ok !== true) {
      const code = String(resendJson.error_code ?? "ERR_OTP_REQUEST_DENIED");
      const status = code === "ERR_OTP_COOLDOWN_ACTIVE" ? 429 : 400;
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse(resendJson, status);
    }

    const html = buildSixDigitOtpEmailHtml({
      otpCode,
      badgeText: "DESPERRENGUE CEO · NOVO CÓDIGO DE ENTRADA",
      headline: "Novo Código de 6 Dígitos Gerado",
      subtitle: "O código anterior foi invalidado imediatamente",
      instruction: "Digite os 6 dígitos abaixo no Desperrengue CEO para concluir sua entrada:",
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    const delivered = await sendStrictCeoEmail(
      `[Desperrengue CEO] Novo Código de Acesso: ${otpCode.slice(0, 3)} ${otpCode.slice(3, 6)}`,
      html,
    );

    await enforceTimingFloorWithJitter(startedAt, 420);

    if (!delivered) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_DELIVERY_FAILED" }, 502);
    }

    return jsonResponse({
      ok: true,
      challenge_id: resendJson.challenge_id,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: resendJson.expires_at,
      next_cooldown_seconds: resendJson.next_cooldown_seconds ?? 60,
    });
  }

  // ---------------------------------------------------------------------------
  // 7. `complete_login_2fa` — Valida 6 dígitos e hidrata Sessão Soberana In-App
  // ---------------------------------------------------------------------------
  if (action === "complete_login_2fa") {
    const challengeId = typeof body.challenge_id === "string" ? body.challenge_id.trim() : "";
    const otpCode = typeof body.otp_code === "string" ? body.otp_code.replace(/\D/g, "") : "";

    if (!/^[0-9a-fA-F-]{36}$/.test(challengeId) || !/^[0-9]{6}$/.test(otpCode)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_OTP_INPUT" }, 400);
    }

    const ownerUid = await ensureCanonicalCeoAuthUser();
    const { data: completeData, error: completeErr } = await supabaseAdmin.rpc("ceo_edge_complete_login_2fa", {
      p_user_id: ownerUid,
      p_challenge_id: challengeId,
      p_otp_code: otpCode,
      p_device_hash: deviceHash,
      p_device_label: deviceLabel,
    });

    if (completeErr || !completeData) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_LOGIN_2FA_FAILED" }, 500);
    }

    const completeJson = completeData as Record<string, unknown>;
    if (completeJson.ok !== true) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse(completeJson, 401);
    }

    let jwtSession;
    try {
      jwtSession = await mintInAppSovereignJwtSession();
    } catch {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_SOVEREIGN_SESSION_MINT_FAILED" }, 500);
    }

    await enforceTimingFloorWithJitter(startedAt, 420);
    return jsonResponse({
      ok: true,
      owner_email: MONOCRATIC_CEO_EMAIL,
      access_token: jwtSession.accessToken,
      refresh_token: jwtSession.refreshToken,
      expires_in: jwtSession.expiresIn,
      stepup_token: completeJson.stepup_token,
      stepup_expires_at: completeJson.stepup_expires_at,
      password_version: completeJson.password_version,
      password_updated_at: completeJson.password_updated_at,
    });
  }

  // ---------------------------------------------------------------------------
  // 8. `get_ceo_profile_security_status` — Telemetria do Perfil CEO (Autenticado)
  // ---------------------------------------------------------------------------
  if (action === "get_ceo_profile_security_status") {
    const authCheck = await authenticateBearerCeoOwner(req);
    if (!authCheck.ok) {
      await enforceTimingFloorWithJitter(startedAt, 380);
      return jsonResponse({ ok: false, error_code: authCheck.errorCode }, authCheck.status);
    }

    const stepupToken = typeof body.stepup_token === "string" ? body.stepup_token.trim().toLowerCase() : "";
    const { data, error } = await supabaseAdmin.rpc("ceo_edge_get_profile_security_status", {
      p_user_id: authCheck.userId,
      p_stepup_token: stepupToken,
      p_device_hash: deviceHash,
    });

    await enforceTimingFloorWithJitter(startedAt, 360);
    if (error || !data) {
      return jsonResponse({ ok: false, error_code: "ERR_PROFILE_STATUS_FAILED" }, 500);
    }
    const resJson = data as Record<string, unknown>;
    return jsonResponse(resJson, resJson.ok === true ? 200 : 401);
  }

  // ---------------------------------------------------------------------------
  // 9. `request_password_change_otp` — Perfil CEO Etapa 1: Envia E-mail #1 (6 dígitos)
  // ---------------------------------------------------------------------------
  if (action === "request_password_change_otp") {
    const authCheck = await authenticateBearerCeoOwner(req);
    if (!authCheck.ok) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: authCheck.errorCode }, authCheck.status);
    }

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const stepupToken = typeof body.stepup_token === "string" ? body.stepup_token.trim().toLowerCase() : "";
    const otpCode = generateCsprngSixDigitCode();

    const { data: reqData, error: reqErr } = await supabaseAdmin.rpc(
      "ceo_edge_request_profile_password_change_otp",
      {
        p_user_id: authCheck.userId,
        p_stepup_token: stepupToken,
        p_device_hash: deviceHash,
        p_ip_hash: ipHash,
        p_otp_code: otpCode,
      },
    );

    if (reqErr || !reqData) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_OTP_CHALLENGE_PERSIST_FAILED" }, 500);
    }

    const reqJson = reqData as Record<string, unknown>;
    if (reqJson.ok !== true) {
      const code = String(reqJson.error_code ?? "ERR_OTP_REQUEST_DENIED");
      const status = code === "ERR_OTP_COOLDOWN_ACTIVE" ? 429 : 401;
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse(reqJson, status);
    }

    const html = buildSixDigitOtpEmailHtml({
      otpCode,
      badgeText: "PERFIL CEO · ETAPA 1 DE 2 · AUTORIZAÇÃO DE TROCA",
      headline: "Código para Liberar Troca da Senha Mestra",
      subtitle: "Solicitado dentro do Perfil Soberano no Desperrengue CEO",
      instruction:
        "Digite os 6 dígitos abaixo no Perfil CEO do aplicativo para autorizar e receber o link exclusivo de criação da nova senha:",
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    const delivered = await sendStrictCeoEmail(
      `[Desperrengue CEO] Código para Alterar Senha: ${otpCode.slice(0, 3)} ${otpCode.slice(3, 6)}`,
      html,
    );

    await enforceTimingFloorWithJitter(startedAt, 420);

    if (!delivered) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_DELIVERY_FAILED" }, 502);
    }

    return jsonResponse({
      ok: true,
      challenge_id: reqJson.challenge_id,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: reqJson.expires_at,
      next_cooldown_seconds: reqJson.next_cooldown_seconds ?? 30,
    });
  }

  // ---------------------------------------------------------------------------
  // 10. `verify_password_change_otp_and_dispatch_link` — Valida 6d e envia E-mail #2
  //     com botão clicável HTTPS -> Deep-Link fixado em `br.com.desperrengue.app.founder`
  // ---------------------------------------------------------------------------
  if (action === "verify_password_change_otp_and_dispatch_link") {
    const authCheck = await authenticateBearerCeoOwner(req);
    if (!authCheck.ok) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: authCheck.errorCode }, authCheck.status);
    }

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const stepupToken = typeof body.stepup_token === "string" ? body.stepup_token.trim().toLowerCase() : "";
    const challengeId = typeof body.challenge_id === "string" ? body.challenge_id.trim() : "";
    const otpCode = typeof body.otp_code === "string" ? body.otp_code.replace(/\D/g, "") : "";

    if (!/^[0-9a-fA-F-]{36}$/.test(challengeId) || !/^[0-9]{6}$/.test(otpCode)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_OTP_INPUT" }, 400);
    }

    const rawGrantHex = generateCsprngHex(32);

    const { data: verifyData, error: verifyErr } = await supabaseAdmin.rpc(
      "ceo_edge_verify_profile_otp_and_issue_reset_link",
      {
        p_user_id: authCheck.userId,
        p_stepup_token: stepupToken,
        p_device_hash: deviceHash,
        p_challenge_id: challengeId,
        p_otp_code: otpCode,
        p_raw_grant_hex: rawGrantHex,
      },
    );

    if (verifyErr || !verifyData) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse({ ok: false, error_code: "ERR_RESET_LINK_ISSUE_FAILED" }, 500);
    }

    const verifyJson = verifyData as Record<string, unknown>;
    if (verifyJson.ok !== true) {
      await enforceTimingFloorWithJitter(startedAt, 420);
      return jsonResponse(verifyJson, 400);
    }

    const linkId = String(verifyJson.link_id);
    const bridgeUrl =
      `${SUPABASE_URL}/functions/v1/ceo-vault-authority?bridge=reset-password&lid=${encodeURIComponent(linkId)}&gt=${encodeURIComponent(rawGrantHex)}`;

    const emailHtml = buildPasswordResetLinkUnlockedEmailHtml({
      bridgeUrl,
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    const delivered = await sendStrictCeoEmail(
      "[Desperrengue CEO] Troca de Senha Liberada — Toque para Abrir no Aplicativo",
      emailHtml,
    );

    await enforceTimingFloorWithJitter(startedAt, 440);

    if (!delivered) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_DELIVERY_FAILED" }, 502);
    }

    return jsonResponse({
      ok: true,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: verifyJson.expires_at,
    });
  }

  // ---------------------------------------------------------------------------
  // 11. `commit_password_reset_from_link` — Efetiva Nova Senha Forte via Deep-Link,
  //     incrementa `password_version` e revoga 100% das sessões globalmente!
  // ---------------------------------------------------------------------------
  if (action === "commit_password_reset_from_link") {
    // Se houver um Bearer token presente de um não-titular, bloqueia com canário imediatamente
    const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
    if (authHeader.toLowerCase().startsWith("bearer ") && authHeader.slice(7).trim().length > 20) {
      const { data: maybeAuth } = await supabaseAdmin.auth.getUser(authHeader.slice(7).trim());
      if (maybeAuth?.user?.email) {
        const bearerEmail = maybeAuth.user.email.trim().toLowerCase();
        if (!constantTimeEqualsAscii(bearerEmail, MONOCRATIC_CEO_EMAIL)) {
          await supabaseAdmin.rpc("ceo_edge_log_intrusion_canary", {
            p_actor_uid: maybeAuth.user.id,
            p_attempted_email: bearerEmail,
            p_reason: "COMMIT_PW_RESET_NON_OWNER_BEARER",
            p_meta: {},
          });
          await enforceTimingFloorWithJitter(startedAt, 440);
          return jsonResponse({ ok: false, error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501" }, 403);
        }
      }
    }

    const linkId = typeof body.link_id === "string" ? body.link_id.trim() : "";
    const grantToken = typeof body.grant_token === "string" ? body.grant_token.trim().toLowerCase() : "";
    const newPassword = typeof body.password === "string" ? body.password : "";
    const providedCk = typeof body.client_key_hex === "string"
      ? body.client_key_hex.trim().toLowerCase()
      : "";

    if (!/^[0-9a-fA-F-]{36}$/.test(linkId) || !/^[0-9a-f]{64}$/.test(grantToken)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_RESET_LINK_INVALID" }, 400);
    }

    const policy = evaluateCeoStrongPassword(newPassword);
    if (!policy.valid) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_WEAK_PASSWORD_POLICY",
          failed_rules: policy.failedRules,
          shannon_bits_per_char: policy.shannonBitsPerChar,
          total_entropy_bits: policy.totalEntropyBits,
          message:
            "A nova Senha Mestra deve atender 100% aos requisitos de complexidade, entropia e comprimento (12 a 64 caracteres).",
        },
        422,
      );
    }

    const derivedCk = await deriveClientKeyFromPassword(newPassword);
    if (providedCk.length > 0 && !constantTimeEqualsAscii(derivedCk, providedCk)) {
      await enforceTimingFloorWithJitter(startedAt, 400);
      return jsonResponse({ ok: false, error_code: "ERR_KDF_INTEGRITY_MISMATCH" }, 400);
    }

    const newEdgeKeyHex = await blindClientKeyWithEdgePepper(derivedCk);
    const ownerUid = await ensureCanonicalCeoAuthUser();

    const { data: commitData, error: commitErr } = await supabaseAdmin.rpc(
      "ceo_edge_commit_password_reset_from_link",
      {
        p_user_id: ownerUid,
        p_link_id: linkId,
        p_raw_grant_hex: grantToken,
        p_new_edge_key_hex: newEdgeKeyHex,
        p_device_hash: deviceHash,
        p_device_label: deviceLabel,
      },
    );

    if (commitErr || !commitData) {
      await enforceTimingFloorWithJitter(startedAt, 440);
      return jsonResponse({ ok: false, error_code: "ERR_PASSWORD_ROTATION_FAILED" }, 500);
    }

    const commitJson = commitData as Record<string, unknown>;
    if (commitJson.ok !== true) {
      const code = String(commitJson.error_code ?? "ERR_PASSWORD_ROTATION_DENIED");
      const status = code === "ERR_PASSWORD_REUSE_FORBIDDEN" ? 422 : 400;
      await enforceTimingFloorWithJitter(startedAt, 440);
      return jsonResponse(commitJson, status);
    }

    // Revogação global de todos os refresh/access tokens GoTrue do titular para exigir novo login completo
    try {
      await supabaseAdmin.auth.admin.signOut(ownerUid, "global");
    } catch {
      // As sessões step-up no PostgreSQL já foram 100% revogadas atomicamente
    }

    if (RESEND_API_KEY) {
      const confirmHtml = buildSecurityNoticeEmailHtml({
        badgeText: "COFRE SOBERANO ATUALIZADO · SESSÕES ANTERIORES ENCERRADAS",
        headline: "Sua Senha Mestra CEO Foi Alterada com Sucesso",
        bodyHtml:
          "<p style=\"margin:0;\">A Senha Mestra de Administrador do <strong style=\"color:#FDE047;\">Desperrengue CEO</strong> foi recifrada em AES-256 com novo sal criptográfico de 256 bits. Por segurança máxima, todas as sessões anteriores foram encerradas para que você valide sua entrada com a nova senha e código de 6 dígitos.</p>",
        timestampSp: formatSaoPauloTimestamp(),
        deviceLabel,
      });
      await sendStrictCeoEmail("[Desperrengue CEO] Confirmação de Alteração da Senha Mestra", confirmHtml);
    }

    await enforceTimingFloorWithJitter(startedAt, 440);
    return jsonResponse({
      ok: true,
      require_full_relogin: true,
      password_version: commitJson.password_version,
      password_updated_at: commitJson.password_updated_at,
    });
  }

  await enforceTimingFloorWithJitter(startedAt, 320);
  return jsonResponse({ ok: false, error_code: "ERR_UNKNOWN_ACTION" }, 400);
});

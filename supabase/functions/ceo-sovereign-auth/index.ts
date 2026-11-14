// Edge Function: ceo-sovereign-auth
//
// Barreira Criptográfica Monocrática do aplicativo exclusivo `Desperrengue CEO`
// (`br.com.desperrengue.app.founder`).
//
// INVARIANTES DE SEGURANÇA EXTREMA:
//   1. Titular Único Inviolável: APENAS `wagneroliveira2395@gmail.com` (validado
//      criptograficamente via `supabaseAdmin.auth.getUser(jwt)` no servidor Auth)
//      pode solicitar ou validar códigos de segurança.
//   2. Qualquer tentativa com outro e-mail grava imediatamente um `INTRUSION_CANARY`
//      comitado na cadeia WORM SHA-256 (`private.founder_audit_log`) e retorna 403
//      com piso de tempo constante (~350 ms) sem jamais disparar e-mail.
//   3. Destinatário Hardcoded: o campo `to` do Resend TLS 1.3 é SEMPRE a constante
//      imutável `["wagneroliveira2395@gmail.com"]` — nunca lido do body da requisição.
//   4. Zero OTP em Texto Puro em Repouso ou Logs: o código CSPRNG de 6 dígitos
//      (rejection sampling sem viés modular) é persistido em `private.ceo_otp_challenges`
//      exclusivamente como digest `SHA-256` salgado + apimentado (TTL 5 min, máx 5 tentativas).

import { createClient } from "@supabase/supabase-js";

const CANONICAL_CEO_EMAIL = "wagneroliveira2395@gmail.com";
const MASKED_CEO_EMAIL = "wa***95@gmail.com";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const EMAIL_FROM = Deno.env.get("CEO_SECURITY_EMAIL_FROM") ??
  Deno.env.get("EMAIL_FROM") ??
  "Desperrengue CEO Security <onboarding@desperrengue.tech>";

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Pragma": "no-cache",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
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

/** Gera código numérico de 6 dígitos via CSPRNG sem viés modular (rejection sampling). */
function generateCsprngSixDigitCode(): string {
  const buf = new Uint32Array(1);
  // Maior múltiplo de 1.000.000 estritamente <= 2^32 (4.294.000.000)
  const limit = 4_294_000_000;
  while (true) {
    crypto.getRandomValues(buf);
    const val = buf[0]!;
    if (val < limit) {
      return String(val % 1_000_000).padStart(6, "0");
    }
  }
}

async function enforceTimingFloor(startedAtMs: number, minElapsedMs: number): Promise<void> {
  const elapsed = Date.now() - startedAtMs;
  if (elapsed < minElapsedMs) {
    await new Promise((resolve) => setTimeout(resolve, minElapsedMs - elapsed));
  }
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

function purposeHumanLabel(purpose: string): string {
  switch (purpose) {
    case "INITIAL_PIN_SETUP":
      return "Criação do seu PIN Pessoal Soberano";
    case "PIN_RESET":
      return "Redefinição do seu PIN Pessoal Soberano";
    case "NEW_DEVICE_BIND":
      return "Autorização Criptográfica de Novo Dispositivo";
    default:
      return "Validação de Segurança do Cofre CEO";
  }
}

function buildSovereignOtpEmailHtml(params: {
  otpCode: string;
  purpose: string;
  deviceLabel: string;
  deviceHashPrefix: string;
  timestampSp: string;
}): string {
  const codeLeft = escapeHtml(params.otpCode.slice(0, 3));
  const codeRight = escapeHtml(params.otpCode.slice(3, 6));
  const purposeTitle = escapeHtml(purposeHumanLabel(params.purpose));
  const safeDevice = escapeHtml(params.deviceLabel);
  const safeFp = escapeHtml(params.deviceHashPrefix.toUpperCase());
  const safeTs = escapeHtml(params.timestampSp);

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Código de Segurança Desperrengue CEO</title>
</head>
<body style="margin:0;padding:24px 12px;background:#07090D;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#F8FAFC;">
  <div style="max-width:540px;margin:0 auto;background:#0E131B;border:1px solid #2A3342;border-radius:20px;overflow:hidden;">
    <div style="padding:28px 24px 20px;background:linear-gradient(135deg,#0B0F17 0%,#161E2C 100%);border-bottom:1px solid rgba(245,158,11,0.28);text-align:center;">
      <div style="display:inline-block;padding:5px 12px;border-radius:999px;background:rgba(245,158,11,0.14);border:1px solid rgba(245,158,11,0.45);color:#FDE047;font-size:11px;font-weight:700;letter-spacing:1.6px;text-transform:uppercase;">
        DESPERRENGUE CEO · COFRE SOBERANO
      </div>
      <h1 style="margin:14px 0 4px;font-size:22px;font-weight:800;color:#FFFFFF;letter-spacing:-0.3px;">
        Código de Verificação Exclusivo
      </h1>
      <p style="margin:0;font-size:13px;color:#94A3B8;">
        ${purposeTitle}
      </p>
    </div>

    <div style="padding:28px 24px;">
      <p style="margin:0 0 18px;font-size:14px;line-height:1.6;color:#CBD5E1;">
        Olá, <strong style="color:#FFFFFF;">Wagner</strong>. Digite os 6 dígitos abaixo nas células ópticas do aplicativo
        <strong style="color:#FDE047;">Desperrengue CEO</strong> para prosseguir com segurança máxima:
      </p>

      <div style="margin:22px 0;padding:22px 16px;background:#07090D;border:1px solid rgba(253,224,71,0.42);border-radius:16px;text-align:center;">
        <div style="font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace;font-size:36px;font-weight:800;letter-spacing:8px;color:#FDE047;">
          ${codeLeft}&nbsp;${codeRight}
        </div>
        <div style="margin-top:10px;font-size:12px;color:#94A3B8;">
          Expira em <strong style="color:#E2E8F0;">5 minutos</strong> · Uso único · Protegido por SHA-256
        </div>
      </div>

      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:18px 0;background:#111824;border-radius:12px;border:1px solid #1E293B;">
        <tr>
          <td style="padding:12px 16px;font-size:12px;color:#94A3B8;border-bottom:1px solid #1E293B;">Dispositivo solicitante</td>
          <td style="padding:12px 16px;font-size:12px;color:#F1F5F9;font-weight:600;text-align:right;border-bottom:1px solid #1E293B;">${safeDevice}</td>
        </tr>
        <tr>
          <td style="padding:12px 16px;font-size:12px;color:#94A3B8;border-bottom:1px solid #1E293B;">Assinatura SHA-256</td>
          <td style="padding:12px 16px;font-family:monospace;font-size:12px;color:#67E8F9;text-align:right;border-bottom:1px solid #1E293B;">${safeFp}…</td>
        </tr>
        <tr>
          <td style="padding:12px 16px;font-size:12px;color:#94A3B8;">Horário (Brasília)</td>
          <td style="padding:12px 16px;font-size:12px;color:#E2E8F0;text-align:right;">${safeTs}</td>
        </tr>
      </table>

      <p style="margin:18px 0 0;font-size:12px;line-height:1.55;color:#94A3B8;">
        <strong style="color:#F87171;">Alerta Anti-Phishing:</strong> Jamais informe este código a terceiros.
        Se você não iniciou esta ação no seu aparelho, ignore esta mensagem — seu Cofre Soberano permanece trancado.
      </p>
    </div>

    <div style="padding:16px 24px;background:#090D14;border-top:1px solid #1E293B;text-align:center;font-size:11px;color:#64748B;">
      Titularidade Monocrática Exclusiva · Desperrengue CEO Security Kernel
    </div>
  </div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  const startedAt = Date.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ ok: false, error_code: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return jsonResponse({ ok: false, error_code: "ERR_SERVER_MISCONFIGURED" }, 500);
  }

  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const jwt = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";

  if (!jwt) {
    await enforceTimingFloor(startedAt, 350);
    return jsonResponse({ ok: false, error_code: "ERR_MISSING_BEARER_TOKEN" }, 401);
  }

  // 1. Verificação criptográfica do JWT diretamente contra o Supabase Auth Server
  const { data: authData, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  const user = authData?.user;

  if (authErr || !user) {
    await enforceTimingFloor(startedAt, 350);
    return jsonResponse({ ok: false, error_code: "ERR_INVALID_OR_EXPIRED_JWT" }, 401);
  }

  const normalizedEmail = (user.email ?? "").trim().toLowerCase();

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const action = typeof body.action === "string" ? body.action.trim().toLowerCase() : "";

  // 2. Barreira Monocrática Absoluta: qualquer e-mail != wagneroliveira2395@gmail.com é barrado com canário WORM!
  if (normalizedEmail !== CANONICAL_CEO_EMAIL) {
    try {
      await supabaseAdmin.rpc("ceo_edge_log_intrusion_canary", {
        p_actor_uid: user.id,
        p_attempted_email: normalizedEmail,
        p_reason: "EDGE_NON_OWNER_EMAIL_REJECTED",
        p_meta: {
          action: action.slice(0, 32),
        },
      });
    } catch {
      // Falha secundária jamais suprime o bloqueio 403
    }

    await enforceTimingFloor(startedAt, 350);
    return jsonResponse(
      {
        ok: false,
        error_code: "ERR_MONOCRATIC_OWNER_ONLY_42501",
        message: "Acesso restrito exclusivamente ao titular soberano do Desperrengue CEO.",
      },
      403,
    );
  }

  const deviceHash = typeof body.device_hash === "string" ? body.device_hash.trim().toLowerCase() : "";
  const deviceLabel = typeof body.device_label === "string" && body.device_label.trim().length > 0
    ? body.device_label.trim().slice(0, 80)
    : "Dispositivo Soberano CEO";

  if (!/^[0-9a-f]{64}$/.test(deviceHash)) {
    await enforceTimingFloor(startedAt, 250);
    return jsonResponse({ ok: false, error_code: "ERR_INVALID_DEVICE_HASH" }, 400);
  }

  // 3. Ação 1: Emitir e enviar código criptográfico de 6 dígitos para wagneroliveira2395@gmail.com
  if (action === "request_otp") {
    const rawPurpose = typeof body.purpose === "string" ? body.purpose.trim().toUpperCase() : "INITIAL_PIN_SETUP";
    const purpose = ["INITIAL_PIN_SETUP", "PIN_RESET", "NEW_DEVICE_BIND"].includes(rawPurpose)
      ? rawPurpose
      : "INITIAL_PIN_SETUP";

    if (!RESEND_API_KEY) {
      return jsonResponse({ ok: false, error_code: "ERR_EMAIL_GATEWAY_NOT_CONFIGURED" }, 503);
    }

    const otpCode = generateCsprngSixDigitCode();

    const { data: issueRes, error: issueErr } = await supabaseAdmin.rpc("ceo_edge_issue_otp_challenge", {
      p_user_id: user.id,
      p_purpose: purpose,
      p_device_hash: deviceHash,
      p_otp_code: otpCode,
      p_delivery_channel: "RESEND_TLS",
    });

    if (issueErr || !issueRes) {
      await enforceTimingFloor(startedAt, 300);
      return jsonResponse({ ok: false, error_code: "ERR_OTP_CHALLENGE_PERSIST_FAILED" }, 500);
    }

    const issueJson = issueRes as Record<string, unknown>;
    if (issueJson.ok !== true) {
      const code = String(issueJson.error_code ?? "ERR_OTP_REQUEST_DENIED");
      const status = code === "ERR_OTP_COOLDOWN_ACTIVE" ? 429 : 400;
      await enforceTimingFloor(startedAt, 300);
      return jsonResponse(issueJson, status);
    }

    const html = buildSovereignOtpEmailHtml({
      otpCode,
      purpose,
      deviceLabel,
      deviceHashPrefix: deviceHash.slice(0, 12),
      timestampSp: formatSaoPauloTimestamp(),
    });

    // Destinatário estritamente imutável: somente [CANONICAL_CEO_EMAIL]
    const emailResp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [CANONICAL_CEO_EMAIL],
        subject: `[Desperrengue CEO] Código de Segurança: ${otpCode.slice(0, 3)} ${otpCode.slice(3, 6)}`,
        html,
      }),
    });

    if (!emailResp.ok) {
      await enforceTimingFloor(startedAt, 350);
      return jsonResponse(
        {
          ok: false,
          error_code: "ERR_EMAIL_DELIVERY_FAILED",
          message: "Não foi possível entregar o código de 6 dígitos no momento. Tente novamente em instantes.",
        },
        502,
      );
    }

    await enforceTimingFloor(startedAt, 350);
    return jsonResponse({
      ok: true,
      challenge_id: issueJson.challenge_id,
      masked_destination: MASKED_CEO_EMAIL,
      expires_at: issueJson.expires_at,
      next_cooldown_seconds: issueJson.next_cooldown_seconds ?? 30,
    });
  }

  // 4. Ação 2: Validar os 6 dígitos em tempo constante SHA-256 e retornar `enrollment_ticket`
  if (action === "verify_otp") {
    const challengeId = typeof body.challenge_id === "string" ? body.challenge_id.trim() : "";
    const otpCode = typeof body.otp_code === "string" ? body.otp_code.replace(/\D/g, "") : "";

    if (!/^[0-9a-fA-F-]{36}$/.test(challengeId) || !/^[0-9]{6}$/.test(otpCode)) {
      await enforceTimingFloor(startedAt, 300);
      return jsonResponse({ ok: false, error_code: "ERR_INVALID_OTP_INPUT" }, 400);
    }

    const { data: verifyRes, error: verifyErr } = await supabaseAdmin.rpc("ceo_edge_verify_otp_challenge", {
      p_user_id: user.id,
      p_challenge_id: challengeId,
      p_device_hash: deviceHash,
      p_otp_code: otpCode,
      p_device_label: deviceLabel,
    });

    await enforceTimingFloor(startedAt, 320);

    if (verifyErr || !verifyRes) {
      return jsonResponse({ ok: false, error_code: "ERR_OTP_VERIFICATION_FAILED" }, 500);
    }

    const verifyJson = verifyRes as Record<string, unknown>;
    return jsonResponse(verifyJson, verifyJson.ok === true ? 200 : 400);
  }

  await enforceTimingFloor(startedAt, 250);
  return jsonResponse({ ok: false, error_code: "ERR_UNKNOWN_ACTION" }, 400);
});

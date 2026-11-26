// Edge Function: enviar-email-aprovacao
//
// Envia o e-mail oficial de aprovação da conta Desperrengue (via Resend) tanto
// para **Clientes** quanto para **Profissionais**.
//
// Formas de invocação autorizadas:
//  1. Trigger/Webhook do banco com header `x-webhook-secret` (compatível com
//     `profiles_notify_kyc_approved` para APPROVED_PENDING_EMAIL);
//  2. Chamada autenticada do aplicativo (`Authorization: Bearer <user_jwt>`)
//     logo após concluir o cadastro KYC ou ao tocar em "Reenviar e-mail".
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM") ??
  "Desperrengue <onboarding@desperrengue.tech>";
const DEEP_LINK = Deno.env.get("ONBOARDING_DEEP_LINK") ??
  "desperrengue://onboarding/ativar";

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

function formatDateBr(isoOrNull: string | null | undefined): string {
  const target = isoOrNull
    ? new Date(isoOrNull)
    : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
  if (Number.isNaN(target.getTime())) {
    const fallback = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
    return fallback.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
  }
  return target.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}

function buildHtml(params: {
  nome: string;
  roleMode: "client" | "provider";
  validUntilBr: string;
}): string {
  const safeName = escapeHtml(params.nome);
  const safeDate = escapeHtml(params.validUntilBr);
  const isProvider = params.roleMode === "provider";
  const badgeLabel = isProvider
    ? "CONTA DE PROFISSIONAL APROVADA"
    : "CONTA DE CLIENTE APROVADA";
  const leadParagraph = isProvider
    ? "Concluímos a verificação da sua identidade biométrica, documento oficial e Certidão Negativa da Polícia Federal. Sua conta de <strong>Profissional Desperrengue foi aprovada com sucesso</strong>!"
    : "Concluímos a verificação da sua identidade biométrica, documento oficial e Certidão Negativa da Polícia Federal. Sua conta de <strong>Cliente Desperrengue foi aprovada com sucesso</strong>!";
  const actionParagraph = isProvider
    ? "Toque no botão abaixo pelo seu celular para validar este e-mail, ativar seu perfil e começar a receber chamados com custódia protegida."
    : "Toque no botão abaixo pelo seu celular para validar este e-mail e liberar seu acesso completo para contratar profissionais verificados com garantia de 90 dias.";
  const ctaLabel = isProvider
    ? "Confirmar e Ativar Perfil Profissional"
    : "Confirmar e Ativar Minha Conta";

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Sua conta Desperrengue foi aprovada!</title>
</head>
<body style="margin:0;padding:0;background:#F4F7FC;font-family:Inter,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0F172A;">
  <div style="max-width:600px;margin:32px auto;background:#FFFFFF;border-radius:20px;overflow:hidden;border:1px solid #DCE5F2;box-shadow:0 8px 30px rgba(15,23,42,0.06);">
    <div style="background:linear-gradient(135deg,#0B1F4D 0%,#1D4ED8 100%);padding:36px 28px;text-align:center;">
      <div style="display:inline-block;padding:6px 14px;border-radius:999px;background:rgba(16,185,129,0.2);border:1px solid rgba(52,211,153,0.45);color:#A7F3D0;font-size:12px;font-weight:700;letter-spacing:0.6px;margin-bottom:14px;">
        ✓ ${badgeLabel}
      </div>
      <h1 style="color:#FFFFFF;margin:0;font-size:26px;font-weight:800;letter-spacing:-0.4px;">Desperrengue</h1>
      <p style="color:#CBD5E1;margin:6px 0 0;font-size:14px;">Comunidade verificada · Segurança real em cada atendimento</p>
    </div>
    <div style="padding:32px 28px;">
      <h2 style="margin:0 0 14px;font-size:22px;color:#0F172A;letter-spacing:-0.3px;">Tudo pronto, ${safeName}!</h2>
      <p style="font-size:15px;line-height:1.65;color:#334155;margin:0 0 14px;">
        ${leadParagraph}
      </p>
      <p style="font-size:15px;line-height:1.65;color:#334155;margin:0 0 24px;">
        ${actionParagraph}
      </p>
      <div style="text-align:center;margin:28px 0;">
        <a href="${DEEP_LINK}"
           style="background:#1D4ED8;color:#FFFFFF;text-decoration:none;padding:16px 32px;border-radius:14px;font-size:16px;font-weight:700;display:inline-block;box-shadow:0 6px 18px rgba(29,78,216,0.28);">
          ${ctaLabel}
        </a>
      </div>
      <div style="background:#F0FDF4;border:1px solid #BBF7D0;border-radius:14px;padding:16px 18px;margin:24px 0;">
        <p style="margin:0 0 6px;font-size:13px;font-weight:700;color:#065F46;">
          🛡️ Validade Oficial de Segurança: 90 dias (até ${safeDate})
        </p>
        <p style="margin:0;font-size:13px;line-height:1.55;color:#047857;">
          Alinhada ao prazo oficial da Certidão da Polícia Federal, sua validação vale até <strong>${safeDate}</strong>.
          Não se preocupe: enviaremos lembretes automáticos por e-mail 15 dias e 5 dias antes do vencimento.
        </p>
      </div>
      <p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
        Está lendo este e-mail em outro dispositivo ou o botão não abriu direto? Basta abrir o aplicativo
        <strong>Desperrengue</strong> no seu celular e tocar em <strong>"Já validei meu e-mail"</strong>.
      </p>
    </div>
    <div style="text-align:center;padding:22px 24px;font-size:12px;color:#94A3B8;background:#F8FAFC;border-top:1px solid #E2E8F0;">
      Se você não solicitou este cadastro, ignore este e-mail ou fale com privacidade@desperrengue.com.br.<br />
      © 2026 Desperrengue. Todos os direitos reservados.
    </div>
  </div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const payload = await req.json().catch(() => ({}));
    const providedSecret = req.headers.get("x-webhook-secret") ?? "";
    const authHeader = req.headers.get("authorization") ?? "";

    let targetUserId: string | null = null;
    let requestedMode: "client" | "provider" | null = null;

    // Modo 1: Trigger/Webhook com segredo compartilhado
    if (WEBHOOK_SECRET && providedSecret && safeEqual(providedSecret, WEBHOOK_SECRET)) {
      const record = payload?.record;
      if (!record || typeof record.id !== "string") {
        return json({ error: "Payload inválido." }, 400);
      }
      if (
        record.verification_status !== "APPROVED_PENDING_EMAIL" &&
        record.client_kyc_status !== "APPROVED" &&
        payload?.force !== true
      ) {
        return json({ sent: false, message: "Status não exige envio de e-mail." });
      }
      targetUserId = record.id;
      requestedMode = record.is_provider && !record.is_client
        ? "provider"
        : (payload?.target_mode === "provider" ? "provider" : "client");
    } else if (authHeader.toLowerCase().startsWith("bearer ")) {
      // Modo 2: Usuário autenticado via JWT do app
      const jwt = authHeader.slice(7).trim();
      const { data: userRes, error: userErr } = await supabaseAdmin.auth.getUser(jwt);
      if (userErr || !userRes?.user?.id) {
        return json({ error: "Unauthorized" }, 401);
      }
      targetUserId = userRes.user.id;
      requestedMode = payload?.target_mode === "provider" ? "provider" : "client";
    } else {
      return json({ error: "Unauthorized" }, 401);
    }

    const { data: profile, error: profErr } = await supabaseAdmin
      .from("profiles")
      .select(
        "id, full_name, verified_full_name, is_client, is_provider, client_kyc_status, liveness_verified, verification_status, kyc_expires_at, criminal_record_expires_at",
      )
      .eq("id", targetUserId)
      .maybeSingle();

    if (profErr || !profile) {
      return json({ error: "Perfil não encontrado." }, 404);
    }

    const isApproved =
      profile.client_kyc_status === "APPROVED" ||
      profile.liveness_verified === true ||
      profile.verification_status === "APPROVED_PENDING_EMAIL" ||
      profile.verification_status === "ACTIVE";

    if (!isApproved) {
      return json({ sent: false, message: "Conta ainda não aprovada." }, 409);
    }

    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.getUserById(
      targetUserId,
    );
    if (authErr || !authData?.user?.email) {
      return json({ error: "E-mail do usuário não encontrado." }, 404);
    }

    const roleMode: "client" | "provider" = requestedMode ??
      (profile.is_provider && !profile.is_client ? "provider" : "client");

    const rawName = (profile.verified_full_name || profile.full_name || "").trim();
    const firstName = rawName && !rawName.includes("@")
      ? rawName.split(/\s+/)[0]
      : (roleMode === "provider" ? "Profissional" : "Cliente");

    const validUntilIso = profile.kyc_expires_at || profile.criminal_record_expires_at;
    const validUntilBr = formatDateBr(validUntilIso);

    if (!RESEND_API_KEY) {
      return json({ sent: false, error: "RESEND_API_KEY não configurada." }, 500);
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM,
        to: [authData.user.email],
        subject: roleMode === "provider"
          ? "Sua conta de Profissional Desperrengue foi aprovada!"
          : "Sua conta Desperrengue foi aprovada! Confirme seu e-mail",
        html: buildHtml({
          nome: firstName,
          roleMode,
          validUntilBr,
        }),
      }),
    });

    const result = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("Resend error", res.status, result);
      return json({ sent: false, success: false, error: "Falha ao enviar e-mail." }, 502);
    }

    await supabaseAdmin
      .from("profiles")
      .update({ approval_email_sent_at: new Date().toISOString() })
      .eq("id", targetUserId);

    return json({ sent: true, success: true, id: result?.id, roleMode });
  } catch (error) {
    console.error("enviar-email-aprovacao", error);
    const message = error instanceof Error ? error.message : "Erro desconhecido";
    return json({ sent: false, error: message }, 400);
  }
});

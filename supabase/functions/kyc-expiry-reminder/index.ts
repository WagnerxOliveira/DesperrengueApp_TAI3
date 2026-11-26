// Edge Function: kyc-expiry-reminder
//
// Executada diariamente via pg_cron (ou chamada administrativa autenticada)
// para enviar avisos prévios automáticos por e-mail (Resend) a Clientes e
// Profissionais antes do vencimento do ciclo oficial de 90 dias da Certidão
// da Polícia Federal (15 dias antes, 5 dias antes e no vencimento).
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM") ??
  "Desperrengue Segurança <onboarding@desperrengue.tech>";
const DEEP_LINK = Deno.env.get("ONBOARDING_DEEP_LINK") ??
  "desperrengue://onboarding/ativar";

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
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

interface ReminderRow {
  user_id: string;
  email: string;
  full_name: string;
  is_client: boolean;
  is_provider: boolean;
  expires_at: string;
  days_remaining: number;
  reminder_stage: "15d" | "5d" | "expired";
}

function buildReminderEmail(row: ReminderRow): { subject: string; html: string } {
  const firstName = escapeHtml(
    (row.full_name || "Usuário").trim().split(/\s+/)[0] || "Usuário",
  );
  const expiryDateBr = escapeHtml(
    new Date(row.expires_at).toLocaleDateString("pt-BR", {
      timeZone: "America/Sao_Paulo",
    }),
  );
  const roleDesc = row.is_client && row.is_provider
    ? "Cliente e Profissional"
    : (row.is_provider ? "Profissional" : "Cliente");

  const isExpired = row.reminder_stage === "expired";
  const isUrgent = row.reminder_stage === "5d";

  const subject = isExpired
    ? "Sua validação de 90 dias venceu — Renove sua Certidão PF no Desperrengue"
    : isUrgent
    ? `Faltam ${row.days_remaining} dias para renovar sua validação Desperrengue`
    : `Lembrete: sua validação de 90 dias vence em ${expiryDateBr}`;

  const badgeText = isExpired
    ? "RENOVAÇÃO NECESSÁRIA (CICLO 90 DIAS)"
    : isUrgent
    ? `VENCE EM ${row.days_remaining} DIAS`
    : "AVISO PRÉVIO DE RENOVAÇÃO (90 DIAS)";

  const accentBg = isExpired
    ? "#B91C1C"
    : isUrgent
    ? "#B45309"
    : "#1D4ED8";

  const mainCopy = isExpired
    ? `O ciclo oficial de <strong>90 dias</strong> da sua Certidão de Antecedentes Criminais da Polícia Federal encerrou em <strong>${expiryDateBr}</strong>. Para continuar usando sua conta (${roleDesc}) com proteção total, basta emitir gratuitamente uma nova certidão no gov.br e anexá-la no aplicativo.`
    : `Sua validação de segurança e Certidão Negativa da Polícia Federal (conta <strong>${roleDesc}</strong>) vence em <strong>${expiryDateBr}</strong> (faltam <strong>${row.days_remaining} dias</strong>). Alinhado ao prazo oficial de 90 dias da Polícia Federal, recomendamos renovar antecipadamente para que sua conta nunca seja interrompida.`;

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#F4F7FC;font-family:Inter,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0F172A;">
  <div style="max-width:600px;margin:32px auto;background:#FFFFFF;border-radius:20px;overflow:hidden;border:1px solid #DCE5F2;box-shadow:0 8px 30px rgba(15,23,42,0.06);">
    <div style="background:linear-gradient(135deg,#0B1F4D 0%,${accentBg} 100%);padding:34px 28px;text-align:center;">
      <div style="display:inline-block;padding:6px 14px;border-radius:999px;background:rgba(255,255,255,0.16);border:1px solid rgba(255,255,255,0.35);color:#FFFFFF;font-size:12px;font-weight:700;letter-spacing:0.5px;margin-bottom:12px;">
        🛡️ ${badgeText}
      </div>
      <h1 style="color:#FFFFFF;margin:0;font-size:24px;font-weight:800;">Desperrengue</h1>
    </div>
    <div style="padding:30px 28px;">
      <h2 style="margin:0 0 14px;font-size:20px;color:#0F172A;">Olá, ${firstName}!</h2>
      <p style="font-size:15px;line-height:1.65;color:#334155;margin:0 0 16px;">
        ${mainCopy}
      </p>
      <p style="font-size:14px;line-height:1.6;color:#475569;margin:0 0 24px;">
        A leitura no aplicativo é <strong>100% automática</strong>: você só precisa anexar o PDF gratuito emitido em
        <em>servicos.pf.gov.br/epol-sinic-publico</em> — sem digitar protocolo nem código.
      </p>
      <div style="text-align:center;margin:26px 0;">
        <a href="${DEEP_LINK}"
           style="background:${accentBg};color:#FFFFFF;text-decoration:none;padding:15px 30px;border-radius:14px;font-size:15px;font-weight:700;display:inline-block;">
          Renovar no Aplicativo Agora
        </a>
      </div>
    </div>
    <div style="text-align:center;padding:20px 24px;font-size:12px;color:#94A3B8;background:#F8FAFC;border-top:1px solid #E2E8F0;">
      Ciclo Oficial de Segurança de 90 dias · Proteção LGPD<br />
      © 2026 Desperrengue. Todos os direitos reservados.
    </div>
  </div>
</body>
</html>`;

  return { subject, html };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const providedSecret = req.headers.get("x-webhook-secret") ?? "";
  const authHeader = req.headers.get("authorization") ?? "";
  const isWebhookAuthed = Boolean(WEBHOOK_SECRET) && safeEqual(providedSecret, WEBHOOK_SECRET);
  const isServiceRoleAuthed = Boolean(SERVICE_ROLE_KEY) &&
    authHeader === `Bearer ${SERVICE_ROLE_KEY}`;

  if (!isWebhookAuthed && !isServiceRoleAuthed) {
    return json({ error: "Unauthorized" }, 401);
  }

  if (!RESEND_API_KEY) {
    return json({ error: "RESEND_API_KEY não configurada." }, 500);
  }

  try {
    const { data: rows, error } = await supabaseAdmin.rpc(
      "get_profiles_needing_kyc_expiry_reminder",
    );
    if (error) {
      return json({ error: error.message }, 500);
    }

    const targets: ReminderRow[] = Array.isArray(rows) ? rows : [];
    let sentCount = 0;
    let failedCount = 0;

    for (const row of targets) {
      const { subject, html } = buildReminderEmail(row);
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: FROM,
          to: [row.email],
          subject,
          html,
        }),
      });

      if (!res.ok) {
        failedCount++;
        console.error("kyc-expiry-reminder Resend error", row.user_id, res.status);
        continue;
      }

      const nowIso = new Date().toISOString();
      const updatePatch = row.reminder_stage === "expired"
        ? { kyc_expiry_reminder_expired_sent_at: nowIso }
        : row.reminder_stage === "5d"
        ? { kyc_expiry_reminder_5d_sent_at: nowIso }
        : { kyc_expiry_reminder_15d_sent_at: nowIso };

      await supabaseAdmin
        .from("profiles")
        .update(updatePatch)
        .eq("id", row.user_id);

      sentCount++;
    }

    return json({
      ok: true,
      scanned: targets.length,
      sent: sentCount,
      failed: failedCount,
    });
  } catch (err) {
    console.error("kyc-expiry-reminder", err);
    return json({ error: err instanceof Error ? err.message : "Erro desconhecido" }, 500);
  }
});

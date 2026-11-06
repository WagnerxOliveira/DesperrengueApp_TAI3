// Edge Function: excluir-conta  (Offboarding LGPD + Dossiê de Despedida, POR ESCOPO)
//
// Corpo: { confirm: "EXCLUIR", scope?: "client" | "provider" | "all" }  (padrão: "all")
//   client   -> remove SÓ os dados e o papel de CLIENTE (conta e papel de profissional ficam)
//   provider -> remove SÓ os dados e o papel de PROFISSIONAL (conta e papel de cliente ficam)
//   all      -> conta inteira (purga + Storage + auth.admin.deleteUser)
//
// Fluxo (a ORDEM é a garantia de segurança do usuário):
//   1. autentica o chamador pelo JWT dele (nunca confia em id vindo do corpo);
//   2. exige confirmação explícita ("EXCLUIR") — evita chamada acidental;
//   3. normaliza o escopo NO SERVIDOR (RPC `_normalize_deletion_scope`: um papel só
//      ou escopo que cobre todos os papéis => "all"; papel que a conta não tem => 400);
//   4. trava financeira do escopo NO SERVIDOR (saldo, custódia, serviço em andamento);
//   5. monta o dossiê do escopo (RPC) e gera UM PDF só com as contas excluídas;
//   6. envia o e-mail com o PDF (Resend) ao e-mail do próprio usuário. Se NÃO for 2xx:
//      aborta, nada é apagado;
//   7. só então: purga LGPD do escopo (RPC `purge_account`), limpeza do Storage do
//      escopo e — SOMENTE para "all" — apaga a conta de autenticação (revoga sessões).
// Segredos: RESEND_API_KEY (Supabase secrets). Nada sensível vai para o log.
import { createClient } from "@supabase/supabase-js";
import { buildDossiePdf, toBase64 } from "./dossie.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM") ?? "Equipe Desperrengue <onboarding@desperrengue.tech>";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const esc = (v: string) =>
  v.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

type Scope = "client" | "provider" | "all";
const SCOPES: readonly string[] = ["client", "provider", "all"];

/** Papéis cobertos pelo dossiê -> textos do e-mail. */
function labels(roles: string[]): { subject: string; conta: string; file: string } {
  const c = roles.includes("client");
  const p = roles.includes("provider");
  if (c && p) {
    return { subject: "Dossiê de Despedida — contas de Cliente e Profissional", conta: "suas contas de Cliente e de Profissional", file: "cliente-e-profissional" };
  }
  if (p) return { subject: "Dossiê de Despedida — conta de Profissional", conta: "sua conta de Profissional", file: "profissional" };
  if (c) return { subject: "Dossiê de Despedida — conta de Cliente", conta: "sua conta de Cliente", file: "cliente" };
  return { subject: "Dossiê de Despedida — Desperrengue", conta: "sua conta", file: "conta" };
}

function emailHtml(nome: string, scope: Scope, roles: string[]): string {
  const l = labels(roles);
  const mantida = roles.includes("client") ? "Profissional" : "Cliente";
  const intro = scope === "all"
    ? `Sua conta foi <strong>excluída</strong> a seu pedido (${esc(l.conta)}).`
    : `${esc(l.conta[0].toUpperCase() + l.conta.slice(1))} foi <strong>excluída</strong> a seu pedido. ` +
      `Sua conta de <strong>${mantida}</strong> continua ativa: você pode seguir usando o aplicativo com o mesmo e-mail e senha.`;
  const rodape = scope === "all"
    ? "Removemos seus dados pessoais. Mantivemos apenas os registros financeiros exigidos por lei, sem nome, endereço ou vínculo com você."
    : "Removemos os dados pessoais dessa parte da conta. Mantivemos apenas os registros financeiros exigidos por lei, sem nome, endereço ou vínculo com você.";
  return `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8" /></head>
<body style="margin:0;background:#F8FAFC;font-family:Inter,-apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0F172A;">
  <div style="max-width:600px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;">
    <div style="background:#1E3B70;padding:28px 24px;text-align:center;">
      <h1 style="color:#fff;margin:0;font-size:22px;">Desperrengue</h1>
    </div>
    <div style="padding:28px 24px;">
      <h2 style="margin:0 0 12px;font-size:20px;color:#1E3B70;">Até logo, ${esc(nome)}.</h2>
      <p style="font-size:16px;line-height:1.6;color:#475569;">
        ${intro} Em anexo está o seu
        <strong>Dossiê de Despedida</strong> (PDF) com o histórico de ${esc(l.conta)}: pedidos, orçamentos,
        avaliações, gráficos e totais.
      </p>
      <p style="font-size:14px;line-height:1.6;color:#64748B;">
        ${rodape} Guarde este e-mail: não é possível gerar o dossiê depois.
      </p>
      <p style="font-size:14px;color:#64748B;">Se não foi você, responda a este e-mail imediatamente.</p>
    </div>
    <div style="text-align:center;padding:18px;font-size:12px;color:#94A3B8;border-top:1px solid #F1F5F9;">
      © 2026 Desperrengue. Todos os direitos reservados.
    </div>
  </div>
</body></html>`;
}

/** Remove arquivos em lotes (melhor esforço). */
async function removeAll(bucket: string, paths: string[]): Promise<number> {
  let removed = 0;
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    const { error } = await admin.storage.from(bucket).remove(batch);
    if (error) break;
    removed += batch.length;
  }
  return removed;
}

/** Lista TODOS os nomes (1º nível) da pasta <uid>/ de um bucket, paginando. */
async function listFolder(bucket: string, uid: string): Promise<string[]> {
  const names: string[] = [];
  for (let page = 0; page < 50; page++) {
    const { data, error } = await admin.storage.from(bucket).list(uid, { limit: 100, offset: page * 100 });
    if (error || !data || data.length === 0) break;
    for (const f of data) if (f.name) names.push(f.name);
    if (data.length < 100) break;
  }
  return names;
}

/** Remove TODA a pasta <uid>/ de um bucket (escopo "all" e KYC). */
async function wipeFolder(bucket: string, uid: string): Promise<number> {
  return await removeAll(bucket, (await listFolder(bucket, uid)).map((n) => `${uid}/${n}`));
}

/**
 * Remove, na pasta <uid>/, só os arquivos cujo nome começa com um dos prefixos, mais os
 * caminhos EXATOS devolvidos pela purga (sempre filtrados para a pasta do próprio uid).
 * Na dúvida NÃO apaga: avatar (`avatar_*`) e qualquer prefixo desconhecido ficam.
 */
async function wipeScoped(bucket: string, uid: string, prefixes: string[], exact: unknown): Promise<number> {
  const victims = new Set<string>();
  for (const n of await listFolder(bucket, uid)) {
    if (prefixes.some((p) => n.startsWith(p))) victims.add(`${uid}/${n}`);
  }
  if (Array.isArray(exact)) {
    for (const p of exact) {
      if (typeof p === "string" && p.startsWith(`${uid}/`) && !p.includes("..")) victims.add(p);
    }
  }
  return await removeAll(bucket, [...victims]);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Quem está chamando? (JWT do próprio usuário)
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sessão expirada." }, 401);
  const { data: auth, error: authErr } = await admin.auth.getUser(token);
  const user = auth?.user;
  if (authErr || !user) return json({ error: "Sessão expirada." }, 401);

  // 2. Confirmação explícita + escopo pedido (o id NUNCA vem do corpo)
  const body = await req.json().catch(() => ({}));
  if (body?.confirm !== "EXCLUIR") return json({ error: "Confirmação ausente." }, 400);
  const requested = body?.scope == null ? "all" : String(body.scope).trim().toLowerCase();
  if (!SCOPES.includes(requested)) return json({ error: "Escopo inválido." }, 400);

  const email = user.email;
  if (!email) return json({ error: "Conta sem e-mail para enviar o dossiê." }, 422);

  try {
    // 3. Escopo normalizado no servidor (autoridade final)
    const { data: normalized, error: nErr } = await admin.rpc("_normalize_deletion_scope", {
      p_user: user.id,
      p_scope: requested,
    });
    if (nErr) {
      // 22023 = escopo inválido; P0001 = a conta não tem o papel pedido
      if (nErr.code === "22023" || nErr.code === "P0001") {
        return json({ error: "Escopo inválido para esta conta." }, 400);
      }
      throw nErr;
    }
    const scope = String(normalized) as Scope;
    if (!SCOPES.includes(scope)) throw new Error("escopo");

    // 4. Trava financeira do escopo (a tela já checou; aqui é a autoridade final)
    const { data: st, error: stErr } = await admin.rpc("_deletion_blockers", { p_user: user.id, p_scope: scope });
    if (stErr) throw stErr;
    if (!st?.can_delete) return json({ error: "blocked", status: st }, 409);

    // 5. Dossiê do escopo + PDF em memória (só as contas excluídas)
    const { data: dossier, error: dErr } = await admin.rpc("account_dossier", { p_user: user.id, p_scope: scope });
    if (dErr) throw dErr;
    const roles: string[] = Array.isArray(dossier?.scope_roles) ? dossier.scope_roles.map(String) : [];
    const pdf = await buildDossiePdf(dossier);
    const nome = String(dossier?.name ?? "").trim().split(" ")[0] || "usuário";
    const lb = labels(roles);

    // 6. E-mail (sempre ao e-mail do próprio usuário) — falha aqui NÃO apaga nada
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: FROM,
        to: [email],
        subject: lb.subject,
        html: emailHtml(nome, scope, roles),
        attachments: [{ filename: `dossie-de-despedida-desperrengue-${lb.file}.pdf`, content: toBase64(pdf) }],
      }),
    });
    if (!res.ok) {
      console.error("excluir-conta: Resend", res.status);
      return json({ error: "Não foi possível enviar o dossiê. Nada foi excluído; tente novamente." }, 502);
    }

    // 7. Hard delete do escopo: banco -> storage -> (só "all") autenticação
    const { data: purged, error: pErr } = await admin.rpc("purge_account", { p_user: user.id, p_scope: scope });
    if (pErr) throw pErr;
    const exact = purged?.storage ?? {};

    if (scope === "all") {
      for (const bucket of ["public-media", "job-media", "kyc-documents"]) {
        await wipeFolder(bucket, user.id).catch(() => 0);
      }
    } else if (scope === "client") {
      // Uploads do papel cliente: fotos do pedido (job_*) + provas de chamado e fotos de
      // avaliação listadas pela purga. NÃO apaga avatar nem nada do papel profissional.
      await wipeScoped("job-media", user.id, ["job_"], exact.job_media).catch(() => 0);
      await wipeScoped("public-media", user.id, [], exact.public_media).catch(() => 0);
    } else {
      // Papel profissional: KYC inteiro, portfólio, evidências (ev_*) e fotos de avaliação que ele escreveu.
      // NÃO apaga avatar (avatar_*) nem uploads do papel cliente (job_*, ticket_*).
      await wipeFolder("kyc-documents", user.id).catch(() => 0);
      await wipeScoped("public-media", user.id, ["portfolio_"], exact.public_media).catch(() => 0);
      await wipeScoped("job-media", user.id, ["ev_"], exact.job_media).catch(() => 0);
    }

    let accountRemoved = false;
    if (scope === "all") {
      const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
      if (delErr) throw delErr;
      accountRemoved = true;
    }

    return json({
      deleted: true,
      scope,
      account_removed: accountRemoved,
      jobs_deleted: purged?.jobs_deleted ?? 0,
      jobs_retained: purged?.jobs_retained ?? 0,
    });
  } catch (e) {
    console.error("excluir-conta", e instanceof Error ? e.message : "erro");
    return json({ error: "Não foi possível concluir a exclusão. Tente novamente." }, 500);
  }
});

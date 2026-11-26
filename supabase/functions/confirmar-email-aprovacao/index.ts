// Edge Function: confirmar-email-aprovacao
//
// Destino do botão "Confirmar e Ativar Minha Conta" do e-mail de aprovação.
// É o ÚNICO caminho que libera uma conta nova (Cliente ou Profissional): o app
// nunca confirma sozinho. O link carrega um token aleatório de 256 bits, de uso
// único e 72 h de validade; no banco existe apenas o hash SHA-256 do token.
//
// Fluxo: GET ?t=<token> -> consome o token (RPC service_role) -> redireciona para o
// app (intent:// no Android, desperrengue:// no iOS). O app, que está aguardando na
// tela "Verifique seu e-mail", detecta a confirmação e mostra a tela de boas-vindas.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_SCHEME = Deno.env.get("ONBOARDING_APP_SCHEME") ?? "desperrengue";
const ANDROID_PACKAGE = Deno.env.get("ANDROID_APP_PACKAGE") ??
  "br.com.desperrengue.app";

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const BASE_HEADERS: Record<string, string> = {
  "Cache-Control": "no-store, no-cache, must-revalidate, private, max-age=0",
  "Pragma": "no-cache",
  "Referrer-Policy": "no-referrer",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "X-Content-Type-Options": "nosniff",
};

function plain(status: number, body: string): Response {
  return new Response(body, {
    status,
    headers: { ...BASE_HEADERS, "Content-Type": "text/plain; charset=utf-8" },
  });
}

function redirect(location: string): Response {
  return new Response(null, {
    status: 302,
    headers: { ...BASE_HEADERS, Location: location },
  });
}

// Scanners de e-mail (SafeLinks, Gmail, antivírus) abrem links automaticamente.
// Eles NÃO podem consumir o token: só um navegador de pessoa real confirma.
const SCANNER_UA =
  /(bot|crawler|spider|preview|scanner|safelinks|proofpoint|mimecast|barracuda|googleimageproxy|facebookexternalhit|slackbot|microsoft office|curl\/|wget\/|python-requests|go-http-client|headlesschrome)/i;

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

const DONE_TEXT =
  "Conta confirmada com sucesso!\n\nVolte ao aplicativo Desperrengue: sua conta já está liberada e você será recebido(a) com as boas-vindas.";

Deno.serve(async (req: Request) => {
  if (req.method === "HEAD" || req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: BASE_HEADERS });
  }
  if (req.method !== "GET") return plain(405, "Método não permitido.");

  const url = new URL(req.url);

  // Página final de segurança (fallback quando o aparelho não abre o app).
  if (url.searchParams.get("done") === "1") return plain(200, DONE_TEXT);

  const token = url.searchParams.get("t") ?? "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) {
    return plain(400, "Link inválido. Peça um novo e-mail de aprovação no aplicativo.");
  }

  const userAgent = req.headers.get("user-agent") ?? "";
  if (!userAgent || SCANNER_UA.test(userAgent)) {
    return plain(
      200,
      "Este link é pessoal. Abra-o no seu celular para confirmar sua conta Desperrengue.",
    );
  }

  let result: { ok?: boolean; reason?: string } | null = null;
  try {
    const { data, error } = await supabaseAdmin.rpc("consume_approval_email_token", {
      p_token_hash: await sha256Hex(token),
    });
    if (error) throw error;
    result = data as { ok?: boolean; reason?: string };
  } catch (err) {
    console.error("confirmar-email-aprovacao", err);
    return plain(500, "Não foi possível confirmar agora. Toque no botão do e-mail novamente em instantes.");
  }

  if (!result?.ok) {
    return plain(
      410,
      result?.reason === "expired"
        ? "Este link expirou (validade de 72 horas). Abra o aplicativo Desperrengue e toque em \"Reenviar e-mail de aprovação\"."
        : "Este link é inválido ou não existe mais. Abra o aplicativo Desperrengue e toque em \"Reenviar e-mail de aprovação\".",
    );
  }

  const doneUrl = `${SUPABASE_URL}/functions/v1/confirmar-email-aprovacao?done=1`;
  const deepLink = `${APP_SCHEME}://onboarding/ativado`;

  if (/android/i.test(userAgent)) {
    return redirect(
      `intent://onboarding/ativado#Intent;scheme=${APP_SCHEME};package=${ANDROID_PACKAGE};` +
        `S.browser_fallback_url=${encodeURIComponent(doneUrl)};end`,
    );
  }
  if (/iphone|ipad|ipod/i.test(userAgent)) {
    return redirect(deepLink);
  }
  return redirect(doneUrl);
});

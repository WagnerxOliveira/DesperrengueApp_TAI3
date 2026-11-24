// Edge Function: voice-triage-structurer
//
// Transforma relato falado coloquial (PT-BR) em um briefing tecnico estruturado
// para que o profissional compreenda o problema, local/equipamento, sintomas,
// historico e urgencia em poucos segundos.
//
// Arquitetura 100% Free-Tier (custo zero, falha graciosamente para fallback local):
//   1. Groq Free Tier (`GROQ_API_KEY` -> llama-3.3-70b-versatile, JSON mode)
//   2. Google Gemini Free Tier (`GEMINI_API_KEY` -> gemini-2.5-flash -> gemini-2.0-flash)
//   3. OpenRouter Free Tier (`OPENROUTER_API_KEY` -> llama-3.3-70b-instruct:free)
//   4. Sem chaves configuradas ou rate-limit -> retorna 200 { structured: null }
//
// Seguranca: valida JWT obrigatorio (`admin.auth.getUser(token)`). Nunca inventa
// dados nao presentes na fala do cliente.
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GROQ_API_KEY = (Deno.env.get("GROQ_API_KEY") ?? "").trim();
const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
const OPENROUTER_API_KEY = (Deno.env.get("OPENROUTER_API_KEY") ?? "").trim();

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const SYSTEM_PROMPT = [
  "Você é um engenheiro de triagem residencial do aplicativo Desperrengue (Brasil).",
  "Sua tarefa é estruturar a transcrição de áudio de um cliente em JSON objetivo e cristalino para o profissional prestador de serviço.",
  "REGRAS INVIOLÁVEIS:",
  "1. JAMAIS invente peças, medidas, marcas, datas ou fatos que o cliente NÃO disse. Se algo não foi mencionado, retorne null ou lista vazia [].",
  "2. Remova gagueiras, saudações ('oi', 'boa noite', 'tudo bem'), vícios de fala e repetições, mantendo 100% dos fatos técnicos.",
  "3. Corrija erros óbvios de transcrição de voz no contexto residencial (ex.: 'disjutor' -> 'disjuntor', 'lorenzete' -> 'Lorenzetti', '220 volts' -> '220V', 'cifao' -> 'sifão').",
  "4. Responda EXCLUSIVAMENTE com um objeto JSON válido com estas chaves:",
  "{",
  '  "headline": "Título técnico curto até 60 chars",',
  '  "problem_summary": "1 frase objetiva descrevendo o problema principal",',
  '  "location_and_equipment": "Cômodo, equipamento, marca e especificação citados (ou null)",',
  '  "observed_symptoms": ["Lista curta de 1 a 5 sintomas objetivos relatados"],',
  '  "timeline_and_context": "Quando começou ou gatilho citado (ou null)",',
  '  "client_actions_or_notes": "O que o cliente já fez ou restrições citadas (ou null)",',
  '  "urgency_and_availability": "Urgência ou janela de horário solicitada (ou null)",',
  '  "suggested_category": "Encanador | Eletricista | Ar-Condicionado | Chaveiro | Pintor | Telhado / Calha | Pedreiro | Montador | Marido de Aluguel (ou null)",',
  '  "safety_risk": "none | attention | critical"',
  "}",
].join("\n");

function buildUserPrompt(
  transcript: string,
  categoryHint: string | null,
  photoNotes: string[],
): string {
  const parts = [`Transcrição do cliente:\n"""${transcript}"""`];
  if (categoryHint) {
    parts.push(`Categoria selecionada no app: ${categoryHint}`);
  }
  if (photoNotes.length > 0) {
    parts.push(`Legendas de fotos enviadas: ${photoNotes.join(" | ")}`);
  }
  parts.push("Retorne apenas o JSON estruturado em português do Brasil.");
  return parts.join("\n\n");
}

function normalizeJsonCandidate(rawText: string): Record<string, unknown> | null {
  const trimmed = rawText.trim();
  if (!trimmed) return null;
  const cleaned = trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  try {
    const parsed = JSON.parse(cleaned);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      const rec = parsed as Record<string, unknown>;
      if (typeof rec.problem_summary === "string" && rec.problem_summary.trim().length > 0) {
        return rec;
      }
    }
  } catch {
    const firstBrace = cleaned.indexOf("{");
    const lastBrace = cleaned.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        const sub = JSON.parse(cleaned.slice(firstBrace, lastBrace + 1));
        if (sub && typeof sub === "object" && !Array.isArray(sub)) {
          return sub as Record<string, unknown>;
        }
      } catch {
        return null;
      }
    }
  }
  return null;
}

async function callGroq(prompt: string): Promise<Record<string, unknown> | null> {
  if (!GROQ_API_KEY) return null;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 4500);
  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      signal: ctrl.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        temperature: 0.1,
        max_tokens: 480,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return null;
    return normalizeJsonCandidate(content);
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function callGeminiModel(
  model: string,
  prompt: string,
): Promise<Record<string, unknown> | null> {
  if (!GEMINI_API_KEY) return null;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 5000);
  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`;
    const generationConfig: Record<string, unknown> = {
      temperature: 0.1,
      maxOutputTokens: 600,
      responseMimeType: "application/json",
    };
    if (model.includes("2.5")) {
      generationConfig.thinkingConfig = { thinkingBudget: 0 };
    }
    const res = await fetch(url, {
      method: "POST",
      signal: ctrl.signal,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") return null;
    return normalizeJsonCandidate(text);
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function callOpenRouter(prompt: string): Promise<Record<string, unknown> | null> {
  if (!OPENROUTER_API_KEY) return null;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 5000);
  try {
    const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      signal: ctrl.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      },
      body: JSON.stringify({
        model: "meta-llama/llama-3.3-70b-instruct:free",
        temperature: 0.1,
        max_tokens: 480,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return null;
    return normalizeJsonCandidate(content);
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sessão expirada." }, 401);
  const { data: auth, error: authErr } = await admin.auth.getUser(token);
  if (authErr || !auth?.user) return json({ error: "Sessão expirada." }, 401);

  const body = await req.json().catch(() => ({}));
  const transcript = typeof body?.transcript === "string" ? body.transcript.trim() : "";
  if (transcript.length < 4 || transcript.length > 4000) {
    return json({ structured: null, provider: "local_fallback" });
  }
  const categoryHint = typeof body?.category_hint === "string" && body.category_hint.trim().length > 0
    ? body.category_hint.trim().slice(0, 80)
    : null;
  const photoNotes = Array.isArray(body?.photo_notes)
    ? body.photo_notes.filter((x: unknown): x is string => typeof x === "string" && x.trim().length > 0).slice(0, 4)
    : [];

  const prompt = buildUserPrompt(transcript, categoryHint, photoNotes);

  const groq = await callGroq(prompt);
  if (groq) return json({ structured: groq, provider: "ai_groq" });

  const gemini25 = await callGeminiModel("gemini-2.5-flash", prompt);
  if (gemini25) return json({ structured: gemini25, provider: "ai_gemini" });

  const gemini20 = await callGeminiModel("gemini-2.0-flash", prompt);
  if (gemini20) return json({ structured: gemini20, provider: "ai_gemini" });

  const openrouter = await callOpenRouter(prompt);
  if (openrouter) return json({ structured: openrouter, provider: "ai_openrouter" });

  return json({ structured: null, provider: "local_fallback" });
});

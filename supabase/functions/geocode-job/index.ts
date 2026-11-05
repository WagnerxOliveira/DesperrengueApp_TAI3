// Edge Function: geocode-job
//
// Resolve (e guarda em cache) as coordenadas do endereço de um serviço, para que o servidor possa
// validar o geofence de 100 m em `start_job`. Usa o Nominatim (OpenStreetMap), 100 % gratuito.
//
// Segurança:
//  * o JWT do usuário é validado AQUI (admin.auth.getUser) — só o cliente dono ou o profissional
//    contratado do serviço podem pedir;
//  * o endereço completo é lido por service_role (job_addresses é privado) e NUNCA devolvido;
//    a resposta traz só o resultado da geocodificação (lat/lng/qualidade);
//  * se o cliente já confirmou o pino (`client_pin`) ou o pedido já tem coordenadas, nada é sobrescrito.
//
// Política de uso do Nominatim (https://operations.osmfoundation.org/policies/nominatim/):
//  User-Agent identificável, no máx. 1 req/s e cache — o resultado fica em `job_geo` (1 consulta/serviço).
//
// Qualidade: `house` (número da casa achado) · `street` (só a rua) · `locality` (só bairro/cidade).
// `locality` NÃO serve para validar presença (raio 0): o cliente precisa confirmar o pino no mapa.
import { createClient } from "@supabase/supabase-js";

const UA = "Desperrengue/1.0 (suporte@desperrengue.tech)";
const admin = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

type Level = "house" | "street" | "locality";
type Hit = { lat: number; lng: number; level: Level; display: string };

/** "Rua X, 203 - Bairro, Cidade - MG" -> partes para montar consultas do mais para o menos específico. */
export function parseAddress(line: string, summary: string | null) {
  const parts = line.split(" - ").map((s) => s.trim()).filter(Boolean);
  const first = (parts[0] ?? line).trim(); // "Rua X, 203"
  const [streetRaw, numberRaw] = first.split(",").map((s) => s.trim());
  let place = (parts[1] ?? "").trim(); // "Bairro, Cidade"
  let uf = (parts[2] ?? "").trim();
  if (!place && summary) {
    // Sem o trecho "Bairro, Cidade" na linha: usa o resumo público ("Bairro, Cidade - UF").
    const s = summary.split(" - ").map((x) => x.trim());
    place = s[0] ?? "";
    uf = uf || (s[1] ?? "");
  }
  const placeBits = place.split(",").map((s) => s.trim()).filter(Boolean);
  const city = placeBits.length > 1 ? placeBits[placeBits.length - 1] : (placeBits[0] ?? "");
  const hood = placeBits.length > 1 ? placeBits[0] : "";
  const number = (numberRaw ?? "").match(/\d+/)?.[0] ?? "";
  return { street: streetRaw ?? first, number, hood, city, uf };
}

export function buildQueries(a: ReturnType<typeof parseAddress>): string[] {
  const tail = [a.city, a.uf, "Brasil"].filter(Boolean).join(", ");
  const q: string[] = [];
  if (a.number) q.push(`${a.street} ${a.number}, ${a.hood ? a.hood + ", " : ""}${tail}`);
  q.push(`${a.street}, ${a.hood ? a.hood + ", " : ""}${tail}`);
  if (a.hood) q.push(`${a.hood}, ${tail}`);
  if (a.city) q.push(tail);
  return [...new Set(q)];
}

function levelOf(r: Record<string, unknown>): Level {
  const addr = (r.address ?? {}) as Record<string, string>;
  if (addr.house_number) return "house";
  const at = String(r.addresstype ?? "");
  if (r.class === "highway" || ["road", "residential", "pedestrian", "footway", "path", "street"].includes(at)) return "street";
  return "locality";
}

async function nominatim(q: string): Promise<Hit | null> {
  const u = new URL("https://nominatim.openstreetmap.org/search");
  u.search = new URLSearchParams({ format: "jsonv2", limit: "1", addressdetails: "1", countrycodes: "br", q }).toString();
  const res = await fetch(u, { headers: { "User-Agent": UA, "Accept-Language": "pt-BR" } });
  if (!res.ok) return null;
  const arr = await res.json().catch(() => []);
  const r = Array.isArray(arr) ? arr[0] : null;
  if (!r) return null;
  const lat = Number(r.lat), lng = Number(r.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng, level: levelOf(r), display: String(r.display_name ?? "") };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: u } = await admin.auth.getUser(token);
  const uid = u?.user?.id;
  if (!uid) return json({ error: "Unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const jobId = typeof body?.job_id === "string" ? body.job_id : "";
  if (!/^[0-9a-f-]{36}$/i.test(jobId)) return json({ error: "job_id inválido" }, 400);

  const { data: job } = await admin.from("jobs")
    .select("id, client_id, provider_id, latitude, longitude, address_summary").eq("id", jobId).maybeSingle();
  if (!job || (job.client_id !== uid && job.provider_id !== uid)) return json({ error: "Forbidden" }, 403);

  const { data: cached } = await admin.from("job_geo").select("lat, lng, precision_level, source").eq("job_id", jobId).maybeSingle();
  if (cached) return json({ ok: true, cached: true, source: cached.source, precision: cached.precision_level });
  if (job.latitude != null && job.longitude != null) return json({ ok: true, cached: true, source: "client", precision: "exact" });

  const { data: addr } = await admin.from("job_addresses").select("address_line").eq("job_id", jobId).maybeSingle();
  const line = (addr?.address_line ?? "").trim();
  if (!line) return json({ ok: false, reason: "no_address" });

  let best: Hit | null = null;
  const queries = buildQueries(parseAddress(line, job.address_summary));
  for (let i = 0; i < queries.length; i++) {
    if (i > 0) await sleep(1100); // <= 1 req/s (política do Nominatim)
    const hit = await nominatim(queries[i]).catch(() => null);
    if (hit) { best = hit; break; }
  }
  if (!best) return json({ ok: false, reason: "not_found" });

  // Nunca sobrescreve um pino do cliente que tenha chegado enquanto geocodificávamos.
  const { error } = await admin.from("job_geo").upsert(
    { job_id: jobId, lat: best.lat, lng: best.lng, precision_level: best.level, source: "nominatim", display_name: best.display.slice(0, 200) },
    { onConflict: "job_id", ignoreDuplicates: true },
  );
  if (error) return json({ ok: false, reason: "db" }, 500);
  return json({ ok: true, cached: false, source: "nominatim", precision: best.level });
});

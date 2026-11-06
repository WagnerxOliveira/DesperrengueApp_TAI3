// Teste do Dossiê de Despedida (PDF) em Node, sem Deno nem rede além do npm.
//   node scripts/test-dossie.mjs
// Copia dossie.ts para uma pasta temporária com `pdf-lib` instalado (o arquivo usa
// import "pdf-lib", resolvido pelo import map no Deno e por node_modules aqui).
// Requer Node >= 22.6 (importa o .ts direto, com remoção de tipos).
//
// Cobre: escopos client / provider / all, gráficos COM e SEM dados, 12 meses, texto
// com emoji/acentos, 200+ linhas (paginação), PDF que reabre e conteúdo por escopo
// (o texto das páginas é extraído do próprio PDF).
// Variáveis: SAMPLES_DIR = pasta onde salvar os PDFs de amostra (padrão: a pasta temporária).
import { execSync } from "node:child_process";
import { copyFileSync, mkdtempSync, writeFileSync, mkdirSync } from "node:fs";
import { inflateSync } from "node:zlib";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const tmp = mkdtempSync(join(tmpdir(), "dossie-"));
writeFileSync(join(tmp, "package.json"), JSON.stringify({ name: "t", type: "module", private: true }));
execSync("npm install pdf-lib@1.17.1 --silent --no-audit --no-fund", { cwd: tmp, stdio: "inherit" });
copyFileSync(join(root, "supabase/functions/excluir-conta/dossie.ts"), join(tmp, "dossie.ts"));

const m = await import(pathToFileURL(join(tmp, "dossie.ts")).href);
const require = createRequire(join(tmp, "x.js"));
const { PDFDocument, PDFName, PDFRawStream, PDFDict } = require("pdf-lib");
const samplesDir = process.env.SAMPLES_DIR || tmp;
mkdirSync(samplesDir, { recursive: true });

let ok = 0;
const t = (name, fn) => { fn(); ok++; console.log("ok   ", name); };
const ta = async (name, fn) => { await fn(); ok++; console.log("ok   ", name); };

/** Texto desenhado em todas as páginas (extraído do PDF: Tj em hex, WinAnsi ~ latin1). */
async function pdfText(bytes) {
  const doc = await PDFDocument.load(bytes);
  let out = "";
  for (const [, obj] of doc.context.enumerateIndirectObjects()) {
    if (!(obj instanceof PDFRawStream)) continue;
    const filter = obj.dict.get(PDFName.of("Filter"));
    let data = obj.getContents();
    if (filter && String(filter).includes("FlateDecode")) {
      try { data = inflateSync(data); } catch { continue; }
    }
    const s = Buffer.from(data).toString("latin1");
    if (!s.includes("Tj")) continue;
    for (const mt of s.matchAll(/<([0-9A-Fa-f]+)>\s*Tj/g)) {
      out += Buffer.from(mt[1], "hex").toString("latin1") + "\n";
    }
  }
  return out;
}
const pages = async (bytes) => (await PDFDocument.load(bytes)).getPageCount();

// ------------------------------------------------------------------ utilidades
t("formatBRL: milhar, centavos, negativo e lixo", () => {
  assert.equal(m.formatBRL(1234.5), "R$ 1.234,50");
  assert.equal(m.formatBRL(0), "R$ 0,00");
  assert.equal(m.formatBRL(1234567.891), "R$ 1.234.567,89");
  assert.equal(m.formatBRL(-5), "-R$ 5,00");
  assert.equal(m.formatBRL(null), "R$ 0,00");
  assert.equal(m.formatBRL("abc"), "R$ 0,00");
});
t("formatDate: dd/mm/aaaa e entradas inválidas", () => {
  assert.equal(m.formatDate("2026-10-29T12:00:00Z"), "29/10/2026");
  assert.equal(m.formatDate(null), "-");
  assert.equal(m.formatDate("lixo"), "-");
});
t("statusPt traduz status (inclui scheduled) e preserva desconhecidos", () => {
  assert.equal(m.statusPt("completed"), "Concluído");
  assert.equal(m.statusPt("scheduled"), "Agendado");
  assert.equal(m.statusPt("xyz"), "xyz");
  assert.equal(m.statusPt(null), "-");
});
t("toBase64 de PDF grande (sem estourar a pilha) é reversível", () => {
  const big = new Uint8Array(600_000).map((_, i) => i % 251);
  assert.deepEqual(new Uint8Array(Buffer.from(m.toBase64(big), "base64")), big);
});
await ta("safeText troca emoji/CJK por '?' e mantém acentos", async () => {
  const doc = await PDFDocument.create();
  const f = await doc.embedFont("Helvetica");
  assert.equal(m.safeText(f, "açúcar 😀 日本"), "açúcar ? ??");
  assert.equal(m.safeText(f, null), "");
  assert.equal(m.safeText(f, "a\nb\tc"), "a b c");
});

// ------------------------------------------------------------------ fixtures
const months12 = (f) => {
  // 12 meses terminando em 2026-10
  const out = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(Date.UTC(2026, 9 - i, 1));
    out.push({ month: `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`, ...f(11 - i) });
  }
  return out;
};
const CATS = ["Elétrica", "Hidráulica", "Pintura", "Montagem", "Limpeza", "Jardinagem"];
const TITLES = ["Troca de tomada ☺ açúcar, coração", "Chuveiro 🚿 novo", "Pintar quarto — 2 demãos", "Montar guarda-roupa", "日本語 título estranho"];

function clientSection(nOrders = 12) {
  const orders = Array.from({ length: nOrders }, (_, i) => {
    const done = i % 4 !== 3;
    const quotes = i % 3 === 0 ? 3 : 1;
    const price = 120 + i * 7;
    const avg = quotes >= 2 ? price + 40 + i : null;
    return {
      id: `AB${String(i).padStart(6, "0")}`, title: `${TITLES[i % TITLES.length]} ${i} ${"x".repeat(i % 30)}`, category: CATS[i % CATS.length],
      status: done ? "completed" : i % 8 === 3 ? "canceled" : "open", created_at: "2026-09-01T10:00:00Z",
      scheduled_for: "2026-09-02T14:00:00Z", started_at: "2026-09-02T14:10:00Z", finished_at: "2026-09-02T16:00:00Z",
      partner: "Ana S.", price, paid: done ? price : null, payment_status: done ? "released" : null,
      quotes_received: quotes, avg_other_quotes: avg, saved: done && avg ? avg - price : 0,
    };
  });
  const spent = orders.reduce((a, o) => a + (o.paid ?? 0), 0);
  const saved = orders.reduce((a, o) => a + o.saved, 0);
  const done = orders.filter((o) => o.status === "completed").length;
  return {
    orders, orders_count: nOrders, total_spent: spent, total_saved: saved, completed_count: done, paid_count: done,
    ticket_medio: done ? spent / done : 0,
    monthly: months12((i) => ({ spent: i === 5 ? 0 : 100 + i * 90, saved: i % 3 === 0 ? 0 : 20 + i * 8, orders: i % 4 })),
    by_category: CATS.map((c, i) => ({ category: c, orders: 5 - (i % 4), spent: 900 - i * 120 })),
    by_status: { completed: done, open: 2, canceled: 1 },
    reviews_given: { count: 4, avg: 4.5 }, wallet: { total: 350, count: 3 },
  };
}
function providerSection(nJobs = 10) {
  const jobs = Array.from({ length: nJobs }, (_, i) => {
    const gross = 200 + i * 15;
    return {
      id: `EF${String(i).padStart(6, "0")}`, title: `${TITLES[i % TITLES.length]} ${i}`, category: CATS[i % CATS.length],
      status: i % 5 === 4 ? "canceled" : "completed", created_at: "2026-08-10T10:00:00Z", scheduled_for: "2026-08-12T10:00:00Z",
      started_at: "2026-08-12T10:05:00Z", finished_at: "2026-08-12T12:00:00Z", partner: "Bruno C.", price: gross,
      gross, fee: gross * 0.12, net: gross * 0.88, payment_status: "released",
    };
  });
  const gross = jobs.reduce((a, j) => a + j.gross, 0);
  return {
    jobs, jobs_count: nJobs, completed_count: nJobs - Math.floor(nJobs / 5), total_gross: gross, total_fee: gross * 0.12, total_profit: gross * 0.88,
    total_withdrawn: gross * 0.5,
    monthly: months12((i) => ({ gross: 300 + i * 150, net: 264 + i * 132, fee: 36 + i * 18, jobs: 1 + (i % 3) })),
    by_category: CATS.map((c, i) => ({ category: c, jobs: 4 - (i % 3), gross: 800 - i * 90, net: 700 - i * 80 })),
    quotes: Array.from({ length: 6 }, (_, i) => ({ job: `AB12CD0${i}`, title: "Chuveiro", price: 99.9 + i, status: i % 2 ? "accepted" : "rejected", created_at: "2026-09-01T10:00:00Z" })),
    quotes_total: 6, quotes_accepted: 3, acceptance_rate: 50,
    reviews: [
      { job: "AB12CD00", rating: 5, comment: "Excelente profissional, muito educado e pontual! 😀 " + "texto longo ".repeat(20), created_at: "2026-09-02T10:00:00Z" },
      { job: "AB12CD01", rating: 4, comment: null, created_at: "2026-09-03T10:00:00Z" },
    ],
    reviews_count: 12, rating_avg: 4.58, rating_dist: { 1: 0, 2: 1, 3: 1, 4: 3, 5: 7 }, achievements_count: 3,
    withdrawals: Array.from({ length: 3 }, (_, i) => ({ created_at: "2026-09-10T10:00:00Z", amount: 100 + i, status: "simulated_paid", pix_key_type: "cpf", pix_key_hint: "***8901" })),
  };
}
const emptyClient = () => ({
  orders: [], orders_count: 0, total_spent: 0, total_saved: 0, completed_count: 0, paid_count: 0, ticket_medio: 0,
  monthly: months12(() => ({ spent: 0, saved: 0, orders: 0 })), by_category: [], by_status: {}, reviews_given: { count: 0, avg: 0 }, wallet: { total: 0, count: 0 },
});
const emptyProvider = () => ({
  jobs: [], jobs_count: 0, completed_count: 0, total_gross: 0, total_fee: 0, total_profit: 0, total_withdrawn: 0,
  monthly: months12(() => ({ gross: 0, net: 0, fee: 0, jobs: 0 })), by_category: [], quotes: [], quotes_total: 0, quotes_accepted: 0, acceptance_rate: 0,
  reviews: [], reviews_count: 0, rating_avg: 0, rating_dist: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }, achievements_count: 0, withdrawals: [],
});
const base = { generated_at: "2026-10-29T12:00:00Z", name: "Wagner Oliveira 😀", member_since: "2026-01-02T00:00:00Z" };
const dClient = (c = clientSection()) => ({ ...base, scope: "client", scope_roles: ["client"], is_client: true, is_provider: true, client: c, totals: { spent: c.total_spent, saved: c.total_saved, profit: 0 } });
const dProvider = (p = providerSection()) => ({ ...base, scope: "provider", scope_roles: ["provider"], is_client: true, is_provider: true, provider: p, totals: { spent: 0, saved: 0, profit: p.total_profit } });
const dAll = (c = clientSection(), p = providerSection()) => ({ ...base, scope: "all", scope_roles: ["client", "provider"], is_client: true, is_provider: true, client: c, provider: p, totals: { spent: c.total_spent, saved: c.total_saved, profit: p.total_profit } });

const isPdf = (b) => Buffer.from(b.subarray(0, 5)).toString("latin1") === "%PDF-";

// ------------------------------------------------------------------ escopos
const pdfClient = await m.buildDossiePdf(dClient());
const pdfProvider = await m.buildDossiePdf(dProvider());
const pdfAll = await m.buildDossiePdf(dAll());
const txtClient = await pdfText(pdfClient);
const txtProvider = await pdfText(pdfProvider);
const txtAll = await pdfText(pdfAll);

await ta("escopo CLIENTE: PDF válido, várias páginas e só conteúdo de cliente", async () => {
  assert.ok(isPdf(pdfClient));
  assert.ok((await pages(pdfClient)) >= 2);
  assert.match(txtClient, /Conta de Cliente/);
  assert.match(txtClient, /Pedidos como cliente/);
  assert.match(txtClient, /Gasto e economia por m/);
  assert.match(txtClient, /Gasto por categoria/);
  assert.match(txtClient, /Economia por pedido/);
  assert.match(txtClient, /Total economizado/);
  assert.match(txtClient, /Ticket m/);
  assert.doesNotMatch(txtClient, /Servi.os como profissional/);
  assert.doesNotMatch(txtClient, /Lucro l.quido/);
  assert.match(txtClient, /conta de profissional continua ativa/);
});
await ta("escopo PROFISSIONAL: PDF válido e só conteúdo de profissional", async () => {
  assert.ok(isPdf(pdfProvider));
  assert.ok((await pages(pdfProvider)) >= 2);
  assert.match(txtProvider, /Conta de Profissional/);
  assert.match(txtProvider, /Servi.os como profissional/);
  assert.match(txtProvider, /Lucro l.quido por m/);
  assert.match(txtProvider, /Distribui..o das notas recebidas/);
  assert.match(txtProvider, /Taxa de aceita..o/);
  assert.match(txtProvider, /Saques \(3\)/);
  assert.doesNotMatch(txtProvider, /Pedidos como cliente/);
  assert.doesNotMatch(txtProvider, /Total economizado/);
  assert.match(txtProvider, /conta de cliente continua ativa/);
});
await ta("escopo ALL (dois papéis): as duas partes no mesmo PDF e título combinado", async () => {
  assert.ok(isPdf(pdfAll));
  assert.match(txtAll, /Contas de Cliente e Profissional/);
  assert.match(txtAll, /Pedidos como cliente/);
  assert.match(txtAll, /Servi.os como profissional/);
  assert.match(txtAll, /conta foi exclu.da por inteiro/);
  assert.doesNotMatch(txtAll, /continua ativa/);
  assert.ok((await pages(pdfAll)) > (await pages(pdfClient)), "all deve ter mais páginas que só cliente");
});
await ta("paginação: rodapé 'Página X de Y' em todas as páginas e cabeçalho repetido", async () => {
  const n = await pages(pdfAll);
  for (let i = 1; i <= n; i++) assert.ok(txtAll.includes(`P\xe1gina ${i} de ${n}`), `faltou rodapé da página ${i}/${n}`);
  const repeats = txtAll.split("Desperrengue \xb7 ").length; // não usado como contagem exata
  assert.ok(txtAll.includes("Dossi\xea de Despedida \xb7 Contas de Cliente e Profissional"), "cabeçalho repetido");
  assert.ok(repeats >= 1);
});
await ta("'all' de conta de um papel só: título do papel e conta removida por inteiro", async () => {
  const d = { ...dClient(), scope: "all" };
  const tx = await pdfText(await m.buildDossiePdf(d));
  assert.match(tx, /Conta de Cliente/);
  assert.match(tx, /conta foi exclu.da por inteiro/);
  assert.doesNotMatch(tx, /Servi.os como profissional/);
});

// ------------------------------------------------------------------ gráficos sem dados
await ta("SEM dados (arrays vazios, 12 meses zerados): todos os escopos geram PDF e mostram estado vazio", async () => {
  for (const [nome, d] of [["client", dClient(emptyClient())], ["provider", dProvider(emptyProvider())], ["all", dAll(emptyClient(), emptyProvider())]]) {
    const b = await m.buildDossiePdf(d);
    assert.ok(isPdf(b), nome);
    assert.ok((await pages(b)) >= 1, nome);
    const tx = await pdfText(b);
    assert.match(tx, /Sem movimento no per.odo/, nome);
    assert.match(tx, /Sem dados no per.odo/, nome);
    assert.match(tx, /Nenhum/, nome);
  }
  const tx = await pdfText(await m.buildDossiePdf(dProvider(emptyProvider())));
  assert.match(tx, /Nenhuma avalia..o recebida/);
});
await ta("dados NULOS/ausentes (objeto mínimo, formato antigo sem scope_roles) não quebram", async () => {
  const minimal = await m.buildDossiePdf({ name: "S\xf3 Cliente", is_client: true, is_provider: false, client: { orders: [] }, totals: {} });
  assert.ok(isPdf(minimal) && minimal.length > 1500);
  const nulls = await m.buildDossiePdf({ scope_roles: ["client", "provider"], client: { orders: null, monthly: null, by_category: null, by_status: null, reviews_given: null, wallet: null },
    provider: { jobs: null, quotes: null, reviews: null, withdrawals: null, rating_dist: null, monthly: null, by_category: null }, totals: null });
  assert.ok(isPdf(nulls));
  const vazio = await m.buildDossiePdf(null);
  assert.ok(isPdf(vazio));
  const antigo = await m.buildDossiePdf({ ...base, is_client: true, is_provider: true,
    client: { orders: [{ id: "A", title: "x", status: "completed", paid: 10 }], total_spent: 10, total_saved: 0 },
    provider: { jobs: [{ id: "B", title: "y", net: 5 }], total_gross: 6, total_fee: 1, total_profit: 5, total_withdrawn: 0, quotes: [], reviews: [] },
    totals: { spent: 10, saved: 0, profit: 5 } });
  const tx = await pdfText(antigo);
  assert.match(tx, /Contas de Cliente e Profissional/);
});
await ta("valores extremos/estranhos (negativos, NaN, strings, muito grandes) não quebram os gráficos", async () => {
  const c = clientSection(3);
  c.monthly = months12((i) => ({ spent: i === 2 ? -50 : i === 3 ? "abc" : i === 4 ? NaN : 99999999, saved: undefined, orders: null }));
  const p = providerSection(3);
  p.monthly = months12((i) => ({ net: i === 0 ? 1e12 : 0.004 }));
  p.rating_dist = { 5: "x", 4: -3 };
  const b = await m.buildDossiePdf(dAll(c, p));
  assert.ok(isPdf(b));
});

// ------------------------------------------------------------------ 12 meses, texto e paginação
await ta("12 meses: gráfico mensal com os 12 rótulos (mês/ano) no PDF", async () => {
  for (const lab of ["nov/25", "dez/25", "jan/26", "fev/26", "mar/26", "abr/26", "mai/26", "jun/26", "jul/26", "ago/26", "set/26", "out/26"]) {
    assert.ok(txtClient.includes(lab), `faltou o rótulo ${lab}`);
  }
});
await ta("emoji, CJK e acentos nos títulos/comentários/nome não quebram e aparecem como '?'", async () => {
  assert.match(txtClient, /Troca de tomada/);
  assert.match(txtClient, /a\xe7\xfacar|a.{1,2}car/);
  assert.ok(!txtAll.includes("\u{1F600}"));
});
const big = dAll(clientSection(230), providerSection(210));
big.provider.quotes = Array.from({ length: 220 }, (_, i) => ({ job: `Q${i}`, title: `Orçamento ${i}`, price: 50 + i, status: i % 3 ? "pending" : "accepted", created_at: "2026-09-01T10:00:00Z" }));
big.provider.reviews = Array.from({ length: 210 }, (_, i) => ({ job: `R${i}`, rating: 1 + (i % 5), comment: `Comentário ${i} ${"palavra ".repeat(30)}`, created_at: "2026-09-01T10:00:00Z" }));
const pdfBig = await m.buildDossiePdf(big);
const txtBig = await pdfText(pdfBig);
await ta("200+ linhas por tabela: paginação correta, cabeçalho de tabela repetido e rodapé em todas as páginas", async () => {
  const n = await pages(pdfBig);
  assert.ok(n >= 12, `esperava >= 12 páginas, veio ${n}`);
  for (let i = 1; i <= n; i++) assert.ok(txtBig.includes(`P\xe1gina ${i} de ${n}`), `rodapé ${i}/${n}`);
  for (const last of ["AB000229", "EF000209", "Q219", "R209"]) assert.ok(txtBig.includes(last), `a última linha (${last}) foi desenhada`);
  assert.ok(txtBig.split("Servi\xe7o").length > 6, "cabeçalhos de tabela repetidos");
});
await ta("nenhuma tabela estoura a margem: PDF abre (PDFDocument.load) e todas as páginas têm tamanho A4", async () => {
  const doc = await PDFDocument.load(pdfBig);
  for (const p of doc.getPages()) {
    const { width, height } = p.getSize();
    assert.ok(Math.abs(width - 595.28) < 0.01 && Math.abs(height - 841.89) < 0.01);
  }
});

// ------------------------------------------------------------------ amostras
const samples = {
  "dossie-cliente.pdf": pdfClient, "dossie-profissional.pdf": pdfProvider, "dossie-ambos.pdf": pdfAll,
  "dossie-cliente-vazio.pdf": await m.buildDossiePdf(dClient(emptyClient())),
  "dossie-profissional-vazio.pdf": await m.buildDossiePdf(dProvider(emptyProvider())),
  "dossie-ambos-200-linhas.pdf": pdfBig,
};
for (const [nome, bytes] of Object.entries(samples)) writeFileSync(join(samplesDir, nome), bytes);
console.log(`\n${ok} testes OK · amostras em ${samplesDir}`);
for (const [nome, bytes] of Object.entries(samples)) console.log(`  ${nome}  ${bytes.length} bytes  ${await pages(bytes)} pág.`);

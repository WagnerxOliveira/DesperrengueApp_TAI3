// Dossiê de Despedida: gera o PDF em memória (sem disco, sem navegador).
//
// Decisão técnica: `pdf-lib` (JS puro) em vez de Puppeteer. Edge Functions não
// trazem Chromium (cold start e pacote gigantes); pdf-lib sobe em milissegundos,
// é determinístico e testável em Node. Todo o visual (capa, cartões de KPI e
// GRÁFICOS) é desenhado com primitivas vetoriais do pdf-lib: nenhuma imagem externa.
//
// O PDF cobre SÓ o escopo excluído (`d.scope_roles`): conta de Cliente, de
// Profissional, ou as duas partes. Tudo é tolerante a dados vazios/nulos e a texto
// fora do WinAnsi (`safeText`). Sem Intl.
//
// Segurança/LGPD: o PDF contém SÓ dados do próprio titular; a contraparte
// aparece por nome curto ("Ana S.") — minimização de dado de terceiros.
import { PDFDocument, PDFFont, PDFPage, rgb, StandardFonts } from "pdf-lib";

export type Json = Record<string, any>;

// ---------------------------------------------------------------- paleta
const NAVY = rgb(0.118, 0.231, 0.439); // #1E3B70
const ORANGE = rgb(0.949, 0.42, 0.059); // #F26B0F (cliente)
const BLUE = rgb(0.106, 0.227, 0.471); // #1B3A78 (profissional)
const BLUE_L = rgb(0.357, 0.553, 0.878); // #5B8DE0
const GREEN = rgb(0.184, 0.714, 0.486); // #2FB67C
const INK = rgb(0.07, 0.09, 0.15);
const MUTED = rgb(0.42, 0.45, 0.5);
const LINE = rgb(0.88, 0.9, 0.92);
const SOFT = rgb(0.94, 0.96, 0.99);
const ZEBRA = rgb(0.975, 0.98, 0.99);
const WHITE = rgb(1, 1, 1);
const AMBER = rgb(0.96, 0.69, 0.1);
const RED = rgb(0.86, 0.25, 0.25);

const PAGE_W = 595.28; // A4
const PAGE_H = 841.89;
const MARGIN = 44;
const CONTENT_W = PAGE_W - MARGIN * 2;
const FOOTER_Y = 24;
const BOTTOM = MARGIN + 18;

// ---------------------------------------------------------------- formatação
/** R$ 1.234,56 (sem depender de Intl no runtime). */
export function formatBRL(v: unknown): string {
  const n = Number(v ?? 0);
  const x = Number.isFinite(n) ? n : 0;
  const neg = x < 0;
  const [int, dec] = Math.abs(x).toFixed(2).split(".");
  return `${neg ? "-" : ""}R$ ${int.replace(/\B(?=(\d{3})+(?!\d))/g, ".")},${dec}`;
}

export function formatDate(v: unknown): string {
  if (!v) return "-";
  const d = new Date(String(v));
  if (Number.isNaN(d.getTime())) return "-";
  const p = (x: number) => String(x).padStart(2, "0");
  return `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`;
}

const STATUS_PT: Record<string, string> = {
  open: "Aberto", awaiting_payment: "Aguardando pagamento", scheduled: "Agendado", in_progress: "Em andamento",
  awaiting_approval: "Aguardando aprovação", completed: "Concluído", canceled: "Cancelado",
  disputed: "Em mediação", pending: "Pendente", accepted: "Aceito", rejected: "Recusado",
  withdrawn: "Retirado", escrow: "Em custódia", released: "Liberado", refunded: "Reembolsado",
  simulated_paid: "Pago", paid: "Pago", failed: "Falhou",
};
export const statusPt = (s: unknown) => STATUS_PT[String(s ?? "")] ?? String(s ?? "-");

/** Mantém só caracteres que a fonte padrão (WinAnsi) consegue desenhar. */
export function safeText(font: PDFFont, text: unknown): string {
  const set = new Set(font.getCharacterSet());
  let out = "";
  for (const ch of String(text ?? "").replace(/[\r\n\t]+/g, " ")) {
    out += set.has(ch.codePointAt(0)!) ? ch : "?";
  }
  return out;
}

const num = (v: unknown): number => {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? n : 0;
};
const arr = (v: unknown): Json[] => (Array.isArray(v) ? (v as Json[]) : []);
const obj = (v: unknown): Json => (v && typeof v === "object" && !Array.isArray(v) ? (v as Json) : {});

const MONTHS = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];
/** 'YYYY-MM' -> 'out/26' */
function monthLabel(m: unknown): string {
  const mt = /^(\d{4})-(\d{2})$/.exec(String(m ?? ""));
  if (!mt) return String(m ?? "-").slice(0, 7);
  return `${MONTHS[Math.max(0, Math.min(11, Number(mt[2]) - 1))]}/${mt[1].slice(2)}`;
}

/** Valor curto para eixo/rótulo de gráfico: 950 -> "950", 1500 -> "1,5k", 12000 -> "12k". */
function compactNum(v: number): string {
  const a = Math.abs(v);
  if (a >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(".", ",")}M`;
  if (a >= 10_000) return `${Math.round(v / 1000)}k`;
  if (a >= 1000) return `${(v / 1000).toFixed(1).replace(".", ",")}k`;
  return String(Math.round(v));
}

/** Teto "redondo" para o eixo Y (1, 2, 2.5, 5 × 10^n). */
function niceMax(v: number): number {
  if (!(v > 0)) return 1;
  const exp = Math.pow(10, Math.floor(Math.log10(v)));
  const f = v / exp;
  const m = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
  return m * exp;
}

function fit(font: PDFFont, raw: string, size: number, maxW: number): string {
  const text = safeText(font, raw); // medir texto fora do WinAnsi lança erro: sanitiza antes
  if (font.widthOfTextAtSize(text, size) <= maxW) return text;
  let t = text;
  while (t.length > 1 && font.widthOfTextAtSize(t + "...", size) > maxW) t = t.slice(0, -1);
  return t + "...";
}

type Col = { h: string; w: number; right?: boolean };

// ---------------------------------------------------------------- escritor
class Writer {
  page!: PDFPage;
  y = 0;
  pageNo = 0;
  doc: PDFDocument;
  font: PDFFont;
  bold: PDFFont;
  headerTitle: string;
  accent = NAVY;

  constructor(doc: PDFDocument, font: PDFFont, bold: PDFFont, headerTitle: string) {
    this.doc = doc;
    this.font = font;
    this.bold = bold;
    this.headerTitle = headerTitle;
    this.newPage();
  }

  /** Nova página; a partir da 2ª, cabeçalho repetido (marca + título + filete). */
  newPage() {
    this.page = this.doc.addPage([PAGE_W, PAGE_H]);
    this.pageNo++;
    this.y = PAGE_H - MARGIN;
    if (this.pageNo > 1) {
      this.page.drawRectangle({ x: 0, y: PAGE_H - 6, width: PAGE_W, height: 6, color: NAVY });
      this.page.drawText("Desperrengue", { x: MARGIN, y: PAGE_H - 26, size: 9, font: this.bold, color: NAVY });
      const t = safeText(this.font, this.headerTitle);
      this.page.drawText(t, {
        x: PAGE_W - MARGIN - this.font.widthOfTextAtSize(t, 8), y: PAGE_H - 26, size: 8, font: this.font, color: MUTED,
      });
      this.page.drawRectangle({ x: MARGIN, y: PAGE_H - 33, width: CONTENT_W, height: 0.6, color: LINE });
      this.y = PAGE_H - 52;
    }
  }

  ensure(h: number) {
    if (this.y - h < BOTTOM) this.newPage();
  }

  text(t: string, o: { size?: number; bold?: boolean; color?: any; x?: number; gap?: number } = {}) {
    const size = o.size ?? 10;
    const f = o.bold ? this.bold : this.font;
    this.ensure(size + (o.gap ?? 4));
    this.y -= size;
    this.page.drawText(safeText(f, t), { x: o.x ?? MARGIN, y: this.y, size, font: f, color: o.color ?? INK });
    this.y -= o.gap ?? 4;
  }

  paragraph(t: string, size = 9.5, color: any = MUTED, x = MARGIN, width = CONTENT_W) {
    const words = safeText(this.font, t).split(" ");
    let line = "";
    for (const w of words) {
      const next = line ? `${line} ${w}` : w;
      if (this.font.widthOfTextAtSize(next, size) > width && line) {
        this.text(line, { size, color, gap: 2, x });
        line = w;
      } else line = next;
    }
    if (line) this.text(line, { size, color, gap: 6, x });
  }

  /** Marcador "• texto" com recuo. */
  bullet(t: string, size = 9.5, color: any = INK) {
    const startY = this.y;
    this.ensure(size + 6);
    if (this.y !== startY) { /* mudou de página: o marcador acompanha */ }
    this.page.drawCircle({ x: MARGIN + 4, y: this.y - size / 2 - 1, size: 1.6, color: this.accent });
    this.paragraph(t, size, color, MARGIN + 14, CONTENT_W - 14);
  }

  section(title: string, accent = NAVY) {
    this.ensure(52);
    this.y -= 14;
    this.page.drawRectangle({ x: MARGIN, y: this.y - 14, width: 4, height: 18, color: accent });
    this.page.drawText(safeText(this.bold, title), { x: MARGIN + 11, y: this.y - 10, size: 13, font: this.bold, color: NAVY });
    this.y -= 22;
    this.page.drawRectangle({ x: MARGIN, y: this.y, width: CONTENT_W, height: 0.8, color: LINE });
    this.y -= 10;
  }

  subtitle(t: string) {
    this.ensure(26);
    this.text(t, { size: 10, bold: true, color: INK, gap: 6 });
  }

  /** Tabela com cabeçalho repetido a cada página e zebra. */
  table(cols: Col[], rows: string[][], opts: { empty?: string; fontSize?: number } = {}) {
    const fs = opts.fontSize ?? 8;
    const total = cols.reduce((a, c) => a + c.w, 0);
    const scale = CONTENT_W / total;
    const head = () => {
      this.ensure(22);
      this.page.drawRectangle({ x: MARGIN, y: this.y - 16, width: CONTENT_W, height: 18, color: SOFT });
      let x = MARGIN + 4;
      for (const c of cols) {
        const cw = c.w * scale;
        const t = safeText(this.bold, c.h);
        const tx = c.right ? x + cw - 8 - this.bold.widthOfTextAtSize(t, 7.5) : x;
        this.page.drawText(t, { x: tx, y: this.y - 11, size: 7.5, font: this.bold, color: NAVY });
        x += cw;
      }
      this.y -= 22;
    };
    head();
    if (rows.length === 0) {
      this.text(opts.empty ?? "Nenhum registro.", { size: 9, color: MUTED });
      return;
    }
    let k = 0;
    for (const r of rows) {
      if (this.y - 16 < BOTTOM) {
        this.newPage();
        head();
      }
      if (k % 2 === 1) {
        this.page.drawRectangle({ x: MARGIN, y: this.y - 12, width: CONTENT_W, height: 15, color: ZEBRA });
      }
      let x = MARGIN + 4;
      cols.forEach((c, i) => {
        const cw = c.w * scale;
        const t = fit(this.font, safeText(this.font, r[i] ?? ""), fs, cw - 10);
        const tx = c.right ? x + cw - 8 - this.font.widthOfTextAtSize(t, fs) : x;
        this.page.drawText(t, { x: tx, y: this.y - 9, size: fs, font: this.font, color: INK });
        x += cw;
      });
      this.y -= 15;
      k++;
    }
    this.y -= 4;
  }

  /** Cartão de KPI (altura 58). */
  kpi(x: number, w: number, label: string, value: string, color: any = NAVY) {
    const top = this.y;
    this.page.drawRectangle({ x, y: top - 58, width: w, height: 58, color: SOFT, borderColor: LINE, borderWidth: 0.7 });
    this.page.drawRectangle({ x, y: top - 58, width: 4, height: 58, color });
    this.page.drawText(safeText(this.font, fit(this.font, label, 8, w - 18)), { x: x + 12, y: top - 18, size: 8, font: this.font, color: MUTED });
    const v = safeText(this.bold, value);
    let size = 15;
    while (size > 9 && this.bold.widthOfTextAtSize(v, size) > w - 20) size -= 0.5;
    this.page.drawText(v, { x: x + 12, y: top - 40, size, font: this.bold, color });
  }

  /** Linha de cartões KPI (n por linha). */
  kpiRow(items: { label: string; value: string; color?: any }[]) {
    if (items.length === 0) return;
    this.ensure(70);
    const gap = 10;
    const w = (CONTENT_W - gap * (items.length - 1)) / items.length;
    items.forEach((it, i) => this.kpi(MARGIN + i * (w + gap), w, it.label, it.value, it.color ?? NAVY));
    this.y -= 58 + 12;
  }

  // ------------------------------------------------------------ gráficos
  /**
   * Barras verticais (1 ou 2 séries) por rótulo. Sempre desenha o quadro e o eixo,
   * mesmo sem dados ("Sem movimento no período").
   */
  barChart(o: {
    title: string;
    labels: string[];
    series: { name: string; color: any; values: number[] }[];
    money?: boolean;
    height?: number;
  }) {
    const h = o.height ?? 130;
    const total = h + 54;
    this.ensure(total);
    const top = this.y;
    const p = this.page;
    p.drawRectangle({ x: MARGIN, y: top - total, width: CONTENT_W, height: total, color: WHITE, borderColor: LINE, borderWidth: 0.7 });
    p.drawText(safeText(this.bold, o.title), { x: MARGIN + 10, y: top - 16, size: 9.5, font: this.bold, color: NAVY });
    // legenda
    let lx = MARGIN + CONTENT_W - 10;
    for (const s of [...o.series].reverse()) {
      const nm = safeText(this.font, s.name);
      const wText = this.font.widthOfTextAtSize(nm, 8);
      lx -= wText;
      p.drawText(nm, { x: lx, y: top - 15, size: 8, font: this.font, color: MUTED });
      lx -= 11;
      p.drawRectangle({ x: lx, y: top - 16.5, width: 8, height: 8, color: s.color });
      lx -= 12;
    }

    const plotL = MARGIN + 42;
    const plotR = MARGIN + CONTENT_W - 12;
    const plotTop = top - 30;
    const plotBottom = plotTop - h + 6;
    const plotH = plotTop - plotBottom;
    const n = Math.max(1, o.labels.length);
    const rawMax = Math.max(0, ...o.series.flatMap((s) => s.values.map((v) => num(v))));
    const max = niceMax(rawMax);

    // grade + eixo Y
    for (let i = 0; i <= 4; i++) {
      const yy = plotBottom + (plotH * i) / 4;
      p.drawRectangle({ x: plotL, y: yy, width: plotR - plotL, height: 0.4, color: i === 0 ? MUTED : LINE });
      const lab = safeText(this.font, rawMax <= 0 && i > 0 ? "" : (o.money ? "R$ " : "") + compactNum((max * i) / 4));
      p.drawText(lab, { x: plotL - 4 - this.font.widthOfTextAtSize(lab, 6.5), y: yy - 2.2, size: 6.5, font: this.font, color: MUTED });
    }

    const slot = (plotR - plotL) / n;
    const ns = Math.max(1, o.series.length);
    const barW = Math.min(18, (slot * 0.72) / ns);
    o.labels.forEach((lab, i) => {
      const cx = plotL + slot * i + slot / 2;
      o.series.forEach((s, si) => {
        const v = Math.max(0, num(s.values[i]));
        const bh = max > 0 ? (v / max) * plotH : 0;
        const bx = cx - (barW * ns) / 2 + barW * si;
        if (bh > 0.2) p.drawRectangle({ x: bx, y: plotBottom, width: barW - 1, height: bh, color: s.color });
        if (v > 0 && o.series.length === 1 && n <= 12) {
          const vl = safeText(this.font, compactNum(v));
          p.drawText(vl, { x: bx + (barW - 1) / 2 - this.font.widthOfTextAtSize(vl, 6) / 2, y: plotBottom + bh + 2, size: 6, font: this.font, color: INK });
        }
      });
      const ll = safeText(this.font, fit(this.font, lab, 6.5, slot + 4));
      p.drawText(ll, { x: cx - this.font.widthOfTextAtSize(ll, 6.5) / 2, y: plotBottom - 11, size: 6.5, font: this.font, color: MUTED });
    });
    if (rawMax <= 0) {
      const msg = "Sem movimento no período";
      p.drawText(msg, { x: plotL + (plotR - plotL) / 2 - this.font.widthOfTextAtSize(msg, 9) / 2, y: plotBottom + plotH / 2, size: 9, font: this.font, color: MUTED });
    }
    this.y -= total + 12;
  }

  /** Barras horizontais (ranking): rótulo, barra proporcional e valor à direita. */
  hBarChart(o: { title: string; items: { label: string; value: number; text: string; sub?: string }[]; color: any; max?: number }) {
    const rows = o.items.slice(0, 8);
    const rowH = 19;
    const total = 30 + Math.max(1, rows.length) * rowH + 8;
    this.ensure(total);
    const top = this.y;
    const p = this.page;
    p.drawRectangle({ x: MARGIN, y: top - total, width: CONTENT_W, height: total, color: WHITE, borderColor: LINE, borderWidth: 0.7 });
    p.drawText(safeText(this.bold, o.title), { x: MARGIN + 10, y: top - 16, size: 9.5, font: this.bold, color: NAVY });
    if (rows.length === 0) {
      p.drawText("Sem dados no período", { x: MARGIN + 10, y: top - 42, size: 9, font: this.font, color: MUTED });
      this.y -= total + 12;
      return;
    }
    const labW = 120;
    const valW = 110;
    const barL = MARGIN + 10 + labW + 6;
    const barMax = CONTENT_W - 20 - labW - valW - 12;
    const maxV = o.max ?? Math.max(1e-9, ...rows.map((r) => num(r.value)));
    rows.forEach((r, i) => {
      const yy = top - 30 - i * rowH - 13;
      p.drawText(safeText(this.font, fit(this.font, r.label, 8, labW)), { x: MARGIN + 10, y: yy, size: 8, font: this.font, color: INK });
      p.drawRectangle({ x: barL, y: yy - 2, width: barMax, height: 9, color: SOFT });
      const bw = maxV > 0 ? Math.max(num(r.value) > 0 ? 2 : 0, (num(r.value) / maxV) * barMax) : 0;
      if (bw > 0) p.drawRectangle({ x: barL, y: yy - 2, width: bw, height: 9, color: o.color });
      const t = safeText(this.bold, r.text);
      p.drawText(t, { x: MARGIN + CONTENT_W - 10 - this.bold.widthOfTextAtSize(t, 8), y: yy, size: 8, font: this.bold, color: INK });
      if (r.sub) {
        const st = safeText(this.font, r.sub);
        p.drawText(st, { x: MARGIN + CONTENT_W - 10 - this.bold.widthOfTextAtSize(t, 8) - 6 - this.font.widthOfTextAtSize(st, 7), y: yy, size: 7, font: this.font, color: MUTED });
      }
    });
    this.y -= total + 12;
  }

  /** Distribuição de notas 1–5 (barras horizontais, 5 no topo). */
  ratingChart(dist: Json, avg: number, count: number) {
    const total = 30 + 5 * 17 + 10;
    this.ensure(total);
    const top = this.y;
    const p = this.page;
    p.drawRectangle({ x: MARGIN, y: top - total, width: CONTENT_W, height: total, color: WHITE, borderColor: LINE, borderWidth: 0.7 });
    p.drawText("Distribuição das notas recebidas", { x: MARGIN + 10, y: top - 16, size: 9.5, font: this.bold, color: NAVY });
    const sum = count > 0 ? `Média ${avg.toFixed(2).replace(".", ",")} / 5  ·  ${count} avaliações` : "Nenhuma avaliação recebida";
    const st = safeText(this.font, sum);
    p.drawText(st, { x: MARGIN + CONTENT_W - 10 - this.font.widthOfTextAtSize(st, 8), y: top - 15, size: 8, font: this.font, color: MUTED });
    const counts = [5, 4, 3, 2, 1].map((s) => num(dist?.[String(s)]));
    const mx = Math.max(1, ...counts);
    const barL = MARGIN + 52;
    const barMax = CONTENT_W - 52 - 60;
    [5, 4, 3, 2, 1].forEach((s, i) => {
      const yy = top - 30 - i * 17 - 12;
      p.drawText(`${s} estrela${s > 1 ? "s" : ""}`, { x: MARGIN + 10, y: yy, size: 7.5, font: this.font, color: INK });
      p.drawRectangle({ x: barL, y: yy - 2, width: barMax, height: 9, color: SOFT });
      const bw = (counts[i] / mx) * barMax;
      const col = s >= 4 ? GREEN : s === 3 ? AMBER : RED;
      if (bw > 0) p.drawRectangle({ x: barL, y: yy - 2, width: Math.max(2, bw), height: 9, color: col });
      const t = String(counts[i]);
      p.drawText(t, { x: MARGIN + CONTENT_W - 10 - this.bold.widthOfTextAtSize(t, 8), y: yy, size: 8, font: this.bold, color: INK });
    });
    this.y -= total + 12;
  }

  /** Avaliações recebidas: cabeçalho (pedido · nota · data) + comentário COMPLETO com quebra de linha. */
  reviewList(revs: Json[]) {
    if (revs.length === 0) {
      this.text("Nenhuma avaliação recebida.", { size: 9, color: MUTED });
      return;
    }
    for (const r of revs) {
      this.ensure(34);
      this.text(`${String(r.job ?? "-")}  ·  ${num(r.rating)}/5  ·  ${formatDate(r.created_at)}`, { size: 8.5, bold: true, color: BLUE, gap: 2 });
      const c = String(r.comment ?? "").trim();
      this.paragraph(c ? c.slice(0, 1200) : "(sem comentário)", 8.5, c ? INK : MUTED, MARGIN + 8, CONTENT_W - 8);
    }
  }
  /** "Economia por pedido": contratado (barra cheia) vs. média dos orçamentos (barra clara). */
  savingsChart(items: { label: string; hired: number; avg: number }[]) {
    const rows = items.slice(0, 8);
    const rowH = 22;
    const total = 38 + rows.length * rowH + 6;
    this.ensure(total);
    const top = this.y;
    const p = this.page;
    p.drawRectangle({ x: MARGIN, y: top - total, width: CONTENT_W, height: total, color: WHITE, borderColor: LINE, borderWidth: 0.7 });
    p.drawText("Economia por pedido: valor contratado vs. média dos orçamentos", { x: MARGIN + 10, y: top - 16, size: 9.5, font: this.bold, color: NAVY });
    // legenda
    p.drawRectangle({ x: MARGIN + 10, y: top - 33, width: 8, height: 8, color: GREEN });
    p.drawText("Contratado", { x: MARGIN + 21, y: top - 32, size: 7.5, font: this.font, color: MUTED });
    p.drawRectangle({ x: MARGIN + 80, y: top - 33, width: 8, height: 8, color: LINE });
    p.drawText("Média dos orçamentos", { x: MARGIN + 91, y: top - 32, size: 7.5, font: this.font, color: MUTED });
    const labW = 96;
    const valW = 118;
    const barL = MARGIN + 10 + labW + 6;
    const barMax = CONTENT_W - 20 - labW - valW - 12;
    const mx = Math.max(1e-9, ...rows.map((r) => Math.max(r.hired, r.avg)));
    rows.forEach((r, i) => {
      const yy = top - 38 - i * rowH - 14;
      p.drawText(safeText(this.font, fit(this.font, r.label, 8, labW)), { x: MARGIN + 10, y: yy, size: 8, font: this.font, color: INK });
      p.drawRectangle({ x: barL, y: yy + 1, width: Math.max(1, (r.avg / mx) * barMax), height: 6, color: LINE });
      p.drawRectangle({ x: barL, y: yy - 6, width: Math.max(1, (r.hired / mx) * barMax), height: 6, color: GREEN });
      const sv = Math.max(0, r.avg - r.hired);
      const t = safeText(this.bold, `- ${formatBRL(sv)}`);
      p.drawText(t, { x: MARGIN + CONTENT_W - 10 - this.bold.widthOfTextAtSize(t, 8), y: yy - 1, size: 8, font: this.bold, color: GREEN });
      const t2 = safeText(this.font, `${formatBRL(r.hired)} / ${formatBRL(r.avg)}`);
      p.drawText(t2, { x: MARGIN + CONTENT_W - 10 - this.bold.widthOfTextAtSize(t, 8) - 6 - this.font.widthOfTextAtSize(t2, 7), y: yy - 1, size: 7, font: this.font, color: MUTED });
    });
    this.y -= total + 12;
  }
}

// ---------------------------------------------------------------- textos por escopo
type Roles = { client: boolean; provider: boolean };

function rolesOf(d: Json): Roles {
  const sr: unknown[] = Array.isArray(d.scope_roles) ? d.scope_roles : [];
  if (sr.length > 0) return { client: sr.includes("client"), provider: sr.includes("provider") };
  // Dossiê no formato antigo (sem scope_roles): usa os papéis da conta.
  return { client: !!d.is_client || !!d.client, provider: !!d.is_provider || !!d.provider };
}

export function scopeTitle(r: Roles): string {
  if (r.client && r.provider) return "Contas de Cliente e Profissional";
  if (r.provider) return "Conta de Profissional";
  if (r.client) return "Conta de Cliente";
  return "Conta Desperrengue";
}

function accountRemoved(d: Json, r: Roles): boolean {
  if (typeof d.scope === "string") return d.scope === "all";
  return true;
}

// ---------------------------------------------------------------- PDF
export async function buildDossiePdf(d: Json): Promise<Uint8Array> {
  d = obj(d);
  const roles = rolesOf(d);
  const title = scopeTitle(roles);
  const removed = accountRemoved(d, roles);

  const doc = await PDFDocument.create();
  doc.setTitle(`Dossiê de Despedida — ${title}`);
  doc.setAuthor("Desperrengue");
  doc.setCreator("Desperrengue");
  doc.setSubject("Dossiê de Despedida (LGPD)");
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const w = new Writer(doc, font, bold, `Dossiê de Despedida · ${title}`);

  // ------------------------------------------------ capa / cabeçalho
  const headH = 156;
  w.page.drawRectangle({ x: 0, y: PAGE_H - headH, width: PAGE_W, height: headH, color: NAVY });
  w.page.drawRectangle({ x: 0, y: PAGE_H - headH - 5, width: PAGE_W, height: 5, color: roles.client && !roles.provider ? ORANGE : BLUE_L });
  // faixa de acento (cliente = laranja, profissional = azul)
  const chipX = MARGIN;
  let cx = chipX;
  const chip = (label: string, color: any) => {
    const t = safeText(bold, label);
    const tw = bold.widthOfTextAtSize(t, 8.5);
    w.page.drawRectangle({ x: cx, y: PAGE_H - 143, width: tw + 20, height: 18, color });
    w.page.drawText(t, { x: cx + 10, y: PAGE_H - 137.5, size: 8.5, font: bold, color: WHITE });
    cx += tw + 28;
  };
  w.page.drawText("DESPERRENGUE", { x: MARGIN, y: PAGE_H - 46, size: 11, font: bold, color: rgb(0.78, 0.86, 1) });
  w.page.drawText("Dossiê de Despedida", { x: MARGIN, y: PAGE_H - 78, size: 30, font: bold, color: WHITE });
  w.page.drawText(safeText(font, title), { x: MARGIN, y: PAGE_H - 98, size: 13, font, color: rgb(0.85, 0.9, 1) });
  w.page.drawText(safeText(font, `${d.name ?? "Usuário"}  ·  gerado em ${formatDate(d.generated_at)}`), {
    x: MARGIN, y: PAGE_H - 115, size: 9.5, font, color: rgb(0.78, 0.85, 0.97),
  });
  if (roles.client) chip("CLIENTE", ORANGE);
  if (roles.provider) chip("PROFISSIONAL", BLUE_L);
  w.y = PAGE_H - headH - 22;

  w.paragraph(
    removed
      ? "Este documento reúne o histórico completo da sua conta. Ele é enviado antes da exclusão definitiva dos seus dados " +
        "pessoais, conforme a LGPD (art. 18). Guarde-o: depois da exclusão não será possível gerar outro."
      : "Este documento reúne o histórico da parte da sua conta que está sendo excluída (" + title.replace("Conta de ", "").replace("Contas de ", "").toLowerCase() +
        "). Ele é enviado antes da exclusão dos dados dessa parte, conforme a LGPD (art. 18). Guarde-o: depois da exclusão " +
        "não será possível gerar outro. A sua outra conta continua ativa.",
  );

  // identificação
  w.page.drawRectangle({ x: MARGIN, y: w.y - 40, width: CONTENT_W, height: 40, color: SOFT, borderColor: LINE, borderWidth: 0.7 });
  w.page.drawText(safeText(bold, d.name ?? "-"), { x: MARGIN + 12, y: w.y - 17, size: 11, font: bold, color: NAVY });
  w.page.drawText(
    safeText(font, `Membro desde ${formatDate(d.member_since)}  ·  Escopo da exclusão: ${title}  ·  ${removed ? "conta inteira será removida" : "a outra conta continua ativa"}`),
    { x: MARGIN + 12, y: w.y - 32, size: 8.5, font, color: MUTED },
  );
  w.y -= 52;

  // ------------------------------------------------ CLIENTE
  if (roles.client) clientPart(w, obj(d.client), d);

  // ------------------------------------------------ PROFISSIONAL
  if (roles.provider) {
    if (roles.client) w.newPage(); // as duas contas no mesmo PDF: a parte do profissional começa em página própria
    providerPart(w, obj(d.provider), d);
  }

  // ------------------------------------------------ O que acontece agora
  nextSteps(w, roles, removed);

  // Rodapé com paginação
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawRectangle({ x: MARGIN, y: FOOTER_Y + 11, width: CONTENT_W, height: 0.5, color: LINE });
    p.drawText("Documento gerado automaticamente pelo Desperrengue", { x: MARGIN, y: FOOTER_Y, size: 8, font, color: MUTED });
    const t = `Página ${i + 1} de ${pages.length}`;
    p.drawText(t, { x: PAGE_W - MARGIN - font.widthOfTextAtSize(t, 8), y: FOOTER_Y, size: 8, font, color: MUTED });
  });

  return await doc.save();
}

// ---------------------------------------------------------------- parte do cliente
function clientPart(w: Writer, c: Json, d: Json) {
  w.accent = ORANGE;
  const orders = arr(c.orders);
  const totalSpent = num(c.total_spent ?? d.totals?.spent);
  const totalSaved = num(c.total_saved ?? d.totals?.saved);
  const doneN = c.completed_count != null ? num(c.completed_count) : orders.filter((o) => o.status === "completed").length;
  const paidN = c.paid_count != null ? num(c.paid_count) : orders.filter((o) => o.payment_status === "released").length;
  const ticket = c.ticket_medio != null ? num(c.ticket_medio) : paidN > 0 ? totalSpent / paidN : 0;

  w.section("Conta de Cliente — resumo", ORANGE);
  w.kpiRow([
    { label: "Total gasto na plataforma", value: formatBRL(totalSpent), color: ORANGE },
    { label: "Total economizado", value: formatBRL(totalSaved), color: GREEN },
    { label: "Serviços concluídos", value: String(doneN), color: NAVY },
    { label: "Ticket médio", value: formatBRL(ticket), color: NAVY },
  ]);
  w.paragraph(
    "Economia = média dos orçamentos recebidos menos o valor contratado, somada nos pedidos concluídos com 2 ou mais orçamentos. " +
      "Ticket médio = total gasto ÷ pedidos pagos.",
    8, MUTED,
  );

  const monthly = arr(c.monthly);
  w.subtitle("Seus gastos e economia");
  w.barChart({
    title: "Gasto e economia por mês (últimos 12 meses)",
    labels: monthly.map((m) => monthLabel(m.month)),
    series: [
      { name: "Gasto", color: ORANGE, values: monthly.map((m) => num(m.spent)) },
      { name: "Economia", color: GREEN, values: monthly.map((m) => num(m.saved)) },
    ],
    money: true,
  });

  const byCat = arr(c.by_category);
  w.hBarChart({
    title: "Gasto por categoria de serviço",
    color: ORANGE,
    items: byCat.map((x) => ({ label: String(x.category ?? "Outros"), value: num(x.spent), text: formatBRL(x.spent), sub: `${num(x.orders)} pedido${num(x.orders) === 1 ? "" : "s"}` })),
  });

  const savings = orders
    .filter((o) => num(o.saved) > 0 && o.avg_other_quotes != null && o.price != null)
    .map((o) => ({ label: String(o.title ?? o.id ?? "Pedido"), hired: num(o.price), avg: num(o.avg_other_quotes), saved: num(o.saved) }))
    .sort((a, b) => b.saved - a.saved);
  if (savings.length > 0) w.savingsChart(savings);

  // status + avaliações + carteira
  const bySt = obj(c.by_status);
  const stKeys = Object.keys(bySt).sort((a, b) => num(bySt[b]) - num(bySt[a]));
  const rg = obj(c.reviews_given);
  const wal = obj(c.wallet);
  w.subtitle("Panorama dos pedidos");
  w.table(
    [{ h: "Indicador", w: 220 }, { h: "Valor", w: 295, right: true }],
    [
      ["Pedidos realizados", String(c.orders_count != null ? num(c.orders_count) : orders.length)],
      ...stKeys.map((k) => [`   · ${statusPt(k)}`, String(num(bySt[k]))]),
      ["Avaliações que você deu", num(rg.count) > 0 ? `${num(rg.count)} (média ${num(rg.avg).toFixed(2).replace(".", ",")} / 5)` : "0"],
      ["Recargas na carteira (Pix)", `${num(wal.count)} recarga${num(wal.count) === 1 ? "" : "s"} · ${formatBRL(wal.total)}`],
    ],
  );

  w.section(`Pedidos como cliente (${orders.length})`, ORANGE);
  w.table(
    [
      { h: "ID", w: 50 }, { h: "Serviço", w: 88 }, { h: "Categoria", w: 54 }, { h: "Profissional", w: 54 },
      { h: "Status", w: 58 }, { h: "Agend.", w: 52 }, { h: "Início", w: 52 }, { h: "Término", w: 52 },
      { h: "Orç.", w: 22, right: true }, { h: "Valor", w: 56, right: true },
    ],
    orders.map((o) => [
      String(o.id ?? "-"), String(o.title ?? ""), String(o.category ?? "-"), String(o.partner ?? "-"), statusPt(o.status),
      formatDate(o.scheduled_for), formatDate(o.started_at), formatDate(o.finished_at),
      String(num(o.quotes_received)), o.paid != null ? formatBRL(o.paid) : o.price != null ? formatBRL(o.price) : "-",
    ]),
    { fontSize: 7, empty: "Nenhum pedido registrado." },
  );
}

// ---------------------------------------------------------------- parte do profissional
function providerPart(w: Writer, p: Json, d: Json) {
  w.accent = BLUE;
  const jobs = arr(p.jobs);
  const gross = num(p.total_gross);
  const fee = num(p.total_fee);
  const net = num(p.total_profit ?? d.totals?.profit);
  const withdrawn = num(p.total_withdrawn);
  const jobsN = p.completed_count != null ? num(p.completed_count) : jobs.filter((j) => j.status === "completed").length;
  const quotes = arr(p.quotes);
  const qTotal = p.quotes_total != null ? num(p.quotes_total) : quotes.length;
  const qAcc = p.quotes_accepted != null ? num(p.quotes_accepted) : quotes.filter((q) => q.status === "accepted").length;
  const rate = p.acceptance_rate != null ? num(p.acceptance_rate) : qTotal > 0 ? (100 * qAcc) / qTotal : 0;
  const revs = arr(p.reviews);
  const revN = p.reviews_count != null ? num(p.reviews_count) : revs.length;
  const ratingAvg = p.rating_avg != null ? num(p.rating_avg) : revN > 0 ? revs.reduce((a, r) => a + num(r.rating), 0) / revN : 0;

  w.section("Conta de Profissional — resumo", BLUE);
  w.kpiRow([
    { label: "Lucro líquido", value: formatBRL(net), color: GREEN },
    { label: "Faturamento bruto", value: formatBRL(gross), color: BLUE },
    { label: "Comissão da plataforma", value: formatBRL(fee), color: BLUE_L },
  ]);
  w.kpiRow([
    { label: "Serviços concluídos", value: String(jobsN), color: NAVY },
    { label: "Nota média", value: revN > 0 ? `${ratingAvg.toFixed(2).replace(".", ",")} / 5` : "—", color: AMBER },
    { label: "Sacado via Pix", value: formatBRL(withdrawn), color: NAVY },
  ]);
  w.paragraph("Lucro = valor líquido recebido (bruto menos a comissão da plataforma).", 8, MUTED);

  const monthly = arr(p.monthly);
  w.subtitle("Seus ganhos");
  w.barChart({
    title: "Lucro líquido por mês (últimos 12 meses)",
    labels: monthly.map((m) => monthLabel(m.month)),
    series: [{ name: "Lucro líquido", color: BLUE_L, values: monthly.map((m) => num(m.net)) }],
    money: true,
  });
  const byCat = arr(p.by_category);
  w.hBarChart({
    title: "Lucro líquido por categoria",
    color: BLUE,
    items: byCat.map((x) => ({ label: String(x.category ?? "Outros"), value: num(x.net), text: formatBRL(x.net), sub: `${num(x.jobs)} serviço${num(x.jobs) === 1 ? "" : "s"}` })),
  });
  w.ratingChart(obj(p.rating_dist), ratingAvg, revN);

  w.section(`Serviços como profissional (${jobs.length})`, BLUE);
  w.table(
    [
      { h: "ID", w: 50 }, { h: "Serviço", w: 84 }, { h: "Categoria", w: 52 }, { h: "Cliente", w: 52 }, { h: "Status", w: 56 },
      { h: "Criado", w: 52 }, { h: "Término", w: 52 }, { h: "Bruto", w: 50, right: true }, { h: "Comissão", w: 46, right: true }, { h: "Líquido", w: 54, right: true },
    ],
    jobs.map((j) => [
      String(j.id ?? "-"), String(j.title ?? ""), String(j.category ?? "-"), String(j.partner ?? "-"), statusPt(j.status),
      formatDate(j.created_at), formatDate(j.finished_at),
      j.gross != null ? formatBRL(j.gross) : "-", j.fee != null ? formatBRL(j.fee) : "-", j.net != null ? formatBRL(j.net) : "-",
    ]),
    { fontSize: 7, empty: "Nenhum serviço registrado." },
  );
  w.text(
    `Bruto: ${formatBRL(gross)}   ·   Comissão: ${formatBRL(fee)}   ·   Lucro líquido: ${formatBRL(net)}   ·   Sacado via Pix: ${formatBRL(withdrawn)}`,
    { size: 9, bold: true, color: BLUE },
  );

  w.section(`Orçamentos enviados (${qTotal})`, BLUE);
  w.kpiRow([
    { label: "Orçamentos enviados", value: String(qTotal), color: NAVY },
    { label: "Aceitos", value: String(qAcc), color: GREEN },
    { label: "Taxa de aceitação", value: `${rate.toFixed(1).replace(".", ",")}%`, color: BLUE },
  ]);
  w.table(
    [{ h: "Pedido", w: 56 }, { h: "Serviço", w: 190 }, { h: "Status", w: 100 }, { h: "Data", w: 70 }, { h: "Valor", w: 100, right: true }],
    quotes.map((q) => [String(q.job ?? "-"), String(q.title ?? ""), statusPt(q.status), formatDate(q.created_at), formatBRL(q.price)]),
    { empty: "Nenhum orçamento enviado." },
  );

  w.section(`Avaliações recebidas (${revN})`, BLUE);
  w.reviewList(revs);
  if (p.achievements_count != null) {
    w.text(`Conquistas desbloqueadas: ${num(p.achievements_count)}`, { size: 9, color: MUTED });
  }

  const wds = arr(p.withdrawals);
  w.section(`Saques (${wds.length})`, BLUE);
  w.table(
    [{ h: "Data", w: 70 }, { h: "Chave (mascarada)", w: 150 }, { h: "Status", w: 100 }, { h: "Valor", w: 100, right: true }],
    wds.map((x) => [formatDate(x.created_at), `${String(x.pix_key_type ?? "").toUpperCase()} ${String(x.pix_key_hint ?? "")}`.trim(), statusPt(x.status), formatBRL(x.amount)]),
    { empty: "Nenhum saque realizado." },
  );
}

// ---------------------------------------------------------------- O que acontece agora
function nextSteps(w: Writer, roles: Roles, removed: boolean) {
  w.accent = NAVY;
  w.section("O que acontece agora");
  if (removed) {
    w.paragraph("Sua conta foi excluída por inteiro. Veja o que isso significa:", 9.5, INK);
    w.subtitle("O que foi excluído");
    w.bullet("Seu perfil, e-mail de acesso, documentos de verificação, fotos, mensagens, endereços e demais dados pessoais.");
    w.bullet("Pedidos sem pagamento, carteira, extratos, recargas Pix, portfólio, certificados e conquistas.");
    w.subtitle("O que foi mantido");
    w.bullet(
      "Apenas registros financeiros exigidos por lei (valores, datas e identificadores de pedido), sem nome, endereço ou qualquer vínculo com você, " +
        "para proteger a outra parte de cada serviço.",
    );
    w.paragraph("Se tiver dúvidas, responda ao e-mail que acompanhou este documento.", 9, MUTED);
    return;
  }
  const kept = roles.client ? "profissional" : "cliente";
  const gone = roles.client ? "cliente" : "profissional";
  w.paragraph(`Apenas a sua conta de ${gone} foi excluída. A sua conta de ${kept} continua ativa e você pode seguir usando o aplicativo normalmente com o mesmo e-mail e senha.`, 9.5, INK);
  w.subtitle("O que foi excluído");
  if (roles.client) {
    w.bullet("Pedidos sem pagamento, endereços e códigos de segurança dos pedidos, conversas e chamados de suporte como cliente.");
    w.bullet("Carteira, extrato e recargas Pix. O saldo de homologação da carteira não é recuperável.");
    w.bullet("Seu endereço de cliente e o papel de cliente no seu perfil.");
  } else {
    w.bullet("Perfil profissional, portfólio, certificados, conquistas, fixados da vitrine e fotos de evidência dos serviços.");
    w.bullet("Documentos de verificação (KYC) e orçamentos pendentes. A verificação precisará ser refeita se você voltar a ser profissional.");
    w.bullet("O papel de profissional e a biografia profissional do seu perfil.");
  }
  w.subtitle("O que foi mantido");
  if (roles.client) {
    w.bullet("Pedidos que tiveram pagamento ficam apenas como registro financeiro anonimizado (sem texto, endereço ou vínculo com você), para proteger o profissional e cumprir a lei.");
    w.bullet("A sua conta de profissional, com todos os seus dados, serviços, ganhos, avaliações e saques.");
  } else {
    w.bullet("Pagamentos, saques e avaliações recebidas ficam como registro histórico (financeiro e do cliente), sem dado pessoal além do que já constava.");
    w.bullet("A sua conta de cliente, com todos os seus pedidos, carteira e histórico.");
  }
  w.paragraph("Se tiver dúvidas, responda ao e-mail que acompanhou este documento.", 9, MUTED);
}

/** Base64 sem estourar a pilha com PDFs grandes. */
export function toBase64(bytes: Uint8Array): string {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

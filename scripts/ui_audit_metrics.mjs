#!/usr/bin/env node
// Desperrengue v2.28.0 - Linter de design (metricas + baseline "ratchet").
//
// Varre app/lib/**/*.dart e conta, POR ARQUIVO, ocorrencias proibidas pelo Design System
// (spec 2.5). O resultado vive em app/test/design_system_baseline.json (UMA LINHA POR
// ARQUIVO, ordenada por caminho, metricas zeradas omitidas => merges limpos). O teste
// app/test/design_system_guards_test.dart FALHA se qualquer contagem SUBIR ou se arquivo
// novo tiver ocorrencia proibida. Quando a contagem DIMINUIR, atualize o baseline.
//
// Uso (a partir da raiz do repo; sem dependencias):
//   node scripts/ui_audit_metrics.mjs                       # regenera TODO o baseline + resumo
//   node scripts/ui_audit_metrics.mjs --update <arq...>     # reescreve so as linhas dos arquivos dados
//   node scripts/ui_audit_metrics.mjs --check               # compara com o baseline (exit 1 se subiu)
//   node scripts/ui_audit_metrics.mjs --summary             # so imprime o resumo (nao grava)
// <arq> pode ser `app/lib/features/x.dart`, `lib/features/x.dart` ou `features/x.dart`.
//
// IMPORTANTE: o scanner (tokenizador de comentarios/strings) e as regexes abaixo DEVEM ser
// identicos aos de app/test/design_system/ds_source_scanner.dart. Mude os dois juntos.
//
// Escopo: exclui features/founder/**, main_founder.dart e core/ui/design_system/**.
// core/ui/** (camada de fachada: widgets.dart, app_scaffold.dart...) e isento das metricas
// colorLiteral, fittedBox, materialPageRoute, showModalBottomSheet, showDialog e
// circularProgress (e onde AppRoute/AppSheet/AppDialog sao implementados); fontSize,
// ellipsis e glyphInText continuam valendo la.
// glyphInText: emoji/simbolos (★ ✓ ✗ 🔒 → etc.) dentro de LITERAIS DE STRING (heuristica:
// qualquer string literal vira Text cedo ou tarde; comentarios sao ignorados).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const APP = path.resolve(HERE, '..', 'app');
const LIB = path.join(APP, 'lib');
const BASELINE = path.join(APP, 'test', 'design_system_baseline.json');

// ---- metricas (ordem fixa = ordem no JSON) ---------------------------------------------
// MANTER IDENTICO ao Dart. `where`: 'code' = texto sem comentarios/strings; 'strings' = literais.
export const METRICS = [
  { key: 'fontSize', where: 'code', re: /\bfontSize\s*:\s*-?\.?\d/g },
  { key: 'colorLiteral', where: 'code', re: /\bColor\(\s*0x/g, exemptCoreUi: true },
  { key: 'fittedBox', where: 'code', re: /\bFittedBox\b/g, exemptCoreUi: true },
  { key: 'materialPageRoute', where: 'code', re: /\bMaterialPageRoute\b/g, exemptCoreUi: true },
  { key: 'showModalBottomSheet', where: 'code', re: /\bshowModalBottomSheet\b/g, exemptCoreUi: true },
  { key: 'showDialog', where: 'code', re: /\bshowDialog\b/g, exemptCoreUi: true },
  { key: 'circularProgress', where: 'code', re: /\bCircularProgressIndicator\b/g, exemptCoreUi: true },
  { key: 'ellipsis', where: 'code', re: /\bTextOverflow\.ellipsis\b/g },
  // Pesos sem arquivo embarcado (Inter 100-300 e 900; Jakarta idem). w800 em Inter casa com 700.
  { key: 'unembeddedWeight', where: 'code', re: /\bFontWeight\.w(?:[1-3]00|900)\b/g },
  {
    key: 'glyphInText',
    where: 'strings',
    // Emoji (U+1F000-1FAFF), Misc Symbols + Dingbats (U+2600-27BF: ★ ✓ ✗ ☎ ❤ ...),
    // setas U+2190-2193 (← ↑ → ↓), U+2B00-2BFF (⭐ ⬆ ...), relogio/ampulheta U+231A-231B, U+23E9-23FF.
    re: /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{2193}\u{2B00}-\u{2BFF}\u{231A}\u{231B}\u{23E9}-\u{23FF}]/gu,
  },
];

export function isExcluded(rel) {
  return (
    rel.startsWith('features/founder/') ||
    rel === 'main_founder.dart' ||
    rel.startsWith('core/ui/design_system/')
  );
}
export const isCoreUi = (rel) => rel.startsWith('core/ui/');

// ---- scanner Dart (comentarios + strings) ----------------------------------------------
// Devolve { code, strings }: `code` = fonte sem comentarios e com cada literal de string
// trocado por "" ; `strings` = conteudo (escapes \uXXXX decodificados) de cada literal.
export function scanDart(src) {
  const n = src.length;
  let i = 0;
  const strings = [];

  const isIdent = (c) => c !== undefined && /[A-Za-z0-9_$]/.test(c);

  function readEscape(out) {
    // src[i] === '\\'
    const c = src[i + 1];
    if (c === 'u') {
      if (src[i + 2] === '{') {
        const end = src.indexOf('}', i + 3);
        if (end > 0) {
          const cp = parseInt(src.slice(i + 3, end), 16);
          if (Number.isFinite(cp) && cp <= 0x10ffff) out.push(String.fromCodePoint(cp));
          i = end + 1;
          return;
        }
      } else {
        const hex = src.slice(i + 2, i + 6);
        if (/^[0-9a-fA-F]{4}$/.test(hex)) {
          out.push(String.fromCharCode(parseInt(hex, 16)));
          i += 6;
          return;
        }
      }
    } else if (c === 'x') {
      const hex = src.slice(i + 2, i + 4);
      if (/^[0-9a-fA-F]{2}$/.test(hex)) {
        out.push(String.fromCharCode(parseInt(hex, 16)));
        i += 4;
        return;
      }
    } else if (c === 'n' || c === 't' || c === 'r') {
      out.push(' ');
      i += 2;
      return;
    }
    if (c !== undefined) out.push(c);
    i += 2;
  }

  // Le um literal comecando em i (aspa) e empurra o conteudo em `strings`.
  function scanString(raw) {
    const q = src[i];
    const triple = src[i + 1] === q && src[i + 2] === q;
    i += triple ? 3 : 1;
    const out = [];
    while (i < n) {
      const c = src[i];
      if (triple) {
        if (c === q && src[i + 1] === q && src[i + 2] === q) {
          i += 3;
          break;
        }
      } else if (c === q) {
        i += 1;
        break;
      } else if (c === '\n') {
        // string simples nao atravessa linha: aborta (codigo malformado/heuristica)
        break;
      }
      if (!raw && c === '\\') {
        readEscape(out);
        continue;
      }
      if (!raw && c === '$' && src[i + 1] === '{') {
        i += 2;
        scanCode(true); // consome ate o '}' correspondente; strings internas entram em `strings`
        continue;
      }
      out.push(c);
      i += 1;
    }
    strings.push(out.join(''));
  }

  // Escaneia codigo; se `interp`, para ao encontrar '}' de profundidade 0 (consumindo-o).
  function scanCode(interp) {
    const codeOut = [];
    let depth = 0;
    while (i < n) {
      const c = src[i];
      const d = src[i + 1];
      if (c === '/' && d === '/') {
        while (i < n && src[i] !== '\n') i += 1;
        continue;
      }
      if (c === '/' && d === '*') {
        let level = 1;
        i += 2;
        while (i < n && level > 0) {
          if (src[i] === '/' && src[i + 1] === '*') {
            level += 1;
            i += 2;
          } else if (src[i] === '*' && src[i + 1] === '/') {
            level -= 1;
            i += 2;
          } else {
            if (src[i] === '\n') codeOut.push('\n');
            i += 1;
          }
        }
        continue;
      }
      if (c === '"' || c === "'") {
        const raw = src[i - 1] === 'r' && !isIdent(src[i - 2]);
        if (raw) codeOut.pop(); // remove o 'r' do prefixo
        scanString(raw);
        codeOut.push('""');
        continue;
      }
      if (interp) {
        if (c === '{') depth += 1;
        else if (c === '}') {
          if (depth === 0) {
            i += 1;
            return codeOut.join('');
          }
          depth -= 1;
        }
      }
      codeOut.push(c);
      i += 1;
    }
    return codeOut.join('');
  }

  const code = scanCode(false);
  return { code, strings };
}

export function countMetrics(rel, src) {
  const { code, strings } = scanDart(src);
  const joined = strings.join('\n');
  const counts = {};
  const exempt = {};
  for (const m of METRICS) {
    const text = m.where === 'code' ? code : joined;
    const matches = text.match(m.re);
    const c = matches ? matches.length : 0;
    if (m.exemptCoreUi && isCoreUi(rel)) {
      if (c > 0) exempt[m.key] = c;
      continue;
    }
    if (c > 0) counts[m.key] = c;
  }
  return { counts, exempt };
}

// ---- varredura --------------------------------------------------------------------------
function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dart')) out.push(p);
  }
  return out;
}
const relOf = (abs) => path.relative(LIB, abs).split(path.sep).join('/');

export function scanAll() {
  const result = new Map();
  const exemptTotals = {};
  let files = 0;
  for (const abs of walk(LIB, []).sort()) {
    const rel = relOf(abs);
    if (isExcluded(rel)) continue;
    files += 1;
    const { counts, exempt } = countMetrics(rel, fs.readFileSync(abs, 'utf8'));
    for (const [k, v] of Object.entries(exempt)) exemptTotals[k] = (exemptTotals[k] || 0) + v;
    if (Object.keys(counts).length) result.set(rel, counts);
  }
  return { result, exemptTotals, files };
}

// ---- baseline (uma linha por arquivo) ---------------------------------------------------
const SENTINEL = '~fim';
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

function lineFor(rel, counts) {
  const body = METRICS.filter((m) => counts[m.key]).map((m) => `"${m.key}":${counts[m.key]}`);
  return `  ${JSON.stringify(rel)}: {${body.join(',')}},`;
}
function serialize(map) {
  const lines = [...map.keys()].sort(cmp).map((rel) => lineFor(rel, map.get(rel)));
  return `{\n${lines.join('\n')}${lines.length ? '\n' : ''}  "${SENTINEL}": {}\n}\n`;
}
export function readBaseline() {
  const raw = JSON.parse(fs.readFileSync(BASELINE, 'utf8'));
  const map = new Map();
  for (const [k, v] of Object.entries(raw)) if (k !== SENTINEL && !k.startsWith('_')) map.set(k, v);
  return map;
}

function totals(map) {
  const t = {};
  for (const counts of map.values()) for (const [k, v] of Object.entries(counts)) t[k] = (t[k] || 0) + v;
  return t;
}
function printSummary(map, exemptTotals, files) {
  const t = totals(map);
  console.log(`Arquivos varridos: ${files} | com ocorrencias: ${map.size}`);
  console.log('Metrica                 total  arquivos  (isentos em core/ui)');
  for (const m of METRICS) {
    const nf = [...map.values()].filter((c) => c[m.key]).length;
    const ex = exemptTotals[m.key] ? `  (+${exemptTotals[m.key]} em core/ui)` : '';
    console.log(`${m.key.padEnd(22)} ${String(t[m.key] || 0).padStart(6)} ${String(nf).padStart(9)}${ex}`);
  }
}

function normalizeArg(a) {
  let p = a.replace(/\\/g, '/');
  p = p.replace(/^\.\//, '');
  const i = p.indexOf('app/lib/');
  if (i >= 0) p = p.slice(i + 'app/lib/'.length);
  else if (p.startsWith('lib/')) p = p.slice(4);
  return p;
}

function check() {
  const base = readBaseline();
  const { result } = scanAll();
  const up = [];
  const down = [];
  for (const [rel, counts] of result) {
    const b = base.get(rel) || {};
    for (const m of METRICS) {
      const cur = counts[m.key] || 0;
      const old = b[m.key] || 0;
      if (cur > old) up.push(`${rel} :: ${m.key} ${old} -> ${cur}`);
    }
  }
  for (const [rel, b] of base) {
    const counts = result.get(rel) || {};
    for (const m of METRICS) {
      const cur = counts[m.key] || 0;
      const old = b[m.key] || 0;
      if (cur < old) down.push(`${rel} :: ${m.key} ${old} -> ${cur}`);
    }
  }
  if (down.length) {
    console.log(`Diminuiram (${down.length}) - rode: node scripts/ui_audit_metrics.mjs --update <arquivo>`);
    for (const d of down.slice(0, 50)) console.log('  ' + d);
  }
  if (up.length) {
    console.error(`SUBIRAM (${up.length}) - proibido (ratchet):`);
    for (const u of up) console.error('  ' + u);
    process.exit(1);
  }
  console.log('OK: nenhuma contagem subiu.');
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--check')) return check();
  const { result, exemptTotals, files } = scanAll();
  if (args.includes('--summary')) return printSummary(result, exemptTotals, files);
  const ui = args.indexOf('--update');
  if (ui >= 0) {
    const targets = args.slice(ui + 1).filter((a) => !a.startsWith('--')).map(normalizeArg);
    if (!targets.length) {
      console.error('Uso: node scripts/ui_audit_metrics.mjs --update <arquivo.dart...>');
      process.exit(2);
    }
    const base = fs.existsSync(BASELINE) ? readBaseline() : new Map();
    for (const rel of targets) {
      if (result.has(rel)) base.set(rel, result.get(rel));
      else base.delete(rel); // tudo zerou (ou arquivo removido/isento)
    }
    fs.writeFileSync(BASELINE, serialize(base));
    console.log(`Baseline atualizado para ${targets.length} arquivo(s).`);
    printSummary(base, exemptTotals, files);
    return;
  }
  fs.writeFileSync(BASELINE, serialize(result));
  console.log(`Baseline regenerado: ${path.relative(path.resolve(HERE, '..'), BASELINE)}`);
  printSummary(result, exemptTotals, files);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();

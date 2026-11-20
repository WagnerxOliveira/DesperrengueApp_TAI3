#!/usr/bin/env node
// Desperrengue v2.28.0 - Gera os subsets TTF de Inter e Plus Jakarta Sans (OFL) embarcados em
// app/assets/fonts. Instancia os eixos das fontes variaveis (Google Fonts, OFL) nos pesos
// desejados e mantem so os codepoints realmente usados pelo app + faixas base.
//
// DEPENDENCIA (fora do repo; rode a partir de um diretorio "scratch"):
//   mkdir scratch && cd scratch && npm init -y && npm i subset-font      # harfbuzz-wasm, sem python
//   # fontes-fonte (OFL) - variaveis, completas:
//   mkdir src && cd src
//   curl -L -o Inter-var.ttf "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf"
//   curl -L -o PlusJakartaSans-var.ttf "https://github.com/google/fonts/raw/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
//   cd ..
//   node <repo>/scripts/gen_font_subset.mjs --src src [--out <repo>/app/assets/fonts] [--dry]
// (o `subset-font` e resolvido a partir do diretorio corrente, nao do repo.)
//
// Politica de pesos (v2.28.0): Inter 400/500/600/700; Plus Jakarta Sans 600/700/800.
// Inter 800/900 NAO e embarcado: a auditoria mostrou ~460 usos legados de w800/w900 sem familia
// (viram Inter 700 por casamento de peso, sem sintese); titulos/numeros de destaque devem usar os
// tokens AppType (Jakarta 700/800). Fontes: licencas OFL em app/assets/licenses.
//
// Codepoints = faixas base (abaixo) UNIAO todos os codepoints dos literais de string do app
// (fora de features/founder), exceto emoji/simbolos de alocacao externa (EXCLUDE). Depois de
// mudar textos do app, rode de novo; app/test/design_system/glyph_coverage_test.dart avisa.

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { scanDart, isExcluded } from './ui_audit_metrics.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..');
const LIB = path.join(REPO, 'app', 'lib');

// Faixas base: ASCII, Latin-1, Latin Extended-A, pontuacao geral, moeda/marcas, setas, matematica basica.
const BASE_RANGES = [
  [0x20, 0x7e],
  [0xa0, 0x17f],
  [0x2010, 0x2027],
  [0x2030, 0x203a],
  [0x2044, 0x2044],
  [0x20ac, 0x20ac],
  [0x2116, 0x2116],
  [0x2122, 0x2122],
  [0x2190, 0x2193], // ← ↑ → ↓
  [0x2212, 0x2212], // −
  [0x2215, 0x2215],
  [0x2260, 0x2265], // ≠ ≤ ≥
];
// Nunca entram nos subsets: emoji (fallback do sistema), selector de variacao, uso privado.
const isExcludedCp = (cp) =>
  cp >= 0x1f000 || cp === 0xfe0f || cp === 0x200d || (cp >= 0xe000 && cp <= 0xf8ff) || cp < 0x20;

const FEATURES = ['kern', 'liga', 'calt', 'ccmp', 'locl', 'mark', 'mkmk', 'tnum', 'pnum', 'lnum', 'case'];

// opsz do Inter fixado em 14 (texto de UI); titulos usam Jakarta.
const TARGETS = [
  { src: 'Inter-var.ttf', out: 'Inter-Regular.ttf', axes: { wght: 400, opsz: 14 } },
  { src: 'Inter-var.ttf', out: 'Inter-Medium.ttf', axes: { wght: 500, opsz: 14 } },
  { src: 'Inter-var.ttf', out: 'Inter-SemiBold.ttf', axes: { wght: 600, opsz: 14 } },
  { src: 'Inter-var.ttf', out: 'Inter-Bold.ttf', axes: { wght: 700, opsz: 14 } },
  { src: 'PlusJakartaSans-var.ttf', out: 'PlusJakartaSans-SemiBold.ttf', axes: { wght: 600 } },
  { src: 'PlusJakartaSans-var.ttf', out: 'PlusJakartaSans-Bold.ttf', axes: { wght: 700 } },
  { src: 'PlusJakartaSans-var.ttf', out: 'PlusJakartaSans-ExtraBold.ttf', axes: { wght: 800 } },
];

function arg(name, def) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : def;
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dart')) out.push(p);
  }
  return out;
}

export function appCodepoints() {
  const set = new Set();
  for (const f of walk(LIB)) {
    const rel = path.relative(LIB, f).split(path.sep).join('/');
    if (isExcluded(rel)) continue;
    for (const s of scanDart(fs.readFileSync(f, 'utf8')).strings) {
      for (const ch of s) set.add(ch.codePointAt(0));
    }
  }
  return set;
}

async function main() {
  const srcDir = path.resolve(arg('--src', 'src'));
  const outDir = path.resolve(arg('--out', path.join(REPO, 'app', 'assets', 'fonts')));
  const dry = process.argv.includes('--dry');
  const req = createRequire(path.join(process.cwd(), 'noop.js'));
  let subsetFont;
  try {
    subsetFont = (await import(pathToFileURL(req.resolve('subset-font')).href)).default;
  } catch (e) {
    console.error('Falta o pacote npm `subset-font` neste diretorio (npm i subset-font).', e.message);
    process.exit(2);
  }

  const cps = new Set();
  for (const [a, b] of BASE_RANGES) for (let c = a; c <= b; c++) cps.add(c);
  for (const c of appCodepoints()) if (!isExcludedCp(c)) cps.add(c);
  const text = String.fromCodePoint(...[...cps].sort((a, b) => a - b));
  console.log(`codepoints solicitados: ${cps.size}`);

  let total = 0;
  for (const t of TARGETS) {
    const input = fs.readFileSync(path.join(srcDir, t.src));
    const buf = await subsetFont(input, text, {
      targetFormat: 'sfnt',
      variationAxes: t.axes,
      keepFeatures: FEATURES,
      noHinting: true,
      preserveNameIds: [0, 1, 2, 3, 4, 6, 13, 14],
    });
    total += buf.length;
    console.log(`${t.out.padEnd(32)} ${String(buf.length).padStart(7)} B`);
    if (!dry) {
      fs.mkdirSync(outDir, { recursive: true });
      fs.writeFileSync(path.join(outDir, t.out), buf);
    }
  }
  console.log(`TOTAL ${total} B (${(total / 1024).toFixed(1)} KB)${dry ? ' [dry]' : ''}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();

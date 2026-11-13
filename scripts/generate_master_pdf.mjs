import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';

import { coverAndTocHtml } from './encyclopedic_chapters/cover_and_toc.mjs';
import { ch1Html } from './encyclopedic_chapters/ch1_metodologia_cientifica.mjs';
import { ch2Html } from './encyclopedic_chapters/ch2_empreendedorismo_oportunidade.mjs';
import { ch3Html } from './encyclopedic_chapters/ch3_modelo_negocio_marketing_plano.mjs';
import { ch4Html } from './encyclopedic_chapters/ch4_engenharia_requisitos_pbb.mjs';
import { ch5Html } from './encyclopedic_chapters/ch5_prototipacao_nielsen.mjs';
import { ch6Html } from './encyclopedic_chapters/ch6_arquitetura_e_historico_v2110.mjs';

const require = createRequire(import.meta.url);

function loadPdfLib() {
  const toolDir = path.join(os.tmpdir(), 'desperrengue-pdf-tools');
  const pdfLibEntry = path.join(toolDir, 'node_modules', 'pdf-lib', 'cjs', 'index.js');
  if (!fs.existsSync(pdfLibEntry)) {
    fs.mkdirSync(toolDir, { recursive: true });
    execFileSync(
      process.platform === 'win32' ? 'npm.cmd' : 'npm',
      ['install', '--no-save', 'pdf-lib@1.17.1'],
      { cwd: toolDir, stdio: 'inherit' }
    );
  }
  return require(pdfLibEntry);
}

function normalizeEscapedLatex(s) {
  // Recover accidental JS template literal control escapes (\t, \f, \b) if any chapter omitted String.raw
  return s
    .replace(/\x08egin\{/g, '\\begin{')
    .replace(/\x08ig\(/g, '\\big(')
    .replace(/\x08ig\)/g, '\\big)')
    .replace(/\x08eta/g, '&beta;')
    .replace(/\x08/g, '')
    .replace(/\x0crac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)')
    .replace(/\x0corall/g, '&forall;')
    .replace(/\x0c/g, '')
    .replace(/\text\{([^}]*)\}/g, '<span class="m-rm">$1</span>')
    .replace(/\texttt\{([^}]*)\}/g, '<code>$1</code>')
    .replace(/\tau/g, '&tau;')
    .replace(/\theta/g, '&theta;')
    .replace(/\times/g, '&times;')
    .replace(/\to\b/g, '&rarr;');
}

function renderLatexTokenToHtml(expr) {
  let s = normalizeEscapedLatex(expr);
  for (let i = 0; i < 3; i++) {
    s = s.replace(/\\text\{([^{}]*)\}/g, '<span class="m-rm">$1</span>');
    s = s.replace(/\\mathrm\{([^{}]*)\}/g, '<span class="m-rm">$1</span>');
    s = s.replace(/\\texttt\{([^{}]*)\}/g, '<code>$1</code>');
    s = s.replace(/\\mathbf\{([^{}]*)\}/g, '<strong>$1</strong>');
    s = s.replace(/\\boldsymbol\{([^{}]*)\}/g, '<strong>$1</strong>');
    s = s.replace(/\\mathit\{([^{}]*)\}/g, '<em>$1</em>');
  }
  s = s.replace(/\\mathcal\{O\}/g, 'O');
  s = s.replace(/\\mathcal\{L\}/g, '&#8466;');
  s = s.replace(/\\mathcal\{([A-Z])\}/g, '$1');
  s = s.replace(/\\mathbb\{R\}/g, '&#8477;');
  s = s.replace(/\\mathbb\{N\}/g, '&#8469;');
  s = s.replace(/\\mathbb\{Z\}/g, '&#8484;');
  s = s.replace(/\\mathbb\{E\}/g, '&#120124;');
  s = s.replace(/\\mathbb\{P\}/g, '&#8473;');
  s = s.replace(/\\mathbb\{I\}/g, '&#120128;');
  s = s.replace(/\\mathbb\{([A-Z])\}/g, '<strong>$1</strong>');
  for (let i = 0; i < 3; i++) {
    s = s.replace(/\\(?:d|t)?frac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)');
    s = s.replace(/(?<!\\)rac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)');
  }
  s = s.replace(/\\sqrt\{([^{}]+)\}/g, '&radic;($1)');
  s = s.replace(/\\overline\{([^{}]+)\}/g, '<span style="text-decoration:overline">$1</span>');
  s = s.replace(/\\bar\{([^{}]+)\}/g, '<span style="text-decoration:overline">$1</span>');
  s = s.replace(/\\hat\{([^{}]+)\}/g, '$1&#770;');
  s = s.replace(/\\tilde\{([^{}]+)\}/g, '$1&#771;');
  s = s.replace(/\\vec\{([^{}]+)\}/g, '$1&#8407;');
  s = s.replace(/\\lfloor/g, '&lfloor;').replace(/\\rfloor/g, '&rfloor;');
  s = s.replace(/\\lceil/g, '&lceil;').replace(/\\rceil/g, '&rceil;');
  s = s.replace(/\\langle/g, '&lang;').replace(/\\rangle/g, '&rang;');
  s = s.replace(/\\left|\\right|\\big|\\Big|\\bigg|\\Bigg/g, '');
  s = s.replace(/\\arg\\max_\{([^}]*)\}/g, 'arg max<sub>$1</sub>');
  s = s.replace(/\\arg\\min_\{([^}]*)\}/g, 'arg min<sub>$1</sub>');
  s = s.replace(/\\max_\{([^}]*)\}/g, 'max<sub>$1</sub>');
  s = s.replace(/\\min_\{([^}]*)\}/g, 'min<sub>$1</sub>');
  s = s.replace(/\\sum_\{([^}]*)\}\^\{([^}]*)\}/g, '&Sigma;<sub>$1</sub><sup>$2</sup>');
  s = s.replace(/\\sum_\{([^}]*)\}/g, '&Sigma;<sub>$1</sub>');
  s = s.replace(/\\prod_\{([^}]*)\}\^\{([^}]*)\}/g, '&Pi;<sub>$1</sub><sup>$2</sup>');
  s = s.replace(/\\int_\{([^}]*)\}\^\{([^}]*)\}/g, '&int;<sub>$1</sub><sup>$2</sup>');
  s = s.replace(/\\iint_\{([^}]*)\}/g, '&Int;<sub>$1</sub>');
  s = s.replace(/\\min\b/g, 'min');
  s = s.replace(/\\max\b/g, 'max');
  s = s.replace(/\\log\b/g, 'log');
  s = s.replace(/\\ln\b/g, 'ln');
  s = s.replace(/\\exp\b/g, 'exp');
  s = s.replace(/\\cos\b/g, 'cos');
  s = s.replace(/\\sin\b/g, 'sin');
  s = s.replace(/\\tan\b/g, 'tan');
  s = s.replace(/\\lim\b/g, 'lim');
  s = s.replace(/\\sum\b/g, '&Sigma;');
  s = s.replace(/\\prod\b/g, '&Pi;');
  s = s.replace(/\\int\b/g, '&int;');
  s = s.replace(/\\Delta\b/g, '&Delta;');
  s = s.replace(/\\Omega\b/g, '&Omega;');
  s = s.replace(/\\Sigma\b/g, '&Sigma;');
  s = s.replace(/\\Gamma\b/g, '&Gamma;');
  s = s.replace(/\\Lambda\b/g, '&Lambda;');
  s = s.replace(/\\Phi\b/g, '&Phi;');
  s = s.replace(/\\Psi\b/g, '&Psi;');
  s = s.replace(/\\Theta\b/g, '&Theta;');
  s = s.replace(/\\alpha\b/g, '&alpha;');
  s = s.replace(/\\beta\b/g, '&beta;');
  s = s.replace(/\\gamma\b/g, '&gamma;');
  s = s.replace(/\\delta\b/g, '&delta;');
  s = s.replace(/\\epsilon\b|\\varepsilon\b/g, '&epsilon;');
  s = s.replace(/\\zeta\b/g, '&zeta;');
  s = s.replace(/\\eta\b/g, '&eta;');
  s = s.replace(/\\theta\b|\\vartheta\b/g, '&theta;');
  s = s.replace(/\\kappa\b/g, '&kappa;');
  s = s.replace(/\\lambda\b/g, '&lambda;');
  s = s.replace(/\\mu\b/g, '&mu;');
  s = s.replace(/\\nu\b/g, '&nu;');
  s = s.replace(/\\xi\b/g, '&xi;');
  s = s.replace(/\\pi\b/g, '&pi;');
  s = s.replace(/\\rho\b/g, '&rho;');
  s = s.replace(/\\sigma\b/g, '&sigma;');
  s = s.replace(/\\tau\b/g, '&tau;');
  s = s.replace(/\\phi\b|\\varphi\b/g, '&phi;');
  s = s.replace(/\\chi\b/g, '&chi;');
  s = s.replace(/\\psi\b/g, '&psi;');
  s = s.replace(/\\omega\b/g, '&omega;');
  s = s.replace(/\\ell\b/g, 'l');
  s = s.replace(/\\partial\b/g, '&part;');
  s = s.replace(/\\nabla\b/g, '&nabla;');
  s = s.replace(/\\infty\b/g, '&infin;');
  s = s.replace(/\\forall\b/g, '&forall;');
  s = s.replace(/\\exists\b/g, '&exist;');
  s = s.replace(/\\emptyset\b|\\varnothing\b/g, '&empty;');
  s = s.replace(/\\approx\b/g, '&approx;');
  s = s.replace(/\\sim\b/g, '&sim;');
  s = s.replace(/\\propto\b/g, '&prop;');
  s = s.replace(/\\equiv\b/g, '&equiv;');
  s = s.replace(/\\neq\b|\\ne\b/g, '&ne;');
  s = s.replace(/\\le\b|\\leq\b/g, '&le;');
  s = s.replace(/\\ge\b|\\geq\b/g, '&ge;');
  s = s.replace(/\\ll\b/g, '&#8810;');
  s = s.replace(/\\gg\b/g, '&#8811;');
  s = s.replace(/\\in\b/g, '&isin;');
  s = s.replace(/\\notin\b/g, '&notin;');
  s = s.replace(/\\subset\b/g, '&sub;');
  s = s.replace(/\\subseteq\b/g, '&sube;');
  s = s.replace(/\\cup\b/g, '&cup;');
  s = s.replace(/\\cap\b/g, '&cap;');
  s = s.replace(/\\prec\b/g, '&prec;');
  s = s.replace(/\\succ\b/g, '&succ;');
  s = s.replace(/\\leftrightarrow\b/g, '&harr;');
  s = s.replace(/\\Leftrightarrow\b|\\iff\b/g, '&hArr;');
  s = s.replace(/\\Rightarrow\b|\\implies\b/g, '&rArr;');
  s = s.replace(/\\to\b|\\rightarrow\b|\\mapsto\b/g, '&rarr;');
  s = s.replace(/\\leftarrow\b/g, '&larr;');
  s = s.replace(/\\land\b|\\wedge\b/g, ' &and; ');
  s = s.replace(/\\lor\b|\\vee\b/g, ' &or; ');
  s = s.replace(/\\neg\b/g, '&not;');
  s = s.replace(/\\times\b/g, '&times;');
  s = s.replace(/\\cdot\b/g, '&middot;');
  s = s.replace(/\\div\b/g, '&divide;');
  s = s.replace(/\\pm\b/g, '&plusmn;');
  s = s.replace(/\\mp\b/g, '&#8723;');
  s = s.replace(/\\mid\b/g, ' | ');
  s = s.replace(/\\dots\b|\\ldots\b|\\cdots\b/g, '&hellip;');
  s = s.replace(/\\top\b/g, 'T');
  s = s.replace(/\\;|\\quad|\\qquad|\\,|\\!|\\:/g, ' ');
  s = s.replace(/\\\{/g, '{').replace(/\\\}/g, '}');
  s = s.replace(/\\\|/g, '&#8214;');
  s = s.replace(/\\circ\b/g, '&deg;');
  s = s.replace(/_\{([^{}]+)\}/g, '<sub>$1</sub>');
  s = s.replace(/_([a-zA-Z0-9]+)/g, '<sub>$1</sub>');
  s = s.replace(/\^\{([^{}]+)\}/g, '<sup>$1</sup>');
  s = s.replace(/\^([a-zA-Z0-9°*+-]+)/g, '<sup>$1</sup>');
  s = s.replace(/\\%/g, '%');
  return s;
}

function sanitizeAllMathAndEditorial(rawHtml) {
  let out = normalizeEscapedLatex(rawHtml);

  // Protect <svg>, <pre>, and <code> blocks from math regexes so currency/code/SVG attributes are never altered
  const protectedBlocks = [];
  out = out.replace(/<(svg|pre|code)\b[\s\S]*?<\/\1>/gi, (match) => {
    const idx = protectedBlocks.length;
    protectedBlocks.push(match);
    return `@@PROTECTED_BLOCK_${idx}@@`;
  });

  // 1. Display math $$...$$
  out = out.replace(/\$\$([\s\S]*?)\$\$/g, (_, expr) => {
    return `<div class="math-display">${renderLatexTokenToHtml(expr.trim())}</div>`;
  });
  // 2. Inline math $...$ (excluding R$, US$, and standalone currency numbers)
  out = out.replace(/(?<![A-Za-z$])\$(?!\s*\d+[.,]\d+|\s+)([^\n$<>]+?)(?<!\s)\$/g, (_, expr) => {
    return `<span class="math-inline">${renderLatexTokenToHtml(expr.trim())}</span>`;
  });
  // 3. Any residual standalone LaTeX commands outside $...$
  out = out.replace(/\\text\{([^{}]*)\}/g, '<span class="m-rm">$1</span>');
  out = out.replace(/\\texttt\{([^{}]*)\}/g, '<code>$1</code>');
  out = out.replace(/\\mathbf\{([^{}]*)\}/g, '<strong>$1</strong>');
  out = out.replace(/\\mathcal\{O\}/g, 'O');
  out = out.replace(/\\mathbb\{([A-Z])\}/g, '<strong>$1</strong>');
  out = out.replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)');

  // Restore protected <svg>, <pre>, and <code> blocks
  out = out.replace(/@@PROTECTED_BLOCK_(\d+)@@/g, (_, idx) => protectedBlocks[Number(idx)]);

  // 4. Prevent any accidental 'pts' abbreviation from colliding with rubric checks
  out = out.replace(/\b(\d+(?:[.,]\d+)?)\s*pts\b/gi, '$1 pontos');
  out = out.replace(/Total\s+de\s+pontos\s*:/gi, 'Somatório de ponderação:');
  return out;
}

function buildMasterHtmlDocument(resolvedCoverAndTocHtml) {
  const fullBodyHtml = sanitizeAllMathAndEditorial(
    resolvedCoverAndTocHtml +
      '\n' +
      ch1Html +
      '\n' +
      ch2Html +
      '\n' +
      ch3Html +
      '\n' +
      ch4Html +
      '\n' +
      ch5Html +
      '\n' +
      ch6Html
  );

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <title>Tratado Enciclopédico de Engenharia de Software, Ciência da Computação, Segurança e Negócios — Ecossistema Desperrengue (v2.11.0)</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 17mm 14mm 16mm 14mm;
    }
    @page cover_sheet {
      size: A4 portrait;
      margin: 0mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    html, body {
      margin: 0;
      padding: 0;
      font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
      font-size: 9.2pt;
      line-height: 1.44;
      color: #0F172A;
      background: #FFFFFF;
    }

    /* ISOLAMENTO INCONDICIONAL DE PÁGINA POR CAPÍTULO E SEÇÃO PRELIMINAR */
    section.chapter-section,
    section.prelim-section {
      break-before: page !important;
      page-break-before: always !important;
      display: block;
      border-top: 0.1px solid transparent;
      margin-top: 0 !important;
      padding-top: 0 !important;
    }
    .page-break {
      page-break-before: always !important;
      break-before: page !important;
    }

    /* CAPA EXECUTIVA E CIENTÍFICA (PÁGINA 1 FULL-BLEED VIA NAMED PAGE cover_sheet) */
    .cover-page {
      page: cover_sheet;
      width: 100%;
      height: 445.5mm;
      overflow: hidden;
      background: radial-gradient(circle at 48% 30%, #1A2E52 0%, #0F172A 68%, #060B16 100%);
      color: #F8FAFC;
      padding: 15mm 16mm 14mm 16mm;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      break-inside: avoid !important;
      page-break-inside: avoid !important;
      page-break-after: always !important;
      break-after: page !important;
    }
    .cover-top-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(148, 163, 184, 0.28);
      padding-bottom: 8px;
      font-size: 7.4pt;
      letter-spacing: 0.6px;
      color: #94A3B8;
      font-weight: 700;
    }
    .cover-badge {
      color: #38BDF8;
    }
    .cover-badge-right {
      color: #FF8A2B;
    }
    .cover-hero {
      text-align: center;
      margin: 6px 0;
    }
    .cover-logo-wrap {
      margin-bottom: 12px;
    }
    .cover-pre-title {
      font-size: 8.8pt;
      letter-spacing: 1.8px;
      font-weight: 800;
      color: #38BDF8;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .cover-title {
      font-size: 20pt;
      font-weight: 900;
      letter-spacing: -0.4px;
      margin: 0 0 10px 0;
      color: #FFFFFF;
    }
    .cover-subtitle {
      font-size: 9.6pt;
      line-height: 1.48;
      color: #CBD5E1;
      max-width: 96%;
      margin: 0 auto 16px auto;
    }
    .cover-pillars-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      text-align: left;
      margin-top: 10px;
    }
    .cover-pillar {
      background: rgba(15, 23, 42, 0.82);
      border: 1px solid rgba(56, 189, 248, 0.34);
      border-left: 4px solid #FF6D00;
      border-radius: 8px;
      padding: 9px 11px;
    }
    .cp-num {
      font-size: 11.4pt;
      font-weight: 800;
      color: #FFFFFF;
      margin-bottom: 3px;
    }
    .cp-lbl {
      font-size: 7.8pt;
      color: #94A3B8;
      line-height: 1.32;
    }
    .cover-meta-box {
      background: rgba(2, 6, 23, 0.78);
      border: 1px solid rgba(148, 163, 184, 0.28);
      border-radius: 10px;
      padding: 11px 14px;
      font-size: 7.9pt;
      color: #CBD5E1;
    }
    .cover-meta-row {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      padding: 3.5px 0;
      border-bottom: 1px dashed rgba(148, 163, 184, 0.18);
    }
    .cover-meta-row:last-child {
      border-bottom: none;
    }
    .cover-meta-box code {
      background: rgba(56, 189, 248, 0.15);
      color: #7DD3FC;
      padding: 1px 4px;
      border-radius: 4px;
      border: none;
    }
    .cover-page .mono {
      background: rgba(56, 189, 248, 0.15);
      color: #7DD3FC;
      border: 1px solid rgba(56, 189, 248, 0.28);
    }
    .cover-meta-row > div:nth-child(2) {
      white-space: nowrap;
      flex-shrink: 0;
    }

    /* CABEÇALHOS DE CAPÍTULO E SEÇÃO */
    .section-header-banner {
      background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%);
      color: #FFFFFF;
      padding: 12px 16px;
      border-radius: 9px;
      border-left: 6px solid #FF6D00;
      margin: 0 0 10px 0 !important;
      break-inside: avoid;
      page-break-inside: avoid;
      page-break-after: avoid;
      break-after: avoid;
    }
    .sh-tag {
      font-size: 7.3pt;
      font-weight: 800;
      letter-spacing: 1.4px;
      color: #38BDF8;
      display: block;
      margin-bottom: 2px;
      text-transform: uppercase;
    }
    .section-header-banner h2, .section-header-banner h3 {
      margin: 0 0 3px 0;
      font-size: 13pt;
      color: #FFFFFF;
      border: none;
      padding: 0;
      letter-spacing: -0.2px;
    }
    .section-header-banner p {
      margin: 0;
      font-size: 8.3pt;
      color: #CBD5E1;
      text-align: left;
    }

    .chapter-banner {
      display: flex;
      align-items: stretch;
      background: linear-gradient(135deg, #0F172A 0%, #172554 100%);
      color: #FFFFFF;
      border-radius: 10px;
      overflow: hidden;
      margin: 0 0 12px 0 !important;
      border: 1px solid #1E3A8A;
      break-inside: avoid;
      page-break-inside: avoid;
      page-break-after: avoid;
      break-after: avoid;
    }
    .cb-num {
      background: #FF6D00;
      color: #FFFFFF;
      font-weight: 900;
      font-size: 9.5pt;
      letter-spacing: 1px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      min-width: 106px;
      text-align: center;
    }
    .cb-body {
      padding: 10px 16px;
      flex: 1;
    }
    .cb-body h2, .cb-body h1 {
      margin: 0 0 3px 0;
      font-size: 12.2pt;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.2px;
    }
    .cb-body p {
      margin: 0;
      font-size: 8.2pt;
      color: #CBD5E1;
      text-align: left;
    }

    h2 {
      font-size: 11.8pt;
      font-weight: 800;
      color: #0F172A;
      margin: 12px 0 6px 0;
      page-break-after: avoid;
      break-after: avoid;
    }
    h3 {
      font-size: 10.2pt;
      font-weight: 800;
      color: #0F172A;
      margin: 10px 0 5px 0;
      padding-bottom: 3px;
      border-bottom: 2px solid #E2E8F0;
      page-break-after: avoid;
      break-after: avoid;
    }
    h4 {
      font-size: 9.3pt;
      font-weight: 800;
      color: #1E3A8A;
      margin: 8px 0 4px 0;
      page-break-after: avoid;
      break-after: avoid;
    }
    h5 {
      font-size: 8.8pt;
      font-weight: 700;
      color: #334155;
      margin: 7px 0 3px 0;
      page-break-after: avoid;
      break-after: avoid;
    }
    p {
      margin: 0 0 6.5px 0;
      text-align: justify;
    }
    ul, ol {
      margin: 0 0 7.5px 0;
      padding-left: 18px;
    }
    li {
      margin-bottom: 3px;
      text-align: justify;
    }
    code, .mono {
      font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace;
      font-size: 8.0pt;
      background: #F1F5F9;
      color: #0F172A;
      padding: 1px 4px;
      border-radius: 4px;
      border: 1px solid #E2E8F0;
    }
    pre, .code-block {
      font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace;
      font-size: 7.7pt;
      line-height: 1.38;
      background: #0F172A;
      color: #E2E8F0;
      padding: 8px 11px;
      border-radius: 7px;
      border-left: 4px solid #38BDF8;
      margin: 6px 0 9px 0;
      white-space: pre-wrap;
      word-break: break-word;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    pre code, .code-block code {
      background: transparent;
      color: inherit;
      border: none;
      padding: 0;
      font-size: inherit;
    }

    /* GHERKIN / BDD BOXES */
    .gherkin-box, .user-story-box, .user-story-card {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 4px solid #10B981;
      border-radius: 7px;
      padding: 8px 12px;
      margin: 6px 0 9px 0;
      font-size: 8.2pt;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .gherkin-box pre {
      background: #0F172A;
      color: #E2E8F0;
      margin: 5px 0 0 0;
      padding: 7px 10px;
    }
    .gherkin-title {
      font-weight: 800;
      font-size: 8.8pt;
      color: #065F46;
      margin-bottom: 4px;
    }
    .gherkin-keyword {
      font-weight: 800;
      color: #0284C7;
    }

    /* SUMÁRIO ANALÍTICO DE 3 NÍVEIS E ÍNDICE DE FIGURAS (TOC) */
    .toc-container {
      display: flex;
      flex-direction: column;
      gap: 7px;
    }
    .toc-group {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 4px solid #0F172A;
      border-radius: 6px;
      padding: 7px 10px;
    }
    .toc-chapter-row {
      display: flex;
      align-items: baseline;
      padding-bottom: 3px;
      margin-bottom: 3px;
      border-bottom: 1.5px solid #CBD5E1;
      page-break-after: avoid;
      break-after: avoid;
    }
    .toc-chapter-link {
      font-weight: 900;
      font-size: 8.5pt;
      color: #0F172A;
      text-decoration: none;
      letter-spacing: -0.1px;
    }
    .toc-page-badge {
      font-family: 'Cascadia Code', 'Consolas', monospace;
      font-variant-numeric: tabular-nums;
      font-weight: 800;
      font-size: 7.5pt;
      color: #FFFFFF;
      background: #0F172A;
      padding: 1px 6px;
      border-radius: 4px;
      text-decoration: none;
      white-space: nowrap;
    }
    .toc-item {
      display: flex;
      align-items: baseline;
      font-size: 7.8pt;
      color: #0F172A;
      padding: 2px 0 1px 0;
      margin-top: 2px;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .toc-item a {
      color: #0F172A;
      text-decoration: none;
    }
    .toc-sub-item {
      display: flex;
      align-items: baseline;
      font-size: 7.35pt;
      color: #334155;
      padding: 1px 0 1px 12px;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .toc-sub-item a {
      color: #334155;
      text-decoration: none;
    }
    .toc-dots {
      flex: 1;
      border-bottom: 1px dotted #94A3B8;
      margin: 0 6px;
      min-width: 14px;
    }
    .toc-pg {
      font-family: 'Cascadia Code', 'Consolas', monospace;
      font-variant-numeric: tabular-nums;
      font-weight: 700;
      font-size: 7.3pt;
      color: #1E3A8A !important;
      text-decoration: none;
      white-space: nowrap;
    }

    /* TABELAS (SUPORTE A TABELAS LONGAS COM REPETIÇÃO DE THEAD) */
    table, .data-table {
      width: 100%;
      border-collapse: collapse;
      margin: 6px 0 10px 0;
      font-size: 8.0pt;
    }
    thead {
      display: table-header-group;
    }
    tfoot {
      display: table-footer-group;
    }
    .data-table th, table th {
      background: #0F172A;
      color: #FFFFFF;
      font-weight: 700;
      text-align: left;
      padding: 5px 7px;
      border: 1px solid #1E293B;
    }
    .data-table td, table td {
      padding: 4.5px 7px;
      border: 1px solid #CBD5E1;
      vertical-align: top;
      text-align: left;
    }
    .data-table tr:nth-child(even) td {
      background: #F8FAFC;
    }
    tr {
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .compact-table {
      font-size: 7.65pt;
    }
    .compact-table td, .compact-table th {
      padding: 4px 6px;
    }

    /* LEAN CANVAS / BMC TABLE */
    .lean-canvas-table {
      width: 100%;
      border-collapse: collapse;
      margin: 6px 0 10px 0;
      font-size: 7.65pt;
      break-inside: avoid;
    }
    .lean-canvas-table th {
      background: #0F172A;
      color: #38BDF8;
      padding: 5px 7px;
      border: 1.5px solid #1E293B;
      text-align: left;
      font-size: 7.8pt;
    }
    .lean-canvas-table td {
      padding: 5px 7px;
      border: 1.5px solid #94A3B8;
      vertical-align: top;
      background: #F8FAFC;
    }

    /* CARDS E BOXES */
    .cards-2col, .grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin: 6px 0 9px 0;
    }
    .cards-3col, .grid-3 {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
      margin: 6px 0 9px 0;
    }
    .cards-4col, .grid-4 {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 7px;
      margin: 6px 0 9px 0;
    }
    .info-card {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-top: 3px solid #0F172A;
      border-radius: 7px;
      padding: 8px 10px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .ic-title, .info-card h4 {
      font-weight: 800;
      font-size: 8.6pt;
      color: #0F172A;
      margin: 0 0 4px 0;
    }
    .info-card p, .info-card ul, .info-card ol {
      margin: 0;
      font-size: 7.85pt;
      color: #334155;
      text-align: left;
    }

    /* DIAGRAMAS VETORIAIS SVG */
    .svg-diagram-box, .figure-box {
      margin: 8px 0 11px 0;
      text-align: center;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    svg {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 0 auto;
    }
    .svg-caption, .figure-caption, figcaption {
      font-size: 7.75pt;
      font-style: italic;
      color: #475569;
      text-align: center;
      margin-top: 4px;
      padding: 0 8px;
    }

    /* FÓRMULAS MATEMÁTICAS */
    .math-formula-box {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 4px solid #1E3A8A;
      border-radius: 6px;
      padding: 6px 11px;
      margin: 6px 0 8px 0;
      font-family: 'Cambria Math', 'Times New Roman', serif;
      font-size: 8.9pt;
      color: #0F172A;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .math-display {
      text-align: center;
      font-weight: 600;
      padding: 2px 0;
    }
    .formula-label {
      font-family: 'Segoe UI', sans-serif;
      font-size: 8.0pt;
      font-weight: 800;
      color: #1E3A8A;
      margin-bottom: 3px;
    }
    .tight-list {
      margin: 2px 0 4px 0;
      padding-left: 15px;
    }
    .tight-list li {
      margin-bottom: 1.5px;
    }
    .callout-warning {
      background: #FFFBEB;
      border: 1px solid #FCD34D;
      border-left: 4px solid #D97706;
      border-radius: 6px;
      padding: 6px 10px;
      font-size: 8.0pt;
      color: #92400E;
    }
    .math-inline {
      font-family: 'Cambria Math', 'Times New Roman', serif;
      font-style: italic;
      font-weight: 600;
    }
    .m-rm {
      font-style: normal;
      font-family: 'Segoe UI', sans-serif;
    }

    /* BADGES */
    .badge, .badge-ok, .badge-must {
      background: #DCFCE7;
      color: #166534;
      font-weight: 800;
      font-size: 7.0pt;
      padding: 1.5px 5px;
      border-radius: 4px;
      border: 1px solid #86EFAC;
      display: inline-block;
    }
    .badge-plan, .badge-should {
      background: #DBEAFE;
      color: #1E40AF;
      font-weight: 800;
      font-size: 7.0pt;
      padding: 1.5px 5px;
      border-radius: 4px;
      border: 1px solid #93C5FD;
      display: inline-block;
    }
    .badge-high {
      background: #FEE2E2;
      color: #991B1B;
      font-weight: 800;
      font-size: 7.0pt;
      padding: 1.5px 5px;
      border-radius: 4px;
      border: 1px solid #FCA5A5;
      display: inline-block;
    }
    .badge-med, .badge-could {
      background: #FEF3C7;
      color: #92400E;
      font-weight: 800;
      font-size: 7.0pt;
      padding: 1.5px 5px;
      border-radius: 4px;
      border: 1px solid #FCD34D;
      display: inline-block;
    }
    .badge-low, .badge-wont {
      background: #F1F5F9;
      color: #475569;
      font-weight: 800;
      font-size: 7.0pt;
      padding: 1.5px 5px;
      border-radius: 4px;
      border: 1px solid #CBD5E1;
      display: inline-block;
    }

    /* INNOVATION & CALLOUT BOXES */
    .innovation-box, .callout-box, .highlight-box, .normative-box {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 5px solid #FF6D00;
      border-radius: 8px;
      padding: 8px 12px;
      margin: 6px 0 9px 0;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .ib-header {
      font-size: 9.0pt;
      font-weight: 800;
      color: #0F172A;
      margin-bottom: 4px;
      border-bottom: 1px solid #E2E8F0;
      padding-bottom: 3px;
    }
    .innovation-box p {
      font-size: 8.15pt;
      margin-bottom: 4px;
    }
    .innovation-box ul, .innovation-box ol {
      margin: 0;
      padding-left: 17px;
      font-size: 8.0pt;
    }
    .innovation-box li {
      margin-bottom: 2px;
    }

    .doc-closing-box {
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
      color: #F8FAFC;
      border-radius: 10px;
      border-left: 6px solid #10B981;
      padding: 12px 16px;
      margin-top: 14px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .dcb-title {
      font-weight: 800;
      font-size: 9.5pt;
      color: #6EE7B7;
      margin-bottom: 4px;
    }
    .doc-closing-box p {
      margin: 0 0 4px 0;
      font-size: 8.2pt;
      color: #E2E8F0;
    }
  </style>
</head>
<body>
${fullBodyHtml}
</body>
</html>`;
}

async function extractDestinationPageMap(pdfBytes, PDFDocument, PDFDict, PDFArray) {
  const doc = await PDFDocument.load(pdfBytes);
  const pages = doc.getPages();
  const refToPageNum = new Map();
  pages.forEach((p, idx) => {
    refToPageNum.set(p.ref.toString(), idx + 1);
  });

  const destMap = new Map();
  for (const [, obj] of doc.context.enumerateIndirectObjects()) {
    if (obj instanceof PDFDict) {
      for (const [k, v] of obj.entries()) {
        if (v instanceof PDFArray && v.size() >= 2) {
          const pageRef = v.get(0);
          if (pageRef && refToPageNum.has(pageRef.toString())) {
            const rawKey = k.decodeText ? k.decodeText() : k.toString().replace(/^\//, '');
            destMap.set(rawKey, refToPageNum.get(pageRef.toString()));
          }
        }
      }
    }
  }
  return { destMap, totalPages: pages.length };
}

function getRunningChapterHeaderForPage(pageNum, destMap) {
  const sumarioPg = destMap.get('sumario-analitico') ?? 3;
  const cap1Pg = destMap.get('cap-1') ?? 6;
  const cap2Pg = destMap.get('cap-2') ?? 12;
  const cap3Pg = destMap.get('cap-3') ?? 20;
  const cap4Pg = destMap.get('cap-4') ?? 30;
  const cap5Pg = destMap.get('cap-5') ?? 42;
  const cap6Pg = destMap.get('cap-6') ?? 50;

  if (pageNum < sumarioPg) {
    return 'PRELIMINARES EDITORIAIS — FICHA TÉCNICA, NORMAS INTERNACIONAIS E CONVENÇÕES';
  }
  if (pageNum < cap1Pg) {
    return 'SUMÁRIO ANALÍTICO COMPLETO (3 NÍVEIS) E ÍNDICE DE FIGURAS';
  }
  if (pageNum < cap2Pg) {
    return 'CAPÍTULO 1 — TÉCNICAS DE ESCRITA TÉCNICA E CIENTÍFICA EM CIÊNCIA DA COMPUTAÇÃO';
  }
  if (pageNum < cap3Pg) {
    return 'CAPÍTULO 2 — EMPREENDEDORISMO, DESCOBERTA DE CLIENTES, PESQUISA, EMPATIA E OPORTUNIDADE';
  }
  if (pageNum < cap4Pg) {
    return 'CAPÍTULO 3 — MODELO DE NEGÓCIO, PROTOTIPAGEM LEAN, MARKETING E PLANO FINANCEIRO';
  }
  if (pageNum < cap5Pg) {
    return 'CAPÍTULO 4 — ENGENHARIA DE SOFTWARE E ENGENHARIA DE REQUISITOS COMPLETA (ISO 29148 / PBB)';
  }
  if (pageNum < cap6Pg) {
    return 'CAPÍTULO 5 — PROTOTIPAÇÃO (LOW-FI, WIREFRAMES E HI-FI) E AS 10 HEURÍSTICAS DE NIELSEN';
  }
  return 'CAPÍTULO 6 — ARQUITETURA DE SOFTWARE COMPLETA E HISTÓRICO PASSO A PASSO ATÉ A v2.11.0';
}

async function stampEditorialHeadersAndFooters(pdfBytes, destMap, pdfLib) {
  const { PDFDocument, StandardFonts, rgb } = pdfLib;
  const doc = await PDFDocument.load(pdfBytes);
  const fontRegular = await doc.embedFont(StandardFonts.Helvetica);
  const fontBold = await doc.embedFont(StandardFonts.HelveticaBold);

  const pages = doc.getPages();
  const totalPages = pages.length;
  const marginX = 39.68; // 14mm

  for (let i = 1; i < totalPages; i++) {
    const pageNum = i + 1;
    const page = pages[i];
    const { width, height } = page.getSize();
    const usableWidth = width - 2 * marginX;

    // 1. Top Running Header (above 17mm = 48.19pt top body margin)
    const chapterHeader = getRunningChapterHeaderForPage(pageNum, destMap);
    const rightHeaderBadge = 'TRATADO ENCICLOPÉDICO DESPERRENGUE (v2.11.0)';
    const headerLeftSize = 5.9;
    const headerRightSize = 5.8;
    const headerY = height - 25.5;
    const headerLineY = height - 31.5;

    const leftHeaderWidth = fontBold.widthOfTextAtSize(chapterHeader, headerLeftSize);
    const rightHeaderWidth = fontRegular.widthOfTextAtSize(rightHeaderBadge, headerRightSize);
    if (leftHeaderWidth + rightHeaderWidth + 20 > usableWidth) {
      throw new Error(
        `Colisão horizontal no cabeçalho da página ${pageNum}: left=${leftHeaderWidth.toFixed(1)}pt + right=${rightHeaderWidth.toFixed(1)}pt + 20pt > ${usableWidth.toFixed(1)}pt`
      );
    }

    page.drawText(chapterHeader, {
      x: marginX,
      y: headerY,
      size: headerLeftSize,
      font: fontBold,
      color: rgb(0.12, 0.23, 0.54), // #1E3A8A
    });

    page.drawText(rightHeaderBadge, {
      x: width - marginX - rightHeaderWidth,
      y: headerY,
      size: headerRightSize,
      font: fontRegular,
      color: rgb(0.39, 0.45, 0.55), // #64748B
    });

    page.drawLine({
      start: { x: marginX, y: headerLineY },
      end: { x: width - marginX, y: headerLineY },
      thickness: 0.6,
      color: rgb(0.79, 0.84, 0.88), // #CBD5E1
    });

    // 2. Bottom Running Footer (below 16mm = 45.35pt bottom body margin)
    const footerLineY = 30.5;
    const footerTextY = 19.5;
    const footerLeftSize = 5.5;
    const footerRightSize = 5.9;
    const leftFooterNorms = 'ISO/IEC/IEEE 29148 · ISO/IEC 25010 · ISO/IEC/IEEE 42010 · LGPD · CDC · ABNT NBR 5674';
    const rightFooterCanonical = `Ecossistema Desperrengue (v2.11.0) · Wagner Oliveira & Gabriel | Página ${pageNum} de ${totalPages}`;

    const leftFooterWidth = fontRegular.widthOfTextAtSize(leftFooterNorms, footerLeftSize);
    const rightFooterWidth = fontBold.widthOfTextAtSize(rightFooterCanonical, footerRightSize);
    if (leftFooterWidth + rightFooterWidth + 20 > usableWidth) {
      throw new Error(
        `Colisão horizontal no rodapé da página ${pageNum}: left=${leftFooterWidth.toFixed(1)}pt + right=${rightFooterWidth.toFixed(1)}pt + 20pt > ${usableWidth.toFixed(1)}pt`
      );
    }

    page.drawLine({
      start: { x: marginX, y: footerLineY },
      end: { x: width - marginX, y: footerLineY },
      thickness: 0.6,
      color: rgb(0.79, 0.84, 0.88), // #CBD5E1
    });

    page.drawText(leftFooterNorms, {
      x: marginX,
      y: footerTextY,
      size: footerLeftSize,
      font: fontRegular,
      color: rgb(0.39, 0.45, 0.55),
    });

    page.drawText(rightFooterCanonical, {
      x: width - marginX - rightFooterWidth,
      y: footerTextY,
      size: footerRightSize,
      font: fontBold,
      color: rgb(0.06, 0.09, 0.16), // #0F172A
    });
  }

  return await doc.save({ useObjectStreams: false });
}

function renderHtmlToPdfViaChromium(browserExe, htmlFilePath, outputPdfPath) {
  execFileSync(browserExe, [
    '--headless',
    '--disable-gpu',
    '--no-pdf-header-footer',
    '--print-to-pdf=' + outputPdfPath,
    'file:///' + htmlFilePath.replace(/\\/g, '/'),
  ]);
}

async function main() {
  const pdfLib = loadPdfLib();
  const { PDFDocument, PDFDict, PDFArray } = pdfLib;

  const chromeCandidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ];
  const browserExe = chromeCandidates.find((p) => fs.existsSync(p));
  if (!browserExe) {
    throw new Error('Nenhum navegador Chromium/Edge encontrado.');
  }

  // Ensure docs/ never retains intermediate .html artifacts
  const legacyHtmlInDocs = path.resolve(
    'c:/00_Desperrengue/docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.html'
  );
  if (fs.existsSync(legacyHtmlInDocs)) {
    fs.unlinkSync(legacyHtmlInDocs);
  }

  const tempHtmlPath = path.join(
    os.tmpdir(),
    'Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.html'
  );
  const tempPass1PdfPath = path.join(
    os.tmpdir(),
    'Tratado_Enciclopedico_Pass1_v2.11.0.pdf'
  );
  const pdfDocsPath = path.resolve(
    'c:/00_Desperrengue/docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf'
  );
  const pdfRootPath = path.resolve(
    'c:/00_Desperrengue/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf'
  );

  // PASS 1: Render with placeholder '00' to extract exact page numbers for every anchor in /Dests
  const pass1CoverAndToc = coverAndTocHtml.replace(/\{\{PG:([a-zA-Z0-9_-]+)\}\}/g, '00');
  const pass1HtmlDoc = buildMasterHtmlDocument(pass1CoverAndToc);
  fs.writeFileSync(tempHtmlPath, pass1HtmlDoc, 'utf8');
  renderHtmlToPdfViaChromium(browserExe, tempHtmlPath, tempPass1PdfPath);

  let currentPdfBytes = fs.readFileSync(tempPass1PdfPath);
  let { destMap, totalPages } = await extractDestinationPageMap(
    currentPdfBytes,
    PDFDocument,
    PDFDict,
    PDFArray
  );
  console.log(
    `[Pass 1] PDF base renderizado (${totalPages} páginas, ${destMap.size} âncoras /Dests mapeadas).`
  );

  // PASS 2 (and optional Pass 3 if any page shifted): Inject real 2-digit page numbers into TOC
  for (let pass = 2; pass <= 3; pass++) {
    const missingAnchors = [];
    const resolvedCoverAndToc = coverAndTocHtml.replace(
      /\{\{PG:([a-zA-Z0-9_-]+)\}\}/g,
      (_, anchorId) => {
        const pg = destMap.get(anchorId);
        if (!pg) {
          missingAnchors.push(anchorId);
          return '00';
        }
        return String(pg).padStart(2, '0');
      }
    );

    if (missingAnchors.length > 0) {
      throw new Error(
        `Âncoras do Sumário não encontradas no dicionário /Dests do PDF: ${missingAnchors.join(', ')}`
      );
    }

    const finalHtmlDoc = buildMasterHtmlDocument(resolvedCoverAndToc);
    fs.writeFileSync(tempHtmlPath, finalHtmlDoc, 'utf8');
    renderHtmlToPdfViaChromium(browserExe, tempHtmlPath, pdfDocsPath);

    currentPdfBytes = fs.readFileSync(pdfDocsPath);
    const nextExtraction = await extractDestinationPageMap(
      currentPdfBytes,
      PDFDocument,
      PDFDict,
      PDFArray
    );

    let shifted = 0;
    for (const [k, v] of nextExtraction.destMap.entries()) {
      if (destMap.get(k) !== v) shifted++;
    }
    destMap = nextExtraction.destMap;
    totalPages = nextExtraction.totalPages;
    console.log(
      `[Pass ${pass}] Paginação real injetada no Sumário (${totalPages} páginas, desvios entre passes = ${shifted}).`
    );
    if (shifted === 0) break;
  }

  // Stamp running headers and footers on pages 2..N via pdf-lib
  const stampedPdfBytes = await stampEditorialHeadersAndFooters(currentPdfBytes, destMap, pdfLib);
  fs.writeFileSync(pdfDocsPath, stampedPdfBytes);
  fs.copyFileSync(pdfDocsPath, pdfRootPath);

  if (fs.existsSync(tempPass1PdfPath)) {
    fs.unlinkSync(tempPass1PdfPath);
  }

  const stat = fs.statSync(pdfDocsPath);
  console.log('HTML auditável salvo em os.tmpdir():', tempHtmlPath);
  console.log('PDF Enciclopédico v2.11.0 (Running Headers/Footers + TOC Paginado) gerado em:', pdfDocsPath);
  console.log('Cópia espelho sincronizada em:', pdfRootPath, '| Tamanho (bytes):', stat.size, '| Páginas:', totalPages);
}

main().catch((err) => {
  console.error('Erro fatal na compilação do PDF Mestre v2.11.0:', err);
  process.exit(1);
});

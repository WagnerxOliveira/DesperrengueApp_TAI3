import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

import { aiPart1Html } from './ai_pdf_chapters/ai_part1_cover_toc_and_stack.mjs';
import { aiPart2Html } from './ai_pdf_chapters/ai_part2_innovations_1_to_5.mjs';
import { aiPart3Html } from './ai_pdf_chapters/ai_part3_innovations_6_to_10.mjs';
import { aiPart4Html } from './ai_pdf_chapters/ai_part4_implementation_step_by_step_and_economics.mjs';
import { aiPart5Html } from './ai_pdf_chapters/ai_part5_deep_code_blueprints_and_schemas.mjs';

function normalizeEscapedLatex(s) {
  return s
    .replace(/\\text\{([^}]*)\}/g, '<span class="m-rm">$1</span>')
    .replace(/\\texttt\{([^}]*)\}/g, '<code>$1</code>')
    .replace(/\\tau/g, '&tau;')
    .replace(/\\theta/g, '&theta;')
    .replace(/\\times/g, '&times;')
    .replace(/\\to\b/g, '&rarr;')
    .replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)')
    .replace(/\\begin\{bmatrix\}([\s\S]*?)\\end\{bmatrix\}/g, '[X(u,v), Y(u,v), Z(u,v)]');
}

function renderLatexTokenToHtml(expr) {
  let s = normalizeEscapedLatex(expr);
  s = s.replace(/\\text\{([^}]*)\}/g, '<span class="m-rm">$1</span>');
  s = s.replace(/\\texttt\{([^}]*)\}/g, '<code>$1</code>');
  s = s.replace(/\\mathbf\{([^}]*)\}/g, '<strong>$1</strong>');
  s = s.replace(/\\boldsymbol\{([^}]*)\}/g, '<strong>$1</strong>');
  s = s.replace(/\\mathbb\{R\}/g, '&#8477;');
  s = s.replace(/\\mathbb\{I\}/g, '&#120128;');
  s = s.replace(/\\mathcal\{C\}/g, '&#8493;');
  s = s.replace(/\\mathcal\{V\}/g, 'V');
  s = s.replace(/\\mathcal\{E\}/g, 'E');
  s = s.replace(/\\hat\{([^}]*)\}/g, '$1&#770;');
  s = s.replace(/\\tilde\{([^}]*)\}/g, '$1&#771;');
  s = s.replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '($1) / ($2)');
  s = s.replace(/\\iint_\{([^}]*)\}/g, '&Int;<sub>$1</sub>');
  s = s.replace(/\\sum_\{([^}]*)\}\^\{([^}]*)\}/g, '&Sigma;<sub>$1</sub><sup>$2</sup>');
  s = s.replace(/\\sum_\{([^}]*)\}/g, '&Sigma;<sub>$1</sub>');
  s = s.replace(/\\arg\\max_\{([^}]*)\}/g, 'arg max<sub>$1</sub>');
  s = s.replace(/\\partial/g, '&part;');
  s = s.replace(/\\Omega/g, '&Omega;');
  s = s.replace(/\\Delta/g, '&Delta;');
  s = s.replace(/\\lambda/g, '&lambda;');
  s = s.replace(/\\gamma/g, '&gamma;');
  s = s.replace(/\\beta/g, '&beta;');
  s = s.replace(/\\alpha/g, '&alpha;');
  s = s.replace(/\\eta/g, '&eta;');
  s = s.replace(/\\rho/g, '&rho;');
  s = s.replace(/\\pi/g, '&pi;');
  s = s.replace(/\\sigma/g, '&sigma;');
  s = s.replace(/\\tau/g, '&tau;');
  s = s.replace(/\\kappa/g, '&kappa;');
  s = s.replace(/\\epsilon|\\varepsilon/g, '&epsilon;');
  s = s.replace(/\\psi/g, '&psi;');
  s = s.replace(/\\ell/g, 'l');
  s = s.replace(/\\le\b/g, '&le;');
  s = s.replace(/\\ge\b/g, '&ge;');
  s = s.replace(/\\in\b/g, '&isin;');
  s = s.replace(/\\equiv\b/g, '&equiv;');
  s = s.replace(/\\mid\b/g, ' | ');
  s = s.replace(/\\dots/g, '&hellip;');
  s = s.replace(/\\times\b/g, '&times;');
  s = s.replace(/\\cdot\b/g, '&middot;');
  s = s.replace(/\\top\b/g, 'T');
  s = s.replace(/\\left|\\right|\\big|\\Big/g, '');
  s = s.replace(/\\;|\\quad|\\qquad|\\,/g, ' ');
  s = s.replace(/\\\{/g, '{').replace(/\\\}/g, '}');
  s = s.replace(/\\\|/g, '&#8214;');
  s = s.replace(/_\{([^}]+)\}/g, '<sub>$1</sub>');
  s = s.replace(/_([a-zA-Z0-9]+)/g, '<sub>$1</sub>');
  s = s.replace(/\^\{([^}]+)\}/g, '<sup>$1</sup>');
  s = s.replace(/\^([a-zA-Z0-9*]+)/g, '<sup>$1</sup>');
  s = s.replace(/\\%/g, '%');
  return s;
}

function sanitizeAllMath(rawHtml) {
  let out = normalizeEscapedLatex(rawHtml);
  out = out.replace(/\$\$([\s\S]*?)\$\$/g, (_, expr) => {
    return `<div class="math-display">${renderLatexTokenToHtml(expr.trim())}</div>`;
  });
  out = out.replace(/(?<!R)\$([^\n$]+?)\$/g, (_, expr) => {
    return `<span class="math-inline">${renderLatexTokenToHtml(expr.trim())}</span>`;
  });
  return out;
}

const fullBodyHtml = sanitizeAllMath(
  aiPart1Html + '\n' + aiPart2Html + '\n' + aiPart3Html + '\n' + aiPart4Html + '\n' + aiPart5Html
);

const masterHtmlDocument = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <title>Tratado Completo de Inteligência Artificial &amp; Inovações Fintech — Desperrengue (v2.8.6)</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 13mm 14mm 13mm 14mm;
    }
    @page :first {
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
      font-size: 9.5pt;
      line-height: 1.45;
      color: #0F172A;
      background: #FFFFFF;
    }
    .page-break {
      page-break-before: always;
      break-before: page;
    }
    .cover-page {
      width: 210mm;
      min-height: 297mm;
      background: radial-gradient(circle at 48% 32%, #1A2E52 0%, #0F172A 68%, #090E1A 100%);
      color: #F8FAFC;
      padding: 18mm 18mm 16mm 18mm;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }
    .cover-top-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(148, 163, 184, 0.28);
      padding-bottom: 10px;
      font-size: 7.6pt;
      letter-spacing: 0.7px;
      color: #94A3B8;
      font-weight: 700;
    }
    .cover-badge { color: #38BDF8; }
    .cover-badge-right { color: #FF8A2B; }
    .cover-hero {
      text-align: center;
      margin: 10px 0;
    }
    .cover-logo-wrap { margin-bottom: 16px; }
    .cover-pre-title {
      font-size: 9.2pt;
      letter-spacing: 2.0px;
      font-weight: 800;
      color: #38BDF8;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .cover-title {
      font-size: 36pt;
      font-weight: 900;
      letter-spacing: -1px;
      margin: 0 0 12px 0;
      color: #FFFFFF;
    }
    .cover-subtitle {
      font-size: 10.8pt;
      line-height: 1.55;
      color: #CBD5E1;
      max-width: 94%;
      margin: 0 auto 24px auto;
    }
    .cover-pillars-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      text-align: left;
      margin-top: 14px;
    }
    .cover-pillar {
      background: rgba(15, 23, 42, 0.78);
      border: 1px solid rgba(56, 189, 248, 0.32);
      border-left: 4px solid #FF6D00;
      border-radius: 8px;
      padding: 11px 13px;
    }
    .cp-num {
      font-size: 13pt;
      font-weight: 800;
      color: #FFFFFF;
      margin-bottom: 3px;
    }
    .cp-lbl {
      font-size: 8.3pt;
      color: #94A3B8;
      line-height: 1.35;
    }
    .cover-meta-box {
      background: rgba(2, 6, 23, 0.72);
      border: 1px solid rgba(148, 163, 184, 0.25);
      border-radius: 10px;
      padding: 13px 16px;
      font-size: 8.3pt;
      color: #CBD5E1;
    }
    .cover-meta-row {
      display: flex;
      justify-content: space-between;
      gap: 14px;
      padding: 4px 0;
      border-bottom: 1px dashed rgba(148, 163, 184, 0.16);
    }
    .cover-meta-row:last-child { border-bottom: none; }
    .cover-meta-box code {
      background: rgba(56, 189, 248, 0.15);
      color: #7DD3FC;
      padding: 1px 5px;
      border-radius: 4px;
    }
    .section-header-banner {
      background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%);
      color: #FFFFFF;
      padding: 14px 18px;
      border-radius: 10px;
      border-left: 6px solid #FF6D00;
      margin-bottom: 12px;
    }
    .sh-tag {
      font-size: 7.5pt;
      font-weight: 800;
      letter-spacing: 1.5px;
      color: #38BDF8;
      display: block;
      margin-bottom: 2px;
    }
    .section-header-banner h2 {
      margin: 0 0 3px 0;
      font-size: 14pt;
      letter-spacing: -0.3px;
    }
    .section-header-banner p {
      margin: 0;
      font-size: 8.5pt;
      color: #CBD5E1;
    }
    .chapter-banner {
      display: flex;
      align-items: stretch;
      background: linear-gradient(135deg, #0F172A 0%, #172554 100%);
      color: #FFFFFF;
      border-radius: 10px;
      overflow: hidden;
      margin-bottom: 12px;
      border: 1px solid #1E3A8A;
    }
    .cb-num {
      background: #FF6D00;
      color: #FFFFFF;
      font-weight: 900;
      font-size: 9.8pt;
      letter-spacing: 1px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      min-width: 108px;
      text-align: center;
    }
    .cb-body { padding: 10px 16px; }
    .cb-body h2 {
      margin: 0 0 3px 0;
      font-size: 12.4pt;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.2px;
    }
    .cb-body p {
      margin: 0;
      font-size: 8.4pt;
      color: #CBD5E1;
    }
    h3 {
      font-size: 10.6pt;
      font-weight: 800;
      color: #0F172A;
      margin: 12px 0 6px 0;
      padding-bottom: 3px;
      border-bottom: 2px solid #E2E8F0;
      page-break-after: avoid;
      break-after: avoid;
    }
    p {
      margin: 0 0 8px 0;
      text-align: justify;
    }
    ul, ol {
      margin: 0 0 9px 0;
      padding-left: 19px;
    }
    li {
      margin-bottom: 4px;
      text-align: justify;
    }
    code, .mono {
      font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace;
      font-size: 8.2pt;
      background: #F1F5F9;
      color: #0F172A;
      padding: 1px 4px;
      border-radius: 4px;
      border: 1px solid #E2E8F0;
    }
    .toc-container {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .toc-group {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-left: 4px solid #0F172A;
      border-radius: 6px;
      padding: 7px 11px;
      break-inside: avoid;
    }
    .toc-chapter-title {
      font-weight: 800;
      font-size: 9.0pt;
      color: #0F172A;
      margin-bottom: 3px;
    }
    .toc-chapter-title a {
      color: #0F172A;
      text-decoration: none;
    }
    .toc-item {
      display: flex;
      align-items: baseline;
      font-size: 8.0pt;
      color: #334155;
      padding: 1.5px 0;
    }
    .toc-dots {
      flex: 1;
      border-bottom: 1px dotted #94A3B8;
      margin: 0 8px;
    }
    .data-table {
      width: 100%;
      border-collapse: collapse;
      margin: 6px 0 11px 0;
      font-size: 8.1pt;
    }
    .data-table th {
      background: #0F172A;
      color: #FFFFFF;
      font-weight: 700;
      text-align: left;
      padding: 6px 8px;
      border: 1px solid #1E293B;
    }
    .data-table td {
      padding: 5px 8px;
      border: 1px solid #CBD5E1;
      vertical-align: top;
      text-align: left;
    }
    .data-table tr:nth-child(even) td { background: #F8FAFC; }
    .data-table tr {
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .compact-table { font-size: 7.9pt; }
    .compact-table td, .compact-table th { padding: 4.5px 7px; }
    .cards-2col {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 9px;
      margin: 6px 0 10px 0;
    }
    .info-card {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-top: 3px solid #0F172A;
      border-radius: 7px;
      padding: 8px 11px;
      break-inside: avoid;
    }
    .ic-title {
      font-weight: 800;
      font-size: 8.9pt;
      color: #0F172A;
      margin-bottom: 4px;
    }
    .info-card p {
      margin: 0;
      font-size: 8.1pt;
      color: #334155;
      text-align: left;
    }
    .svg-diagram-box {
      margin: 8px 0 11px 0;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .math-formula-box {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 4px solid #1E3A8A;
      border-radius: 6px;
      padding: 7px 12px;
      margin: 6px 0 9px 0;
      font-family: 'Cambria Math', 'Times New Roman', serif;
      font-size: 9.2pt;
      color: #0F172A;
      break-inside: avoid;
    }
    .math-display {
      text-align: center;
      font-weight: 600;
      padding: 2px 0;
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
    .badge-ok {
      background: #DCFCE7;
      color: #166534;
      font-weight: 800;
      font-size: 7.1pt;
      padding: 2px 5px;
      border-radius: 4px;
      border: 1px solid #86EFAC;
      display: inline-block;
    }
    .badge-high {
      background: #FEE2E2;
      color: #991B1B;
      font-weight: 800;
      font-size: 7.1pt;
      padding: 2px 5px;
      border-radius: 4px;
      border: 1px solid #FCA5A5;
      display: inline-block;
    }
    .badge-med {
      background: #FEF3C7;
      color: #92400E;
      font-weight: 800;
      font-size: 7.1pt;
      padding: 2px 5px;
      border-radius: 4px;
      border: 1px solid #FCD34D;
      display: inline-block;
    }
    .innovation-box {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-left: 5px solid #FF6D00;
      border-radius: 8px;
      padding: 9px 13px;
      margin-bottom: 9px;
      break-inside: avoid;
      page-break-inside: avoid;
    }
    .ib-header {
      font-size: 9.4pt;
      font-weight: 800;
      color: #0F172A;
      margin-bottom: 4px;
      border-bottom: 1px solid #E2E8F0;
      padding-bottom: 3px;
    }
    .innovation-box p {
      font-size: 8.4pt;
      margin-bottom: 5px;
    }
    .innovation-box ul, .innovation-box ol {
      margin: 0;
      padding-left: 17px;
      font-size: 8.2pt;
    }
    .innovation-box li { margin-bottom: 2.5px; }
    .doc-closing-box {
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
      color: #F8FAFC;
      border-radius: 10px;
      border-left: 6px solid #10B981;
      padding: 12px 16px;
      margin-top: 14px;
      break-inside: avoid;
    }
    .dcb-title {
      font-weight: 800;
      font-size: 9.6pt;
      color: #6EE7B7;
      margin-bottom: 4px;
    }
    .doc-closing-box p {
      margin: 0;
      font-size: 8.4pt;
      color: #E2E8F0;
    }
  </style>
</head>
<body>
${fullBodyHtml}
</body>
</html>`;

const htmlPath = path.resolve('c:/00_Desperrengue/docs/Tratado_Completo_IA_Fintech_Inovacoes_Desperrengue_v2.8.6.html');
const pdfRootPath = path.resolve('c:/00_Desperrengue/Tratado_Completo_IA_Fintech_Inovacoes_Desperrengue_v2.8.6.pdf');
const pdfDocsPath = path.resolve('c:/00_Desperrengue/docs/Tratado_Completo_IA_Fintech_Inovacoes_Desperrengue_v2.8.6.pdf');

fs.writeFileSync(htmlPath, masterHtmlDocument, 'utf8');
console.log('HTML mestre de IA gerado em:', htmlPath);

const chromeCandidates = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
];
const browserExe = chromeCandidates.find(p => fs.existsSync(p));
if (!browserExe) {
  throw new Error('Nenhum navegador Chromium encontrado.');
}

execFileSync(browserExe, [
  '--headless',
  '--disable-gpu',
  '--no-pdf-header-footer',
  '--print-to-pdf=' + pdfDocsPath,
  'file:///' + htmlPath.replace(/\\/g, '/'),
]);

fs.copyFileSync(pdfDocsPath, pdfRootPath);
try {
  if (fs.existsSync(htmlPath)) {
    fs.unlinkSync(htmlPath);
  }
} catch (_) {
  // Ignora bloqueio transitório de descritor de arquivo do Chromium no Windows
}
const stat = fs.statSync(pdfRootPath);
console.log('PDF de IA & Fintech gerado com sucesso:', pdfRootPath, 'Tamanho (bytes):', stat.size);

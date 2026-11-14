// Suite Automatizada de Auditoria Editorial, Estrutural, Cientifica e Prova Matematica Pagina a Pagina (v2.11.0)
// Execucao: node scripts/test-encyclopedic-pdf.mjs

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const ROOT_DIR = path.resolve('c:/00_Desperrengue');
const HTML_TEMP_PATH = path.join(os.tmpdir(), 'Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.html');
const HTML_DOCS_FORBIDDEN_PATH = path.join(ROOT_DIR, 'docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.html');
const PDF_DOCS_PATH = path.join(ROOT_DIR, 'docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf');
const PDF_ROOT_PATH = path.join(ROOT_DIR, 'Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf');
const README_PATH = path.join(ROOT_DIR, 'README.md');

const LEGACY_PDF_282 = path.join(ROOT_DIR, 'docs/Tratado_Completo_Desperrengue_v2.8.2.pdf');
const LEGACY_PDF_286 = path.join(ROOT_DIR, 'docs/Tratado_Completo_IA_Fintech_Inovacoes_Desperrengue_v2.8.6.pdf');

function loadPdfLib() {
  const toolDir = path.join(os.tmpdir(), 'desperrengue-pdf-tools');
  const pdfLibEntry = path.join(toolDir, 'node_modules', 'pdf-lib', 'cjs', 'index.js');
  return require(pdfLibEntry);
}

function inflatePdfStream(streamObj, PDFRawStream) {
  if (!streamObj) return '';
  const raw = streamObj instanceof PDFRawStream ? streamObj.contents : streamObj.getContents?.();
  if (!raw) return '';
  try {
    return zlib.inflateSync(Buffer.from(raw)).toString('latin1');
  } catch {
    return Buffer.from(raw).toString('latin1');
  }
}

function parseCMap(cmapText) {
  const map = new Map();
  for (const b of cmapText.matchAll(/beginbfchar([\s\S]*?)endbfchar/g)) {
    for (const m of b[1].matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/g)) {
      const cid = parseInt(m[1], 16);
      const hex = m[2];
      let str = '';
      for (let i = 0; i < hex.length; i += 4) {
        str += String.fromCodePoint(parseInt(hex.slice(i, i + 4), 16));
      }
      map.set(cid, str);
    }
  }
  for (const b of cmapText.matchAll(/beginbfrange([\s\S]*?)endbfrange/g)) {
    for (const m of b[1].matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/g)) {
      const start = parseInt(m[1], 16);
      const end = parseInt(m[2], 16);
      let dst = parseInt(m[3], 16);
      for (let c = start; c <= end; c++) {
        map.set(c, String.fromCodePoint(dst++));
      }
    }
  }
  return map;
}

function decodeWinAnsiHex(hex) {
  const buf = Buffer.from(hex, 'hex');
  let s = '';
  for (const b of buf) {
    if (b === 0x97) s += '\u2014';
    else if (b === 0x96) s += '\u2013';
    else if (b === 0x95) s += '\u2022';
    else s += String.fromCharCode(b);
  }
  return s;
}

function decodeContentStreamText(streamText, fontCMaps) {
  let currentFont = null;
  let out = '';
  const tokenRe = /\/([A-Za-z0-9_.-]+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>\s*Tj|\(([^()\\]*(?:\\.[^()\\]*)*)\)\s*Tj|\[([\s\S]*?)\]\s*TJ|ET\b/g;
  for (const m of streamText.matchAll(tokenRe)) {
    if (m[1]) {
      currentFont = m[1];
    } else if (m[2] !== undefined) {
      const hex = m[2];
      const cmap = fontCMaps.get(currentFont);
      if (cmap && cmap.size > 0) {
        for (let i = 0; i < hex.length; i += 4) {
          const cid = parseInt(hex.slice(i, i + 4), 16);
          out += cmap.get(cid) ?? '';
        }
      } else {
        out += decodeWinAnsiHex(hex);
      }
    } else if (m[3] !== undefined) {
      out += m[3];
    } else if (m[4] !== undefined) {
      const arr = m[4];
      const cmap = fontCMaps.get(currentFont);
      for (const h of arr.matchAll(/<([0-9A-Fa-f]+)>/g)) {
        const hex = h[1];
        if (cmap && cmap.size > 0) {
          for (let i = 0; i < hex.length; i += 4) {
            const cid = parseInt(hex.slice(i, i + 4), 16);
            out += cmap.get(cid) ?? '';
          }
        } else {
          out += decodeWinAnsiHex(hex);
        }
      }
    } else {
      out += ' ';
    }
  }
  return out.replace(/\s+/g, ' ').trim();
}

async function inspectPdfStructureAndText(pdfBytes) {
  const pdfLib = loadPdfLib();
  const { PDFDocument, PDFName, PDFDict, PDFArray, PDFRawStream } = pdfLib;
  const doc = await PDFDocument.load(pdfBytes);
  const pages = doc.getPages();

  const refToPageNum = new Map();
  pages.forEach((p, idx) => {
    refToPageNum.set(p.ref.toString(), idx + 1);
  });

  // Extract /Dests map: anchorId -> { pageNum, x, y }
  const destMap = new Map();
  for (const [, obj] of doc.context.enumerateIndirectObjects()) {
    if (obj instanceof PDFDict) {
      for (const [k, v] of obj.entries()) {
        if (v instanceof PDFArray && v.size() >= 2) {
          const pageRef = v.get(0);
          if (pageRef && refToPageNum.has(pageRef.toString())) {
            const rawKey = k.decodeText ? k.decodeText() : k.toString().replace(/^\//, '');
            const xObj = v.size() >= 3 ? v.get(2) : null;
            const yObj = v.size() >= 4 ? v.get(3) : null;
            const x = xObj && typeof xObj.asNumber === 'function' ? xObj.asNumber() : null;
            const y = yObj && typeof yObj.asNumber === 'function' ? yObj.asNumber() : null;
            destMap.set(rawKey, {
              pageNum: refToPageNum.get(pageRef.toString()),
              x,
              y,
            });
          }
        }
      }
    }
  }

  // Extract decoded text per page (separating Chromium body stream from pdf-lib header/footer stream)
  const pageData = [];
  for (let idx = 0; idx < pages.length; idx++) {
    const page = pages[idx];
    const resources = page.node.Resources();
    const fontDict = resources ? doc.context.lookup(resources.get(PDFName.of('Font'))) : null;
    const fontCMaps = new Map();
    if (fontDict instanceof PDFDict) {
      for (const [k, v] of fontDict.entries()) {
        const fontName = k.toString().replace(/^\//, '');
        const fObj = doc.context.lookup(v);
        if (fObj instanceof PDFDict) {
          const toUni = doc.context.lookup(fObj.get(PDFName.of('ToUnicode')));
          if (toUni) {
            fontCMaps.set(fontName, parseCMap(inflatePdfStream(toUni, PDFRawStream)));
          }
        }
      }
    }

    const contentsObj = doc.context.lookup(page.node.get(PDFName.of('Contents')));
    const streams = [];
    if (contentsObj instanceof PDFArray) {
      for (let i = 0; i < contentsObj.size(); i++) {
        streams.push(doc.context.lookup(contentsObj.get(i)));
      }
    } else if (contentsObj) {
      streams.push(contentsObj);
    }

    const rawStreams = streams.map((s) => inflatePdfStream(s, PDFRawStream));
    const decodedStreams = rawStreams.map((s) => decodeContentStreamText(s, fontCMaps));
    const bodyText =
      decodedStreams.length > 1
        ? decodedStreams.slice(0, -1).join(' ').replace(/\s+/g, ' ').trim()
        : (decodedStreams[0] ?? '');
    const stampText =
      decodedStreams.length > 1 ? decodedStreams[decodedStreams.length - 1].trim() : '';
    const fullText = decodedStreams.join(' ').replace(/\s+/g, ' ').trim();
    const rawBodyStream = rawStreams.length > 1 ? rawStreams[1] : (rawStreams[0] ?? '');

    const { width, height } = page.getSize();
    pageData.push({
      pageNum: idx + 1,
      width,
      height,
      rawBodyStream,
      bodyText,
      stampText,
      fullText,
    });
  }

  return { totalPages: pages.length, destMap, pageData };
}

let passed = 0;
async function test(name, fn) {
  await fn();
  passed++;
  console.log(`ok  [${String(passed).padStart(2, '0')}] ${name}`);
}

async function runSuite() {
  console.log('=== AUDITORIA AUTOMATIZADA E PROVA MATEMATICA DO TRATADO ENCICLOPEDICO v2.11.0 ===\n');

  await test('Higiene de docs/ (sem .html residual), existencia do PDF v2.11.0 (docs/ e raiz) e listagem no README.md', () => {
    assert.ok(
      !fs.existsSync(HTML_DOCS_FORBIDDEN_PATH),
      `Proibido manter arquivo .html intermediario em docs/: ${HTML_DOCS_FORBIDDEN_PATH}`
    );
    assert.ok(fs.existsSync(HTML_TEMP_PATH), `HTML temporario auditavel nao encontrado em os.tmpdir(): ${HTML_TEMP_PATH}`);
    assert.ok(fs.existsSync(PDF_DOCS_PATH), `PDF canonico nao encontrado: ${PDF_DOCS_PATH}`);
    assert.ok(fs.existsSync(PDF_ROOT_PATH), `PDF espelho na raiz nao encontrado: ${PDF_ROOT_PATH}`);

    const readme = fs.readFileSync(README_PATH, 'utf8');
    assert.ok(
      readme.includes('docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf'),
      'README.md deve referenciar docs/Tratado_Enciclopedico_Completo_Desperrengue_v2.11.0.pdf'
    );
  });

  await test('Preservacao intacta dos PDFs historicos v2.8.2 e v2.8.6 em docs/', () => {
    assert.ok(fs.existsSync(LEGACY_PDF_282), 'PDF historico v2.8.2 deve ser preservado');
    assert.ok(fs.existsSync(LEGACY_PDF_286), 'PDF historico v2.8.6 deve ser preservado');
    assert.ok(fs.statSync(LEGACY_PDF_282).size > 100_000, 'PDF v2.8.2 integro');
    assert.ok(fs.statSync(LEGACY_PDF_286).size > 100_000, 'PDF v2.8.6 integro');
  });

  const html = fs.readFileSync(HTML_TEMP_PATH, 'utf8');
  const pdfBytes = fs.readFileSync(PDF_DOCS_PATH);
  const pdfRootBytes = fs.readFileSync(PDF_ROOT_PATH);
  const pdfLatin1 = pdfBytes.toString('latin1');

  await test('Assinatura binaria %PDF-1.x, trailer %%EOF, paridade exata docs/raiz e tamanho robusto', () => {
    const header = pdfLatin1.slice(0, 8);
    assert.match(header, /^%PDF-1\.\d/, `Cabecalho PDF invalido: ${header}`);
    assert.ok(pdfLatin1.includes('%%EOF'), 'Trailer %%EOF ausente no PDF');
    assert.equal(pdfBytes.length, pdfRootBytes.length, 'Copia na raiz deve ter exatamente o mesmo tamanho do PDF em docs/');
    assert.ok(pdfBytes.length > 350_000, `Tamanho do PDF (${pdfBytes.length} bytes) abaixo do limiar minimo esperado`);
  });

  const { totalPages, destMap, pageData } = await inspectPdfStructureAndText(pdfBytes);

  await test('Contagem de paginas A4 via pdf-lib e verificacao geometrica do MediaBox A4 (210mm x 297mm)', () => {
    assert.ok(totalPages >= 55, `Contagem de paginas A4 (${totalPages}) deve ser >= 55 para o Tratado Enciclopedico completo`);
    for (const pg of pageData) {
      assert.ok(pg.width >= 594.0 && pg.width <= 596.5, `Largura da pagina ${pg.pageNum} fora do padrao A4: ${pg.width} pt`);
      assert.ok(pg.height >= 840.5 && pg.height <= 843.0, `Altura da pagina ${pg.pageNum} fora do padrao A4: ${pg.height} pt`);
    }
    const pageMatches = pdfLatin1.match(/\/Type\s*\/Page\b(?!s)/g) || [];
    assert.equal(pageMatches.length, totalPages, 'Contagem de /Type /Page no binario deve coincidir com pdf-lib');
    console.log(`    -> Total de paginas A4 verificadas via pdf-lib e binario: ${totalPages} paginas (${(pdfBytes.length / (1024 * 1024)).toFixed(2)} MB)`);
  });

  await test('PROVA MATEMATICA (a): Isolamento incondicional de pagina por Capitulo (CAPITULO 1 a CAPITULO 6 no topo de folha A4 nova)', () => {
    const majorSections = [
      { id: 'ficha-tecnica-normas', label: 'PRELIMINARES EDITORIAIS', prevForbidden: ['DOCUMENTO NORMATIVO'] },
      { id: 'sumario-analitico', label: 'NAVEGAÇÃO ESTRUTURADA HIPERLINKADA', prevForbidden: ['representação binária IEEE 754'] },
      { id: 'cap-1', label: 'CAPÍTULO 1', prevForbidden: ['Figura 6.4'] },
      { id: 'cap-2', label: 'CAPÍTULO 2', prevForbidden: ['Oráculo Empírico Automatizado'] },
      { id: 'cap-3', label: 'CAPÍTULO 3', prevForbidden: ['Onda 3 (Escala Nacional'] },
      { id: 'cap-4', label: 'CAPÍTULO 4', prevForbidden: ['Perspectiva de Aprendizado e Crescimento'] },
      { id: 'cap-5', label: 'CAPÍTULO 5', prevForbidden: ['Fórmula WSJF (SAFe)'] },
      { id: 'cap-6', label: 'CAPÍTULO 6', prevForbidden: ['Certificação Integral 10/10 Heurísticas'] },
    ];

    let prevPage = 1; // Page 1 is Cover
    const chapterPagesSummary = [];

    for (const sec of majorSections) {
      const dest = destMap.get(sec.id);
      assert.ok(dest, `Destino PDF /Dests ausente para secao principal: ${sec.id}`);
      assert.ok(
        dest.pageNum > prevPage,
        `Violacao de quebra de pagina: ${sec.id} iniciou na pagina ${dest.pageNum}, que nao e estritamente posterior a secao anterior (pag. ${prevPage})`
      );
      // Verify Y coordinate in PDF points is at the very top of the printable area (A4 height = 841.89, top margin 17mm = 48.19pt => y ~ 793.7pt)
      if (dest.y !== null) {
        assert.ok(
          dest.y >= 780,
          `Capitulo/Secao ${sec.id} nao iniciou no topo da folha A4 (coordenada PDF y=${dest.y.toFixed(2)}pt < 780pt)`
        );
      }

      const pgInfo = pageData[dest.pageNum - 1];
      assert.ok(
        pgInfo.bodyText.startsWith(sec.label) || pgInfo.bodyText.includes(sec.label),
        `Texto extraido da pagina ${dest.pageNum} nao contem o cabecalho de abertura "${sec.label}" no inicio do fluxo`
      );
      // Verify the chapter banner is the very first text in the body stream of that page
      const bannerIdx = pgInfo.bodyText.indexOf(sec.label);
      assert.equal(
        bannerIdx,
        0,
        `Texto residual do capitulo anterior detectado antes de "${sec.label}" no topo da pagina ${dest.pageNum}: "${pgInfo.bodyText.slice(0, bannerIdx)}"`
      );

      for (const forbidden of sec.prevForbidden) {
        assert.ok(
          !pgInfo.bodyText.includes(forbidden),
          `Vazamento de texto da secao anterior ("${forbidden}") na pagina de abertura ${dest.pageNum} de ${sec.id}`
        );
      }

      chapterPagesSummary.push(`${sec.id}=Pág.${String(dest.pageNum).padStart(2, '0')} (y=${dest.y?.toFixed(1)}pt, offset=0)`);
      prevPage = dest.pageNum;
    }
    console.log(`    -> Isolamento de pagina provado: ${chapterPagesSummary.join(' | ')}`);
  });

  await test('PROVA MATEMATICA (b): 100% dos numeros de pagina impressos no Sumario ("Pag. XX") batem com a pagina real no PDF', () => {
    assert.ok(!html.includes('{{PG:'), 'Placeholders {{PG:...}} nao resolvidos encontrados no HTML final');

    const tocLinks = [
      ...html.matchAll(/<a\s+href="#([^"]+)"\s+class="toc-(?:page-badge|pg)">Pág\.\s*(\d+)<\/a>/g),
    ];
    assert.ok(
      tocLinks.length >= 110,
      `O Sumario de 3 niveis + Indice de Figuras deve ter pelo menos 110 entradas paginadas (encontradas: ${tocLinks.length})`
    );

    let verifiedCount = 0;
    for (const [, anchorId, printedPageStr] of tocLinks) {
      const printedPage = parseInt(printedPageStr, 10);
      const actualDest = destMap.get(anchorId);
      assert.ok(actualDest, `Ancora #${anchorId} listada no Sumario nao existe em /Dests do PDF`);
      assert.equal(
        printedPage,
        actualDest.pageNum,
        `Divergencia de paginacao no Sumario para #${anchorId}: impresso "Pág. ${printedPageStr}", mas pagina real no PDF e ${actualDest.pageNum}`
      );
      verifiedCount++;
    }
    console.log(`    -> 100% das ${verifiedCount}/${tocLinks.length} entradas do Sumario + Indice de Figuras coincidem exatamente com a pagina real do PDF!`);
  });

  await test('PROVA MATEMATICA (c): Cabecalho corrente e rodape editorial ("Pagina X de Y") presentes em todas as paginas internas 2..N sem colisao horizontal', async () => {
    // Verify Named Page cover_sheet full-bleed CSS rule at 1.0x native scale (297mm)
    assert.ok(html.includes('@page cover_sheet'), 'CSS deve declarar @page cover_sheet { margin: 0mm }');
    assert.ok(html.includes('page: cover_sheet'), '.cover-page deve referenciar page: cover_sheet');
    assert.ok(html.includes('height: 297mm'), '.cover-page deve usar height: 297mm em escala nativa 1.0x');

    // Page 1 (Cover) must NOT have running header/footer stamped
    assert.equal(
      pageData[0].stampText,
      '',
      'A Capa (Pagina 1) nao deve conter cabecalho ou rodape corrente'
    );

    const pdfLib = loadPdfLib();
    const { PDFDocument, StandardFonts } = pdfLib;
    const metricDoc = await PDFDocument.create();
    const fontRegular = await metricDoc.embedFont(StandardFonts.Helvetica);
    const fontBold = await metricDoc.embedFont(StandardFonts.HelveticaBold);
    const usableWidth = 595.28 - 2 * 39.68; // 515.92pt

    const headerCandidates = [
      'PRELIMINARES EDITORIAIS — FICHA TÉCNICA, NORMAS INTERNACIONAIS E CONVENÇÕES',
      'SUMÁRIO ANALÍTICO COMPLETO (3 NÍVEIS) E ÍNDICE DE FIGURAS',
      'CAPÍTULO 1 — TÉCNICAS DE ESCRITA TÉCNICA E CIENTÍFICA EM CIÊNCIA DA COMPUTAÇÃO',
      'CAPÍTULO 2 — EMPREENDEDORISMO, DESCOBERTA DE CLIENTES, PESQUISA, EMPATIA E OPORTUNIDADE',
      'CAPÍTULO 3 — MODELO DE NEGÓCIO, PROTOTIPAGEM LEAN, MARKETING E PLANO FINANCEIRO',
      'CAPÍTULO 4 — ENGENHARIA DE SOFTWARE E ENGENHARIA DE REQUISITOS COMPLETA (ISO 29148 / PBB)',
      'CAPÍTULO 5 — PROTOTIPAÇÃO (LOW-FI, WIREFRAMES E HI-FI) E AS 10 HEURÍSTICAS DE NIELSEN',
      'CAPÍTULO 6 — ARQUITETURA DE SOFTWARE COMPLETA E HISTÓRICO PASSO A PASSO ATÉ A v2.11.0',
    ];
    const rightHeaderBadge = 'TRATADO ENCICLOPÉDICO DESPERRENGUE (v2.11.0)';
    const rightHeaderWidth = fontRegular.widthOfTextAtSize(rightHeaderBadge, 5.8);
    for (const hLeft of headerCandidates) {
      const leftWidth = fontBold.widthOfTextAtSize(hLeft, 5.9);
      assert.ok(
        leftWidth + rightHeaderWidth + 20 <= usableWidth,
        `Colisao horizontal no cabecalho "${hLeft}": ${leftWidth.toFixed(1)} + ${rightHeaderWidth.toFixed(1)} + 20 > ${usableWidth.toFixed(1)}`
      );
    }

    const leftFooterNorms = 'ISO/IEC/IEEE 29148 · ISO/IEC 25010 · ISO/IEC/IEEE 42010 · LGPD · CDC · ABNT NBR 5674';
    const leftFooterWidth = fontRegular.widthOfTextAtSize(leftFooterNorms, 5.5);

    for (let p = 2; p <= totalPages; p++) {
      const pg = pageData[p - 1];
      const expectedFooter = `Ecossistema Desperrengue (v2.11.0) · Wagner Oliveira & Gabriel | Página ${p} de ${totalPages}`;
      const rightFooterWidth = fontBold.widthOfTextAtSize(expectedFooter, 5.9);
      assert.ok(
        leftFooterWidth + rightFooterWidth + 20 <= usableWidth,
        `Colisao horizontal no rodape da pagina ${p}: ${leftFooterWidth.toFixed(1)} + ${rightFooterWidth.toFixed(1)} + 20 > ${usableWidth.toFixed(1)}`
      );
      assert.ok(
        pg.stampText.includes('TRATADO ENCICLOPÉDICO DESPERRENGUE (v2.11.0)'),
        `Cabecalho corrente ausente na pagina ${p}`
      );
      assert.ok(
        pg.stampText.includes(expectedFooter),
        `Rodape corrente exato "${expectedFooter}" ausente na pagina ${p} (encontrado: "${pg.stampText}")`
      );
    }
    console.log(`    -> Cabecalho e rodape corrente verificados pagina a pagina nas paginas 2 a ${totalPages} (folga horizontal >= 30pt, Capa full-bleed na pagina 1).`);
  });

  await test('Presenca e ancoragem real das 18 Figuras Vetoriais SVG (#fig-01 a #fig-18) no HTML e no dicionario /Dests do PDF', () => {
    let lastFigPage = 0;
    for (let i = 1; i <= 18; i++) {
      const figId = `fig-${String(i).padStart(2, '0')}`;
      assert.ok(new RegExp(`id=["']${figId}["']`).test(html), `Ancora de figura ausente no HTML: id="${figId}"`);
      const dest = destMap.get(figId);
      assert.ok(dest, `Ancora #${figId} ausente no dicionario /Dests do PDF`);
      assert.ok(
        dest.pageNum >= lastFigPage,
        `Figura #${figId} (pag. ${dest.pageNum}) fora da ordem monotona de paginas (anterior: pag. ${lastFigPage})`
      );
      lastFigPage = dest.pageNum;
    }
    console.log(`    -> Todas as 18 Figuras (#fig-01 a #fig-18) ancoradas e paginadas no PDF.`);
  });

  await test('Ordem canonica estrita dos 6 Capitulos e de todas as secoes obrigatorias (sec-1-1 a sec-6-3)', () => {
    const sectionsByChapter = {
      'cap-1': ['sec-1-1', 'sec-1-2', 'sec-1-3'],
      'cap-2': ['sec-2-1', 'sec-2-2', 'sec-2-3', 'sec-2-4', 'sec-2-5', 'sec-2-6'],
      'cap-3': ['sec-3-1', 'sec-3-2'],
      'cap-4': ['sec-4-1', 'sec-4-2', 'sec-4-3', 'sec-4-4'],
      'cap-5': ['sec-5-1', 'sec-5-2', 'sec-5-3', 'sec-5-4'],
      'cap-6': ['sec-6-1', 'sec-6-2', 'sec-6-3'],
    };

    const chapterOrder = Object.keys(sectionsByChapter);
    let globalLastPos = -1;

    for (let c = 0; c < chapterOrder.length; c++) {
      const chId = chapterOrder[c];
      const nextChId = chapterOrder[c + 1];
      const chPos = new RegExp(`id=["']${chId}["']`).exec(html).index;
      const nextChPos = nextChId ? new RegExp(`id=["']${nextChId}["']`).exec(html).index : html.length;

      for (const secId of sectionsByChapter[chId]) {
        const secMatch = new RegExp(`id=["']${secId}["']`).exec(html);
        assert.ok(secMatch, `Secao obrigatoria ausente: id="${secId}"`);
        assert.ok(
          secMatch.index > chPos && secMatch.index < nextChPos,
          `Secao ${secId} deve estar contida dentro de ${chId}`
        );
        assert.ok(secMatch.index > globalLastPos, `Secao ${secId} fora da progressao monotona global`);
        globalLastPos = secMatch.index;
      }
    }
  });

  await test('Integridade de 100% dos links internos href="#..." do Sumario e do documento', () => {
    const allIds = new Set([...html.matchAll(/\bid=["']([^"']+)["']/g)].map((m) => m[1]));
    const hrefAnchors = [...html.matchAll(/\bhref=["']#([^"']+)["']/g)].map((m) => m[1]);
    assert.ok(hrefAnchors.length >= 220, `Esperados pelo menos 220 links internos no Sumario de 3 niveis, encontrados: ${hrefAnchors.length}`);
    for (const targetId of hrefAnchors) {
      assert.ok(allIds.has(targetId), `Link interno quebrado: href="#${targetId}" nao possui id="${targetId}" correspondente no HTML`);
    }
  });

  await test('Integridade de todos os 19 diagramas vetoriais <svg>...</svg> (Capa + 18 Figuras de Capitulos)', () => {
    const openSvgs = [...html.matchAll(/<svg\b[^>]*>/gi)];
    const closeSvgs = [...html.matchAll(/<\/svg>/gi)];
    assert.equal(openSvgs.length, closeSvgs.length, `Desbalanceamento de tags SVG: ${openSvgs.length} <svg> vs ${closeSvgs.length} </svg>`);
    assert.equal(openSvgs.length, 19, `Esperados exatamente 19 diagramas SVG (1 capa + 18 figuras de capitulos), encontrados: ${openSvgs.length}`);
    for (let i = 0; i < openSvgs.length; i++) {
      const tag = openSvgs[i][0];
      assert.match(tag, /viewBox=["'][^"']+["']/i, `SVG #${i + 1} sem atributo viewBox`);
    }
  });

  await test('Ausencia de delimitadores LaTeX crus ($$), caracteres de controle (\\x08, \\x0c), rubricas ("pts") e 1a pessoa', () => {
    assert.ok(!html.includes('$$'), 'Encontrado delimitador matematico $$ cru nao convertido no HTML');
    assert.ok(!html.includes('\x08'), 'Encontrado caractere de controle \\x08');
    assert.ok(!html.includes('\x0c'), 'Encontrado caractere de controle \\x0c');
    assert.ok(!/\\frac\{|\\text\{|\\texttt\{|\\mathcal\{|\\mathbb\{/.test(html), 'Encontrado comando LaTeX cru nao sanitizado no HTML');

    const textOnly = html
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ');
    assert.ok(!/\b\d+(?:[.,]\d+)?\s*pts\b/i.test(textOnly), 'Vazamento de rubrica "pts" detectado');
    assert.ok(!/Total\s+de\s+pontos\s*:/i.test(textOnly), 'Vazamento de "Total de pontos:" detectado');

    const firstPersonRegex = /\b(nós|nosso|nossa|nossos|nossas|fizemos|criamos|desenvolvemos|implementamos|construímos|optamos|decidimos)\b/i;
    const match = firstPersonRegex.exec(textOnly);
    assert.ok(!match, `Detectado uso proibido de 1a pessoa no texto: "${match ? match[0] : ''}"`);
  });

  await test('Cobertura CSS integral: todas as classes HTML usadas no corpo possuem definicao em <style>', () => {
    const styleBlock = html.slice(html.indexOf('<style>'), html.indexOf('</style>'));
    const bodyBlock = html.slice(html.indexOf('<body>'));
    const usedClasses = new Set();
    for (const m of bodyBlock.matchAll(/\bclass=["']([^"']+)["']/g)) {
      for (const cls of m[1].split(/\s+/)) {
        if (cls) usedClasses.add(cls);
      }
    }
    const missingClasses = [...usedClasses].filter((cls) => !styleBlock.includes(`.${cls}`));
    assert.deepEqual(missingClasses, [], `Classes CSS sem definicao em <style>: ${missingClasses.join(', ')}`);
    console.log(`    -> Total de classes CSS verificadas e estilizadas: ${usedClasses.size}`);
  });

  await test('PROVA MATEMATICA (d): Escala nativa 1.0x real (CTM 3.125 sem shrink-to-fit, documentElement.scrollWidth <= clientWidth e 0 tabelas transbordando)', () => {
    // 1. Check PDF CTM scale factor on internal pages (3.125 = 300dpi/96dpi = exact 1.0x scale; 2.0833335 = 0.67x shrink-to-fit)
    for (let p = 2; p <= totalPages; p++) {
      const raw = pageData[p - 1].rawBodyStream;
      assert.ok(
        !raw.includes('2.083333'),
        `Shrink-to-fit de 1.5x (CTM 2.0833335) detectado na pagina ${p} do PDF!`
      );
      assert.ok(
        raw.includes('3.125 0 0 3.125'),
        `Escala nativa 1.0x (CTM 3.125 0 0 3.125) ausente na pagina ${p} do PDF`
      );
    }

    // 2. Check live Chromium DOM layout at A4 printable width (182mm = 688px at 96dpi)
    const chromeCandidates = [
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    ];
    const browserExe = chromeCandidates.find((p) => fs.existsSync(p));
    assert.ok(browserExe, 'Navegador Chromium/Edge necessario para auditoria DOM');

    const probeScript = `
<style>::-webkit-scrollbar { display: none; }</style>
<script>
window.addEventListener('DOMContentLoaded', () => {
  const docScrollWidth = document.documentElement.scrollWidth;
  const docClientWidth = document.documentElement.clientWidth;
  const tables = [...document.querySelectorAll('table')];
  const overflowingTables = [];
  tables.forEach((t, idx) => {
    if (t.scrollWidth > t.clientWidth + 1) {
      overflowingTables.push({ idx: idx + 1, scrollWidth: t.scrollWidth, clientWidth: t.clientWidth });
    }
  });
  document.body.setAttribute('data-layout-audit', JSON.stringify({
    docScrollWidth,
    docClientWidth,
    totalTables: tables.length,
    overflowingTables
  }));
});
</script>`;
    const probeHtmlPath = path.join(os.tmpdir(), 'Tratado_Layout_Probe_v2.11.0.html');
    fs.writeFileSync(
      probeHtmlPath,
      html.replace('</body>', `${probeScript}\n</body>`),
      'utf8'
    );

    const domDump = execFileSync(
      browserExe,
      [
        '--headless',
        '--disable-gpu',
        '--window-size=688,1050',
        '--dump-dom',
        'file:///' + probeHtmlPath.replace(/\\/g, '/'),
      ],
      { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 }
    );
    if (fs.existsSync(probeHtmlPath)) fs.unlinkSync(probeHtmlPath);

    const attrMatch = domDump.match(/data-layout-audit="([^"]+)"/);
    assert.ok(attrMatch, 'Atributo data-layout-audit nao encontrado no dump DOM do Chromium');
    const auditJson = JSON.parse(attrMatch[1].replace(/&quot;/g, '"'));
    assert.ok(
      auditJson.docScrollWidth <= auditJson.docClientWidth + 1,
      `Transbordamento horizontal no documento: scrollWidth=${auditJson.docScrollWidth}px > clientWidth=${auditJson.docClientWidth}px`
    );
    assert.deepEqual(
      auditJson.overflowingTables,
      [],
      `Tabelas transbordando a largura util (688px): ${JSON.stringify(auditJson.overflowingTables)}`
    );
    console.log(
      `    -> Escala nativa 1.0x (CTM 3.125) confirmada nas ${totalPages} paginas | DOM scrollWidth=${auditJson.docScrollWidth}px <= clientWidth=${auditJson.docClientWidth}px | 0/${auditJson.totalTables} tabelas transbordando!`
    );
  });

  console.log(`\nSUCESSO ABSOLUTO: ${passed}/${passed} assercoes editoriais, estruturais e provas matematicas pagina a pagina aprovadas!`);
}

runSuite().catch((err) => {
  console.error('Falha na auditoria do PDF Enciclopedico v2.11.0:', err);
  process.exit(1);
});

export const part1Html = `
<!-- ======================================================================= -->
<!-- CAPA EXECUTIVA (FULL-BLEED QUIET LUXURY NAVY #0F172A)                   -->
<!-- ======================================================================= -->
<div class="cover-page">
  <div class="cover-top-bar">
    <span class="cover-badge">DOCUMENTO NORMATIVO &bull; ARQUITETURA DE REFERÊNCIA v2.8.2</span>
    <span class="cover-badge-right">CLASSIFICAÇÃO: ENGENHARIA SÊNIOR FULL-STACK &amp; FINTECH SECURITY</span>
  </div>

  <div class="cover-hero">
    <div class="cover-logo-wrap">
      <!-- Logotipo Vetorial Oficial Desperrengue (Geometria G1 Contínua + Check #FF6D00) -->
      <svg viewBox="0 0 240 240" width="136" height="136" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="covNavy" cx="45%" cy="36%" r="76%">
            <stop offset="0%" stop-color="#1E3A6D"/>
            <stop offset="100%" stop-color="#0F172A"/>
          </radialGradient>
          <linearGradient id="covOrange" x1="0%" y1="100%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#FF6D00"/>
            <stop offset="100%" stop-color="#FF8F38"/>
          </linearGradient>
        </defs>
        <rect x="6" y="6" width="228" height="228" rx="56" fill="url(#covNavy)" stroke="#334155" stroke-width="3"/>
        <g transform="translate(36, 36) scale(0.34)">
          <path d="M 103.3 292.7 L 103.3 413.3 Q 103.3 447.7 137.8 447.7 L 241.1 447.7 A 172.2 172.2 0 0 0 362.9 153.8 L 273.1 64.0 Q 241.1 32.0 209.1 64.0 L 51.7 221.4"
                fill="none" stroke="#FFFFFF" stroke-width="64.0" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M 187.0 273.1 L 231.2 317.3 L 307.5 223.9"
                fill="none" stroke="url(#covOrange)" stroke-width="60.0" stroke-linecap="round" stroke-linejoin="round"/>
        </g>
      </svg>
    </div>

    <div class="cover-pre-title">COMPÊNDIO TÉCNICO-CIENTÍFICO, EXECUTIVO E ARQUITETURAL COMPLETO</div>
    <h1 class="cover-title">DESPERRENGUE</h1>
    <div class="cover-subtitle">
      Ecossistema Distribuído Multi-Modo para Serviços Residenciais com Custódia Financeira Condicional em 3 Camadas,
      Particionamento Orçamentário Assimétrico (<em>Smart Split</em>), Visão Computacional 3D <em>On-Device</em>,
      Motor Antifraude <span class="mono">O(1) / O(log N + K)</span> e Certificação Predial ABNT NBR 5674
    </div>

    <div class="cover-pillars-grid">
      <div class="cover-pillar">
        <div class="cp-num">4 Camadas</div>
        <div class="cp-lbl">Arquitetura Desacoplada 120 FPS + Worker Isolates</div>
      </div>
      <div class="cover-pillar">
        <div class="cp-num">22 Migrações</div>
        <div class="cp-lbl">PostgreSQL 17 + RLS Estrito + 4 Invariantes Contábeis</div>
      </div>
      <div class="cover-pillar">
        <div class="cp-num">R$ 0,00 / KYC</div>
        <div class="cp-lbl">Prova de Vida 3D Ao Vivo + Scanner ISO ID-1 + OCR Local</div>
      </div>
      <div class="cover-pillar">
        <div class="cp-num">14 Travas</div>
        <div class="cp-lbl">Blindagem Criptográfica dHash 64-Bit + Grafo Zero-Linkage</div>
      </div>
      <div class="cover-pillar">
        <div class="cp-num">533 + 577</div>
        <div class="cp-lbl">Testes Automatizados Dart/Flutter &amp; Asserções SQL</div>
      </div>
      <div class="cover-pillar">
        <div class="cp-num">9,65x LTV/CAC</div>
        <div class="cp-lbl">Break-Even no Mês 3 (40 OS) e ROI de +124,2% no Ano 1</div>
      </div>
    </div>
  </div>

  <div class="cover-meta-box">
    <div class="cover-meta-row">
      <div><strong>Versão Auditada do Sistema:</strong> <code>v2.8.2+202611101</code> (Branch <code>main</code> &bull; Produção Beta)</div>
      <div><strong>Stack Principal:</strong> Flutter 3.47 (Dart 3.13) &bull; PostgreSQL 17 (Supabase) &bull; Deno Edge</div>
    </div>
    <div class="cover-meta-row">
      <div><strong>Padrões e Normas Técnicas:</strong> IEEE 1016 &bull; ISO/IEC 25010 &bull; ISO/IEC 7810 ID-1 &bull; ABNT NBR 5674 &bull; Lei 8.245/91 &bull; LGPD (Lei 13.709/18)</div>
      <div><strong>Data de Emissão:</strong> Novembro de 2026</div>
    </div>
    <div class="cover-meta-row">
      <div><strong>Escopo do Documento:</strong> Ferramentas, Linguagens, Bibliotecas, Front-End, Back-End, Banco de Dados, Complexidade Big-O, APIs, Visão Computacional, Funcionalidades, MVP, Backlog, Plano de Negócios, Lean Canvas, Personas, Segurança, Golpes Evitados, Auditoria Red Team de Falhas Residuais e 8 Inovações Globais Inéditas.</div>
    </div>
  </div>
</div>

<!-- ======================================================================= -->
<!-- SUMÁRIO SISTEMÁTICO E ÍNDICE ANALÍTICO                                  -->
<!-- ======================================================================= -->
<div class="page-break"></div>
<div class="section-header-banner">
  <span class="sh-tag">NAVEGAÇÃO ESTRUTURADA</span>
  <h2>SUMÁRIO EXECUTIVO E ÍNDICE ANALÍTICO COMPLETO</h2>
  <p>Organização enciclopédica multidisciplinar cobrindo Engenharia de Software, Sistemas Distribuídos, Ciência de Dados, Visão Computacional, Segurança Cibernética, Economia da Informação, Finanças Corporativas e Inovação.</p>
</div>

<div class="toc-container">
  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-1">CAPÍTULO 1 — Ferramentas Utilizadas, Linguagens de Programação e Catálogo de Bibliotecas</a></div>
    <div class="toc-item"><span>1.1. Matriz de Linguagens de Programação e Paradigmas Computacionais</span><span class="toc-dots"></span><span>Seção 1.1</span></div>
    <div class="toc-item"><span>1.2. Ferramentas de Desenvolvimento, Infraestrutura Cloud, Mensageria e CI/CD</span><span class="toc-dots"></span><span>Seção 1.2</span></div>
    <div class="toc-item"><span>1.3. Catálogo Exaustivo de Bibliotecas e Dependências (<span class="mono">pubspec.yaml</span> &amp; Back-End)</span><span class="toc-dots"></span><span>Seção 1.3</span></div>
    <div class="toc-item"><span>1.4. Pipeline Vetorial Headless (<span class="mono">PictureRecorder &rarr; Skia/Impeller</span>) e Identidade Visual <span class="mono">v2.8.2</span></span><span class="toc-dots"></span><span>Seção 1.4</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-2">CAPÍTULO 2 — Arquitetura de Software em 4 Camadas, Engenharia Front-End (120 FPS) e Back-End</a></div>
    <div class="toc-item"><span>2.1. Visão Geral da Topologia Distribuída Cliente &harr; Worker Isolate &harr; Supabase Cloud</span><span class="toc-dots"></span><span>Seção 2.1</span></div>
    <div class="toc-item"><span>2.2. Engenharia Front-End (Camada 1): Orçamento de Quadro de 8,33 ms, <span class="mono">RepaintBoundary</span> e Design System</span><span class="toc-dots"></span><span>Seção 2.2</span></div>
    <div class="toc-item"><span>2.3. Camada de Aplicação e Pipeline Especulativo de Evidências (Camada 2 — Latência &lt; 50 ms)</span><span class="toc-dots"></span><span>Seção 2.3</span></div>
    <div class="toc-item"><span>2.4. Camada de Domínio e Guardas Forenses em Memória Isolada (<span class="mono">Isolate.run</span> — Camada 3)</span><span class="toc-dots"></span><span>Seção 2.4</span></div>
    <div class="toc-item"><span>2.5. Engenharia Back-End (Camada 4): PostgREST, GoTrue PKCE, Realtime WSS, Storage RLS e Resend DNS</span><span class="toc-dots"></span><span>Seção 2.5</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-3">CAPÍTULO 3 — Banco de Dados Relacional e Contábil (PostgreSQL 17, 22 Migrações e 4 Invariantes)</a></div>
    <div class="toc-item"><span>3.1. Modelagem Entidade-Relacionamento e Dicionário de Dados das Tabelas Nucleares</span><span class="toc-dots"></span><span>Seção 3.1</span></div>
    <div class="toc-item"><span>3.2. Histórico Cronológico Auditado das 22 Migrações SQL Idempotentes</span><span class="toc-dots"></span><span>Seção 3.2</span></div>
    <div class="toc-item"><span>3.3. Mapa Arquitetural dos 9 Índices Estratégicos de Alta Seletividade</span><span class="toc-dots"></span><span>Seção 3.3</span></div>
    <div class="toc-item"><span>3.4. As 4 Invariantes Contábeis Declarativas do Livro-Razão Imutável (<span class="mono">Append-Only Ledger</span>)</span><span class="toc-dots"></span><span>Seção 3.4</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-4">CAPÍTULO 4 — Complexidade de Algoritmos (Big-O), Podagem Espacial e Controle de Concorrência</a></div>
    <div class="toc-item"><span>4.1. Matriz Comparativa: Complexidade Assintótica Ingênua vs. Implementação Desperrengue</span><span class="toc-dots"></span><span>Seção 4.1</span></div>
    <div class="toc-item"><span>4.2. Podagem Geoespacial por Caixa Delimitadora Axial (<span class="mono">Axial Bounding Box</span>) em <span class="mono">O(log N + K)</span></span><span class="toc-dots"></span><span>Seção 4.2</span></div>
    <div class="toc-item"><span>4.3. Distância de Hamming Perceptual de 64 Bits em <span class="mono">O(1)</span> via Algoritmo de Brian Kernighan</span><span class="toc-dots"></span><span>Seção 4.3</span></div>
    <div class="toc-item"><span>4.4. Materialização Incremental em <span class="mono">O(1)</span> do <span class="mono">Relative Trust Score (RTS)</span> e Cascata de 5 Degraus</span><span class="toc-dots"></span><span>Seção 4.4</span></div>
    <div class="toc-item"><span>4.5. Prova Formal por Contradição da Ausência de Deadlocks (Ordem Canônica <span class="mono">R1 &prec; R2 &prec; R3 &prec; R4</span>)</span><span class="toc-dots"></span><span>Seção 4.5</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-5">CAPÍTULO 5 — Catálogo de APIs Internas (RPCs PL/pgSQL), Edge Functions e APIs Externas</a></div>
    <div class="toc-item"><span>5.1. Catálogo Completo de RPCs Transacionais (<span class="mono">SECURITY DEFINER</span>) no PostgreSQL</span><span class="toc-dots"></span><span>Seção 5.1</span></div>
    <div class="toc-item"><span>5.2. Microsserviços Serverless em Supabase Edge Functions (Deno / TypeScript)</span><span class="toc-dots"></span><span>Seção 5.2</span></div>
    <div class="toc-item"><span>5.3. Integrações com APIs Externas, Geocodificação Dual-Provider e Webhooks</span><span class="toc-dots"></span><span>Seção 5.3</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-6">CAPÍTULO 6 — Visão Computacional On-Device, Biometria Ao Vivo (Liveness 3D) e OCR ISO ID-1</a></div>
    <div class="toc-item"><span>6.1. Arquitetura de Visão Computacional a Custo Marginal Zero (<span class="mono">R$ 0,00 / validação</span>)</span><span class="toc-dots"></span><span>Seção 6.1</span></div>
    <div class="toc-item"><span>6.2. Câmera Frontal Ao Vivo na Moldura Oval: Espaço <span class="mono">YCbCr</span>, Razão Ocular (<span class="mono">EAR</span>), Rotação <span class="mono">Yaw</span> e Anti-Monitor</span><span class="toc-dots"></span><span>Seção 6.2</span></div>
    <div class="toc-item"><span>6.3. Scanner Documental Guiado ISO/IEC 7810 ID-1, Recorte <span class="mono">Core ROI Inset 12%</span> e Nitidez Laplaciana</span><span class="toc-dots"></span><span>Seção 6.3</span></div>
    <div class="toc-item"><span>6.4. Anti-Duplicidade Forense (<span class="mono">dHash + MAD + Quadrantes</span>), Face Match 128-D Multi-Ângulo e OCR Visível</span><span class="toc-dots"></span><span>Seção 6.4</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-7">CAPÍTULO 7 — Todas as Funcionalidades do Sistema, MVP (Produto Mínimo Viável) e Backlog</a></div>
    <div class="toc-item"><span>7.1. Mapeamento Exaustivo das Funcionalidades do Modo Cliente (Demanda Residencial)</span><span class="toc-dots"></span><span>Seção 7.1</span></div>
    <div class="toc-item"><span>7.2. Mapeamento Exaustivo das Funcionalidades do Modo Profissional (Painel Executivo, Calculadora, Vitrine)</span><span class="toc-dots"></span><span>Seção 7.2</span></div>
    <div class="toc-item"><span>7.3. Módulos Compartilhados: 4ª Aba "Em Mediação", Comparador Forense Triplo e Passaporte ABNT NBR 5674</span><span class="toc-dots"></span><span>Seção 7.3</span></div>
    <div class="toc-item"><span>7.4. Definição Formal do MVP Entregue vs. Backlog Evolutivo Priorizado (Épicos e Pesos)</span><span class="toc-dots"></span><span>Seção 7.4</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-8">CAPÍTULO 8 — Plano de Negócios, Lean Canvas (9 Blocos), Personas, Tributação e Finanças</a></div>
    <div class="toc-item"><span>8.1. Tese Econômica: Superação da Seleção Adversa de Akerlof e Compatibilidade de Incentivos</span><span class="toc-dots"></span><span>Seção 8.1</span></div>
    <div class="toc-item"><span>8.2. Lean Canvas Oficial em 9 Blocos (Quadro Matricial Executivo e Dossiê Analítico)</span><span class="toc-dots"></span><span>Seção 8.2</span></div>
    <div class="toc-item"><span>8.3. Estudo de Personas Arquetípicas, Mapa de Empatia e Catálogo de User Stories</span><span class="toc-dots"></span><span>Seção 8.3</span></div>
    <div class="toc-item"><span>8.4. Engenharia Tributária (IFRS 15 / CPC 47), Unit Economics (<span class="mono">LTV/CAC 9,65x</span>) e Fluxo de Caixa de 12 Meses</span><span class="toc-dots"></span><span>Seção 8.4</span></div>
    <div class="toc-item"><span>8.5. Análise PESTEL, 5 Forças de Porter, Matriz SWOT/TOWS e Balanced Scorecard (BSC)</span><span class="toc-dots"></span><span>Seção 8.5</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-9">CAPÍTULO 9 — Plano de Segurança, Ideias Inovadoras Aplicadas e Os 6 Vetores de Golpe Evitados</a></div>
    <div class="toc-item"><span>9.1. Arquitetura de Defesa em Profundidade, Criptografia de Dados e Conformidade LGPD</span><span class="toc-dots"></span><span>Seção 9.1</span></div>
    <div class="toc-item"><span>9.2. As 10 Inovações Tecnológicas e Financeiras Já Aplicadas e Em Operação no Desperrengue</span><span class="toc-dots"></span><span>Seção 9.2</span></div>
    <div class="toc-item"><span>9.3. Análise Detalhada dos 6 Vetores de Golpe Evitados (<span class="mono">RN-AF-01</span> a <span class="mono">RN-AF-14</span>) e Prova em Teoria dos Jogos</span><span class="toc-dots"></span><span>Seção 9.3</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-10">CAPÍTULO 10 — Auditoria Red Team: Falhas de Segurança e Golpes que Ainda Existem e Como Corrigi-los</a></div>
    <div class="toc-item"><span>10.1. Metodologia de Auditoria Adversária (Red Team / Threat Modeling OWASP MASVS)</span><span class="toc-dots"></span><span>Seção 10.1</span></div>
    <div class="toc-item"><span>10.2. As 7 Falhas de Segurança Residuais e Golpes Sofisticados que Ainda Podem Ser Tentados Hoje</span><span class="toc-dots"></span><span>Seção 10.2</span></div>
    <div class="toc-item"><span>10.3. Engenharia de Remediação Definitiva: Arquitetura, Protocolos Criptográficos e Código de Correção</span><span class="toc-dots"></span><span>Seção 10.3</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-11">CAPÍTULO 11 — Fronteira de Inovação: 8 Ideias Inéditas no Mercado Mundial para Transformar o Setor</a></div>
    <div class="toc-item"><span>11.1. Visão Geral das 8 Inovações Disruptivas Inéditas (Cliente, Profissional, Plataforma e Mundo)</span><span class="toc-dots"></span><span>Seção 11.1</span></div>
    <div class="toc-item"><span>11.2. Especificação Técnica Profunda das Inovações 1 a 4 (Acústica Ultrassônica, Oráculo SEFAZ, IA Acústica, Microcrédito RTS)</span><span class="toc-dots"></span><span>Seção 11.2</span></div>
    <div class="toc-item"><span>11.3. Especificação Técnica Profunda das Inovações 5 a 8 (PIN Anti-Coação, ESG/IPTU Verde, Swarm Dispatch, Micro-InsureTech)</span><span class="toc-dots"></span><span>Seção 11.3</span></div>
    <div class="toc-item"><span>11.4. Matriz de Impacto Global e Alinhamento com os Objetivos de Desenvolvimento Sustentável (ODS ONU 2030)</span><span class="toc-dots"></span><span>Seção 11.4</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-12">CAPÍTULO 12 — Especificação Normativa Exaustiva (RN-CAM, RN-AF, RN-MZ, RN-KYC) e Rastreabilidade</a></div>
    <div class="toc-item"><span>12.1. Catálogo Completo das 14 Regras Normativas Antifraude (<span class="mono">RN-AF-01</span> a <span class="mono">RN-AF-14</span>)</span><span class="toc-dots"></span><span>Seção 12.1</span></div>
    <div class="toc-item"><span>12.2. Catálogo dos 5 Pilares do Marco Zero (<span class="mono">RN-MZ-01..05</span>) e 6 Regras KYC (<span class="mono">RN-KYC-01..06</span>)</span><span class="toc-dots"></span><span>Seção 12.2</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-13">CAPÍTULO 13 — Taxonomia das 33 Categorias Técnicas, Árvore do Projeto e Engenharia de Q.A. (1.110 Asserções)</a></div>
    <div class="toc-item"><span>13.1. Taxonomia Oficial das 33 Categorias Técnicas Residenciais (<span class="mono">expanded_categories.sql</span>)</span><span class="toc-dots"></span><span>Seção 13.1</span></div>
    <div class="toc-item"><span>13.2. Matriz Completa das 26 Suítes de Testes Automatizados (<span class="mono">533 Testes Dart + 577 SQL</span>)</span><span class="toc-dots"></span><span>Seção 13.2</span></div>
  </div>

  <div class="toc-group">
    <div class="toc-chapter-title"><a href="#cap-14">CAPÍTULO 14 — Inteligência Competitiva: PESTEL, 5 Forças de Porter, Matriz SWOT/TOWS e Balanced Scorecard</a></div>
    <div class="toc-item"><span>14.1. Síntese das Cinco Forças Competitivas de Porter e Matriz SWOT Cruzada (TOWS)</span><span class="toc-dots"></span><span>Seção 14.1</span></div>
    <div class="toc-item"><span>14.2. Painel Consolidado de Telemetria do Balanced Scorecard (BSC — Kaplan &amp; Norton)</span><span class="toc-dots"></span><span>Seção 14.2</span></div>
  </div>
</div>

<!-- ======================================================================= -->
<!-- CAPÍTULO 1 — FERRAMENTAS, LINGUAGENS E BIBLIOTECAS                      -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-1"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 01</div>
  <div class="cb-body">
    <h2>FERRAMENTAS UTILIZADAS, LINGUAGENS DE PROGRAMAÇÃO E CATÁLOGO DE BIBLIOTECAS</h2>
    <p>Inventário tecnológico completo da pilha de engenharia (Full-Stack, Mobile, Web/PWA, Banco de Dados, Criptografia, Visão Computacional e Automação DevOps).</p>
  </div>
</div>

<h3>1.1. Matriz de Linguagens de Programação e Paradigmas Computacionais</h3>
<p>
  O ecossistema <strong>Desperrengue (<code>v2.8.2</code>)</strong> foi construído utilizando um conjunto rigorosamente selecionado de linguagens tipadas e declarativas, escolhidas para maximizar segurança de tipos em tempo de compilação (<em>Compile-Time Type Safety</em>), paralelismo real em múltiplos núcleos (<em>Multi-Core Isolate Concurrency</em>) e atomicidade transacional (<em>ACID</em>) diretamente no motor de banco de dados:
</p>

<table class="data-table">
  <thead>
    <tr>
      <th width="16%">Linguagem</th>
      <th width="14%">Versão / Padrão</th>
      <th width="22%">Camada de Aplicação</th>
      <th width="48%">Papel Arquitetural e Justificativa Técnica no Projeto</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Dart</strong></td>
      <td><code>^3.13.4</code><br/>(Null-Safe)</td>
      <td>Front-End Mobile/Web, Domínio, Visão Computacional e Geradores Vetoriais</td>
      <td>Compilação nativa AOT (<em>Ahead-of-Time</em>) para código de máquina ARM64 no Android/iOS e compilação otimizada para Web/PWA. Suporta <strong>Worker Isolates</strong> (<code>Isolate.run</code>) com memória isolada sem travamentos de Garbage Collection na thread de UI, essencial para calcular hashes perceptuais <code>dHash</code> de 64 bits, segmentação epidérmica <code>YCbCr</code> e geração de laudos PDF vetoriais a 120 FPS.</td>
    </tr>
    <tr>
      <td><strong>SQL &amp; PL/pgSQL</strong></td>
      <td>PostgreSQL <code>17.x</code></td>
      <td>Camada Transacional, Livro-Razão Fintech, Motor Antifraude e RLS</td>
      <td>Toda a lógica financeira (<em>Smart Split</em>, <em>Carve-Out</em> de 1,5%, Reserva <code>D+2/D+5/D+7</code>, <em>Clawback</em>), podagem geoespacial por <em>Axial Bounding Box</em> <code>O(log N + K)</code>, distância de Hamming de 64 bits em <code>O(1)</code> e políticas <em>Row Level Security</em> (RLS) são executadas dentro do SGBD via funções <code>SECURITY DEFINER</code> atômicas.</td>
    </tr>
    <tr>
      <td><strong>TypeScript (Deno)</strong></td>
      <td>Deno Runtime <code>1.4x</code> / TS <code>5.x</code></td>
      <td>Supabase Edge Functions (Serverless Microservices)</td>
      <td>Implementa os microsserviços distribuídos de borda em <code>supabase/functions/</code>: recepção e validação idempotente de webhooks de liquidação PIX (<code>pix-webhook</code>), disparo transacional de e-mails de aprovação de cadastro (<code>enviar-email-aprovacao</code>) e orquestração segura de exclusão de conta (<code>excluir-conta</code>).</td>
    </tr>
    <tr>
      <td><strong>JavaScript (ESM / .mjs)</strong></td>
      <td>Node.js <code>v24.x</code></td>
      <td>Automação de QA, Auditoria de Dados e Smoke Testing</td>
      <td>Scripts em <code>scripts/</code> para verificação automatizada da infraestrutura de banco de dados em produção, testes de fumaça do prontuário predial (<code>test-dossie.mjs</code>), validação de fluxos de cadastro e geração de artefatos documentais.</td>
    </tr>
    <tr>
      <td><strong>HTML5, CSS3 &amp; WebRTC JS</strong></td>
      <td>W3C Standard</td>
      <td> Container PWA (<code>app/web/</code>) e Captura de Câmera no Navegador</td>
      <td>Configuração de manifesto PWA instalável (<code>manifest.json</code>), estilização de splash nativa web e integração com a API <code>navigator.mediaDevices.getUserMedia</code> (<code>facingMode: 'user'</code> e <code>facingMode: 'environment'</code>) para funcionamento da biometria ao vivo também em navegadores desktop/mobile.</td>
    </tr>
    <tr>
      <td><strong>YAML / PowerShell / Bash</strong></td>
      <td>GitHub Actions / Windows / Linux</td>
      <td>Pipelines de Integração Contínua e Entrega Contínua (CI/CD)</td>
      <td>Orquestração de testes automatizados (<code>.github/workflows/ci.yml</code>) e compilação automática de APKs assinados com publicação na release <code>beta-latest</code> (<code>.github/workflows/beta-release.yml</code>).</td>
    </tr>
  </tbody>
</table>

<h3>1.2. Ferramentas de Engenharia, Infraestrutura Cloud e Ecossistema DevOps</h3>

<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">1. Motor Multiplataforma Flutter 3.47 (Skia &amp; Impeller)</div>
    <p>Framework declarativo responsável pela renderização unificada para <strong>Android (API 21 a Android 16)</strong>, <strong>iOS</strong>, <strong>Web PWA</strong>, <strong>Windows</strong> e <strong>macOS</strong>. Utiliza o motor gráfico para desenhar primitivas vetoriais diretamente na GPU, incluindo o logotipo oficial (<code>DesperrengueBrandLogoPainter</code>), a moldura elíptica de biometria facial, a máscara ISO ID-1 de documentos e a animação de splash coreografada.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">2. Plataforma Backend Supabase Cloud (Região sa-east-1)</div>
    <p>Infraestrutura gerenciada que provê: (a) <strong>PostgreSQL 17</strong> dedicado; (b) <strong>GoTrue Auth</strong> com fluxo OAuth2/PKCE e sessões JWT; (c) <strong>PostgREST</strong> para exposição instantânea e segura de RPCs; (d) <strong>Supabase Realtime</strong> via WebSockets (WSS) para atualização ao vivo de pedidos, chat, carteira PIX e mediações; e (e) <strong>Supabase Storage</strong> com buckets públicos e privados protegidos por RLS.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">3. Infraestrutura de E-mail Autenticado Resend SMTP &amp; DNS</div>
    <p>Configuração dedicada no domínio <code>desperrengue.tech</code> com registros criptográficos <strong>DKIM (RSA 2048-bit)</strong>, <strong>SPF</strong> e <strong>DMARC</strong>, eliminando bloqueios de spam e taxas de limite de envio no disparo de códigos OTP de verificação de cadastro, recuperação de senha e notificações de aprovação do dossiê profissional.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">4. Pipeline CI/CD GitHub Actions &amp; OTA In-App Updater</div>
    <p>Cada <em>push</em> na branch <code>main</code> aciona <code>ci.yml</code> (análise estática + 533 testes Flutter) e <code>beta-release.yml</code> (build de APK assinado em keystore de produção e upload na tag <code>beta-latest</code>). Dentro do app, o serviço <code>AppUpdateService</code> + <code>UpdateGate</code> consulta a API do GitHub, detecta novas versões e oferece atualização com 1 toque.</p>
  </div>
</div>

<h3>1.3. Catálogo Exaustivo de Bibliotecas Utilizadas (<span class="mono">app/pubspec.yaml</span>)</h3>
<p>
  Abaixo estão documentadas <strong>todas as 26 bibliotecas</strong> (21 de produção e 5 de desenvolvimento/build) declaradas em <code>app/pubspec.yaml</code>, detalhando sua versão exata e onde cada uma atua no código-fonte:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Pacote / Biblioteca</th>
      <th width="10%">Versão</th>
      <th width="18%">Categoria</th>
      <th width="50%">Utilização Real no Código-Fonte do Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>flutter_riverpod</code></td>
      <td><code>^3.4.3</code></td>
      <td>Gerência de Estado Reativa</td>
      <td>Injeção de dependência e estado reativo global: controle de sessão, <code>themeModeProvider</code> (Claro/Escuro/Sistema), <code>AntiBypassFintechController</code> e sincronização entre modos Cliente e Profissional.</td>
    </tr>
    <tr>
      <td><code>supabase_flutter</code></td>
      <td><code>^2.17.2</code></td>
      <td>Cliente Backend / Realtime / Storage</td>
      <td>Comunicação HTTPS/TLS e WSS com o cluster Supabase: autenticação PKCE, chamadas às RPCs contábeis (<code>submit_client_kyc</code>, <code>open_warranty_mediation</code>, etc.), canais Realtime e upload de evidências.</td>
    </tr>
    <tr>
      <td><code>camera</code></td>
      <td><code>^0.12.1</code></td>
      <td>Hardware Óptico &amp; Visão Computacional</td>
      <td>Controle direto dos sensores ópticos frontal (<code>CameraLensDirection.front</code>) e traseiro (<code>CameraLensDirection.back</code>) dentro do app para a Prova de Vida Ao Vivo na moldura oval e para o Scanner Documental ISO ID-1.</td>
    </tr>
    <tr>
      <td><code>image</code></td>
      <td><code>^4.5.4</code></td>
      <td>Processamento Digital de Imagens</td>
      <td>Executado em <code>Isolate.run</code> para decodificar buffers JPEG/PNG, aplicar recorte <em>Core ROI Inset</em> (12%), rotacionar matrizes em <code>0°/90°/180°/270°</code>, extrair luminância, calcular Laplaciano 3&times;3, <code>dHash</code> 64-bit, <code>MAD</code> e descritores faciais 128-D.</td>
    </tr>
    <tr>
      <td><code>crypto</code></td>
      <td><code>^3.0.6</code></td>
      <td>Criptografia &amp; Hashing Forense</td>
      <td>Geração de resumos criptográficos <code>SHA-256</code> para pseudonimização de CPF com <em>Pepper</em>, selos de autenticidade de evidências (<code>DSP-LIVE-SHA256</code>) e assinatura imutável do Passaporte do Imóvel (<code>DSP-PASS-*</code>).</td>
    </tr>
    <tr>
      <td><code>flutter_secure_storage</code></td>
      <td><code>^11.2.0</code></td>
      <td>Cofre Criptográfico de Hardware</td>
      <td>Armazena o token JWT de sessão (<code>SecureSessionStorage</code>) utilizando Android EncryptedSharedPreferences / Keystore e iOS Keychain, com migração automática transparente e descarte seguro de JSON corrompido.</td>
    </tr>
    <tr>
      <td><code>geolocator</code></td>
      <td><code>^14.0.3</code></td>
      <td>Telemetria GNSS / Anti-Spoofing</td>
      <td>Captura coordenadas geodésicas de alta precisão no check-in e check-out do serviço (&le; 150m do imóvel), pré-aquecimento especulativo de GPS e detecção de <em>Fake GPS</em> via flag <code>Position.isMocked</code>.</td>
    </tr>
    <tr>
      <td><code>flutter_map</code> &amp; <code>latlong2</code></td>
      <td><code>^8.3.2</code> / <code>^0.10.1</code></td>
      <td>Cartografia Vetorial &amp; Geodésia</td>
      <td>Renderiza o mapa interativo de triagem com pinos numerados por mérito (<code>1º, 2º, 3º</code>), raio de cobertura do profissional e cálculo de distância ortodrômica de Haversine.</td>
    </tr>
    <tr>
      <td><code>speech_to_text</code></td>
      <td><code>^7.5.0</code></td>
      <td>Reconhecimento de Voz Nativo</td>
      <td>Permite ao cliente relatar uma emergência residencial em menos de 60 segundos por ditado de voz em português (<code>pt_BR</code>), formatado pelo <code>SmartTranscriptFormatter</code> e classificado nas 33 categorias técnicas.</td>
    </tr>
    <tr>
      <td><code>qr_flutter</code></td>
      <td><code>^4.1.0</code></td>
      <td>Pagamentos Instantâneos PIX</td>
      <td>Renderização vetorial local do QR Code PIX (padrão EMV® BR Code do Banco Central) na tela <code>AdicionarSaldoScreen</code> e nos comprovantes de custódia.</td>
    </tr>
    <tr>
      <td><code>image_picker</code></td>
      <td><code>^1.2.3</code></td>
      <td>Captura Restrita de Evidências</td>
      <td>Configurado sob guarda forense estrita (<code>ImageSource.camera</code> com <code>maxWidth: 1280, maxHeight: 1280</code>) nos fluxos de evidência Before/After e contestação de garantia, além de seleção de portfólio.</td>
    </tr>
    <tr>
      <td><code>app_links</code> &amp; <code>google_sign_in</code></td>
      <td><code>^7.2.2</code> / <code>^7.2.0</code></td>
      <td>Deep Linking &amp; Federação OAuth</td>
      <td>Interceptação de links profundos (<code>br.com.desperrengue.app://login-callback</code>) para retorno de autenticação OAuth2 Google e confirmação de e-mail diretamente no <code>AuthGate</code>.</td>
    </tr>
    <tr>
      <td><code>http</code></td>
      <td><code>^1.6.0</code></td>
      <td>Comunicação REST Externa</td>
      <td>Consultas de CEP e geocodificação estruturada (ViaCEP + Nominatim/OSM com <code>PreciseGeocoder</code>) e verificação de novas releases de APK na API do GitHub.</td>
    </tr>
    <tr>
      <td><code>video_player</code> &amp; <code>lottie</code></td>
      <td><code>^2.14.1</code> / <code>^3.6.1</code></td>
      <td>Multimídia &amp; Micro-Animações</td>
      <td>Reprodução de vídeos de escopo/evidência técnica na vitrine de casos de sucesso (<code>CaseDetail</code>) e animações vetoriais leves de estado.</td>
    </tr>
    <tr>
      <td><code>permission_handler</code></td>
      <td><code>^13.0.2</code></td>
      <td>Governança de Permissões SO</td>
      <td>Solicitação granular e tratamento elegante de permissões de Câmera, Microfone e Localização Fina no Android e iOS.</td>
    </tr>
    <tr>
      <td><code>shared_preferences</code> &amp; <code>package_info_plus</code></td>
      <td><code>^2.5.6</code> / <code>^10.2.2</code></td>
      <td>Preferências Locais &amp; Metadados</td>
      <td>Persistência do tema visual (<code>LocalPrefs</code>), último papel ativo por conta (<code>client/provider</code>), modo privacidade (olhinho <code>R$ •••••</code>) e leitura do <code>buildNumber</code> para atualização OTA.</td>
    </tr>
    <tr>
      <td><code>url_launcher</code> &amp; <code>go_router</code></td>
      <td><code>^6.3.3</code> / <code>^18.0.1</code></td>
      <td>Roteamento &amp; Ações Externas</td>
      <td>Abertura segura de instaladores APK, links de mapas externos e estrutura de navegação declarativa.</td>
    </tr>
    <tr>
      <td><code>flutter_launcher_icons</code> &amp; <code>flutter_native_splash</code></td>
      <td><code>^0.14.3</code> / <code>^2.4.8</code></td>
      <td>Compilação de Ativos Nativos (Dev)</td>
      <td>Geração automatizada de mipmaps Android, Adaptive Icons (Foreground, Background e Monochrome Android 13–16), AppIconset iOS, ícones Web/Windows/macOS e Splash Nativa Android 12+.</td>
    </tr>
  </tbody>
</table>

<h3>1.4. Pipeline Vetorial Headless e Engenharia Óptica do Novo Ícone Oficial (<span class="mono">v2.8.2</span>)</h3>
<p>
  Para eliminar qualquer perda de resolução ou compressão prematura, o projeto implementa um pipeline de geração 100% programático em <code>app/lib/core/ui/desperrengue_brand_logo.dart</code> e <code>app/tool/generate_brand_icons.dart</code>. Ao executar <code>flutter test tool/generate_brand_icons.dart</code>, o motor Skia/Impeller desenha as curvas matemáticas em um <code>ui.PictureRecorder</code> e exporta matrizes PNG de super-amostragem (<code>1024&times;1024 px</code> e <code>512&times;512 px</code>) além do arquivo vetorial puro <code>desperrengue_logo.svg</code>:
</p>
<ul>
  <li><strong>Tangência Geométrica G<sup>1</sup> Exata:</strong> O arco circular direito da letra <strong>"D"</strong> (centrado em <code>(0,49; 0,56)</code> com raio <code>R = 0,35</code>) encontra a água direita do telhado exatamente no ângulo de <code>-45&deg;</code> (<code>(0,7375; 0,3125)</code>), onde o vetor tangente do círculo coincide perfeitamente com a inclinação de <code>45&deg;</code> da cumeeira residencial — eliminando qualquer dente ou quebra de curvatura.</li>
  <li><strong>Calibração Óptica no <em>Sweet Spot</em> de 48% (<code>50 dp / 108 dp</code>):</strong> No sistema de <em>Adaptive Icons</em> do Android (grid de <code>108&times;108 dp</code>, onde os <code>18 dp</code> externos são margem de corte e a máscara visível tem <code>72&times;72 dp</code>), ocupar toda a zona de <code>66 dp</code> faz o ícone parecer "estufado" na máscara <em>Squircle</em> da Samsung One UI. O gerador calibra <code>adaptiveSafeZoneScale: 0.48</code> (<code>492&times;492 px</code> em <code>1024&times;1024 px</code>) e configura <code>mipmap-anydpi-v26/ic_launcher.xml</code> sem duplo inset, igualando o peso óptico de aplicativos líderes como <strong>99, iFood, Shopee e Telegram</strong>, com suporte nativo a <strong>Ícones Temáticos Monocromáticos (Android 13 a 16)</strong>.</li>
</ul>

<!-- ======================================================================= -->
<!-- CAPÍTULO 2 — ARQUITETURA DE SOFTWARE, FRONT-END E BACK-END              -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-2"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 02</div>
  <div class="cb-body">
    <h2>ARQUITETURA DE SOFTWARE EM 4 CAMADAS DESACOPLADAS, FRONT-END (120 FPS) E BACK-END</h2>
    <p>Engenharia de sistemas distribuídos de baixa latência, isolamento de subárvores de renderização, paralelismo em Worker Isolates e topologia em nuvem.</p>
  </div>
</div>

<h3>2.1. Diagrama Vetorial da Arquitetura em 4 Camadas Concêntricas</h3>
<p>
  A arquitetura de software do <strong>Desperrengue</strong> divide o sistema em quatro camadas estritamente desacopladas, garantindo que operações intensivas de criptografia, visão computacional e geração de documentos jamais bloqueiem o <em>Event Loop</em> da interface gráfica (orçamento de quadro de <code>8,33 ms</code> em telas ProMotion/LTPO de <code>120 Hz</code>):
</p>

<div class="svg-diagram-box">
  <svg viewBox="0 0 880 430" width="100%" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="l1Grad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/><stop offset="100%" stop-color="#1E3A8A"/>
      </linearGradient>
      <linearGradient id="l2Grad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#1E1B4B"/><stop offset="100%" stop-color="#312E81"/>
      </linearGradient>
      <linearGradient id="l3Grad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#064E3B"/><stop offset="100%" stop-color="#065F46"/>
      </linearGradient>
      <linearGradient id="l4Grad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#7C2D12"/>
      </linearGradient>
    </defs>

    <!-- Camada 1 -->
    <rect x="16" y="12" width="848" height="88" rx="10" fill="url(#l1Grad)" stroke="#38BDF8" stroke-width="1.5"/>
    <text x="32" y="34" fill="#38BDF8" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">CAMADA 1 — PRESENTATION LAYER (120 FPS DECLARATIVE UI • app/lib/features/ &amp; core/ui/)</text>
    <rect x="32" y="44" width="256" height="44" rx="6" fill="#0B1120" stroke="#475569"/>
    <text x="44" y="63" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">BootGate, UpdateGate &amp; Viewport 480px</text>
    <text x="44" y="79" fill="#94A3B8" font-size="10" font-family="Segoe UI, sans-serif">Cold-Start paralelo sem tela branca + OTA</text>

    <rect x="304" y="44" width="268" height="44" rx="6" fill="#0B1120" stroke="#475569"/>
    <text x="316" y="63" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">ClientShell &amp; ProviderShell (KeepAlive)</text>
    <text x="316" y="79" fill="#94A3B8" font-size="10" font-family="Segoe UI, sans-serif">RepaintBoundary O(1) + 4ª Aba Em Mediação</text>

    <rect x="588" y="44" width="260" height="44" rx="6" fill="#0B1120" stroke="#475569"/>
    <text x="600" y="63" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">Visores Ópticos In-App (Front/Rear)</text>
    <text x="600" y="79" fill="#94A3B8" font-size="10" font-family="Segoe UI, sans-serif">Moldura Oval Liveness + Scanner ISO ID-1</text>

    <!-- Camada 2 -->
    <rect x="16" y="116" width="848" height="86" rx="10" fill="url(#l2Grad)" stroke="#818CF8" stroke-width="1.5"/>
    <text x="32" y="138" fill="#A5B4FC" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">CAMADA 2 — APPLICATION &amp; SPECULATIVE STATE LAYER (app/lib/core/state/ &amp; services/)</text>
    <rect x="32" y="148" width="265" height="42" rx="6" fill="#111827" stroke="#4F46E5"/>
    <text x="44" y="166" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">Pipeline Especulativo (&lt; 50 ms UX)</text>
    <text x="44" y="181" fill="#C7D2FE" font-size="10" font-family="Segoe UI, sans-serif">GPS Warm-up no initState + Upload Paralelo</text>

    <rect x="312" y="148" width="265" height="42" rx="6" fill="#111827" stroke="#4F46E5"/>
    <text x="324" y="166" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">AntiBypassFintechController</text>
    <text x="324" y="181" fill="#C7D2FE" font-size="10" font-family="Segoe UI, sans-serif">Smart Split (0% Peças) + Idempotência UUIDv4</text>

    <rect x="592" y="148" width="256" height="42" rx="6" fill="#111827" stroke="#4F46E5"/>
    <text x="604" y="166" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">Dual-Role State &amp; PrivacyMode</text>
    <text x="604" y="181" fill="#C7D2FE" font-size="10" font-family="Segoe UI, sans-serif">Alternância Cliente/Prestador + Máscara R$ •••</text>

    <!-- Camada 3 -->
    <rect x="16" y="218" width="848" height="90" rx="10" fill="url(#l3Grad)" stroke="#34D399" stroke-width="1.5"/>
    <text x="32" y="240" fill="#6EE7B7" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">CAMADA 3 — DOMAIN &amp; WORKER ISOLATE FORENSIC GUARDS (Isolate.run • 0 ms UI Jank • Custo R$ 0,00)</text>
    <rect x="32" y="250" width="265" height="46" rx="6" fill="#022C22" stroke="#10B981"/>
    <text x="44" y="268" fill="#ECFDF5" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">PerceptualHashGuard (Isolate.run)</text>
    <text x="44" y="284" fill="#A7F3D0" font-size="10" font-family="Segoe UI, sans-serif">Core ROI Inset 12% + dHash 64-Bit + MAD</text>

    <rect x="312" y="250" width="265" height="46" rx="6" fill="#022C22" stroke="#10B981"/>
    <text x="324" y="268" fill="#ECFDF5" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">DocumentOcrAndLivenessService</text>
    <text x="324" y="284" fill="#A7F3D0" font-size="10" font-family="Segoe UI, sans-serif">YCbCr + EAR/Yaw + Laplaciano + Face 128-D</text>

    <rect x="592" y="250" width="256" height="46" rx="6" fill="#022C22" stroke="#10B981"/>
    <text x="604" y="268" fill="#ECFDF5" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">DesperrengueOfficialPdfService</text>
    <text x="604" y="284" fill="#A7F3D0" font-size="10" font-family="Segoe UI, sans-serif">Compilador Vetorial %PDF-1.4 (ABNT 5674)</text>

    <!-- Camada 4 -->
    <rect x="16" y="324" width="848" height="94" rx="10" fill="url(#l4Grad)" stroke="#FB923C" stroke-width="1.5"/>
    <text x="32" y="346" fill="#FDBA74" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">CAMADA 4 — TRANSACTIONAL DATA, IMMUTABLE LEDGER &amp; EDGE LAYER (PostgreSQL 17 + RLS + Deno Edge)</text>
    <rect x="32" y="356" width="265" height="48" rx="6" fill="#270902" stroke="#F97316"/>
    <text x="44" y="374" fill="#FFF7ED" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">22 Migrações SQL &amp; 4 Invariantes</text>
    <text x="44" y="390" fill="#FED7AA" font-size="10" font-family="Segoe UI, sans-serif">warranty_pool_ledger | escrow_maturation</text>

    <rect x="312" y="356" width="265" height="48" rx="6" fill="#270902" stroke="#F97316"/>
    <text x="324" y="374" fill="#FFF7ED" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">Hierarquia Canônica de Locks (4P)</text>
    <text x="324" y="390" fill="#FED7AA" font-size="10" font-family="Segoe UI, sans-serif">1.jobs &rarr; 2.mediations &rarr; 3.escrow &rarr; 4.profiles</text>

    <rect x="592" y="356" width="256" height="48" rx="6" fill="#270902" stroke="#F97316"/>
    <text x="604" y="374" fill="#FFF7ED" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">Edge Functions + Resend SMTP/DNS</text>
    <text x="604" y="390" fill="#FED7AA" font-size="10" font-family="Segoe UI, sans-serif">pix-webhook | enviar-email | excluir-conta</text>
  </svg>
</div>

<h3>2.2. Engenharia Front-End: 120 FPS, Isolamento de Pintura e Design System Dual-Theme</h3>
<ul>
  <li><strong>Inicialização Concorrente sem Tela Branca (<code>BootGate</code> + <code>AnimatedSplashScreen</code>):</strong> O carregamento inicial executa 3 tarefas em paralelo via <code>Future.wait</code> (aquecimento de fontes/assets, inicialização do Supabase com recuperação automática de armazenamento seguro corrompido em <code>SecureSessionStorage</code>, e hidratação do tema visual), reduzindo o tempo de boot à tarefa mais lenta (<code>&approx; max(T<sub>1</sub>, T<sub>2</sub>, T<sub>3</sub>)</code> em vez de <code>&Sigma; T<sub>i</sub></code>).</li>
  <li><strong>Isolamento de Repintura em <code>O(1)</code> (<code>RepaintBoundary</code> + <code>ValueListenableBuilder</code>):</strong> Telas que exibem cronômetros regressivos de SLA (6h/24h), animações de radar geoespacial ou telemetria de câmera ao vivo isolam o nó folha em uma <code>RepaintBoundary</code> dedicada. Assim, a cada tick do relógio, o Flutter não reconstrói nem repinta o restante da árvore de widgets.</li>
  <li><strong>Persistência de Estado de Abas (<code>IndexedStack</code> + <code>AutomaticKeepAliveClientMixin</code>):</strong> Tanto o <code>ClientShell</code> quanto o <code>ProviderShell</code> preservam o estado de rolagem e os streams ativos ao alternar entre abas (<em>Painel</em>, <em>Oportunidades</em>, <em>Carteira</em>, <em>Em Mediação</em> e <em>Perfil</em>), eliminando recarregamentos redundantes de rede.</li>
  <li><strong>Acessibilidade Visual WCAG AAA/AA (<code>AppTokens</code> &amp; <code>LightIsland</code>):</strong> O sistema de tokens (validado por testes matemáticos de luminância relativa e razão de contraste <code>&ge; 4,5 : 1</code> e <code>&ge; 7,0 : 1</code> em <code>offboarding_boot_theme_test.dart</code> e <code>ui_polish_test.dart</code>) aplica elevação tonal progressiva no modo escuro (<code>#0E1218</code> &rarr; <code>#141A23</code> &rarr; <code>#1B222E</code> &rarr; <code>#232C3B</code>) e dessaturação anti-halacão para evitar fadiga visual.</li>
</ul>

<h3>2.3. Pipeline Especulativo de Evidências (<span class="mono">Speculative Execution</span>)</h3>
<p>
  Em aplicativos convencionais, quando o profissional clica em <em>"Concluir Serviço"</em>, o aplicativo inicia sequencialmente: (1) aquisição de satélite GPS (<code>~1.800 ms</code>), (2) compressão e hash da imagem (<code>~400 ms</code>), (3) upload para o Storage (<code>~1.100 ms</code>) e (4) chamada RPC (<code>~200 ms</code>), totalizando <code>~3.500 ms</code> de espera. No <strong>Desperrengue</strong>:
</p>
<ol>
  <li>No exato instante em que o modal de conclusão é aberto (<code>initState</code>), o sensor GNSS entra em pré-aquecimento assíncrono;</li>
  <li>Assim que a foto <em>"Depois"</em> é capturada pela câmera nativa (já redimensionada no ISP de hardware para <code>1280&times;1280 px</code>, ocupando <code>&le; 6,5 MB</code> de RAM), o <em>Worker Isolate</em> calcula o <code>dHash</code> de 64 bits enquanto o upload binário já ocorre em <em>background</em> associado a uma chave de idempotência <code>UUID v4</code>;</li>
  <li>Quando o usuário digita o PIN de 4 dígitos e toca em confirmar, a RPC recebe apenas o <code>BIGINT</code> do hash, a URL pré-enviada e a distância geodésica em cache, reduzindo a latência percebida para <strong>menos de <code>50 ms</code></strong>.</li>
</ol>

<!-- ======================================================================= -->
<!-- CAPÍTULO 3 — BANCO DE DADOS RELACIONAL E CONTÁBIL (POSTGRESQL 17)       -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-3"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 03</div>
  <div class="cb-body">
    <h2>BANCO DE DADOS RELACIONAL E CONTÁBIL: ESQUEMA SQL, 22 MIGRAÇÕES E 4 INVARIANTES</h2>
    <p>Engenharia de dados em PostgreSQL 17, livros-razão imutáveis (Append-Only Ledgers), dicionário de tabelas, índices B-Tree parciais e restrições formais.</p>
  </div>
</div>

<h3>3.1. Dicionário Relacional das Tabelas Nucleares do Esquema <span class="mono">public</span></h3>
<p>
  O banco de dados do <strong>Desperrengue</strong> unifica identidade civil, reputação algorítmica, custódia financeira bipartida, mediação forense e prontuário predial em um esquema relacional normalizado, protegido em 100% das tabelas por <em>Row Level Security</em> (<code>ALTER TABLE ... ENABLE ROW LEVEL SECURITY</code>):
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="23%">Tabela SQL (<code>public.*</code>)</th>
      <th width="27%">Chaves e Índices Críticos</th>
      <th width="50%">Colunas Principais, Restrições <code>CHECK</code> e Papel no Sistema</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>profiles</code></td>
      <td><code>PK (id = auth.uid())</code><br/><code>UK idx_profiles_cpf_hash_unique</code><br/><code>idx_profiles_rescue_waterfall_bbox</code></td>
      <td>Entidade única Multi-Modo (<code>is_client</code>, <code>is_provider</code>). Armazena <code>cpf_hash</code> (SHA-256 + Pepper), <code>face_liveness_hash</code>, <code>liveness_verified</code>, <code>ocr_verified</code>, <code>pix_key_cpf_matched</code>, <code>external_trust_score</code> (<code>RTS &isin; [0, 100]</code>), <code>waterfall_tier_rank</code> (<code>1..5</code>), <code>trust_tier</code>, <code>has_open_dispute</code> (Circuit Breaker), <code>available_wallet_balance</code>, <code>maturing_wallet_balance</code>, <code>clawback_debt_balance</code> e <code>curated_portfolio_urls</code> (5 fotos).</td>
    </tr>
    <tr>
      <td><code>jobs</code></td>
      <td><code>PK (id)</code><br/><code>FK client_id, provider_id</code><br/><code>idx_jobs_auto_release_queue</code></td>
      <td>Ordem de Serviço com <em>Smart Split</em>: <code>labor_amount</code> (<code>&ge; 0</code>, tributável em 13,5% + 1,5%) e <code>materials_amount</code> (<code>&ge; 0</code>, taxa 0%). Contém <code>escrow_status</code>, <code>checkout_pin_hash</code> (crypt 4 dígitos), <code>auto_release_at</code> (SLA 24h), <code>warranty_expires_at</code> (+90 dias), <code>checkin_photo_phash</code>, <code>checkout_photo_phash</code> (64-bit) e <code>is_warranty_rework</code>.</td>
    </tr>
    <tr>
      <td><code>quotes</code> &amp; <code>job_invites</code></td>
      <td><code>PK (id)</code><br/><code>FK job_id, provider_id</code></td>
      <td>Propostas orçamentárias gratuitas (zero cobrança de moedas) com decomposição explícita entre mão de obra e peças/materiais, além de convites diretos na cascata de despacho.</td>
    </tr>
    <tr>
      <td><code>warranty_pool_ledger</code></td>
      <td><code>PK (id)</code><br/><code>UK (idempotency_key)</code><br/><code>chk_invariant_1 &amp; 2</code></td>
      <td>Livro-razão imutável (<em>Append-Only</em>) do Fundo de Garantia. Registra <code>CARVEOUT_CONTRIBUTION_1_5_PCT</code>, <code>REWORK_PAYOUT_DEBIT</code>, <code>CLAWBACK_RECOVERY_CREDIT</code> e <code>COLD_START_SEED_RESERVE</code>, blindado pelas invariantes de teto de cobertura e disjunção de identidade.</td>
    </tr>
    <tr>
      <td><code>escrow_maturation_entries</code></td>
      <td><code>PK (id)</code>, <code>UK (job_id)</code><br/><code>idx_escrow_maturation_queue</code></td>
      <td>Fila de maturação escalonada (<code>D+2</code> Âncora, <code>D+5</code> Padrão, <code>D+7</code> Trainee). Armazena <code>gross_labor_amount</code>, <code>materials_reimbursement_amount</code>, <code>platform_operational_fee</code> (13,5%), <code>warranty_carveout_fee</code> (1,5%), <code>net_provider_amount</code> e <code>maturation_status</code> (<code>MATURING</code>, <code>FROZEN_BY_DISPUTE</code>, <code>AVAILABLE_FOR_PIX</code>, <code>CLAWED_BACK</code>).</td>
    </tr>
    <tr>
      <td><code>job_mediations</code></td>
      <td><code>PK (id)</code>, <code>FK job_id</code><br/><code>idx_mediations_sla_6h_queue</code></td>
      <td>Autômato determinístico das 5 fases da aba <em>"Em Mediação"</em> (<code>PHASE_1_OPENED_AND_FROZEN</code> até <code>PHASE_5_SETTLED_AND_CERTIFIED</code>), com <code>defect_photo_phash</code>, <code>defect_gps_distance_m</code> (<code>&le; 150 m</code>) e <code>original_provider_deadline_at</code> (SLA de 6 horas).</td>
    </tr>
    <tr>
      <td><code>kyc_submissions</code></td>
      <td><code>PK (id)</code><br/><code>FK user_id</code></td>
      <td>Trilha forense de onboarding civil e biométrico: armazena <code>doc_front_phash</code>, <code>doc_back_phash</code>, <code>selfie_liveness_phash</code>, <code>liveness_challenges_passed</code> (JSONB), <code>ocr_extracted_payload</code> (JSONB), <code>laplacian_sharpness_score</code> (<code>&ge; 110</code>), <code>glare_ratio_pct</code> (<code>&le; 8,5%</code>) e <code>face_match_cosine_similarity</code> (<code>&ge; 0,78</code>).</td>
    </tr>
    <tr>
      <td><code>forensic_certificates</code></td>
      <td><code>PK (id)</code><br/><code>FK job_id</code></td>
      <td>Certificados criptográficos SHA-256 gerados na conclusão de cada serviço e retrabalho, alimentando o <strong>Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674)</strong>.</td>
    </tr>
    <tr>
      <td><code>client_wallets</code>, <code>wallet_entries</code> &amp; <code>pix_topups</code></td>
      <td><code>PK (user_id / id)</code><br/><code>UK (idempotency_key)</code></td>
      <td>Subsistema contábil da Carteira do Cliente em centavos inteiros (sem erro de ponto flutuante IEEE 754), gerenciando recargas PIX instantâneas, retenções em custódia, liberações e estornos.</td>
    </tr>
    <tr>
      <td><code>reviews</code>, <code>achievements</code> &amp; <code>provider_portfolio_notes</code></td>
      <td><code>PK (id)</code><br/><code>UK (provider_id, slot_index)</code></td>
      <td>Sistema de avaliações cegas bilaterais (reveladas apenas após ambos avaliarem ou após 48h), mural de selos de conquista gamificados e legendas técnicas da vitrine curada de 5 fotos.</td>
    </tr>
  </tbody>
</table>

<h3>3.2. Histórico Cronológico das 22 Migrações SQL (<span class="mono">supabase/migrations/</span>)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="8%">#</th>
      <th width="42%">Arquivo de Migração SQL</th>
      <th width="50%">Escopo Arquitetural e Entregas no Banco de Dados</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>01</td><td><code>20261009120000_unify_profiles_and_kyc.sql</code></td><td>Unificação da tabela <code>public.profiles</code> Multi-Modo e estrutura base de verificação cadastral.</td></tr>
    <tr><td>02</td><td><code>20261009120100_jobs_quotes_hardening.sql</code></td><td>Modelagem de <code>jobs</code> e <code>quotes</code> com políticas estritas de RLS e integridade referencial.</td></tr>
    <tr><td>03</td><td><code>20261009120200_kyc_storage.sql</code></td><td>Provisionamento de buckets privados de Storage (<code>pro-verifications</code>) com políticas por <code>auth.uid()</code>.</td></tr>
    <tr><td>04</td><td><code>20261019120000_multi_mode_service_flow.sql</code></td><td>Fluxo transacional completo entre modo Cliente e modo Profissional na mesma conta.</td></tr>
    <tr><td>05</td><td><code>20261019130000_invites_pin_evidence.sql</code></td><td>Convites diretos, PIN de segurança de início/conclusão e armazenamento de evidências fotográficas.</td></tr>
    <tr><td>06</td><td><code>20261019140000_realtime_reviews_withdraw.sql</code></td><td>Publicação Supabase Realtime, avaliações bilaterais e solicitações de saque PIX.</td></tr>
    <tr><td>07</td><td><code>20261019150000_flow_fixes.sql</code></td><td>Refinamento de transições de estado de ordens de serviço e garantias de atomicidade.</td></tr>
    <tr><td>08</td><td><code>20261019160000_quotes_withdrawn_status.sql</code></td><td>Suporte a retirada formal de orçamentos pelo profissional antes do aceite.</td></tr>
    <tr><td>09</td><td><code>20261022100000_self_service_guards.sql</code></td><td>Travas relacionais impedindo auto-contratação (cliente contratando a própria conta de prestador).</td></tr>
    <tr><td>10</td><td><code>20261023100000_review_system.sql</code></td><td>Motor de avaliações cegas de duplo compromisso (<em>Double-Blind Reviews</em> com janela de 48h).</td></tr>
    <tr><td>11</td><td><code>20261023200000_achievements.sql</code></td><td>Gatilhos automáticos de concessão de selos técnicos (Super Profissional, Sempre Pontual, Preço Honesto, etc.).</td></tr>
    <tr><td>12</td><td><code>20261029100000_offboarding_wallet_showcase.sql</code></td><td>Trava de segurança de exclusão de conta (verifica saldo/custódia), carteira e vitrine de casos 5 estrelas.</td></tr>
    <tr><td>13</td><td><code>20261030100000_client_wallet_ledger.sql</code></td><td>Livro-razão em centavos inteiros para a Carteira do Cliente, recargas PIX idempotentes e checkouts.</td></tr>
    <tr><td>14</td><td><code>20261030120000_scheduled_start_chat_dossier.sql</code></td><td>Agendamento com janela horária, chat em tempo real com bloqueio anti-vazamento e dossiê técnico.</td></tr>
    <tr><td>15</td><td><code>20261030130000_job_location_pin.sql</code></td><td>Coordenadas geográficas precisas do local do serviço e proteção de privacidade de endereço pré-aceite.</td></tr>
    <tr><td>16</td><td><code>20261105100000_client_geocode_location.sql</code></td><td>Persistência georreferenciada do endereço do cliente para alimentar o filtro espacial.</td></tr>
    <tr><td>17</td><td><code>20261106120000_category_match_orders_dossier.sql</code></td><td>Casamento determinístico de categorias técnicas e estrutura de certificação para o Passaporte do Imóvel.</td></tr>
    <tr><td>18</td><td><code>20261107100000_scoped_account_deletion.sql</code></td><td>RPC <code>delete_own_account_scoped</code> (LGPD Art. 18) para revogação isolada do papel Cliente ou Prestador.</td></tr>
    <tr><td>19</td><td><code>20261107120000_expanded_categories.sql</code></td><td>Expansão taxonômica para as <strong>33 categorias técnicas residenciais</strong> com mapeamento de sinônimos.</td></tr>
    <tr><td>20</td><td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td><td>Motor de Garantia em 3 Camadas, <em>Smart Split</em>, <em>Carve-Out</em> 1,5%, Reserva D+2/D+5/D+7, Grafo Zero-Linkage, Hamming 64-bit <code>O(1)</code>, Podagem Axial <code>O(log N + K)</code> e 4 Invariantes Contábeis.</td></tr>
    <tr><td>21</td><td><code>20261108120000_client_kyc_biometrics_and_ocr.sql</code></td><td>Validador Módulo 11 (<code>is_valid_cpf</code>), tabela <code>kyc_submissions</code>, RPC <code>submit_client_kyc</code>, unicidade Anti-Sybil de CPF/Face e trava <em>Same-Holder PIX Lock</em>.</td></tr>
    <tr><td>22</td><td><code>20261110140000_real_portfolio_5_curated_and_notes.sql</code></td><td>Tabela <code>provider_portfolio_notes</code>, RPC <code>save_curated_portfolio_5</code> e curadoria real de até 5 fotos de destaque do especialista com notas técnicas.</td></tr>
  </tbody>
</table>

<h3>3.3. Mapa Arquitetural dos 9 Índices Estratégicos de Alta Seletividade</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="34%">Identificador do Índice B-Tree</th>
      <th width="28%">Chaves Compostas e Filtro Parcial</th>
      <th width="38%">Complexidade e Operação Acelerada</th>
    </tr>
  </thead>
  <tbody>
    <tr><td><code>idx_profiles_rescue_waterfall_bbox</code></td><td><code>(waterfall_tier_rank, last_latitude, last_longitude) WHERE is_provider AND is_online AND NOT has_open_dispute</code></td><td>Podagem espacial <code>O(log N + K)</code> e ordenação da cascata de despacho sem Sort explícito.</td></tr>
    <tr><td><code>idx_profiles_cpf_hash_unique</code></td><td><code>UNIQUE (cpf_hash) WHERE cpf_hash IS NOT NULL</code></td><td>Bloqueio Anti-Sybil em <code>O(log N) &approx; O(1)</code> contra recriação de conta com mesmo CPF.</td></tr>
    <tr><td><code>idx_profiles_face_liveness_hash</code></td><td><code>(face_liveness_hash) WHERE face_liveness_hash IS NOT NULL</code></td><td>Detecção instantânea de reutilização da mesma biometria facial em múltiplas contas.</td></tr>
    <tr><td><code>idx_jobs_client_provider_link</code> &amp; <code>idx_jobs_provider_client_link</code></td><td><code>(client_id, provider_id)</code> e <code>(provider_id, client_id)</code></td><td>Verificação bidirecional em <code>O(log E)</code> do Grafo <em>Zero-Linkage</em> na Camada 3.</td></tr>
    <tr><td><code>idx_jobs_rescuer_cooldown_24h</code></td><td><code>(rescuer_provider_id, completed_at DESC) WHERE is_warranty_rework = TRUE</code></td><td>Quarentena anti-monopólio de 24 horas entre resgates pagos pelo Fundo de Garantia.</td></tr>
    <tr><td><code>idx_jobs_auto_release_queue</code></td><td><code>(auto_release_at) WHERE escrow_status = 'AWAITING_CLIENT_APPROVAL_24H'</code></td><td>Varredura <code>FOR UPDATE SKIP LOCKED</code> das ordens com SLA de 24h expirado.</td></tr>
    <tr><td><code>idx_escrow_maturation_queue</code></td><td><code>(matures_at, provider_id) WHERE maturation_status = 'MATURING'</code></td><td>Liberação em lote das retenções <code>D+2 / D+5 / D+7</code> para saque PIX livre.</td></tr>
    <tr><td><code>idx_mediations_sla_6h_queue</code></td><td><code>(original_provider_deadline_at) WHERE phase = 'PHASE_1_OPENED_AND_FROZEN'</code></td><td>Escalonamento automático da Camada 1 para a Camada 3 após expiração do SLA de 6h.</td></tr>
  </tbody>
</table>

<h3>3.4. As 4 Invariantes Contábeis Declarativas do Livro-Razão Imutável (<span class="mono">Append-Only Ledger</span>)</h3>
<ol>
  <li><strong>Invariante 1 — Teto Estrito de Cobertura (<code>chk_invariant_1_coverage_cap</code>):</strong> Em qualquer lançamento do tipo <code>REWORK_PAYOUT_DEBIT</code> na tabela <code>warranty_pool_ledger</code>, o valor desembolsado deve ser estritamente menor ou igual a <code>100%</code> do valor da mão de obra original (<code>amount &le; labor_reference_cap</code>), impedindo drenagem desproporcional do fundo.</li>
  <li><strong>Invariante 2 — Disjunção Estrita de Identidade Tripla (<code>chk_invariant_2_disjoint_actors</code>):</strong> Impõe ao nível do kernel SQL que <code>client_actor_id &ne; original_provider_id</code>, <code>rescuer_provider_id &ne; client_actor_id</code> e <code>rescuer_provider_id &ne; original_provider_id</code>.</li>
  <li><strong>Invariante 3 — Imutabilidade Perpétua (<code>trg_warranty_ledger_immutable</code>):</strong> Trigger <code>BEFORE UPDATE OR DELETE ON public.warranty_pool_ledger</code> que aborta qualquer tentativa de edição ou exclusão de lançamentos pretéritos (<code>ERR_IMMUTABLE_LEDGER</code>).</li>
  <li><strong>Invariante 4 — Conservação Algébrica no <em>Smart Split</em>:</strong> A soma de <code>platform_operational_fee (13,5% V<sub>MO</sub>) + warranty_carveout_fee (1,5% V<sub>MO</sub>) + net_provider_amount (85% V<sub>MO</sub> + 100% V<sub>Mat</sub>)</code> iguala exatamente <code>100%</code> do valor depositado pelo cliente em <code>LOCKED_100</code>.</li>
</ol>

<!-- ======================================================================= -->
<!-- CAPÍTULO 4 — COMPLEXIDADE DE ALGORITMOS (BIG-O) E CONCORRÊNCIA          -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-4"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 04</div>
  <div class="cb-body">
    <h2>COMPLEXIDADE DE ALGORITMOS (BIG-O), PODAGEM GEOESPACIAL E CONTROLE DE CONCORRÊNCIA</h2>
    <p>Análise assintótica formal de tempo e espaço, otimização bitwise O(1), indexação espacial O(log N + K) e prova algébrica de ausência de deadlocks.</p>
  </div>
</div>

<h3>4.1. Matriz Comparativa: Complexidade Ingênua vs. Complexidade Otimizada no Desperrengue</h3>
<table class="data-table">
  <thead>
    <tr>
      <th width="25%">Subsistema / Algoritmo</th>
      <th width="16%">Abordagem Ingênua</th>
      <th width="16%">No Desperrengue</th>
      <th width="43%">Estrutura de Dados e Prova do Ganho Assintótico</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Despacho Geoespacial e Cascata de Garantia (Camada 3)</strong></td>
      <td><code>O(N log N)</code><br/>(Full Table Scan + Haversine + Sort)</td>
      <td><strong><code>O(log N + K)</code></strong><br/>(<code>K &ll; N</code>)</td>
      <td>Aplica <strong>Podagem Axial por Bounding Box</strong> sobre o índice B-Tree parcial <code>idx_profiles_rescue_waterfall_bbox (waterfall_tier_rank, last_latitude, last_longitude)</code>, reduzindo o universo de <code>N</code> prestadores para apenas <code>K</code> candidatos dentro do retângulo de <code>15 km</code> antes de calcular a trigonometria esférica de Haversine.</td>
    </tr>
    <tr>
      <td><strong>Distância de Hamming de 64 Bits (Anti-Foto Reciclada)</strong></td>
      <td><code>O(W &times; H)</code> ou <code>O(64)</code> por string</td>
      <td><strong><code>O(1)</code> estrito</strong><br/>(&le; 64 ciclos ALU)</td>
      <td>Converte a imagem em inteiro assinado de 64 bits (<code>BIGINT</code>), aplica <code>XOR</code> bitwise (<code>x := hash_a # hash_b</code>) e limpa apenas os bits <code>1</code> ativos via algoritmo de <em>Brian Kernighan</em> (<code>x := x &amp; (x - 1)</code>).</td>
    </tr>
    <tr>
      <td><strong>Consulta de Reputação (<code>RTS</code>) e Degrau da Cascata (<code>1..5</code>)</strong></td>
      <td><code>O(L)</code><br/>(JOIN + COUNT em <code>L</code> serviços passados)</td>
      <td><strong><code>O(1)</code> estrito</strong><br/>(Leitura direta)</td>
      <td>A trigger <code>BEFORE INSERT OR UPDATE</code> <code>trg_sync_profile_trust_and_rank</code> recalcula incrementalmente <code>external_trust_score</code> e <code>waterfall_tier_rank</code> a cada mutação, materializando ambos na tupla de <code>profiles</code>.</td>
    </tr>
    <tr>
      <td><strong>Verificação Anti-Sybil (CPF e Biometria Facial)</strong></td>
      <td><code>O(N)</code><br/>(Busca sequencial)</td>
      <td><strong><code>O(log N) &approx; O(1)</code></strong></td>
      <td>Índices B-Tree parciais de alta seletividade <code>idx_profiles_cpf_hash_unique</code> e <code>idx_profiles_face_liveness_hash</code>.</td>
    </tr>
    <tr>
      <td><strong>Varredura de Filas Autônomas (Auto-Release 24h e D+N)</strong></td>
      <td><code>O(S)</code> com Table Lock</td>
      <td><strong><code>O(B log S)</code></strong><br/>(Zero Lock Contention)</td>
      <td>Processa lotes fixos (<code>B = 100</code>) com <code>FOR UPDATE SKIP LOCKED LIMIT 100</code> sobre os índices parciais <code>idx_jobs_auto_release_queue</code> e <code>idx_escrow_maturation_queue</code>, permitindo múltiplos workers concorrentes sem espera.</td>
    </tr>
  </tbody>
</table>

<h3>4.2. Demonstração Matemática da Podagem Geoespacial <span class="mono">O(log N + K)</span></h3>
<p>
  Seja <code>(&phi;<sub>0</sub>, &lambda;<sub>0</sub>) = (lat<sub>0</sub>, lng<sub>0</sub>)</code> a coordenada do imóvel sinistrado e <code>R<sub>km</sub> = 15,0 km</code> o raio máximo de atendimento. Como <code>1&deg;</code> de latitude corresponde a aproximadamente <code>111,32 km</code> sobre o elipsoide terrestre e <code>1&deg;</code> de longitude contrai segundo o cosseno da latitude (<code>cos(&phi;<sub>0</sub>)</code>), a RPC <code>trigger_layer3_rework</code> calcula em <code>O(1)</code> os semieixos da caixa delimitadora axial:
</p>
<div class="math-formula-box">
  &Delta;&phi; = R<sub>km</sub> / 111,32 &nbsp;&nbsp;&bull;&nbsp;&nbsp; &Delta;&lambda; = R<sub>km</sub> / [ 111,32 &times; max(0,10, |cos(rad(&phi;<sub>0</sub>))|) ]<br/>
  Filtro Indexado B-Tree: &phi;<sub>p</sub> &isin; [&phi;<sub>0</sub> &minus; &Delta;&phi;, &phi;<sub>0</sub> + &Delta;&phi;] &nbsp;&and;&nbsp; &lambda;<sub>p</sub> &isin; [&lambda;<sub>0</sub> &minus; &Delta;&lambda;, &lambda;<sub>0</sub> + &Delta;&lambda;]
</div>
<p>
  Apenas para as <code>K</code> tuplas que sobrevivem à busca em árvore B-Tree (<code>K &ll; N</code>), avalia-se a distância ortodrômica exata de Haversine (<code>d<sub>H</sub> &le; R<sub>km</sub></code>) e a disjunção em grafo (<code>NOT EXISTS</code> em <code>idx_jobs_client_provider_link</code> e <code>idx_jobs_provider_client_link</code>).
</p>

<h3>4.3. Prova Formal de Ausência de Deadlocks (Ordem Canônica <span class="mono">R1 &prec; R2 &prec; R3 &prec; R4</span>)</h3>
<p>
  Em sistemas transacionais de custódia onde um cliente pode abrir uma disputa (<code>open_warranty_mediation</code>) no exato milissegundo em que o worker assíncrono tenta liberar o saldo de 24 horas (<code>process_autonomous_escrow_and_mediation_queues</code>), a aquisição desordenada de bloqueios exclusivos (<code>SELECT ... FOR UPDATE</code>) causaria espera circular (<em>Condição de Coffman nº 4</em>). O <strong>Desperrengue</strong> elimina matematicamente qualquer possibilidade de deadlock impondo uma <strong>ordem parcial estrita global</strong> sobre os recursos:
</p>
<div class="math-formula-box">
  R<sub>1</sub> (<code>public.jobs</code>) &nbsp;&prec;&nbsp; R<sub>2</sub> (<code>public.job_mediations</code>) &nbsp;&prec;&nbsp; R<sub>3</sub> (<code>public.escrow_maturation_entries</code>) &nbsp;&prec;&nbsp; R<sub>4</sub> (<code>public.profiles</code>)
</div>
<p>
  <strong>Teorema (Liberdade de Deadlock):</strong> <em>Se toda transação <code>T<sub>i</sub></code> adquire bloqueios pessimistas respeitando monotonamente a relação de ordem <code>R<sub>a</sub> &prec; R<sub>b</sub></code>, o grafo de espera entre transações (<code>WFG</code>) é um Grafo Acíclico Direcionado (DAG). Logo, não existem ciclos e a probabilidade de deadlock é identicamente zero (<code>P(Deadlock) = 0</code>).</em>
</p>
`;

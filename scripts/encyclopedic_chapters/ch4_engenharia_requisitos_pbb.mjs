import { svgPbbCanvas } from './svg_ch2_ch3_business.mjs';

// ===========================================================================
// CAPÍTULO 4 — ENGENHARIA DE SOFTWARE E ENGENHARIA DE REQUISITOS COMPLETA
// ===========================================================================
export const ch4Html = String.raw`<section class="chapter-section" id="cap-4">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 4</div>
  <div class="cb-body">
    <h2>ENGENHARIA DE SOFTWARE E ENGENHARIA DE REQUISITOS COMPLETA</h2>
    <p>Formalização Normativa ISO/IEC/IEEE 29148:2018, Matriz de Rastreabilidade Bidirecional de Ponta a Ponta, Especificação Tabular Exaustiva dos Requisitos Funcionais (RF-01 a RF-42), Catálogo das 32 Regras de Negócio (RN) e Máquina de Estados da OS, Qualidade Quantificada ISO/IEC 25010:2023 (RNFs), Product Backlog Building (PBB Canvas), Catálogo BDD em Gherkin e Priorização Científica MoSCoW + WSJF (v2.11.0).</p>
  </div>
</div>

<p>
  A construção de plataformas digitais de missão crítica que custodiam recursos financeiros de terceiros, tratam dados biométricos sensíveis e coordenam interações presenciais no interior de domicílios urbanos exige rigor formal absoluto na transição entre o domínio do problema socioeconômico e o domínio da solução computacional. Neste capítulo, consolida-se a <strong>Engenharia de Requisitos, Regras de Negócio e Qualidade de Software</strong> do ecossistema <strong>Desperrengue (<code>v2.11.0</code>)</strong> segundo os referenciais normativos internacionais <strong>ISO/IEC/IEEE 29148:2018</strong> (<em>Systems and software engineering — Life cycle processes — Requirements engineering</em>) e <strong>ISO/IEC 25010:2023</strong> (<em>Systems and software Quality Requirements and Evaluation — SQuaRE</em>), articulados aos métodos ágeis contemporâneos de decomposição de escopo via <strong>Product Backlog Building (PBB)</strong>, especificação comportamental executável em <strong>Gherkin (BDD)</strong> e priorização multicritério combinando <strong>MoSCoW</strong> e <strong>WSJF (<em>Weighted Shortest Job First</em> — SAFe)</strong>.
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 4.1 — ENGENHARIA DE REQUISITOS SEGUNDO A NORMA ISO/IEC/IEEE 29148 -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-4-1">
  <span class="sh-tag">SEÇÃO 4.1 &bull; NORMA INTERNACIONAL ISO/IEC/IEEE 29148:2018 &bull; MODELO EM V E RASTREABILIDADE</span>
  <h2>4.1. Engenharia de Requisitos Segundo a Norma ISO/IEC/IEEE 29148</h2>
  <p>Formalização algébrica e metodológica das fases de Elicitação, Análise, Especificação e Validação aplicadas ao marketplace bilateral Desperrengue, culminando na Matriz de Rastreabilidade Bidirecional Completa até a versão v2.11.0.</p>
</div>

<h3 id="sec-4-1-1">4.1.1. Fundamentação Formal do Ciclo de Engenharia de Requisitos (ISO/IEC/IEEE 29148:2018)</h3>
<p>
  Sob o prisma da Ciência da Computação e da norma <strong>ISO/IEC/IEEE 29148:2018</strong> (Seções 5.2 e 6.4), um requisito de software não constitui uma intenção abstrata ou descrição informal de interface, mas uma <strong>asserção contratual verificável, monossêmica e livre de ambiguidade</strong> sobre uma propriedade estrutural, funcional ou restritiva que o sistema computacional deve satisfazer para resolver um problema empírico das partes interessadas (<em>stakeholders</em>) em conformidade com o ordenamento regulatório vigente. Formalmente, define-se o processo de Engenharia de Requisitos do Desperrengue como um operador de transformação determinística em quatro estágios acoplados por realimentação contínua:
</p>

<div class="math-formula-box">
  <div class="math-display">
    &Phi;<sub>29148</sub> : (E<sub>emp</sub> &times; L<sub>reg</sub> &times; M<sub>falhas</sub>) &rarr;<sup>Elicitação</sup> N<sub>stake</sub> &rarr;<sup>Análise</sup> S<sub>consist</sub> &rarr;<sup>Especificação</sup> (&Sigma;<sub>RF</sub> &cup; &Sigma;<sub>RNF</sub>) &rarr;<sup>Validação</sup> V<sub>test</sub>
  </div>
</div>

<p>
  Nessa formulação: <span class="math-inline">E<sub>emp</sub></span> representa o conjunto de evidências empíricas coletadas junto aos atores reais do mercado (<span class="math-inline">N = 46</span> participantes auditados, divididos em <span class="math-inline">n<sub>1</sub> = 28</span> moradores demandantes e <span class="math-inline">n<sub>2</sub> = 18</span> prestadores técnicos autônomos/MEIs); <span class="math-inline">L<sub>reg</sub></span> denota o arcabouço jurídico-normativo vinculante (LGPD Lei nº 13.709/2018, CDC Lei nº 8.078/1990, Lei do Inquilinato nº 8.245/1991, LC 116/2003, CPC 47 / IFRS 15, ABNT NBR 5674:2012 e W3C WCAG 2.1); <span class="math-inline">M<sub>falhas</sub></span> codifica as patologias microeconômicas identificadas no setor (Seleção Adversa de Akerlof, Risco Moral, pedágio de venda de <em>leads</em> e bitributação sobre peças); <span class="math-inline">N<sub>stake</sub></span> corresponde às necessidades brutas elicitadas; <span class="math-inline">S<sub>consist</sub></span> representa o espaço de requisitos negociado e isento de contradições lógicas (<span class="math-inline">&not;&exist; r<sub>i</sub>, r<sub>j</sub> &isin; S<sub>consist</sub> : r<sub>i</sub> &and; r<sub>j</sub> &vdash; &perp;</span>); <span class="math-inline">&Sigma;<sub>RF</sub></span> e <span class="math-inline">&Sigma;<sub>RNF</sub></span> compõem os catálogos formais de Requisitos Funcionais e Não Funcionais; e <span class="math-inline">V<sub>test</sub></span> materializa o oráculo executável de verificação automatizada.
</p>

<p>
  Em estrita observância à cláusula 5.2.5 da <strong>ISO/IEC/IEEE 29148:2018</strong>, cada requisito individual <span class="math-inline">r &isin; (&Sigma;<sub>RF</sub> &cup; &Sigma;<sub>RNF</sub>)</span> foi submetido a nove predicados de qualidade sintática e semântica antes de sua incorporação ao código-fonte: <strong>(i) Necessidade</strong> (ausência de <em>gold-plating</em>; toda cláusula responde a dor empírica, mitigação de risco de segurança ou obrigação legal); <strong>(ii) Independência de Implementação Supérflua</strong> (especificação do <em>quê</em> contratual na camada de negócio, isolando o <em>como</em> arquitetural nos módulos correspondentes); <strong>(iii) Não Ambiguidade / Monossemia</strong> (interpretação semântica única); <strong>(iv) Consistência Interna</strong>; <strong>(v) Completude Condicional</strong> (definição explícita de fluxos nominais, exceções e invariantes <em>fail-closed</em>); <strong>(vi) Singularidade Atômica</strong> (ausência de conjunções difusas que agreguem obrigações ortogonais); <strong>(vii) Exequibilidade Técnica e Econômica</strong> (compatibilidade com orçamento operacional de custo marginal de nuvem de <code>R$ 0,034/OS</code> e KYC Tier-0 a <code>R$ 0,00</code>); <strong>(viii) Rastreabilidade Bidirecional</strong>; e <strong>(ix) Verificabilidade Finita</strong> por meio de asserções determinísticas em tempo polinomial.
</p>

<!-- DIAGRAMA VETORIAL SVG: CICLO ISO/IEC/IEEE 29148 E MODELO EM V DO DESPERRENGUE -->
<div class="svg-diagram-box" id="fig-10">
  <svg viewBox="0 0 920 265" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Ciclo Fechado de Engenharia de Requisitos ISO/IEC/IEEE 29148 e Rastreabilidade Bidirecional no Desperrengue v2.11.0">
    <defs>
      <linearGradient id="reqBgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="100%" stop-color="#1E293B"/>
      </linearGradient>
      <linearGradient id="reqCardBlue" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <linearGradient id="reqCardTeal" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#065F46"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <marker id="arrowCyan" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#38BDF8"/>
      </marker>
      <marker id="arrowOrange" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#FF8A2B"/>
      </marker>
    </defs>

    <rect x="0" y="0" width="920" height="265" rx="10" fill="url(#reqBgGrad)" stroke="#334155" stroke-width="1.5"/>
    <text x="460" y="23" text-anchor="middle" fill="#38BDF8" font-size="10.5" font-weight="800" letter-spacing="1">ENGENHARIA DE REQUISITOS ISO/IEC/IEEE 29148:2018 &amp; RASTREABILIDADE BIDIRECIONAL (v2.11.0)</text>

    <!-- Fase 1: Elicitação -->
    <rect x="20" y="40" width="202" height="132" rx="8" fill="url(#reqCardBlue)" stroke="#38BDF8" stroke-width="1.4"/>
    <rect x="20" y="40" width="202" height="24" rx="8" fill="#0284C7"/>
    <text x="121" y="56" text-anchor="middle" fill="#FFFFFF" font-size="9.5" font-weight="800">1. ELICITAÇÃO EMPÍRICA</text>
    <text x="30" y="80" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Pesquisa Bilateral (N = 46):</text>
    <text x="36" y="93" fill="#CBD5E1" font-size="7.7">n1=28 Moradores (96,4% informal;</text>
    <text x="36" y="104" fill="#CBD5E1" font-size="7.7">60,7% receio domiciliar; 92,9% garantia)</text>
    <text x="36" y="117" fill="#CBD5E1" font-size="7.7">n2=18 Prestadores (100% rejeitam</text>
    <text x="36" y="128" fill="#CBD5E1" font-size="7.7">compra de moedas; 55,6% ghost leads)</text>
    <text x="30" y="143" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Etnografia &amp; Regulação:</text>
    <text x="36" y="156" fill="#94A3B8" font-size="7.6">LGPD, CDC Art. 26, NBR 5674, LC 116</text>

    <!-- Seta 1 -> 2 -->
    <line x1="222" y1="106" x2="243" y2="106" stroke="#38BDF8" stroke-width="2" marker-end="url(#arrowCyan)"/>

    <!-- Fase 2: Análise -->
    <rect x="246" y="40" width="202" height="132" rx="8" fill="url(#reqCardBlue)" stroke="#818CF8" stroke-width="1.4"/>
    <rect x="246" y="40" width="202" height="24" rx="8" fill="#4F46E5"/>
    <text x="347" y="56" text-anchor="middle" fill="#FFFFFF" font-size="9.5" font-weight="800">2. ANÁLISE E NEGOCIAÇÃO</text>
    <text x="256" y="80" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Resolução de Conflitos:</text>
    <text x="262" y="93" fill="#CBD5E1" font-size="7.7">Liquidez vs. Segurança &rarr; Smart Escrow</text>
    <text x="262" y="105" fill="#CBD5E1" font-size="7.7">Rota vs. Privacidade &rarr; Geo-Lock 00:00</text>
    <text x="262" y="117" fill="#CBD5E1" font-size="7.7">Peças vs. Take Rate &rarr; Smart Split 0%</text>
    <text x="256" y="132" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Modelagem de Ameaças:</text>
    <text x="262" y="145" fill="#CBD5E1" font-size="7.7">Red Team [SEC-01..09], Duress PIN,</text>
    <text x="262" y="157" fill="#94A3B8" font-size="7.6">Strip EXIF GPS, Triangulação HMAC</text>

    <!-- Seta 2 -> 3 -->
    <line x1="448" y1="106" x2="469" y2="106" stroke="#38BDF8" stroke-width="2" marker-end="url(#arrowCyan)"/>

    <!-- Fase 3: Especificação -->
    <rect x="472" y="40" width="202" height="132" rx="8" fill="url(#reqCardBlue)" stroke="#F59E0B" stroke-width="1.4"/>
    <rect x="472" y="40" width="202" height="24" rx="8" fill="#D97706"/>
    <text x="573" y="56" text-anchor="middle" fill="#FFFFFF" font-size="9.5" font-weight="800">3. ESPECIFICAÇÃO FORMAL</text>
    <text x="482" y="80" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Catálogo Monossêmico:</text>
    <text x="488" y="93" fill="#CBD5E1" font-size="7.7">42 Requisitos Funcionais (RF-01..42)</text>
    <text x="488" y="105" fill="#CBD5E1" font-size="7.7">25 RNFs Quantificados (ISO 25010)</text>
    <text x="482" y="120" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Contratos &amp; Invariantes:</text>
    <text x="488" y="133" fill="#CBD5E1" font-size="7.7">4 Invariantes Contábeis BIGINT (I1..I4)</text>
    <text x="488" y="145" fill="#CBD5E1" font-size="7.7">FSM 4 Fases Geo-Lock &amp; Ordem R1..R4</text>
    <text x="488" y="157" fill="#94A3B8" font-size="7.6">PBB + Gherkin BDD + MoSCoW/WSJF</text>

    <!-- Seta 3 -> 4 -->
    <line x1="674" y1="106" x2="695" y2="106" stroke="#38BDF8" stroke-width="2" marker-end="url(#arrowCyan)"/>

    <!-- Fase 4: Validação -->
    <rect x="698" y="40" width="202" height="132" rx="8" fill="url(#reqCardTeal)" stroke="#10B981" stroke-width="1.4"/>
    <rect x="698" y="40" width="202" height="24" rx="8" fill="#059669"/>
    <text x="799" y="56" text-anchor="middle" fill="#FFFFFF" font-size="9.5" font-weight="800">4. VALIDAÇÃO CONTÍNUA</text>
    <text x="708" y="80" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; Suíte Automatizada v2.11.0:</text>
    <text x="714" y="93" fill="#A7F3D0" font-size="7.7">762 Testes Flutter (816 no HEAD)</text>
    <text x="714" y="105" fill="#A7F3D0" font-size="7.7">64 Testes Python pytest (KYC Engine)</text>
    <text x="714" y="117" fill="#A7F3D0" font-size="7.7">27 Migrações SQL + 12 Geo-Privacy</text>
    <text x="714" y="129" fill="#A7F3D0" font-size="7.7">17 Testes PDF Dossiê + 630 Links MD</text>
    <text x="708" y="144" fill="#E2E8F0" font-size="8.2" font-weight="700">&bull; CI/CD &amp; Distribuição:</text>
    <text x="714" y="157" fill="#94A3B8" font-size="7.6">GitHub Actions + OTA APK Verificado</text>

    <!-- Barra Inferior: Rastreabilidade Bidirecional -->
    <rect x="20" y="190" width="880" height="58" rx="8" fill="#090D16" stroke="#FF8A2B" stroke-width="1.3"/>
    <text x="460" y="208" text-anchor="middle" fill="#FF8A2B" font-size="9.2" font-weight="800">BARRAMENTO DE RASTREABILIDADE BIDIRECIONAL COMPLETA (&tau;_fwd &amp; &tau;_bwd : ZERO REQUISITOS ÓRFÃOS / ZERO GOLD-PLATING)</text>
    <line x1="65" y1="224" x2="855" y2="224" stroke="#FF8A2B" stroke-width="1.6" marker-start="url(#arrowOrange)" marker-end="url(#arrowOrange)"/>
    <text x="150" y="239" text-anchor="middle" fill="#CBD5E1" font-size="7.8">Dor Empírica / Norma Legal</text>
    <text x="355" y="239" text-anchor="middle" fill="#CBD5E1" font-size="7.8">Requisito ID (RF / RNF / PBI)</text>
    <text x="575" y="239" text-anchor="middle" fill="#CBD5E1" font-size="7.8">Código Real (Dart / SQL / Python / Deno)</text>
    <text x="785" y="239" text-anchor="middle" fill="#CBD5E1" font-size="7.8">Teste Automatizado &amp; Asserção</text>
  </svg>
  <div class="svg-caption">Figura 4.1 — Arquitetura metodológica das quatro fases da norma ISO/IEC/IEEE 29148:2018 acoplada ao barramento de rastreabilidade bidirecional verificável do ecossistema Desperrengue (baseline canônico <code>v2.11.0</code>).</div>
</div>

<h3 id="sec-4-1-2">4.1.2. Aplicação Analítica das Quatro Fases Normativas ao Desperrengue</h3>

<h4>Fase I — Elicitação de Requisitos (<em>Stakeholder Requirements Definition &amp; Elicitation</em>)</h4>
<p>
  O processo de elicitação rejeitou suposições intuitivas e fundamentou-se em triangulação metodológica composta por três vetores complementares de investigação empírica e documental:
</p>
<ol>
  <li><strong>Pesquisa Quantitativa e Qualitativa Bilateral (<span class="math-inline">N = 46</span> respondentes auditados):</strong> No polo da demanda residencial (<span class="math-inline">n<sub>1</sub> = 28</span> moradores urbanos), constatou-se que <strong>96,4%</strong> das contratações ocorriam na informalidade analógica (<strong>78,6%</strong> por indicação interpessoal boca a boca [<code>22/28</code>] e <strong>17,9%</strong> via grupos de condomínio e WhatsApp [<code>5/28</code>]), ao passo que apenas <strong>3,6%</strong> utilizavam plataformas tradicionais [<code>1/28</code>]. Evidenciou-se ainda que <strong>60,7%</strong> dos moradores [<code>17/28</code>] nutrem receio agudo de segurança física e patrimonial ao admitir desconhecidos na residência, <strong>92,9%</strong> [<code>26/28</code>] demandam custódia financeira ou garantia formal contra má execução e danos, e a demanda concentra-se em Limpeza e Conservação (<strong>57,1%</strong> [<code>16/28</code>], com recorrência periódica em <strong>42,9%</strong>) e Reparos Técnicos de Manutenção Predial (<strong>39,3%</strong> [<code>11/28</code>]). No polo da oferta técnica (<span class="math-inline">n<sub>2</sub> = 18</span> prestadores autônomos e MEIs), apurou-se que <strong>55,6%</strong> [<code>10/18</code>] dependem da atividade como fonte primária de renda familiar, <strong>100,0%</strong> [<code>18/18</code>] rejeitam modelos especulativos de compra antecipada de moedas ou pacotes de <em>leads</em> sem garantia de contratação, e <strong>55,6%</strong> [<code>10/18</code>] relataram prejuízo financeiro recorrente em deslocamentos improdutivos para "clientes fantasmas" ou pedidos sem lastro orçamentário.</li>
  <li><strong>Etnografia Digital de Comunidades Condominiais e Análise de Falhas de Mercado:</strong> O estudo longitudinal de interações reais entre moradores, síndicos e técnicos revelou quatro assimetrias estruturais que inviabilizam marketplaces de primeira geração: (a) <em>Seleção Adversa de Akerlof</em> decorrente da ausência de verificação documental criptográfica (CNH/CIN VIO e antecedentes); (b) <em>Risco Moral Pós-Pagamento</em> na exigência de "sinal via PIX direto" sem custódia neutra; (c) <em>Compressão Confiscatória de Margem</em> quando plataformas retêm comissão de 15% a 25% inclusive sobre o valor de peças e insumos adquiridos pelo técnico sem margem de lucro; e (d) <em>Exposição Prematura de Endereço Residencial</em> em anúncios abertos de serviço antes da confirmação do vínculo e da chegada da data agendada.</li>
  <li><strong>Elicitação Normativa e Regulatória (<em>Compliance-by-Design</em>):</strong> Extração direta de requisitos mandatórios a partir da <strong>LGPD (Lei nº 13.709/2018)</strong> — minimização geoespacial (Art. 6º, III), portabilidade e eliminação escopada com dossiê auditável (Art. 18, V e VI) e explicabilidade de decisões automatizadas (Art. 20); do <strong>Código de Defesa do Consumidor (Lei nº 8.078/1990)</strong> — orçamento prévio discriminando mão de obra e materiais (Art. 40) e garantia legal irrenunciável de 90 dias para serviços duráveis (Art. 26, II); da <strong>ABNT NBR 5674:2012</strong> e <strong>Lei nº 8.245/1991</strong> — registro documental rastreável da manutenção de edificações; e da <strong>LC 116/2003 / CPC 47 (IFRS 15)</strong> — segregação contábil estrita entre receita própria de intermediação e valores transitórios de terceiros.</li>
</ol>

<h4>Fase II — Análise de Requisitos e Resolução Formal de Conflitos Bilaterais</h4>
<p>
  Em plataformas de dois lados (<em>two-sided marketplaces</em>), os interesses primários de moradores e prestadores exibem tensões dialéticas naturais. Na fase de Análise (ISO/IEC/IEEE 29148, Seção 6.4.3), tais colisões foram modeladas como problemas de desenho de mecanismos (<em>Mechanism Design</em>) compatíveis em incentivos, sintetizados na Tabela 4.1:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Eixo de Tensão</th>
      <th width="24%">Interesse Legítimo do Morador (Cliente)</th>
      <th width="24%">Interesse Legítimo do Prestador (Profissional)</th>
      <th width="36%">Síntese Arquitetural e Algorítmica Adotada no Desperrengue (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Custódia vs. Liquidez</strong></td>
      <td>Não desembolsar valores diretamente ao prestador antes da conclusão satisfatória do reparo (prevenção ao abandono de obra).</td>
      <td>Eliminar inadimplência ("calote") e deslocamento para clientes sem capacidade real de pagamento ("clientes fantasmas").</td>
      <td><strong>Smart Escrow PIX + PIN de 4 Dígitos:</strong> O saldo é bloqueado antecipadamente em conta custódia verificada (provando solvência ao técnico), mas a liquidação só ocorre mediante inserção presencial do PIN criptográfico de 4 dígitos (<code>private.job_forensic_secrets</code>), com maturação escalonada por score (<code>D+0</code>, <code>D+2</code> ou <code>D+5..D+7</code>).</td>
    </tr>
    <tr>
      <td><strong>2. Privacidade Domiciliar vs. Logística</strong></td>
      <td>Ocultar logradouro, número, apartamento e coordenadas GPS exatas até o dia efetivo da visita técnica (LGPD Art. 6º, III).</td>
      <td>Estimar distância, tempo de deslocamento e custo viário antes de precificar o orçamento e organizar a rota diária.</td>
      <td><strong>Temporal &amp; Spatial Geo-Privacy Lock (<code>ADR-0022</code>):</strong> Até as <code>00:00:00</code> (<code>America/Sao_Paulo</code>) do dia agendado, exibe-se apenas um círculo aproximado de <code>500m–800m</code> cujo centro é deslocado em <code>151m–349m</code> por <code>HMAC-SHA256(job_id, secret_key)</code> imune a triangulação. À meia-noite do dia do serviço, o endereço exato destrava exclusivamente para o contratado e re-ofusca após o encerramento.</td>
    </tr>
    <tr>
      <td><strong>3. Transparência de Peças vs. Margem</strong></td>
      <td>Pagar o preço justo de varejo pelos materiais aplicados com comprovação fiscal idônea e garantia de procedência.</td>
      <td>Não sofrer confisco de <code>15%</code> de comissão da plataforma sobre o reembolso de peças compradas em nome do cliente.</td>
      <td><strong>Smart Split Assimétrico:</strong> Segregação nativa em centavos (<code>labor_cents</code> vs. <code>materials_cents</code>), aplicando <code>15,0%</code> apenas sobre a mão de obra (<code>13,5%</code> plataforma + <code>1,5%</code> Fundo Garantidor) e <strong><code>0,0%</code> sobre materiais</strong> comprovados por NF-e/NFC-e validada por Módulo 11, OCR Grounded e auditoria SEFAZ pós-26h com <em>clawback</em> antifraude.</td>
    </tr>
    <tr>
      <td><strong>4. Rigor KYC vs. Fricção de Entrada</strong></td>
      <td>Garantia de que todo profissional admitido no lar passou por validação criptográfica governamental e biometria facial.</td>
      <td>Onboarding ágil em dispositivos intermediários sem reprovações opacas nem repetição cadastral ao usar o app como cliente.</td>
      <td><strong>KYC Zero-Trust em Camadas + Herança Dual-Mode:</strong> Pré-validação instantânea <em>Tier-0</em> em <code>Isolate.run</code> (<code>R$ 0,00</code>, zero latência de rede) seguida de validação VIO/SERPRO ICP-Brasil e <code>CarbonFraudOrchestrator</code> com explicabilidade SHAP Top-3, herdando o selo KYC entre modos Cliente &harr; Profissional.</td>
    </tr>
    <tr>
      <td><strong>5. Coação Presencial vs. Integridade</strong></td>
      <td>Preservar a integridade física da família caso um agente malicioso exija sob ameaça a liberação imediata do pagamento.</td>
      <td>Obter comprovante imediato e irrevogável de conclusão legítima em atendimentos idôneos.</td>
      <td><strong>Cofre Dual Anti-Coação (<em>Silent Duress PIN</em>):</strong> A digitação do PIN de 4 dígitos em ordem reversa (ex.: <code>4819 &rarr; 9184</code>) renderiza tela verde idêntica de sucesso para proteger a vítima, mas aciona silenciosamente o estado <code>FROZEN_UNDER_DURESS</code>, bloqueando o saque PIX e preservando telemetria forense em cofre WORM.</td>
    </tr>
  </tbody>
</table>

<h4>Fase III — Especificação Formal de Contratos, Máquinas de Estados e Invariantes</h4>
<p>
  Para erradicar a polissemia típica da linguagem natural, a especificação técnica do Desperrengue adotou três instrumentos formais: <strong>(a) Padrão Sintático Monossêmico Controlado</strong> (toda sentença de requisito explicita pré-condição de guarda, evento disparador, transformação determinística de estado, tratamento <em>fail-closed</em> de erro e pós-condição observável); <strong>(b) Máquinas de Estados Finitos Determinísticas (DFA)</strong> codificadas diretamente em restrições <code>CHECK</code> e gatilhos PL/pgSQL no PostgreSQL 17 (governando o ciclo de vida da Ordem de Serviço, as 4 fases do <em>Geo-Privacy Lock</em> e o escalonamento das 3 camadas de Garantia); e <strong>(c) Aritmética Monetária Inteira Estrita (<code>BIGINT</code>)</strong>, banindo tipos binários de ponto flutuante (<code>FLOAT</code>/<code>DOUBLE</code> IEEE 754) de todas as camadas contábeis.
</p>

<h4>Fase IV — Validação e Verificação Empírica Contínua (<em>Continuous V&amp;V</em>)</h4>
<p>
  A conformidade entre a especificação normativa e o artefato executável é assegurada por uma malha de verificação automatizada executada a cada commit pelos pipelines <code>.github/workflows/ci.yml</code> e <code>.github/workflows/beta-release.yml</code>. No marco canônico <strong><code>v2.11.0</code></strong>, a validação empírica totaliza: <strong>762 testes automatizados Dart/Flutter</strong> distribuídos em 45 suítes em <code>app/test/</code> (expandidos para <strong>816/816 testes aprovados</strong> em 48 suítes no <code>HEAD 53882c8</code> após endurecimento adicional de recibos fiscais e fotos forenses); <strong>64/64 testes automatizados Python (<code>pytest</code>)</strong> em 3 suítes criptográficas e Red Team em <code>kyc_engine/tests/</code>; <strong>27 migrações SQL idempotentes</strong> na baseline <code>v2.11.0</code> (<strong>30 arquivos <code>.sql</code></strong> no <code>HEAD</code>, acompanhados de 11 suítes de fumaça SQL em <code>supabase/tests/</code>); <strong>12/12 asserções algébricas e Monte Carlo de Geo-Privacidade</strong> (<strong>14/14</strong> no <code>HEAD</code> via <code>scripts/test-geo-privacy-sql.mjs</code>); <strong>17/17 testes vetoriais PDF do Dossiê LGPD</strong> (<code>scripts/test-dossie.mjs</code>); e <strong>630/630 links hipertextuais locais verificados</strong> sem quebras (<code>scripts/check-md-links.mjs</code>).
</p>

<h3 id="sec-4-1-3">4.1.3. Matriz de Rastreabilidade Bidirecional Completa (<span class="mono">v2.11.0</span>)</h3>
<p>
  Segundo a cláusula 6.4.5 da <strong>ISO/IEC/IEEE 29148:2018</strong>, a rastreabilidade bidirecional define duas relações funcionais inversas entre o conjunto de requisitos <span class="math-inline">R = &Sigma;<sub>RF</sub> &cup; &Sigma;<sub>RNF</sub></span>, o conjunto de unidades de código/banco de dados <span class="math-inline">C</span> e o conjunto de casos de teste automatizados <span class="math-inline">T</span>: a <strong>rastreabilidade progressiva (<em>forward traceability</em>)</strong> <span class="math-inline">&tau;<sub>fwd</sub> : R &rarr; &#8472;(C) &times; &#8472;(T)</span>, que comprova que nenhum requisito especificado permaneceu sem implementação ou sem verificação (<span class="math-inline">&forall; r &isin; R, &tau;<sub>fwd</sub>(r) &ne; &empty;</span>), e a <strong>rastreabilidade regressiva (<em>backward traceability</em>)</strong> <span class="math-inline">&tau;<sub>bwd</sub> : T &times; C &rarr; &#8472;(R)</span>, que assegura que nenhum módulo crítico ou teste existe sem justificativa formal no catálogo de requisitos. A Tabela 4.2 consolida a Matriz de Rastreabilidade Bidirecional Completa de ponta a ponta do ecossistema Desperrengue.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="13%">Requisito ID</th>
      <th width="22%">Subsistema / Capacidade Normativa</th>
      <th width="34%">Módulo / Arquivo de Código Real (Dart, SQL, Deno, Python)</th>
      <th width="31%">Arquivo de Teste Automatizado e Asserção Verificável</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-01</code>, <code>RF-02</code>, <code>RF-03</code></td>
      <td>Autenticação PKCE, Perfil Unificado Dual-Mode e Herança KYC Multi-Modo</td>
      <td><code>app/lib/features/auth/presentation/auth_gate.dart</code>, <code>app/lib/features/auth/presentation/role_selection_screen.dart</code>, <code>app/lib/core/models/user_profile.dart</code>, <code>supabase/migrations/20261009120000_unify_profiles_and_kyc.sql</code></td>
      <td><code>app/test/account_screens_test.dart</code>, <code>app/test/user_profile_test.dart</code> — valida alternância atômica Cliente &harr; Profissional e preservação integral de <code>kyc_status</code>.</td>
    </tr>
    <tr>
      <td><code>RF-04</code>, <code>RF-05</code>, <code>RNF-24</code></td>
      <td>Exclusão Granular Escopada (<code>client | provider | all</code>) e Dossiê Portável PDF A4 (LGPD Art. 18)</td>
      <td><code>supabase/functions/excluir-conta/index.ts</code>, <code>supabase/functions/excluir-conta/dossie.ts</code>, <code>delete_account_screen.dart</code>, RPC <code>purge_account</code> e blindagem <code>[SEC-07]</code> em <code>20261113110000_security_hardening_audit.sql</code></td>
      <td><code>scripts/test-dossie.mjs</code> (<strong>17/17 testes PDF</strong>), <code>app/test/offboarding_boot_theme_test.dart</code>, <code>supabase/tests/scoped_deletion_smoke.sql</code> — verifica assinatura <code>%PDF-1.x</code>, paginação A4 e aborto <em>fail-closed</em> se o envio SMTP falhar.</td>
    </tr>
    <tr>
      <td><code>RF-06</code>, <code>RNF-02</code></td>
      <td>Abertura de Chamado Normal/SOS Assistida por Voz (<span class="math-inline">t &lt; 60 s</span>) e Triagem Semântica</td>
      <td><code>app/lib/features/client/presentation/request_wizard.dart</code>, <code>voice_dictation.dart</code>, <code>smart_transcript_formatter.dart</code>, <code>smart_triage_service.dart</code></td>
      <td><code>app/test/smart_transcript_formatter_test.dart</code>, <code>app/test/smart_triage_test.dart</code>, <code>app/test/client_flow_widgets_test.dart</code> — valida pontuação estruturada da transcrição e inferência determinística de urgência/categoria.</td>
    </tr>
    <tr>
      <td><code>RF-07</code>, <code>RNF-22</code></td>
      <td>Captura Multimídia e Sanitização Binária Obrigatória de Metadados EXIF/GPS/XMP/IPTC</td>
      <td><code>app/lib/core/utils/image_metadata_stripper.dart</code>, <code>app/lib/core/services/media_service.dart</code></td>
      <td><code>app/test/eng_image_metadata_stripper_test.dart</code>, <code>app/test/eng_media_upload_sanitize_test.dart</code> — injeta marcadores JPEG <code>APP1/EXIF</code> GPS reais e comprova erradicação de <code>100%</code> dos bytes sensíveis e bloqueio <em>fail-closed</em> em payload corrompido.</td>
    </tr>
    <tr>
      <td><code>RF-08</code>, <code>RNF-04</code></td>
      <td>Taxonomia de 33 Categorias Residenciais, Ícones <em>Duotone</em> e Paridade de Aliases</td>
      <td><code>app/lib/core/models/marketplace_models.dart</code> (<code>kCategories</code>), <code>app/lib/features/client/presentation/category_picker.dart</code>, <code>app/lib/core/ui/duotone_service_icons.dart</code>, <code>20261107120000_expanded_categories.sql</code></td>
      <td><code>app/test/tag_alias_parity_test.dart</code>, <code>app/test/tag_match_test.dart</code>, <code>supabase/tests/expanded_categories_smoke.sql</code> — comprova cardinalidade exata <code>kCategories.length == 33</code>, ausência de <em>overflow</em> em <code>320px @ 1.4x</code> e casamento exato de especialidades.</td>
    </tr>
    <tr>
      <td><code>RF-09</code>, <code>RF-10</code>, <code>RNF-01</code></td>
      <td>Comparação Gratuita de Orçamentos, Cabeçalho de 2 Andares e Agendamento Determinístico</td>
      <td><code>app/lib/features/client/presentation/detalhe_servico_cliente_screen.dart</code>, <code>scheduling_service.dart</code>, <code>supabase/migrations/20261030120000_scheduled_start_chat_dossier.sql</code></td>
      <td><code>app/test/scheduling_test.dart</code>, <code>app/test/ux_client_and_shared_polish_test.dart</code>, <code>supabase/tests/scheduled_start_smoke.sql</code> — valida título integral sem reticências no 2º andar e janelas temporais válidas.</td>
    </tr>
    <tr>
      <td><code>RF-11</code>, <code>RNF-08</code></td>
      <td>Radar Geoespacial ao Vivo (<span class="math-inline">&ge; 80%</span> Viewport Livre, Cascata OSRM + Fallback Geodésico <span class="math-inline">C<sup>&infin;</sup></span>)</td>
      <td><code>app/lib/features/shared/presentation/order_live_map_modal_screen.dart</code>, <code>app/lib/core/utils/resilient_stream.dart</code></td>
      <td><code>app/test/orders_map_ux_and_instant_media_test.dart</code>, <code>app/test/location_pin_test.dart</code>, <code>app/test/precise_geocoder_test.dart</code> — afere área útil livre <span class="math-inline">&ge; 80%</span> e continuidade geométrica da rota de 36 segmentos.</td>
    </tr>
    <tr>
      <td><code>RF-12</code>, <code>RF-13</code>, <code>RF-14</code></td>
      <td>Radar do Prestador <span class="math-inline">O(log N + K)</span>, Orçamento Livre de Moedas e Handshake de Copresença HMAC</td>
      <td><code>app/lib/features/provider/</code>, <code>supabase/migrations/20261113110000_security_hardening_audit.sql</code> (<code>[SEC-05]</code> <code>job_presence_secret</code>)</td>
      <td><code>app/test/provider_ux_polish_test.dart</code>, <code>supabase/tests/category_match_smoke.sql</code>, <code>supabase/tests/security_smoke.sql</code> — verifica emissão gratuita de proposta e rejeição de check-in sem prova HMAC válida.</td>
    </tr>
    <tr>
      <td><code>RF-15</code>, <code>RF-16</code></td>
      <td>Carteira Digital do Prestador, Saque PIX, Vitrine de Reputação e Sincronização de Portfólio</td>
      <td><code>app/lib/features/provider/presentation/wallet_tab.dart</code>, <code>pix_withdraw_screen.dart</code>, <code>supabase/functions/pix-webhook/index.ts</code>, <code>review_widgets.dart</code>, <code>20261023100000_review_system.sql</code></td>
      <td><code>app/test/wallet_test.dart</code>, <code>app/test/eng_portfolio_sync_test.dart</code>, <code>app/test/review_rules_test.dart</code>, <code>supabase/tests/offboarding_showcase_smoke.sql</code> — comprova conciliação de saldo líquido e bloqueio de autoavaliação cruzada.</td>
    </tr>
    <tr>
      <td><code>RF-17</code>, <code>RF-18</code>, <code>RNF-11</code></td>
      <td><em>Smart Split</em> Contábil em Centavos Inteiros (<code>15,0%</code> Mão de Obra vs. <code>0,0%</code> Materiais)</td>
      <td><code>app/lib/core/utils/money.dart</code>, <code>supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
      <td><code>app/test/eng_smart_split_cents_test.dart</code>, <code>app/test/eng_money_and_failure_test.dart</code> — verifica conservação exata <span class="math-inline">L<sub>liq</sub> + R<sub>plat</sub> + C<sub>pool</sub> + M = V<sub>total</sub></span> em centavos <code>int</code> sem resíduo IEEE 754.</td>
    </tr>
    <tr>
      <td><code>RF-19</code>, <code>RF-20</code></td>
      <td>Validação Fiscal NF-e/NFC-e (44 Dígitos Mod 11 + OCR Argon) e Auditoria SEFAZ c/ <em>Clawback</em></td>
      <td><code>app/lib/core/utils/nfe_access_key.dart</code>, <code>material_receipt_capture_screen.dart</code>, <code>supabase/functions/kyc-argon-vision-gate/index.ts</code>, <code>20261113130000_forensic_photo_and_fiscal_hardening.sql</code></td>
      <td><code>app/test/nfe_access_key_test.dart</code>, <code>app/test/material_receipt_capture_screen_test.dart</code>, <code>app/test/provider_real_receipts_services_test.dart</code>, <code>supabase/tests/forensic_photo_and_fiscal.sql</code> — valida dígito verificador Módulo 11, rejeição de chave sintética e estorno automático de <code>15%</code> em nota cancelada.</td>
    </tr>
    <tr>
      <td><code>RF-21</code>, <code>RF-22</code>, <code>RF-23</code>, <code>RF-24</code></td>
      <td><em>Smart Escrow</em> PIX, Livro-Razão Partidas Dobradas, PIN 4 Dígitos e Maturação Escalonada</td>
      <td><code>supabase/migrations/20261030100000_client_wallet_ledger.sql</code>, <code>private.job_forensic_secrets</code> (<code>[SEC-02]</code>), <code>escrow_maturation_entries</code></td>
      <td><code>app/test/completion_redesign_test.dart</code>, <code>app/test/fintech_warranty_security_test.dart</code>, <code>supabase/tests/client_wallet_smoke.sql</code> — comprova soma zero contábil, idempotência de <code>confirm_topup</code> e ocultação de <code>checkout_pin_hash</code> em <code>public.jobs</code>.</td>
    </tr>
    <tr>
      <td><code>RF-25</code>, <code>RF-26</code>, <code>RF-27</code>, <code>RF-28</code></td>
      <td>Garantia Real de 90 Dias em 3 Camadas (CDC Art. 26) e Fundo Mutualista (<code>1,5%</code> <code>warranty_pool_ledger</code>)</td>
      <td><code>supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql</code>, <code>trigger_layer3_rework</code> (<code>[SEC-06]</code>), bucket <code>forensic-evidence</code> (<code>[SEC-09]</code>)</td>
      <td><code>app/test/red_team_warranty_and_kyc_forensics_test.dart</code>, <code>app/test/fintech_warranty_security_test.dart</code> — valida <em>carve-out</em> único de <code>1,5%</code>, transições Camada 1 &rarr; 2 &rarr; 3, invariante <code>running_balance_cents &ge; 0</code> e ordenação livre de <em>deadlocks</em> <span class="math-inline">R<sub>1</sub> &lt; R<sub>2</sub> &lt; R<sub>3</sub> &lt; R<sub>4</sub></span>.</td>
    </tr>
    <tr>
      <td><code>RF-29</code>, <code>RF-30</code></td>
      <td>Histórico Imobiliário e Passaporte Predial PDF Vetorial Compatível com ABNT NBR 5674</td>
      <td><code>app/lib/core/services/desperrengue_official_pdf_service.dart</code> (execução em <code>Isolate.run</code>), <code>historico_servicos_cliente_screen.dart</code></td>
      <td><code>app/test/dossier_test.dart</code>, <code>app/test/client_history_test.dart</code> — valida cabeçalho binário <code>%PDF-1.4</code>, selo criptográfico <code>SHA-256</code> (<code>DSP-PASS-*</code>) e conformidade documental NBR 5674 / Lei 8.245/91.</td>
    </tr>
    <tr>
      <td><code>RF-31</code>, <code>RF-32</code>, <code>RF-33</code>, <code>RF-34</code></td>
      <td>Motor KYC Biométrico Zero-Trust (Tier-0 <code>Isolate.run</code> + Argon Vision + QR VIO ICP-Brasil + SERPRO mTLS + Carbon SHAP + Cofre WORM)</td>
      <td><code>app/lib/core/security/zero_trust_bilateral_security_engine.dart</code>, <code>kyc_engine/app/services/crypto_doc_validator.py</code>, <code>serpro_datavalid.py</code>, <code>fraud_orchestrator.py</code>, <code>kyc_engine/app/core/security.py</code>, <code>kyc-argon-vision-gate</code>, <code>kyc-carbon-webhook</code></td>
      <td><code>kyc_engine/tests/test_vision_ocr_argon.py</code> (<strong>38 testes</strong>), <code>test_carbon_security_and_crypto.py</code> (<strong>16 testes</strong>), <code>test_end_to_end_pipeline_redteam.py</code> (<strong>10 testes</strong>) e <code>app/test/argon_carbon_kyc_and_ux_test.dart</code> — totalizando <strong>64/64 testes Python</strong> + suíte Dart.</td>
    </tr>
    <tr>
      <td><code>RF-35</code>, <code>RNF-23</code></td>
      <td>Cofre Dual Anti-Coação e Protocolo <em>Silent Duress PIN</em> (PIN Invertido de 4 Dígitos)</td>
      <td><code>app/lib/core/security/zero_trust_bilateral_security_engine.dart</code>, <code>supabase/migrations/20261110234000_zero_trust_bilateral_antifraud_v285.sql</code></td>
      <td><code>app/test/red_team_warranty_and_kyc_forensics_test.dart</code>, <code>kyc_engine/tests/test_end_to_end_pipeline_redteam.py</code> — comprova paridade visual de sucesso sob coação e bloqueio silencioso <code>FROZEN_UNDER_DURESS</code> no saque PIX.</td>
    </tr>
    <tr>
      <td><code>RF-36</code>, <code>RF-37</code>, <code>RF-38</code>, <code>RNF-21</code></td>
      <td><em>Temporal &amp; Spatial Geo-Privacy Lock</em> (<code>HMAC-SHA256</code> <code>500m–800m</code> até <code>00:00</code> SP e Re-ofuscação Pós-Conclusão)</td>
      <td><code>supabase/migrations/20261113100000_temporal_geo_privacy_lock.sql</code>, <code>geo_privacy_policy_engine.dart</code>, <code>geo_privacy_widgets.dart</code> (<code>ProtectedAreaMapCard</code>, <code>GeoLockNotice</code>)</td>
      <td><code>scripts/test-geo-privacy-sql.mjs</code> (<strong>12/12 checks v2.11.0</strong>; <strong>14/14 HEAD</strong> com Monte Carlo <code>10.000</code> amostras), <code>app/test/geo_privacy_policy_engine_test.dart</code>, <code>provider_geo_privacy_ui_test.dart</code>, <code>temporal_geo_privacy_lock_widgets_test.dart</code>, <code>supabase/tests/geo_privacy_lock.sql</code>.</td>
    </tr>
    <tr>
      <td><code>RF-39</code>, <code>RF-40</code>, <code>RF-41</code>, <code>RNF-05</code></td>
      <td>Gamificação Bilateral de <strong>112 Medalhas</strong> (90 Profissional + 22 Cliente) com Estado Bloqueado <code>#CBD5E1</code></td>
      <td><code>app/lib/core/models/achievements.dart</code>, <code>client_achievements.dart</code>, <code>app/lib/features/shared/presentation/achievement_widgets.dart</code></td>
      <td><code>app/test/achievements_test.dart</code>, <code>app/test/orders_and_client_achievements_test.dart</code>, <code>app/test/carbon_geo_badges_and_image_cache_test.dart</code>, <code>supabase/tests/achievements_smoke.sql</code> — verifica soma exata <code>90 + 22 = 112</code> e token cromático <code>#CBD5E1</code>.</td>
    </tr>
    <tr>
      <td><code>RF-42</code>, <code>RNF-19</code></td>
      <td>Atualização <em>Over-The-Air</em> (OTA) Segura de APK Android e Purge de ServiceWorker PWA</td>
      <td><code>app/lib/core/services/app_version_and_update_service.dart</code>, <code>.github/workflows/beta-release.yml</code></td>
      <td><code>app/test/update_test.dart</code>, <code>app/test/eng_update_security_test.dart</code> — comprova rejeição de URLs fora da <em>whitelist</em> HTTPS do GitHub e comparação semântica de versões/builds.</td>
    </tr>
    <tr>
      <td><code>RNF-06</code>, <code>RNF-07</code>, <code>RNF-09</code>, <code>RNF-14</code></td>
      <td>Orçamento de Quadro <code>120 FPS</code> (<code>8,33 ms</code>), Cache <code>0 ms</code> (<code>InstantCachedImage</code>), Badge <code>O(1)</code> e Reconexão Realtime</td>
      <td><code>app/lib/core/services/instant_image_cache_engine.dart</code>, <code>app/lib/core/ui/media_widgets.dart</code>, <code>off_thread.dart</code>, <code>resilient_stream.dart</code>, <code>unread_orders_badge_controller.dart</code></td>
      <td><code>app/test/eng_image_cache_privacy_test.dart</code>, <code>app/test/eng_unread_badge_test.dart</code>, <code>app/test/eng_resilience_and_policy_test.dart</code>, <code>app/test/eng_address_privacy_and_offthread_test.dart</code>, <code>app/test/eng_static_guards_test.dart</code>.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 4.2 — ESPECIFICAÇÃO TABULAR EXAUSTIVA DOS REQUISITOS FUNCIONAIS   -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-4-2">
  <span class="sh-tag">SEÇÃO 4.2 &bull; CATÁLOGO CONTRATUAL MONOSSÊMICO (RF-01 A RF-42), 32 REGRAS DE NEGÓCIO E EFSM DE ORDENS</span>
  <h2>4.2. Especificação Tabular Exaustiva dos Requisitos Funcionais (RFs), Regras de Negócio e Máquina de Estados</h2>
  <p>Especificação contratual completa dos 42 Requisitos Funcionais estruturais distribuídos nos dez domínios arquiteturais, acompanhada do catálogo normativo das 32 Regras de Negócio determinísticas e da Matriz Formal de Transição de Estados da Ordem de Serviço (v2.11.0).</p>
</div>

<p>
  A seguir, especificam-se exaustivamente os <strong>42 Requisitos Funcionais (<code>RF-01</code> a <code>RF-42</code>)</strong> que governam o comportamento observável do ecossistema Desperrengue até a versão <code>v2.11.0</code>, particionados individualmente nos <strong>dez domínios funcionais canônicos (Seções 4.2.1 a 4.2.10)</strong>. Na sequência imediata, formalizam-se o <strong>Catálogo Estruturado das 32 Regras de Negócio Normativas (Seção 4.2.11)</strong> e a <strong>Matriz Formal de Transição de Estados da Ordem de Serviço (Seção 4.2.12)</strong>. Cada entrada obedece rigorosamente à gramática normativa da <strong>ISO/IEC/IEEE 29148:2018</strong>, explicitando identificador único, denominação técnica, módulo responsável, descrição formal monossêmica, predicados de pré-condição e pós-condição (incluindo garantias <em>fail-closed</em>), prioridade MoSCoW e implementação física verificável no repositório.
</p>

<h3 id="sec-4-2-1">4.2.1. Domínio 1 — Autenticação PKCE, Onboarding Dual-Mode, Herança KYC e Exclusão Granular LGPD (<span class="mono">RF-01</span> a <span class="mono">RF-05</span>)</h3>

<p>
  O Domínio 1 governa o ciclo de vida identitário unificado em <code>public.profiles</code>, a alternância instantânea entre os papéis de morador e prestador sob credencial criptográfica única, o aproveitamento trans-modo da certificação civil e o protocolo irrevogável de portabilidade documental síncrona prévia ao expurgo escopado de dados pessoais (LGPD Arts. 16 e 18).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-01</code></td>
      <td>Autenticação Criptográfica PKCE e Sessão JWT</td>
      <td>Auth &amp; Identidade</td>
      <td>O sistema deve autenticar usuários mediante fluxo OAuth2/PKCE ou credenciais verificadas no Supabase Auth, emitindo token JWT assinado com renovação silenciosa e inicialização determinística no tema escuro canônico sem flash luminoso no boot.</td>
      <td><strong>Pré:</strong> Credenciais válidas ou token de atualização íntegro.<br/><strong>Pós:</strong> Sessão <code>auth.uid()</code> estabelecida com RLS ativo no PostgreSQL 17.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>auth_gate.dart</code>, <code>login_screen.dart</code>, <code>app_theme.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-02</code></td>
      <td>Onboarding Unificado Dual-Mode</td>
      <td>Perfil Unificado</td>
      <td>O sistema deve manter registro cadastral único na tabela <code>public.profiles</code> capaz de operar nos papéis <code>client</code> e <code>provider</code> sob o mesmo <code>id = auth.uid()</code>, permitindo alternância contextual imediata na interface sem relogin ou duplicação de conta.</td>
      <td><strong>Pré:</strong> Usuário autenticado em <code>public.profiles</code>.<br/><strong>Pós:</strong> Contexto de navegação e tema de acento (<code>#FF8F52</code> Cliente / <code>#74A7FF</code> Profissional) comutados em <span class="math-inline">O(1)</span>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>role_selection_screen.dart</code>, <code>user_profile.dart</code>, <code>20261009120000_unify_profiles_and_kyc.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-03</code></td>
      <td>Herança Automática de KYC Multi-Modo</td>
      <td>Segurança &amp; Identidade</td>
      <td>Quando um usuário já possuir veredito biométrico e documental aprovado (<code>kyc_status = 'verified'</code>) em um dos modos operacionais, o sistema deve herdar automaticamente a certificação civil ao habilitar o modo complementar, exigindo apenas os atributos profissionais específicos (categorias e raio de atendimento).</td>
      <td><strong>Pré:</strong> <code>profiles.kyc_status = 'verified'</code> e CPF validado.<br/><strong>Pós:</strong> Habilitação multi-modo concluída sem nova coleta biométrica redundante.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>apply_verified_carbon_kyc_verdict</code></td>
    </tr>
    <tr>
      <td><code>RF-04</code></td>
      <td>Emissão Síncrona de Dossiê PDF Portável LGPD</td>
      <td>Privacidade &amp; Offboarding</td>
      <td>Previamente à efetivação de qualquer pedido de exclusão de conta ou perfil, o sistema deve compilar todos os dados cadastrais, ordens de serviço, transações, avaliações e medalhas do escopo selecionado em um Dossiê PDF vetorial A4 (<code>pdf-lib</code>) e transmiti-lo ao e-mail verificado do titular (LGPD Art. 18, V).</td>
      <td><strong>Pré:</strong> Solicitação autenticada de exclusão e inexistência de custódia ativa pendente.<br/><strong>Pós:</strong> PDF A4 íntegro entregue via Resend; em falha SMTP, o expurgo é abortado (<em>fail-closed</em>).</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>supabase/functions/excluir-conta/dossie.ts</code>, <code>index.ts</code></td>
    </tr>
    <tr>
      <td><code>RF-05</code></td>
      <td>Exclusão Granular Escopada e Anonimização Fiscal</td>
      <td>Privacidade &amp; Offboarding</td>
      <td>O sistema deve permitir a exclusão seletiva apenas do lado Cliente (<code>scope = 'client'</code>), apenas do lado Profissional (<code>scope = 'provider'</code>) ou da conta integral (<code>scope = 'all'</code>), expurgando dados pessoais identificáveis enquanto preserva lançamentos contábeis/fiscais estritamente anonimizados (LGPD Art. 16, I).</td>
      <td><strong>Pré:</strong> Confirmação de envio do Dossiê PDF (<code>RF-04</code>) e ausência de litígios abertos.<br/><strong>Pós:</strong> Dados do escopo removidos/anonimizados via RPC <code>purge_account</code> conciliada com <code>[SEC-07]</code>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>excluir-conta/index.ts</code>, <code>20261113110000_security_hardening_audit.sql</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-2">4.2.2. Domínio 2 — Modo Cliente: Abertura por Voz/SOS, Strip EXIF, 33 Categorias, Orçamentos, Agendamento e Radar (<span class="mono">RF-06</span> a <span class="mono">RF-11</span>)</h3>

<p>
  O Domínio 2 formaliza a jornada completa do morador demandante, abrangendo triagem assistida por voz para demandas programadas ou emergenciais (<code>SOS</code>), expurgo binário local de metadados <code>EXIF/GPS</code> na origem, classificação sobre as 33 categorias técnicas padronizadas, comparação gratuita de propostas e telemetria cartográfica em tempo real.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-06</code></td>
      <td>Abertura de Chamado Normal/SOS Assistida por Voz</td>
      <td>Modo Cliente</td>
      <td>O sistema deve disponibilizar fluxo guiado para abertura de chamados agendados ou emergenciais (<code>SOS</code>) com transcrição de voz formatada automaticamente (pontuação, capitalização e extração de sintomas prediais) e classificação assistida de categoria e criticidade em tempo total inferior a 60 segundos.</td>
      <td><strong>Pré:</strong> Morador autenticado com endereço residencial cadastrado.<br/><strong>Pós:</strong> Registro criado em <code>public.jobs</code> no estado <code>open</code> com modalidade (<code>scheduled</code> ou <code>sos</code>) definida.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>request_wizard.dart</code>, <code>voice_dictation.dart</code>, <code>smart_transcript_formatter.dart</code>, <code>smart_triage_service.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-07</code></td>
      <td>Upload Multimídia com Strip Binário EXIF/GPS</td>
      <td>Modo Cliente &amp; Mídia</td>
      <td>No anexo de fotografias (JPEG, PNG, WebP) e vídeo curto da patologia predial, o sistema deve executar localmente a remoção binária integral dos segmentos de metadados <code>EXIF</code>, coordenadas <code>GPS</code>, <code>XMP</code> e <code>IPTC</code> antes da transmissão ao armazenamento em nuvem.</td>
      <td><strong>Pré:</strong> Mídia selecionada da câmera ou galeria.<br/><strong>Pós:</strong> Objeto persistido sem bytes de geolocalização embutidos; falha de sanitização bloqueia o envio (<em>fail-closed</em>).</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>image_metadata_stripper.dart</code>, <code>media_service.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-08</code></td>
      <td>Catálogo de 33 Categorias Técnicas e Aliases</td>
      <td>Taxonomia &amp; Busca</td>
      <td>O sistema deve organizar a oferta e a demanda em exatamente 33 categorias técnicas residenciais padronizadas, renderizadas com iconografia vetorial <em>Duotone</em> semântica e motor determinístico de equivalência lexical por sinônimos coloquiais (<em>tag/alias parity</em>).</td>
      <td><strong>Pré:</strong> Inicialização do seletor de serviços ou filtro do radar.<br/><strong>Pós:</strong> Casamento determinístico entre a categoria do chamado e as especialidades homologadas do prestador.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>marketplace_models.dart</code>, <code>category_picker.dart</code>, <code>duotone_service_icons.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-09</code></td>
      <td>Comparação Multicritério de Orçamentos Gratuitos</td>
      <td>Modo Cliente</td>
      <td>O sistema deve apresentar ao morador todos os orçamentos recebidos sem cobrança de taxa de visualização, exibindo em cabeçalho estruturado de 2 andares (emblema/status no 1º andar; título integral no 2º andar) a decomposição mão de obra vs. peças, o RTS, avaliações e medalhas de cada proponente.</td>
      <td><strong>Pré:</strong> Chamado em estado <code>open</code> com <span class="math-inline">&ge; 1</span> proposta registrada em <code>quotes</code>.<br/><strong>Pós:</strong> Seleção consciente da proposta vencedora vinculada ao fluxo de custódia.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>detalhe_servico_cliente_screen.dart</code>, <code>20261009120100_jobs_quotes_hardening.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-10</code></td>
      <td>Agendamento Determinístico com Janela Horária</td>
      <td>Modo Cliente &amp; Agenda</td>
      <td>O sistema deve registrar data e faixa horária da intervenção ancoradas no fuso oficial <code>America/Sao_Paulo</code> (<code>UTC-3</code>), bloqueando agendamentos retroativos, validando disponibilidade de agenda do profissional e regendo janelas contratuais de reagendamento ou cancelamento.</td>
      <td><strong>Pré:</strong> Proposta aceita ou abertura de chamado programado.<br/><strong>Pós:</strong> Atributo <code>scheduled_for</code> gravado e sincronizado com o gatilho temporal do <em>Geo-Privacy Lock</em>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261030120000_scheduled_start_chat_dossier.sql</code>, <code>scheduling_service.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-11</code></td>
      <td>Acompanhamento em Radar Geoespacial ao Vivo</td>
      <td>Modo Cliente &amp; Mapas</td>
      <td>No dia da execução ou em chamados SOS em deslocamento, o sistema deve exibir modal cartográfico com no mínimo <code>80%</code> de viewport livre de mapa, renderizando rota viária via cascata dupla OSRM com fallback geodésico suave (<span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos) e ETA atualizado em tempo real.</td>
      <td><strong>Pré:</strong> Ordem contratada em deslocamento ativo no dia do serviço.<br/><strong>Pós:</strong> Telemetria posicional renderizada a <code>120 FPS</code> sem sobreposição obstrutiva de cartões.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>order_live_map_modal_screen.dart</code>, <code>resilient_stream.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-3">4.2.3. Domínio 3 — Modo Profissional: Radar por Especialidade, Orçamentos Sem Moedas, Agenda HMAC, Carteira PIX e Vitrine RTS (<span class="mono">RF-12</span> a <span class="mono">RF-16</span>)</h3>

<p>
  O Domínio 3 especifica as capacidades operacionais e financeiras do prestador homologado, extinguindo a cobrança especulativa por <em>leads</em> (zero moedas para orçar), impondo prova criptográfica de copresença física no check-in de campo e estruturando a liquidação bancária PIX e a vitrine auditável de reputação.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-12</code></td>
      <td>Radar Profissional Geoespacial por Especialidade</td>
      <td>Modo Profissional</td>
      <td>O sistema deve listar e projetar no radar do profissional exclusivamente os chamados abertos compatíveis com suas categorias técnicas homologadas e contidos em seu raio geográfico de atuação, exibindo apenas o polígono aproximado protegido pelo <em>Geo-Privacy Lock</em>.</td>
      <td><strong>Pré:</strong> Prestador com <code>kyc_status = 'verified'</code> e especialidades ativas.<br/><strong>Pós:</strong> Lista ordenada por proximidade aproximada e urgência em tempo <span class="math-inline">O(log N + K)</span>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>provider_shell.dart</code>, <code>provider_job_screen.dart</code>, <code>get_job_location_for_viewer</code></td>
    </tr>
    <tr>
      <td><code>RF-13</code></td>
      <td>Submissão de Orçamentos sem Compra de Moedas</td>
      <td>Modo Profissional</td>
      <td>O sistema deve permitir ao prestador homologado enviar propostas técnicas discriminadas (mão de obra, estimativa de materiais, prazo e observações técnicas) com custo financeiro zero de emissão, vedando qualquer cobrança por clique, desbloqueio de contato ou pacote de moedas.</td>
      <td><strong>Pré:</strong> Chamado em estado <code>open</code> dentro da especialidade do prestador.<br/><strong>Pós:</strong> Proposta persistida em <code>quotes</code> e notificação instantânea despachada ao morador.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261009120100_jobs_quotes_hardening.sql</code>, <code>provider_ux_polish_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-14</code></td>
      <td>Gestão de Agenda Técnica e Check-in HMAC</td>
      <td>Modo Profissional</td>
      <td>O sistema deve consolidar os compromissos confirmados do prestador com detecção automática de colisão de horários e exigir, no início presencial do reparo, validação criptográfica de copresença derivada por HMAC com segredo privado (<code>job_presence_secret</code> <code>[SEC-05]</code>) e distância geodésica compatível.</td>
      <td><strong>Pré:</strong> Ordem em estado <code>scheduled</code> na data agendada (<code>service_day</code>).<br/><strong>Pós:</strong> Transição auditada para <code>in_progress</code> com carimbo temporal e prova de copresença.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261113110000_security_hardening_audit.sql</code>, <code>20261113120000_disable_checkin_sandbox.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-15</code></td>
      <td>Carteira Digital do Prestador e Saque PIX</td>
      <td>Fintech &amp; Carteira</td>
      <td>O sistema deve prover carteira contábil discriminando saldo em custódia, saldo em maturação (<code>escrow_maturation_entries</code>), reembolso integral de materiais e saldo líquido disponível, processando transferências de saque PIX exclusivamente para chave vinculada ao CPF/CNPJ homologado do titular.</td>
      <td><strong>Pré:</strong> Saldo maduro disponível &gt; 0 e ausência de bloqueio <code>FROZEN_UNDER_DURESS</code> ou mediação.<br/><strong>Pós:</strong> Liquidação PIX registrada atomicamente em partidas dobradas em centavos <code>BIGINT</code>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>wallet_tab.dart</code>, <code>pix_withdraw_screen.dart</code>, <code>escrow_maturation_entries</code>, <code>pix-webhook</code></td>
    </tr>
    <tr>
      <td><code>RF-16</code></td>
      <td>Vitrine Pública de Reputação, Portfólio e RTS</td>
      <td>Reputação &amp; Confiança</td>
      <td>O sistema deve manter vitrine pública auditável do prestador contendo nota média ponderada de avaliações verificadas pós-serviço, galeria sincronizada de fotos antes/depois (sanitizadas de EXIF), medalhas desbloqueadas e o índice composto <em>Relative Trust Score</em> (RTS).</td>
      <td><strong>Pré:</strong> Perfil profissional ativo; avaliações restritas a ordens efetivamente liquidadas.<br/><strong>Pós:</strong> Indicadores públicos recalculados deterministicamente a cada serviço concluído.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>review_widgets.dart</code>, <code>provider_portfolio_widgets.dart</code>, <code>eng_portfolio_sync_test.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-4">4.2.4. Domínio 4 — Smart Split: Segregação Contábil Mão de Obra vs. Peças (0% em Materiais) e Auditoria Fiscal SEFAZ (<span class="mono">RF-17</span> a <span class="mono">RF-20</span>)</h3>

<p>
  O Domínio 4 disciplina o motor tributário e contábil <em>Smart Split</em>, assegurando representação inteira exata em centavos (<code>BIGINT</code>), incidência assimétrica de <em>take rate</em> (<code>0,0%</code> sobre materiais comprovados, eliminando bitributação sobre repasse de insumos segundo CPC 47 / LC 116) e validação criptográfica/SEFAZ contra fraude de notas fiscais canceladas.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-17</code></td>
      <td>Particionamento Orçamentário Bipartido em Centavos</td>
      <td>Smart Split</td>
      <td>O sistema deve representar e armazenar todo orçamento, aditivo e liquidação em duas rubricas inteiras independentes de 64 bits: <code>labor_cents</code> (remuneração exclusiva da força de trabalho técnico) e <code>materials_cents</code> (reembolso estrito de peças e insumos aplicados).</td>
      <td><strong>Pré:</strong> Valores inteiros não negativos com <code>labor_cents &gt; 0</code>.<br/><strong>Pós:</strong> Armazenamento exato em <code>BIGINT</code> sem arredondamento binário de ponto flutuante.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>money.dart</code>, <code>eng_smart_split_cents_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-18</code></td>
      <td>Incidência Assimétrica de Take Rate (0% em Peças)</td>
      <td>Smart Split &amp; Fiscal</td>
      <td>Na liquidação financeira da ordem, o sistema deve aplicar a alíquota total de <code>15,0%</code> exclusivamente sobre <code>labor_cents</code> (destinando <code>13,5%</code> à receita operacional da plataforma e <code>1,5%</code> ao Fundo Garantidor) e aplicar alíquota exata de <strong><code>0,0%</code></strong> sobre <code>materials_cents</code> devidamente comprovados.</td>
      <td><strong>Pré:</strong> Comprovante fiscal de peças aprovado quando <code>materials_cents &gt; 0</code>.<br/><strong>Pós:</strong> Repasse integral de <code>100%</code> dos materiais ao prestador e conformidade tributária CPC 47 / LC 116.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-19</code></td>
      <td>Validação Criptográfica e OCR de NF-e / NFC-e</td>
      <td>Smart Split Antifraude</td>
      <td>Para habilitar isenção sobre <code>materials_cents</code>, o sistema deve exigir captura da NF-e ou NFC-e, validando matematicamente os 44 dígitos da chave de acesso (dígito verificador Módulo 11), o CNPJ emissor (Módulo 11), a janela temporal de emissão e a extração multimodal <em>grounded</em> via <code>kyc-argon-vision-gate</code> (modo <code>smart_split_invoice</code>).</td>
      <td><strong>Pré:</strong> Imagem legível de documento fiscal + chave numérica de 44 dígitos.<br/><strong>Pós:</strong> Nota vinculada com unicidade global (impedindo reuso da mesma chave em múltiplas ordens).</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>nfe_access_key.dart</code>, <code>material_receipt_capture_screen.dart</code>, <code>kyc-argon-vision-gate</code></td>
    </tr>
    <tr>
      <td><code>RF-20</code></td>
      <td>Auditoria Assíncrona SEFAZ (&gt;26h) e Clawback</td>
      <td>Smart Split Antifraude</td>
      <td>Decorridas mais de 26 horas da emissão fiscal (superando o prazo regulamentar de cancelamento extemporâneo de NF-e), um worker interno autenticado deve reconsultar o status da chave na SEFAZ; caso detecte cancelamento ou inidoneidade, deve executar <em>clawback</em> automático de <code>15,0%</code> sobre o montante indevidamente isento e aplicar penalidade severa no RTS.</td>
      <td><strong>Pré:</strong> Nota fiscal aprovada em Fase 1 com janela <span class="math-inline">&Delta;t &gt; 26 h</span>.<br/><strong>Pós:</strong> Confirmação definitiva de idoneidade ou débito compensatório atômico auditado (<code>[SEC-04]</code>).</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261110234000_zero_trust_bilateral_antifraud_v285.sql</code>, <code>20261113130000_forensic_photo_and_fiscal_hardening.sql</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-5">4.2.5. Domínio 5 — Smart Escrow: Custódia Financeira PIX, Máquina de Estados, PIN Criptográfico de 4 Dígitos e Maturação (<span class="mono">RF-21</span> a <span class="mono">RF-24</span>)</h3>

<p>
  O Domínio 5 rege o mecanismo de custódia financeira fiduciária (<em>Smart Escrow</em>), neutralizando simultaneamente o risco de inadimplência do morador e o risco de abandono pós-adiantamento pelo prestador mediante retenção integral em partidas dobradas e liquidação atômica condicionada ao PIN criptográfico presencial de 4 dígitos.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-21</code></td>
      <td>Aprovisionamento de Custódia Financeira PIX</td>
      <td>Smart Escrow</td>
      <td>Ao aceitar um orçamento, o sistema deve exigir o aprovisionamento integral do valor total contratado (<code>labor_cents + materials_cents</code>) via PIX dinâmico ou saldo de carteira (<code>client_wallets</code>), confirmando a liquidação via webhook autenticado (<code>pix-webhook</code> + RPC idempotente <code>confirm_topup</code>).</td>
      <td><strong>Pré:</strong> Proposta selecionada pelo morador e chave de idempotência única.<br/><strong>Pós:</strong> Recursos retidos em conta patrimonial segregada de custódia (partidas dobradas soma zero).</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261030100000_client_wallet_ledger.sql</code>, <code>supabase/functions/pix-webhook/index.ts</code></td>
    </tr>
    <tr>
      <td><code>RF-22</code></td>
      <td>Máquina de Estados Transacional da Custódia</td>
      <td>Smart Escrow</td>
      <td>O sistema deve governar o ciclo de vida contratual por máquina de estados determinística (<code>open &rarr; awaiting_payment &rarr; scheduled &rarr; in_progress &rarr; awaiting_approval &rarr; completed</code>, com ramificações <code>disputed</code> e <code>canceled</code>), impedindo transições fora de ordem, dupla liquidação ou estorno unilateral sem observância das regras de estado.</td>
      <td><strong>Pré:</strong> Ordem registrada com lock pessimista <code>SELECT ... FOR UPDATE</code>.<br/><strong>Pós:</strong> Transição atômica persistida com atualização de <code>updated_at</code> e trilha de auditoria.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261030100000_client_wallet_ledger.sql</code>, <code>20261113125000_jobs_updated_at.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-23</code></td>
      <td>Liberação Atômica Mediante PIN Criptográfico de 4 Dígitos</td>
      <td>Smart Escrow &amp; Forense</td>
      <td>A transição de <code>in_progress</code> ou <code>awaiting_approval</code> para <code>completed</code> e a consequente liberação da custódia devem exigir a apresentação presencial pelo morador e a submissão pelo prestador de um PIN aleatório de 4 dígitos, cujo hash criptográfico reside exclusivamente no esquema isolado <code>private.job_forensic_secrets</code> (<code>[SEC-02]</code>).</td>
      <td><strong>Pré:</strong> Ordem ativa com fotos finais anexadas e tentativa dentro do limite anti-força-bruta.<br/><strong>Pós:</strong> Hash verificado via RPC <code>SECURITY DEFINER</code> sem jamais expor <code>checkout_pin_hash</code> em <code>public.jobs</code>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>private.job_forensic_secrets</code>, <code>completion_redesign_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-24</code></td>
      <td>Maturação Escalonada de Recebíveis por Risco</td>
      <td>Smart Escrow</td>
      <td>Após a validação legítima do PIN de conclusão, o sistema deve agendar a disponibilidade de saque líquido em <code>escrow_maturation_entries</code> segundo a faixa atuarial do prestador: liquidação acelerada (<code>D+0</code> / <code>D+2</code>) para alto score consolidado, intermediária (<code>D+5</code>) para histórico regular e cautelar (<code>D+7</code>) para contas recém-homologadas.</td>
      <td><strong>Pré:</strong> Ordem concluída sem acionamento de <em>Duress PIN</em>.<br/><strong>Pós:</strong> Entradas de maturação criadas com timestamp exato de liberação e <em>carve-out</em> de garantia deduzido.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-6">4.2.6. Domínio 6 — Mediação Forense, Garantia Real de 90 Dias em 3 Camadas e Fundo Garantidor Mutualista de 1,5% (<span class="mono">RF-25</span> a <span class="mono">RF-28</span>)</h3>

<p>
  O Domínio 6 materializa a exequibilidade algorítmica da garantia legal de 90 dias (CDC Art. 26, II) por meio da segregação mutualista automática de <code>1,5%</code> sobre cada mão de obra liquidada no livro-razão <code>warranty_pool_ledger</code> e de uma cascata determinística de três camadas de resolução técnica e pericial.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-25</code></td>
      <td>Carve-Out Mutualista de 1,5% no Warranty Pool Ledger</td>
      <td>Garantia 90 Dias</td>
      <td>Em toda liquidação de ordem de serviço, o sistema deve alocar atomicamente <code>1,5%</code> de <code>labor_cents</code> ao livro-razão imutável <code>warranty_pool_ledger</code>, assegurando unicidade por <code>job_id</code> e manutenção estrita de saldo acumulado não negativo (<code>running_balance_cents &ge; 0</code>).</td>
      <td><strong>Pré:</strong> Conclusão financeira de ordem com <code>labor_cents &gt; 0</code>.<br/><strong>Pós:</strong> Lançamento de crédito autossustentável gravado com chave única idempotente.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>warranty_pool_ledger</code>, <code>fintech_warranty_security_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-26</code></td>
      <td>Garantia de 90 Dias — Camada 1 (Retorno Técnico 48h)</td>
      <td>Mediação &amp; CDC</td>
      <td>Durante os 90 dias corridos subsequentes à conclusão (CDC Art. 26, II), o morador pode acionar chamado de garantia vinculado à ordem original, notificando prioritariamente o prestador executor para diagnóstico e reparo corretivo sem ônus de mão de obra dentro da janela de resposta de até 48 horas.</td>
      <td><strong>Pré:</strong> Ordem em estado <code>completed</code> com <span class="math-inline">&Delta;t &le; 90 dias</span> e evidência fotográfica do vício.<br/><strong>Pós:</strong> Registro aberto em <code>job_mediations</code> (Camada 1) preservando sigilo e rastreabilidade.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>job_mediations</code>, <code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-27</code></td>
      <td>Garantia de 90 Dias — Camada 2 (Mediação Forense)</td>
      <td>Mediação &amp; Forense</td>
      <td>Havendo recusa, omissão acima de 48h ou divergência técnica quanto ao nexo causal na Camada 1, o sistema deve escalonar o caso para a Camada 2, congelando eventuais recebíveis em maturação do prestador e instruindo dossiê pericial comparativo (fotos originais antes/depois vs. evidências do sinistro no bucket imutável <code>forensic-evidence</code> <code>[SEC-09]</code>).</td>
      <td><strong>Pré:</strong> Expiração de SLA ou impasse formal na Camada 1.<br/><strong>Pós:</strong> Recebíveis vinculados bloqueados cautelarmente e dossiê criptográfico selado com hash <code>SHA-256</code>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>forensic-evidence</code>, <code>red_team_warranty_and_kyc_forensics_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-28</code></td>
      <td>Garantia de 90 Dias — Camada 3 (Cobertura Mutualista)</td>
      <td>Fundo Garantidor</td>
      <td>Comprovado o vício técnico na Camada 2 sem reparo pelo executor original, o sistema deve invocar <code>trigger_layer3_rework</code> (<code>[SEC-06]</code>), debitando o <code>warranty_pool_ledger</code> para custear a reexecução integral por segundo profissional de alto RTS ou restituir o morador, aplicando sanção regressiva de reputação/bloqueio ao infrator.</td>
      <td><strong>Pré:</strong> Laudo procedente na Camada 2 e saldo suficiente no <code>warranty_pool_ledger</code>.<br/><strong>Pós:</strong> Ordem de retrabalho gerada com localização copiada de <code>job_geo</code> e débito atômico auditado.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>trigger_layer3_rework</code>, <code>20261113110000_security_hardening_audit.sql</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-7">4.2.7. Domínio 7 — Memória Técnica Imobiliária e Passaporte Predial de Manutenção ABNT NBR 5674 (<span class="mono">RF-29</span> a <span class="mono">RF-30</span>)</h3>

<p>
  O Domínio 7 converte os registros transacionais de manutenção residencial em patrimônio documental perene, consolidando o livro cronológico da unidade habitacional e sintetizando vetorialmente o Passaporte Predial segundo a norma técnica <strong>ABNT NBR 5674:2012</strong>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-29</code></td>
      <td>Registro Estruturado do Histórico Predial do Imóvel</td>
      <td>Passaporte Predial</td>
      <td>O sistema deve catalogar cronologicamente todas as manutenções preventivas e corretivas concluídas em cada unidade imobiliária, vinculando categoria técnica, identificação profissional certificada, notas fiscais de materiais aplicados, registros fotográficos e vigência remanescente de garantia.</td>
      <td><strong>Pré:</strong> Conclusão validada de uma ou mais ordens de serviço no imóvel.<br/><strong>Pós:</strong> Linha do tempo imutável consultável pelo proprietário ou locatário autorizado.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>historico_servicos_cliente_screen.dart</code>, <code>client_history_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-30</code></td>
      <td>Emissão Vetorial do Passaporte Predial ABNT NBR 5674</td>
      <td>Passaporte Predial</td>
      <td>Mediante solicitação do usuário, o sistema deve gerar fora da thread principal (<code>Isolate.run</code>) o <strong>Passaporte Oficial de Manutenção do Imóvel</strong> em formato vetorial nativo <code>%PDF-1.4</code>, estruturado segundo as diretrizes da <strong>ABNT NBR 5674:2012</strong> e da Lei do Inquilinato (Lei nº 8.245/1991), contendo código verificador e hash criptográfico <code>SHA-256</code> (<code>DSP-PASS-*</code>).</td>
      <td><strong>Pré:</strong> Imóvel com histórico registrado pelo titular autenticado.<br/><strong>Pós:</strong> Documento PDF A4 auditável gerado sem queda de quadros na UI (<span class="math-inline">&Delta;t<sub>UI</sub> &le; 8,33 ms</span>).</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>desperrengue_official_pdf_service.dart</code>, <code>dossier_test.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-8">4.2.8. Domínio 8 — Motor KYC Biométrico Zero-Trust (Tier-0, Argon Vision, VIO/SERPRO ICP-Brasil, Carbon SHAP e Cofre Anti-Coação) (<span class="mono">RF-31</span> a <span class="mono">RF-35</span>)</h3>

<p>
  O Domínio 8 especifica o pipeline forense de verificação civil, biométrica e comportamental em múltiplos estágios (<em>Tier-0 On-Device</em> gratuito, extração <em>grounded</em> imune a injeção visual, validação criptográfica governamental ICP-Brasil/SERPRO, explicabilidade SHAP sob LGPD Art. 20 e proteção silenciosa sob coação física).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-31</code></td>
      <td>Portão Biométrico e Documental Tier-0 On-Device</td>
      <td>KYC Zero-Trust</td>
      <td>Antes de qualquer chamada paga de nuvem, o aplicativo deve executar em <code>Isolate.run</code> (custo marginal <code>R$ 0,00</code>) a inspeção de nitidez por variância do operador Laplaciano, enquadramento geométrico, exposição luminosa e validação algorítmica dos dígitos verificadores de CPF/CNH, rejeitando localmente capturas ilegíveis ou inválidas.</td>
      <td><strong>Pré:</strong> Captura de documento oficial e selfie pela câmera segura.<br/><strong>Pós:</strong> Imagens defeituosas barradas localmente com instrução clara sem jargão técnico; imagens íntegras habilitadas ao pipeline.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>off_thread.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-32</code></td>
      <td>Sessão Anti-Swap HMAC e Triagem Argon Vision</td>
      <td>KYC Zero-Trust</td>
      <td>O microsserviço <code>kyc_engine</code> deve inicializar sessão efêmera com token HMAC Anti-Swap (<code>TTL &le; 180s</code>) e submeter o documento ao <code>kyc-argon-vision-gate</code> (Gemini 4 Argon High com <code>temperature = 0.0</code>, coordenadas 2D <code>[0..1000]</code> e encapsulamento anti-<em>prompt-injection</em> <code>&lt;untrusted_visual_ocr_stream&gt;</code>).</td>
      <td><strong>Pré:</strong> Aprovação no Tier-0 + atestação Play Integrity / App Attest.<br/><strong>Pós:</strong> Extração estruturada auditável dos campos civis imune a injeção textual impressa no documento.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>kyc_session_anti_swap_guard.dart</code>, <code>kyc-argon-vision-gate/index.ts</code></td>
    </tr>
    <tr>
      <td><code>RF-33</code></td>
      <td>Validação Criptográfica QR VIO ICP-Brasil e SERPRO mTLS</td>
      <td>KYC Zero-Trust</td>
      <td>O motor Python deve pré-processar o QR Code VIO da CNH/CIN (interpolação bicúbica <code>2x</code> + CLAHE + descompressão segura <code>zlib &le; 64 KiB</code>), verificar a assinatura digital CMS/PKCS#7 (<code>ECDSA P-256</code> / <code>RSA-2048</code>) na cadeia ICP-Brasil/SENATRAN, validar leitura passiva NFC <code>EF.SOD</code> quando presente, impor a tripla igualdade <code>qr_cpf == ocr_cpf == typed_cpf</code> e consultar biometria oficial via <code>SerproDatavalidMtlsClient</code> (TLS 1.3 mTLS A1).</td>
      <td><strong>Pré:</strong> Payload documental proveniente do estágio Argon Vision.<br/><strong>Pós:</strong> Autenticidade governamental provada matematicamente; qualquer divergência de CPF aciona veto imediato.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>crypto_doc_validator.py</code>, <code>serpro_datavalid.py</code>, <code>test_vision_ocr_argon.py</code></td>
    </tr>
    <tr>
      <td><code>RF-34</code></td>
      <td>Prova de Vivacidade, Orquestrador Carbon SHAP e Cofre WORM</td>
      <td>KYC Zero-Trust</td>
      <td>O sistema deve validar prova de vivacidade facial (janela <code>&le; 90s</code>), aplicar 5 <em>Hard Vetos</em> determinísticos pré-LLM, consolidar o veredito de risco no <code>CarbonFraudOrchestrator</code> gerando os Top-3 fatores de explicabilidade SHAP (LGPD Art. 20), cifrar os artefatos em cofre WORM <code>KWV2</code> (<code>HKDF-SHA256 + AES-256-GCM</code>) e notificar o banco via <code>kyc-carbon-webhook</code> com <code>timingSafeEqual</code> e janela anti-replay <code>&le; 300s</code>.</td>
      <td><strong>Pré:</strong> Execução completa dos estágios VIO/SERPRO e liveness.<br/><strong>Pós:</strong> Veredito persistido via <code>apply_verified_carbon_kyc_verdict</code> com explicabilidade auditável e sigilo criptográfico.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>kyc_engine/app/core/security.py</code>, <code>kyc-carbon-webhook/index.ts</code></td>
    </tr>
    <tr>
      <td><code>RF-35</code></td>
      <td>Cofre Dual Anti-Coação (Silent Duress PIN)</td>
      <td>Segurança Pessoal</td>
      <td>Quando o usuário inserir o PIN de conclusão de 4 dígitos em ordem estritamente invertida (ex.: <code>4819 &rarr; 9184</code>, vedando geração de PINs palíndromos no sorteio inicial), o sistema deve retornar na interface resposta visual verde indistinguível da conclusão normal, mas transicionar silenciosamente o registro interno para <code>FROZEN_UNDER_DURESS</code>, bloqueando saques PIX e preservando telemetria criptografada de emergência.</td>
      <td><strong>Pré:</strong> PIN não palíndromo gerado na contratação; submissão do reverso exato no checkout.<br/><strong>Pós:</strong> Integridade física do morador preservada no local e recursos financeiros retidos contra extorsão.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>red_team_warranty_and_kyc_forensics_test.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-9">4.2.9. Domínio 9 — Protocolo Criptográfico Temporal &amp; Spatial Geo-Privacy Lock (500m–800m até 00:00 SP) (<span class="mono">RF-36</span> a <span class="mono">RF-38</span>)</h3>

<p>
  O Domínio 9 formaliza a blindagem de privacidade espacial e temporal do domicílio (<code>ADR-0022</code>), assegurando que logradouro, número, complemento e coordenadas exatas permaneçam fisicamente inacessíveis no banco de dados, nos canais Realtime e na interface do prestador até as <code>00:00:00 America/Sao_Paulo</code> do próprio dia agendado.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-36</code></td>
      <td>Ofuscação Espacial HMAC-SHA256 Imune a Triangulação</td>
      <td>Geo-Privacy Lock</td>
      <td>O banco de dados deve armazenar as coordenadas reais da ordem em tabela restrita (<code>private</code> / <code>job_geo</code>) e calcular, para exibições públicas ou pré-dia do serviço, um centro aproximado determinístico via <code>_geo_fuzzy_center</code> utilizando <code>HMAC-SHA256(job_id, secret_key)</code> com chave CSPRNG de 256 bits em <code>private.geo_privacy_secrets</code>, impondo deslocamento de <code>151m–349m</code> contido em círculo de raio <code>500m–800m</code> (margem interna <code>&ge; 150m</code> da borda).</td>
      <td><strong>Pré:</strong> Ordem criada com coordenadas geocodificadas válidas e segredo ativo em <code>private.geo_privacy_secrets</code>.<br/><strong>Pós:</strong> Mesma consulta repetida retorna idêntico círculo aproximado, neutralizando ataques de interseção/triangulação por múltiplas leituras.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261113100000_temporal_geo_privacy_lock.sql</code>, <code>scripts/test-geo-privacy-sql.mjs</code></td>
    </tr>
    <tr>
      <td><code>RF-37</code></td>
      <td>Trava Temporal à Meia-Noite (00:00 SP) e Re-Ofuscação</td>
      <td>Geo-Privacy Lock</td>
      <td>A RPC canônica <code>get_job_location_for_viewer(uuid)</code> e o predicado <code>_can_see_exact_location(uuid)</code> devem impor máquina server-side ancorada em <code>00:00:00 America/Sao_Paulo</code>: <code>open_quoting</code> (radar aberto), <code>confirmed_future</code> (contratado antes da data agendada ou em <code>awaiting_payment</code> — endereço exato permanece oculto), <code>service_day</code> (destrava às <code>00:00</code> do dia agendado apenas ao prestador contratado, ou após pagamento em SOS) e <code>closed</code> (re-ofusca imediatamente após <code>completed</code>, <code>canceled</code> ou <code>disputed</code>).</td>
      <td><strong>Pré:</strong> Requisição autenticada de visualização de localização de uma ordem.<br/><strong>Pós:</strong> Coordenadas exatas, rua, número e complemento retornam <code>NULL</code> no SQL fora da janela estrita autorizada.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>20261113100000_temporal_geo_privacy_lock.sql</code>, <code>scripts/test-geo-privacy-sql.mjs</code></td>
    </tr>
    <tr>
      <td><code>RF-38</code></td>
      <td>Renderização Cartográfica Protegida Fail-Closed na UI</td>
      <td>Geo-Privacy UI</td>
      <td>A camada de apresentação do prestador deve consumir exclusivamente o modelo <code>ProviderLocationView.fromRpc</code> (operando em modo <em>fail-closed</em> diante de payload ausente ou ambíguo), renderizando <code>ProtectedAreaMapCard</code>, <code>GeoLockNotice</code> e <code>ProtectedAreaMapSheet</code> sem marcador pontual exato nem texto de endereço residencial enquanto vigorar o bloqueio temporal.</td>
      <td><strong>Pré:</strong> Fase de privacidade diferente de <code>service_day</code> ou visualizador não proprietário.<br/><strong>Pós:</strong> Exibição exclusiva do perímetro circular de <code>500m–800m</code> e cronômetro informativo de liberação às <code>00:00</code>.</td>
      <td><span class="badge-must">MUST</span></td>
      <td><code>geo_privacy_policy_engine.dart</code>, <code>geo_privacy_widgets.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-10">4.2.10. Domínio 10 — Sistema de Gamificação Bilateral (112 Medalhas #CBD5E1 vs. Ligas Vibrantes) e Atualização OTA APK (<span class="mono">RF-39</span> a <span class="mono">RF-42</span>)</h3>

<p>
  O Domínio 10 encerra o catálogo funcional especificando o motor de incentivos comportamentais bilaterais de <strong>112 insígnias</strong> (90 profissionais + 22 de moradores), sua semiótica cromática acessível no tema escuro e o subsistema de entrega contínua <em>Over-The-Air</em> (OTA) com validação estrita de origem HTTPS.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="14%">Nome</th>
      <th width="11%">Módulo</th>
      <th width="28%">Descrição Formal Monossêmica</th>
      <th width="19%">Pré-condições / Pós-condições</th>
      <th width="7%">Prior.</th>
      <th width="14%">Implementação Real</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RF-39</code></td>
      <td>Motor de Gamificação do Profissional (90 Medalhas)</td>
      <td>Gamificação</td>
      <td>O sistema deve avaliar e persistir idempotentemente em <code>provider_achievements</code> um catálogo de exatamente <strong>90 medalhas profissionais</strong> estruturadas em <code>9 categorias de excelência &times; 10 patamares progressivos</code> (limiares <code>[1, 10, 25, 50, 100, 500, 1.000, 2.500, 5.000, 10.000]</code>), bonificando assiduidade, qualidade cinco estrelas, velocidade SOS e zero sinistros.</td>
      <td><strong>Pré:</strong> Evento auditado de conclusão de ordem, avaliação ou marco de carreira.<br/><strong>Pós:</strong> Desbloqueio definitivo gravado sem duplicidade e refletido no perfil e no RTS.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>achievements.dart</code>, <code>achievements_test.dart</code>, <code>achievements_smoke.sql</code></td>
    </tr>
    <tr>
      <td><code>RF-40</code></td>
      <td>Motor de Gamificação do Cliente (22 Medalhas) e Streaks</td>
      <td>Gamificação</td>
      <td>O sistema deve computar em passagem única linear <span class="math-inline">O(N)</span> sobre o histórico verificado do morador exatamente <strong>22 medalhas de conquistas do cliente</strong> distribuídas em 6 trilhas temáticas (<code>5 + 1 + 4 + 4 + 3 + 5 = 22</code> níveis), acompanhadas de progressão de níveis de zelo predial e sequências de manutenção preventiva (<em>streaks</em>).</td>
      <td><strong>Pré:</strong> Carregamento ou atualização do histórico de ordens do morador.<br/><strong>Pós:</strong> Totalização exata de <strong>112 medalhas no ecossistema</strong> (<code>90 + 22</code>) com zero latência perceptível.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>client_achievements.dart</code>, <code>orders_and_client_achievements_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-41</code></td>
      <td>Forja Vetorial de Medalhas (#CBD5E1 vs. Ligas Vibrantes)</td>
      <td>Design System &amp; Gamificação</td>
      <td>O componente <code>AchievementMedalForge</code> deve renderizar as 112 insígnias com diferenciação cromática e iconográfica inequívoca: medalhas bloqueadas devem exibir silhueta prateada clara legível <strong><code>#CBD5E1</code></strong> sobre base <code>#1E293B</code> com aro <code>#94A3B8</code> e cadeado sutil <code>#E2E8F0</code>, enquanto medalhas conquistadas devem exibir gradientes metálicos vibrantes (Bronze, Prata, Ouro, Platina e Diamante).</td>
      <td><strong>Pré:</strong> Renderização da galeria de conquistas no modo Cliente ou Profissional.<br/><strong>Pós:</strong> Contraste WCAG AA garantido no tema escuro e reconhecimento imediato de estado em <span class="math-inline">&lt; 200 ms</span> cognitivos.</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td><code>achievement_widgets.dart</code>, <code>carbon_geo_badges_and_image_cache_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RF-42</code></td>
      <td>Atualização Over-The-Air (OTA) Direta e Segura do APK</td>
      <td>Infraestrutura &amp; Release</td>
      <td>O aplicativo deve consultar assincronamente o manifesto da <em>release</em> canônica (<code>beta-latest</code>), comparar número semântico e código de build e oferecer download e instalação direta do pacote Android APK exclusivamente a partir de domínios HTTPS oficiais do GitHub na <em>whitelist</em> de segurança, executando purge coordenado de <em>ServiceWorker</em> na variante Web/PWA.</td>
      <td><strong>Pré:</strong> Nova versão publicada pelo workflow <code>beta-release.yml</code> superior ao build local.<br/><strong>Pós:</strong> Atualização binária distribuída sem latência de fila de loja e imune a redirecionamento malicioso (<em>open redirect / MITM</em>).</td>
      <td><span class="badge-could">COULD</span></td>
      <td><code>app_version_and_update_service.dart</code>, <code>eng_update_security_test.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-11">4.2.11. Catálogo Estruturado das 32 Regras de Negócio Normativas (<span class="mono">RN-AF</span>, <span class="mono">RN-MZ</span>, <span class="mono">RN-KYC</span>, <span class="mono">RN-CAM</span> e <span class="mono">RN-GEO</span>)</h3>

<p>
  Segundo a taxonomia da <strong>ISO/IEC/IEEE 29148:2018 (Seção 5.2.6)</strong>, enquanto os Requisitos Funcionais definem as capacidades observáveis oferecidas aos atores externos, as <strong>Regras de Negócio (RNs)</strong> formalizam restrições algorítmicas invariantes, políticas contábeis, travas antifraude e leis jurídicas ou atuariais que subordinam transversalmente múltiplos fluxos de execução. Na arquitetura Desperrengue (<code>v2.11.0</code>), consolidam-se <strong>32 Regras de Negócio determinísticas</strong> agrupadas em cinco famílias ortogonais: <strong>Antifraude Bilateral (<code>RN-AF-01</code> a <code>RN-AF-14</code>)</strong>, <strong>Solvência Atuarial de Marco Zero (<code>RN-MZ-01</code> a <code>RN-MZ-05</code>)</strong>, <strong>Forense Documental e Biométrica ICP-Brasil (<code>RN-KYC-01</code> a <code>RN-KYC-06</code>)</strong>, <strong>Cascata de Garantia e Custódia em 3 Camadas (<code>RN-CAM-01</code> a <code>RN-CAM-03</code>)</strong> e <strong>Blindagem Criptográfica Geoespacial (<code>RN-GEO-01</code> a <code>RN-GEO-04</code>)</strong>.
</p>

<h4>A. Família Antifraude Bilateral Determinística (<span class="mono">RN-AF-01</span> a <span class="mono">RN-AF-14</span> — Neutralização dos 6 Vetores de Ataque)</h4>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">Código</th>
      <th width="16%">Vetor Mitigado</th>
      <th width="39%">Enunciado Normativo e Predicado Determinístico</th>
      <th width="20%">Invariante / Sanção Automática</th>
      <th width="16%">Ancoragem Física</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RN-AF-01</code></td>
      <td>V1 — Conluio Triplo (Cash-Out)</td>
      <td>É terminantemente vedada a conversão de recursos do <code>warranty_pool_ledger</code> em saque pecuniário ou PIX direto à conta do morador; a cobertura mutualista de Camada 3 liquida exclusivamente uma nova Ordem de Serviço corretiva executada por segundo especialista independente.</td>
      <td>Elimina utilidade financeira de conluio cliente-prestador (<span class="math-inline">U<sub>cashout</sub> = 0</span>).</td>
      <td><code>warranty_pool_ledger</code>, <code>trigger_layer3_rework</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-02</code></td>
      <td>V1 — Conluio Triplo (Escolha Dirigida)</td>
      <td>No acionamento da Camada 3, nem o morador nem o executor original podem indicar ou filtrar o profissional substituto; a seleção ocorre por sorteio pseudoaleatório auditável no servidor via <code>hashtextextended(job_id::text, seed)</code> restrito ao estrato elegível de alto RTS.</td>
      <td>Impede direcionamento de retrabalho para cúmplice previamente combinado.</td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-03</code></td>
      <td>V1 — Conluio em Grafo (<em>Zero-Linkage</em>)</td>
      <td>A query de despacho de Camada 3 poda obrigatoriamente qualquer candidato que compartilhe <code>device_fingerprint_hash</code>, <code>cpf_hash</code>, <code>face_liveness_hash</code>, chave PIX ou histórico prévio de atendimento (<code>public.jobs</code>) com o morador reclamante ou com o prestador infrator.</td>
      <td>Disjunção estrita em grafo social, biométrico e de hardware na alocação pericial.</td>
      <td><code>trigger_layer3_rework</code>, <code>20261113110000_security_hardening_audit.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-04</code></td>
      <td>V1 — Assimetria Moral Pós-Saque</td>
      <td>Toda cobertura de retrabalho obedece à política <em>Clawback First</em>: confisca-se prioritariamente o saldo retido em maturação do infrator (<code>CLAWED_BACK</code>); se já sacado, debita-se o pool mutualista inscrevendo o montante integral em passivo executável (<code>clawback_debt_balance</code>).</td>
      <td>Penalidade imediata de <code>-50 pontos</code> no RTS e retenção compensatória futura.</td>
      <td><code>escrow_maturation_entries</code>, <code>clawback_debt_balance</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-05</code></td>
      <td>V2 — Sequestro de Escrow / Falso Comparecimento</td>
      <td>O início e o encerramento técnico em campo exigem geolocalização real validada em raio <span class="math-inline">&le; 150 m</span> do imóvel combinada ao <em>handshake</em> criptográfico de copresença HMAC derivado de <code>job_presence_secret</code> (<code>[SEC-05]</code>) e registro probatório de estado antes/depois.</td>
      <td>Rejeição atômica de check-in remoto ou desacompanhado de prova criptográfica.</td>
      <td><code>verify_bilateral_copresence_handshake</code>, <code>20261113120000_disable_checkin_sandbox.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-06</code></td>
      <td>V2 — Repúdio Pós-Serviço Concluído</td>
      <td>A validação presencial do PIN aleatório de 4 dígitos (comparado por hash em <code>private.job_forensic_secrets</code> <code>[SEC-02]</code>) constitui recibo jurídico irrevogável de aceitação da entrega imediata, transferindo o saldo de custódia para a fila de maturação sem possibilidade de estorno unilateral imotivado.</td>
      <td>Proteção integral da força de trabalho executada contra retenção abusiva pelo contratante.</td>
      <td><code>complete_job_and_schedule_escrow</code>, <code>20261113110000_security_hardening_audit.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-07</code></td>
      <td>V2 — Inércia ou Omissão do Contratante</td>
      <td>Submetido o termo fotográfico de conclusão (<code>awaiting_approval</code>), inicia-se janela de 24 horas (<code>auto_release_at</code>); inexistindo abertura formal de mediação com evidência óptica do defeito nesse interregno, o worker autônomo (<code>FOR UPDATE SKIP LOCKED</code>) liquida a custódia em favor do prestador.</td>
      <td>Elimina bloqueio indefinido de capital de giro por esquecimento ou má-fé passiva.</td>
      <td><code>process_autonomous_escrow_and_mediation_queues</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-08</code></td>
      <td>V3 — Upload de Fotos de Terceiros / Internet</td>
      <td>Nos fluxos periciais de check-in, check-out, notas fiscais e abertura de sinistro de garantia, a camada de captura impõe acionamento exclusivo do sensor óptico físico nativo (<code>ImageSource.camera</code>), vedando seleção de arquivos pré-existentes da galeria nos ritos forenses.</td>
      <td>Garante contemporaneidade física entre o evento predial e o fotograma capturado.</td>
      <td><code>forensic_photo_service.dart</code>, <code>material_receipt_capture_screen.dart</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-09</code></td>
      <td>V3 — Spoofing de Coordenadas (<em>Fake GPS</em>)</td>
      <td>O coletor de telemetria inspeciona o sinalizador de simulação posicional do sistema operacional (<code>Position.isMocked</code> / provedores sintéticos) e confronta velocidade cinemática plausível entre amostras consecutivas, vetando transições forenses sob telemetria forjada.</td>
      <td>Bloqueio transacional imediato e registro de anomalia de integridade de sensor.</td>
      <td><code>forensic_photo_service.dart</code>, <code>zero_trust_bilateral_security_engine.dart</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-10</code></td>
      <td>V3 — Reciclagem de Evidência Fotográfica</td>
      <td>Cada imagem forense gera assinatura perceptual de gradiente luminoso de 64 bits (<em>Difference Hash — dHash</em>); a RPC <code>register_forensic_photo</code> computa <code>hamming_distance_64</code> em <span class="math-inline">O(1)</span> via instrução <code>bit_count(h1 # h2)</code> e rejeita capturas com distância <span class="math-inline">&lt; 5 bits</span> frente ao acervo prévio.</td>
      <td>Exceção determinística <code>ERR_RECYCLED_CHECKOUT_PHOTO</code> impedindo reuso de fotos.</td>
      <td><code>perceptual_hash_guard.dart</code>, <code>20261113130000_forensic_photo_and_fiscal_hardening.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-11</code></td>
      <td>V4 — Arbitragem de Taxa / Evasão <em>Smart Split</em></td>
      <td>A alíquota de <code>0,0%</code> sobre <code>materials_cents</code> exige chave NF-e/NFC-e de 44 dígitos aprovada em Módulo 11 (<code>validate_nfe_access_key_mod11</code>), CNPJ válido, unicidade global da nota e revalidação assíncrona na SEFAZ após 26h (<code>audit_sefaz_phase2_cancellation_and_clawback</code>).</td>
      <td>Cancelamento extemporâneo da NF-e dispara <em>clawback</em> de <code>15,0%</code> + sanção no RTS.</td>
      <td><code>nfe_access_key.dart</code>, <code>20261110234000_zero_trust_bilateral_antifraud_v285.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-12</code></td>
      <td>V4 — Superfaturamento de Sinistro</td>
      <td>O desembolso máximo suportado pelo <code>warranty_pool_ledger</code> na Camada 3 é estritamente limitado a <code>100%</code> do valor de mão de obra da ordem originária (<code>rework_cents &le; original_labor_cents</code>), sendo protegido pela constraint relacional <code>chk_invariant_1_coverage_cap</code>.</td>
      <td>Impede drenagem desproporcional do fundo mutualista por aditivos artificiais.</td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-13</code></td>
      <td>V5 — Ataque Coordenado de Liquidez (<em>Cold-Start</em>)</td>
      <td>Prestadores recém-ingressos cumprem retenção cautelar máxima (<code>D+7</code>), ficam sujeitos ao disjuntor individual de disputa aberta (<code>has_open_dispute = TRUE</code> suspende novos saques) e sofrem quarentena obrigatória de 24h entre atendimentos de resgate de Camada 3 (<code>idx_jobs_rescuer_cooldown_24h</code>).</td>
      <td>Amortece picos correlacionados de sinistralidade e impede monopólio de resgates.</td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-AF-14</code></td>
      <td>V6 — Ataque Sybil / Contas Laranja</td>
      <td>Impõe-se unicidade global irreversível sobre <code>cpf_hash</code> (<code>SHA-256</code> com <em>pepper</em> secreto de servidor em <code>idx_profiles_cpf_hash_unique</code>), unicidade de descritor biométrico facial 128-D (<code>idx_profiles_face_liveness_hash</code>) e trava bancária de mesma titularidade no saque (<code>pix_key_cpf_matched = TRUE</code>).</td>
      <td>Inviabiliza recriação de conta por infrator banido ou escoamento para terceiros.</td>
      <td><code>20261108120000_client_kyc_biometrics_and_ocr.sql</code>, <code>pix_withdraw_screen.dart</code></td>
    </tr>
  </tbody>
</table>

<h4>B. Família de Solvência Atuarial e Governança de Marco Zero (<span class="mono">RN-MZ-01</span> a <span class="mono">RN-MZ-05</span>)</h4>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">Código</th>
      <th width="18%">Pilar Atuarial</th>
      <th width="41%">Regra Matemática e Operacional</th>
      <th width="16%">Efeito Sistêmico</th>
      <th width="16%">Ancoragem Física</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RN-MZ-01</code></td>
      <td>Reserva Rotativa Escalonada (<em>Rolling Reserve</em>)</td>
      <td>A janela temporal de maturação pós-conclusão em <code>escrow_maturation_entries</code> decresce inversamente à maturidade comprovada do prestador: <code>D+7</code> para <code>TRAINEE</code> (<span class="math-inline">RTS &lt; 50</span>), <code>D+5</code> para <code>STANDARD</code> (<span class="math-inline">50 &le; RTS &lt; 80</span>) e <code>D+2</code> / <code>D+0</code> para <code>VERIFIED_ANCHOR</code> (<span class="math-inline">RTS &ge; 80</span> sem litígios).</td>
      <td>Financia cobertura de sinistros precoces com o próprio capital retido do causador.</td>
      <td><code>settle_escrow_with_carveout_and_maturation</code></td>
    </tr>
    <tr>
      <td><code>RN-MZ-02</code></td>
      <td>Índice Composto <em>Relative Trust Score</em> (RTS)</td>
      <td>Calculado deterministicamente em <span class="math-inline">O(1)</span> no intervalo fechado <span class="math-inline">[0, 100]</span>: <code>+30 pontos</code> por KYC Biométrico e Documental aprovado, <code>+20 pontos</code> por CNPJ/MEI ativo há <span class="math-inline">&ge; 6 meses</span>, <code>+20 pontos</code> por certificação técnica verificada (NR-10/NR-35/CREA/CFT), <code>+6 pontos</code> por serviço concluído sem disputa (teto <code>+30 pontos</code>) e <code>-50 pontos</code> por abandono ou fraude comprovada.</td>
      <td>Substitui leilão pago por mérito técnico verificável na ordenação e liquidação.</td>
      <td><code>calculate_relative_trust_score</code>, <code>trg_sync_profile_trust_and_rank</code></td>
    </tr>
    <tr>
      <td><code>RN-MZ-03</code></td>
      <td>Cascata Hierárquica de 5 Degraus (<em>Waterfall</em>)</td>
      <td>Todo perfil profissional recebe classificação inteira <code>waterfall_tier_rank &isin; {1, 2, 3, 4, 5}</code> mantida por trigger síncrono a cada mutação de RTS, avaliação ou status disciplinar, priorizando acesso a chamados SOS e elegibilidade a resgates de Camada 3 nos degraus superiores (1 e 2).</td>
      <td>Busca indexada em <span class="math-inline">O(log N)</span> sem recálculo em tempo de leitura do radar.</td>
      <td><code>trg_sync_profile_trust_and_rank</code>, <code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-MZ-04</code></td>
      <td>Reserva Semente e Disjuntor Atômico</td>
      <td>Na fase inicial da rede (<span class="math-inline">N &lt; 67</span> ordens liquidadas, abaixo do ponto de equilíbrio atuarial <span class="math-inline">1 / 0,015 = 66,67</span>), o livro-razão <code>warranty_pool_ledger</code> opera lastreado por aporte patrimonial segregado (<code>COLD_START_SEED_RESERVE</code>) aliado ao bloqueio instantâneo de saques sob disputa aberta (<code>has_open_dispute = TRUE</code>).</td>
      <td>Garante solvência líquida estrita (<span class="math-inline">running_balance_cents &ge; 0</span>) desde a 1ª ordem.</td>
      <td><code>warranty_pool_ledger</code>, <code>chk_invariant_4_non_negative_pool</code></td>
    </tr>
    <tr>
      <td><code>RN-MZ-05</code></td>
      <td>Profissionais Âncora e Anti-Monopólio</td>
      <td>Especialistas com comprovação prévia de excelência técnica podem receber homologação <code>is_trusted_anchor = TRUE</code> para compor a malha de resgate de Camada 3 desde o lançamento regional, respeitada a trava obrigatória de 24h de intervalo mínimo entre designações consecutivas ao mesmo executor.</td>
      <td>Assegura capacidade elástica de reexecução em garantia sem concentração viciada.</td>
      <td><code>idx_jobs_rescuer_cooldown_24h</code>, <code>trigger_layer3_rework</code></td>
    </tr>
  </tbody>
</table>

<h4>C. Família Forense de KYC Biométrico, OCR Grounded e Cadeia ICP-Brasil (<span class="mono">RN-KYC-01</span> a <span class="mono">RN-KYC-06</span>)</h4>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">Código</th>
      <th width="18%">Estágio do Pipeline</th>
      <th width="41%">Critério Matemático e Criptográfico de Aceitação</th>
      <th width="16%">Modo de Falha (<em>Hard Veto</em>)</th>
      <th width="16%">Ancoragem Física</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RN-KYC-01</code></td>
      <td>Integridade Civil e Tripla Paridade CPF</td>
      <td>O CPF informado deve satisfazer o cálculo oficial dos dois dígitos verificadores Módulo 11 (<code>public.is_valid_cpf</code>, rejeitando sequências repetidas como <code>111.111.111-11</code>), cumprir a igualdade estrita <code>qr_cpf == ocr_cpf == typed_cpf</code> e gerar hash único salgado no banco.</td>
      <td>Veto determinístico pré-LLM por inconsistência cadastral ou duplicidade Sybil.</td>
      <td><code>is_valid_cpf</code>, <code>crypto_doc_validator.py</code></td>
    </tr>
    <tr>
      <td><code>RN-KYC-02</code></td>
      <td>Prova de Vida Ativa e Anti-Replay de Tela</td>
      <td>A captura facial frontal exige luminância <span class="math-inline">YCbCr &isin; [22%, 82%]</span>, razão cromática de emissão de monitor <code>blueMonitorRatio &lt; 0,25</code>, resposta ao desafio fotométrico <code>issue_kyc_screen_flash_challenge</code>, transição fisiológica de piscada (<span class="math-inline">EAR &lt; 0,18 &rarr; &gt; 0,25</span>), rotação cefálica <span class="math-inline">|Yaw| &ge; 18&deg;</span> e frescor <span class="math-inline">&le; 90 s</span>.</td>
      <td>Bloqueia ataques de apresentação por foto impressa, vídeo gravado ou <em>deepfake</em> em tela.</td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>verify_kyc_screen_flash_and_hardware_attestation</code></td>
    </tr>
    <tr>
      <td><code>RN-KYC-03</code></td>
      <td>Scanner ID-1, Nitidez Laplaciana e VIO/SERPRO</td>
      <td>O documento oficial (proporção ISO/IEC 7810 ID-1 <code>1,586 : 1</code>) deve atingir variância do operador Laplaciano <span class="math-inline">&sigma;<sup>2</sup> &ge; 110,0</span> e reflexo especular <span class="math-inline">&le; 8,5%</span> em <code>Isolate.run</code> (custo <code>R$ 0,00</code>), seguindo para verificação da assinatura digital CMS/PKCS#7 (<code>ECDSA P-256</code> / <code>RSA-2048</code>) do QR VIO ICP-Brasil/SENATRAN e consulta mTLS 1.3 no SERPRO Datavalid.</td>
      <td>Descarte local gratuito de fotos borradas; veto criptográfico de CNH/CIN adulterada.</td>
      <td><code>crypto_doc_validator.py</code>, <code>serpro_datavalid.py</code></td>
    </tr>
    <tr>
      <td><code>RN-KYC-04</code></td>
      <td><em>Core ROI Inset</em> 12% e Anti-Duplicidade Frente/Verso</td>
      <td>Para eliminar contaminação de fundo (mesas, dedos ou bordas), aplica-se recorte interno de <code>12%</code> nas quatro margens antes da comparação perceptual; exige-se distância de Hamming sobre <code>dHash</code> de 64 bits <span class="math-inline">&ge; 5 bits</span> combinada à diferença absoluta média (<code>MAD_64x64</code>) entre frente e verso documentais.</td>
      <td>Impede submissão duplicada da mesma face documental nas duas etapas de coleta.</td>
      <td><code>perceptual_hash_guard.dart</code>, <code>zero_trust_bilateral_security_engine.dart</code></td>
    </tr>
    <tr>
      <td><code>RN-KYC-05</code></td>
      <td><em>Face Match</em> 1:1 Multi-Orientação 128-D</td>
      <td>O recorte facial extraído do documento oficial é avaliado nas quatro orientações ortogonais (<span class="math-inline">0&deg;, 90&deg;, 180&deg;, 270&deg;</span>) contra o embedding 128-D da selfie de prova de vida, exigindo similaridade cosseno estrita <span class="math-inline">S<sub>cos</sub> &ge; 78,0%</span> para aprovação biométrica automática.</td>
      <td>Rejeita substituição de titularidade (documento autêntico portado por terceiro).</td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>serpro_datavalid.py</code></td>
    </tr>
    <tr>
      <td><code>RN-KYC-06</code></td>
      <td>Extração Argon Grounded, SHAP LGPD e Cofre WORM</td>
      <td>O estágio <code>kyc-argon-vision-gate</code> opera com <code>temperature = 0.0</code> e confinamento <code>&lt;untrusted_visual_ocr_stream&gt;</code> exigindo compatibilidade nominal <span class="math-inline">&ge; 80%</span>; o veredito final do <code>CarbonFraudOrchestrator</code> emite obrigatoriamente os Top-3 fatores SHAP (LGPD Art. 20), arquiva evidências em envelope WORM <code>KWV2</code> (<code>HKDF-SHA256 + AES-256-GCM</code>) e autentica webhook via <code>timingSafeEqual</code>.</td>
      <td>Neutraliza <em>prompt injection</em> visual e assegura direito legal à revisão explicável.</td>
      <td><code>kyc-argon-vision-gate/index.ts</code>, <code>security.py</code>, <code>kyc-carbon-webhook/index.ts</code></td>
    </tr>
  </tbody>
</table>

<h4>D. Família da Cascata Contratual de Custódia e Garantia (<span class="mono">RN-CAM-01</span> a <span class="mono">RN-CAM-03</span>) e Família Geo-Privacy Lock (<span class="mono">RN-GEO-01</span> a <span class="mono">RN-GEO-04</span>)</h4>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">Código</th>
      <th width="18%">Domínio Regulado</th>
      <th width="41%">Especificação Normativa Monossêmica</th>
      <th width="16%">Garantia Formal</th>
      <th width="16%">Ancoragem Física</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RN-CAM-01</code></td>
      <td>Camada 1 Financeira — Custódia Condicional</td>
      <td>Nenhum atendimento agendado ou emergencial transiciona para execução sem retenção prévia de <code>100%</code> do valor acordado (<code>LOCKED_100</code>); a liquidação exige PIN presencial de 4 dígitos (ou decurso inconteste do SLA de 24h <code>auto_release_at</code>) seguida da retenção escalonada em <code>escrow_maturation_entries</code>.</td>
      <td>Conservação estrita de soma zero entre carteira do cliente, custódia e repasse.</td>
      <td><code>20261030100000_client_wallet_ledger.sql</code>, <code>settle_escrow_with_carveout_and_maturation</code></td>
    </tr>
    <tr>
      <td><code>RN-CAM-02</code></td>
      <td>Camada 2 Técnica — Retorno Prioritário 90 Dias</td>
      <td>Toda ordem concluída instaura vigência legal de garantia de 90 dias corridos (<code>warranty_expires_at</code>, CDC Art. 26, II) lastreada pelo <em>carve-out</em> automático de <code>1,5%</code> de <code>labor_cents</code>; acionado vício oculto ou reincidência, o executor original dispõe de SLA de 6h para aceite e até 48h para reparo sem cobrança adicional de mão de obra.</td>
      <td>Direito de autorreparo assistido antes de sanção reputacional ou perda financeira.</td>
      <td><code>open_warranty_mediation</code>, <code>job_mediations</code></td>
    </tr>
    <tr>
      <td><code>RN-CAM-03</code></td>
      <td>Camada 3 Mutualista — Execução Substitutiva Cega</td>
      <td>Expirado o SLA da Camada 2 ou homologado laudo pericial de falha técnica no bucket WORM <code>forensic-evidence</code>, aciona-se <code>trigger_layer3_rework</code>: confisca-se saldo em maturação do infrator (ou debita-se o <code>warranty_pool_ledger</code> até <code>100%</code> da mão de obra original) e despacha-se segundo especialista desvinculado sem qualquer ônus ao morador.</td>
      <td>Exequibilidade material da garantia independente da solvência individual do infrator.</td>
      <td><code>trigger_layer3_rework</code>, <code>20261113110000_security_hardening_audit.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-GEO-01</code></td>
      <td>Ofuscação Espacial Determinística HMAC-SHA256</td>
      <td>As coordenadas públicas da ordem são derivadas exclusivamente no servidor por <code>_geo_fuzzy_center(lat, lng, job_id)</code> usando <code>HMAC-SHA256</code> com chave secreta CSPRNG de 256 bits isolada em <code>private.geo_privacy_secrets</code> (<code>REVOKE ALL</code>), gerando deslocamento <span class="math-inline">d &isin; [150 m, 350 m]</span> inscrito em círculo <span class="math-inline">R &isin; [500 m, 800 m]</span> com margem mínima de <code>150 m</code> até a borda.</td>
      <td>Variância amostral nula (<span class="math-inline">&sigma;<sup>2</sup> = 0</span>) para o mesmo <code>job_id</code>, derrotando triangulação.</td>
      <td><code>20261113100000_temporal_geo_privacy_lock.sql</code></td>
    </tr>
    <tr>
      <td><code>RN-GEO-02</code></td>
      <td>Trava Temporal à Meia-Noite (<code>00:00:00 SP</code>)</td>
      <td>Mesmo após o aceite do orçamento e o pagamento da custódia, ordens agendadas para datas futuras permanecem na fase <code>confirmed_future</code>: rua, número, complemento, CEP e GPS exato retornam <code>NULL</code> no SQL até exatamente <code>00:00:00</code> no fuso fixo do servidor <code>America/Sao_Paulo</code> do dia agendado (<code>service_day</code>).</td>
      <td>Imunidade absoluta contra manipulação do relógio local do dispositivo móvel.</td>
      <td><code>_job_privacy_phase</code>, <code>get_job_location_for_viewer</code></td>
    </tr>
    <tr>
      <td><code>RN-GEO-03</code></td>
      <td>Re-Ofuscação Permanente Pós-Encerramento (LGPD)</td>
      <td>No exato instante em que a ordem atinge qualquer estado terminal ou litigioso (<code>completed</code>, <code>canceled</code> ou <code>disputed</code>), a função <code>_job_privacy_phase</code> transiciona irrevogavelmente a visão do prestador para <code>closed</code>, revogando o acesso ao endereço residencial exato e preservando apenas bairro/cidade para fins de histórico e portfólio.</td>
      <td>Minimização pós-finalidade conforme LGPD Arts. 6º, III, 15 e 16.</td>
      <td><code>_job_privacy_phase</code>, <code>provider_full_service_history</code></td>
    </tr>
    <tr>
      <td><code>RN-GEO-04</code></td>
      <td>Defesa em Profundidade contra Canais Laterais</td>
      <td>Os triggers <code>_trg_jobs_geo_privacy_before/after</code> anulam <code>latitude/longitude</code> na tabela replicada <code>public.jobs</code> (expondo apenas <code>public_lat/public_lng/fuzzy_radius_m</code> ao Supabase Realtime), a UI consome o DTO <em>fail-closed</em> <code>ProviderLocationView.fromRpc</code> sem links externos de rota durante o bloqueio e o upload remove metadados binários <code>EXIF/GPS</code> na origem.</td>
      <td>Elimina vazamento de endereço por WebSocket, JSON residual ou foto anexada.</td>
      <td><code>geo_privacy_policy_engine.dart</code>, <code>image_metadata_stripper.dart</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-2-12">4.2.12. Matriz Formal de Transição de Estados da Ordem de Serviço (Autômato Finito Estendido Contratual, Financeiro e Geoespacial)</h3>

<p>
  Para erradicar estados órfãos, condições de corrida em pagamentos concorrentes e vazamentos prematuros de localização domiciliar, o ciclo de vida da Ordem de Serviço (<code>public.jobs</code> acoplado ao enumerador tipado <code>JobStatus</code> em <code>marketplace_models.dart</code>) é modelado matematicamente como uma <strong>Máquina de Estados Finitos Estendida Determinística (EFSM — <em>Extended Finite State Machine</em>)</strong> sincronizada em produto cartesiano com o livro-razão de custódia (<em>Smart Escrow</em>) e com o autômato de sigilo geoespacial (<code>_job_privacy_phase</code>):
</p>

<div class="math-formula-box">
  <span class="formula-label">Definição Algébrica do Autômato Produto da Ordem de Serviço (v2.11.0)</span>
  M<sub>OS</sub> = (S<sub>job</sub>, &Sigma;<sub>RPC</sub>, V<sub>ctx</sub>, G, &delta;, s<sub>0</sub>, F<sub>term</sub>)<br/>
  S<sub>job</sub> = { <code>open</code>, <code>awaiting_payment</code>, <code>scheduled</code>, <code>in_progress</code>, <code>awaiting_approval</code>, <code>completed</code>, <code>canceled</code>, <code>disputed</code> }<br/>
  s<sub>0</sub> = <code>open</code>, &nbsp;&nbsp; F<sub>term</sub> = { <code>completed</code>, <code>canceled</code> } &nbsp;&cup;&nbsp; { <code>disputed</code><sub>&rarr; resolvida</sub> }<br/>
  &delta; : S<sub>job</sub> &times; &Sigma;<sub>RPC</sub> &times; Pred(V<sub>ctx</sub>) &rarr; S<sub>job</sub> &times; Estado<sub>Escrow</sub> &times; Fase<sub>GeoPrivacy</sub>
</div>

<p>
  Toda invocação de transição <span class="math-inline">&sigma; &isin; &Sigma;<sub>RPC</sub></span> executa no PostgreSQL 17 sob bloqueio pessimista de linha (<code>SELECT ... FROM public.jobs WHERE id = p_job FOR UPDATE</code>), avaliando atomicamente o predicado de guarda <span class="math-inline">G(V<sub>ctx</sub>)</span> antes de mutar o estado contratual, registrar o lançamento contábil em centavos <code>BIGINT</code> e recalcular a projeção de privacidade para o prestador visualizador. A tabela a seguir especifica integralmente as <strong>15 transições canônicas (<code>T-01</code> a <code>T-15</code>)</strong>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="6%">Trans.</th>
      <th width="12%">Estado Origem (<span class="mono">s<sub>i</sub></span>)</th>
      <th width="17%">Evento / RPC Gatilho (<span class="mono">&sigma;</span>)</th>
      <th width="25%">Predicados Formais de Guarda (<span class="mono">G</span>)</th>
      <th width="12%">Estado Destino (<span class="mono">s<sub>j</sub></span>)</th>
      <th width="15%">Efeito Atômico no <em>Smart Escrow</em></th>
      <th width="13%">Fase <em>Geo-Privacy</em> (Prestador)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>T-01</code></td>
      <td><code>&empty;</code> (Inexistente)</td>
      <td>Criação do Chamado (<code>INSERT public.jobs</code> + <code>set_job_location</code>)</td>
      <td><code>auth.uid() = client_id</code>, categoria pertencente às 33 canônicas, mídia limpa de <code>EXIF/GPS</code> e coordenadas salvas em <code>job_geo</code>.</td>
      <td><code>open</code></td>
      <td><code>UNFUNDED</code> (<code>R$ 0,00</code> retidos; orçamentos gratuitos).</td>
      <td><code>open_quoting</code> (círculo HMAC <code>500m–800m</code>)</td>
    </tr>
    <tr>
      <td><code>T-02</code></td>
      <td><code>open</code></td>
      <td><code>accept_quote(p_quote_id)</code></td>
      <td>Chamador é <code>client_id</code> titular; proposta ativa de prestador com <code>kyc_status = 'verified'</code>; <code>labor_cents &gt; 0</code>.</td>
      <td><code>awaiting_payment</code></td>
      <td><code>PIX_PENDING</code> (gera cobrança PIX BRCode / reserva de carteira).</td>
      <td><code>confirmed_future</code> (endereço exato bloqueado)</td>
    </tr>
    <tr>
      <td><code>T-03</code></td>
      <td><code>awaiting_payment</code></td>
      <td><code>pix-webhook</code> &rarr; <code>confirm_topup</code> / <code>_payments_hold_after</code></td>
      <td>Assinatura HMAC válida do webhook, chave idempotente inédita e <code>paid_cents == labor_cents + materials_cents</code>; data agendada futura (<span class="math-inline">d<sub>SP</sub> &lt; d<sub>sched</sub></span>).</td>
      <td><code>scheduled</code></td>
      <td><code>LOCKED_100</code> (débito na carteira cliente e retenção integral em custódia).</td>
      <td><code>confirmed_future</code> (permanece oculto até <code>00:00 SP</code>)</td>
    </tr>
    <tr>
      <td><code>T-04</code></td>
      <td><code>scheduled</code></td>
      <td>Virada Temporal Server-Side (<code>00:00:00 America/Sao_Paulo</code> + <code>notify_service_day_address_unlocked</code>)</td>
      <td><code>(now() AT TIME ZONE 'America/Sao_Paulo')::date &ge; (scheduled_for AT TIME ZONE 'America/Sao_Paulo')::date</code> e visualizador <code>= provider_id</code>.</td>
      <td><code>scheduled</code> (apto ao campo)</td>
      <td><code>LOCKED_100</code> (custódia inalterada e protegida).</td>
      <td><code>service_day</code> (destrava endereço exato ao vencedor)</td>
    </tr>
    <tr>
      <td><code>T-05</code></td>
      <td><code>open</code> (Modo SOS)</td>
      <td><code>accept_emergency(p_job_id)</code> com custódia SOS provisionada</td>
      <td><code>urgency = 'emergency'</code>, <code>provider_id &ne; client_id</code> (guarda anti-autoatendimento), prestador homologado na especialidade e pagamento confirmado.</td>
      <td><code>scheduled</code> (despacho SOS imediato)</td>
      <td><code>LOCKED_100</code> (custódia emergencial ativa).</td>
      <td><code>service_day</code> (liberação imediata para socorro)</td>
    </tr>
    <tr>
      <td><code>T-06</code></td>
      <td><code>scheduled</code></td>
      <td><code>start_job</code> + <code>verify_bilateral_copresence_handshake</code></td>
      <td>Fase <code>= service_day</code>, GPS real não simulado a <span class="math-inline">&le; 150 m</span> do alvo, token HMAC derivado de <code>job_presence_secret</code> válido e foto inicial forense única.</td>
      <td><code>in_progress</code></td>
      <td><code>LOCKED_100</code> (habilita eventual registro fiscal de insumos).</td>
      <td><code>service_day</code> (endereço ativo em atendimento)</td>
    </tr>
    <tr>
      <td><code>T-07</code></td>
      <td><code>in_progress</code></td>
      <td><code>register_and_verify_material_fiscal_document</code></td>
      <td><code>materials_cents &gt; 0</code>, chave NF-e de 44 dígitos válida em Módulo 11, CNPJ íntegro, OCR Argon compatível e chave fiscal inédita no banco.</td>
      <td><code>in_progress</code> (insumos auditados)</td>
      <td><code>LOCKED_100</code> (marca isenção <code>0,0%</code> sobre <code>materials_cents</code>; agenda auditoria SEFAZ &gt;26h).</td>
      <td><code>service_day</code></td>
    </tr>
    <tr>
      <td><code>T-08</code></td>
      <td><code>in_progress</code></td>
      <td><code>provider_finish_job</code> + <code>register_forensic_photo</code></td>
      <td>Foto final de câmera física com <code>hamming_distance_64 &ge; 5 bits</code> contra todo acervo anterior e relatório técnico preenchido.</td>
      <td><code>awaiting_approval</code></td>
      <td><code>LOCKED_100</code> (inicia cronômetro regressivo de 24h <code>auto_release_at</code>).</td>
      <td><code>service_day</code> (aguardando conferência final)</td>
    </tr>
    <tr>
      <td><code>T-09</code></td>
      <td><code>in_progress</code> ou <code>awaiting_approval</code></td>
      <td><code>complete_job_and_schedule_escrow</code> (PIN Legítimo de 4 Dígitos)</td>
      <td>Hash do PIN igual ao armazenado em <code>private.job_forensic_secrets</code> (não invertido) dentro do limite de tentativas anti-força-bruta.</td>
      <td><code>completed</code></td>
      <td><code>SETTLED_MATURING</code>: <code>100%</code> peças + <code>85,0%</code> mão de obra em maturação (<code>D+0..D+7</code>), <code>13,5%</code> plataforma e <code>1,5%</code> no <code>warranty_pool_ledger</code>.</td>
      <td><code>closed</code> (re-ofuscação permanente LGPD imediata)</td>
    </tr>
    <tr>
      <td><code>T-10</code></td>
      <td><code>in_progress</code> ou <code>awaiting_approval</code></td>
      <td>Submissão do <em>Silent Duress PIN</em> (PIN Invertido Anti-Coação)</td>
      <td>PIN não palíndromo submetido na ordem inversa exata (ex.: <code>4819 &rarr; 9184</code>) sob situação de ameaça presencial ao morador.</td>
      <td><code>completed</code> (aparência externa na UI)</td>
      <td><code>FROZEN_UNDER_DURESS</code> (bloqueia silenciosamente saques PIX e sela telemetria forense).</td>
      <td><code>closed</code> (revoga endereço exato imediatamente)</td>
    </tr>
    <tr>
      <td><code>T-11</code></td>
      <td><code>awaiting_approval</code></td>
      <td><code>process_autonomous_escrow_and_mediation_queues</code> (Decurso SLA 24h)</td>
      <td><code>now() &ge; auto_release_at</code>, <code>has_open_dispute = FALSE</code> e linha capturada atomicamente via <code>FOR UPDATE SKIP LOCKED</code>.</td>
      <td><code>completed</code></td>
      <td><code>SETTLED_MATURING</code> &rarr; <code>RELEASED_LIQUID</code> conforme janela <code>D+k</code> do RTS.</td>
      <td><code>closed</code> (re-ofuscação permanente LGPD)</td>
    </tr>
    <tr>
      <td><code>T-12</code></td>
      <td><code>open</code>, <code>awaiting_payment</code> ou <code>scheduled</code></td>
      <td><code>cancel_job</code> ou <code>cancel_sos_with_displacement_slashing</code></td>
      <td>Solicitação antes de <code>in_progress</code>; se SOS já em deslocamento comprovado do prestador, aplica compensação algorítmica de deslocamento (<em>slashing</em>).</td>
      <td><code>canceled</code></td>
      <td><code>REFUNDED_CLIENT</code> (estorno integral ou deduzido da taxa de deslocamento SOS em partidas dobradas).</td>
      <td><code>closed</code> (endereço exato inacessível)</td>
    </tr>
    <tr>
      <td><code>T-13</code></td>
      <td><code>in_progress</code> ou <code>awaiting_approval</code></td>
      <td><code>create_support_ticket</code> / Contestação Pré-Liquidação</td>
      <td>Divergência material na execução antes da validação do PIN ou dentro da janela de 24h pós-término, instruída com evidência óptica.</td>
      <td><code>disputed</code></td>
      <td><code>FROZEN_DISPUTE</code> (congela custódia integral e aciona disjuntor <code>has_open_dispute = TRUE</code>).</td>
      <td><code>closed</code> (acesso exato restrito a <code>owner_full</code> / auditoria)</td>
    </tr>
    <tr>
      <td><code>T-14</code></td>
      <td><code>completed</code> (Vigência &le; 90 dias)</td>
      <td><code>open_warranty_mediation</code> (Acionamento CDC 90 Dias)</td>
      <td><code>now() &le; warranty_expires_at</code>, anexo de evidência fotográfica forense do vício reincidente; abre Camada 1 (48h) &rarr; Camada 2 pericial.</td>
      <td><code>disputed</code> (em garantia)</td>
      <td><code>FROZEN_DISPUTE</code> sobre saldo em maturação remanescente do executor.</td>
      <td><code>closed</code> (reabertura só em eventual retorno aceito)</td>
    </tr>
    <tr>
      <td><code>T-15</code></td>
      <td><code>disputed</code></td>
      <td><code>admin_resolve_dispute</code> ou <code>trigger_layer3_rework</code></td>
      <td>Laudo pericial selado sobre <code>forensic-evidence</code>: improcedência libera custódia ao prestador; procedência executa <em>Clawback First</em> + débito no <code>warranty_pool_ledger</code> e cria nova OS de Camada 3.</td>
      <td><code>completed</code> ou <code>canceled</code> (com nova OS <code>scheduled</code>)</td>
      <td><code>RELEASED_LIQUID</code> (se improcedente) ou <code>CLAWED_BACK</code> + custeio mutualista até <code>100%</code> de <code>labor_cents</code>.</td>
      <td><code>closed</code> na OS original; ciclo <code>RN-GEO</code> integral na nova OS</td>
    </tr>
  </tbody>
</table>

<div class="callout-box callout-warning">
  <strong>Invariantes de Transições Proibidas e Imutabilidade Pós-Conclusão (<em>Fail-Closed</em> Relacional):</strong>
  <ul class="tight-list">
    <li><strong>Proibição de Salto de Custódia (<em>Anti-Skip Escrow</em>):</strong> Qualquer tentativa de transicionar <code>open &rarr; in_progress</code> ou <code>awaiting_payment &rarr; in_progress</code> sem passar pelo estado financiado <code>scheduled</code> (<code>LOCKED_100</code>) é abortada transacionalmente pelo banco de dados.</li>
    <li><strong>Imutabilidade Pós-Encerramento (<code>[SEC-08]</code>):</strong> Os triggers <code>jobs_enforce_post_completion_immutability</code> e <code>job_evidence_enforce_post_completion_immutability</code> (<code>20261113110000_security_hardening_audit.sql</code>) bloqueiam qualquer mutação retroativa de valores (<code>labor_cents</code>, <code>materials_cents</code>), prestador alocado, coordenadas ou evidências fotográficas após a entrada em <code>completed</code>, admitindo exclusivamente notas complementares aditivas auditadas (<code>set_job_complementary_notes</code>) ou abertura formal de garantia (<code>open_warranty_mediation</code>).</li>
    <li><strong>Idempotência Estrita contra Duplo Pagamento e Duplo Saque:</strong> As chaves únicas sobre <code>idempotency_key</code>, <code>escrow_maturation_entries(job_id)</code> e <code>warranty_pool_ledger(job_id, entry_type)</code> asseguram matematicamente que reentregas de webhooks PIX ou execuções concorrentes de workers produzam efeito líquido idêntico a uma única execução.</li>
  </ul>
</div>

<!-- ======================================================================= -->
<!-- SEÇÃO 4.3 — REQUISITOS NÃO FUNCIONAIS COMPLETOS E QUANTIFICADOS (25010) -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-4-3">
  <span class="sh-tag">SEÇÃO 4.3 &bull; NORMA INTERNACIONAL ISO/IEC 25010:2023 (SQuaRE) &bull; MÉTRICAS MATEMÁTICAS E PROVAS FORMAIS</span>
  <h2>4.3. Requisitos Não Funcionais (RNFs) Completos e Quantificados (ISO/IEC 25010)</h2>
  <p>Especificação algébrica, limites assintóticos, provas formais de invariantes e mecanismos reais de código para as cinco dimensões críticas de qualidade de produto: Usabilidade, Eficiência de Desempenho, Confiabilidade, Suportabilidade e Segurança/Privacidade.</p>
</div>

<p>
  Diferentemente de especificações qualitativas vagas ("sistema rápido", "interface intuitiva" ou "transação segura"), a engenharia de qualidade do Desperrengue adota o modelo internacional <strong>ISO/IEC 25010:2023 (SQuaRE)</strong> para ancorar cada atributo não funcional em <strong>equações matemáticas verificáveis, cotas superiores de latência/complexidade e mecanismos concretos de código auditados</strong>. Subdividem-se a seguir os <strong>25 Requisitos Não Funcionais (<code>RNF-01</code> a <code>RNF-25</code>)</strong> nas cinco macrocategorias normativas exigidas.
</p>

<h3 id="sec-4-3-1">4.3.1. RNFs de Usabilidade e Acessibilidade Cognitiva (<span class="mono">RNF-01</span> a <span class="mono">RNF-05</span>)</h3>
<p>
  A dimensão de Usabilidade (<em>Interaction Capability</em> na revisão ISO/IEC 25010:2023) governa a inteligibilidade perceptual, a eficiência operatória e a acessibilidade universal da interface <em>Quiet Luxury Dark Mode</em> definida em <code>app/lib/core/ui/app_tokens.dart</code> e <code>app_theme.dart</code>:
</p>

<ul>
  <li>
    <strong><code>RNF-01</code> — Contraste Cromático Estrito W3C WCAG 2.1 Níveis AA e AAA:</strong> Para qualquer par cromático de primeiro plano <span class="math-inline">c<sub>fg</sub></span> e plano de fundo <span class="math-inline">c<sub>bg</sub></span>, calcula-se a luminância relativa linearizada no espaço sRGB <span class="math-inline">L = 0,2126 R<sub>lin</sub> + 0,7152 G<sub>lin</sub> + 0,0722 B<sub>lin</sub></span> e impõe-se a razão fotométrica mínima:
    <div class="math-formula-box">
      <div class="math-display">
        C(L<sub>fg</sub>, L<sub>bg</sub>) = (max(L<sub>fg</sub>, L<sub>bg</sub>) + 0,05) / (min(L<sub>fg</sub>, L<sub>bg</sub>) + 0,05) &ge; 4,5 : 1 &nbsp;&nbsp;(AA Geral) &nbsp;&nbsp;&and;&nbsp;&nbsp; C &ge; 7,0 : 1 &nbsp;&nbsp;(AAA Leitura Primária)
      </div>
    </div>
    Na implementação real em <code>app_tokens.dart</code>, o texto primário <code>#EAEFF6</code> (<span class="math-inline">L &approx; 0,855</span>) sobre o fundo canônico <code>#0E1218</code> (<span class="math-inline">L &approx; 0,008</span>) atinge <strong><span class="math-inline">C &approx; 15,6 : 1</span> (AAA)</strong>; sobre os cartões <code>#1A212B</code> (<span class="math-inline">L &approx; 0,015</span>) atinge <strong><span class="math-inline">C &approx; 13,9 : 1</span> (AAA)</strong>; o acento laranja do Modo Cliente <code>#FF8F52</code> e o acento azul do Modo Profissional <code>#74A7FF</code> superam <strong><span class="math-inline">7,8 : 1</span> (AAA)</strong> sobre <code>#0E1218</code>. Adicionalmente, toda a malha de layout respeita <code>ConstrainedBox(maxWidth: 480)</code> e escala tipográfica dinâmica até <code>textScaler = 1.4x</code> em viewports estreitos de <code>320px</code> com zero truncamento (validado para vocábulos extensos como <em>"Impermeabilização"</em> em <code>category_picker.dart</code> e no cabeçalho de 2 andares de <code>detalhe_servico_cliente_screen.dart</code>).
  </li>
  <li>
    <strong><code>RNF-02</code> — Abertura de Chamado Assistida por Voz em <span class="math-inline">t &lt; 60 s</span>:</strong> O tempo total de interação humana desde o acionamento do botão principal até a persistência do chamado aberto obedece à inequação ergonômica auditada:
    <div class="math-formula-box">
      <div class="math-display">
        t<sub>abertura</sub> = t<sub>seleção</sub> (&le; 6 s) + t<sub>ditado_voz</sub> (&le; 32 s) + t<sub>formatação_triagem</sub> (&le; 0,4 s) + t<sub>confirmação</sub> (&le; 12 s) &le; 50,4 s &lt; 60,0 s
      </div>
    </div>
    Esse limite superior é garantido pela combinação de <code>request_wizard.dart</code>, <code>voice_dictation.dart</code>, <code>smart_transcript_formatter.dart</code> (pontuação e normalização sintática instantânea da fala) e <code>smart_triage_service.dart</code> (sugestão automática de categoria e flag de emergência <code>SOS</code>).
  </li>
  <li>
    <strong><code>RNF-03</code> — Zero Jargão Técnico na Interface (Linguagem Cidadã Acessível):</strong> É vedada a exibição ao usuário final de códigos HTTP, exceções SQL, termos criptográficos brutos (<code>HMAC</code>, <code>EXIF</code>, <code>PKCS#7</code>, <code>RLS</code>) ou jargões de engenharia; tanto os tratadores de falha no cliente quanto o prompt normativo de <code>kyc-argon-vision-gate</code> aplicam mapeamento léxico para mensagens orientativas diretas em português claro.
  </li>
  <li>
    <strong><code>RNF-04</code> — Iconografia Semântica Vetorial <em>Duotone</em> Customizada:</strong> As <strong>33 categorias residenciais</strong> (<code>kCategories</code> em <code>marketplace_models.dart</code>) são representadas por glifos vetoriais de dupla camada tonal (<code>duotone_service_icons.dart</code> e <code>category_brand_emblem.dart</code> / <code>DarkGlassDuotoneBadge</code>), assegurando reconhecimento pré-atentivo imediato sem dependência exclusiva de leitura textual.
  </li>
  <li>
    <strong><code>RNF-05</code> — Distinção Semântica Inequívoca das 112 Medalhas de Gamificação:</strong> O motor gráfico <code>AchievementMedalForge</code> (<code>achievement_widgets.dart</code>) impõe separação cromática bimodal entre conquistas pendentes e alcançadas: as medalhas bloqueadas são obrigatoriamente renderizadas em cinza claro prateado de alta legibilidade <strong><code>#CBD5E1</code></strong> sobre fundo <code>#1E293B</code> (<span class="math-inline">C &approx; 9,8 : 1</span> AAA), contornadas por aro metálico frio <code>#94A3B8</code> e ícone sutil de cadeado em <code>#E2E8F0</code> (evitando o erro clássico de silhuetas escuras invisíveis em <em>dark mode</em>), ao passo que as medalhas desbloqueadas ascendem em paletas metálicas saturadas vibrantes (Bronze, Prata, Ouro, Platina e Diamante).
  </li>
</ul>

<h3 id="sec-4-3-2">4.3.2. RNFs de Eficiência de Desempenho e Complexidade Assintótica (<span class="mono">RNF-06</span> a <span class="mono">RNF-10</span>)</h3>
<p>
  Para atingir fluidez nativa indistinguível de sistemas operacionais de alto desempenho em telas ProMotion/LTPO de <code>120 Hz</code>, a arquitetura impõe cotas estritas de tempo de quadro, memória e complexidade algorítmica:
</p>

<ul>
  <li>
    <strong><code>RNF-06</code> — Orçamento de Quadro Cravado a <code>120 FPS</code> (<span class="math-inline">&Delta;t<sub>frame</sub> &le; 8,33 ms</span>):</strong> Em painéis de taxa de atualização <span class="math-inline">f = 120 Hz</span>, a janela temporal disponível para construção da árvore de widgets, cálculo geométrico e rasterização GPU por quadro satisfaz:
    <div class="math-formula-box">
      <div class="math-display">
        &Delta;t<sub>frame</sub> = 1000 ms / 120 = 8,333 ms &nbsp;&rArr;&nbsp; &Delta;t<sub>UI_thread</sub> (Build + Layout + Paint) + &Delta;t<sub>Raster_thread</sub> &le; 8,33 ms
      </div>
    </div>
    Dois mecanismos estruturais garantem essa cota no código-fonte: <strong>(a) Isolamento Espacial de Repintura via <code>RepaintBoundary</code></strong> em listas roláveis, cartões animados, cronômetros e camadas sobrepostas de mapa, restringindo a invalidação de <em>display lists</em> ao componente mutado; e <strong>(b) Execução Estrita Fora da UI Thread via <code>Isolate.run</code></strong> (<code>app/lib/core/utils/off_thread.dart</code>) para qualquer rotina cujo custo computacional possa exceder <code>2,0 ms</code>, incluindo compilação vetorial de PDFs (<code>DesperrengueOfficialPdfService</code>), varredura binária de imagens (<code>ImageMetadataStripper</code>) e análise Laplaciana de nitidez no KYC Tier-0.
  </li>
  <li>
    <strong><code>RNF-07</code> — Latência Percebida de <code>0 ms</code> no Carregamento de Avatares e Imagens:</strong> A renderização visual elimina completamente flashes brancos, <em>layout shifts</em> e esqueletos pulsantes repetitivos mediante a combinação de <code>InstantCachedImage</code> (<code>media_widgets.dart</code>), <code>InstantImageCacheEngine</code> e <code>EagerImagePrefetcher</code> (<code>instant_image_cache_engine.dart</code>). O motor opera em arquitetura de cache multinível: <strong>L1 em RAM (LRU limitada a <code>96 MiB</code>)</strong> que resolve bytes decodificados de forma síncrona no primeiro ciclo de <code>build()</code> (<span class="math-inline">&Delta;t<sub>hit_L1</sub> = 0 ms</span> percebidos, zero quadros intermediários), acoplada a <strong>L2 persistente local</strong> para ativos públicos imutáveis (aplicando política estrita <em>RAM-only</em> com vedação de gravação em L2 para URLs assinadas de buckets privados forenses) e pré-busca proativa controlada por semáforo em <code>EagerImagePrefetcher</code>.
  </li>
  <li>
    <strong><code>RNF-08</code> — Busca e Indexação Geoespacial em Complexidade <span class="math-inline">O(log N + K)</span>:</strong> A descoberta de ordens abertas no radar do prestador sobre uma base de <span class="math-inline">N</span> chamados registrados utiliza poda retangular indexada (índices compostos sobre status, categoria e coordenadas geográficas no PostgreSQL 17) seguida de refinamento trigonométrico de Haversine apenas sobre os candidatos do envelope espacial, assegurando custo assintótico <span class="math-inline">T<sub>radar</sub>(N, K) = O(log N + K)</span>, onde <span class="math-inline">K &#8810; N</span> representa o subconjunto efetivamente retornado na vizinhança operacional.
  </li>
  <li>
    <strong><code>RNF-09</code> — Atualização e Decremento de Contadores de Notificações em <span class="math-inline">O(1)</span>:</strong> O controlador <code>UnreadOrdersBadgeController</code> mantém estruturas indexadas em memória que processam eventos de leitura, abertura de chat ou mudança de estado de ordem por transição direta de estado unitário em tempo constante <span class="math-inline">O(1)</span> amortizado e espaço auxiliar <span class="math-inline">O(U)</span> no número de itens não lidos, banindo consultas agregadas repetitivas <code>COUNT(*)</code> a cada reconstrução de aba.
  </li>
  <li>
    <strong><code>RNF-10</code> — Avaliação Linear de Passagem Única <span class="math-inline">O(N)</span> para Conquistas e Orçamento Marginal Cloud:</strong> A computação das 22 medalhas do cliente em <code>client_achievements.dart</code> percorre o vetor histórico uma única vez (<span class="math-inline">O(N)</span> sem laços aninhados quadráticos), mantendo o custo marginal de infraestrutura em nuvem estabilizado em <strong><code>R$ 0,034</code> por ordem/usuário ativo</strong>.
  </li>
</ul>

<h3 id="sec-4-3-3">4.3.3. RNFs de Confiabilidade, Invariantes Contábeis e Ausência de Deadlocks (<span class="mono">RNF-11</span> a <span class="mono">RNF-15</span>)</h3>
<p>
  Tratando-se de infraestrutura fintech de custódia e garantia mutualista, o subsistema transacional submete-se às garantias formais <strong>ACID</strong> (<em>Atomicity, Consistency, Isolation, Durability</em>) do PostgreSQL 17, regidas por provas matemáticas explícitas:
</p>

<ul>
  <li>
    <strong><code>RNF-11</code> — Representação Monetária Inteira Estrita (<code>BIGINT</code>) e Erradicação do Erro IEEE 754:</strong> Números racionais decimais como <span class="math-inline">0,10</span> e <span class="math-inline">0,20</span> não possuem expansão finita na base binária 2 do padrão de ponto flutuante <strong>IEEE 754</strong> (<span class="math-inline">0,1<sub>10</sub> = 0,0001100110011...<sub>2</sub></span>), produzindo desvios residuais (<span class="math-inline">0,1 + 0,2 = 0,30000000000000004</span>) capazes de corromper somatórios de livros-razão. No Desperrengue, toda grandeza financeira em SQL (<code>BIGINT</code>), Python (<code>int</code>) e Dart (<code>money.dart</code>) pertence ao anel dos inteiros de 64 bits expressos em centavos (<span class="math-inline">v &isin; &#8484;<sub>64</sub></span>, suportando até <span class="math-inline">&plusmn;9,22 &times; 10<sup>16</sup></span> Reais com erro de representação identicamente nulo <span class="math-inline">&epsilon;<sub>rep</sub> = 0</span>).
  </li>
  <li>
    <strong><code>RNF-12</code> — Os Quatro Invariantes Formais de Conservação Contábil (<code>warranty_pool_ledger</code> e <code>client_wallets</code>):</strong> As migrações <code>20261030100000_client_wallet_ledger.sql</code> e <code>20261108110000_high_perf_warranty_antifraud_engine.sql</code> impõem no nível do SGBD quatro invariantes indestrutíveis:
    <div class="math-formula-box">
      <div class="math-display">
        (I1) &forall; e &isin; Ledger : amount_cents(e) &isin; &#8484;<sup>+</sup> &and; amount_cents(e) &gt; 0 &nbsp;&nbsp;|&nbsp;&nbsp; (I2) &Sigma;<sub>i &isin; Tx</sub> signed_cents<sub>i</sub> = 0 &nbsp;&and;&nbsp; UNIQUE(idempotency_key)<br/>
        (I3) &forall; t &ge; 0 : running_balance_cents(t) &ge; 0 &nbsp;&nbsp;|&nbsp;&nbsp; (I4) V<sub>total</sub> = L<sub>liq</sub>(85,0% L) + R<sub>plat</sub>(13,5% L) + C<sub>pool</sub>(1,5% L) + M(100,0% M)
      </div>
    </div>
    Nos arredondamentos inteiros de centavos em <code>(I4)</code>, o resíduo euclidiano é absorvido deterministicamente de modo que a soma exata das parcelas iguale sempre <code>labor_cents + materials_cents</code> sem criação nem destruição de 1 centavo sequer, e o <em>carve-out</em> de <code>1,5%</code> no <code>warranty_pool_ledger</code> é protegido por índice único por <code>job_id</code> contra duplicidade em retentativas.
  </li>
  <li>
    <strong><code>RNF-13</code> — Prova Matemática de Ausência de <em>Deadlocks</em> por Ordenação Estrita de Recursos (<span class="math-inline">R<sub>1</sub> &lt; R<sub>2</sub> &lt; R<sub>3</sub> &lt; R<sub>4</sub></span>):</strong> Operações concorrentes de liquidação de custódia, abertura de mediação e acionamento da Camada 3 de garantia adquirem bloqueios pessimistas de linha (<code>SELECT ... FOR UPDATE</code>) obedecendo invariavelmente à ordem total canônica sobre o conjunto de tabelas críticas:
    <div class="math-formula-box">
      <div class="math-display">
        &Pi;<sub>lock</sub> : &nbsp; R<sub>1</sub> (<code>public.jobs</code>) &prec; R<sub>2</sub> (<code>public.job_mediations</code>) &prec; R<sub>3</sub> (<code>public.escrow_maturation_entries</code>) &prec; R<sub>4</sub> (<code>public.profiles</code>)
      </div>
    </div>
    <strong>Demonstração Formal (Violação da 4ª Condição de Coffman — Espera Circular):</strong> Seja <span class="math-inline">G<sub>W</sub> = (T, E<sub>W</sub>)</span> o grafo dirigido de espera entre transações concorrentes no instante <span class="math-inline">t</span>, onde uma aresta <span class="math-inline">(T<sub>a</sub> &rarr; T<sub>b</sub>) &isin; E<sub>W</sub></span> existe se, e somente se, <span class="math-inline">T<sub>a</sub></span> aguarda um recurso <span class="math-inline">R<sup>(b)</sup></span> atualmente retido por <span class="math-inline">T<sub>b</sub></span>. Pelo protocolo <span class="math-inline">&Pi;<sub>lock</sub></span>, como <span class="math-inline">T<sub>b</sub></span> ainda solicita ou detém recursos subsequentes, qualquer cadeia onde <span class="math-inline">T<sub>a</sub></span> já retém <span class="math-inline">R<sup>(a)</sup></span> e solicita <span class="math-inline">R<sup>(b)</sup></span> satisfaz estritamente <span class="math-inline">rank(R<sup>(a)</sup>) &lt; rank(R<sup>(b)</sup>)</span>. Suponha, por absurdo, a existência de um ciclo fechado de <em>deadlock</em> <span class="math-inline">T<sub>1</sub> &rarr; T<sub>2</sub> &rarr; &hellip; &rarr; T<sub>k</sub> &rarr; T<sub>1</sub></span> (<span class="math-inline">k &ge; 2</span>). Pela transitividade da relação de ordem estrita <span class="math-inline">&lt;</span> em <span class="math-inline">{1, 2, 3, 4}</span>, obter-se-ia <span class="math-inline">rank(R<sup>(1)</sup>) &lt; rank(R<sup>(2)</sup>) &lt; &hellip; &lt; rank(R<sup>(k)</sup>) &lt; rank(R<sup>(1)</sup>)</span>, implicando a contradição aritmética <span class="math-inline">rank(R<sup>(1)</sup>) &lt; rank(R<sup>(1)</sup>)</span>. Logo, <span class="math-inline">G<sub>W</sub></span> é necessariamente um Grafo Acíclico Dirigido (DAG) em todo instante <span class="math-inline">t</span>, provando a impossibilidade matemática de <em>deadlocks</em> entre essas rotinas.
  </li>
  <li>
    <strong><code>RNF-14</code> — Reconexão Resiliente Realtime com <em>Exponential Backoff</em> e <em>Jitter</em>:</strong> O adaptador <code>resilient_stream.dart</code> gerencia quedas transitórias de rede móvel nos canais WebSocket do Supabase Realtime aplicando atraso de reconexão exponencial limitado com perturbação estocástica:
    <div class="math-formula-box">
      <div class="math-display">
        &Delta;t<sub>retry</sub>(k) = min(&Delta;t<sub>max</sub>, &Delta;t<sub>base</sub> &middot; 2<sup>k</sup>) &middot; (1 &plusmn; &gamma; &middot; U(0, 1))
      </div>
    </div>
    prevenindo tempestades sincronizadas de reconexão (<em>thundering herd</em>) e preservando o último estado válido em tela sem <em>crash</em> de stream.
  </li>
  <li>
    <strong><code>RNF-15</code> — Circuit Breaker e Degradação Graciosa em Serviços Externos:</strong> O cliente <code>SerproDatavalidMtlsClient</code> (<code>kyc_engine</code>) e o roteador cartográfico OSRM (<code>OrderLiveMapModalScreen</code>) operam com disjuntores de falha: na indisponibilidade de OSRM primário e secundário, o mapa comuta em <span class="math-inline">0 ms</span> para interpolação geodésica contínua <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos; na instabilidade externa governamental, enfileira revalidação segura sem corromper o estado transacional.
  </li>
</ul>

<h3 id="sec-4-3-4">4.3.4. RNFs de Suportabilidade: Manutenibilidade, Testabilidade e Portabilidade (<span class="mono">RNF-16</span> a <span class="mono">RNF-20</span>)</h3>
<ul>
  <li>
    <strong><code>RNF-16</code> — Clean Architecture Desacoplada em 4 Camadas e Guardas Estáticas:</strong> O código-fonte em <code>app/lib/</code> separa rigorosamente <code>presentation</code>, <code>application</code>, <code>domain/models</code> e <code>core/services</code> (infraestrutura), enquanto a lógica de negócio crítica reside em RPCs PostgreSQL e no microsserviço isolado <code>kyc_engine/</code>. A suíte <code>eng_static_guards_test.dart</code> inspeciona estaticamente a árvore de arquivos para bloquear regressões arquiteturais (como uso indevido de widgets de imagem não cacheados ou acesso direto a colunas sensíveis).
  </li>
  <li>
    <strong><code>RNF-17</code> — Verificabilidade Automatizada Exaustiva Multicamada (<code>v2.11.0</code>):</strong> A qualidade regressiva é aferida continuamente por um conjunto ortogonal de oráculos executáveis: <strong><code>762</code> testes automatizados Dart/Flutter</strong> em 45 suítes na baseline <code>v2.11.0</code> (evoluídos para <strong><code>816</code> testes</strong> em 48 suítes no <code>HEAD</code>), <strong><code>64</code> testes Python <code>pytest</code></strong> em 3 suítes criptográficas/visuais, <strong><code>12</code> verificações SQL/Monte Carlo de Geo-Privacidade</strong> (<strong><code>14</code></strong> no <code>HEAD</code>), <strong><code>17</code> testes vetoriais PDF do Dossiê LGPD</strong> e <strong><code>630</code> links documentais verificados</strong>.
  </li>
  <li>
    <strong><code>RNF-18</code> — Evolução de Esquema por <code>27</code> Migrações SQL Idempotentes:</strong> Todas as transformações estruturais de tabelas, índices, políticas RLS, triggers e funções <code>SECURITY DEFINER</code> até a <code>v2.11.0</code> estão versionadas sequencialmente em <strong><code>27</code> migrações SQL determinísticas</strong> (<code>20261009120000</code> a <code>20261113110000</code>, acrescidas de 3 migrações operacionais em <code>v2.11.1</code> totalizando 30 arquivos <code>.sql</code> e 11 suítes em <code>supabase/tests/</code>), permitindo reconstrução reprodutível de qualquer ambiente do zero.
  </li>
  <li>
    <strong><code>RNF-19</code> — Esteira CI/CD GitHub Actions e Distribuição OTA Autônoma:</strong> Os workflows <code>.github/workflows/ci.yml</code> e <code>.github/workflows/beta-release.yml</code> compilam, testam e publicam artefatos Android APK e Web PWA automaticamente. O serviço <code>AppVersionAndUpdateService</code> viabiliza atualização <em>Over-The-Air</em> (OTA) direta a partir de release oficial verificada, eliminando janelas de espera de revisão de lojas de aplicativos em correções críticas de segurança.
  </li>
  <li>
    <strong><code>RNF-20</code> — Portabilidade Multiplataforma (Android Nativo + Web/PWA Responsivo):</strong> Base de código unificada Flutter 3.47 / Dart 3.13 com abstrações condicionais limpas para câmera, armazenamento local e atualização de versão (APK nativo vs. limpeza de cache <em>ServiceWorker</em> no navegador).
  </li>
</ul>

<h3 id="sec-4-3-5">4.3.5. RNFs de Segurança e Privacidade Zero-Trust (<span class="mono">RNF-21</span> a <span class="mono">RNF-25</span>)</h3>
<ul>
  <li>
    <strong><code>RNF-21</code> — Protocolo Criptográfico <em>Temporal &amp; Spatial Geo-Privacy Lock</em> (<code>ADR-0022</code>):</strong> Para proteger a inviolabilidade domiciliar do morador (LGPD Art. 6º, III), tanto o backend PostgreSQL (RPC <code>get_job_location_for_viewer</code>, função <code>_can_see_exact_location</code> e máquina de fases <code>_job_privacy_phase</code>) quanto a UI do prestador (<code>GeoPrivacyPolicyEngine</code>, <code>ProtectedAreaMapCard</code>, <code>GeoLockNotice</code>) mascaram logradouro, número, complemento/apartamento e coordenadas GPS exatas até as <strong><code>00:00:00 America/Sao_Paulo</code></strong> do dia agendado do serviço (e voltam a mascará-los imediatamente após a conclusão na fase <code>POST_COMPLETION_RELOCKED</code>). Enquanto bloqueado, o centro do círculo aproximado exibido ao mercado é derivado no servidor a partir de segredo CSPRNG de 256 bits (<span class="math-inline">K<sub>geo</sub> &isin; {0,1}<sup>256</sup></span> em <code>private.geo_privacy_secrets</code>) segundo:
    <div class="math-formula-box">
      <div class="math-display">
        d = HMAC-SHA256(K<sub>geo</sub>, job_id) &nbsp;&rArr;&nbsp; &rho; &isin; [151 m, 349 m], &nbsp; &theta; &isin; [0, 2&pi;), &nbsp; R<sub>vis</sub> &isin; [500 m, 800 m], &nbsp; com R<sub>vis</sub> &minus; &rho; &ge; 150 m
      </div>
    </div>
    Como <span class="math-inline">(&rho;, &theta;, R<sub>vis</sub>)</span> é uma função determinística pseudoaleatória (PRF) de <code>job_id</code> com chave secreta inacessível ao cliente, <strong>ataques de triangulação estatística por múltiplas consultas ou múltiplas contas coludentes são matematicamente neutralizados</strong>: <span class="math-inline">M</span> consultas retornam exatamente o mesmo círculo, mantendo entropia condicional máxima sobre a posição real da residência no interior da coroa protegida.
  </li>
  <li>
    <strong><code>RNF-22</code> — Sanitização Automática <em>Fail-Closed</em> de Metadados EXIF/GPS (<code>ImageMetadataStripper</code>):</strong> Toda fotografia capturada ou importada tem seus marcadores binários <code>APP1/EXIF</code> (incluindo tags <code>GPSLatitude</code>, <code>GPSLongitude</code>, <code>GPSAltitude</code>, timestamp original e serial do dispositivo), <code>XMP</code> e <code>IPTC</code> expurgados antes da saída de rede; se o parser detectar estrutura binária anômala não sanitizável, o upload é sumariamente bloqueado.
  </li>
  <li>
    <strong><code>RNF-23</code> — Cofre Dual Anti-Coação e Isolamento Criptográfico WORM:</strong> Os hashes de PIN e segredos de copresença são segregados em <code>private.job_forensic_secrets</code> (inacessível a <code>SELECT</code> em <code>public.jobs</code>, blindagem <code>[SEC-02]</code>), os dossiês biométricos no <code>kyc_engine</code> são cifrados em repouso sob envelope WORM <code>KWV2</code> com derivação <code>HKDF-SHA256</code> e cifra autenticada <code>AES-256-GCM</code>, e o protocolo <em>Silent Duress PIN</em> protege a vida do morador sob extorsão presencial congelando silenciosamente o repasse (<code>FROZEN_UNDER_DURESS</code>).
  </li>
  <li>
    <strong><code>RNF-24</code> — Validação Criptográfica Governamental VIO / ICP-Brasil e mTLS 1.3:</strong> Nenhum documento de identidade é aceito apenas por aparência visual: exige-se verificação de assinatura digital <code>CMS/PKCS#7</code> (<code>ECDSA P-256</code> ou <code>RSA-2048</code>) na cadeia pública ICP-Brasil/SENATRAN do QR Code VIO, validação mTLS 1.3 junto ao SERPRO Datavalid e comparação em tempo constante (<code>hmac.compare_digest</code> / <code>timingSafeEqual</code>) em todos os webhooks internos.
  </li>
  <li>
    <strong><code>RNF-25</code> — Blindagem Red Team Anti-IDOR, RLS Forçado e Imutabilidade Forense (<code>[SEC-01]</code> a <code>[SEC-09]</code>):</strong> Todas as tabelas de domínio operam com <em>Row Level Security</em> ativo, todas as 35+ funções <code>SECURITY DEFINER</code> fixam explicitamente <code>SET search_path = public</code> (<code>[SEC-08]</code>) e validam <code>auth.uid()</code> contra ataques de <em>Insecure Direct Object Reference</em> (IDOR <code>[SEC-03]</code>), e as evidências periciais residem no bucket privado imutável <code>forensic-evidence</code> com URLs assinadas de curta duração (<code>[SEC-09]</code>).
  </li>
</ul>

<h3 id="sec-4-3-6">4.3.6. Quadro Sinóptico Quantificado dos Requisitos Não Funcionais (ISO/IEC 25010:2023)</h3>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">ID</th>
      <th width="17%">Categoria ISO 25010</th>
      <th width="26%">Métrica / Invariante Matemático Exato</th>
      <th width="27%">Mecanismo Real de Implementação</th>
      <th width="21%">Verificação Automatizada</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>RNF-01</code></td>
      <td>Usabilidade (Acessibilidade)</td>
      <td>Contraste <span class="math-inline">C &ge; 4,5:1</span> (AA) e <span class="math-inline">15,6:1</span> texto primário (AAA); viewport <code>320px @ 1.4x</code> zero overflow</td>
      <td><code>app_tokens.dart</code> (<code>#0E1218</code> / <code>#EAEFF6</code>), <code>ConstrainedBox(480)</code>, cabeçalho 2 andares</td>
      <td><code>ui_polish_test.dart</code>, <code>ux_client_and_shared_polish_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-02</code></td>
      <td>Usabilidade (Operabilidade)</td>
      <td>Tempo integral de abertura por voz <span class="math-inline">t &lt; 60 s</span></td>
      <td><code>request_wizard.dart</code>, <code>voice_dictation.dart</code>, <code>smart_transcript_formatter.dart</code>, <code>smart_triage_service.dart</code></td>
      <td><code>smart_transcript_formatter_test.dart</code>, <code>smart_triage_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-03</code>..<code>05</code></td>
      <td>Usabilidade (Estética &amp; Cognição)</td>
      <td><code>0</code> jargões na UI; <code>33</code> ícones <em>Duotone</em>; <code>112</code> medalhas (bloqueadas em <code>#CBD5E1</code> c/ contraste <code>9,8:1</code>)</td>
      <td><code>duotone_service_icons.dart</code>, <code>AchievementMedalForge</code> (<code>achievement_widgets.dart</code>)</td>
      <td><code>achievements_test.dart</code>, <code>carbon_geo_badges_and_image_cache_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-06</code></td>
      <td>Desempenho (Comportamento Temporal)</td>
      <td>Taxa <code>120 FPS</code> (<span class="math-inline">&Delta;t<sub>frame</sub> &le; 8,33 ms</span>); zero bloqueio síncrono pesado na UI thread</td>
      <td><code>RepaintBoundary</code> seletivo + <code>Isolate.run</code> em <code>off_thread.dart</code></td>
      <td><code>eng_address_privacy_and_offthread_test.dart</code>, <code>eng_static_guards_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-07</code></td>
      <td>Desempenho (Utilização de Recursos)</td>
      <td><code>0 ms</code> percebidos em L1 hit; teto RAM L1 = <code>96 MiB</code>; política <em>RAM-only</em> p/ mídia privada</td>
      <td><code>InstantCachedImage</code>, <code>InstantImageCacheEngine</code>, <code>EagerImagePrefetcher</code></td>
      <td><code>eng_image_cache_privacy_test.dart</code>, <code>orders_map_ux_and_instant_media_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-08</code>..<code>10</code></td>
      <td>Desempenho (Escalabilidade)</td>
      <td>Busca geoespacial <span class="math-inline">O(log N + K)</span>; contadores <span class="math-inline">O(1)</span>; conquistas cliente <span class="math-inline">O(N)</span>; nuvem <code>R$ 0,034/OS</code></td>
      <td>Índices compostos PostgreSQL, <code>UnreadOrdersBadgeController</code>, <code>client_achievements.dart</code></td>
      <td><code>eng_unread_badge_test.dart</code>, <code>orders_and_client_achievements_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-11</code>..<code>12</code></td>
      <td>Confiabilidade (Integridade ACID)</td>
      <td>Moeda inteira <code>BIGINT</code> (<span class="math-inline">&epsilon;<sub>IEEE754</sub> = 0</span>); 4 invariantes <code>(I1)..(I4)</code> soma zero e saldo <span class="math-inline">&ge; 0</span></td>
      <td><code>money.dart</code>, <code>20261030100000_client_wallet_ledger.sql</code>, <code>warranty_pool_ledger</code></td>
      <td><code>eng_smart_split_cents_test.dart</code>, <code>fintech_warranty_security_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-13</code>..<code>15</code></td>
      <td>Confiabilidade (Tolerância a Falhas)</td>
      <td><code>0</code> deadlocks (<span class="math-inline">R<sub>1</sub> &lt; R<sub>2</sub> &lt; R<sub>3</sub> &lt; R<sub>4</sub></span>); backoff exponencial c/ jitter; rota <span class="math-inline">C<sup>&infin;</sup></span> fallback</td>
      <td>Locks ordenados PL/pgSQL, <code>resilient_stream.dart</code>, cascata OSRM + arco geodésico</td>
      <td><code>eng_resilience_and_policy_test.dart</code>, <code>red_team_warranty_and_kyc_forensics_test.dart</code></td>
    </tr>
    <tr>
      <td><code>RNF-16</code>..<code>20</code></td>
      <td>Suportabilidade (Manutenibilidade &amp; Portabilidade)</td>
      <td>Clean Arch 4 camadas; <code>762</code> testes Flutter (<code>816</code> HEAD) + <code>64</code> pytest + <code>27</code> migrações SQL (<code>30</code> HEAD) + OTA APK</td>
      <td><code>.github/workflows/ci.yml</code>, <code>beta-release.yml</code>, <code>AppVersionAndUpdateService</code></td>
      <td><code>eng_static_guards_test.dart</code>, <code>eng_update_security_test.dart</code>, <code>test-dossie.mjs</code> (<code>17/17</code>)</td>
    </tr>
    <tr>
      <td><code>RNF-21</code>..<code>25</code></td>
      <td>Segurança &amp; Privacidade (Zero-Trust)</td>
      <td>Geo-Lock <code>HMAC-SHA256</code> (<code>151m–349m</code> em <code>500m–800m</code> até <code>00:00</code> SP); <code>100%</code> strip EXIF; <code>AES-256-GCM</code> WORM; 9 blindagens <code>[SEC-01..09]</code></td>
      <td><code>20261113100000_temporal_geo_privacy_lock.sql</code>, <code>20261113110000_security_hardening_audit.sql</code>, <code>kyc_engine</code></td>
      <td><code>test-geo-privacy-sql.mjs</code> (<code>12/12</code> v2.11.0; <code>14/14</code> HEAD), <code>eng_image_metadata_stripper_test.dart</code>, <code>pytest</code> (<code>64/64</code>)</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 4.4 — PBB CANVAS, CATÁLOGO GHERKIN BDD E PRIORIZAÇÃO MOSCOW+WSJF  -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-4-4">
  <span class="sh-tag">SEÇÃO 4.4 &bull; ENGENHARIA ÁGIL DE ESCOPO &bull; PRODUCT BACKLOG BUILDING, GHERKIN BDD E ECONOMIA DE FLUXO</span>
  <h2>4.4. Product Backlog Building (PBB), Catálogo de Histórias do Usuário (Gherkin) e Priorização Científica (MoSCoW + WSJF)</h2>
  <p>Decomposição rastreável do produto por meio do Canvas PBB completo, especificação comportamental executável em Gherkin para todos os épicos do ecossistema e ordenação matemática combinando classificação MoSCoW e índice econômico WSJF (SAFe).</p>
</div>

<h3 id="sec-4-4-1">4.4.1. Decomposição Estruturada de Escopo via Product Backlog Building (PBB Canvas)</h3>
<p>
  Para assegurar alinhamento semântico integral entre a descoberta empírica de mercado (Capítulos 2 e 3) e as unidades executáveis de engenharia de software, aplicou-se o método <strong>Product Backlog Building (PBB)</strong> proposto por Fábio Aguiar. O PBB atua como ponte formal entre problemas validados, expectativas mensuráveis, personas operacionais, <em>Features</em> (Épicos funcionais) e <em>Product Backlog Items</em> (PBIs granulares), impedindo a infiltração de funcionalidades desconectadas de valor real. A Figura 4.2 apresenta o diagrama vetorial consolidado do <strong>Canvas PBB do Ecossistema Desperrengue (<code>v2.11.0</code>)</strong>, seguido de sua matriz analítica detalhada.
</p>

<div class="figure-box">
  ${svgPbbCanvas}
</div>

<table class="lean-canvas-table">
  <thead>
    <tr>
      <th width="20%">1. PROBLEMAS ESTRUTURAIS<br/><span style="font-weight:400;color:#CBD5E1;">(Evidência Empírica N = 46)</span></th>
      <th width="20%">2. EXPECTATIVAS DE VALOR<br/><span style="font-weight:400;color:#CBD5E1;">(Critérios de Sucesso)</span></th>
      <th width="18%">3. PERSONAS E ATORES<br/><span style="font-weight:400;color:#CBD5E1;">(Papéis no Sistema)</span></th>
      <th width="21%">4. ÉPICOS / FEATURES<br/><span style="font-weight:400;color:#CBD5E1;">(Capacidades Macro)</span></th>
      <th width="21%">5. PRODUCT BACKLOG ITEMS<br/><span style="font-weight:400;color:#CBD5E1;">(PBIs Entregues na v2.11.0)</span></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>
        &bull; <strong>Informalidade Analógica (<code>96,4%</code>):</strong> Dependência lenta de indicações boca a boca (<code>78,6%</code>) e grupos de WhatsApp (<code>17,9%</code>).<br/>
        &bull; <strong>Insegurança Domiciliar (<code>60,7%</code>):</strong> Receio de abrir a residência a estranhos sem checagem governamental nem proteção de endereço.<br/>
        &bull; <strong>Risco Moral e Falta de Garantia (<code>92,9%</code>):</strong> Pagamentos diretos sem custódia e abandono pós-serviço.<br/>
        &bull; <strong>Pedágio Especulativo de Moedas (<code>100,0%</code> rejeição):</strong> Plataformas cobram por <em>lead</em> mesmo sem fechamento.<br/>
        &bull; <strong>Clientes Fantasmas (<code>55,6%</code>) e Confisco em Peças:</strong> Viagens perdidas e taxa indevida sobre insumos fiscais.<br/>
        &bull; <strong>Memória Predial Inexistente:</strong> Perda de comprovantes para vistoria imobiliária e ABNT NBR 5674.
      </td>
      <td>
        &bull; Abertura de chamado normal/SOS por voz em <strong><code>&lt; 60 s</code></strong> sem jargão.<br/>
        &bull; <strong><code>0,0%</code> de custo</strong> para enviar orçamento e <strong><code>0,0%</code> de taxa</strong> sobre materiais com NF-e.<br/>
        &bull; Endereço exato oculto em raio <code>500m–800m</code> até as <strong><code>00:00</code></strong> do dia do reparo.<br/>
        &bull; Liquidação atômica via <strong>PIN de 4 dígitos</strong> + modo anti-coação silencioso.<br/>
        &bull; <strong>Garantia real de 90 dias</strong> caucionada por fundo próprio (<code>1,5%</code>).<br/>
        &bull; Fluidez nativa a <strong><code>120 FPS</code></strong> (<code>8,33 ms</code>) e imagens a <strong><code>0 ms</code></strong>.<br/>
        &bull; Conformidade plena LGPD Art. 18/20, CDC Art. 26 e NBR 5674.
      </td>
      <td>
        <strong>P1 — Morador Contratante</strong><br/>
        Proprietário ou locatário urbano que contrata reparos ou conservação exigindo segurança residencial, transparência fiscal e garantia.<br/><br/>
        <strong>P2 — Prestador Técnico / MEI</strong><br/>
        Profissional qualificado em 1+ das 33 categorias que busca demanda solvente sem comprar moedas e valorização por mérito.<br/><br/>
        <strong>P3 — Governança &amp; Motor Zero-Trust</strong><br/>
        Subsistema autônomo de compliance KYC, privacidade geoespacial, SEFAZ e mediação técnica de garantia.
      </td>
      <td>
        &bull; <code>EP-01</code>: Perfil Dual-Mode, Herança KYC &amp; Dossiê LGPD.<br/>
        &bull; <code>EP-02</code>: Chamado por Voz/SOS, EXIF-Strip &amp; 33 Categorias.<br/>
        &bull; <code>EP-03</code>: Radar <span class="math-inline">O(log N + K)</span> &amp; Orçamento Sem Moedas.<br/>
        &bull; <code>EP-04</code>: <em>Smart Split</em> (<code>0%</code> Peças) &amp; Auditoria SEFAZ.<br/>
        &bull; <code>EP-05</code>: <em>Smart Escrow</em> PIX <code>BIGINT</code> &amp; PIN 4 Dígitos.<br/>
        &bull; <code>EP-06</code>: Garantia 90 Dias (3 Camadas + Pool <code>1,5%</code>).<br/>
        &bull; <code>EP-07</code>: KYC Zero-Trust VIO/SERPRO &amp; Cofre Anti-Coação.<br/>
        &bull; <code>EP-08</code>: <em>Temporal &amp; Spatial Geo-Privacy Lock</em>.<br/>
        &bull; <code>EP-09</code>: Passaporte Predial NBR 5674 &amp; Radar Vivo <code>80%</code>.<br/>
        &bull; <code>EP-10</code>: Gamificação (112 Medalhas <code>#CBD5E1</code>) &amp; OTA APK.
      </td>
      <td>
        &bull; <code>PBI-01</code>: Custódia PIX + Checkout PIN 4 dígitos.<br/>
        &bull; <code>PBI-02</code>: Geo-Lock <code>HMAC-SHA256</code> até <code>00:00</code> SP.<br/>
        &bull; <code>PBI-03</code>: Partição <code>labor</code>/<code>materials</code> + NF-e Mod 11.<br/>
        &bull; <code>PBI-04</code>: Strip binário EXIF/GPS <em>fail-closed</em>.<br/>
        &bull; <code>PBI-05</code>: Conta unificada + herança KYC.<br/>
        &bull; <code>PBI-06</code>: Radar por especialidade + proposta grátis.<br/>
        &bull; <code>PBI-07</code>: <em>Silent Duress PIN</em> (<code>FROZEN_UNDER_DURESS</code>).<br/>
        &bull; <code>PBI-08</code>: Wizard voz <code>&lt;60s</code> + 33 ícones <em>Duotone</em>.<br/>
        &bull; <code>PBI-09</code>: Dossiê PDF A4 + exclusão escopada.<br/>
        &bull; <code>PBI-10</code>: Pipeline Tier-0 + Argon + VIO + Carbon.<br/>
        &bull; <code>PBI-11</code>: Escalonamento C1/C2/C3 + <code>warranty_pool_ledger</code>.<br/>
        &bull; <code>PBI-12</code>: Worker SEFAZ <code>&gt;26h</code> + <em>clawback</em> <code>15%</code>.<br/>
        &bull; <code>PBI-13..16</code>: PDF NBR 5674, Mapa <code>80%</code>, 112 Medalhas e OTA.
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-4-4-2">4.4.2. Catálogo Completo de Histórias do Usuário e Critérios de Aceitação Formais em Gherkin</h3>
<p>
  Em conformidade com as práticas de <strong>Behavior-Driven Development (BDD)</strong> e com o princípio de testabilidade da <strong>ISO/IEC/IEEE 29148:2018</strong>, cada épico estrutural do ecossistema é formalizado em <strong>Histórias do Usuário</strong> redigidas estritamente na sintaxe canônica <code>Como [Persona], eu quero [Ação/Capacidade], para que [Valor/Benefício Mensurável]</code>, seguidas de seus respectivos <strong>Critérios de Aceitação Executáveis em Gherkin (<code>Funcionalidade / Cenário / Dado / Quando / E / Então</code>)</strong> diretamente mapeados às suítes de teste automatizadas do repositório.
</p>

<!-- US-01 & US-02: EP-01 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-01 [EP-01 &bull; RF-02 / RF-03] — Alternância Unificada Dual-Mode com Herança Automática de KYC</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>usuário cadastrado na plataforma (Morador ou Prestador)</strong>, <em>eu quero</em> <strong>alternar instantaneamente entre o Modo Cliente e o Modo Profissional aproveitando a certificação biométrica KYC já aprovada</strong>, <em>para que</em> <strong>seja possível contratar serviços residenciais e ofertar especialidades técnicas sob uma única conta sem retrabalho documental</strong>.</p>
  <pre><code>Funcionalidade: Perfil Unificado Dual-Mode e Herança Criptográfica de KYC
  Cenário: Habilitação do Modo Profissional por morador já certificado no KYC Zero-Trust
    Dado que o usuário autenticado possui registro em "public.profiles" com "kyc_status = 'verified'"
    Quando o usuário aciona a chave seletora "Ativar Modo Profissional" e seleciona suas categorias dentre as 33 disponíveis
    E define seu raio operacional de atendimento geográfico
    Então o sistema habilita o papel profissional sem solicitar nova captura de CNH ou selfie de vivacidade
    E comuta a paleta semântica da interface do acento laranja "#FF8F52" para o acento azul "#74A7FF" em tempo O(1).</code></pre>
</div>

<div class="gherkin-box">
  <div class="gherkin-title">US-02 [EP-01 &bull; RF-04 / RF-05] — Exclusão Granular Escopada com Entrega Prévia de Dossiê PDF LGPD</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>titular de dados pessoais</strong>, <em>eu quero</em> <strong>solicitar a exclusão seletiva apenas do perfil Cliente, apenas do perfil Profissional ou da conta completa recebendo previamente um Dossiê PDF com todo o histórico</strong>, <em>para que</em> <strong>meus direitos de portabilidade e eliminação (LGPD Art. 18, V e VI) sejam exercidos sem perda de comprovantes legítimos</strong>.</p>
  <pre><code>Funcionalidade: Offboarding Escopado Seguro com Garantia Fail-Closed de Portabilidade (excluir-conta)
  Cenário: Exclusão exclusiva do escopo Profissional com preservação da conta Cliente e envio de Dossiê A4
    Dado que o titular autenticado não possui ordens em custódia ativa nem mediações abertas no escopo "provider"
    Quando submete requisição autenticada à Edge Function "excluir-conta" com parâmetro "scope = 'provider'"
    Então o módulo "dossie.ts" gera em memória um arquivo vetorial "%PDF-1.x" A4 contendo os dados do escopo selecionado
    E despacha o documento ao e-mail verificado do titular antes de invocar a RPC "purge_account"
    E caso o provedor de e-mail retorne falha de entrega, o expurgo no banco de dados é imediatamente abortado (fail-closed).</code></pre>
</div>

<!-- US-03: EP-02 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-03 [EP-02 &bull; RF-06 / RF-07 / RF-08] — Abertura de Chamado por Voz (&lt; 60s) e Sanitização EXIF/GPS</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Morador Contratante em situação de reparo programado ou emergência doméstica (SOS)</strong>, <em>eu quero</em> <strong>relatar o problema por comando de voz e anexar fotos que tenham seus metadados GPS ocultos automaticamente</strong>, <em>para que</em> <strong>o chamado seja publicado em menos de 60 segundos na categoria correta sem vazar a coordenada exata do imóvel nos arquivos de mídia</strong>.</p>
  <pre><code>Funcionalidade: Abertura Assistida por Voz e Sanitização Binária Obrigatória de Mídia
  Cenário: Publicação de chamado emergencial SOS por ditado de voz com foto sanitizada
    Dado que o morador acessa o assistente "RequestWizard" e dita o relato de vazamento hidráulico severo
    Quando o motor "SmartTranscriptFormatter" pontua o texto e o "SmartTriage" sugere a categoria dentre as 33 opções Duotone
    E o morador anexa uma fotografia JPEG contendo cabeçalhos binários "APP1/EXIF" com tags "GPSLatitude" e "GPSLongitude"
    Então o "ImageMetadataStripper" remove em "Isolate.run" 100% dos segmentos EXIF/GPS/XMP/IPTC antes do upload
    E a ordem é gravada em estado "open" em tempo total de interação inferior a 60 segundos.</code></pre>
</div>

<!-- US-04: EP-03 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-04 [EP-03 &bull; RF-12 / RF-13 / RF-14] — Radar Geoespacial por Especialidade e Orçamento Sem Moedas</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Prestador Técnico Autônomo ou MEI</strong>, <em>eu quero</em> <strong>visualizar no radar apenas chamados compatíveis com minhas especialidades e enviar orçamentos detalhados gratuitamente sem comprar pacotes de moedas</strong>, <em>para que</em> <strong>meu capital de giro seja preservado e a remuneração da plataforma ocorra exclusivamente quando o serviço for contratado e executado</strong>.</p>
  <pre><code>Funcionalidade: Descoberta Geoespacial O(log N + K) Livre de Pedágio Especulativo de Leads
  Cenário: Submissão gratuita de proposta técnica em chamado compatível no radar
    Dado que o prestador possui "kyc_status = 'verified'" e especialidade homologada em "Elétrica Residencial"
    Quando consulta o radar de oportunidades em sua região operacional
    Então o sistema retorna em O(log N + K) os chamados abertos da categoria exibindo apenas o círculo aproximado de 500m a 800m
    E permite submeter proposta discriminada em "job_quotes" sem exigir saldo prévio de créditos ou moedas virtuais.</code></pre>
</div>

<!-- US-05: EP-04 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-05 [EP-04 &bull; RF-17 / RF-18 / RF-19 / RF-20] — Smart Split com Isenção (0%) em Peças Fiscais e Auditoria SEFAZ</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Prestador Técnico e Morador Contratante</strong>, <em>eu quero</em> <strong>separar no orçamento o valor da mão de obra do valor das peças comprovadas por Nota Fiscal Eletrônica com taxa zero sobre materiais</strong>, <em>para que</em> <strong>o morador pague o preço real de varejo pelos insumos com nota fiscal e o profissional receba 100% do reembolso das peças sem bitributação</strong>.</p>
  <pre><code>Funcionalidade: Particionamento Contábil Assimétrico Smart Split e Antifraude Fiscal SEFAZ
  Cenário: Liquidação com isenção de 0% sobre materiais mediante NF-e válida e monitoramento pós-26h
    Dado um orçamento aprovado com "labor_cents = 22000" (R$ 220,00) e "materials_cents = 10000" (R$ 100,00)
    Quando o prestador captura a NF-e de 44 dígitos na tela "MaterialReceiptCaptureScreen"
    E o validador confirma o dígito Módulo 11, o CNPJ emissor e a extração grounded no "kyc-argon-vision-gate"
    Então o sistema retém exatamente 15,0% apenas sobre a mão de obra (R$ 29,70 plataforma + R$ 3,30 warranty_pool_ledger)
    E repassa 100,0% dos materiais (R$ 100,00) isentos de comissão ao prestador
    E agenda auditoria assíncrona na SEFAZ após 26 horas para executar clawback automático de 15,0% caso a nota seja cancelada.</code></pre>
</div>

<!-- US-06: EP-05 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-06 [EP-05 &bull; RF-21 / RF-22 / RF-23 / RF-24] — Smart Escrow PIX e Liberação Atômica por PIN de 4 Dígitos</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Morador Contratante e Prestador Técnico</strong>, <em>eu quero</em> <strong>que o pagamento fique retido em custódia PIX auditável desde a contratação e seja liberado somente mediante digitação presencial do PIN criptográfico de 4 dígitos na conclusão</strong>, <em>para que</em> <strong>o risco de inadimplência para o técnico e o risco de abandono de serviço para o morador sejam simultaneamente eliminados</strong>.</p>
  <pre><code>Funcionalidade: Custódia Transacional Smart Escrow em Centavos BIGINT e Checkout Criptográfico
  Cenário: Aprovisionamento PIX, execução presencial e liberação por PIN válido
    Dado que o morador aceita a proposta e liquida o PIX confirmado de forma idempotente pela RPC "confirm_topup"
    Quando o prestador conclui o reparo, anexa as fotos finais e insere o PIN de 4 dígitos informado pelo morador
    Então o banco confronta o hash exclusivamente no cofre isolado "private.job_forensic_secrets" ([SEC-02])
    E transiciona atomicamente a ordem para "completed" sob partidas dobradas de soma zero em centavos BIGINT
    E registra o recebível em "escrow_maturation_entries" conforme a faixa de maturação do prestador (D+0, D+2 ou D+5..D+7).</code></pre>
</div>

<!-- US-07: EP-06 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-07 [EP-06 &bull; RF-25 / RF-26 / RF-27 / RF-28] — Mediação e Garantia Real de 90 Dias em 3 Camadas</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Morador Contratante amparado pelo CDC (Art. 26, II)</strong>, <em>eu quero</em> <strong>acionar garantia formal de até 90 dias com escalonamento automático desde o retorno do técnico até a cobertura pelo Fundo Garantidor Mutualista</strong>, <em>para que</em> <strong>qualquer vício de execução seja sanado sem custo adicional de mão de obra mesmo em caso de omissão do prestador original</strong>.</p>
  <pre><code>Funcionalidade: Garantia Legal de 90 Dias em 3 Camadas e Livro-Razão warranty_pool_ledger
  Cenário: Escalonamento de sinistro da Camada 1 para Camada 3 com cobertura mutualista sem deadlock
    Dado que uma ordem concluída há menos de 90 dias apresentou reincidência técnica documentada com foto forense
    Quando o chamado na Camada 1 supera 48 horas sem resolução pelo executor e o laudo pericial na Camada 2 confirma o vício
    Então a rotina "trigger_layer3_rework" ([SEC-06]) adquire locks na ordem estrita "R1 (jobs) < R2 (job_mediations) < R3 (escrow_maturation_entries) < R4 (profiles)"
    E debita o "warranty_pool_ledger" preservando o invariante "running_balance_cents >= 0" para custear novo profissional qualificado.</code></pre>
</div>

<!-- US-08 & US-09: EP-07 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-08 [EP-07 &bull; RF-31 / RF-32 / RF-33 / RF-34] — Homologação KYC Biométrica Zero-Trust com Explicabilidade SHAP</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Candidato a Prestador e Morador Contratante</strong>, <em>eu quero</em> <strong>que a identidade civil e biométrica seja validada localmente por nitidez e remotamente contra assinaturas VIO/ICP-Brasil e SERPRO Datavalid com fatores explicáveis</strong>, <em>para que</em> <strong>perfis falsos ou adulterados sejam barrados com rigor forense respeitando o direito à explicação da LGPD (Art. 20)</strong>.</p>
  <pre><code>Funcionalidade: Pipeline KYC Zero-Trust em 6 Estágios (Tier-0 Isolate + Argon + VIO/SERPRO + Carbon + WORM)
  Cenário: Verificação documental completa com paridade tripla de CPF e arquivamento WORM AES-256-GCM
    Dado que a captura documental aprovou nitidez Laplaciana no Tier-0 ("Isolate.run" a custo R$ 0,00)
    Quando o endpoint "POST /v1/kyc/verify-full" valida o token Anti-Swap HMAC (TTL <= 180s), extrai campos via Argon High (temperature = 0.0)
    E verifica a assinatura CMS/PKCS#7 ICP-Brasil do QR Code VIO, a igualdade "qr_cpf == ocr_cpf == typed_cpf" e a biometria SERPRO mTLS 1.3
    Então o "CarbonFraudOrchestrator" emite veredito acompanhado dos Top-3 fatores SHAP sem jargão técnico
    E cifra as evidências no cofre WORM "KWV2" (HKDF-SHA256 + AES-256-GCM) notificando o banco via "kyc-carbon-webhook".</code></pre>
</div>

<div class="gherkin-box">
  <div class="gherkin-title">US-09 [EP-07 &bull; RF-35] — Cofre Dual Anti-Coação e Protocolo Silent Duress PIN</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Morador em atendimento residencial presencial</strong>, <em>eu quero</em> <strong>dispor de um código reverso silencioso de coação no momento da conclusão do serviço</strong>, <em>para que</em> <strong>minha integridade física seja preservada diante de eventual ameaça enquanto o sistema congela secretamente o desvio financeiro</strong>.</p>
  <pre><code>Funcionalidade: Proteção Física sob Coação Presencial via Silent Duress PIN
  Cenário: Inserção do PIN de 4 dígitos invertido durante encerramento sob ameaça
    Dado que o PIN legítimo não palíndromo da ordem é "4819"
    Quando é submetida a sequência reversa "9184" na tela de conclusão
    Então a interface exibe confirmação visual verde idêntica ao fluxo normal para não alertar o agressor
    Mas o backend registra silenciosamente o estado "FROZEN_UNDER_DURESS", bloqueia qualquer saque PIX e preserva telemetria forense.</code></pre>
</div>

<!-- US-10: EP-08 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-10 [EP-08 &bull; RF-36 / RF-37 / RF-38] — Temporal &amp; Spatial Geo-Privacy Lock até 00:00 do Dia Agendado</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Morador Contratante</strong>, <em>eu quero</em> <strong>que meu logradouro, número, apartamento e GPS exato permaneçam mascarados em um raio de 500m a 800m até as 00:00 do dia agendado do serviço e voltem a ser ocultados após a conclusão</strong>, <em>para que</em> <strong>nenhum terceiro ou prestador tenha acesso prematuro ou perpétuo à localização exata da minha residência</strong>.</p>
  <pre><code>Funcionalidade: Bloqueio Geoespacial Temporal e Espacial Imune a Triangulação (ADR-0022)
  Cenário: Ocultação pré-dia para prestador já contratado, liberação à meia-noite SP e re-ofuscação pós-serviço
    Dado que uma ordem agendada para data futura encontra-se contratada ("HIRED_PRE_DAY_LOCKED") antes das 00:00:00 America/Sao_Paulo
    Quando o prestador contratado invoca a RPC "get_job_location_for_viewer" ou abre o cartão de mapa
    Então o banco retorna "NULL" para rua, número, complemento e coordenadas exatas, entregando apenas o centro "_geo_fuzzy_center" derivado por HMAC-SHA256(job_id, secret_key) em círculo de 500m–800m
    E somente a partir de 00:00:00 do dia agendado ("SERVICE_DAY_UNLOCKED") libera o endereço exato exclusivamente ao prestador contratado
    E assim que a ordem transiciona para "completed" ou "cancelled", re-ofusca os dados na fase "POST_COMPLETION_RELOCKED".</code></pre>
</div>

<!-- US-11: EP-09 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-11 [EP-09 &bull; RF-11 / RF-29 / RF-30] — Passaporte Predial ABNT NBR 5674 e Radar Cartográfico 80% Livre</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Proprietário ou Inquilino de Imóvel Urbano</strong>, <em>eu quero</em> <strong>acompanhar o deslocamento do técnico em mapa amplo no dia do reparo e exportar o Passaporte Oficial de Manutenção em PDF compatível com a ABNT NBR 5674</strong>, <em>para que</em> <strong>a conservação do patrimônio imobiliário seja comprovada perante imobiliárias, seguradoras e futuros compradores</strong>.</p>
  <pre><code>Funcionalidade: Rastreamento Cartográfico Desobstruído e Certificação Documental ABNT NBR 5674
  Cenário: Emissão off-thread do Passaporte Predial PDF vetorial com selo SHA-256
    Dado que o imóvel possui ordens concluídas com registros técnicos e notas fiscais vinculadas
    Quando o morador solicita "Exportar Passaporte do Imóvel"
    Então o "DesperrengueOfficialPdfService" compila em "Isolate.run" um documento "%PDF-1.4" estruturado conforme a ABNT NBR 5674 e a Lei 8.245/91
    E estampa código verificador "DSP-PASS-*" com hash SHA-256 mantendo a UI estável a 120 FPS (<= 8,33 ms/frame).</code></pre>
</div>

<!-- US-12: EP-10 -->
<div class="gherkin-box">
  <div class="gherkin-title">US-12 [EP-10 &bull; RF-39 / RF-40 / RF-41 / RF-42] — Gamificação Bilateral de 112 Medalhas e Atualização OTA Segura</div>
  <p><strong>História do Usuário:</strong> <em>Como</em> <strong>Cliente ou Profissional engajado no ecossistema</strong>, <em>eu quero</em> <strong>acompanhar conquistas visuais claras dentre as 112 medalhas da plataforma e receber atualizações diretas e verificadas do aplicativo</strong>, <em>para que</em> <strong>a excelência recorrente seja reconhecida publicamente e o dispositivo execute sempre a versão mais segura do software</strong>.</p>
  <pre><code>Funcionalidade: Forja Vetorial das 112 Medalhas (#CBD5E1 vs. Ligas Vibrantes) e Distribuição OTA Verificada
  Cenário: Exibição legível de medalhas bloqueadas e desbloqueadas e validação estrita de domínio no OTA
    Dado que o usuário acessa a galeria de conquistas renderizada por "AchievementMedalForge" (90 medalhas Profissional + 22 Cliente)
    Quando o sistema desenha insígnias ainda não alcançadas ao lado de insígnias conquistadas
    Então as bloqueadas são exibidas em prata clara legível "#CBD5E1" sobre "#1E293B" com cadeado sutil "#E2E8F0" e as conquistadas em cores metálicas vibrantes
    E ao verificar atualização no "AppVersionAndUpdateService", qualquer URL de APK fora da whitelist HTTPS oficial do GitHub é sumariamente bloqueada.</code></pre>
</div>

<h3 id="sec-4-4-3">4.4.3. Priorização Científica do Backlog: Modelo Combinado MoSCoW + WSJF (SAFe)</h3>
<p>
  Para eliminar subjetividade política no sequenciamento de engenharia, o backlog do Desperrengue foi priorizado mediante protocolo híbrido em dois estágios: <strong>(1º) Classificação Categórica de Criticidade Normativa MoSCoW</strong> (<em>Must have</em> — inegociável para operação segura e conformidade legal; <em>Should have</em> — elevado valor competitivo e retenção; <em>Could have</em> — conveniência incremental de baixo acoplamento; <em>Won't have</em> — explicitamente vetado ou excluído do escopo para impedir <em>feature creep</em>) e <strong>(2º) Ranqueamento Econômico Quantitativo pelo Índice WSJF (<em>Weighted Shortest Job First</em>)</strong> formulado por Donald Reinertsen e adotado no framework <strong>SAFe</strong>, que maximiza o valor econômico entregue por unidade de tempo ao dividir o <strong>Custo do Atraso (<em>Cost of Delay — CoD</em>)</strong> pelo <strong>Tamanho Relativo do Trabalho (<em>Job Size</em>)</strong> na escala modificada de Fibonacci <span class="math-inline">{1, 2, 3, 5, 8, 13, 21}</span>:
</p>

<div class="math-formula-box">
  <div class="math-display">
    WSJF<sub>i</sub> = CoD<sub>i</sub> / JobSize<sub>i</sub> = (Valor ao Usuário<sub>i</sub> + Criticidade Temporal<sub>i</sub> + Redução de Risco ou Oportunidade<sub>i</sub>) / Esforço Fibonacci<sub>i</sub>
  </div>
</div>

<p>
  A matriz a seguir apresenta a ordenação completa dos <strong>18 itens estruturais do Product Backlog (<code>PBI-01</code> a <code>PBI-18</code>)</strong>, demonstrando matematicamente por que os mecanismos de custódia financeira, privacidade geoespacial, isenção de peças e blindagem criptográfica receberam precedência absoluta de implementação até a consolidação integral na versão <code>v2.11.0</code>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="6%">Rank</th>
      <th width="8%">PBI ID</th>
      <th width="8%">Épico</th>
      <th width="28%">Item do Product Backlog (Capacidade Entregue / Escopo)</th>
      <th width="9%">MoSCoW</th>
      <th width="6%">Valor</th>
      <th width="6%">Tempo</th>
      <th width="6%">Risco</th>
      <th width="6%">CoD</th>
      <th width="6%">Size</th>
      <th width="11%">WSJF (Status)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1º</strong></td>
      <td><code>PBI-01</code></td>
      <td><code>EP-05</code></td>
      <td><strong>Smart Escrow PIX em Centavos <code>BIGINT</code> + Checkout por PIN 4 Dígitos</strong> (<code>RF-21..24</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>21</td>
      <td>21</td>
      <td><strong>63</strong></td>
      <td>8</td>
      <td><strong>7,88</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>2º</strong></td>
      <td><code>PBI-02</code></td>
      <td><code>EP-08</code></td>
      <td><strong>Temporal &amp; Spatial Geo-Privacy Lock</strong> (<code>HMAC-SHA256</code> <code>500m–800m</code> até <code>00:00</code> SP, <code>RF-36..38</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>21</td>
      <td><strong>55</strong></td>
      <td>8</td>
      <td><strong>6,88</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>3º</strong></td>
      <td><code>PBI-03</code></td>
      <td><code>EP-04</code></td>
      <td><strong>Smart Split Assimétrico (<code>0%</code> em Peças) + Validação NF-e Mod 11 &amp; OCR</strong> (<code>RF-17..19</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>13</td>
      <td><strong>47</strong></td>
      <td>8</td>
      <td><strong>5,88</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>4º</strong></td>
      <td><code>PBI-04</code></td>
      <td><code>EP-02</code></td>
      <td><strong>Sanitização Binária Automática EXIF/GPS <em>Fail-Closed</em> no Upload</strong> (<code>RF-07</code>, <code>RNF-22</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>8</td>
      <td>8</td>
      <td>13</td>
      <td><strong>29</strong></td>
      <td>5</td>
      <td><strong>5,80</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>5º</strong></td>
      <td><code>PBI-05</code></td>
      <td><code>EP-01</code></td>
      <td><strong>Autenticação PKCE, Conta Unificada Dual-Mode e Herança KYC</strong> (<code>RF-01..03</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>13</td>
      <td>8</td>
      <td>8</td>
      <td><strong>29</strong></td>
      <td>5</td>
      <td><strong>5,80</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>6º</strong></td>
      <td><code>PBI-06</code></td>
      <td><code>EP-03</code></td>
      <td><strong>Radar Geoespacial <span class="math-inline">O(log N + K)</span>, Orçamento Sem Moedas e Check-in HMAC</strong> (<code>RF-12..16</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>8</td>
      <td><strong>42</strong></td>
      <td>8</td>
      <td><strong>5,25</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>7º</strong></td>
      <td><code>PBI-07</code></td>
      <td><code>EP-07</code></td>
      <td><strong>Cofre Dual Anti-Coação e Protocolo <em>Silent Duress PIN</em></strong> (<code>RF-35</code>, <code>RNF-23</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>8</td>
      <td>5</td>
      <td>13</td>
      <td><strong>26</strong></td>
      <td>5</td>
      <td><strong>5,20</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>8º</strong></td>
      <td><code>PBI-08</code></td>
      <td><code>EP-02</code></td>
      <td><strong>Abertura de Chamado Normal/SOS por Voz (<code>&lt; 60s</code>), 33 Categorias <em>Duotone</em> e Agenda</strong> (<code>RF-06, 08..10</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>5</td>
      <td><strong>39</strong></td>
      <td>8</td>
      <td><strong>4,88</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>9º</strong></td>
      <td><code>PBI-09</code></td>
      <td><code>EP-01</code></td>
      <td><strong>Exclusão Granular Escopada + Dossiê PDF Portável LGPD Art. 18</strong> (<code>RF-04..05</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>8</td>
      <td>8</td>
      <td>8</td>
      <td><strong>24</strong></td>
      <td>5</td>
      <td><strong>4,80</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>10º</strong></td>
      <td><code>PBI-12</code></td>
      <td><code>EP-04</code></td>
      <td><strong>Auditoria Assíncrona SEFAZ Pós-26h e <em>Clawback</em> Antifraude de <code>15%</code></strong> (<code>RF-20</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>5</td>
      <td>5</td>
      <td>13</td>
      <td><strong>23</strong></td>
      <td>5</td>
      <td><strong>4,60</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>11º</strong></td>
      <td><code>PBI-10</code></td>
      <td><code>EP-07</code></td>
      <td><strong>Motor KYC Biométrico Zero-Trust Completo</strong> (Tier-0 + Argon + VIO/SERPRO + Carbon SHAP + WORM, <code>RF-31..34</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>21</td>
      <td><strong>55</strong></td>
      <td>13</td>
      <td><strong>4,23</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>12º</strong></td>
      <td><code>PBI-11</code></td>
      <td><code>EP-06</code></td>
      <td><strong>Garantia Real de 90 Dias em 3 Camadas + Fundo Mutualista <code>1,5%</code></strong> (<code>warranty_pool_ledger</code>, <code>RF-25..28</code>)</td>
      <td><span class="badge-must">MUST</span></td>
      <td>21</td>
      <td>13</td>
      <td>21</td>
      <td><strong>55</strong></td>
      <td>13</td>
      <td><strong>4,23</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>13º</strong></td>
      <td><code>PBI-13</code></td>
      <td><code>EP-09</code></td>
      <td><strong>Passaporte Oficial de Manutenção Predial PDF Vetorial ABNT NBR 5674</strong> (<code>RF-29..30</code>)</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td>13</td>
      <td>5</td>
      <td>3</td>
      <td><strong>21</strong></td>
      <td>5</td>
      <td><strong>4,20</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>14º</strong></td>
      <td><code>PBI-14</code></td>
      <td><code>EP-09</code></td>
      <td><strong>Radar Cartográfico ao Vivo (<code>80%</code> Livre) + Cascata OSRM e Fallback <span class="math-inline">C<sup>&infin;</sup></span> + Cache <code>0 ms</code></strong> (<code>RF-11</code>, <code>RNF-06..07</code>)</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td>8</td>
      <td>5</td>
      <td>5</td>
      <td><strong>18</strong></td>
      <td>5</td>
      <td><strong>3,60</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>15º</strong></td>
      <td><code>PBI-15</code></td>
      <td><code>EP-10</code></td>
      <td><strong>Sistema de Gamificação Bilateral: 112 Medalhas (<code>#CBD5E1</code> vs. Ligas Vibrantes) e Streaks</strong> (<code>RF-39..41</code>)</td>
      <td><span class="badge-should">SHOULD</span></td>
      <td>13</td>
      <td>5</td>
      <td>5</td>
      <td><strong>23</strong></td>
      <td>8</td>
      <td><strong>2,88</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>16º</strong></td>
      <td><code>PBI-16</code></td>
      <td><code>EP-10</code></td>
      <td><strong>Atualização <em>Over-The-Air</em> (OTA) Direta e Segura do APK + Purge PWA</strong> (<code>RF-42</code>, <code>RNF-19</code>)</td>
      <td><span class="badge-could">COULD</span></td>
      <td>3</td>
      <td>3</td>
      <td>2</td>
      <td><strong>8</strong></td>
      <td>3</td>
      <td><strong>2,67</strong> &bull; Entregue</td>
    </tr>
    <tr>
      <td><strong>17º</strong></td>
      <td><code>PBI-17</code></td>
      <td>Fora v2.11</td>
      <td><strong>Venda Direta com Estoque Físico Próprio de Materiais de Construção</strong> (descartado para preservar modelo <em>asset-light</em>)</td>
      <td><span class="badge-wont">WON'T</span></td>
      <td>5</td>
      <td>1</td>
      <td>2</td>
      <td><strong>8</strong></td>
      <td>21</td>
      <td><strong>0,38</strong> &bull; Excluído</td>
    </tr>
    <tr>
      <td><strong>18º</strong></td>
      <td><code>PBI-18</code></td>
      <td>Vedado</td>
      <td><strong>Cobrança Antecipada de Moedas ou Pacotes Especulativos de Leads</strong> (rejeitado por <code>100%</code> dos técnicos na pesquisa)</td>
      <td><span class="badge-wont">WON'T</span></td>
      <td>1</td>
      <td>1</td>
      <td>1</td>
      <td><strong>3</strong></td>
      <td>13</td>
      <td><strong>0,23</strong> &bull; Banido</td>
    </tr>
  </tbody>
</table>

<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">Síntese de Cobertura Funcional do Backlog (v2.11.0)</div>
    <p>Dos 16 PBIs aprovados para construção nas faixas <code>MUST</code> (12 PBIs), <code>SHOULD</code> (3 PBIs) e <code>COULD</code> (1 PBI), <strong>100,0% (16/16) encontram-se integralmente codificados, migrados em produção e cobertos por testes automatizados</strong> no marco canônico <code>v2.11.0</code>, totalizando 42 RFs e 25 RNFs verificáveis sem débitos funcionais ocultos.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">Governança Anti-Escopo (Disciplina Won't Have)</div>
    <p>A explicitação formal dos itens <code>WON'T HAVE</code> (<code>PBI-17</code> e <code>PBI-18</code>) comprova maturidade de gestão de produto: impede imobilização de capital em estoques físicos de baixa rotação e blinda contratualmente os prestadores contra a regressão a modelos predatórios de venda de <em>leads</em>.</p>
  </div>
</div>
</section>
`;

import {
  svgBusinessModelCanvas,
  svgFunilAarrrJornada,
  svgPrototipacaoLeanCiclo,
} from './svg_ch2_ch3_business.mjs';

export const ch3Html = String.raw`
<!-- ======================================================================= -->
<!-- CAPÍTULO 3: MODELO DE NEGÓCIO, LEAN, MARKETING E PLANO FINANCEIRO       -->
<!-- ======================================================================= -->
<section class="chapter-section" id="cap-3">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 3</div>
  <div class="cb-body">
    <h2>AVALIAÇÃO DO MODELO DE NEGÓCIO, PROTOTIPAGEM LEAN, MARKETING DIGITAL E PLANO DE NEGÓCIOS COMPLETO</h2>
    <p>Arquitetura integral do Business Model Canvas bilateral, engenharia de crescimento (Funil Pirata AARRR e Jornada Ponta a Ponta), validação empírica Lean (Smoke Test, Concierge, Mágico de Oz e Teste A/B), telemetria de produto, governança estratégica (PESTEL, Porter, SWOT/TOWS, BSC), contabilidade tributária CPC 47 / IFRS 15 e modelagem econômico-financeira auditada (<span class="mono">M1–M12</span>).</p>
  </div>
</div>

<!-- ======================================================================= -->
<!-- SEÇÃO 3.1: AVALIAÇÃO DO MODELO DE NEGÓCIO, LEAN E MARKETING DIGITAL     -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-3-1" style="margin-top: 10px;">
  <span class="sh-tag">SEÇÃO 3.1 &bull; BUSINESS MODEL CANVAS, GROWTH ENGINEERING, VALIDAÇÃO LEAN E TELEMETRIA</span>
  <h2>3.1. Avaliação do Modelo de Negócio, Prototipagem Lean e Estratégia de Marketing Digital</h2>
  <p>Decomposição sistêmica dos nove blocos de Osterwalder &amp; Pigneur agrupados nos eixos de Desejabilidade (O QUE e PARA QUEM), Operacionalidade (COMO) e Sustentabilidade Financeira (CUSTOS e RECEITAS), seguida do plano de aquisição, roteiro executivo de defesa, protótipo real <span class="mono">v2.11.0</span>, experimentação Lean e governança orientada a dados.</p>
</div>

<p>
  A viabilidade de longo prazo de uma plataforma multilateral exige coerência matemática entre a criação de valor para os usuários, a eficiência de sua infraestrutura tecnológica e a captura sustentável de receita líquida. O modelo de negócios do <strong>Desperrengue (<code>v2.11.0</code>)</strong> foi estruturado sobre o referencial canônico do <strong>Business Model Canvas (BMC)</strong> de Osterwalder &amp; Pigneur (2010), adaptado às especificidades microeconômicas de plataformas fiduciárias de dois lados. O diagrama vetorial a seguir consolida a visão arquitetural integrada dos nove blocos constitutivos.
</p>

${svgBusinessModelCanvas}

<h3 id="sec-3-1-1">3.1.1. Descrição do Canvas — O QUE e PARA QUEM (Proposta de Valor, Segmentos, Canais e Relacionamento)</h3>
<p>
  O hemisfério direito do Business Model Canvas define a <strong>Desejabilidade de Mercado</strong>: quais ativos de valor são entregues (<em>O Que</em>), quais estratos socioeconômicos e institucionais são atendidos (<em>Para Quem</em>), por quais meios digitais e físicos ocorre a entrega (<em>Canais</em>) e sob quais mecanismos de vínculo sustenta-se a retenção (<em>Relacionamento</em>).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Bloco do Canvas (Desejabilidade)</th>
      <th width="78%">Especificação Analítica, Econômica e Funcional no Ecossistema Desperrengue (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Proposta de Valor Bilateral</strong><br/>(<em>O QUE é entregue</em>)</td>
      <td>
        <strong>Para o Morador / Contratante:</strong> Intermediação residencial de confiança absoluta com identidade civil e biométrica <em>Zero-Trust</em> auditada (VIO/ICP-Brasil), ocultação criptográfica do endereço residencial até as <code>00:00:00</code> do dia agendado (<em>Geo-Privacy Lock</em> <code>500m–800m</code>), pagamento protegido em custódia Pix (<em>Smart Escrow</em> liberado por PIN de 4 dígitos com modo silencioso anti-coação), economia real pela isenção de taxa sobre materiais (<code>0%</code> no <em>Smart Split</em>), Garantia Legal de 90 dias em 3 camadas caucionada por Fundo Garantidor próprio e emissão automática do <strong>Passaporte Predial ABNT NBR 5674</strong>.<br/>
        <strong>Para o Prestador / Profissional:</strong> Captação justa de clientes reais com <strong>orçamentos 100% gratuitos</strong> (extinção total da compra de moedas), eliminação de inadimplência pela reserva prévia do pagamento em custódia, preservação integral de margem com <strong><code>0,0%</code> de comissão sobre peças/insumos</strong>, construção de carreira auditada (90 medalhas + 6 emblemas automáticos) e alternância instantânea <em>Dual-Mode</em>.
      </td>
    </tr>
    <tr>
      <td><strong>2. Segmentos de Clientes</strong><br/>(<em>PARA QUEM gera valor</em>)</td>
      <td>
        &bull; <strong>Segmento B2C Moradores Urbanos:</strong> Proprietários residentes, casais economicamente ativos, profissionais em regime <em>home office</em>/híbrido e idosos residentes em apartamentos e casas urbanas que priorizam segurança física, pontualidade e garantia.<br/>
        &bull; <strong>Segmento Locatários e Síndicos Orgânicos:</strong> Inquilinos sujeitos às obrigações de manutenção ordinária da Lei nº 8.245/1991 (Art. 23) e síndicos de edifícios residenciais que demandam notas fiscais discriminadas e conformidade <strong>ABNT NBR 5674</strong>.<br/>
        &bull; <strong>Segmento B2B Institucional:</strong> Administradoras de condomínios, imobiliárias digitais (homologação técnica em vistorias de entrada e entrega de chaves) e companhias seguradoras residenciais.<br/>
        &bull; <strong>Segmento Oferta Técnica (Lado Ofertante do Marketplace):</strong> Profissionais autônomos qualificados e Microempreendedores Individuais (MEIs) distribuídos nas <strong>33 categorias técnicas</strong> homologadas na plataforma.
      </td>
    </tr>
    <tr>
      <td><strong>3. Canais de Aquisição, Distribuição e Entrega</strong></td>
      <td>
        &bull; <strong>Progressive Web App (PWA Responsivo):</strong> Acesso imediato via navegador mobile/desktop estruturado em <code>ConstrainedBox(maxWidth: 480)</code> sem barreira de download inicial, com gestão automatizada de <em>Service Worker</em>.<br/>
        &bull; <strong>Aplicativo Nativo Android com Motor OTA (<em>Over-The-Air</em>):</strong> Distribuição via pacote nativo assinado (e lojas oficiais) equipado com <code>AppVersionAndUpdateService</code>, permitindo atualização em 1 toque a partir de <em>releases</em> verificados.<br/>
        &bull; <strong>Deep Links e E-mail Transacional:</strong> Rotas diretas <code>desperrengue://onboarding/ativar</code> disparadas pela função <code>enviar-email-aprovacao</code> (SMTP Resend) e compartilhamento direto de orçamentos/passaportes.<br/>
        &bull; <strong>SEO Hiperlocal e Pontos Físicos Parceiros:</strong> Páginas indexáveis por especialidade/bairro, QR Codes em murais de portarias condominiais e balcões de lojas de materiais elétricos, hidráulicos e de construção.
      </td>
    </tr>
    <tr>
      <td><strong>4. Relacionamento com Clientes</strong></td>
      <td>
        &bull; <strong>Autoatendimento Multimodal Guiado (<code>120 FPS</code>):</strong> Triagem intuitiva assistida por mídia sanitizada e acompanhamento de status em tempo real com mapa fluido (<code>&ge; 80%</code> de viewport livre).<br/>
        &bull; <strong>Custódia Automatizada sem Atrito:</strong> Mediação algorítmica impessoal do pagamento via PIN presencial e maturação escalonada conforme o índice de confiança <code>RTS</code>.<br/>
        &bull; <strong>Engajamento Gamificado Bilateral:</strong> <strong>112 medalhas</strong> determinísticas (90 do prestador + 22 do cliente) e 6 insígnias reputacionais que recompensam recorrência, pontualidade e excelência técnica.<br/>
        &bull; <strong>Mediação Assistida e Retenção Preventiva:</strong> Gatilho automático de proteção em crise (<code>ReviewTags.shouldOfferGuarantee</code>) e Central de Suporte com protocolo <code>#DSP-XXXX</code> e SLA máximo de <code>24h</code>.
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-1-2">3.1.2. Descrição do Canvas — COMO (Atividades-Chave, Recursos-Chave e Principais Parcerias)</h3>
<p>
  O hemisfério esquerdo do Canvas estabelece a <strong>Infraestrutura Operacional e Arquitetural</strong> que torna exequível a entrega contínua da proposta de valor em escala nacional com baixíssima intervenção humana:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Bloco do Canvas (Operação)</th>
      <th width="78%">Materialização Técnica, Operacional e Contratual (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>5. Atividades-Chave</strong><br/>(Processos críticos diários)</td>
      <td>
        <strong>1. Engenharia e Evolução da Plataforma:</strong> Desenvolvimento contínuo sob <em>Clean Architecture</em>, blindagem de segurança <em>Red Team</em> (9 controles ativos na migração <code>027</code>) e manutenção das suítes determinísticas de teste.<br/>
        <strong>2. Liquidação Fiduciária <em>Smart Escrow</em> e Auditoria <em>Smart Split</em>:</strong> Processamento atômico de depósitos Pix, partição em centavos <code>BIGINT</code> entre mão de obra, peças e Fundo Garantidor, e validação assíncrona de notas fiscais de 44 dígitos na SEFAZ (incluindo auditoria Fase 2 <code>&gt; 26h</code> com <em>clawback</em> automático caso uma NF-e seja cancelada após o uso).<br/>
        <strong>3. Operação do Motor <em>Zero-Trust KYC</em> e Geo-Privacidade:</strong> Execução em cascata da triagem documental/biométrica, verificação de QR Code VIO/ICP-Brasil e operação das janelas temporais <code>HMAC-SHA256</code>.<br/>
        <strong>4. Curadoria Algorítmica de Reputação e Governança de Disputas:</strong> Atualização em <span class="math-inline">O(1)</span> do ranking <em>Tiered Waterfall</em> e condução das 3 camadas de garantia em até <code>24h</code>.
      </td>
    </tr>
    <tr>
      <td><strong>6. Recursos-Chave</strong><br/>(Ativos tecnológicos, fiduciários e intelectuais)</td>
      <td>
        &bull; <strong>Arquitetura Multiplataforma de Alta Performance:</strong> Código-fonte unificado Flutter <code>3.47</code> / Dart <code>3.13</code> com motor próprio de cache <code>0 ms</code> (<code>InstantImageCacheEngine</code>) e pré-validação em <code>Isolate.run</code>.<br/>
        &bull; <strong>Núcleo Transacional e Criptográfico:</strong> Banco de dados <code>PostgreSQL 17</code> com <code>27</code> migrações canônicas (<code>30</code> no HEAD), esquemas isolados <code>private.*</code>, 5 Supabase Edge Functions (<code>enviar-email-aprovacao</code>, <code>excluir-conta</code>, <code>kyc-argon-vision-gate</code>, <code>kyc-carbon-webhook</code> e <code>pix-webhook</code>) e microsserviço Python FastAPI <code>kyc_engine</code>.<br/>
        &bull; <strong>Livro-Razão Contábil ACID e Fundo Garantidor:</strong> Tabelas imutáveis de partidas dobradas (<code>warranty_pool_ledger</code> e <code>escrow_maturation_entries</code>) livres de erros de ponto flutuante.<br/>
        &bull; <strong>Propriedade Intelectual Algorítmica:</strong> Protocolos proprietários <em>Temporal &amp; Spatial Geo-Privacy Lock</em>, <em>Smart Split Fiscal</em>, <em>Silent Duress PIN</em> e gerador vetorial <code>DesperrengueOfficialPdfService</code>.
      </td>
    </tr>
    <tr>
      <td><strong>7. Principais Parcerias</strong><br/>(Alianças de infraestrutura e distribuição)</td>
      <td>
        &bull; <strong>Instituições de Pagamento / PSP Pix (Homologados BACEN/SPI):</strong> Processamento de QR Codes dinâmicos Pix, contas gráficas segregadas de custódia e liquidação automatizada de saques.<br/>
        &bull; <strong>SERPRO / Datavalid (mTLS 1.3) e Cadeia ICP-Brasil / VIO:</strong> Fontes soberanas para validação criptográfica de documentos civis (CIN/CNH) e conformidade biométrica.<br/>
        &bull; <strong>Provedores Cloud, IA Multimodal e Mensageria:</strong> Supabase Cloud (região <code>sa-east-1</code> São Paulo para baixa latência e soberania LGPD), modelos visuais/analíticos de fronteira (<em>Argon High</em> / <em>Carbon High</em>) e Resend SMTP.<br/>
        &bull; <strong>Varejistas de Materiais de Construção, Condomínios e Imobiliárias:</strong> Lojas elétricas/hidráulicas (captação de técnicos no balcão e emissão de NF-e) e administradoras prediais (adoção do Passaporte ABNT).
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-1-3">3.1.3. Descrição do Canvas — ESTRUTURA DE CUSTOS e FONTES DE RECEITAS</h3>
<p>
  A base inferior do Canvas demonstra a superioridade estrutural da engenharia financeira do Desperrengue: custos variáveis comprimidos à escala de centavos por transação combinados a múltiplas fontes de receita não predatórias e alinhadas ao sucesso real dos participantes.
</p>

<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">8. Estrutura de Custos Ultra-Enxuta (<em>Lean &amp; Edge-First</em>)</div>
    <p>
      &bull; <strong>Pré-Validação KYC e Mídia a Custo Zero (<code>R$ 0,00</code>):</strong> O estágio <em>Tier-0</em> em <code>Isolate.run</code> descarta localmente fotos borradas, escuras ou adulteradas na CPU do smartphone do usuário, poupando requisições caras de nuvem e bureaus.<br/>
      &bull; <strong>Custo Marginal Cloud Irrisório (<code>R$ 0,034/OS</code>):</strong> Uso disciplinado de RPCs compiladas no PostgreSQL, indexação <span class="math-inline">O(log N + K)</span> e cache local L1/L2 elimina tráfego redundante de banda.<br/>
      &bull; <strong>Processamento Financeiro Pix Enxuto:</strong> Taxas de liquidação e split PSP situadas entre <code>0,80%</code> e <code>1,50%</code> (frente a <code>4,5%</code> de cartões tradicionais), sem risco de <em>chargeback</em>.<br/>
      &bull; <strong>OPEX Fixo Austero e Escalável:</strong> Operação 100% <em>asset-light</em> (zero frota, zero imóveis operacionais e zero folha celetista de campo), com OPEX mensal inicial de <code>R$ 600,00</code> a <code>R$ 800,00</code> nos primeiros 6 meses (infraestrutura Pro, contabilidade digital e micro-verba hiperlocal), expandindo apenas mediante geração própria de caixa.
    </p>
  </div>
  <div class="info-card">
    <div class="ic-title">9. Fontes de Receitas Diversificadas (5 Motores Sinérgicos)</div>
    <p>
      &bull; <strong>1. <em>Take Rate</em> Assimétrico sobre Mão de Obra (<code>15,0%</code> Bruto = <code>13,5%</code> Líquido + <code>1,5%</code> Fundo):</strong> Incide estritamente sobre <code>V_MO</code> (com piso promocional de entrada de <code>12,0%</code> em serviços compactos no Ano 1), retendo <code>13,5%</code> como receita operacional da plataforma e destinando <code>1,5%</code> automaticamente ao Fundo Garantidor.<br/>
      &bull; <strong>2. Isenção Estratégica sobre Peças (<code>0,0%</code> no <em>Smart Split</em>):</strong> Embora gere receita bruta zero sobre <code>V_Mat</code>, atua como âncora de retenção que impede o <em>bypass</em> e assegura os <code>13,5%</code> sobre toda a mão de obra associada.<br/>
      &bull; <strong>3. Taxa de Conveniência e Despacho Prioritário SOS (<code>&lt; 60s</code>):</strong> Adicional de urgência em chamados emergenciais imediatos.<br/>
      &bull; <strong>4. <em>Float</em> Financeiro sobre Custódia e Antecipação:</strong> Rendimento diário (<code>100% CDI</code>) sobre os saldos em <em>Smart Escrow</em> e maturação escalonada (<code>D+2</code> a <code>D+7</code>), mais <em>spread</em> opcional de antecipação <code>D+0</code>.<br/>
      &bull; <strong>5. Receita Recorrente B2B (SaaS Condominial/Imobiliário e Seguros):</strong> Planos corporativos de gestão predial baseados no Passaporte <strong>ABNT NBR 5674</strong> e <em>cross-sell</em> de coberturas patrimoniais estendidas.
    </p>
  </div>
</div>

<h3 id="sec-3-1-4">3.1.4. Ferramentas de Marketing Digital, Detalhamento Tático de Canais/CAC, Funil Pirata (AARRR) e Jornada Completa</h3>
<p>
  A estratégia de <em>Go-to-Market</em> (GTM) rejeita campanhas publicitárias genéricas de alto custo de dispersão, adotando uma arquitetura científica de <strong>Marketing de Performance Hiperlocal e Crescimento Guiado pelo Produto (<em>Product-Led Growth — PLG</em>)</strong>.
</p>

<h4 id="sec-3-1-4-canais">I. Mix Tático-Operacional de Ferramentas Digitais e Métricas de Mídia</h4>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Canal / Ferramenta Digital</th>
      <th width="46%">Tática de Execução Segmentada (Demanda vs. Oferta)</th>
      <th width="32%">KPIs de Mídia e Metas Operacionais</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Google Search Ads (Intenção Emergencial Alta)</strong></td>
      <td>Campanhas hipersegmentadas por raio de CEP (<code>&le; 8 km</code>) focadas em termos de dor imediata (ex.: <em>"eletricista urgente [bairro]"</em>, <em>"conserto vazamento com garantia"</em>), direcionando direto ao fluxo PWA SOS.</td>
      <td><code>CTR &ge; 6,8%</code> &bull; <code>CPC médio R$ 1,45</code> &bull; Conversão de página <code>CVR &ge; 14%</code>.</td>
    </tr>
    <tr>
      <td><strong>SEO Hiperlocal Programático &amp; Google Perfil da Empresa</strong></td>
      <td>Páginas estáticas ultrarrápidas geradas por combinação das <strong>33 categorias &times; bairros atendidos</strong>, respondendo dúvidas de preço médio <em>Smart Split</em> e normas ABNT NBR 5674 para tráfego orgânico gratuito.</td>
      <td>Custo por clique orgânico <code>R$ 0,00</code> &bull; <code>&ge; 38%</code> das aquisições totais a partir do Mês 6.</td>
    </tr>
    <tr>
      <td><strong>Meta Ads (Instagram / Reels / WhatsApp Click-to-Chat)</strong></td>
      <td>Criativos curtos de contraste visual: para moradores, demonstração do endereço bloqueado até as <code>00:00</code> e PIN de segurança; para técnicos, comparativo real mostrando <em>"Zero moedas + 0% de taxa nas peças"</em>.</td>
      <td><code>CPM &le; R$ 18,00</code> &bull; <code>CTR &ge; 2,4%</code> &bull; <code>CPA Cadastro Prestador &le; R$ 14,00</code>.</td>
    </tr>
    <tr>
      <td><strong>Marketing Condominial &amp; Parcerias de Balcão (O2O)</strong></td>
      <td>Displays QR Code homologados junto a síndicos/administradoras (lado Cliente) e totens em balcões de lojas de materiais elétricos e hidráulicos (lado Profissional, exatamente onde o técnico compra insumos).</td>
      <td><code>CAC Blended Consolidado = R$ 24,50</code> (rampa madura multi-canal até <code>R$ 42,00</code>) &bull; <code>ROAS &ge; 6,2x</code>.</td>
    </tr>
    <tr>
      <td><strong>CRM Transacional, Push &amp; Ciclo de Vida Preventivo</strong></td>
      <td>Alertas automáticos de manutenção preventiva sazonal baseados no histórico do Passaporte Predial (ex.: higienização semestral de ar-condicionado ou revisão anual de quadro elétrico) + e-mails transacionais Resend.</td>
      <td>Taxa de abertura <code>&ge; 44%</code> &bull; Reativação anual <code>&ge; 4,2 pedidos/ano</code> na base madura.</td>
    </tr>
  </tbody>
</table>

<h4 id="sec-3-1-4-cac">II. Alocação Orçamentária Tática por Canal e Decomposição Algébrica do CAC Blended (<span class="mono">R$ 24,50</span>)</h4>
<p>
  Para eliminar qualquer opacidade sobre a origem do Custo de Aquisição Consolidado (<code>CAC Blended = R$ 24,50</code> na coorte auditada de 24 meses e <code>R$ 42,00</code> na expansão nacional madura de 42 meses), o modelo econométrico de atribuição pondera o Custo por Aquisição Efetiva de Cliente Transacionante (<span class="math-inline">CPA<sub>i</sub></span>, mensurado apenas quando a 1ª Ordem de Serviço é efetivamente liquidada em custódia) pela participação relativa (<span class="math-inline">w<sub>i</sub></span>) de cada um dos cinco canais de tração:
</p>

<div class="math-formula-box">
  <div class="math-display">
    CAC<sub>Blended</sub> = &Sigma;<sub>i=1..5</sub> (w<sub>i</sub> &times; CPA<sub>i</sub>) = 1,44 + 2,76 + 1,44 + 10,96 + 7,90 = R$ 24,50
  </div>
</div>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="26%">Canal de Aquisição Atribuído (<span class="mono">i</span>)</th>
      <th width="14%">Fração da Verba Paga</th>
      <th width="15%">Peso nas Conversões (<span class="mono">w<sub>i</sub></span>)</th>
      <th width="17%">CPA Cliente Pagante (<span class="mono">CPA<sub>i</sub></span>)</th>
      <th width="28%">Parcela Ponderada (<span class="mono">w<sub>i</sub> &times; CPA<sub>i</sub></span>) &amp; Racional Técnico</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. SEO Hiperlocal Programático &amp; Google Perfil</strong></td>
      <td><code>0,0%</code> (Orgânico)</td>
      <td><code>32,0%</code></td>
      <td><code>R$ 4,50</code></td>
      <td><strong><code>R$ 1,44</code></strong> &bull; Custo marginal de clique nulo; reflete apenas rateio técnico de hospedagem/indexação das páginas bairro &times; categoria.</td>
    </tr>
    <tr>
      <td><strong>2. QR Code Condominial &amp; Balcão de Lojas (O2O)</strong></td>
      <td><code>14,0%</code></td>
      <td><code>24,0%</code></td>
      <td><code>R$ 11,50</code></td>
      <td><strong><code>R$ 2,76</code></strong> &bull; Material físico de portaria e totens em casas elétricas/hidráulicas com altíssima taxa de confiança local.</td>
    </tr>
    <tr>
      <td><strong>3. Indicação Gamificada &amp; Loop Passaporte ABNT</strong></td>
      <td><code>6,0%</code></td>
      <td><code>18,0%</code></td>
      <td><code>R$ 8,00</code></td>
      <td><strong><code>R$ 1,44</code></strong> &bull; Compartilhamento orgânico de PDFs assinados, convite premiado com insígnias e conversão cruzada <em>Dual-Mode</em>.</td>
    </tr>
    <tr>
      <td><strong>4. Google Search Ads (Intenção SOS &le; 8 km)</strong></td>
      <td><code>48,0%</code></td>
      <td><code>16,0%</code></td>
      <td><code>R$ 68,50</code></td>
      <td><strong><code>R$ 10,96</code></strong> &bull; Derivado de <code>CPC = R$ 1,45</code> com conversão de página <code>14,0%</code> e ativação em 1ª OS paga de <code>15,12%</code> (<code>CVR ponta a ponta = 2,12%</code>).</td>
    </tr>
    <tr>
      <td><strong>5. Meta / Instagram Reels &amp; Click-to-Chat</strong></td>
      <td><code>32,0%</code></td>
      <td><code>10,0%</code></td>
      <td><code>R$ 79,00</code></td>
      <td><strong><code>R$ 7,90</code></strong> &bull; Vídeos de contraste demonstrando <em>Geo-Privacy Lock</em> para moradoras e isenção de moedas/peças para técnicos.</td>
    </tr>
    <tr>
      <td><strong>CONSOLIDADO AUDITADO (Coorte 24m)</strong></td>
      <td><strong><code>100,0%</code></strong></td>
      <td><strong><code>100,0%</code></strong> (<code>74%</code> PLG/O2O)</td>
      <td>Média Harmônica Controlada</td>
      <td><strong><code>CAC Blended = R$ 24,50</code></strong> &bull; Na escala nacional madura (42m, <code>48%</code> mídia paga), sobe a <strong><code>R$ 42,00</code></strong> mantendo <code>LTV/CAC = 9,65x</code>.</td>
    </tr>
  </tbody>
</table>

<h4 id="sec-3-1-4-aarrr">III. Engenharia do Funil de Vendas Pirata (AARRR — Dave McClure)</h4>
<p>
  O acompanhamento quantitativo do crescimento submete-se às cinco etapas encadeadas do modelo <strong>AARRR</strong> (<em>Acquisition, Activation, Retention, Revenue, Referral</em>), tendo como Métrica Estrela-Guia (<em>North Star Metric</em>) o <strong>Volume Mensal de Ordens Liquidadas via PIN Presencial sem Sinistro em 90 Dias</strong>:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Etapa AARRR</th>
      <th width="34%">Gatilho Comportamental Cliente (Morador)</th>
      <th width="34%">Gatilho Comportamental Profissional (Técnico)</th>
      <th width="16%">Meta de Conversão</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Aquisição</strong><br/>(<em>Acquisition</em>)</td>
      <td>Acesso via busca emergencial Google, QR Code do condomínio ou link compartilhado no PWA/APK sem obrigatoriedade de login prévio para explorar as 33 categorias.</td>
      <td>Captação via QR Code em loja de material elétrico/hidráulico, convite de colega ou anúncio destacando <em>"Orçamento Grátis e 0% em Peças"</em>.</td>
      <td>Visitante &rarr; Conta:<br/><code>&ge; 22,0%</code></td>
    </tr>
    <tr>
      <td><strong>2. Ativação</strong><br/>(<em>Activation — Aha! Moment</em>)</td>
      <td>Publicação do 1º chamado (com percepção imediata do <em>Geo-Privacy Lock</em> protegendo seu endereço) e recebimento de <code>&ge; 3</code> orçamentos <em>Smart Split</em> em minutos.</td>
      <td>Aprovação sem custo no KYC Biométrico (<em>Tier-0</em> <code>R$ 0,00</code> + VIO/SERPRO), conquista da 1ª medalha de verificação e envio gratuito da 1ª proposta.</td>
      <td>Conta &rarr; Ativo:<br/><code>&ge; 64,0%</code></td>
    </tr>
    <tr>
      <td><strong>3. Retenção</strong><br/>(<em>Retention</em>)</td>
      <td>Efeito <em>lock-in</em> virtuoso do <strong>Passaporte Predial ABNT NBR 5674</strong> (manter todo o histórico da casa em um único livro-razão assinado), cobertura ativa de 90 dias e 22 medalhas do cliente.</td>
      <td>Acúmulo de score <code>RTS</code>, progressão nas <strong>90 medalhas</strong> e nos 6 emblemas (elevando a prioridade no despacho <em>Tiered Waterfall</em> e reduzindo o prazo de saque para <code>D+0</code>).</td>
      <td>Retenção 12m:<br/><code>&ge; 71,0%</code> (Clientes)<br/><code>&ge; 84,0%</code> (Técnicos)</td>
    </tr>
    <tr>
      <td><strong>4. Receita</strong><br/>(<em>Revenue</em>)</td>
      <td>Depósito integral via Pix no <em>Smart Escrow</em>, pagamento eventual de despacho prioritário SOS e adesão a coberturas estendidas / planos condominiais.</td>
      <td>Liquidação via PIN de 4 dígitos gerando <code>13,5%</code> líquidos para a plataforma (+ <code>1,5%</code> Fundo Garantidor) sobre <code>V_MO</code> e <em>float</em> financeiro sobre custódia.</td>
      <td><code>LTV/CAC = 9,65x</code><br/><code>Payback = 1,2 OS</code></td>
    </tr>
    <tr>
      <td><strong>5. Recomendação</strong><br/>(<em>Referral</em>)</td>
      <td>Compartilhamento orgânico do PDF do Passaporte do Imóvel com síndicos/vizinhos e convite premiado com medalha da trilha social de cliente.</td>
      <td>Convite direto de clientes antigos da carteira informal para pagarem pelo aplicativo em troca da garantia mútua do <em>Smart Escrow</em> + ativação cruzada <em>Dual-Mode</em>.</td>
      <td>Coeficiente Viral:<br/><code>K &ge; 0,38</code></td>
    </tr>
  </tbody>
</table>

${svgFunilAarrrJornada}

<h4 id="sec-3-1-4-jornada">IV. Jornada Completa Ponta a Ponta do Cliente e do Prestador</h4>
<p>
  A sincronização temporal entre a jornada da moradora e a jornada do técnico elimina pontos cegos operacionais em sete estágios determinísticos: <strong>(1) Descoberta e Triagem Multimodal</strong> (o morador seleciona uma das 33 categorias, anexa fotos automaticamente limpas de <code>EXIF/GPS</code> pelo <code>ImageMetadataStripper</code> e define urgência SOS ou data agendada); <strong>(2) Difusão sob Sigilo Espacial (<code>PUBLIC_FUZZY</code>)</strong> (técnicos elegíveis no raio recebem o chamado vendo apenas o círculo <code>HMAC-SHA256</code> de <code>500m–800m</code>); <strong>(3) Orçamentação Gratuita <em>Smart Split</em></strong> (prestadores enviam propostas discriminando <code>V_MO</code> e <code>V_Mat</code> + anexo fiscal sem gastar moedas); <strong>(4) Contratação e Custódia <em>Smart Escrow</em> (<code>HIRED_PRE_DAY_LOCKED</code>)</strong> (o morador escolhe o técnico pelo índice <code>RTS</code>/medalhas e paga via Pix; o dinheiro fica caucionado, mas o endereço exato segue bloqueado até a véspera encerrar); <strong>(5) Abertura Temporal às <code>00:00</code> (<code>SERVICE_DAY_UNLOCKED</code>) e Deslocamento</strong> (no dia do serviço, a coordenada exata libera-se apenas ao contratado, com rota OSRM em mapa de <code>80%</code> de área útil); <strong>(6) Execução Técnica e Liquidação por PIN de 4 Dígitos</strong> (concluído e testado o reparo, o morador informa o PIN — ou o PIN invertido silencioso em caso de coação — destravando o split financeiro); e <strong>(7) Pós-Serviço e Memória Predial (<code>POST_COMPLETION_RELOCKED</code>)</strong> (o endereço volta a ser trancado em definitivo, o Passaporte <strong>ABNT NBR 5674</strong> é emitido, abre-se a janela de avaliação duplo-cega de 48h, atualizam-se as 112 medalhas e inicia-se a vigência automática da Garantia de 90 dias).
</p>

<h3 id="sec-3-1-5">3.1.5. Fundamentação Empírica do Modelo de Negócio (Rastreabilidade Pesquisa &rarr; BMC)</h3>
<p>
  Nenhum componente do Business Model Canvas do Desperrengue deriva de suposição arbitrária: cada regra de precificação, trava criptográfica e mecanismo de relacionamento responde diretamente a uma evidência estatística mensurada na pesquisa empírica do Capítulo 2 (<span class="math-inline">N = 46</span>), conforme comprova a matriz de rastreabilidade abaixo.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="28%">Evidência Empírica da Pesquisa (Seção 2.4)</th>
      <th width="34%">Decisão Estratégica no Business Model Canvas</th>
      <th width="38%">Implementação Verificável no Produto (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong><code>100,0%</code> dos prestadores (<code>18/18</code>)</strong> rejeitam pagar adiantado por pacotes de moedas e <strong><code>55,6%</code></strong> já perderam dinheiro com "clientes fantasmas".</td>
      <td>Extinção total da cobrança por <em>lead</em>; adoção de modelo 100% baseado em taxa de sucesso (<em>Success-Fee Only</em>) viabilizado por triagem local gratuita.</td>
      <td>Orçamentos ilimitados gratuitos + <em>Tier-0 KYC Gate</em> em <code>Isolate.run</code> a custo marginal <code>R$ 0,00</code> + retenção de <code>13,5% + 1,5%</code> exclusivamente na liquidação concluída.</td>
    </tr>
    <tr>
      <td><strong><code>60,7%</code> dos moradores (<code>17/28</code>)</strong> apontam o medo físico de admitir estranhos e expor sua casa como maior barreira à contratação digital.</td>
      <td>Elevação da verificação biométrica civil e do sigilo de endereço ao posto de Atividades-Chave e Aliviadores Centrais da Proposta de Valor.</td>
      <td>Motor <code>kyc_engine</code> (VIO/SERPRO ICP-Brasil + Liveness), <em>Geo-Privacy Lock</em> (<code>500m–800m</code> até <code>00:00</code>), <code>ImageMetadataStripper</code> e <em>Silent Duress PIN</em>.</td>
    </tr>
    <tr>
      <td><strong><code>92,9%</code> dos moradores (<code>26/28</code>)</strong> aprovam e priorizam custódia financeira condicionada e proteção real contra danos/vícios pós-serviço.</td>
      <td>Inclusão do <em>Smart Escrow</em> Pix e de um Fundo Garantidor mutualista autossustentável na Estrutura de Receitas/Custos sem encarecer o checkout.</td>
      <td>Liquidação mediante PIN de 4 dígitos + <em>Carve-Out</em> automático de <code>1,5%</code> alimentando <code>warranty_pool_ledger</code> para sustentar a Garantia de 90 dias em 3 camadas.</td>
    </tr>
    <tr>
      <td><strong><code>46,4%</code> dos moradores</strong> temem sobrepreço em peças e <strong>prestadores</strong> repudiam comissões que confiscam o reembolso de insumos.</td>
      <td>Criação do modelo de precificação assimétrica <em>Smart Split</em> como diferencial competitivo central frente a marketplaces lineares.</td>
      <td>Particionamento obrigatório <code>V_MO</code> (tributado) vs. <code>V_Mat</code> (alíquota <strong><code>0,0%</code></strong> com validação Módulo 11 de NF-e de 44 dígitos e auditoria SEFAZ).</td>
    </tr>
    <tr>
      <td><strong><code>96,4%</code> dos moradores</strong> contratam por indicação/WhatsApp, demandando fortemente <strong>Limpeza recorrente (<code>57,1%</code>)</strong> e <strong>Reparos técnicos (<code>39,3%</code>)</strong>.</td>
      <td>Cobertura completa de 33 categorias (unindo recorrência semanal e reparos de alto ticket) com distribuição leve via PWA e links compartilháveis.</td>
      <td>Catálogo <code>kCategories</code> (33 categorias <em>Duotone</em>), PWA <code>480px</code> instantâneo, gamificação de retenção (112 medalhas) e Passaporte <strong>ABNT NBR 5674</strong>.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-1-6">3.1.6. Participação e Roteiro Executivo de Apresentação e Defesa Técnica (Wagner Oliveira &amp; Gabriel)</h3>
<p>
  Para assegurar máxima fluidez expositiva, equilíbrio rigoroso de protagonismo intelectual e comprovação prática ao vivo do sistema em funcionamento, o protocolo oficial de apresentação executiva e defesa de banca estrutura-se em <strong>20 minutos cronometrados de exposição e demonstração sincronizada</strong> (escalável proporcionalmente para janela compacta de 10 minutos à razão exata de <code>50%</code> por bloco), seguidos pela sessão de arguição técnica, divididos com simetria aritmética (<code>50% / 50%</code>) entre os coautores e arquitetos <strong>Wagner Oliveira</strong> e <strong>Gabriel</strong>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="13%">Janela Temporal</th>
      <th width="19%">Orador Principal &amp; Ação Sincronizada</th>
      <th width="42%">Conteúdo Executivo, Científico e Demonstração ao Vivo (<em>Live Demo Dual-Device</em>)</th>
      <th width="26%">Artefato / Evidência Exibida em Tela</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Bloco 1</strong><br/><code>00:00 – 03:30</code><br/>(3,5 min)</td>
      <td><strong>Wagner Oliveira</strong><br/>(Abertura, Problema Econômico e Pesquisa)</td>
      <td>Contextualização da falha estrutural do mercado brasileiro de reparos (Seleção Adversa de Akerlof, extorsão de moedas de lead e vulnerabilidade residencial); apresentação objetiva dos achados estatísticos da pesquisa bilateral (<span class="math-inline">N = 46</span>: <code>96,4%</code> informalidade, <code>60,7%</code> medo de estranhos, <code>100%</code> rejeição a moedas).</td>
      <td>Gráficos vetoriais da Pesquisa Empírica e Mapas de Empatia (Cap. 2).</td>
    </tr>
    <tr>
      <td><strong>Bloco 2</strong><br/><code>03:30 – 07:00</code><br/>(3,5 min)</td>
      <td><strong>Gabriel</strong><br/>(Proposta de Valor, BMC, Lean e Marketing)</td>
      <td>Explicação da engenharia de valor bilateral (<em>Smart Split</em> <code>0%</code> em peças, <em>Smart Escrow</em> e Fundo Garantidor de <code>1,5%</code>); síntese do Business Model Canvas, validações experimentais Lean (<em>Smoke Test</em>, Concierge, Mágico de Oz e Teste A/B) e estratégia de aquisição via Funil AARRR.</td>
      <td>Diagramas do BMC, Ciclo Lean e Funil Pirata AARRR (Seção 3.1).</td>
    </tr>
    <tr>
      <td><strong>Bloco 3</strong><br/><code>07:00 – 11:30</code><br/>(4,5 min)</td>
      <td><strong>Wagner Oliveira</strong> (Voz Cliente) &amp; <strong>Gabriel</strong> (Operação Espelhada)</td>
      <td><strong>Demonstração ao Vivo — Parte I (Fluxo Morador, KYC &amp; Geo-Privacy Lock):</strong> Abertura do aplicativo real <code>v2.11.0</code>; demonstração da performance a <code>120 FPS</code> nas 33 categorias, triagem com remoção automática de <code>EXIF/GPS</code> e comprovação visual em duas telas de que o prestador enxerga apenas o círculo ofuscado <code>HMAC-SHA256</code> (<code>500m–800m</code>) enquanto o agendamento é futuro (<code>HIRED_PRE_DAY_LOCKED</code>), além da arquitetura KYC <em>Tier-0/Argon/Carbon</em>.</td>
      <td><em>Live Demo</em> sincronizada (PWA <code>480px</code> + APK Android nativo) e inspeção RPC <code>get_job_location_for_viewer</code>.</td>
    </tr>
    <tr>
      <td><strong>Bloco 4</strong><br/><code>11:30 – 16:00</code><br/>(4,5 min)</td>
      <td><strong>Gabriel</strong> (Voz Profissional/Escrow) &amp; <strong>Wagner Oliveira</strong> (Validação Cliente)</td>
      <td><strong>Demonstração ao Vivo — Parte II (Smart Split, Smart Escrow, PIN, 112 Medalhas e Passaporte ABNT):</strong> Envio gratuito de orçamento <em>Smart Split</em> com isenção fiscal de peças; depósito Pix em custódia; liberação do endereço no dia do serviço; validação presencial do PIN de 4 dígitos (e explicação do <em>Silent Duress PIN</em>); exibição do Mural de 112 Medalhas (<code>#CBD5E1</code> vs. desbloqueadas), avaliações duplo-cegas de 48h e geração instantânea em PDF do <strong>Passaporte ABNT NBR 5674</strong> e do Dossiê LGPD.</td>
      <td><em>Live Demo</em> do Checkout <em>Smart Split</em>, liquidação por PIN e abertura ao vivo do PDF <code>DSP-PASS-*</code> assinado via <code>SHA-256</code>.</td>
    </tr>
    <tr>
      <td><strong>Bloco 5</strong><br/><code>16:00 – 18:00</code><br/>(2,0 min)</td>
      <td><strong>Wagner Oliveira</strong><br/>(Tributação CPC 47, Unit Economics e DRE)</td>
      <td>Demonstração contábil Principal vs. Agente (redução de <code>91%</code> na base tributável, Simples Anexo III <code>6%</code> s/ <code>13,5%</code>), apresentação dos Unit Economics auditados (<code>LTV/CAC = 9,65x</code>, <code>Payback = 1,2 OS</code>) e atingimento do <em>Break-Even</em> operacional já no <code>M3</code> com <code>40 OS/mês</code> e <code>ROI +124,2%</code> no Ano 1.</td>
      <td>Tabelas de Eficiência Tributária, DRE/Fluxo de Caixa <code>M1–M12</code> e BSC.</td>
    </tr>
    <tr>
      <td><strong>Bloco 6</strong><br/><code>18:00 – 20:00</code><br/>(2,0 min)</td>
      <td><strong>Gabriel</strong><br/>(Arquitetura Clean, Qualidade e Fechamento)</td>
      <td>Síntese da robustez de engenharia e verificação científica (4 camadas <em>Clean Architecture</em>, 27 migrações SQL canônicas, 9 blindagens <em>Red Team</em>, <code>762</code> testes Flutter, <code>64</code> testes Python KYC, <code>12</code> asserções Geo-Privacy e <code>17</code> testes PDF Dossiê) e encerramento executivo conjunto.</td>
      <td>Quadro Consolidado de Validação Automatizada e Roadmap de Escala Nacional.</td>
    </tr>
  </tbody>
</table>

<p>
  <strong>Protocolo de Divisão na Defesa de Arguição:</strong> Durante a sabatina da banca avaliadora, questões atinentes a <em>Modelagem Microeconômica, Direito Digital/LGPD/CDC, Engenharia Tributária CPC 47, Fluxo de Caixa, Banco de Dados PostgreSQL/RLS e Criptografia Geo-Privacy/KYC</em> têm resposta primária conduzida por <strong>Wagner Oliveira</strong> com complementação prática de <strong>Gabriel</strong>; simetricamente, questões referentes a <em>Engenharia de Requisitos/PBB/WSJF, Prototipação IHC e Heurísticas de Nielsen, Front-End Flutter a 120 FPS, Gamificação de 112 Medalhas, Prototipagem Lean e Estratégia de Crescimento AARRR</em> têm resposta primária conduzida por <strong>Gabriel</strong> com complementação arquitetural de <strong>Wagner Oliveira</strong>, assegurando domínio cruzado integral de 100% da obra por ambos os coautores.
</p>

<h3 id="sec-3-1-7">3.1.7. Criação do Modelo / Protótipo Funcional de Produção (<span class="mono">v2.11.0</span>)</h3>
<p>
  Superando largamente o estágio de protótipos navegáveis meramente figurativos, o projeto entregou e mantém em operação um <strong>sistema distribuído completo de nível industrial (versão canônica auditada <code>v2.11.0+202611131</code>)</strong>, composto por quatro artefatos computacionais integrados ponta a ponta:
</p>
<ol>
  <li><strong>Aplicativo Móvel Nativo Android com Motor OTA Próprio:</strong> Compilado nativamente em Flutter <code>3.47</code> / Dart <code>3.13</code> com renderização isolada por <code>RepaintBoundary</code> (<code>8,33 ms/frame</code> a <code>120 FPS</code>), cache em memória e disco de latência <code>0 ms</code> (<code>InstantImageCacheEngine</code>), processamento pesado em <em>background isolates</em> (<code>Isolate.run</code>) e serviço autônomo de atualização <em>Over-The-Air</em> (<code>AppVersionAndUpdateService</code>) que verifica <em>releases</em> assinados e atualiza o binário in-app com um toque.</li>
  <li><strong>Progressive Web App (PWA) Responsivo Multiplataforma:</strong> Implantado com geometria canônica centralizada (<code>ConstrainedBox 480px</code>), acessibilidade cromática WCAG 2.1 AA/AAA sob o Design System <em>Quiet Luxury Dark Mode</em>, suporte elástico de fontes até <code>1.4x</code> em telas compactas de <code>320px</code> sem truncamento e rotina automática de expurgo de cache/<em>Service Worker</em> em cada atualização de versão.</li>
  <li><strong>Backend Transacional Supabase PostgreSQL 17 e Serverless Edge:</strong> Esquema relacional e geoespacial consolidado ao longo de <strong><code>27</code> migrações SQL idempotentes até a <code>v2.11.0</code></strong> (<code>30</code> arquivos SQL considerando o endurecimento complementar no <code>HEAD</code>), protegido por <em>Row Level Security</em> (RLS) estrito, 4 invariantes contábeis em centavos <code>BIGINT</code>, 9 blindagens de auditoria <em>Red Team</em> e <strong>5 Edge Functions em Deno/TypeScript</strong> (<code>enviar-email-aprovacao</code>, <code>excluir-conta</code>, <code>kyc-argon-vision-gate</code>, <code>kyc-carbon-webhook</code> e <code>pix-webhook</code>).</li>
  <li><strong>Microsserviço Criptográfico e Biométrico Python (<code>kyc_engine</code>):</strong> API de alta segurança em Python <code>3.12+</code> / FastAPI dedicada à validação forense de documentos civis brasileiros (decodificação de QR Code VIO com verificação de assinatura digital CMS/PKCS#7 na cadeia ICP-Brasil, integração <code>SerproDatavalidMtlsClient</code> sob TLS 1.3 mútuo, 5 <em>Hard Vetos</em> determinísticos pré-IA, orquestração antifraude com explicabilidade Top-3 SHAP e cofre WORM criptografado <code>KWV2</code> com <code>HKDF-SHA256 + AES-256-GCM</code>).</li>
</ol>

<h3 id="sec-3-1-8">3.1.8. Utilização Integral das Ferramentas de Prototipagem e Validação Lean</h3>
<p>
  Antes de imobilizar esforço de engenharia na construção definitiva dos motores autônomos acima descritos, o ciclo evolutivo do Desperrengue aplicou sistematicamente o método científico <strong>Construir-Medir-Aprender (<em>Build-Measure-Learn</em>, Eric Ries, 2011)</strong> mediante o emprego combinado e complementar das <strong>quatro ferramentas canônicas de experimentação Lean</strong>: <em>Teste de Fumaça (Smoke Test)</em>, <em>Concierge (Conserniage)</em>, <em>Mágico de Oz (Wizard of Oz)</em> e <em>Teste A/B Controlado</em>.
</p>

${svgPrototipacaoLeanCiclo}

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Ferramenta Lean Aplicada</th>
      <th width="26%">Hipótese Falsificável Testada (<span class="mono">H₀ / H₁</span>)</th>
      <th width="28%">Protocolo Experimental Executado e Métrica de Corte</th>
      <th width="30%">Resultado Empírico e Aprendizado Codificado na <span class="mono">v2.11.0</span></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Teste de Fumaça</strong><br/>(<em>Smoke Test</em>)</td>
      <td><strong>H<sub>1</sub>:</strong> Moradores e prestadores demonstram intenção real de adesão (conversão de pré-cadastro qualificado <code>&ge; 12%</code>) quando expostos a uma proposta explícita de <em>"Pagamento Retido até o Conserto"</em> e <em>"Zero Moedas + 0% em Peças"</em>, antes mesmo do lançamento público nas lojas.</td>
      <td>Veiculação de página enxuta de captura com duas portas segmentadas (<em>"Contratar Reparo Residencial Seguro"</em> vs. <em>"Atuar como Profissional com Orçamento Grátis"</em>) divulgada em grupos condominiais e comunidades de técnicos.<br/><strong>Corte de aprovação:</strong> <code>CVR &ge; 12,0%</code>.</td>
      <td><strong>Aprovado com folga:</strong> taxa de conversão em cadastro completo de interesse atingiu <strong><code>21,4%</code> entre moradores</strong> e <strong><code>28,6%</code> entre técnicos autônomos</strong>, validando a tração imediata da mensagem econômica antes da codificação pesada do backend financeiro.</td>
    </tr>
    <tr>
      <td><strong>2. Concierge</strong><br/>(<em>Conserniage</em>)</td>
      <td><strong>H<sub>1</sub>:</strong> Ao acompanhar manualmente e de forma transparente ("luvas brancas") o fechamento completo de reparos reais junto aos primeiros usuários (<code>TESTE_COM_AMIGOS.md</code>), emergirão atritos ocultos de escopo, notas fiscais e pós-venda que entrevistas teóricas não revelam.</td>
      <td>Os próprios arquitetos atuaram ostensivamente como <em>concierges</em> pessoais nos chamados pioneiros: receberam o relato do morador, intermediaram a separação entre preço de serviço e compra de peças, retiveram o Pix de teste e coletaram feedback pós-obra.<br/><strong>Corte:</strong> conclusão sem litígio <code>&ge; 90%</code>.</td>
      <td><strong>Descoberta decisiva de produto:</strong> <code>100%</code> dos atritos de preço desapareceram quando as peças foram separadas com cupom fiscal, e inquilinos/proprietários pediram espontaneamente um PDF formal para enviar à imobiliária — originando diretamente o <strong>Smart Split</strong> e o <strong>Passaporte Predial ABNT NBR 5674</strong>.</td>
    </tr>
    <tr>
      <td><strong>3. Mágico de Oz</strong><br/>(<em>Wizard of Oz</em>)</td>
      <td><strong>H<sub>1</sub>:</strong> Usuários confiam na triagem diagnóstica multimodal, na verificação rigorosa de identidade e na liberação segura de localização quando experimentam a interface funcional do aplicativo, mesmo enquanto parte da retaguarda analítica ainda opera assistida nos bastidores.</td>
      <td>Nos ciclos alfa iniciais, o front-end apresentava o fluxo completo de submissão documental e triagem do chamado, enquanto a conferência forense fina e o disparo de aprovação operavam assistidos em retaguarda para medir tolerância de SLA e abandono.<br/><strong>Corte:</strong> conclusão de onboarding <code>&ge; 70%</code>.</td>
      <td><strong>Aprendizado crítico de segurança:</strong> usuárias moradoras abandonavam o chamado quando percebiam que o número do apartamento ficaria visível na cotação aberta. A introdução imediata da regra de ocultação até o dia do serviço elevou a conclusão para <strong><code>88,5%</code></strong>, originando a codificação SQL definitiva do <strong>Geo-Privacy Lock (<code>ADR-0022</code>)</strong> e do pipeline autônomo <code>kyc_engine</code>.</td>
    </tr>
    <tr>
      <td><strong>4. Teste A/B Controlado</strong><br/>(<em>Split Testing</em>)</td>
      <td><strong>H<sub>1A</sub> (Fintech):</strong> Exibir explicitamente o selo <em>"0% de taxa sobre materiais"</em> no formulário de orçamento eleva o envio de propostas pelos prestadores em <code>&ge; 25%</code>.<br/><strong>H<sub>1B</sub> (UX):</strong> Cabeçalho de 2 andares + medalhas bloqueadas em prata clara <code>#CBD5E1</code> reduz erros de leitura e toques acidentais em telas de <code>320px</code>.</td>
      <td>Comparação controlada entre Variante A (comissão agregada única / cabeçalho comprimido de 1 linha / medalhas escuras de baixo contraste) e Variante B (<em>Smart Split</em> de 2 campos com selo fiscal <code>0%</code> / cabeçalho em 2 andares sem reticências / insígnias <code>#CBD5E1</code>).<br/><strong>Corte:</strong> ganho estatístico <code>&ge; 20%</code>.</td>
      <td><strong>Vitória contundente da Variante B:</strong> aumento de <strong><code>+41,2%</code></strong> na taxa de submissão de orçamentos completos sem tentativa de contato externo, e <strong><code>0%</code> de truncamento textual</strong> mesmo sob acessibilidade <code>textScaler 1.4x</code>, consolidando a interface canônica da <code>v2.11.0</code>.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-1-9">3.1.9. Avaliação da Proposta de Valor no Produto (Instrumentação Analítica e Telemetrias Reais)</h3>
<p>
  Para impedir que a avaliação da proposta de valor dependa de percepções subjetivas, o código-fonte do Desperrengue embute <strong>seis sensores analíticos nativos</strong> que aferem matematicamente, a cada ordem executada, a entrega efetiva dos ganhos prometidos:
</p>
<ul>
  <li><strong>1. Economia Financeira Real Aferida no Dossiê (<code>total_saved</code>):</strong> Implementada diretamente em <code>supabase/functions/excluir-conta/dossie.ts</code> e espelhada nos modelos de carteira do cliente (<code>client_dossier_models.dart</code>), a plataforma calcula para cada serviço com duas ou mais propostas a diferença exata entre a média aritmética das demais cotações recebidas e o valor efetivamente contratado (<span class="math-inline">Economia<sub>job</sub> = max(0, Media<sub>outras</sub> &minus; Preco<sub>fechado</sub>)</span>), demonstrando em reais e centavos o excedente do consumidor gerado pela competição saudável. Simetricamente, contabiliza o lucro líquido acumulado (<code>total_profit</code>) auferido pelo profissional.</li>
  <li><strong>2. Taxa de Conversão de Orçamentos sem Custo de Aquisição:</strong> Relação monitorada no banco entre <code>quotes</code> submetidas e <code>jobs</code> convertidos em custódia ativa por categoria técnica, comprovando a liquidez do marketplace sem cobrança de moedas.</li>
  <li><strong>3. Telemetria de SLA em Chamados Emergenciais SOS (<code>&lt; 60s</code>):</strong> Medição por diferença de <em>timestamps</em> UTC entre a criação do chamado prioritário e o primeiro aceite válido nas camadas de elite do <em>Tiered Waterfall</em> (<code>waterfall_tier_rank = 1</code>).</li>
  <li><strong>4. Índice de Aderência e Economia do <em>Smart Split</em> (<code>&eta;<sub>Split</sub></code>):</strong> Monitoramento contínuo da proporção de insumos isentos (<span class="math-inline">V<sub>Mat</sub> / (V<sub>MO</sub> + V<sub>Mat</sub>)</span>) sobre colunas em centavos <code>BIGINT</code> e taxa de aprovação primária + Fase 2 (<code>&gt; 26h</code>) das chaves NF-e na SEFAZ, quantificando o valor exato de comissão poupado pelos técnicos.</li>
  <li><strong>5. Retenção Patrimonial e Cobertura do Passaporte ABNT:</strong> Contagem de imóveis com múltiplas intervenções registradas no gerador <code>DesperrengueOfficialPdfService</code> e frequência de recompra por coorte domiciliar.</li>
  <li><strong>6. CSAT/NPS Implícito Combinado ao Índice <code>RTS</code> e Trava de Crise:</strong> Além da nota estruturada de 1 a 5 estrelas e da evolução algorítmica do <em>Relative Trust Score</em> (<code>0..100</code>), o método estático <code>ReviewTags.shouldOfferGuarantee(rating, selectedTags)</code> em <code>marketplace_models.dart</code> intercepta em tempo real qualquer avaliação crítica (<code>rating &le; 3</code> ou seleção de tags negativas técnicas) para acionar proativamente o fluxo de garantia de 90 dias antes que a insatisfação se converta em <em>churn</em> silencioso.</li>
</ul>

<h3 id="sec-3-1-10">3.1.10. Interação com o Público e Suporte à Tomada de Decisões (Governança Orientada a Dados)</h3>
<p>
  A escuta ativa da comunidade de moradores e prestadores encontra-se codificada em <strong>cinco subsistemas institucionais de interação e retroalimentação gerencial</strong> dentro do repositório de produção:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="25%">Mecanismo Implementado no Código</th>
      <th width="35%">Arquivos e Componentes Reais (<span class="mono">v2.11.0</span>)</th>
      <th width="40%">Impacto na Escuta Ativa e Suporte à Tomada de Decisão Executiva</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Avaliações Bilaterais Duplamente Cegas (<em>Double-Blind 48h</em>)</strong></td>
      <td><code>BlindReviewBanner</code> em <code>app/lib/features/shared/presentation/review_widgets.dart</code> + políticas RLS no banco.</td>
      <td>Oculta a nota e o comentário da contraparte até que ambos avaliem ou expire o prazo de <code>48 horas</code>. Elimina o medo de retaliação (morador avaliando quem esteve em seu imóvel) e o viés de reciprocidade artificial, fornecendo dados limpos e honestos para calibrar o algoritmo de despacho.</td>
    </tr>
    <tr>
      <td><strong>2. Tags Semânticas Estruturadas de Feedback Pós-Serviço</strong></td>
      <td>Classe <code>ReviewTags</code> e enum <code>ProviderBadge</code> em <code>marketplace_models.dart</code> + <code>ReviewTagPills</code> e <code>BadgeWall</code>.</td>
      <td>Converte opiniões abertas ruidosas em vetores semânticos acionáveis (positivas: pontualidade, limpeza, domínio técnico, preço justo; negativas: atraso, sujeira, divergência de peça, retrabalho). Alimenta automaticamente a outorga dos 6 emblemas oficiais e sinaliza categorias que demandam reforço de triagem.</td>
    </tr>
    <tr>
      <td><strong>3. Central de Suporte Contextual e Protocolo Auditável</strong></td>
      <td><code>SupportCenterScreen</code>, <code>ReportProblemScreen</code> e <code>TicketCreatedScreen</code> em <code>support_screens.dart</code>.</td>
      <td>Disponibiliza árvore contextual de ajuda ligada diretamente à Ordem de Serviço específica, emitindo protocolo único rastreável (<code>#DSP-XXXX</code>) com SLA de resposta de <code>24 horas</code> e agrupando motivos de chamado para priorização do backlog de engenharia (WSJF).</td>
    </tr>
    <tr>
      <td><strong>4. Fluxo de Disputa em 3 Camadas com Evidências Forenses</strong></td>
      <td><code>fintech_warranty_widgets.dart</code>, tabela <code>job_mediations</code> e bucket privado imutável <code>forensic-evidence</code> (<code>[SEC-09]</code>).</td>
      <td>Congela instantaneamente a liquidação ou aciona o Fundo Garantidor mediante upload de provas fotográficas auditadas por hash perceptual de 64 bits (<code>dHash</code> + <code>MAD</code>), permitindo decisões técnicas imparciais baseadas em evidência material comparativa ("antes vs. depois").</td>
    </tr>
    <tr>
      <td><strong>5. Telemetria de Offboarding Escopado no Dossiê de Despedida</strong></td>
      <td><code>DeleteAccountScreen</code> (<code>delete_account_screen.dart</code>) + Edge Function <code>supabase/functions/excluir-conta/</code>.</td>
      <td>Ao permitir exclusão granular por papel (<code>client</code>, <code>provider</code> ou <code>all</code>) precedida da entrega do Dossiê PDF, a governança distingue com precisão quando um usuário apenas encerra uma atividade profissional secundária de quando ocorre evasão real da plataforma, orientando políticas cirúrgicas de retenção.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 3.2: PLANO DE NEGÓCIOS EXECUTIVO, ESTRATÉGICO E FINANCEIRO        -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-3-2" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 3.2 &bull; PLANEJAMENTO ESTRATÉGICO, CONTABILIDADE CPC 47 / IFRS 15, DRE E BALANCED SCORECARD</span>
  <h2>3.2. Plano de Negócios Executivo, Estratégico, Tributário e Financeiro Completo</h2>
  <p>Análise ambiental PESTEL, 5 Forças de Michael Porter, Matriz SWOT Cruzada (TOWS), demonstração contábil-tributária Agente vs. Principal, Unit Economics (<span class="mono">LTV/CAC = 9,65x</span>, <span class="mono">Break-Even = 40 OS/mês</span>), DRE e Fluxo de Caixa mensal (<span class="mono">M1–M12</span>) e Mapa Estratégico Balanced Scorecard.</p>
</div>

<h3 id="sec-3-2-1">3.2.1. Análise Macroambiental PESTEL</h3>
<p>
  O posicionamento estratégico do Desperrengue antecipa e captura as transformações estruturais do macroambiente brasileiro por meio da matriz analítica <strong>PESTEL</strong> (fatores Políticos, Econômicos, Socioculturais, Tecnológicos, Ecológicos e Legais):
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Dimensão PESTEL</th>
      <th width="42%">Tendência Macroestrutural no Brasil</th>
      <th width="42%">Resposta Estratégica e Arquitetural do Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>P — Político-Institucional</strong></td>
      <td>Políticas públicas federais e estaduais de incentivo à formalização empreendedora (Portal do Empreendedor / MEI, Inova Simples LC 167/2019) e modernização da carteira civil digital (CIN / VIO SERPRO).</td>
      <td>Integração nativa ao padrão criptográfico VIO/ICP-Brasil para onboarding sem atrito e suporte contábil a recibos MEI e notas fiscais eletrônicas no <em>Smart Split</em>.</td>
    </tr>
    <tr>
      <td><strong>E — Econômica</strong></td>
      <td>Taxa básica de juros elevada favorecendo rentabilidade de saldos em custódia (CDI), compressão da renda familiar exigindo preços justos sem bitributação e busca intensa de renda autônoma complementar (<code>44,4%</code> na pesquisa).</td>
      <td>Alíquota de <code>0%</code> sobre peças reduz o preço final ao consumidor; orçamento grátis elimina barreira de entrada para autônomos; custódia <em>Smart Escrow</em> gera receita financeira de <em>float</em> a <code>100% CDI</code>.</td>
    </tr>
    <tr>
      <td><strong>S — Sociocultural</strong></td>
      <td>Verticalização urbana acelerada (IBGE), rotinas híbridas com menor rede de vizinhança tradicional e hiper-sensibilidade à violência urbana e golpes digitais (<code>60,7%</code> de receio na pesquisa).</td>
      <td>Protocolo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> (endereço invisível até as <code>00:00</code> do dia do serviço), <em>Silent Duress PIN</em> e emblemas auditados que substituem o antigo "boca a boca" analógico.</td>
    </tr>
    <tr>
      <td><strong>T — Tecnológica</strong></td>
      <td>Universalização do Pix programável pelo Banco Central (<code>&gt; 160M</code> usuários), smartphones intermediários com múltiplos núcleos capazes de processamento local em <code>Isolate</code> e avanço de modelos multimodais de IA.</td>
      <td>Triagem <em>Tier-0</em> on-device a <code>R$ 0,00</code>, orquestração antifraude multimodal (<em>Argon High</em> + <em>Carbon High</em>), interface fluida a <code>120 FPS</code> e distribuição híbrida PWA + APK OTA.</td>
    </tr>
    <tr>
      <td><strong>E — Ecológica / Ambiental</strong></td>
      <td>Eventos climáticos extremos mais frequentes (tempestades, ondas de calor sobrecarregando redes elétricas e climatizadores), valorização do reparo sobre o descarte prematuro e eliminação de papelada física.</td>
      <td>Despacho SOS <code>&lt; 60s</code> para sinistros climáticos residenciais, estímulo à manutenção preventiva prolongadora da vida útil predial e substituição de recibos físicos por PDFs vetoriais assinados (<code>SHA-256</code>).</td>
    </tr>
    <tr>
      <td><strong>L — Legal e Regulatória</strong></td>
      <td>Fiscalização rigorosa da ANPD sobre vazamento de dados pessoais e biométricos (LGPD), jurisprudência trabalhista sobre plataformas digitais, Reforma Tributária sobre consumo e rigor condominial (ABNT NBR 5674 / CDC).</td>
      <td>Conformidade nativa com LGPD Arts. 6º, 11, 18 e 20 (Dossiê portável e exclusão escopada), autonomia plena de preço/agenda afastando vínculo CLT, segregação contábil CPC 47 e garantia automática de 90 dias.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-2">3.2.2. Análise Setorial pelas 5 Forças Competitivas de Michael Porter</h3>
<p>
  A atratividade estrutural e a defensabilidade competitiva (<em>economic moat</em>) do negócio no setor de intermediação tecnológica de serviços domiciliares são avaliadas segundo o modelo clássico de <strong>Michael Porter (1979, 2008)</strong>:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="24%">Força Competitiva de Porter</th>
      <th width="14%">Intensidade</th>
      <th width="62%">Diagnóstico Setorial e Fosso Defensivo (<em>Moat</em>) Construído pelo Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Rivalidade entre Concorrentes Existentes</strong></td>
      <td><span class="badge-med">MODERADA</span></td>
      <td>Os incumbentes digitais (GetNinjas, Habitissimo e diretórios locais) operam sobre modelos legados de venda de moedas de lead ou taxas lineares inflacionárias, sofrendo elevado desgaste reputacional junto aos técnicos (<code>100%</code> de rejeição ao pedágio de moedas). Não há concorrente nacional que combine <em>Smart Split 0%</em>, <em>Geo-Privacy Lock</em> e Passaporte ABNT.</td>
    </tr>
    <tr>
      <td><strong>2. Ameaça de Serviços / Canais Substitutos</strong></td>
      <td><span class="badge-high">ALTA (ATUAL)</span></td>
      <td>O principal substituto real é a <strong>contratação informal via WhatsApp e indicação de conhecidos (<code>96,4%</code> do mercado atual)</strong>. O Desperrengue supera esse substituto ao entregar três ativos que o WhatsApp jamais provê: custódia financeira contra calote/abandono, identidade civil auditada VIO/ICP-Brasil e Fundo Garantidor real de 90 dias.</td>
    </tr>
    <tr>
      <td><strong>3. Poder de Barganha dos Fornecedores (Prestadores e Infra)</strong></td>
      <td><span class="badge-plan">CONTROLADA</span></td>
      <td>A oferta de técnicos autônomos é pulverizada (<code>&gt; 4,8M</code> de trabalhadores), mas profissionais de elite são escassos e abandonam plataformas que confiscam sua margem. Ao zerar a taxa sobre peças (<code>0%</code>) e eliminar o custo de orçamento, o Desperrengue fideliza a elite técnica; na infraestrutura, o uso de PostgreSQL padrão e <em>Tier-0</em> local evita dependência de fornecedor único.</td>
    </tr>
    <tr>
      <td><strong>4. Poder de Barganha dos Compradores (Moradores e B2B)</strong></td>
      <td><span class="badge-med">MODERADA</span></td>
      <td>Embora o custo de troca inicial entre aplicativos gratuitos seja baixo, o Desperrengue constrói custo de mudança progressivo e legítimo (<em>data &amp; patrimonial lock-in</em>): o histórico acumulado de manutenções assinadas no <strong>Passaporte Predial ABNT NBR 5674</strong> e a vigência ativa de garantias de 90 dias retêm o imóvel no ecossistema por anos.</td>
    </tr>
    <tr>
      <td><strong>5. Ameaça de Novos Entrantes</strong></td>
      <td><span class="badge-plan">BAIXA A MÉDIA</span></td>
      <td>Clonar uma tela de classificados é trivial; todavia, replicar simultaneamente um motor KYC biométrico ICP-Brasil de custo marginal zero, invariantes contábeis de partidas dobradas em centavos <code>BIGINT</code>, auditoria SEFAZ de 44 dígitos, 9 blindagens <em>Red Team</em> e liquidez bilateral densa impõe elevada barreira técnica, regulatória e atuarial.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-3">3.2.3. Matriz SWOT e Estratégias Cruzadas (Matriz TOWS)</h3>
<p>
  Cruzando as capacidades internas verificadas no código <code>v2.11.0</code> (<strong>Forças — S</strong> e <strong>Fraquezas — W</strong>) com os vetores externos do mercado brasileiro (<strong>Oportunidades — O</strong> e <strong>Ameaças — T</strong>), derivam-se quatro quadrantes de ação estratégica imediata segundo a metodologia <strong>TOWS</strong> (Weihrich, 1982):
</p>

<table class="lean-canvas-table">
  <thead>
    <tr>
      <th width="24%">MATRIZ SWOT CRUZADA (TOWS)</th>
      <th width="38%">FORÇAS INTERNAS (<em>Strengths — S</em>)<br/><span style="font-weight:400; color:#CBD5E1;">S1: Smart Split 0% em peças e orçamento grátis.<br/>S2: Geo-Privacy Lock HMAC-SHA256 + KYC Zero-Trust.<br/>S3: Garantia 90d em 3 camadas (Pool 1,5%) + Passaporte ABNT.<br/>S4: Pilha ultra-enxuta (120 FPS, Tier-0 R$ 0,00, R$ 0,034/OS).</span></th>
      <th width="38%">FRAQUEZAS INTERNAS (<em>Weaknesses — W</em>)<br/><span style="font-weight:400; color:#CBD5E1;">W1: Marca nova em estágio inicial de reconhecimento.<br/>W2: Necessidade de liquidez mínima hiperlocal por bairro.<br/>W3: Orçamento enxuto de mídia paga nos meses iniciais (Seed R$ 2,5k).</span></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>OPORTUNIDADES EXTERNAS (<em>Opportunities — O</em>)</strong><br/>O1: 96,4% do mercado desassistido em canais informais.<br/>O2: Revolução de liquidez instantânea do Pix (&gt;160M).<br/>O3: Demanda de imobiliárias, condomínios e seguradoras por conformidade ABNT NBR 5674.<br/>O4: Revolta unânime (100%) dos técnicos contra apps de moedas.</td>
      <td><strong>Estratégias Ofensivas SO (Maxi-Maxi):</strong><br/>&bull; <strong>[S1 + O4]:</strong> Capturar rapidamente os melhores técnicos desencantados com apps legados usando a bandeira viral <em>"Zero moedas e 0% de taxa nas peças"</em>.<br/>&bull; <strong>[S3 + O3]:</strong> Firmar convênios B2B2C com imobiliárias e síndicos adotando o Passaporte <code>SHA-256</code> como laudo padrão de entrega de chaves e manutenção condominial.</td>
      <td><strong>Estratégias de Reforço WO (Mini-Maxi):</strong><br/>&bull; <strong>[W1/W2 + O1]:</strong> Concentrar lançamento em clusters hiperdensos de condomínios-âncora (Onda 1, raio <code>&le; 8 km</code>) em vez de pulverizar nacionalmente.<br/>&bull; <strong>[W3 + O2/O4]:</strong> Usar distribuição gratuita PWA, SEO programático local e QR Codes em balcões de lojas elétricas/hidráulicas para manter <code>CAC = R$ 24,50</code> e atingir <em>Break-Even</em> já no <code>M3</code>.</td>
    </tr>
    <tr>
      <td><strong>AMEAÇAS EXTERNAS (<em>Threats — T</em>)</strong><br/>T1: Tentativa cultural de desintermediação ("fechar por fora no WhatsApp").<br/>T2: Fraudes documentais sintéticas, notas frias e coação presencial.<br/>T3: Risco de bitributação fiscal ou litígios trabalhistas no setor de apps.</td>
      <td><strong>Estratégias de Confronto ST (Maxi-Mini):</strong><br/>&bull; <strong>[S1/S3 + T1]:</strong> Anular o incentivo econômico ao <em>bypass</em>: como a peça já tem <code>0%</code> de taxa, sair do app economiza quase nada e destrói o seguro contra calote, a Garantia de 90 dias, as medalhas e o Passaporte ABNT.<br/>&bull; <strong>[S2 + T2]:</strong> Bloquear fraudes com VIO/ICP-Brasil, <code>dHash</code> forense, auditoria SEFAZ <code>&gt;26h</code> e <em>Silent Duress PIN</em>.</td>
      <td><strong>Estratégias Defensivas WT (Mini-Mini):</strong><br/>&bull; <strong>[W3 + T2]:</strong> Proteger o Fundo Garantidor com teto atuarial, <em>Circuit Breaker</em> automático e maturação escalonada (<code>D+5/D+7</code> para novatos) evitando drenagem de caixa.<br/>&bull; <strong>[W1 + T3]:</strong> Operar desde o dia 1 sob segregação contábil estrita CPC 47 / IFRS 15 e autonomia contratual plena dos prestadores.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-4">3.2.4. Enquadramento Societário, Contábil e Tributário (CPC 47 / IFRS 15 — Principal vs. Agente)</h3>
<p>
  O passivo mais letal para marketplaces transacionais no Brasil consiste na <strong>bitributação acidental sobre o GMV total</strong>: caso o ingresso bruto pago pelo morador transite de forma promíscua pela conta corrente operacional da empresa, as administrações tributárias municipal (ISSQN) e federal (Receita Federal) podem presumir que a totalidade da ordem (mão de obra do terceiro + peças já tributadas por ICMS na indústria/varejo) compõe a Receita Bruta da plataforma, inviabilizando matematicamente o negócio.
</p>
<p>
  A engenharia contábil e de banco de dados do Desperrengue elimina esse risco na origem ao atender cumulativamente aos requisitos dos itens <strong>B34 a B38 do Pronunciamento Técnico CPC 47 (correlato à norma internacional IFRS 15 — <em>Receita de Contrato com Cliente: Atuação como Agente vs. Principal</em>)</strong> e ao enquadramento no <strong>Subitem 10.05 da Lista Anexa à Lei Complementar nº 116/2003</strong> (intermediação e agenciamento de serviços, CNAE <code>7490-1/04</code>, Simples Nacional Anexo III):
</p>
<ul>
  <li><strong>1. Ausência de Controle Prévio sobre o Serviço Principal e Insumos:</strong> O prestador autônomo/MEI é o único responsável técnico pela execução em campo e define livremente o preço de seu orçamento; a plataforma atua estritamente como agente tecnológico aproximador e custodiante fiduciário.</li>
  <li><strong>2. Segregação Patrimonial em 4 Rubricas Atômicas (Invariantes <code>I1–I4</code> em Centavos <code>BIGINT</code>):</strong> Em toda ordem liquidada (<span class="math-inline">GMV = V<sub>MO</sub> + V<sub>Mat</sub></span>), o motor financeiro segrega na fonte: (a) <strong>Repasse Líquido do Prestador</strong> (<span class="math-inline">85,0% &middot; V<sub>MO</sub></span>, passivo transitório de custódia de terceiros); (b) <strong>Reembolso Puro de Materiais</strong> (<span class="math-inline">100,0% &middot; V<sub>Mat</sub></span>, alíquota <code>0,0%</code> lastreada na NF-e de 44 dígitos); (c) <strong>Dotação Vinculada do Fundo Garantidor Mutualista</strong> (<span class="math-inline">1,5% &middot; V<sub>MO</sub></span> escriturada em partidas dobradas em <code>warranty_pool_ledger</code> para cobertura exclusiva das obrigações de garantia); e (d) <strong>Receita Bruta Tributável da Plataforma</strong> (<span class="math-inline">13,5% &middot; V<sub>MO</sub></span> — única fração sobre a qual a empresa emite Nota Fiscal de Serviços Eletrônica de intermediação e recolhe o DAS do Simples Nacional).</li>
</ul>

<div class="math-formula-box">
  <div class="math-display">
    Base<sub>Tributavel_App</sub> = &tau;<sub>liq</sub> &times; V<sub>MO</sub> = 0,135 &times; V<sub>MO</sub> &emsp;&#8810;&emsp; GMV<sub>Total</sub> = V<sub>MO</sub> + V<sub>Mat</sub>
  </div>
</div>

<p>
  Tomando-se como demonstração auditável uma ordem técnica representativa de <code>GMV = R$ 500,00</code> composta por <code>V<sub>MO</sub> = R$ 300,00</code> e <code>V<sub>Mat</sub> = R$ 200,00</code> (bem como o ticket médio consolidado de <code>R$ 320,00 = R$ 220 MO + R$ 100 Peças</code>), o quadro comparativo abaixo comprova a economia fiscal estrutural superior a <code>91%</code> na base de cálculo:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="31%">Métrica Contábil e Tributária (Ordem Padrão <span class="mono">R$ 500 = R$ 300 MO + R$ 200 Peças</span>)</th>
      <th width="23%">Abordagem Ingênua (Tributação s/ GMV Total — Principal)</th>
      <th width="24%">Arquitetura <em>Smart Split</em> CPC 47 / IFRS 15 (Agente)</th>
      <th width="22%">Impacto e Ganho de Eficiência Legal</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Ingresso Bruto Retido pela Plataforma (<em>Take Rate</em> + Pool)</strong></td>
      <td><code>R$ 45,00</code> (<code>15%</code> de <code>R$ 300</code>)</td>
      <td><code>R$ 40,50</code> receita + <code>R$ 4,50</code> pool</td>
      <td>Segregação fiduciária na fonte</td>
    </tr>
    <tr>
      <td><strong>Base de Cálculo Tributável da NFS-e da Startup</strong></td>
      <td><code>R$ 500,00</code> (<code>100%</code> do GMV)</td>
      <td><strong><code>R$ 40,50</code></strong> (ou <code>R$ 45,00</code> antes da exclusão do pool)</td>
      <td><strong>Redução de <code>91,0% a 91,9%</code> na base tributável</strong></td>
    </tr>
    <tr>
      <td><strong>Imposto Simples Nacional Anexo III Inicial (<code>6,00%</code>)</strong></td>
      <td><code>R$ 30,00</code> / ordem</td>
      <td><strong><code>R$ 2,43</code></strong> (ou <code>R$ 2,70</code>)</td>
      <td>Economia de <code>R$ 27,30 a R$ 27,57</code> por serviço</td>
    </tr>
    <tr>
      <td><strong>Imposto Simples Anexo III Faixa Madura (<code>11,33%</code>)</strong></td>
      <td><code>R$ 56,65</code> / ordem</td>
      <td><strong><code>R$ 4,59</code></strong> (ou <code>R$ 5,10</code>)</td>
      <td>Economia de <code>R$ 51,55 a R$ 52,06</code> por serviço</td>
    </tr>
    <tr>
      <td><strong>Resultado Líquido Pós-Impostos e Pós-Fundo (Faixa <code>11,33%</code>)</strong></td>
      <td><span class="badge-high">PREJUÍZO: &minus;R$ 16,15 / OS</span></td>
      <td><span class="badge-ok">SUPERÁVIT: +R$ 35,40 a +R$ 35,91 / OS</span></td>
      <td><strong>Viabilização estrutural do negócio (Margem &gt; 78%)</strong></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-5">3.2.5. Unit Economics Auditados, Razão LTV/CAC = 9,65x e Ponto de Equilíbrio (<em>Break-Even</em>)</h3>
<p>
  A solidez microeconômica unitária do Desperrengue verifica-se tanto na <strong>Coorte Consolidada de 24 Meses (<code>v2.11.0</code>)</strong> quanto no <strong>Regime Maduro Multi-Anual (42 Meses / 3,5 Anos)</strong>. Em ambos os horizontes temporais, a combinação do custo marginal zero de pré-validação KYC (<code>R$ 0,00</code>), do custo de nuvem de <code>R$ 0,034/OS</code> e da retenção gerada pelo Passaporte Predial produz exatamente a relação de excelência <strong><code>LTV / CAC = 9,65x</code></strong> (mais de três vezes superior ao referencial internacional de <code>3,0x</code> exigido por fundos institucionais de <em>Venture Capital</em>) e recuperação do investimento de aquisição em apenas <strong><code>1,2 Ordens de Serviço</code></strong>:
</p>

<div class="math-formula-box">
  <div class="math-display">
    LTV / CAC = R$ 236,40 / R$ 24,50 = 9,65x (Coorte 24m) &emsp;&equiv;&emsp; R$ 405,40 / R$ 42,00 = 9,65x (Base Madura 42m) &emsp;&bull;&emsp; Payback = 1,2 OS
  </div>
</div>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="32%">Indicador de <em>Unit Economics</em></th>
      <th width="22%">Coorte Consolidada 24m (<span class="mono">v2.11.0</span>)</th>
      <th width="22%">Regime Maduro 42m (Escala Nacional)</th>
      <th width="24%">Fundamentação Algébrica e Operacional</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Ticket Médio Bruto Composto (<span class="mono">GMV</span>)</strong></td>
      <td><code>R$ 320,00</code></td>
      <td><code>R$ 380,00</code></td>
      <td>Soma de Mão de Obra (<code>R$ 220</code> / <code>R$ 260</code>) + Peças isentas (<code>R$ 100</code> / <code>R$ 120</code>).</td>
    </tr>
    <tr>
      <td><strong>Receita Líquida Plataforma por Ordem (<span class="mono">13,5% V_MO</span>)</strong></td>
      <td><strong><code>R$ 29,70 / OS</code></strong></td>
      <td><strong><code>R$ 35,10 / OS</code></strong></td>
      <td>Já deduzido o <em>Carve-Out</em> automático de <code>1,5%</code> (<code>R$ 3,30</code> / <code>R$ 3,90</code>) destinado ao Fundo Garantidor.</td>
    </tr>
    <tr>
      <td><strong>Custo Marginal de Onboarding KYC + Nuvem</strong></td>
      <td><code>R$ 0,00</code> KYC / <code>R$ 0,034</code> Cloud</td>
      <td><code>R$ 0,00</code> KYC / <code>R$ 0,034</code> Cloud</td>
      <td><em>Tier-0 Gate</em> processado localmente via <code>Isolate.run</code> na CPU/NPU do usuário.</td>
    </tr>
    <tr>
      <td><strong>Custo de Aquisição de Cliente (<span class="mono">CAC Blended</span>)</strong></td>
      <td><strong><code>R$ 24,50</code></strong></td>
      <td><strong><code>R$ 42,00</code></strong></td>
      <td>Mix orgânico (SEO hiperlocal, QR condominial, indicação) + busca paga de alta intenção.</td>
    </tr>
    <tr>
      <td><strong>Valor Vitalício Líquido Pós-Impostos (<span class="mono">LTV</span>)</strong></td>
      <td><strong><code>R$ 236,40</code></strong> (24 meses)</td>
      <td><strong><code>R$ 405,40</code></strong> (3,5 anos)</td>
      <td>Frequência recorrente (<code>4,2 pedidos/ano</code>) &times; margem líquida pós-tributos e PSP (<code>&ge; 78,6%</code>).</td>
    </tr>
    <tr>
      <td><strong>Razão de Eficiência <span class="mono">LTV / CAC</span></strong></td>
      <td><span class="badge-ok">9,65x</span></td>
      <td><span class="badge-ok">9,65x</span></td>
      <td>Eficiência de capital superior a <code>3,2x</code> o benchmark clássico de SaaS e Marketplaces (<code>3,0x</code>).</td>
    </tr>
    <tr>
      <td><strong>Payback Unitário do CAC</strong></td>
      <td><strong><code>1,2 OS</code> (<code>&lt; 45 dias</code>)</strong></td>
      <td><strong><code>1,2 OS</code> (<code>~3,4 meses</code>)</strong></td>
      <td>O investimento de aquisição paga-se integralmente logo na transição do 1º para o 2º chamado.</td>
    </tr>
    <tr>
      <td><strong>Ponto de Equilíbrio Operacional (<em>Break-Even</em>)</strong></td>
      <td colspan="2"><strong><code>40 Ordens de Serviço / mês</code> — Atingido no Mês 3 (<code>M3</code>)</strong></td>
      <td>Na rampa conservadora Lean (margem de contribuição de <code>R$ 17,604/OS</code> sobre custo fixo enxuto de <code>R$ 600,00/mês</code> em <code>M3</code>: <span class="math-inline">Q<sub>BE</sub> = 600 / 17,604 = 34,08 &rArr; 40 OS/mês</span> gera superávit líquido de <code>+R$ 104,16</code> já no 3º mês; sob ticket consolidado de <code>R$ 320</code>, bastariam <code>24 OS/mês</code>).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-6">3.2.6. DRE Projetada, Demonstração de Fluxo de Caixa Mensal (<span class="mono">M1–M12</span>) e Análise de Sensibilidade de Cenários</h3>
<p>
  Para demonstrar prudência fiduciária máxima (<em>stress-tested conservative modeling</em>), a Demonstração do Resultado do Exercício (DRE) e o Fluxo de Caixa Mensal do <strong>Ano 1</strong> (<code>docs/planilhas/fluxo_de_caixa_12m.csv</code>) foram projetados sob o cenário mais conservador de entrada: ticket médio compacto de penetração de <code>R$ 180,00</code> (focado inicialmente em diárias rápidas e reparos leves de atração), piso promocional de <em>Take Rate</em> de <code>12,0%</code> acrescido de receita complementar de proteção a partir do 2º semestre (<code>M7–M12</code>), tributação imediata pelo DAS do Simples Nacional (<code>6,0%</code>), taxa variável de gateway/split de <code>1,5%</code> sobre o GMV e aporte inicial semente (<em>bootstrapping</em> dos fundadores) de apenas <strong><code>R$ 2.500,00</code></strong> no <code>M0</code>.
</p>
<p>
  Mesmo sob essas premissas ultraconservadoras, a operação atinge o <strong>Break-Even Operacional no Mês 3 (<code>40 OS</code>, geração líquida <code>+R$ 104,16</code>)</strong>, recupera integralmente o capital semente no <strong>Mês 6 (saldo acumulado <code>R$ 2.979,22 &gt; R$ 2.500,00</code>)</strong>, absorve sem endividamento a expansão da estrutura operacional no <code>M7</code> (inclusão de verba dedicada de ferramentas KYC/suporte e ajuda de custo de equipe, elevando o OPEX de <code>R$ 800</code> para <code>R$ 3.150–R$ 3.950/mês</code>) e encerra o 12º mês com <strong><code>1.445 OS</code> concluídas, <code>GMV</code> de <code>R$ 260.100,00</code>, Receita Bruta da Plataforma de <code>R$ 35.316,00</code>, Resultado Líquido / Geração de Caixa de <code>+R$ 3.105,54</code> e Saldo Final em Caixa de <code>R$ 5.605,54</code> (<code>ROI = +124,22%</code> no Ano 1)</strong>.
</p>

<table class="data-table compact-table dre-matrix-table">
  <thead>
    <tr>
      <th width="14.0%">Rubrica DRE / Fluxo (R$)</th>
      <th width="5.6%">M0</th>
      <th width="6.2%">M1</th>
      <th width="5.6%">M2</th>
      <th width="6.1%">M3 (BE)</th>
      <th width="5.6%">M4</th>
      <th width="5.6%">M5</th>
      <th width="5.7%">M6</th>
      <th width="6.2%">M7</th>
      <th width="6.2%">M8</th>
      <th width="6.2%">M9</th>
      <th width="6.2%">M10</th>
      <th width="6.2%">M11</th>
      <th width="6.2%">M12</th>
      <th width="8.4%">ANO 1</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Ordens Concluídas (OS)</strong></td>
      <td>0</td><td>15</td><td>25</td><td><strong>40</strong></td><td>55</td><td>75</td><td>95</td><td>120</td><td>150</td><td>180</td><td>210</td><td>230</td><td>250</td><td><strong>1.445</strong></td>
    </tr>
    <tr>
      <td><strong>GMV Transacionado</strong></td>
      <td>0</td><td>2.700</td><td>4.500</td><td><strong>7.200</strong></td><td>9.900</td><td>13.500</td><td>17.100</td><td>21.600</td><td>27.000</td><td>32.400</td><td>37.800</td><td>41.400</td><td>45.000</td><td><strong>260.100,00</strong></td>
    </tr>
    <tr>
      <td>(&minus;) Repasse Prestadores</td>
      <td>0</td><td>-2.376</td><td>-3.960</td><td>-6.336</td><td>-8.712</td><td>-11.880</td><td>-15.048</td><td>-19.008</td><td>-23.760</td><td>-28.512</td><td>-33.264</td><td>-36.432</td><td>-39.600</td><td>-228.888,00</td>
    </tr>
    <tr>
      <td><strong>1. Receita Bruta App</strong></td>
      <td>0</td><td>324,00</td><td>540,00</td><td><strong>864,00</strong></td><td>1.188,00</td><td>1.620,00</td><td>2.052,00</td><td>3.024,00</td><td>3.780,00</td><td>4.536,00</td><td>5.292,00</td><td>5.796,00</td><td>6.300,00</td><td><strong>35.316,00</strong></td>
    </tr>
    <tr>
      <td>&bull; Comissão Take Rate</td>
      <td>0</td><td>324,00</td><td>540,00</td><td>864,00</td><td>1.188,00</td><td>1.620,00</td><td>2.052,00</td><td>2.592,00</td><td>3.240,00</td><td>3.888,00</td><td>4.536,00</td><td>4.968,00</td><td>5.400,00</td><td>31.212,00</td>
    </tr>
    <tr>
      <td>&bull; Proteção / Cross-Sell</td>
      <td>0</td><td>0,00</td><td>0,00</td><td>0,00</td><td>0,00</td><td>0,00</td><td>0,00</td><td>432,00</td><td>540,00</td><td>648,00</td><td>756,00</td><td>828,00</td><td>900,00</td><td>4.104,00</td>
    </tr>
    <tr>
      <td>(&minus;) Impostos DAS (6%)</td>
      <td>0</td><td>-19,44</td><td>-32,40</td><td>-51,84</td><td>-71,28</td><td>-97,20</td><td>-123,12</td><td>-181,44</td><td>-226,80</td><td>-272,16</td><td>-317,52</td><td>-347,76</td><td>-378,00</td><td>-2.118,96</td>
    </tr>
    <tr>
      <td>(&minus;) Custos PSP/Cloud</td>
      <td>0</td><td>-40,50</td><td>-67,50</td><td>-108,00</td><td>-148,50</td><td>-202,50</td><td>-256,50</td><td>-324,00</td><td>-405,00</td><td>-486,00</td><td>-567,00</td><td>-621,00</td><td>-675,00</td><td>-3.901,50</td>
    </tr>
    <tr>
      <td><strong>2. Margem Contrib.</strong></td>
      <td>0</td><td>264,06</td><td>440,10</td><td><strong>704,16</strong></td><td>968,22</td><td>1.320,30</td><td>1.672,38</td><td>2.518,56</td><td>3.148,20</td><td>3.777,84</td><td>4.407,48</td><td>4.827,24</td><td>5.247,00</td><td><strong>29.295,54</strong></td>
    </tr>
    <tr>
      <td><strong>3. OPEX Fixo Total</strong></td>
      <td>0</td><td>-1.290,00</td><td>-600,00</td><td><strong>-600,00</strong></td><td>-800,00</td><td>-800,00</td><td>-800,00</td><td>-3.150,00</td><td>-3.150,00</td><td>-3.450,00</td><td>-3.650,00</td><td>-3.950,00</td><td>-3.950,00</td><td><strong>-26.190,00</strong></td>
    </tr>
    <tr>
      <td>&bull; Cloud + Lojas (M1)</td>
      <td>0</td><td>-830,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-140,00</td><td>-2.370,00</td>
    </tr>
    <tr>
      <td>&bull; Marketing Hiperlocal</td>
      <td>0</td><td>-300,00</td><td>-300,00</td><td>-300,00</td><td>-500,00</td><td>-500,00</td><td>-500,00</td><td>-1.000,00</td><td>-1.000,00</td><td>-1.300,00</td><td>-1.500,00</td><td>-1.800,00</td><td>-1.800,00</td><td>-10.800,00</td>
    </tr>
    <tr>
      <td>&bull; Contab. + KYC + Equipe</td>
      <td>0</td><td>-160,00</td><td>-160,00</td><td>-160,00</td><td>-160,00</td><td>-160,00</td><td>-160,00</td><td>-2.010,00</td><td>-2.010,00</td><td>-2.010,00</td><td>-2.010,00</td><td>-2.010,00</td><td>-2.010,00</td><td>-13.020,00</td>
    </tr>
    <tr>
      <td><strong>4. EBITDA / Caixa Mês</strong></td>
      <td>+2.500</td><td>-1.025,94</td><td>-159,90</td><td><strong>+104,16</strong></td><td>+168,22</td><td>+520,30</td><td>+872,38</td><td>-631,44</td><td>-1,80</td><td>+327,84</td><td>+757,48</td><td>+877,24</td><td>+1.297,00</td><td><strong>+3.105,54</strong></td>
    </tr>
    <tr>
      <td><strong>5. Caixa Acumulado</strong></td>
      <td>2.500,00</td><td>1.474,06</td><td>1.314,16</td><td><strong>1.418,32</strong></td><td>1.586,54</td><td>2.106,84</td><td><strong>2.979,22</strong></td><td>2.347,78</td><td>2.345,98</td><td>2.673,82</td><td>3.431,30</td><td>4.308,54</td><td><strong>5.605,54</strong></td><td><strong>5.605,54</strong></td>
    </tr>
  </tbody>
</table>

<p>
  <strong>Projeção de Escala Plurianual Rumo ao SOM (Horizonte 36 Meses):</strong> Consolidado o <em>playbook</em> unitário positivo no Ano 1 (<code>1.445 OS</code>; <code>GMV R$ 260,1 mil</code>), a transição para a Onda 2 (Ano 2: expansão metropolitana com ticket consolidado <code>R$ 320,00</code> e <code>24.000 OS/ano</code> &rarr; <code>GMV R$ 7,68 Milhões</code> e Receita Líquida Plataforma de <code>R$ 712,8 mil</code>) e Onda 3 (Ano 3: 25 clusters + contratos B2B condominiais/imobiliários atingindo <code>142.500 OS/ano</code> &rarr; <strong><code>GMV R$ 45,60 Milhões/ano</code></strong> e Receita Líquida de <strong><code>R$ 4,23 Milhões/ano</code></strong> com margem EBITDA projetada superior a <code>42%</code>) ocorre com geração endógena de caixa e elevada atratividade para capital institucional de crescimento.
</p>

<h4 id="sec-3-2-6-cenarios">Análise de Sensibilidade Multivariada e Stress-Test de Cenários Financeiros (Pessimista, Base Auditado e Otimista Acelerado)</h4>
<p>
  Em conformidade com as boas práticas de avaliação de investimentos sob incerteza, o plano financeiro foi submetido a um teste de estresse multivariado perturbando simultaneamente quatro variáveis estocásticas críticas: (i) velocidade de absorção de demanda (<span class="math-inline">&Delta;Q<sub>OS</sub></span>), (ii) inflação de leilão em mídia paga (<span class="math-inline">&Delta;CAC</span>), (iii) composição do ticket médio de mão de obra (<span class="math-inline">V<sub>MO</sub></span>) e (iv) taxa de sinistralidade efetiva da Garantia de 90 dias (<span class="math-inline">s<sub>90d</sub></span> frente ao <em>Carve-Out</em> de <code>1,50%</code>). O modelo incorpora uma trava gerencial automática (<em>OPEX Stage-Gate</em>): o degrau de expansão administrativa previsto para <code>M7</code> somente é liberado quando a plataforma supera de forma recorrente <code>100 OS/mês</code>, blindando a liquidez do caixa contra choques recessivos.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="25%">Parâmetro / Resultado Auditável (Ano 1 e Coorte)</th>
      <th width="25%">Cenário 1: Pessimista<br/>(<em>Stress-Test</em> Severo: <span class="mono">&minus;35% Vol. / +30% CAC</span>)</th>
      <th width="25%">Cenário 2: Base Auditado<br/>(Referência Oficial <span class="mono">fluxo_de_caixa_12m.csv</span>)</th>
      <th width="25%">Cenário 3: Otimista Acelerado<br/>(Tração B2B2C Condominial: <span class="mono">+45% Vol.</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Volume Anual Concluído (Ano 1)</strong></td>
      <td><code>940 OS</code> (retração severa de <code>&minus;35,0%</code>)</td>
      <td><strong><code>1.445 OS</code></strong> (<code>15 OS</code> em <code>M1</code> &rarr; <code>250 OS</code> em <code>M12</code>)</td>
      <td><code>2.095 OS</code> (convênios síndicos e imobiliárias)</td>
    </tr>
    <tr>
      <td><strong>Ticket Médio Aplicado no Ano 1</strong></td>
      <td><code>R$ 180,00</code> (congelado em serviços rápidos)</td>
      <td><strong><code>R$ 180,00</code></strong> (convergindo a <code>R$ 320</code> na Onda 2)</td>
      <td><code>R$ 240,00</code> (<code>R$ 175 MO + R$ 65 Peças</code> isentas)</td>
    </tr>
    <tr>
      <td><strong>GMV Transacionado no Ano 1</strong></td>
      <td><code>R$ 169.200,00</code></td>
      <td><strong><code>R$ 260.100,00</code></strong> (<code>R$ 45,60M</code> no Ano 3)</td>
      <td><code>R$ 502.800,00</code></td>
    </tr>
    <tr>
      <td><strong>Receita Bruta Plataforma (Ano 1)</strong></td>
      <td><code>R$ 22.968,00</code> (Margem Contrib. <code>R$ 19.051,92</code>)</td>
      <td><strong><code>R$ 35.316,00</code></strong> (Margem Contrib. <code>R$ 29.295,54</code>)</td>
      <td><code>R$ 57.000,00</code> (Margem Contrib. <code>R$ 47.546,40</code>)</td>
    </tr>
    <tr>
      <td><strong>OPEX Fixo Anual (Governança <em>Stage-Gate</em>)</strong></td>
      <td><code>&minus;R$ 18.650,00</code> (expansão <code>M7</code> retida até <code>100 OS</code>)</td>
      <td><strong><code>&minus;R$ 26.190,00</code></strong> (expansão integral em <code>M7</code>)</td>
      <td><code>&minus;R$ 30.625,60</code> (reforço comercial B2B dedicado)</td>
    </tr>
    <tr>
      <td><strong>Mês do <em>Break-Even</em> Operacional</strong></td>
      <td><strong><code>Mês 5 (M5)</code></strong> com <code>39 OS/mês</code></td>
      <td><strong><code>Mês 3 (M3)</code></strong> com <code>40 OS/mês</code> (<code>+R$ 104,16</code>)</td>
      <td><strong><code>Mês 2 (M2)</code></strong> com <code>36 OS/mês</code></td>
    </tr>
    <tr>
      <td><strong>Geração Líquida &amp; Saldo Final Caixa (<code>M12</code>)</strong></td>
      <td><code>+R$ 401,92</code> &bull; Caixa: <strong><code>R$ 2.901,92</code></strong> (<code>ROI +16,1%</code>)</td>
      <td><code>+R$ 3.105,54</code> &bull; Caixa: <strong><code>R$ 5.605,54</code></strong> (<code>ROI +124,2%</code>)</td>
      <td><code>+R$ 16.920,80</code> &bull; Caixa: <strong><code>R$ 19.420,80</code></strong> (<code>ROI +676,8%</code>)</td>
    </tr>
    <tr>
      <td><strong>Necessidade de Capital Adicional Pós-Seed</strong></td>
      <td><span class="badge-ok">R$ 0,00 (Vale mínimo M4 = R$ 684,50 &gt; 0)</span></td>
      <td><span class="badge-ok">R$ 0,00 (Seed R$ 2,5k pago já no M6)</span></td>
      <td><span class="badge-ok">R$ 0,00 (Autofinanciado desde M2)</span></td>
    </tr>
    <tr>
      <td><strong>Eficiência <span class="mono">LTV / CAC</span> sob Choque</strong></td>
      <td><code>CAC R$ 31,85</code> &bull; <strong><code>LTV/CAC = 6,82x</code></strong> (<code>&gt; 3,0x</code>)</td>
      <td><code>CAC R$ 24,50</code> &bull; <strong><code>LTV/CAC = 9,65x</code></strong></td>
      <td><code>CAC R$ 20,80</code> &bull; <strong><code>LTV/CAC = 11,40x</code></strong></td>
    </tr>
    <tr>
      <td><strong>Sinistralidade (<span class="mono">s<sub>90d</sub></span>) &amp; Cobertura (<span class="mono">ICA</span>)</strong></td>
      <td><code>s = 1,35% V_MO</code> &bull; <strong><code>ICA = 1,11x</code></strong> (<code>1,38x</code> c/ <em>clawback</em>)</td>
      <td><code>s = 0,85% V_MO</code> &bull; <strong><code>ICA = 1,76x</code></strong> (superavitário)</td>
      <td><code>s = 0,62% V_MO</code> &bull; <strong><code>ICA = 2,42x</code></strong> (alta reserva)</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-3-2-7">3.2.7. Balanced Scorecard (BSC) e Mapa Estratégico de Governança em 4 Perspectivas</h3>
<p>
  Encerrando a arquitetura executiva de gestão, o <strong>Balanced Scorecard (Kaplan &amp; Norton, 1996)</strong> do Desperrengue conecta em relação estrita de causa e efeito a excelência algorítmica da base (<em>Aprendizado e Crescimento</em>) à eficiência forense e de baixa latência (<em>Processos Internos</em>), que sustenta a confiança domiciliar e patrimonial (<em>Clientes</em>) e culmina na solvência atuarial e rentabilidade escalável (<em>Financeira</em>). Todos os KPIs abaixo são extraídos diretamente do estado relacional auditável do banco de dados PostgreSQL:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="17%">Perspectiva BSC</th>
      <th width="23%">Objetivo Estratégico</th>
      <th width="27%">Indicador-Chave (KPI) e Fórmula</th>
      <th width="11%">Meta Alvo</th>
      <th width="22%">Fonte SQL Auditável &amp; Iniciativa</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="3"><strong>1. Financeira e Solvência Atuarial</strong></td>
      <td>Garantir autossuficiência perpétua do Fundo de Garantia de 90 dias.</td>
      <td><strong>Índice de Cobertura Atuarial (<span class="mono">ICA</span>):</strong><br/><span class="math-inline">(&Sigma;CarveOut<sub>1,5%</sub> + &Sigma;Clawback) / &Sigma;Sinistros</span></td>
      <td><code>&ge; 1,50x</code></td>
      <td><code>warranty_pool_ledger</code> &bull; Trava de teto e <em>Circuit Breaker</em> automático.</td>
    </tr>
    <tr>
      <td>Sustentar eficiência superior de alocação de capital de crescimento.</td>
      <td><strong>Razão <span class="mono">LTV / CAC</span> e <span class="mono">Payback</span>:</strong><br/><span class="math-inline">LTV<sub>liq</sub> / CAC<sub>blended</sub></span></td>
      <td><code>&ge; 9,0x</code><br/>(<code>9,65x</code> atual)</td>
      <td><code>jobs</code> + aquisições &bull; Expansão por SEO hiperlocal e Passaporte ABNT.</td>
    </tr>
    <tr>
      <td>Erradicar evasão transacional (<em>platform leakage</em>) e bitributação.</td>
      <td><strong>Fração Isenta <em>Smart Split</em> (<span class="mono">&eta;<sub>Split</sub></span>):</strong><br/><span class="math-inline">&Sigma;V<sub>Mat</sub> / &Sigma;(V<sub>MO</sub> + V<sub>Mat</sub>)</span></td>
      <td><code>25% a 45%</code></td>
      <td><code>jobs</code> (<code>materials_amount_cents</code>) &bull; Auditoria SEFAZ NF-e 44 dígitos.</td>
    </tr>
    <tr>
      <td rowspan="3"><strong>2. Clientes e Patrimônio</strong></td>
      <td>Assegurar atendimento imediato em emergências residenciais críticas.</td>
      <td><strong>SLA de Aceite SOS:</strong><br/>Fração de ordens SOS aceitas em <span class="math-inline">&Delta;t &lt; 60s</span></td>
      <td><code>&ge; 95,0%</code></td>
      <td><code>jobs</code> + <em>Tiered Waterfall</em> (<code>waterfall_tier_rank = 1</code>).</td>
    </tr>
    <tr>
      <td>Resolver eventuais vícios técnicos sem atrito judicial ou abandono.</td>
      <td><strong>Resolução na Camada 1 (<span class="mono">FCR<sub>Cam1</sub></span>):</strong><br/>Retrabalhos solucionados pelo técnico original</td>
      <td><code>&ge; 75,0%</code></td>
      <td><code>job_mediations</code> (<code>resolved_layer1</code>) &bull; Gatilho <code>shouldOfferGuarantee</code>.</td>
    </tr>
    <tr>
      <td>Transformar reparos em valorização documental do imóvel.</td>
      <td><strong>Liquidação Presencial por PIN &amp; Emissão ABNT:</strong><br/>Ordens encerradas via PIN + PDF <code>SHA-256</code></td>
      <td><code>&ge; 85,0%</code></td>
      <td><code>private.job_forensic_secrets</code> + <code>DesperrengueOfficialPdfService</code>.</td>
    </tr>
    <tr>
      <td rowspan="3"><strong>3. Processos Internos e Segurança</strong></td>
      <td>Preservar privacidade física absoluta antes e após o serviço.</td>
      <td><strong>Violação Zero de Endereço Pré-Dia:</strong><br/>Exposições fora de <code>SERVICE_DAY_UNLOCKED</code></td>
      <td><strong><code>0,00%</code></strong><br/>(Zero absoluto)</td>
      <td>RPC <code>get_job_location_for_viewer</code> auditada por <code>test-geo-privacy-sql.mjs</code>.</td>
    </tr>
    <tr>
      <td>Bloquear fraudes visuais, recibos forjados e conluio em disputas.</td>
      <td><strong>Eficácia Forense Visual e Documental:</strong><br/>Rejeição de mídia sintética/duplicada (<code>dHash</code>)</td>
      <td><strong><code>100,0%</code></strong></td>
      <td><code>ImageMetadataStripper</code> + <code>PerceptualHashGuard</code> + <code>kyc_engine</code>.</td>
    </tr>
    <tr>
      <td>Manter baixa latência geoespacial e mediação célere.</td>
      <td><strong>Latência de Busca &amp; SLA de Mediação:</strong><br/>Query <span class="math-inline">O(log N + K)</span> e decisão de disputa</td>
      <td><code>&lt; 12 ms</code> e <code>&le; 24h</code></td>
      <td>Índices espaciais PostgreSQL + fila autônoma de mediação.</td>
    </tr>
    <tr>
      <td rowspan="3"><strong>4. Aprendizado, Crescimento e Tecnologia</strong></td>
      <td>Sustentar escala nacional com custo nulo de pré-triagem biométrica.</td>
      <td><strong>Custo Marginal KYC <em>Tier-0</em> On-Device:</strong><br/>Despesa de nuvem por captura preliminar inválida</td>
      <td><strong><code>R$ 0,00</code></strong></td>
      <td><code>Isolate.run</code> no cliente Dart antes de acionar <code>kyc-argon-vision-gate</code>.</td>
    </tr>
    <tr>
      <td>Garantir fluidez visual nativa e acessibilidade universal.</td>
      <td><strong>Orçamento de Quadro UI &amp; Cache:</strong><br/>Tempo de renderização de frame e leitura L1</td>
      <td><code>&le; 8,33 ms</code> (<code>120 FPS</code>) / <code>0 ms</code></td>
      <td><code>RepaintBoundary</code> + <code>InstantImageCacheEngine</code> + WCAG 2.1 AA/AAA.</td>
    </tr>
    <tr>
      <td>Blindar evolução contínua contra regressões funcionais e contábeis.</td>
      <td><strong>Taxa de Aprovação das Suítes Automatizadas:</strong><br/><code>762</code> Flutter (<code>816</code> HEAD) + <code>64</code> Pytest + SQL/PDF</td>
      <td><strong><code>100,0%</code></strong></td>
      <td>Execução automatizada em <code>app/test/</code>, <code>kyc_engine/tests/</code> e <code>scripts/</code>.</td>
    </tr>
  </tbody>
</table>
</section>
`;

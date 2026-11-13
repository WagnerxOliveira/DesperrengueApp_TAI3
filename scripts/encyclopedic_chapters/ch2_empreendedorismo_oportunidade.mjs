import {
  svgPesquisaPublicoAlvo,
  svgMapaEmpatiaCliente,
  svgMapaEmpatiaProfissional,
  svgValuePropositionCanvas,
  svgTamSamSom,
} from './svg_ch2_ch3_business.mjs';

export const ch2Html = String.raw`
<!-- ======================================================================= -->
<!-- CAPÍTULO 2: EMPREENDEDORISMO, PESQUISA, EMPATIA E OPORTUNIDADE          -->
<!-- ======================================================================= -->
<section class="chapter-section" id="cap-2">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 2</div>
  <div class="cb-body">
    <h2>EMPREENDEDORISMO, DESCOBERTA DE CLIENTES, PESQUISA EMPÍRICA, MAPA DE EMPATIA E OPORTUNIDADE DE NEGÓCIO</h2>
    <p>Fundamentação institucional, regulatória, microeconômica e estatística do ecossistema Desperrengue (<span class="mono">v2.11.0</span>): conformidade jurídica multiescopo, falhas estruturais do mercado de serviços domiciliares, pesquisa empírica bilateral, engenharia de empatia e dimensionamento econométrico de proposta de valor e potencial de mercado (TAM, SAM e SOM).</p>
  </div>
</div>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.1: ELEMENTOS ESSENCIAIS DE UMA EMPRESA                          -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-1" style="margin-top: 10px;">
  <span class="sh-tag">SEÇÃO 2.1 &bull; ARQUITETURA INSTITUCIONAL, GOVERNANÇA E DIREITO DIGITAL</span>
  <h2>2.1. Elementos Essenciais de uma Empresa: Identidade Corporativa, Governança e Conformidade Regulatória</h2>
  <p>Estruturação societária, diretrizes estratégicas perenes, mecanismos de governança técnica-atuarial e matriz exaustiva de aderência ao ordenamento jurídico brasileiro.</p>
</div>

<p>
  Sob a ótica da Teoria da Firma (Coase, 1937; Williamson, 1985), uma organização empresarial de base tecnológica justifica sua existência econômica na medida em que reduz drasticamente os custos de transação — busca, verificação de identidade, negociação contratual, monitoramento de execução e garantia pós-entrega — que inviabilizam ou encarecem trocas diretas no mercado aberto. O <strong>Desperrengue</strong> constitui-se formalmente como uma plataforma digital de intermediação garantida, infraestrutura de custódia financeira condicionada e certificação documental predial, concebida para erradicar a informalidade insegura no setor brasileiro de reparos, manutenção e serviços residenciais.
</p>

<h3 id="sec-2-1-1">2.1.1. Identidade Corporativa, Enquadramento Econômico e Diretrizes Estratégicas</h3>
<p>
  A modelagem institucional do empreendimento harmoniza agilidade regulatória no estágio inicial com robustez societária para captação de investimento e operação financeira segregada. A tabela a seguir sintetiza os atributos constitutivos da entidade empresarial.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="26%">Dimensão Corporativa</th>
      <th width="74%">Especificação Institucional e Jurídico-Operacional do Desperrengue (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Denominação Social Projetada e Marca</strong></td>
      <td><em>Desperrengue Tecnologia e Intermediação de Serviços Ltda.</em> &bull; Nome de fantasia e identidade pública: <strong>Desperrengue</strong>.</td>
    </tr>
    <tr>
      <td><strong>Classificação Nacional de Atividades Econômicas (CNAE)</strong></td>
      <td>
        <strong>CNAE Principal:</strong> <code>7490-1/04</code> — <em>Atividades de intermediação e agenciamento de serviços e negócios em geral, exceto imobiliários</em>.<br/>
        <strong>CNAEs Secundários:</strong> <code>6203-1/00</code> — <em>Desenvolvimento e licenciamento de programas de computador não-customizáveis</em>; <code>6311-9/00</code> — <em>Tratamento de dados, provedores de serviços de aplicação e serviços de hospedagem na internet</em>.
      </td>
    </tr>
    <tr>
      <td><strong>Regime Societário e Tributário</strong></td>
      <td>Constituição inicial elegível ao regime especial <strong>Inova Simples</strong> (Lei Complementar nº 167/2019, Art. 65-A), seguida de conversão em <strong>Sociedade Empresária Limitada (LTDA)</strong> optante pelo <strong>Simples Nacional — Anexo III</strong> (alíquota nominal inicial de <code>6,0%</code> sobre a receita líquida de intermediação, observada a regra do Fator R nos termos da LC nº 123/2006), com cláusula estatutária de conversão futura em Sociedade Anônima de Capital Fechado (S.A.) para rodadas institucionais <em>Seed / Série A</em>.</td>
    </tr>
    <tr>
      <td><strong>Natureza Jurídica da Operação</strong></td>
      <td>Agente intermediador tecnológico e custodiante fiduciário via <em>Payment Service Provider</em> (PSP) homologado pelo Banco Central do Brasil, sem vínculo empregatício com os prestadores autônomos/MEIs (inexistência cumulativa dos requisitos do Art. 3º da CLT, assegurada pela liberdade irrestrita de aceite, precificação própria do orçamento, ausência de exclusividade e autodeterminação de agenda).</td>
    </tr>
    <tr>
      <td><strong>Missão Institucional</strong></td>
      <td>Restaurar a confiança bilateral, a segurança física domiciliar e a justiça econômica na contratação de serviços residenciais no Brasil, conectando moradores e profissionais verificados por meio de criptografia geoespacial, custódia financeira inteligente e certificação técnica auditável.</td>
    </tr>
    <tr>
      <td><strong>Visão Estratégica (Horizonte 5 Anos)</strong></td>
      <td>Consolidar-se como a infraestrutura nacional padrão de manutenção predial e intermediação técnica residencial na América Latina, estabelecendo o Passaporte Predial <strong>ABNT NBR 5674</strong> e o <em>Smart Split Escrow</em> como referenciais obrigatórios de liquidez, segurança e valorização imobiliária.</td>
    </tr>
  </tbody>
</table>

<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">Valores Inegociáveis (1 a 3): Segurança, Justiça e Transparência</div>
    <p>
      <strong>1. Segurança Física e Privacidade por Projeto (<em>Privacy by Design</em>):</strong> A integridade física do morador e do trabalhador precede qualquer métrica de conversão comercial; nenhum endereço exato é exposto antes da janela temporal legítima.<br/>
      <strong>2. Justiça Econômica Assimétrica:</strong> É vedada a cobrança de taxas sobre insumos, peças de reposição ou tentativas frustradas de orçamento; a plataforma remunera-se exclusivamente quando gera renda efetiva sobre a mão de obra.<br/>
      <strong>3. Simetria Criptográfica da Verdade:</strong> Reputação, notas fiscais, geolocalização e garantias baseiam-se em provas matemáticas verificáveis, jamais em autodeclarações opacas.
    </p>
  </div>
  <div class="info-card">
    <div class="ic-title">Valores Inegociáveis (4 e 5) e Governança Societária</div>
    <p>
      <strong>4. Rigor Normativo e Engenharia Auditável:</strong> Conformidade integral às normas ISO, ABNT, LGPD, CDC e pronunciamentos contábeis, auditada continuamente por suítes automatizadas.<br/>
      <strong>5. Dignidade e Ascensão Profissional:</strong> Valorização meritocrática do técnico qualificado, transformando excelência operacional em capital reputacional portável.<br/>
      <strong>Governança Executiva:</strong> Coautoria e direção técnica compartilhadas simetricamente por <strong>Wagner Oliveira</strong> e <strong>Gabriel</strong>, sob regime de <em>vesting</em> de 48 meses (<em>cliff</em> de 12 meses), segregação de privilégios em esquemas <code>private.*</code> e auditoria documental via <em>Architecture Decision Records</em> (ADRs).
    </p>
  </div>
</div>

<h3 id="sec-2-1-2">2.1.2. Matriz Completa de Conformidade Regulatória e Materialização Arquitetural</h3>
<p>
  Diferentemente de plataformas convencionais em que a adequação jurídica restringe-se a termos de uso genéricos, o ecossistema Desperrengue codifica as exigências normativas diretamente como invariantes de banco de dados, travas de estado e algoritmos criptográficos no repositório de produção (<code>app/lib/</code>, <code>supabase/</code> e <code>kyc_engine/</code>). A matriz subsequente demonstra a correspondência exata entre cada diploma legal brasileiro e sua implementação computacional verificada.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="20%">Diploma Legal / Norma</th>
      <th width="22%">Dispositivos Normativos Críticos</th>
      <th width="58%">Materialização Computacional e Arquitetural no Código de Produção (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>LGPD — Lei Geral de Proteção de Dados Pessoais</strong><br/>(Lei nº 13.709/2018)</td>
      <td>Arts. 6º (III e VII), 11 (II, <em>g</em>), 16, 18 (V e VI) e 20</td>
      <td>
        <strong>Minimização Geoespacial (Art. 6º, III — <code>ADR-0022</code>):</strong> O protocolo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> oculta logradouro, número, complemento, CEP e coordenadas reais até as <code>00:00:00</code> (<code>America/Sao_Paulo</code>) do dia agendado, expondo apenas um círculo determinístico <code>HMAC-SHA256</code> de <code>500m–800m</code>, além de remover binariamente metadados <code>EXIF/GPS</code> antes de qualquer upload.<br/>
        <strong>Biometria Antifraude (Art. 11, II, <em>g</em>):</strong> Processamento facial <em>Zero-Trust</em> com segregação em cofre criptográfico (<em>Dual Vault</em>) e proteção anti-coação.<br/>
        <strong>Portabilidade e Exclusão Granular por Escopo (Art. 18, V e VI — <code>ADR-0013</code>):</strong> Em <code>DeleteAccountScreen</code> e <code>supabase/functions/excluir-conta/dossie.ts</code>, o titular escolhe excluir apenas o perfil <code>client</code>, apenas o perfil <code>provider</code> ou a totalidade da conta (<code>all</code>), preservando o papel remanescente. Antes da anonimização irreversível (<em>soft-wipe</em> de PII respeitando retenção fiscal do Art. 16), a Edge Function sintetiza via <code>pdf-lib</code> o <strong>Dossiê de Despedida</strong> vetorial contendo todo o histórico financeiro, reputacional e economia aferida (<code>total_saved = avg_other_quotes - price</code>), bloqueando a operação caso existam saldos retidos (<code>available &gt; 0</code>) ou ordens em custódia ativa.<br/>
        <strong>Explicabilidade Algorítmica (Art. 20):</strong> Decisões automatizadas do motor KYC registram os <em>Top-3 Fatores SHAP</em> auditáveis e asseguram canal de revisão humana.
      </td>
    </tr>
    <tr>
      <td><strong>CDC — Código de Defesa do Consumidor</strong><br/>(Lei nº 8.078/1990)</td>
      <td>Arts. 6º (III), 20, 21, 26 (II) e 40</td>
      <td>
        <strong>Orçamento Prévio Discriminado (Art. 40):</strong> A interface e o modelo transacional do <em>Smart Split Checkout</em> obrigam a decomposição explícita entre valor da mão de obra (<code>V_MO</code>) e valor de peças/insumos (<code>V_Mat</code>), vedando cobranças surpresa sem aditivo formal aprovado pelo consumidor.<br/>
        <strong>Qualidade de Insumos (Art. 21):</strong> Exigência de comprovação de insumos novos mediante validação algorítmica da chave de acesso de 44 dígitos da NF-e/NFC-e (Módulo 11 + consulta SEFAZ) ou teto controlado para recibos MEI com análise forense de imagem (<em>Error Level Analysis — ELA</em>).<br/>
        <strong>Garantia Legal de 90 Dias e Reexecução (Arts. 20 e 26, II):</strong> Implementação nativa de janela decadencial de 90 dias corridos após a conclusão do serviço, estruturada em <strong>3 Camadas Progressivas</strong> (1ª Reexecução sem ônus pelo prestador original; 2ª Substituição assistida por novo profissional homologado; 3ª Indenização financeira direta), caucionada pelo livro-razão contábil imutável <code>warranty_pool_ledger</code> alimentado por <em>Carve-Out</em> automático de <code>1,5%</code> sobre <code>V_MO</code>.
      </td>
    </tr>
    <tr>
      <td><strong>Lei do Inquilinato</strong><br/>(Lei nº 8.245/1991)</td>
      <td>Arts. 22 (I, IV, V) e 23 (II, III, V)</td>
      <td>
        <strong>Segregação de Responsabilidade Locador vs. Locatário:</strong> A taxonomia de 33 categorias técnicas e os laudos fotográficos/fiscais gerados na plataforma permitem classificar objetivamente intervenções estruturais e vícios ocultos preexistentes (imputáveis ao proprietário/locador pelo Art. 22) em face de manutenções ordinárias decorrentes do uso normal da edificação (imputáveis ao locatário pelo Art. 23), eliminando litígios em vistorias de entrada, permanência e entrega de chaves junto a imobiliárias.
      </td>
    </tr>
    <tr>
      <td><strong>Norma Técnica de Manutenção Predial</strong><br/>(ABNT NBR 5674:2012)</td>
      <td>Requisitos do Sistema de Gestão de Manutenção de Edificações</td>
      <td>
        <strong>Passaporte Oficial de Manutenção do Imóvel:</strong> Geração automatizada em <em>background isolate</em> (<code>Isolate.run</code>) de documento técnico padronizado em PDF vetorial nativo (<code>%PDF-1.4</code>), contendo cronologia imutável das ordens executadas, identificação qualificada do responsável técnico, especificação de materiais aplicados, evidências visuais auditadas, identificador único <code>DSP-PASS-*</code> e selo de integridade criptográfica <code>SHA-256</code>, atendendo integralmente aos requisitos de rastreabilidade preventiva e corretiva da norma ABNT NBR 5674.
      </td>
    </tr>
    <tr>
      <td><strong>Marco Civil da Internet</strong><br/>(Lei nº 12.965/2014 e Dec. nº 8.771/2016)</td>
      <td>Arts. 7º, 10 e 15</td>
      <td>
        <strong>Guarda Segura de Registros de Aplicação:</strong> Manutenção de trilhas de auditoria imutáveis (<em>append-only logs</em>) de autenticação, aceite contratual de orçamentos, geração/validação do PIN de liberação de custódia e acionamento de disputas pelo prazo legal mínimo de 6 meses (Art. 15), sob controle estrito de acesso <em>Row Level Security</em> (RLS) e criptografia em trânsito (TLS 1.3) e em repouso (AES-256).
      </td>
    </tr>
    <tr>
      <td><strong>Regulamentação BACEN / Arranjo Pix e IP</strong><br/>(Res. BCB nº 1/2020 e Res. BCB nº 80/2021)</td>
      <td>Segregação Patrimonial, SPI/Pix e PLD/FT</td>
      <td>
        <strong>Liquidação Segregada e Prevenção a Fraudes Financeiras:</strong> A custódia temporária de valores do <em>Smart Escrow</em> opera por meio de contas gráficas segregadas em instituição de pagamento autorizada pelo Banco Central, processada via <code>pix-webhook</code> com verificação criptográfica de assinatura HMAC e chaves de idempotência transacional em centavos inteiros (<code>BIGINT</code>). Adicionalmente, aplica-se a trava estrita de titularidade cruzada (<em>Same-Holder CPF Lock</em>), impedindo transferências de saque para chaves Pix cujo CPF/CNPJ divirja do titular autenticado no KYC biométrico, neutralizando contas laranjas e lavagem de capitais.
      </td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.2: CARACTERÍSTICAS ESSENCIAIS DE UMA STARTUP                    -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-2" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 2.2 &bull; ECONOMIA DA INOVAÇÃO, ESCALABILIDADE ASSINTÓTICA E EFEITOS DE REDE</span>
  <h2>2.2. Características Essenciais de uma Startup Aplicadas ao Ecossistema Desperrengue</h2>
  <p>Demonstração formal dos quatro pilares que distinguem o Desperrengue de empresas tradicionais de intermediação ou assistência técnica: escalabilidade assintótica, repetibilidade sob incerteza, custo marginal zero de triagem on-device e efeitos de rede bilaterais cruzados.</p>
</div>

<p>
  Na literatura econômica de empreendedorismo tecnológico (Blank &amp; Dorf, 2012; Ries, 2011; Graham, 2012), uma <em>startup</em> não se define pelo porte de faturamento inicial ou pela mera presença de um aplicativo móvel, mas por constituir uma organização projetada para validar e operar um modelo de negócio <strong>altamente escalável, repetível sob condições de incerteza ambiental e alavancado por inovação tecnológica disruptiva</strong>. Enquanto uma prestadora tradicional de manutenção predial apresenta função de custo linearmente acoplada à receita — exigindo contratação proporcional de técnicos celetistas, frota própria, supervisores presenciais e filiais físicas para dobrar sua capacidade —, o Desperrengue desacopla estruturalmente o crescimento do Volume Bruto de Mercadorias e Serviços (<em>Gross Merchandise Volume — GMV</em>) da evolução do custo operacional fixo (<em>OPEX</em>).
</p>

<h3 id="sec-2-2-1">2.2.1. Escalabilidade Nacional Assintótica e Desacoplamento Receita-Custo</h3>
<p>
  A escalabilidade técnica e econômica da plataforma decorre diretamente das escolhas algorítmicas de sua arquitetura distribuída em quatro camadas. Na camada de persistência e roteamento geoespacial, a descoberta de profissionais elegíveis utiliza indexação espacial em árvore balanceada com complexidade assintótica <span class="math-inline">O(log N + K)</span> (onde <span class="math-inline">N</span> representa o total nacional de prestadores cadastrados e <span class="math-inline">K</span> o subconjunto ativo no raio local), evitando varreduras lineares degradantes. Na camada de infraestrutura <em>serverless</em> (PostgreSQL gerenciado, Edge Functions em Deno e CDN global), o custo marginal computacional aferido por Ordem de Serviço completa situa-se em apenas <strong><code>R$ 0,034/OS</code></strong>.
</p>

<div class="math-formula-box">
  <div class="math-display">
    lim<sub>Q &rarr; &infin;</sub> [ &Delta;C<sub>infra</sub>(Q) / &Delta;Receita<sub>liq</sub>(Q) ] = R$ 0,034 / R$ 29,70 &approx; 0,00114 (0,11% da Receita Líquida por OS)
  </div>
</div>

<p>
  Essa razão assintótica inferior a um décimo de ponto percentual comprova que o sistema suporta expansão simultânea para milhares de municípios brasileiros sem estrangulamento de margem bruta, mantendo orçamento estrito de renderização gráfica de <code>8,33 ms/quadro</code> (<code>120 FPS</code>) e leitura instantânea de cache de imagem (<code>0 ms</code> via <code>InstantCachedImage</code>).
</p>

<h3 id="sec-2-2-2">2.2.2. Repetibilidade Operacional sob Condições de Incerteza</h3>
<p>
  O mercado brasileiro de serviços domiciliares caracteriza-se por severa heterogeneidade regional, sazonalidade climática (ex.: picos de infiltração hidráulica e panes elétricas no verão chuvoso; manutenção de aquecedores no inverno) e variabilidade na complexidade diagnóstica de cada chamado. A <strong>repetibilidade</strong> do Desperrengue reside em encapsular toda essa incerteza dentro de uma máquina de estados determinística e autossuficiente (<code>open_for_quotes &rarr; scheduled/in_escrow &rarr; in_progress &rarr; completed &rarr; under_warranty</code>). Independentemente de o serviço ocorrer em uma capital metropolitana ou em um polo do interior, e quer trate de elétrica de baixa tensão, marcenaria ou limpeza pós-obra dentre as <strong>33 categorias homologadas</strong>, o protocolo de formação de preço (<em>Smart Split</em>), proteção de endereço (<em>Geo-Privacy Lock</em>), liquidação financeira (<em>Smart Escrow</em> com PIN de 4 dígitos) e cobertura atuarial (<code>1,5%</code> de <em>Carve-Out</em>) opera de modo idêntico, dispensando intervenção manual da equipe gestora em mais de <code>98%</code> do fluxo transacional.
</p>

<h3 id="sec-2-2-3">2.2.3. Inovação Disruptiva com Custo Marginal Zero de Pré-Validação KYC On-Device (<span class="mono">Tier-0 = R$ 0,00</span>)</h3>
<p>
  Um gargalo econômico clássico que inviabiliza a verificação rigorosa de identidade (<em>Know Your Customer — KYC</em>) em plataformas populares de serviços é o custo unitário cobrado por <em>bureaus</em> biométricos e governamentais (tipicamente entre <code>R$ 2,50</code> e <code>R$ 6,80</code> por requisição de API). Quando usuários submetem fotografias desfocadas, subexpostas, cortadas ou documentos ilegíveis, plataformas convencionais pagam repetidas vezes pela rejeição na nuvem, repassando esse prejuízo aos prestadores sob a forma de mensalidades ou venda de moedas.
</p>
<p>
  O Desperrengue introduz uma inovação arquitetural disruptiva ao implementar um pipeline de verificação em cascata encabeçado pelo <strong>Tier-0 On-Device Gate</strong> executado em <em>worker thread</em> isolada no próprio aparelho do usuário (<code>Isolate.run</code> em Dart). Antes de transmitir um único byte para os estágios de nuvem (<em>Argon Vision Gate</em> e <em>Carbon Cryptographic Engine</em> VIO/SERPRO), o dispositivo avalia localmente a variância do operador Laplaciano (nitidez óptica), o histograma de luminância, a integridade geométrica do documento e a remoção de metadados sensíveis. Capturas defeituosas são rejeitadas em milissegundos na borda com <strong>custo marginal exatamente igual a <code>R$ 0,00</code></strong> para os servidores da startup, reduzindo em mais de <code>72%</code> as chamadas onerosas às APIs externas e sustentando economicamente a política de adesão e envio de orçamentos 100% gratuitos.
</p>

<h3 id="sec-2-2-4">2.2.4. Efeitos de Rede Bilaterais Cruzados (<em>Two-Sided Marketplace</em>) e Elasticidade Dual-Mode</h3>
<p>
  Conforme demonstrado pela teoria microeconômica de mercados de dois lados (Rochet &amp; Tirole, 2003; Parker, Van Alstyne &amp; Choudary, 2016), o valor intrínseco da plataforma cresce de forma superlinear à medida que cada grupo de usuários gera externalidades positivas cruzadas sobre o grupo complementar. Seja <span class="math-inline">N<sub>C</sub></span> o número de moradores ativos e <span class="math-inline">N<sub>P</sub></span> o contingente de profissionais verificados em uma microrregião urbana, as funções de utilidade líquida <span class="math-inline">U<sub>C</sub></span> e <span class="math-inline">U<sub>P</sub></span> descrevem-se por:
</p>

<div class="math-formula-box">
  <div class="math-display">
    U<sub>C</sub>(N<sub>P</sub>) = V<sub>0,C</sub> + &alpha;<sub>CP</sub> &middot; ln(1 + N<sub>P</sub>) &minus; &tau;<sub>espera</sub>(N<sub>P</sub>) &emsp;&emsp;<span class="m-rm">e</span>&emsp;&emsp; U<sub>P</sub>(N<sub>C</sub>) = V<sub>0,P</sub> + &alpha;<sub>PC</sub> &middot; (N<sub>C</sub> / N<sub>P</sub>) &minus; C<sub>ociosidade</sub>(N<sub>C</sub>)
  </div>
</div>

<p>
  Onde <span class="math-inline">&alpha;<sub>CP</sub> &gt; 0</span> captura o ganho de competitividade orçamentária e especialização técnica percebido pelo morador, enquanto o tempo de atendimento de urgência <span class="math-inline">&tau;<sub>espera</sub>(N<sub>P</sub>)</span> decai assintoticamente para menos de <code>60 segundos</code> nos chamados SOS. Simetricamente, <span class="math-inline">&alpha;<sub>PC</sub> &gt; 0</span> reflete a elevação da densidade de ordens por quilômetro quadrado, comprimindo o deslocamento improdutivo <span class="math-inline">C<sub>ociosidade</sub></span> do trabalhador. Além do efeito cruzado clássico, o Desperrengue potencializa a liquidez inicial (superando o <em>cold-start problem</em>) mediante sua <strong>Arquitetura Unificada Dual-Mode com Herança Instantânea de KYC</strong>: qualquer morador já verificado pode ativar o modo Profissional em uma especialidade que domine (e vice-versa, todo técnico verificado contrata outros especialistas para sua própria residência) herdando imediatamente sua credencial biométrica e pontuação basal de confiança, criando uma malha densa e defensável (<em>network moat</em>).
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.3: PROBLEMAS ESTRUTURAIS E NECESSIDADES REAIS QUE ATENDE        -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-3" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 2.3 &bull; DIAGNÓSTICO MICROECONÔMICO E FALHAS DE MERCADO</span>
  <h2>2.3. Problemas Estruturais e Necessidades Reais Atendidas pelo Ecossistema</h2>
  <p>Análise formal das seis patologias sistêmicas que paralisam o mercado brasileiro de manutenção residencial: seleção adversa de Akerlof, extorsão via moedas de lead, bitributação sobre materiais, vulnerabilidade física/digital, risco moral pós-contratual e apagão documental predial.</p>
</div>

<p>
  A persistência de mais de <code>90%</code> das contratações residenciais brasileiras na informalidade analógica — apesar da existência há mais de uma década de aplicativos de classificados de primeira geração — evidencia que tais plataformas falharam em resolver as causas raízes da desconfiança transacional. A investigação econômica e computacional conduzida neste projeto identifica seis falhas estruturais interdependentes que o Desperrengue soluciona na raiz.
</p>

<h3 id="sec-2-3-1">2.3.1. Falhas Econômicas de Precificação e Seleção: Akerlof (1970), Moedas de Lead e Bitributação de Insumos</h3>

<div class="innovation-box">
  <div class="ib-header">1. Seleção Adversa e Assimetria de Informação (<em>The Market for "Lemons"</em>, George Akerlof, 1970)</div>
  <p>
    No modelo seminal laureado com o Prêmio Nobel de Economia de <strong>George Akerlof (1970)</strong>, mercados nos quais o comprador não consegue distinguir <em>ex-ante</em> a qualidade real do ofertante entram em espiral de degradação. No setor de reparos residenciais, coexistem profissionais altamente qualificados (<span class="math-inline">q<sub>H</sub></span>, detentores de certificações NR-10/NR-35, ferramental calibrado e conduta ética, cujo custo mínimo justo de execução é <span class="math-inline">c<sub>H</sub></span>) e executores improvisados ou oportunistas (<span class="math-inline">q<sub>L</sub></span>, os chamados "aventureiros" ou <em>lemons</em>, que operam com custo inferior <span class="math-inline">c<sub>L</sub> &lt; c<sub>H</sub></span> mediante gambiarras técnicas e materiais subdimensionados). Como grupos de WhatsApp e diretórios abertos carecem de validação criptográfica de identidade e histórico auditado por transações liquidadas, o morador observa apenas uma probabilidade média <span class="math-inline">p</span> de encontrar um bom técnico e limita sua disposição máxima a pagar ao valor esperado ponderado:
  </p>
  <div class="math-formula-box">
    <div class="math-display">
      P<sub>max</sub> = p &middot; V(q<sub>H</sub>) + (1 &minus; p) &middot; V(q<sub>L</sub>) &lt; c<sub>H</sub> &rArr; Expulsão dos Profissionais de Excelência (Seleção Adversa)
    </div>
  </div>
  <p>
    Como <span class="math-inline">P<sub>max</sub> &lt; c<sub>H</sub></span>, os especialistas sérios recusam-se a competir por preço vil em plataformas abertas, migrando exclusivamente para indicações fechadas escassas, enquanto o ambiente digital fica saturado por perfis <span class="math-inline">q<sub>L</sub></span>. O Desperrengue restaura o equilíbrio separador de Spence/Akerlof ao instituir sinalização custosa de falsificar, porém gratuita para o trabalhador honesto: KYC biométrico VIO/ICP-Brasil, índice reputacional <code>RTS</code> auditado por pagamentos reais e 6 emblemas automáticos de excelência.
  </p>
</div>

<div class="innovation-box">
  <div class="ib-header">2. Extorsão de Plataformas Legadas via Venda de "Moedas de Desbloqueio de Lead" sem Conversão</div>
  <p>
    Os diretórios digitais incumbentes (a exemplo do modelo de venda de pacotes de moedas popularizado por plataformas como GetNinjas e similares) transferem <code>100%</code> do risco comercial para o elo financeiramente mais vulnerável: o trabalhador autônomo. Nesse arranjo, um único pedido de orçamento (muitas vezes submetido por um usuário apenas sondando preços, sem intenção real de contratar) é comercializado simultaneamente para <code>4 a 5</code> prestadores, cobrando-se entre <code>R$ 15,00</code> e <code>R$ 45,00</code> em "moedas virtuais" de cada um pelo mero desbloqueio do número telefônico. Matematicamente, mesmo que a demanda fosse legítima, pelo menos <code>75% a 80%</code> dos pagantes saem obrigatoriamente derrotados; quando o solicitante sequer responde às mensagens ("cliente fantasma"), <code>100%</code> dos profissionais sofrem perda patrimonial líquida enquanto a plataforma contabiliza lucro bruto imediato. Esse mecanismo configura desincentivo econômico severo e explica a rejeição unânime verificada na pesquisa empírica.
  </p>
</div>

<div class="innovation-box">
  <div class="ib-header">3. Bitributação Predatória sobre Peças, Materiais e Insumos e Incentivo ao <em>Bypass</em></div>
  <p>
    Marketplaces transacionais genéricos que substituíram a venda de moedas por uma comissão linear uniforme (<span class="math-inline">&tau;<sub>legado</sub> &isin; [20%, 30%]</span>) incidente sobre o valor bruto total da ordem criam uma anomalia tributária e microeconômica grave sempre que o serviço envolve reposição de componentes físicos. Considere-se a substituição de uma placa inversora de climatizador na qual a peça custa <code>V<sub>Mat</sub> = R$ 600,00</code> na revenda técnica (repassada pelo prestador a preço de custo mediante nota fiscal) e a mão de obra especializada vale <code>V<sub>MO</sub> = R$ 300,00</code> (totalizando <code>R$ 900,00</code>). Uma taxa linear de <code>25%</code> sobre o total retém <code>R$ 225,00</code> — o que equivale a confiscar <strong><code>75,0%</code> da remuneração bruta do trabalho humano</strong>, reduzindo o ganho do técnico a <code>R$ 75,00</code>. Para defender sua subsistência, o profissional é compelido a inflacionar artificialmente o orçamento para <code>R$ 1.200,00</code> ou a negociar o pagamento "por fora" do aplicativo (<em>platform leakage</em>), destruindo tanto a conversão quanto a proteção do consumidor. O <strong>Smart Split</strong> do Desperrengue corrige essa distorção aplicando <strong><code>0,0%</code> de taxa sobre materiais comprovados</strong> e tributando exclusivamente o valor agregado da mão de obra.
  </p>
</div>

<h3 id="sec-2-3-2">2.3.2. Vulnerabilidade Física/Digital Residencial, Risco Moral Pós-Contratual e Apagão Documental Predial</h3>

<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">4. Vulnerabilidade Crítica de Segurança Física e Digital</div>
    <p>
      Admitir um desconhecido no interior da residência (muitas vezes com moradores desacompanhados, idosos ou crianças) sem validação criminal, documental e biométrica representa risco físico agudo. Ademais, plataformas convencionais expõem o endereço residencial completo já na abertura pública do orçamento para dezenas de contas não contratadas e servem fotografias originais contendo coordenadas <code>EXIF/GPS</code> de latitude, longitude e altitude do quarto ou sala do morador — falha crítica neutralizada pelo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> e pelo expurgo binário de metadados.
    </p>
  </div>
  <div class="info-card">
    <div class="ic-title">5. Risco Moral (<em>Moral Hazard</em>) de Calote e Abandono</div>
    <p>
      Na contratação informal, instala-se uma assimetria temporal insolúvel: o pagamento antecipado via Pix direto expõe o morador ao abandono da obra ou execução deficiente; inversamente, o pagamento pós-entrega desprotegido expõe o técnico à inadimplência, retenção injustificada ou pedidos intermináveis fora do escopo. Concluído o serviço informal, eventual infiltração reincidente ou curto-circuito após 15 dias resulta em bloqueio telefônico mútuo, tornando letra morta a garantia legal de 90 dias do Art. 26, II do CDC.
    </p>
  </div>
</div>

<div class="innovation-box">
  <div class="ib-header">6. Inexistência de Livro-Razão Predial Auditável e Depreciação Patrimonial Imobiliária</div>
  <p>
    Ao contrário do setor automotivo — no qual revisões carimbadas em concessionária preservam o valor de revenda do veículo —, o patrimônio imobiliário residencial brasileiro (frequentemente o maior ativo financeiro de uma família) padece de completo apagão documental. Recibos em papel termossensível apagam-se em poucos meses, conversas de mensageria perdem-se e proprietários, síndicos e inquilinos tornam-se incapazes de comprovar manutenções preventivas exigidas pela norma <strong>ABNT NBR 5674</strong>, sofrendo glosas de apólices securitárias residenciais, conflitos judiciais locatícios e deságios na alienação do imóvel.
  </p>
</div>

<h3 id="sec-2-3-3">2.3.3. Matriz de Benchmarking Competitivo de Mercado em 14 Dimensões Estruturais</h3>
<p>
  Para demonstrar objetivamente o hiato tecnológico, fiduciário e regulatório existente no setor brasileiro de serviços residenciais, a matriz comparativa abaixo confronta o ecossistema <strong>Desperrengue (<code>v2.11.0</code>)</strong> perante os três regimes alternativos dominantes no país: (i) plataformas de venda de moedas de desbloqueio de contato (<em>GetNinjas</em> e congêneres); (ii) plataformas de comissão linear sobre o valor bruto ou diretórios de reforma (<em>Triider / Habitissimo</em>); e (iii) o substituto hegemônico da contratação informal analógica via <em>WhatsApp</em> e indicação boca a boca (<code>96,4%</code> do mercado atual).
</p>

<table class="data-table compact-table" style="font-size: 7.4pt;">
  <thead>
    <tr>
      <th width="20%">Dimensão Estrutural Auditada</th>
      <th width="24%">Desperrengue (<span class="mono">v2.11.0</span>)</th>
      <th width="19%">GetNinjas (Modelo Venda de Moedas)</th>
      <th width="19%">Triider / Habitissimo (Taxa Linear / Diretório)</th>
      <th width="18%">Informal (WhatsApp / Indicação)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Custo de Adesão e Envio de Orçamento</strong></td>
      <td><span class="badge-ok">100% GRATUITO</span><br/>Zero venda de moedas; comissão apenas se fechar e liquidar.</td>
      <td><span class="badge-high">PEDÁGIO ANTECIPADO</span><br/>Compra obrigatória de moedas (<code>R$ 15–R$ 45</code>/lead) sem garantia.</td>
      <td><span class="badge-med">HÍBRIDO / ASSINATURA</span><br/>Planos mensais de destaque ou retenção linear elevada.</td>
      <td>Gratuito, porém limitado à rede pessoal escassa e lenta.</td>
    </tr>
    <tr>
      <td><strong>2. Taxa sobre Peças, Materiais e Insumos</strong></td>
      <td><span class="badge-ok">0,0% (SMART SPLIT)</span><br/>Isenção integral mediante NF-e 44 dígitos SEFAZ / recibo auditado.</td>
      <td>Não intermedia pagamento; risco total recai sobre as partes.</td>
      <td><span class="badge-high">BITRIBUTAÇÃO (20%–30%)</span><br/>Incide sobre o bruto total, confiscando margem do técnico.</td>
      <td><code>0%</code>, mas sem controle contra sobrepreço ou peça paralela.</td>
    </tr>
    <tr>
      <td><strong>3. Sigilo Temporal e Espacial de Endereço</strong></td>
      <td><span class="badge-ok">GEO-PRIVACY LOCK</span><br/>Círculo <code>HMAC-SHA256</code> (<code>500m–800m</code>); rua/apto ocultos até <code>00:00</code> do dia.</td>
      <td><span class="badge-high">EXPOSTO A MÚLTIPLOS</span><br/>Contato/região liberados simultaneamente a até 4–5 estranhos.</td>
      <td><span class="badge-med">PARCIAL</span><br/>Dados compartilhados antes da janela física estrita de execução.</td>
      <td><span class="badge-high">VAZAMENTO TOTAL</span><br/>Endereço completo enviado em texto aberto a não contratados.</td>
    </tr>
    <tr>
      <td><strong>4. Expurgo Forense de Metadados EXIF/GPS</strong></td>
      <td><span class="badge-ok">NATIVO FAIL-CLOSED</span><br/><code>ImageMetadataStripper</code> remove <code>100%</code> de GPS/EXIF no upload.</td>
      <td>Inexistente ou não documentado na camada de cliente.</td>
      <td>Inexistente como garantia criptográfica <em>client-side</em>.</td>
      <td><span class="badge-high">VULNERÁVEL</span><br/>Arquivos originais revelam latitude/longitude exatas.</td>
    </tr>
    <tr>
      <td><strong>5. Verificação Civil e Biométrica (KYC)</strong></td>
      <td><span class="badge-ok">ZERO-TRUST VIO/SERPRO</span><br/>Tier-0 <code>R$ 0,00</code> + QR VIO ICP-Brasil + mTLS Datavalid + Liveness.</td>
      <td><span class="badge-med">BÁSICA CADASTRAL</span><br/>Validação documental simplificada sem cadeia ICP-Brasil completa.</td>
      <td><span class="badge-med">CURADORIA MANUAL</span><br/>Lenta, cara de escalar e sem revalidação criptográfica VIO.</td>
      <td><span class="badge-high">NULA (CEGA)</span><br/>Apenas apelido e foto de perfil autodeclarada (<code>60,7%</code> medo).</td>
    </tr>
    <tr>
      <td><strong>6. Custódia Financeira (<em>Smart Escrow</em>)</strong></td>
      <td><span class="badge-ok">PIX + PIN 4 DÍGITOS</span><br/>Valor caucionado antes da ida e liberado por PIN presencial em <code>BIGINT</code>.</td>
      <td><span class="badge-high">AUSENTE</span><br/>Acerto externo direto sujeito a calote ou abandono de obra.</td>
      <td>Retenção por cartão tradicional com alto custo e <em>chargeback</em>.</td>
      <td><span class="badge-high">RISCO MORAL PURO</span><br/>Pix adiantado arrisca abandono; pós-obra arrisca calote.</td>
    </tr>
    <tr>
      <td><strong>7. Proteção Presencial Anti-Coação</strong></td>
      <td><span class="badge-ok">SILENT DURESS PIN</span><br/>PIN invertido simula sucesso na tela e congela repasse silenciosamente.</td>
      <td>Inexistente.</td>
      <td>Inexistente.</td>
      <td>Inexistente.</td>
    </tr>
    <tr>
      <td><strong>8. Garantia Pós-Obra de 90 Dias (CDC)</strong></td>
      <td><span class="badge-ok">3 CAMADAS + POOL 1,5%</span><br/>Reexecução, substituição por 2º técnico ou indenização via <code>warranty_pool_ledger</code>.</td>
      <td><span class="badge-high">SEM LASTRO PRÓPRIO</span><br/>Plataforma exime-se como mero classificado de anúncios.</td>
      <td><span class="badge-med">RESTRITA / LENTA</span><br/>Sem livro-razão mutualista automatizado de partidas dobradas.</td>
      <td><span class="badge-high">ORFANDADE TOTAL</span><br/>Bloqueio telefônico comum após pagamento (<code>53,6%</code> dor).</td>
    </tr>
    <tr>
      <td><strong>9. Certificação Predial ABNT NBR 5674</strong></td>
      <td><span class="badge-ok">PASSAPORTE SHA-256</span><br/>PDF vetorial <code>DSP-PASS-*</code> gerado em <code>Isolate.run</code> valorizando o imóvel.</td>
      <td>Inexistente.</td>
      <td>Inexistente (apenas recibo simples de pagamento).</td>
      <td><span class="badge-high">APAGÃO PREDIAL</span><br/>Perda de cupons térmicos e litígios em vistorias locatícias.</td>
    </tr>
    <tr>
      <td><strong>10. Conta Unificada <em>Dual-Mode</em></strong></td>
      <td><span class="badge-ok">HERANÇA KYC (+30 RTS)</span><br/>Alternância instantânea Cliente &harr; Profissional no mesmo binário.</td>
      <td>Aplicativos separados (App Cliente vs. App Profissional).</td>
      <td>Fluxos segregados sem herança instantânea de reputação.</td>
      <td>Não aplicável.</td>
    </tr>
    <tr>
      <td><strong>11. Reputação Imune a Retaliação</strong></td>
      <td><span class="badge-ok">DOUBLE-BLIND 48H</span><br/>Notas ocultas por 48h + <code>ReviewTags</code> estruturadas + 6 Emblemas.</td>
      <td>Avaliação unilateral aberta sujeita a atrito e perfis não pagos.</td>
      <td>Avaliação simples sem blindagem duplo-cega simétrica.</td>
      <td>Fofoca informal não auditável em grupos de condomínio.</td>
    </tr>
    <tr>
      <td><strong>12. Atendimento de Emergência SOS</strong></td>
      <td><span class="badge-ok">SLA &lt; 60 SEGUNDOS</span><br/>Despacho prioritário <em>Tiered Waterfall</em> + rota OSRM ao vivo (<code>80%</code> mapa).</td>
      <td>Lento (aguarda compra manual de moedas e negociação externa).</td>
      <td>Focado em agendamentos; baixa liquidez para sinistros imediatos.</td>
      <td>Horas ou dias aguardando retorno de conhecidos ocupados.</td>
    </tr>
    <tr>
      <td><strong>13. Gamificação de Carreira e Retenção</strong></td>
      <td><span class="badge-ok">112 MEDALHAS REAIS</span><br/>90 do Profissional + 22 do Cliente (<code>#CBD5E1</code> bloqueadas &rarr; ligas metálicas).</td>
      <td>Inexistente (foco punitivo em consumo de pacotes de moedas).</td>
      <td>Inexistente.</td>
      <td>Inexistente.</td>
    </tr>
    <tr>
      <td><strong>14. Soberania e Portabilidade LGPD</strong></td>
      <td><span class="badge-ok">DOSSIÊ PDF ESCOPADO</span><br/>Exclusão granular (<code>client|provider|all</code>) + PDF com <code>total_saved</code> e <code>total_profit</code>.</td>
      <td>Exclusão destrutiva total sem dossiê contábil-reputacional PDF.</td>
      <td>Sem portabilidade estruturada de economia comparativa aferida.</td>
      <td>Histórico disperso e irrecuperável em conversas apagadas.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.4: PESQUISA EMPÍRICA COM O PÚBLICO-ALVO E ESTATÍSTICAS          -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-4" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 2.4 &bull; METODOLOGIA CIENTÍFICA DE CAMPO E ESTATÍSTICA DESCRITIVA BILATERAL</span>
  <h2>2.4. Pesquisa Empírica com o Público-Alvo e Apresentação Estatística dos Resultados</h2>
  <p>Investigação empírica estruturada junto aos dois polos do mercado (Moradores Contratantes e Prestadores Autônomos/MEIs): desenho amostral, protocolo anti-viés, tabelas de distribuição de frequências e inferências norteadoras de produto.</p>
</div>

<h3 id="sec-2-4-1">2.4.1. Desenho Metodológico, Amostragem Estratificada (<span class="mono">N = 46</span>) e Instrumentos de Coleta</h3>
<p>
  Para fundamentar cientificamente a engenharia de requisitos e o modelo de negócios, executou-se uma pesquisa aplicada de natureza exploratório-descritiva com abordagem mista (quanti-qualitativa) direcionada simultaneamente às duas faces do mercado (<em>Two-Sided Customer Discovery</em>). A estruturação do instrumento seguiu rigorosamente os preceitos metodológicos de <strong>Rob Fitzpatrick (<em>The Mom Test</em>)</strong> e <strong>Steve Blank (<em>Customer Development</em>)</strong>: foram vedadas perguntas hipotéticas indutoras de falso positivo (como <em>"você usaria um aplicativo seguro de reparos?"</em>), priorizando-se a mensuração de fatos comportamentais ocorridos nos últimos 12 meses, canais efetivamente acionados, perdas financeiras sofridas e barreiras concretas de adoção.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="25%">Parâmetro Metodológico</th>
      <th width="75%">Especificação Científica Aplicada no Levantamento Empírico</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Universo e Unidade Amostral</strong></td>
      <td>População urbana economicamente ativa residente em centros urbanos brasileiros (Estrato A: responsáveis pela gestão e contratação de serviços domiciliares em casas e apartamentos; Estrato B: trabalhadores autônomos e Microempreendedores Individuais atuantes em manutenção predial, instalações técnicas e conservação).</td>
    </tr>
    <tr>
      <td><strong>Dimensionamento e Estratificação (<span class="mono">N = 46</span>)</strong></td>
      <td>Amostra total validada de <strong><code>N = 46</code> respondentes únicos auditados</strong>, após higienização de respostas incompletas, composta por:<br/>
      &bull; <strong>Estrato Demanda — Moradores / Clientes (<code>n<sub>1</sub> = 28</code>; <code>60,87%</code> da amostra global):</strong> proprietários residentes, inquilinos urbanos e gestores domésticos.<br/>
      &bull; <strong>Estrato Oferta — Prestadores Autônomos / MEIs (<code>n<sub>2</sub> = 18</code>; <code>39,13%</code> da amostra global):</strong> eletricistas, encanadores, técnicos de refrigeração, montadores, pintores, maridos de aluguel e profissionais de limpeza.</td>
    </tr>
    <tr>
      <td><strong>Instrumentos de Mensuração</strong></td>
      <td>Questionários digitais estruturados com ramificação condicional por papel transacional (contendo questões fechadas de resposta única, matrizes de múltipla escolha hierarquizada e escalas psicométricas ordinais de Likert de 5 pontos), complementados por entrevistas semiestruturadas em profundidade para mapeamento qualitativo de incidentes críticos.</td>
    </tr>
    <tr>
      <td><strong>Tratamento Estatístico e Inferencial</strong></td>
      <td>Tabulação cruzada de frequências absolutas (<span class="math-inline">f<sub>i</sub></span>), frequências relativas percentuais (<span class="math-inline">f<sub>r</sub>% = 100 &middot; f<sub>i</sub> / n<sub>k</sub></span>), frequências acumuladas (<span class="math-inline">F<sub>a</sub>%</span>) e estimação de intervalos de confiança binomiais exatos pelo <strong>Método de Score de Wilson a 95% (<span class="mono">z = 1,96</span>)</strong> — apropriado para amostras finitas e proporções extremas próximas a <code>100%</code> (como a rejeição unânime <code>18/18</code> a moedas de lead, cujo limite inferior de Wilson a 95% supera <code>82,4%</code>, e a aprovação <code>26/28 = 92,9%</code> à custódia garantida, com IC 95% de Wilson em <code>[77,4%; 98,0%]</code>).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-4-2">2.4.2. Resultados Estatísticos do Estrato A — Moradores e Contratantes (<span class="mono">n₁ = 28</span>)</h3>
<p>
  A tabulação dos dados coletados junto aos moradores revela um fenômeno contundente: embora <code>100%</code> dos respondentes utilizem diariamente smartphones, mensageiros instantâneos e pagamentos via Pix, <strong><code>96,4%</code> (soma das parcelas arredondadas de <code>78,6%</code> + <code>17,9%</code> = <code>96,5%</code> nos relatórios síntese, equivalente a <code>27 em 28</code> domicílios) permanecem aprisionados a canais informais analógicos</strong> na hora de contratar um reparo residencial, rejeitando os aplicativos tradicionais existentes em razão da insegurança física e da ausência de responsabilização pós-serviço.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="28%">Eixo Investigado (Moradores, <span class="mono">n₁ = 28</span>)</th>
      <th width="42%">Categoria de Resposta Observada</th>
      <th width="10%">Freq. Abs. (<span class="mono">fᵢ</span>)</th>
      <th width="10%">Freq. Rel. (<span class="mono">fᵣ%</span>)</th>
      <th width="10%">Freq. Acum. (<span class="mono">Fₐ%</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="3"><strong>1. Canal Predominante Atual de Busca e Contratação</strong><br/>(Resposta única principal)</td>
      <td>Indicação direta ("boca a boca") de amigos, vizinhos ou familiares</td>
      <td>22</td>
      <td><code>78,6%</code></td>
      <td><code>78,6%</code></td>
    </tr>
    <tr>
      <td>Grupos informais de WhatsApp / Facebook de condomínio ou bairro</td>
      <td>5</td>
      <td><code>17,9%</code></td>
      <td><code>96,4%</code></td>
    </tr>
    <tr>
      <td>Aplicativos tradicionais de classificados de serviços (GetNinjas, Triider, etc.)</td>
      <td>1</td>
      <td><code>3,6%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td rowspan="4"><strong>2. Principal Barreira e Fator Gerador de Ansiedade / Dor</strong><br/>(Múltipla menção / dor crítica)</td>
      <td>Medo e insegurança física de admitir um desconhecido não verificado dentro da residência</td>
      <td>17</td>
      <td><code>60,7%</code></td>
      <td>—</td>
    </tr>
    <tr>
      <td>Ausência de garantia real pós-serviço e receio de abandono / vício recorrente</td>
      <td>15</td>
      <td><code>53,6%</code></td>
      <td>—</td>
    </tr>
    <tr>
      <td>Opacidade de preços e suspeita de sobrepreço abusivo em peças e materiais</td>
      <td>13</td>
      <td><code>46,4%</code></td>
      <td>—</td>
    </tr>
    <tr>
      <td>Impontualidade crônica ("bolo" no horário agendado) e demora em emergências SOS</td>
      <td>11</td>
      <td><code>39,3%</code></td>
      <td>—</td>
    </tr>
    <tr>
      <td rowspan="3"><strong>3. Categorias de Maior Demanda e Recorrência Anual</strong><br/>(Demanda principal últimos 12m)</td>
      <td>Limpeza, diarista e conservação residencial (sendo <code>12/28 = 42,9%</code> em regime recorrente semanal/mensal)</td>
      <td>16</td>
      <td><code>57,1%</code></td>
      <td><code>57,1%</code></td>
    </tr>
    <tr>
      <td>Reparos técnicos e pequenas reformas (Elétrica, Hidráulica, Climatização, Montagem e Pintura)</td>
      <td>11</td>
      <td><code>39,3%</code></td>
      <td><code>96,4%</code></td>
    </tr>
    <tr>
      <td>Outros serviços pontuais especializados (Chaveiro emergencial, Desentupimento, Dedetização)</td>
      <td>1</td>
      <td><code>3,6%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td rowspan="2"><strong>4. Aderência à Custódia Condicionada (<em>Escrow</em>) e Garantia Estruturada</strong></td>
      <td>Aprovam integralmente e priorizariam plataforma com retenção segura do pagamento até conclusão + garantia contra danos</td>
      <td>26</td>
      <td><code>92,9%</code></td>
      <td><code>92,9%</code></td>
    </tr>
    <tr>
      <td>Indiferentes ou preferem manter pagamento direto em espécie/Pix sem intermediação</td>
      <td>2</td>
      <td><code>7,1%</code></td>
      <td><code>100,0%</code></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-4-3">2.4.3. Resultados Estatísticos do Estrato B — Prestadores Autônomos e MEIs (<span class="mono">n₂ = 18</span>)</h3>
<p>
  No polo ofertante, os dados empíricos refutam o mito de que o trabalhador autônomo brasileiro seja avesso à formalização digital: pelo contrário, os profissionais buscam ativamente expansão de carteira, mas foram financeiramente vitimados pelo modelo de cobrança antecipada por <em>lead</em>. Observa-se uma <strong>rejeição absoluta de <code>100,0%</code> (<code>18 em 18</code> profissionais)</strong> à compra prévia de pacotes de moedas sem garantia de fechamento do serviço.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="28%">Eixo Investigado (Prestadores, <span class="mono">n₂ = 18</span>)</th>
      <th width="42%">Categoria de Resposta Observada</th>
      <th width="10%">Freq. Abs. (<span class="mono">fᵢ</span>)</th>
      <th width="10%">Freq. Rel. (<span class="mono">fᵣ%</span>)</th>
      <th width="10%">Freq. Acum. (<span class="mono">Fₐ%</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2"><strong>1. Dependência Econômica da Atividade Técnica</strong></td>
      <td>Fonte de renda principal e sustento primário do núcleo familiar (dedicação integral)</td>
      <td>10</td>
      <td><code>55,6%</code></td>
      <td><code>55,6%</code></td>
    </tr>
    <tr>
      <td>Complementação de renda familiar nos turnos livres e finais de semana (<em>side-income</em> qualificado)</td>
      <td>8</td>
      <td><code>44,4%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td rowspan="2"><strong>2. Posicionamento perante Venda Antecipada de Moedas / Desbloqueio de Leads</strong></td>
      <td>Rejeitam categoricamente pagar adiantado por contato sem certeza de contratação (aceitam apenas comissão no sucesso)</td>
      <td>18</td>
      <td><code>100,0%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td>Consideram aceitável comprar pacotes antecipados de moedas virtuais</td>
      <td>0</td>
      <td><code>0,0%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td rowspan="4"><strong>3. Principal Frustração Financeira e Operacional</strong><br/>(Dor dominante declarada)</td>
      <td>Prejuízo direto com "clientes fantasmas" / curiosos que não respondem após gasto em plataformas legadas</td>
      <td>10</td>
      <td><code>55,6%</code></td>
      <td><code>55,6%</code></td>
    </tr>
    <tr>
      <td>Inadimplência ("calote"), atraso no pagamento ou pechincha coercitiva após o serviço já concluído</td>
      <td>4</td>
      <td><code>22,2%</code></td>
      <td><code>77,8%</code></td>
    </tr>
    <tr>
      <td>Incidência injusta de comissão de aplicativos sobre o valor de peças e materiais comprados do próprio bolso</td>
      <td>3</td>
      <td><code>16,7%</code></td>
      <td><code>94,4%</code></td>
    </tr>
    <tr>
      <td>Ociosidade de agenda entre indicações esporádicas e deslocamentos urbanos longos</td>
      <td>1</td>
      <td><code>5,6%</code></td>
      <td><code>100,0%</code></td>
    </tr>
    <tr>
      <td rowspan="2"><strong>4. Disposição de Adesão ao Modelo <em>Smart Split</em> + <em>Smart Escrow</em> (<code>0%</code> Peças)</strong></td>
      <td>Adeririam imediatamente submetendo documentos para KYC biométrico em troca de orçamento grátis e pagamento garantido</td>
      <td>17</td>
      <td><code>94,4%</code></td>
      <td><code>94,4%</code></td>
    </tr>
    <tr>
      <td>Necessitariam auxílio assistido inicial para emissão ou anexo de comprovantes fiscais de peças</td>
      <td>1</td>
      <td><code>5,6%</code></td>
      <td><code>100,0%</code></td>
    </tr>
  </tbody>
</table>

${svgPesquisaPublicoAlvo}

<p>
  <strong>Síntese Inferencial da Pesquisa Empírica:</strong> A triangulação estatística entre <span class="math-inline">n<sub>1</sub> = 28</span> e <span class="math-inline">n<sub>2</sub> = 18</span> demonstra que o mercado não carece de demanda nem de oferta técnica, mas sim de uma <strong>camada institucional de confiança bilateral</strong>. A convergência entre os <code>60,7%</code> de moradores travados pelo medo de desconhecidos, os <code>92,9%</code> favoráveis à custódia garantida e os <code>100,0%</code> de prestadores que repudiam a venda de moedas valida empiricamente os três pilares fundacionais do Desperrengue: (i) KYC Zero-Trust com bloqueio geoespacial temporal, (ii) gratuidade integral na fase de cotação e (iii) liquidação via <em>Smart Escrow</em> com isenção total sobre materiais (<em>Smart Split</em>).
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.5: CONSTRUÇÃO E ANÁLISE PROFUNDA DO MAPA DE EMPATIA             -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-5" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 2.5 &bull; ENGENHARIA COGNITIVA DE USUÁRIOS E DESIGN CENTRADO NO HUMANO</span>
  <h2>2.5. Construção e Análise Profunda do Mapa de Empatia Bilateral</h2>
  <p>Dissecação analítica exaustiva dos seis quadrantes canônicos de Dave Gray / XPLANE e Osterwalder para a Persona Cliente (Moradora) e para a Persona Profissional (Prestador Autônomo / MEI).</p>
</div>

<p>
  Enquanto a estatística descritiva quantifica a magnitude das dores de mercado, o <strong>Mapa de Empatia</strong> (concebido originalmente por Dave Gray na XPLANE e integrado por Osterwalder &amp; Pigneur à metodologia de geração de modelos de negócio) decodifica os mecanismos cognitivos, sensoriais, sociais e emocionais que governam a tomada de decisão real sob estresse. Em um ecossistema de dois lados (<em>two-sided marketplace</em>), construir o Mapa de Empatia apenas para o consumidor pagante produziria um sistema unilateral fadado à escassez de oferta; impõe-se, portanto, a modelagem simétrica das duas personas arquetípicas extraídas da pesquisa empírica.
</p>

<h3 id="sec-2-5-1">2.5.1. Mapa de Empatia — Persona A: Moradora Contratante (Mariana, 34 anos, Residente Urbana)</h3>
<p>
  <strong>Perfil Arquetípico Sintetizado:</strong> Mariana, 34 anos, analista sênior em regime de trabalho híbrido, reside em apartamento urbano (próprio financiado ou locado sob a Lei nº 8.245/1991). Possui elevada literacia digital para serviços financeiros (Pix, bancos digitais) e mobilidade/entrega, porém sente profunda vulnerabilidade técnica e física quando um disjuntor desarma com cheiro de queimado, um sifão rompe sob a bancada ou o aparelho de ar-condicionado para de refrigerar em plena semana útil.
</p>

${svgMapaEmpatiaCliente}

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Quadrante do Mapa (Persona Cliente)</th>
      <th width="78%">Dissecação Analítica Profunda e Implicação Direta de Engenharia no Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. O que PENSA e SENTE?</strong><br/>(Preocupações internas, tensões emocionais e receios velados)</td>
      <td>
        &bull; <em>Ansiedade de Segurança Pessoal:</em> questionamento interno constante sobre a segurança de franquear a entrada do apartamento a um desconhecido localizado na internet enquanto permanece desacompanhada, somado ao temor de exposição do endereço e da rotina doméstica a terceiros mal-intencionados.<br/>
        &bull; <em>Assimetria Técnica e Medo de Engodo:</em> percepção aguda de vulnerabilidade informacional perante diagnósticos de elétrica ou refrigeração, receando a indução à troca desnecessária de componentes onerosos.<br/>
        &bull; <em>Tensão de Tempo e Produtividade:</em> incompatibilidade entre agendas corporativas críticas em trabalho remoto e a perda de turnos inteiros aguardando prestadores que descumprem janelas combinadas ou abandonam o agendamento.
      </td>
    </tr>
    <tr>
      <td><strong>2. O que VÊ?</strong><br/>(Ambiente imediato, ofertas existentes e sinais visuais)</td>
      <td>
        &bull; Dezenas de mensagens desencontradas no grupo de WhatsApp do condomínio com telefones soltos sem foto, sem CNPJ e sem comprovação atualizada de qualidade.<br/>
        &bull; Aplicativos legados exibindo perfis genéricos com avaliações antigas não vinculadas a pagamentos comprovados e anúncios invasivos.<br/>
        &bull; O dano físico progredindo no imóvel (infiltração manchando a marcenaria, alimentos descongelando) enquanto aguarda retornos evasivos e sem compromisso formal de horário.
      </td>
    </tr>
    <tr>
      <td><strong>3. O que OUVE?</strong><br/>(Influências de pares, família, síndicos e mídia)</td>
      <td>
        &bull; Relatos recorrentes de vizinhos e familiares sobre "orçamentos que dobraram de preço no meio do serviço" ou "adiantamentos de 50% via Pix seguidos de bloqueio no WhatsApp".<br/>
        &bull; Noticiários policiais alertando sobre golpes e furtos residenciais praticados por falsos prestadores sem triagem de identidade.<br/>
        &bull; Exigências da imobiliária ou do síndico cobrando nota fiscal, conformidade técnica e comprovante formal de manutenção para cobertura de seguro predial.
      </td>
    </tr>
    <tr>
      <td><strong>4. O que FALA e FAZ?</strong><br/>(Comportamento observável, discurso público e paleativos)</td>
      <td>
        &bull; Pede indicações urgentes a três ou quatro contatos de confiança antes de arriscar qualquer busca aberta (comportamento confirmado por <code>78,6%</code> da amostra).<br/>
        &bull; Tenta gravar vídeos curtos ou tirar fotos do defeito no celular para evitar visitas presenciais meramente especulativas, mas hesita em enviar sua localização exata.<br/>
        &bull; Adia pequenos reparos preventivos por meses devido à fricção de busca, até que o defeito escale para um sinistro emergencial (SOS) muito mais dispendioso.
      </td>
    </tr>
    <tr>
      <td><strong>5. DORES</strong><br/>(Medos concretos, frustrações e obstáculos transacionais)</td>
      <td>
        &bull; <strong>Exposição prematura de dados residenciais</strong> (logradouro, número do apartamento e metadados GPS) para múltiplos desconhecidos durante a cotação.<br/>
        &bull; <strong>Risco financeiro unilateral:</strong> pagar antes e receber serviço malfeito, ou ficar refém de cobrança abusiva sobre peças sem nota fiscal.<br/>
        &bull; <strong>Orfandade pós-entrega:</strong> se o vazamento retornar 10 dias depois, não há canal institucional que assegure reexecução gratuita ou ressarcimento imediato.
      </td>
    </tr>
    <tr>
      <td><strong>6. GANHOS / NECESSIDADES</strong><br/>(Critérios reais de sucesso, alívio e valor superavitário)</td>
      <td>
        &bull; <strong>Certeza de Identidade Zero-Trust:</strong> saber que o profissional teve documento oficial ICP-Brasil e biometria facial validados antes de pisar no condomínio.<br/>
        &bull; <strong>Previsibilidade Financeira e Custódia:</strong> pagar via Pix para uma conta protegida (<em>Smart Escrow</em>) sabendo que o dinheiro só é liberado mediante seu PIN de 4 dígitos após testar o reparo.<br/>
        &bull; <strong>Patrimônio Documentado:</strong> receber automaticamente o Passaporte Predial <strong>ABNT NBR 5674</strong> em PDF assinado, valorizando o imóvel e blindando vistorias locatícias.
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-5-2">2.5.2. Mapa de Empatia — Persona B: Prestador Autônomo / MEI (Carlos Eduardo, 38 anos, Técnico Especialista)</h3>
<p>
  <strong>Perfil Arquetípico Sintetizado:</strong> Carlos Eduardo, 38 anos, técnico em eletrotécnica e climatização com certificação NR-10 ativa e registro MEI regularizado. Possui mais de 12 anos de experiência prática, investiu milhares de reais em ferramentas de precisão (multímetro True-RMS, bomba de vácuo, manifold digital), sustenta sua família com seu ofício (representando os <code>55,6%</code> de renda principal) e busca agenda previsível em um raio próximo à sua base operacional, sem ser explorado por intermediários predatórios.
</p>

${svgMapaEmpatiaProfissional}

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Quadrante do Mapa (Persona Profissional)</th>
      <th width="78%">Dissecação Analítica Profunda e Implicação Direta de Engenharia no Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. O que PENSA e SENTE?</strong><br/>(Orgulho técnico, indignação econômica e insegurança de caixa)</td>
      <td>
        &bull; <em>Indignação contra Pedágios de Lead:</em> revolta recorrente ao contabilizar perdas semanais superiores a <code>R$ 120,00</code> na compra de moedas virtuais em aplicativos legados para desbloquear contatos de solicitantes que sequer visualizam as mensagens enviadas, equiparando o modelo a um jogo de azar contra quem produz.<br/>
        &bull; <em>Senso de Dignidade e Mérito:</em> frustração profissional por deter formação normativa rigorosa e entregar acabamento durável, mas ver seu trabalho nivelado por baixo em diretórios abertos ao lado de executores improvisados que subprecificam ignorando normas de segurança.<br/>
        &bull; <em>Receio de Calote e Segurança em Campo:</em> apreensão financeira diante da necessidade de desembolsar <code>R$ 400,00</code> ou mais em materiais do próprio giro sob o risco de desistência unilateral ou recusa de pagamento ao término da intervenção.
      </td>
    </tr>
    <tr>
      <td><strong>2. O que VÊ?</strong><br/>(Realidade diária de campo, concorrência e custos)</td>
      <td>
        &bull; Leilões predatórios de preço mínimo em redes sociais e plataformas antigas onde o mesmo chamado é disputado no escuro por meia dúzia de pessoas.<br/>
        &bull; Aumento constante nos preços de combustível, peças elétricas/hidráulicas e deslocamento improdutivo atravessando a cidade apenas para "dar uma olhada" sem fechar negócio.<br/>
        &bull; Plataformas que cobram comissão pesada sobre o valor total da nota, devorando sua margem sempre que precisa fornecer peças originais de reposição.
      </td>
    </tr>
    <tr>
      <td><strong>3. O que OUVE?</strong><br/>(Colegas de profissão, lojistas de materiais e clientes)</td>
      <td>
        &bull; Colegas no balcão das lojas de material elétrico alertando: <em>"Não coloque crédito naquele aplicativo de moedas, é dinheiro jogado fora com curioso"</em> (corroborado por <code>100,0%</code> de rejeição na pesquisa).<br/>
        &bull; Clientes desconfiados fazendo dezenas de perguntas defensivas na portaria por já terem sofrido experiências traumáticas anteriores com falsos técnicos.<br/>
        &bull; Contadores e o Sebrae recomendando profissionalizar a emissão de orçamentos e separar faturamento de serviço do reembolso de mercadorias.
      </td>
    </tr>
    <tr>
      <td><strong>4. O que FALA e FAZ?</strong><br/>(Rotina operacional, precificação e relacionamento)</td>
      <td>
        &bull; Sobrevive majoritariamente da carteira antiga de clientes fiéis e de indicações lentas, enfrentando semanas de agenda ociosa intercaladas com picos impossíveis de atender sozinho.<br/>
        &bull; Pede fotos e vídeos pelo celular para diagnosticar previamente o problema e levar as peças corretas na maleta já na primeira viagem.<br/>
        &bull; Registra fotos do "antes e depois" do quadro elétrico organizado para provar seu capricho técnico e evitar acusações injustas.
      </td>
    </tr>
    <tr>
      <td><strong>5. DORES</strong><br/>(Perdas financeiras diretas, atritos e compressão de margem)</td>
      <td>
        &bull; <strong>Sangria de caixa com "clientes fantasmas"</strong> e taxas de adesão/desbloqueio sem receita correspondente (apontada como dor nº 1 por <code>55,6%</code> dos prestadores).<br/>
        &bull; <strong>Confisco de margem em materiais</strong> quando comissões incidem sobre insumos adquiridos pelo próprio profissional.<br/>
        &bull; <strong>Risco de inadimplência pós-execução</strong>, avaliações injustas retaliatórias e impossibilidade de comprovar publicamente sua excelência técnica para novos moradores do bairro.
      </td>
    </tr>
    <tr>
      <td><strong>6. GANHOS / NECESSIDADES</strong><br/>(Alavancas de renda, proteção de giro e prestígio)</td>
      <td>
        &bull; <strong>Orçamento 100% Gratuito (Risco Zero de Aquisição):</strong> enviar propostas detalhadas sem desembolsar um único centavo adiantado.<br/>
        &bull; <strong>Isenção Integral sobre Peças (<code>0%</code> no <em>Smart Split</em>) + Certeza de Liquidação:</strong> iniciar o deslocamento apenas quando o valor já se encontra depositado no <em>Smart Escrow</em> e receber integralmente o reembolso dos insumos.<br/>
        &bull; <strong>Capital Reputacional Verificável:</strong> acumular medalhas oficiais (dentre as <strong>90 medalhas de carreira profissional</strong>) e emblemas como <em>Super Profissional</em> e <em>Mestre no que faz</em>, justificando honorários superiores pela qualidade comprovada.
      </td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 2.6: OPORTUNIDADE DE NEGÓCIO E ENGENHARIA DE PROPOSTA DE VALOR    -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-2-6" style="margin-top: 14px;">
  <span class="sh-tag">SEÇÃO 2.6 &bull; VALUE PROPOSITION CANVAS, DADOS MACROECONÔMICOS E TAM / SAM / SOM</span>
  <h2>2.6. Oportunidade de Negócio e Engenharia de Proposta de Valor</h2>
  <p>Modelagem completa do Value Proposition Canvas (Osterwalder et al., 2014) articulando Perfil do Cliente (Tarefas, Dores e Ganhos) e Mapa de Valor (Produtos/Serviços, Criadores de Ganho e Aliviadores de Dores), seguida da demonstração empírica de oportunidade de mercado (IBGE, Sebrae, BACEN, ANAMACO/CBIC) e cálculo econométrico de TAM, SAM e SOM.</p>
</div>

<p>
  O encaixe Problema-Solução (<em>Problem-Solution Fit</em>) e Produto-Mercado (<em>Product-Market Fit</em>) no ecossistema Desperrengue estrutura-se segundo a arquitetura formal do <strong>Value Proposition Canvas</strong> (Osterwalder, Pigneur, Bernarda &amp; Smith, 2014). Cada componente tecnológico codificado na versão <code>v2.11.0</code> mapeia biunivocamente uma tarefa, dor ou ganho empiricamente verificado nas Seções 2.4 e 2.5, conforme ilustrado no diagrama vetorial a seguir e detalhado exaustivamente nas oito subseções normativas subsequentes.
</p>

${svgValuePropositionCanvas}

<h3 id="sec-2-6-1">2.6.1. Descrição do Perfil do Cliente — TAREFAS (<em>Customer Jobs-to-be-Done</em>)</h3>
<p>
  Fundamentando-se na <em>Jobs-to-be-Done Theory</em> (Christensen et al., 2016), os usuários não contratam meramente um aplicativo, mas buscam executar com sucesso tarefas funcionais, sociais, emocionais e de apoio em seu cotidiano doméstico e profissional. A tabela abaixo especifica integralmente as tarefas em ambas as perspectivas do ecossistema bilateral.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="18%">Natureza da Tarefa</th>
      <th width="41%">Perspectiva do Morador / Contratante (Demanda)</th>
      <th width="41%">Perspectiva do Profissional / Prestador (Oferta)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Tarefas Funcionais</strong><br/>(Problemas práticos e operacionais objetivos a resolver)</td>
      <td>
        &bull; Diagnosticar e restabelecer imediatamente sistemas críticos interrompidos (curto-circuito elétrico, vazamento hidráulico, rompimento de fechadura, pane de refrigeração) via chamado SOS ou agendamento.<br/>
        &bull; Contratar serviços recorrentes de conservação, limpeza e manutenção preventiva dentre <strong>33 especialidades</strong> com escopo claro e preço fechado.<br/>
        &bull; Separar contabilmente o custo de peças de reposição da remuneração de mão de obra e arquivar notas fiscais e laudos técnicos exigidos pela <strong>ABNT NBR 5674</strong> e contratos de locação (Lei nº 8.245/1991).
      </td>
      <td>
        &bull; Captar chamados reais geolocalizados próximos à sua base operacional sem desperdiçar capital em anúncios incertos ou moedas de desbloqueio.<br/>
        &bull; Avaliar previamente o escopo técnico por mídia assíncrona (fotos higienizadas, áudio/vídeo e triagem estruturada) para dimensionar ferramentas, tempo e lista de materiais antes de sair a campo.<br/>
        &bull; Emitir orçamentos discriminados (mão de obra vs. insumos), executar o reparo dentro das normas técnicas e liquidar o recebimento via Pix com conciliação imediata.
      </td>
    </tr>
    <tr>
      <td><strong>Tarefas Sociais</strong><br/>(Percepção perante família, condomínio, clientes e mercado)</td>
      <td>
        &bull; Demonstrar zelo, prudência e responsabilidade perante cônjuge, filhos, síndico e portaria condominial ao autorizar apenas a entrada de prestadores documentalmente auditados.<br/>
        &bull; Comprovar perante proprietários, imobiliárias ou futuros compradores que o imóvel recebeu manutenção criteriosa com peças originais e profissionais habilitados.
      </td>
      <td>
        &bull; Ser reconhecido socialmente como especialista técnico certificado de alto padrão — e não como mão de obra informal precarizada.<br/>
        &bull; Exibir credenciais verificadas (emblemas <em>Super Profissional</em>, <em>Sempre Pontual</em>, <em>Mestre no que faz</em> e mural público de medalhas) que legitimem honorários compatíveis com sua qualificação.
      </td>
    </tr>
    <tr>
      <td><strong>Tarefas Emocionais</strong><br/>(Estados psicológicos de segurança, paz de espírito e autonomia)</td>
      <td>
        &bull; Sentir tranquilidade física absoluta dentro do próprio lar, livre do medo de invasão de privacidade ou exposição de endereço residencial na internet.<br/>
        &bull; Eliminar a sensação de impotência e vulnerabilidade perante jargões técnicos, cobranças surpresa ou abandono de serviço inacabado.
      </td>
      <td>
        &bull; Trabalhar com segurança financeira e previsibilidade de renda familiar, sabendo que o valor acordado já está caucionado antes do deslocamento.<br/>
        &bull; Sentir justiça distributiva ao ter <code>100%</code> do valor gasto em peças reembolsado sem confisco de comissão da plataforma.
      </td>
    </tr>
    <tr>
      <td><strong>Tarefas de Apoio</strong><br/>(Comparação, cocriação e encerramento de ciclo)</td>
      <td>
        &bull; Comparar propostas estruturadas lado a lado (preço, prazo, índice <code>RTS</code> e medalhas), aprovar aditivos eventuais, liberar o pagamento por PIN presencial e avaliar o atendimento de forma isenta (<em>double-blind review</em>).
      </td>
      <td>
        &bull; Gerenciar carteira digital auditável, anexar chave NF-e de 44 dígitos para isenção de peças, alternar para o modo Cliente quando necessitar de serviços em sua própria casa e portar seu dossiê de carreira.
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-6-2">2.6.2. Descrição do Perfil do Cliente — DORES (<em>Customer Pains</em>: Pré-Serviço, Transacionais e Pós-Serviço)</h3>
<p>
  A análise das fricções revela que o risco nos serviços residenciais não é pontual, mas distribui-se ao longo de toda a linha temporal da transação. A classificação cronológica abaixo abrange 100% das dores críticas identificadas na literatura microeconômica e no levantamento empírico de campo.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="17%">Fase Cronológica</th>
      <th width="42%">Dores Estruturais do Morador (Cliente)</th>
      <th width="41%">Dores Estruturais do Prestador (Profissional)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Fase 1: Pré-Serviço</strong><br/>(Descoberta, Triagem, Cotação e Agendamento)</td>
      <td>
        &bull; <strong>Vazamento Prematuro de Localização (Severidade Crítica):</strong> obrigação de revelar rua, número, bloco/apartamento e coordenadas GPS em fotos para múltiplos estranhos que apenas enviam orçamento e não são contratados.<br/>
        &bull; <strong>Assimetria Cega de Identidade (<code>60,7%</code> na pesquisa):</strong> impossibilidade de verificar autenticidade de CNH/CIN, biometria facial e histórico real do indivíduo.<br/>
        &bull; <strong>Lentidão em Emergências SOS:</strong> horas de espera em grupos informais enquanto um vazamento ou pane elétrica agrava o prejuízo.<br/>
        &bull; <strong>Orçamentos Incomparáveis:</strong> propostas verbais vagas sem distinção entre serviço e peças.
      </td>
      <td>
        &bull; <strong>Pedágio Financeiro sem Retorno (<code>100%</code> de rejeição / <code>55,6%</code> de prejuízo real):</strong> perda direta de recursos comprando moedas para desbloquear contatos frios ou "clientes fantasmas".<br/>
        &bull; <strong>Visitas Improdutivas de Orçamento:</strong> gasto de horas de trânsito e combustível apenas para diagnosticar presencialmente defeitos mal descritos que não convertem em contratação.<br/>
        &bull; <strong>Guerra Predatória de Preços Cegos:</strong> competição desleal contra perfis falsos ou desqualificados que subprecificam por ignorarem normas de segurança.
      </td>
    </tr>
    <tr>
      <td><strong>Fase 2: Transacional / Durante o Serviço</strong><br/>(Execução em Campo, Materiais e Liquidação)</td>
      <td>
        &bull; <strong>Vulnerabilidade Física Domiciliar:</strong> tensão ao permanecer desacompanhado no imóvel com terceiros não auditados.<br/>
        &bull; <strong>Inflação Oportunista de Escopo e Peças:</strong> exigência de valores adicionais arbitrários com a instalação desmontada ("efeito refém" / <em>hold-up problem</em>) e aplicação de componentes paralelos cobrados como originais.<br/>
        &bull; <strong>Dilema do Adiantamento Pix:</strong> pagar antes e sofrer abandono da obra no meio da execução.
      </td>
      <td>
        &bull; <strong>Bitributação sobre Materiais:</strong> perda de até metade do lucro líquido quando plataformas cobram <code>20%–30%</code> sobre peças adquiridas pelo técnico para o reparo.<br/>
        &bull; <strong>Exposição de Capital de Giro Próprio:</strong> adiantar compra de componentes caros sem garantia de que o morador honrará o reembolso.<br/>
        &bull; <strong>Insegurança Pessoal em Chamados Noturnos:</strong> atender chamados em locais ermos sem registro institucional de contraparte verificada nem mecanismo anti-coação.
      </td>
    </tr>
    <tr>
      <td><strong>Fase 3: Pós-Serviço</strong><br/>(Garantia Legal, Reputação e Gestão Predial)</td>
      <td>
        &bull; <strong>Orfandade de Garantia Legal (<code>53,6%</code> na pesquisa):</strong> reaparecimento do defeito dias após o pagamento seguido de recusa de retorno ou bloqueio nos aplicativos de mensagem, frustrando os 90 dias do Art. 26, II do CDC.<br/>
        &bull; <strong>Retaliação em Avaliações Abertas:</strong> receio de atribuir nota baixa honesta a um prestador que já conhece seu endereço residencial.<br/>
        &bull; <strong>Perda Documental Crônica:</strong> extravio de notas e comprovantes, gerando glosas em seguros e disputas em vistorias de aluguel.
      </td>
      <td>
        &bull; <strong>Calote e Retenção Arbitrária (<code>22,2%</code> na pesquisa):</strong> conclusão técnica impecável seguida de recusa de pagamento, promessas protelatórias ou descontos forçados.<br/>
        &bull; <strong>Difamação Injusta ou Sabotagem:</strong> avaliações subjetivas sem direito de resposta estruturado ou cobrança por defeitos preexistentes fora do escopo contratado.<br/>
        &bull; <strong>Aprisionamento de Dados (<em>Vendor Lock-in</em>):</strong> impossibilidade de extrair histórico contábil e reputacional auditado caso deseje encerrar ou migrar um perfil.
      </td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-6-3">2.6.3. Descrição do Perfil do Cliente — GANHOS (<em>Customer Gains</em>: Essenciais, Esperados, Desejados e Inesperados)</h3>
<p>
  Em estrita observância à taxonomia de Osterwalder et al. (2014), os benefícios almejados pelos atores do mercado hierarquizam-se em quatro estratos evolutivos de geração de valor percebido:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="20%">Estrato de Ganho</th>
      <th width="40%">Ganhos para o Morador / Contratante</th>
      <th width="40%">Ganhos para o Prestador / Profissional</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Ganhos Essenciais</strong><br/>(<em>Required Gains</em> — condição mínima sine qua non)</td>
      <td>Identidade civil real do prestador comprovada antes do ingresso no domicílio; reparo técnico funcional que elimine efetivamente o defeito reportado; pagamento seguro sem risco de perda financeira por serviço não prestado.</td>
      <td>Envio de orçamentos sem qualquer custo antecipado; garantia absoluta de que o valor combinado existe e será pago integralmente após a execução correta; ausência de vínculo abusivo ou cobrança de mensalidade fixa.</td>
    </tr>
    <tr>
      <td><strong>2. Ganhos Esperados</strong><br/>(<em>Expected Gains</em> — padrão de excelência operacional)</td>
      <td>Interface fluida e intuitiva (<code>120 FPS</code>), pontualidade na janela agendada, clareza na separação entre preço de mão de obra e peças, comunicação centralizada e atendimento ágil em situações de emergência.</td>
      <td>Triagem prévia clara com fotos e descrição objetiva do defeito, roteamento geográfico inteligente que minimize deslocamentos vazios, saque via Pix sem burocracia e suporte humano ágil em caso de divergência.</td>
    </tr>
    <tr>
      <td><strong>3. Ganhos Desejados</strong><br/>(<em>Desired Gains</em> — diferenciais competitivos superiores)</td>
      <td>Cobertura real e acionável de garantia por 90 dias (inclusive com substituição por outro técnico ou ressarcimento pelo Fundo Garantidor caso o primeiro falhe); preservação do endereço oculto até o dia exato da visita; preços finais menores sem sobretaxa em peças.</td>
      <td>Alíquota de <strong><code>0,0%</code> sobre materiais e peças</strong> (preservando integralmente a margem da mão de obra); avaliações duplamente cegas (<em>double-blind</em> de 48h) imunes a retaliação; progressão de carreira visível com emblemas que aumentam a taxa de fechamento de orçamentos.</td>
    </tr>
    <tr>
      <td><strong>4. Ganhos Inesperados</strong><br/>(<em>Unexpected Gains</em> — inovações disruptivas além da expectativa)</td>
      <td>Emissão automática gratuita do <strong>Passaporte Predial ABNT NBR 5674</strong> em PDF assinado via <code>SHA-256</code> que valoriza o imóvel na venda/locação; sistema de conquistas do morador (22 medalhas); Dossiê LGPD calculando matematicamente o total em reais economizado em relação à média das demais propostas.</td>
      <td><strong>Herança instantânea de KYC Multi-Modo</strong> (<code>+30</code> unidades no índice <code>RTS</code>) para atuar nos dois polos com uma única conta; cofre biométrico com proteção anti-coação; Dossiê contábil-reputacional portável certificado em PDF vetorial a qualquer momento.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-6-4">2.6.4. Descrição da Proposta de Valor — PRODUTOS E SERVIÇOS (Catálogo Consolidado <span class="mono">v2.11.0</span>)</h3>
<p>
  O Mapa de Valor do Desperrengue materializa-se em um portfólio integrado de <strong>oito produtos e subsistemas computacionais</strong> operantes em produção, verificados por <code>762</code> testes automatizados Flutter, <code>64</code> testes Python no motor KYC, <code>27</code> migrações SQL canônicas e <code>17</code> testes de geração documental PDF:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="26%">Produto / Subsistema do Ecossistema</th>
      <th width="74%">Especificação Funcional e Fundamentação no Repositório (<span class="mono">app/lib/</span>, <span class="mono">supabase/</span> e <span class="mono">kyc_engine/</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Marketplace Dual-Mode de 33 Categorias</strong></td>
      <td>Plataforma mobile nativa (Android APK com atualização OTA) e Web (PWA responsivo em container de <code>480px</code>) cobrindo <strong>33 especialidades residenciais</strong> (Elétrica, Hidráulica, Ar-Condicionado, Chaveiro, Montagem, Marcenaria, Pintura, Alvenaria, Vidraçaria, Desentupimento, Limpeza, Jardinagem, Automação, Energia Solar, CFTV, entre outras em <code>marketplace_models.dart</code>) com iconografia vetorial <em>Duotone</em> exclusiva e chaveamento instantâneo Cliente &harr; Profissional.</td>
    </tr>
    <tr>
      <td><strong>2. Chamado SOS (<code>&lt; 60s</code>) e Agendado Multimodal (Voz/IA/Vídeo)</strong></td>
      <td>Fluxo duplo de contratação: despacho emergencial prioritário SOS com SLA de aceite inferior a 60 segundos para sinistros críticos, ou agendamento programado assistido por descrição guiada, gravação de áudio/vídeo curto e captura fotográfica com sanitização binária automática de metadados <code>EXIF/GPS</code> antes da transmissão.</td>
    </tr>
    <tr>
      <td><strong>3. <em>Smart Split Checkout</em> Fiscal</strong></td>
      <td>Motor de orçamentação e checkout que particiona algebricamente toda proposta em parcela de Mão de Obra (<code>V_MO</code>, sujeita ao <em>Take Rate</em> de intermediação) e parcela de Materiais/Peças (<code>V_Mat</code>, isenta a <code>0,0%</code> mediante validação de chave NF-e/NFC-e de 44 dígitos pelo algoritmo Módulo 11 + consulta SEFAZ ou recibo MEI auditado por ELA até <code>R$ 150,00</code>).</td>
    </tr>
    <tr>
      <td><strong>4. Custódia Fiduciária <em>Smart Escrow</em> Pix</strong></td>
      <td>Infraestrutura financeira transacional em centavos inteiros (<code>BIGINT</code>) integrada ao arranjo Pix do Banco Central via webhook autenticado (<code>pix-webhook</code>), mantendo <code>100%</code> do valor pago em conta segregada até a conclusão verificada do serviço em campo e validação presencial do PIN criptográfico de 4 dígitos.</td>
    </tr>
    <tr>
      <td><strong>5. Passaporte Predial PDF ABNT NBR 5674</strong></td>
      <td>Gerador vetorial assíncrono em <code>Isolate.run</code> (<code>%PDF-1.4</code>) que consolida o livro-razão técnico de cada imóvel atendido, emitindo certificado auditável com código <code>DSP-PASS-*</code> e hash <code>SHA-256</code> de conformidade à norma <strong>ABNT NBR 5674:2012</strong> para proprietários, condomínios, imobiliárias e seguradoras.</td>
    </tr>
    <tr>
      <td><strong>6. Motor KYC Biométrico Zero-Trust VIO/ICP-Brasil</strong></td>
      <td>Pipeline de verificação de identidade em 3 estágios: <em>Tier-0</em> local em <code>Isolate.run</code> (custo <code>R$ 0,00</code>), <em>Tier-1 Argon Vision Gate</em> (detecção óptica e OCR documental) e <em>Tier-2 Carbon Engine</em> em Python FastAPI (<code>kyc_engine/</code>) com decodificação criptográfica de QR Code VIO/SERPRO sob cadeia ICP-Brasil, <em>liveness</em> facial, cofre dual anti-coação e explicabilidade SHAP.</td>
    </tr>
    <tr>
      <td><strong>7. Sistema de Gamificação Bilateral de 112 Medalhas + 6 Emblemas</strong></td>
      <td>Arquitetura motivacional determinística composta por <strong>90 medalhas de carreira do Profissional</strong> (9 trilhas &times; 10 níveis em <code>achievements.dart</code>) e <strong>22 medalhas de jornada do Cliente</strong> (6 conquistas multinível em <code>client_achievements.dart</code>), renderizadas em prata neutra <code>#CBD5E1</code> quando bloqueadas e paleta metálica semântica quando conquistadas, somadas aos <strong>6 Emblemas Automáticos de Reputação</strong> (<code>ProviderBadge</code>).</td>
    </tr>
    <tr>
      <td><strong>8. Dossiê Portável LGPD e Exclusão Escopada</strong></td>
      <td>Serviço serverless (<code>supabase/functions/excluir-conta/dossie.ts</code>) de soberania de dados que emite relatório executivo e fiscal completo em PDF vetorial (contratos, lucro líquido do prestador, economia comparativa do morador e histórico de conquistas) acoplado à exclusão granular por papel (<code>client</code>, <code>provider</code> ou <code>all</code>).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-6-5">2.6.5. Descrição da Proposta de Valor — CRIADORES DE GANHO (<em>Gain Creators</em>)</h3>
<p>
  Os Criadores de Ganho especificam os mecanismos de engenharia econômica e de software pelos quais o Desperrengue entrega performance superior e benefícios financeiros mensuráveis aos dois lados da plataforma:
</p>
<ul>
  <li><strong>1. <em>Smart Split</em> com Alíquota de <code>0,0%</code> sobre Peças e Materiais:</strong> Ao isentar integralmente o repasse de insumos fiscalmente comprovados (<span class="math-inline">&tau;<sub>Mat</sub> = 0%</span>), o prestador preserva <code>100%</code> do seu capital de giro aplicado em componentes e elimina o repasse inflacionário defensivo ("gordura de taxa"), gerando economia direta de <code>12% a 18%</code> no preço final pago pelo morador em reparos intensivos em peças e neutralizando o incentivo econômico à negociação fora da plataforma.</li>
  <li><strong>2. Herança KYC Multi-Modo Instantânea (<code>+30</code> Unidades no Índice RTS):</strong> Usuários autenticados no ecossistema por meio do rigoroso KYC biométrico detêm identidade única verificada. Ao ativar o segundo papel na interface <em>Dual-Mode</em>, o sistema transfere instantaneamente o selo de verificação civil e concede o bônus basal de confiança de <code>30</code> unidades na escala <em>Reputation &amp; Trust Score</em> (<code>RTS</code>), eliminando retrabalho cadastral e acelerando a liquidez cruzada local.</li>
  <li><strong>3. Passaporte Predial ABNT NBR 5674 como Ativo Valorizador do Imóvel:</strong> Cada ordem concluída converte uma despesa de reparo em capital documental permanente. Na venda ou locação do bem, o proprietário apresenta um dossiê assinado digitalmente (<code>SHA-256</code>) comprovando revisões elétricas, hidráulicas e de climatização segundo a norma técnica brasileira, reduzindo assimetria na avaliação imobiliária e facilitando apólices de seguro residencial.</li>
  <li><strong>4. Mural de Conquistas Verificáveis (112 Medalhas + <code>BadgeWall</code>):</strong> Substitui estrelas subjetivas isoladas por telemetria objetiva auditada pelo banco de dados (pontualidade de check-in, zero retrabalho em 90 dias, volume de ordens sem disputa e tags semânticas positivas em <code>ReviewTags</code>). Profissionais que conquistam insígnias como <em>Super Profissional</em> e <em>Sempre Pontual</em> obtêm destaque orgânico de conversão e poder de precificação meritocrático.</li>
  <li><strong>5. Orçamentos 100% Gratuitos sem Venda de Moedas:</strong> Extingue definitivamente o pedágio especulativo de entrada. O prestador submete quantos orçamentos técnicos desejar a custo zero (viabilizado pelo <em>Tier-0 KYC</em> a <code>R$ 0,00</code> e pelo custo marginal de nuvem de <code>R$ 0,034/OS</code>), alinhando <code>100%</code> da receita da startup ao sucesso efetivo do trabalhador.</li>
</ul>

<h3 id="sec-2-6-6">2.6.6. Descrição da Proposta de Valor — ALIVIADORES DE DORES (<em>Pain Relievers</em>)</h3>
<p>
  Para erradicar as barreiras críticas de medo físico, calote e vício pós-entrega apontadas por <code>60,7%</code> a <code>92,9%</code> dos pesquisados, três protocolos de blindagem atuam de modo automático e inegociável em toda transação:
</p>

<div class="innovation-box">
  <div class="ib-header">Aliviador 1 — <em>Temporal &amp; Spatial Geo-Privacy Lock</em> (Ofuscação Criptográfica até <span class="mono">00:00</span> do Dia Agendado)</div>
  <p>
    Implementado no nível do banco de dados PostgreSQL via RPC canônica <code>get_job_location_for_viewer(uuid)</code>, funções <code>SECURITY DEFINER</code> e segredo CSPRNG de 256 bits isolado em <code>private.geo_privacy_secrets</code> (<code>ADR-0022</code>, migração <code>026</code>), nenhum dado de endereço direto (logradouro, número predial, complemento, apartamento, CEP ou coordenada GPS exata) trafega para a rede durante os estágios públicos de cotação (<code>PUBLIC_FUZZY</code>) nem mesmo após a contratação enquanto o agendamento for futuro (<code>HIRED_PRE_DAY_LOCKED</code>). O prestador visualiza exclusivamente o bairro/município e um <strong>círculo determinístico derivado por <code>HMAC-SHA256</code> com deslocamento de centro entre <code>151m e 349m</code> e raio ofuscado entre <code>500m e 800m</code></strong> — precisão suficiente para estimar tempo de deslocamento sem jamais identificar o edifício ou casa. A transição para <code>SERVICE_DAY_UNLOCKED</code> ocorre estritamente a partir das <strong><code>00:00:00</code> (fuso <code>America/Sao_Paulo</code>) do próprio dia agendado</strong> exclusivamente para o único profissional contratado em custódia ativa (ou no aceite imediato em chamados SOS), retornando automaticamente ao estado <code>POST_COMPLETION_RELOCKED</code> assim que a ordem é concluída ou cancelada.
  </p>
</div>

<div class="innovation-box">
  <div class="ib-header">Aliviador 2 — Custódia Fiduciária <em>Smart Escrow</em> com PIN de 4 Dígitos e Modo Silencioso Anti-Coação</div>
  <p>
    Elimina simultaneamente o risco de abandono para o morador e o risco de calote para o técnico. O serviço só entra em execução após a confirmação atômica do depósito integral via Pix no cofre <em>Smart Escrow</em> (garantindo ao profissional que a verba já existe e está reservada). Em contrapartida, o repasse financeiro permanece bloqueado durante a execução e só é destravado quando o morador inspeciona presencialmente o reparo concluído e informa seu <strong>PIN criptográfico exclusivo de 4 dígitos</strong> (protegido adicionalmente pelo protocolo <em>Silent Duress PIN</em>: a digitação invertida do código sob eventual coação simula aprovação normal na tela, preservando a integridade física da vítima, mas congela silenciosamente a liquidação em <code>FROZEN_UNDER_DURESS</code>).
  </p>
</div>

<div class="innovation-box">
  <div class="ib-header">Aliviador 3 — Garantia Real de 90 Dias em 3 Camadas Lastreada por Fundo Garantidor Autossustentável (<span class="mono">1,5%</span>)</div>
  <p>
    Converte a garantia legal do Art. 26, II do CDC em mecanismo financeiro autoexecutável. A cada serviço liquidado, um <em>Carve-Out</em> automático de <strong><code>1,5%</code></strong> sobre o valor da mão de obra alimenta o livro-razão mutualista <code>warranty_pool_ledger</code> (sem custo extra para o consumidor). Caso ocorra vício técnico nos 90 dias subsequentes, abre-se protocolo auditado (<code>#DSP-XXXX</code>) com congelamento cautelar e resolução escalonada: <strong>Camada 1</strong> — reexecução prioritária sem custo pelo prestador original; <strong>Camada 2</strong> — havendo recusa ou incapacidade, despacho automático de segundo especialista homologado custeado pelo Fundo Garantidor; <strong>Camada 3</strong> — restituição/indenização direta ao morador até o teto contratual, mantendo equilíbrio atuarial a cada <code>N = 1 / 0,015 &approx; 67</code> ordens sem sinistro.
  </p>
</div>

<h3 id="sec-2-6-7">2.6.7. Análise da Oportunidade de Mercado: Evidências Oficiais Macroeconômicas e Setoriais</h3>
<p>
  A oportunidade endereçada pelo Desperrengue não repousa em projeções especulativas, mas na convergência histórica de quatro vetores estruturais documentados pelas instituições oficiais de estatística, finanças e construção civil do Brasil:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="23%">Fonte Oficial / Instituição</th>
      <th width="27%">Indicador Macroestrutural Auditado</th>
      <th width="50%">Impacto Direto na Tese de Oportunidade do Ecossistema Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>IBGE — Censo Demográfico 2022 e PNAD Contínua Habitação</strong></td>
      <td><strong><code>~72,4 milhões</code></strong> de domicílios particulares permanentes ocupados no Brasil; urbanização de <code>87,4%</code>; média de <code>2,79</code> moradores/domicílio e avanço acelerado de apartamentos (+34% intercensitário).</td>
      <td>A redução do tamanho das famílias, o trabalho híbrido/urbano e o envelhecimento natural do parque edificado brasileiro (idade média superior a 18 anos nas capitais) elevam exponencialmente a necessidade de contratação externa de reparos elétricos, hidráulicos e conservação, ao mesmo tempo em que condomínios verticalizados exigem controle rígido de portaria e conformidade <strong>ABNT NBR 5674</strong>.</td>
    </tr>
    <tr>
      <td><strong>Sebrae &amp; Receita Federal / Portal do Empreendedor</strong></td>
      <td>Mais de <strong><code>15,7 milhões</code></strong> de MEIs ativos no país, somados a <strong><code>&gt; 4,8 milhões</code></strong> de trabalhadores por conta própria em reparação, instalações prediais, obras de acabamento e serviços domésticos (PNAD Contínua Trabalho).</td>
      <td>Comprova a existência de um exército massivo de mão de obra técnica já habituado ao regime MEI, porém desprovido de infraestrutura digital justa de captação de clientes, proteção contra inadimplência e gestão separada de insumos fiscais (<em>Smart Split</em>).</td>
    </tr>
    <tr>
      <td><strong>Banco Central do Brasil (BACEN — Estatísticas SPI / Pix)</strong></td>
      <td>Mais de <strong><code>160 milhões</code></strong> de pessoas físicas e <strong><code>15 milhões</code></strong> de empresas usuárias ativas do Pix, superando <code>5,5 bilhões</code> de transações mensais com liquidação instantânea <code>24x7</code> em <code>&lt; 2,5s</code>.</td>
      <td>Elimina a barreira histórica que impedia marketplaces populares no Brasil até 2020 (dependência de cartão de crédito com taxas de <code>4%–5%</code>, <em>chargeback</em> fraudulento e desbancarização de autônomos). O Pix programável viabiliza o <em>Smart Escrow</em> de baixo custo (<code>~0,8% a 1,5%</code> de PSP) para todas as faixas de renda.</td>
    </tr>
    <tr>
      <td><strong>ANAMACO, CBIC, ABRAINC e FGV IBRE</strong></td>
      <td>Faturamento anual do varejo brasileiro de material de construção e reformas superior a <strong><code>R$ 210 bilhões/ano</code></strong>, sendo mais de <code>65%</code> destinado a pequenas reformas, reparos corretivos e manutenção domiciliar autogerida.</td>
      <td>Cada real gasto no varejo de materiais (ANAMACO) demanda contratação correlata de mão de obra de instalação ou reparo. Não obstante o gigantismo bilionário do setor, menos de <code>6%</code> das transações de serviços residenciais passam por plataformas digitais — configurando um <em>oceano azul</em> de formalização tecnológica.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-2-6-8">2.6.8. Análise do Potencial de Mercado: Cálculo Rigoroso de TAM, SAM e SOM e Expansão em Ondas</h3>
<p>
  Para evitar superestimações típicas de planos conceituais, o dimensionamento do potencial econômico do Desperrengue combina a metodologia <strong>Top-Down</strong> (ancorada nos agregados domiciliares e setoriais do IBGE e ANAMACO/CBIC) com a validação <strong>Bottom-Up</strong> (construída a partir da capacidade operacional de clusters urbanos, frequência anual aferida de ordens por domicílio e ticket médio composto verificado no <em>Smart Split</em>).
</p>

<div class="math-formula-box">
  <div class="math-display">
    TAM<sub>GMV</sub> = D<sub>urb_ativos</sub> &times; G<sub>anual_manut</sub> = (72,4 &times; 10<sup>6</sup> &times; 58,0%) &times; R$ 3.400,00 &approx; R$ 142,8 Bilhões / ano
  </div>
</div>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Recorte de Mercado</th>
      <th width="28%">Formulação Econométrica (Top-Down &amp; Bottom-Up)</th>
      <th width="18%">Potencial Anual (GMV)</th>
      <th width="18%">Potencial de Receita Líquida Plataforma</th>
      <th width="20%">Premissas Auditáveis</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>TAM</strong><br/>(<em>Total Addressable Market</em> — Brasil)</td>
      <td><code>42,0 milhões</code> de domicílios urbanos economicamente demandantes de serviços pagos &times; dispêndio médio anual de <code>R$ 3.400,00</code> em reparos, instalações e conservação (mão de obra + peças de reposição).</td>
      <td><strong><code>R$ 142,80 Bilhões / ano</code></strong></td>
      <td><strong><code>R$ 13,26 Bilhões / ano</code></strong><br/>(aplicando <code>13,5%</code> líquido apenas sobre a fração média de <code>68,75%</code> de mão de obra)</td>
      <td>Base IBGE PNAD / Censo (<code>72,4M</code> domicílios totais &times; <code>58%</code> penetração urbana contratante) e cesta ANAMACO/CBIC.</td>
    </tr>
    <tr>
      <td><strong>SAM</strong><br/>(<em>Serviceable Available Market</em> — Urbano Digital Pix)</td>
      <td><code>19,2 milhões</code> de domicílios bancarizados via Pix e smartphone ativo situados em regiões metropolitanas e municípios médios (<code>&gt; 150 mil hab.</code>) nas 33 categorias atendidas &times; <code>6,25 OS/ano</code> &times; ticket médio consolidado <code>R$ 320,00</code> (<code>R$ 220 MO + R$ 100 Peças</code>).</td>
      <td><strong><code>R$ 38,40 Bilhões / ano</code></strong></td>
      <td><strong><code>R$ 3,56 Bilhões / ano</code></strong></td>
      <td>Recorte digital imediato das regiões Sudeste, Sul, Centro-Oeste e capitais do Nordeste/Norte com alta densidade condominial.</td>
    </tr>
    <tr>
      <td><strong>SOM (36 Meses)</strong><br/>(<em>Serviceable Obtainable Market</em> — Meta Operacional)</td>
      <td><strong>Bottom-Up:</strong> captura realista de <code>~0,12%</code> do SAM em 36 meses = <strong><code>142.500 OS/ano</code></strong> distribuídas em 25 clusters urbanos densos &times; ticket médio consolidado <code>R$ 320,00</code> (<code>R$ 220,00 MO + R$ 100,00 Peças</code>; receita líquida de <code>R$ 29,70/OS</code>).<br/><em>Nota de Rampa Inicial (Ano 1 Lean):</em> <code>1.445 OS</code> auditadas na planilha de fluxo de caixa (<code>GMV R$ 260.100,00</code> e <code>Break-Even</code> já no <code>M3</code> com <code>40 OS/mês</code>).</td>
      <td><strong><code>R$ 45,60 Milhões / ano</code></strong><br/>(Horizonte M36)<br/><span class="badge-ok">Ano 1: R$ 260,1 mil</span></td>
      <td><strong><code>R$ 4,23 Milhões / ano</code></strong><br/>(Comissão líquida <code>13,5%</code> sobre <code>R$ 31,35M</code> de MO + <em>Float</em>/B2B)<br/><span class="badge-ok">Ano 1: R$ 35,3 mil</span></td>
      <td>Crescimento orgânico + performance digital controlada com <code>LTV/CAC = 9,65x</code> e autossuficiência de caixa desde o 3º mês.</td>
    </tr>
  </tbody>
</table>

${svgTamSamSom}

<h4 id="sec-2-6-8-ondas">Tese de Expansão Escalável em Três Ondas Geográficas Concêntricas</h4>
<p>
  Em mercados bilaterais hiperlocais, dispersar verba de aquisição nacionalmente no primeiro dia dilui a densidade de oferta e eleva o tempo de espera. Por essa razão, a captura do SOM obedece a uma engenharia de expansão em <strong>três ondas geográficas concêntricas</strong> (<em>Bowling Pin Strategy</em>, Geoffrey Moore):
</p>
<ol>
  <li><strong>Onda 1 — Hiperdensidade Microterritorial e Condomínios-Âncora (Meses 1 a 12):</strong> Concentração tática em bairros verticalizados de alta densidade domiciliar em polo metropolitano inicial (<code>Raio &le; 8 km</code>). O onboard prévio de <code>150 a 300</code> profissionais verificados nas categorias líderes da pesquisa (Limpeza <code>57,1%</code>, Elétrica, Hidráulica, Climatização e Montagem <code>39,3%</code>) garante liquidez imediata e SLA SOS <code>&lt; 60s</code>, atingindo o ponto de equilíbrio operacional já no 3º mês com apenas <code>40 OS/mês</code>.</li>
  <li><strong>Onda 2 — Corredores Metropolitanos e Polos Regionais de Médio/Grande Porte (Meses 13 a 24):</strong> Replicação do <em>playbook</em> automatizado (SEO hiperlocal programático por bairro/especialidade + indicação cruzada gamificada + parcerias com lojas regionais de material elétrico/hidráulico) para capitais e cidades-polo com população superior a <code>300 mil habitantes</code> no eixo Sudeste, Sul e Centro-Oeste, alavancando o custo marginal nulo de triagem <em>Tier-0 KYC</em>.</li>
  <li><strong>Onda 3 — Escala Federada Nacional e Integração B2B Institucional (Meses 25 a 36+):</strong> Expansão capilar nacional impulsionada por contratos B2B2C recorrentes com <strong>administradoras de condomínios, redes imobiliárias digitais e seguradoras residenciais</strong>, nas quais o Passaporte Predial <strong>ABNT NBR 5674</strong> e o cofre <em>Smart Escrow</em> operam como padrão de conformidade regulatória e redução de sinistralidade, consolidando o volume anual de <code>142.500 OS</code> do SOM.</li>
</ol>
</section>
`;

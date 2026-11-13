export const ch1Html = String.raw`
<!-- ======================================================================= -->
<!-- CAPÍTULO 1 — TÉCNICAS DE ESCRITA TÉCNICA E CIENTÍFICA EM COMPUTAÇÃO     -->
<!-- ======================================================================= -->
<section class="chapter-section" id="cap-1">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 1</div>
  <div class="cb-body">
    <h2>TÉCNICAS DE ESCRITA TÉCNICA E CIENTÍFICA APLICADAS EM CIÊNCIA DA COMPUTAÇÃO</h2>
    <p>Fundamentação epistemológica, linguística de especialidade monossêmica, templates formais ISO/IEC/IEEE 29148 &amp; EARS, impessoalidade estrita em 3ª pessoa, normatização estilística de tabelas e equações e método hipotético-dedutivo aplicados ao ecossistema Desperrengue (<span class="mono">v2.11.0</span>).</p>
  </div>
</div>

<p>
  Na Ciência da Computação e na Engenharia de Sistemas Distribuídos de Missão Crítica, a documentação técnica e científica não opera como mero apêndice narrativo redigido após a codificação, mas como <strong>artefato formal de engenharia</strong> dotado de semântica operacional precisa, verificabilidade empírica e valor contratual entre camadas de software, esquemas relacionais de banco de dados, protocolos criptográficos e exigências regulatórias. Em plataformas transacionais bilaterais que custodiam valores fiduciários, processam biometria governamental e resguardam a integridade física domiciliar dos cidadãos — caso concreto do ecossistema <strong>Desperrengue (<span class="mono">v2.11.0</span>)</strong> — qualquer ambiguidade lexical, adjetivação subjetiva ou lacuna de rastreabilidade converte-se diretamente em defeito arquitetural, superfície de ataque ou inconsistência contábil.
</p>
<p>
  Este capítulo institui o rigor metodológico, linguístico, notacional e epistemológico que rege integralmente os seis capítulos deste Tratado Enciclopédico. Formalizam-se: (i) a <strong>linguagem de especialidade monossêmica, a lógica modal normativa e a gramática estruturada EARS</strong> sob as normas internacionais <strong>ISO/IEC/IEEE 29148:2018</strong>, <strong>ISO/IEC 25010:2023</strong> e <strong>ISO/IEC/IEEE 42010:2022</strong>; (ii) a estilística da <strong>objetividade denotativa, impessoalidade estrita em 3ª pessoa, voz passiva analítica e normatização de tabelas, equações e citações científicas</strong>; e (iii) a <strong>estruturação lógica hipotético-dedutiva</strong> acoplada aos critérios formais de verificabilidade e à Matriz Mestra de Rastreabilidade Científica Epistemológica do repositório oficial.
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 1.1                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-1-1">
  <span class="sh-tag">SEÇÃO 1.1 &bull; SEMÂNTICA FORMAL, MONOSSEMIA, LÓGICA MODAL E PADRÃO EARS</span>
  <h2>1.1. Linguagem de Especialidade Monossêmica e Vocabulário Controlado (ISO/IEC/IEEE 29148, ISO/IEC 25010 e ISO/IEC/IEEE 42010)</h2>
  <p>Eliminação de polissemia, entropia semântica condicional nula, lógica deôntica normativa, gramática formal EARS e mapeamento léxico controlado do ecossistema Desperrengue.</p>
</div>

<h3 id="sec-1-1-1">1.1.1. Epistemologia da Monossemia e Entropia Semântica Zero em Especificações Computacionais</h3>
<p>
  A língua natural coloquial caracteriza-se estruturalmente pela <strong>polissemia</strong> (um único significante remetendo a múltiplos significados distintos conforme o contexto pragmático), pela <strong>sinonímia estilística livre</strong> (alternância arbitrária de vocábulos para designar o mesmo ente) e pela <strong>vagueza gradual</strong> (predicados desprovidos de fronteira numérica decidível, tais como <em>&ldquo;rápido&rdquo;</em>, <em>&ldquo;seguro&rdquo;</em>, <em>&ldquo;perto&rdquo;</em> ou <em>&ldquo;confiável&rdquo;</em>). Embora funcionais no discurso cotidiano ou publicitário, tais fenômenos linguísticos são deletérios na Engenharia de Software rigorosa, na qual enunciados normativos precisam ser traduzidos sem resíduo interpretativo em máquinas de estados finitos, restrições DDL/DCL em PostgreSQL e oráculos determinísticos de teste.
</p>
<p>
  Na <strong>Linguagem de Especialidade em Ciência da Computação</strong>, institui-se um <strong>Vocabulário Controlado Monossêmico</strong> (<span class="math-inline">V<sub>ctrl</sub></span>) mapeado sobre o universo formal de conceitos de domínio, protocolos e componentes arquiteturais (<span class="math-inline">C</span>). À luz da Teoria Matemática da Comunicação de Claude Shannon (1948), dado um termo técnico controlado <span class="math-inline">t &isin; V<sub>ctrl</sub></span>, a função de interpretação <span class="math-inline">&Phi; : V<sub>ctrl</sub> &rarr; C</span> deve ser injetora e unívoca em todo o escopo documental, anulando a entropia semântica condicional entre autores, implementadores e auditores:
</p>

<div class="math-formula-box">
  <div class="math-display">
    &forall; t &isin; V<sub>ctrl</sub>, &exist;! c &isin; C : &Phi;(t) = c &nbsp;&rArr;&nbsp; H(C | T = t) = &minus; &Sigma;<sub>c &isin; C</sub> P(c | t) &middot; log<sub>2</sub> P(c | t) = 0 <span class="m-rm">bits</span>
  </div>
</div>

<p>
  Inversamente, qualquer termo coloquial polissêmico <span class="math-inline">t<sub>col</sub> &notin; V<sub>ctrl</sub></span> induz distribuição não degenerada de interpretações concorrentes (<span class="math-inline">H(C | T = t<sub>col</sub>) &gt; 0</span> bits), originando defeitos de interface entre front-end, banco de dados e microsserviços. No ecossistema Desperrengue, a erradicação dessa entropia apoia-se no tripé normativo internacional sintetizado a seguir.
</p>

<div class="cards-3col">
  <div class="info-card">
    <div class="ic-title">1. ISO/IEC/IEEE 29148:2018 (Requisitos)</div>
    <p>As cláusulas <code>5.2.5</code> a <code>5.2.8</code> exigem que cada requisito individual seja <strong>necessário, livre de detalhes supérfluos de implementação externa, não ambíguo, consistente, completo, singular, exequível, rastreável e verificável</strong>, vedando expressões abertas como <em>&ldquo;etc.&rdquo;</em>, <em>&ldquo;e/ou&rdquo;</em> e <em>&ldquo;entre outros&rdquo;</em>.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">2. ISO/IEC 25010:2023 (Qualidade SQuaRE)</div>
    <p>Decompõe a qualidade do produto de software em atributos mensuráveis dotados de intervalos fechados: Eficiência de Desempenho (<code>&le; 8,33 ms/quadro</code> a <code>120 Hz</code>), Confiabilidade (ACID em centavos <code>BIGINT</code>), Segurança (<code>HMAC-SHA256</code> 256 bits e <code>FORCE RLS</code>), Usabilidade (WCAG 2.1 AA/AAA) e Suportabilidade.</p>
  </div>
  <div class="info-card">
    <div class="ic-title">3. ISO/IEC/IEEE 42010:2022 (Arquitetura)</div>
    <p>Estabelece distinção ontológica rigorosa entre <em>Sistema</em>, <em>Ambiente</em>, <em>Partes Interessadas</em> (<em>Stakeholders</em>), <em>Preocupações</em> (<em>Concerns</em>), <em>Pontos de Vista</em> (<em>Viewpoints</em>), <em>Visões</em> (Modelo C4 Níveis 1–3 e Clean Architecture em 4 camadas) e <em>Decisões Arquiteturais</em> (<code>ADR-0001</code> a <code>ADR-0022</code>).</p>
  </div>
</div>

<h3 id="sec-1-1-2">1.1.2. Semântica Modal Normativa Segundo a ISO/IEC/IEEE 29148:2018</h3>
<p>
  Para eliminar qualquer indecidibilidade jurídica ou algorítmica acerca da força vinculante de cada enunciado técnico, aplica-se correspondência estrita entre operadores de lógica modal deôntica e verbos auxiliares normativos:
</p>
<ul>
  <li><strong>Obrigação Contratual Estrita (<code>DEVE</code> / <em>SHALL</em>):</strong> denota requisito mandatório ou invariante matemática cuja violação invalida a conformidade da build e interrompe o pipeline de integração contínua (exemplo: <em>&ldquo;O livro-razão <code>warranty_pool_ledger</code> DEVE persistir montantes exclusivamente em inteiros de 64 bits em centavos (<code>BIGINT</code>)&rdquo;</em>).</li>
  <li><strong>Interdição Formal de Segurança/Domínio (<code>NÃO DEVE</code> / <em>SHALL NOT</em>):</strong> define estado ou fluxo informacional terminantemente proibido pela fronteira <em>Zero-Trust</em> (exemplo: <em>&ldquo;A tabela pública <code>public.jobs</code> NÃO DEVE reter coordenadas geográficas exatas nem hashes de PIN presencial&rdquo;</em>).</li>
  <li><strong>Recomendação Arquitetural Justificada (<code>DEVERIA</code> / <em>SHOULD</em>):</strong> indica diretriz técnica preferencial de projeto cuja eventual exceção exige registro formal em ADR acompanhado de demonstração quantitativa de compensação.</li>
  <li><strong>Permissão Parametrizada (<code>PODE</code> / <em>MAY</em>):</strong> delimita faculdade operacional opcional explicitamente prevista na máquina de estados, sem introduzir comportamento indefinido; declarações meramente descritivas de fatos externos utilizam o presente do indicativo sem verbo modal de obrigação.</li>
</ul>

<h3 id="sec-1-1-3">1.1.3. Templates Sintáticos Formais ISO/IEC/IEEE 29148 e Padrão EARS (<em>Easy Approach to Requirements Syntax</em>)</h3>
<p>
  Mesmo utilizando vocabulário monossêmico, frases redigidas sem estrutura sintática canônica sofrem de ambiguidade de escopo condicional, omissão do sujeito responsável ou subespecificação de gatilhos temporais. Para erradicar defeitos sintáticos na raiz, a engenharia documental deste Tratado conjuga o modelo sentencial da cláusula <code>5.2.7</code> da <strong>ISO/IEC/IEEE 29148:2018</strong> com a gramática formal <strong>EARS (<em>Easy Approach to Requirements Syntax</em>)</strong> proposta por Alistair Mavin et al. (2009), amplamente adotada em sistemas aeronáuticos, financeiros e de segurança crítica.
</p>
<p>
  Em notação de Backus-Naur Estendida (<code>EBNF</code>), toda especificação normativa bem-formada deriva da produção geral:
</p>

<div class="math-formula-box">
  <div class="math-display">
    &lang;Req<sub>EARS</sub>&rang; ::= [&lang;Precondição<sub>Estado</sub>&rang;] &nbsp; [&lang;Gatilho<sub>Evento/Falha</sub>&rang;] &nbsp; &lang;Agente<sub>Sistema</sub>&rang; &nbsp; (<code>DEVE</code> | <code>NÃO DEVE</code>) &nbsp; &lang;Resposta<sub>Mensurável</sub>&rang; &nbsp; [&lang;Restrição<sub>SLA/Limite</sub>&rang;]
  </div>
</div>

<p>
  A Tabela 1.1 cataloga os seis arquétipos formais da gramática EARS/ISO 29148 e demonstra sua instanciação direta sobre os protocolos reais do ecossistema Desperrengue (<code>v2.11.0</code>).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Classe Sintática EARS</th>
      <th width="26%">Molde Gramatical Canônico Controlado</th>
      <th width="22%">Escopo Lógico-Formal</th>
      <th width="36%">Instanciação Normativa Real no Desperrengue (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Ubíquo</strong><br/>(<em>Ubiquitous</em>)</td>
      <td><code>O &lt;subsistema&gt; DEVE &lt;invariante permanente&gt;.</code></td>
      <td>Propriedades estruturais invariantes ativas em <code>100%</code> dos estados de execução (<span class="math-inline">&square; P</span> em lógica temporal LTL).</td>
      <td><em>&ldquo;O motor contábil (<code>money.dart</code> e <code>ledger_lines</code>) DEVE representar e operar valores monetários exclusivamente em inteiros de 64 bits em centavos (<code>BIGINT</code>) com soma algébrica nula por transação (<code>&Sigma; cents = 0</code>).&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>2. Orientado a Evento</strong><br/>(<em>Event-Driven</em>)</td>
      <td><code>QUANDO &lt;evento discreto&gt;, o &lt;subsistema&gt; DEVE &lt;resposta determinística&gt;.</code></td>
      <td>Transição atômica disparada por borda de subida de um evento externo ou relógio (<span class="math-inline">&square;(E &rarr; &bigcirc; R)</span>).</td>
      <td><em>&ldquo;QUANDO o relógio do servidor atingir <code>00:00:00 America/Sao_Paulo</code> da data agendada de uma ordem contratada, a RPC <code>get_job_location_for_viewer</code> DEVE liberar o logradouro exato exclusivamente ao cliente titular e ao profissional contratado.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>3. Orientado a Estado</strong><br/>(<em>State-Driven</em>)</td>
      <td><code>ENQUANTO &lt;estado ativo&gt;, o &lt;subsistema&gt; DEVE &lt;restrição contínua&gt;.</code></td>
      <td>Invariante mantida durante todo o intervalo em que um predicado de estado permanece verdadeiro (<span class="math-inline">&square;(S &rarr; R)</span>).</td>
      <td><em>&ldquo;ENQUANTO a ordem de serviço encontrar-se nas fases <code>PUBLIC_FUZZY</code> ou <code>HIRED_PRE_DAY_LOCKED</code>, o banco PostgreSQL DEVE expor apenas centro ofuscado via <code>HMAC-SHA256</code> (<code>151m–349m</code>) e raio de <code>500m–800m</code>.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>4. Comportamento Indesejado</strong><br/>(<em>Unwanted Behavior</em>)</td>
      <td><code>SE &lt;falha, ataque ou coação&gt;, ENTÃO o &lt;subsistema&gt; DEVE &lt;mitigação fail-closed&gt;.</code></td>
      <td>Tratamento determinístico de exceções, fraudes fiscais, falhas de rede e ameaças físicas domiciliares.</td>
      <td><em>&ldquo;SE o usuário submeter o PIN de 4 dígitos em ordem posicional reversa (ex.: <code>4819 &rarr; 9184</code>), ENTÃO <code>ZeroTrustBilateralSecurityEngine</code> DEVE exibir confirmação visual padrão ao terminal e bloquear silenciosamente o repasse (<code>FROZEN_UNDER_DURESS</code>).&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>5. Opcional / Escopo</strong><br/>(<em>Where-Driven</em>)</td>
      <td><code>ONDE &lt;capacidade/escopo ativo&gt;, o &lt;subsistema&gt; DEVE &lt;comportamento específico&gt;.</code></td>
      <td>Especialização condicional governada por modo de operação ou recurso de hardware disponível.</td>
      <td><em>&ldquo;ONDE o orçamento contiver parcela de materiais vinculada a chave NF-e/NFC-e válida de 44 dígitos (Módulo 11), o motor <em>Smart Split</em> DEVE aplicar alíquota de intermediação igual a <code>0,0%</code> sobre o reembolso de insumos.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>6. Composto / Híbrido</strong><br/>(<em>Complex EARS</em>)</td>
      <td><code>ENQUANTO &lt;estado&gt;, QUANDO &lt;evento&gt;, SE &lt;falha&gt;, ENTÃO o &lt;subsistema&gt; DEVE &lt;ação&gt;.</code></td>
      <td>Protocolos transacionais multi-estágio que exigem guarda simultânea de estado, gatilho e <em>rollback</em>.</td>
      <td><em>&ldquo;ENQUANTO houver solicitação de exclusão LGPD (<code>client | provider | all</code>), QUANDO a Edge Function <code>excluir-conta</code> sintetizar o dossiê PDF A4 (<code>dossie.ts</code>), SE a entrega SMTP ao titular falhar, ENTÃO o servidor DEVE abortar atomicamente a invocação de <code>purge_account</code>.&rdquo;</em></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-1-1-4">1.1.4. Matriz Léxica Contrastiva Aplicada ao Ecossistema Desperrengue (<span class="mono">v2.11.0</span>)</h3>
<p>
  A Tabela 1.2 consolida o vocabulário controlado oficial do projeto, contrastando expressões coloquiais ou polissêmicas — estritamente vedadas neste compêndio — com os respectivos termos técnico-científicos monossêmicos e sua materialização verificável no repositório.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="19%">Expressão Coloquial / Ambígua (Vedada)</th>
      <th width="23%">Patologia Semântica e Risco de Engenharia</th>
      <th width="29%">Vocabulário Técnico-Científico Monossêmico Controlado</th>
      <th width="29%">Materialização Real no Código Auditado (<span class="mono">v2.11.0</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><em>&ldquo;Tela rápida e que não trava ao rolar&rdquo;</em></td>
      <td>Vagueza métrica; impossibilita aferição determinística de regressão gráfica em displays de alta frequência.</td>
      <td><strong>Orçamento de Renderização de <span class="mono">8,33 ms/quadro</span> (<span class="mono">120 Hz</span>) com Isolamento de Repintura</strong></td>
      <td><code>RepaintBoundary</code> na árvore Flutter, pré-decodificação assíncrona e execução pesada via <code>off_thread.dart</code> (<code>Isolate.run</code>).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Foto que abre na hora sem carregar&rdquo;</em></td>
      <td>Hipérbole informal; oculta política de memória, invalidação e proteção de objetos confidenciais.</td>
      <td><strong>Cache Hierárquico de Imagens em Duplo Nível (<span class="mono">0 ms</span> em <em>Hit</em> Quente L1/L2) com Isolamento de Buckets Privados</strong></td>
      <td><code>instant_image_cache_engine.dart</code> (<code>InstantImageCacheEngine</code>, <code>InstantCachedImage</code> L1 RAM <code>96 MB</code> + decodificado <code>128 MB</code> + L2 <code>SharedPreferences</code>; <code>storage:</code> restrito à RAM) e <code>EagerImagePrefetcher</code>.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Guardar dinheiro sem erro de vírgula&rdquo;</em></td>
      <td>Indefinição do tipo numérico e ausência de garantias de conservação contábil sob concorrência.</td>
      <td><strong>Aritmética Monetária Inteira de 64 Bits em Centavos (<span class="mono">BIGINT</span>) sob Escrituração de Partidas Dobradas Soma-Zero</strong></td>
      <td>Utilitário <code>Money</code> (<code>app/lib/core/utils/money.dart</code> com rateio pelo maior resto) e tabelas <code>client_wallets</code>, <code>ledger_lines</code> (<code>&Sigma; cents = 0</code>) e <code>warranty_pool_ledger</code>.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Esconder o endereço do cliente até o dia&rdquo;</em></td>
      <td>Ambiguidade sobre fuso horário, raio geométrico, reversibilidade de hash e camada de filtragem.</td>
      <td><strong>Protocolo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> via <span class="mono">HMAC-SHA256</span> com Chave CSPRNG de 256 Bits no Servidor</strong></td>
      <td>Migração <code>026</code> (<code>20261113100000_temporal_geo_privacy_lock.sql</code>): <code>private.geo_privacy_secrets</code>, <code>_geo_fuzzy_center</code> (<code>151m–349m</code> em raio <code>500m–800m</code>) e destravamento às <code>00:00:00 America/Sao_Paulo</code> via <code>get_job_location_for_viewer</code>.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Não cobrar comissão em cima das peças&rdquo;</em></td>
      <td>Omissão do requisito de comprovação fiscal idônea e do tratamento contra cancelamento fraudulento posterior.</td>
      <td><strong>Particionamento Orçamentário Assimétrico (<em>Smart Split</em>) com Isenção Fiscal Condicional (<span class="mono">0,0%</span>) e <em>Clawback</em> Assíncrono</strong></td>
      <td>Alíquota de <code>15,0%</code> restrita à mão de obra e <code>0,0%</code> sobre insumos vinculados a NF-e/NFC-e de 44 dígitos (<code>nfe_access_key.dart</code>) em <code>job_fiscal_documents</code>, auditada após <code>26h</code> (<code>audit_sefaz_phase2_cancellation_and_clawback</code>).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Segurar o pagamento até terminar o serviço&rdquo;</em></td>
      <td>Indeterminação quanto ao mecanismo criptográfico de aceite presencial e ao cronograma de liquidação antifraude.</td>
      <td><strong>Custódia Fiduciária <em>Smart Escrow</em> com Prova Presencial por PIN de 4 Dígitos (<span class="mono">bcrypt</span>) e Maturação Escalonada</strong></td>
      <td>Segredo isolado em <code>private.job_forensic_secrets</code> (<code>[SEC-02]</code>), RPC <code>complete_job_and_schedule_escrow</code> e fila <code>escrow_maturation_entries</code> (<code>D+0 / D+2 / D+5..D+7</code>).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Botão de pânico caso o cliente seja ameaçado&rdquo;</em></td>
      <td>Um botão visível de alerta expõe a vítima a retaliação física imediata durante coação presencial no domicílio.</td>
      <td><strong>Cofre Dual Anti-Coação por PIN Reverso Esteganográfico (<em>Silent Duress PIN</em>)</strong></td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>: inversão posicional do PIN (ex.: <code>4819 &rarr; 9184</code>) renderiza tela idêntica de sucesso ao agressor enquanto congela silenciosamente o repasse (<code>FROZEN_UNDER_DURESS</code>) e retém telemetria forense.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Garantia de 3 meses paga pelo aplicativo&rdquo;</em></td>
      <td>Confusão jurídica entre responsabilidade objetiva ilimitada e mecanismo mutualista atuarial autossustentável.</td>
      <td><strong>Protocolo de Mediação Técnica em 3 Camadas Caucionado por Fundo Garantidor Mutualista (<span class="mono">1,5%</span> <em>Carve-Out</em>)</strong></td>
      <td>Tabelas <code>job_mediations</code> e <code>warranty_pool_ledger</code> (migração <code>020</code>): Camada 1 (autocomposição assistida), Camada 2 (retrabalho por outro prestador via busca espacial <span class="math-inline">O(log N + K)</span>) e Camada 3 (estorno atuarial até o teto do serviço).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Checar selfie e RG com inteligência artificial&rdquo;</em></td>
      <td>Generalização opaca; ignora custo em nuvem, ataques de injeção visual, assinaturas ICP-Brasil e explicabilidade legal.</td>
      <td><strong>Pipeline KYC Biométrico e Documental <em>Zero-Trust</em> em 3 Níveis (Tier-0 Local + Argon High + Carbon High / ICP-Brasil)</strong></td>
      <td><code>document_ocr_and_liveness_service.dart</code> em <code>Isolate.run</code> (<code>R$ 0,00</code>), Edge Function <code>kyc-argon-vision-gate</code> e microsserviço Python <code>kyc_engine/</code> (<code>crypto_doc_validator.py</code>, <code>serpro_datavalid.py</code>, <code>fraud_orchestrator.py</code> e Top-3 SHAP LGPD Art. 20).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Tirar localização da foto e ver se é repetida&rdquo;</em></td>
      <td>Falta de especificação sobre recodificação (perda de qualidade) e resistência a cortes ou ajustes de brilho.</td>
      <td><strong>Sanitização Binária Sem Perdas de Metadados (<span class="mono">EXIF/GPS/XMP/IPTC</span>) e <em>Hashing</em> Perceptual <span class="mono">dHash</span> de 64 Bits</strong></td>
      <td><code>image_metadata_stripper.dart</code> (remoção <em>lossless fail-closed</em> em JPEG/PNG/WebP), <code>perceptual_hash_guard.dart</code> (<code>dHash</code> com recorte de borda de <code>12%</code> e limiar de entropia <code>MAD</code>) e <code>hamming_distance_64</code> <span class="math-inline">O(1)</span> no PostgreSQL.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Evitar que duas operações travem o banco&rdquo;</em></td>
      <td>Descrição sintomática sem prova formal de prevenção de espera circular entre transações concorrentes.</td>
      <td><strong>Serialização Transacional Livre de <em>Deadlocks</em> por Ordenação Canônica Estrita de Locks e Varredura <span class="mono">SKIP LOCKED</span></strong></td>
      <td>Ordem parcial estrita <span class="math-inline">R<sub>1</sub> (jobs) &prec; R<sub>2</sub> (job_mediations) &prec; R<sub>3</sub> (escrow_maturation_entries) &prec; R<sub>4</sub> (profiles)</span> (migração <code>020</code>), eliminando ciclos no grafo de espera.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Nota média justa de estrelas do profissional&rdquo;</em></td>
      <td>Média aritmética simples distorce o ranking com amostras pequenas (1 avaliação 5,0 supera 200 avaliações 4,9) e induz retaliação.</td>
      <td><strong>Avaliação Bilateral Duplo-Cega com Suavização Bayesiana Empírica (<em>Empirical Bayes Shrinkage</em>)</strong></td>
      <td>Migração <code>010</code> (<code>20261023100000_review_system.sql</code>): ocultação recíproca até submissão bilateral ou expiração temporal (<code>reveal_job_reviews</code>) e ponderação pela média global <code>platform_avg_rating</code> em <code>refresh_provider_reputation</code>.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Apagar conta do usuário quando ele pedir&rdquo;</em></td>
      <td>Conflito aparente entre o direito de eliminação (LGPD) e o dever de retenção probatória fiscal/garantia pós-serviço.</td>
      <td><strong>Expurgo Seletivo Escopado (<span class="mono">client | provider | all</span>) com Emissão Prévio-Atômica de Dossiê Portável e Anonimização Forense</strong></td>
      <td>Edge Function <code>excluir-conta/dossie.ts</code> (<code>pdf-lib</code> A4) + RPC <code>purge_account</code> (migrações <code>012</code>, <code>018</code> e <code>027 [SEC-07]</code>), abortando a deleção caso o envio do dossiê ao titular falhe.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Relatório bonito dos consertos feitos na casa&rdquo;</em></td>
      <td>Subjetividade estética; desconsidera normas técnicas de engenharia civil/predial e autenticidade documental.</td>
      <td><strong>Passaporte Predial Vetorial (<span class="mono">%PDF-1.4</span>) em Conformidade com a ABNT NBR 5674:2012 e Selo Criptográfico <span class="mono">SHA-256</span></strong></td>
      <td><code>desperrengue_official_pdf_service.dart</code> executado em <code>Isolate.run</code>, estruturando histórico auditável de manutenções preventivas/corretivas com código verificável <code>DSP-PASS-*</code> (Lei 8.245/1991).</td>
    </tr>
    <tr>
      <td><em>&ldquo;Medalhinhas para engajar quem usa o app&rdquo;</em></td>
      <td>Trivialização lúdica; omite modelagem matemática de limiares, acessibilidade cromática e separação de papéis.</td>
      <td><strong>Motor Determinístico de Gamificação Bilateral com 112 Insígnias Vetoriais e Contraste Semântico Controlado</strong></td>
      <td><code>90</code> medalhas do Profissional (<code>9 &times; 10</code> em <code>achievements.dart</code>) + <code>22</code> do Cliente (<code>client_achievements.dart</code>), renderizadas em <code>achievement_widgets.dart</code> com estado bloqueado em prata legível <code>#CBD5E1</code> e ligas metálicas ao desbloquear.</td>
    </tr>
    <tr>
      <td><em>&ldquo;Baixar atualização nova direto pelo aplicativo&rdquo;</em></td>
      <td>Risco severo de execução remota de código arbitrário (<em>Man-in-the-Middle</em>) caso a origem do pacote não seja validada.</td>
      <td><strong>Distribuição <em>Over-The-Air</em> (OTA) com <em>Host Pinning</em> Estrito e Invalidação Atômica de Cache <em>ServiceWorker</em> PWA</strong></td>
      <td><code>app_version_and_update_service.dart</code>: verificação semântica de build, restrição de download HTTPS a <code>github.com</code> / <code>*.githubusercontent.com</code> e expurgo controlado via <code>pwa_cache_buster_web.dart</code>.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 1.2                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-1-2">
  <span class="sh-tag">SEÇÃO 1.2 &bull; ESTILÍSTICA CIENTÍFICA, IMPESSOALIDADE E NORMATIZAÇÃO EDITORIAL</span>
  <h2>1.2. Objetividade Denotativa, Impessoalidade Estrita (3ª Pessoa e Voz Passiva Analítica) e Função Referencial da Linguagem na Engenharia Documental</h2>
  <p>Primazia da função cognitiva-referencial de Jakobson, supressão morfológica de dêiticos de primeira pessoa, proposições falsificáveis e regras estilísticas para tabelas, equações e citações técnicas.</p>
</div>

<h3 id="sec-1-2-1">1.2.1. Função Referencial da Linguagem vs. Funções Emotiva e Conativa</h3>
<p>
  Segundo a teoria funcionalista da comunicação formulada por Roman Jakobson (1960), todo ato discursivo articula seis elementos constitutivos (remetente, destinatário, referente/contexto, mensagem, código e canal), instaurando seis funções linguísticas correspondentes. Em narrativas comerciais, ensaios opinativos ou relatórios informais, prevalecem a <strong>função emotiva/expressiva</strong> (centrada na subjetividade psíquica do emissor, marcada por verbos e pronomes em primeira pessoa e advérbios intensificadores não quantificados) e a <strong>função conativa/apelativa</strong> (orientada à persuasão retórica sem comprovação empírica).
</p>
<p>
  Na <strong>Engenharia Documental da Ciência da Computação</strong>, impõe-se a soberania absoluta da <strong>função referencial (denotativa ou cognitiva)</strong>, apoiada unicamente pela <strong>função metalinguística</strong> (definição rigorosa de tipos algébricos, esquemas relacionais, invariantes contábeis e protocolos criptográficos). Sob o regime estritamente denotativo, o valor de verdade de cada período textual independe da identidade biográfica ou da opinião dos autores, subordinando-se exclusivamente à correspondência verificável com o <strong>referente computacional objetivo</strong>: a árvore sintática abstrata do código-fonte Dart/Python/TypeScript, o catálogo sistêmico do PostgreSQL 17 e os relatórios reprodutíveis das suítes automatizadas de verificação.
</p>

<h3 id="sec-1-2-2">1.2.2. Morfossintaxe da Impessoalidade Estrita em 3ª Pessoa</h3>
<p>
  Para preservar o distanciamento epistemológico e a universalidade analítica ao longo de todos os capítulos deste Tratado, vigora a interdição morfossintática integral de <strong>pronomes pessoais retos, oblíquos e possessivos de primeira pessoa do singular e do plural</strong>, bem como de <strong>desinências número-pessoais de primeira pessoa do plural (morfema verbal <code>-mos</code>)</strong>. A superfície textual é construída exclusivamente mediante três mecanismos sintáticos de terceira pessoa:
</p>

<div class="cards-3col">
  <div class="info-card">
    <div class="ic-title">1. Voz Passiva Analítica</div>
    <p>Estrutura <code>[Sujeito Paciente Técnico] + [Auxiliar Ser/Estar em 3ª Pessoa] + [Particípio] + [Agente da Passiva Inanimado]</code>. Exemplo: <em>&ldquo;O segredo criptográfico de 256 bits é armazenado isoladamente pela migração <code>026</code> na tabela <code>private.geo_privacy_secrets</code>.&rdquo;</em></p>
  </div>
  <div class="info-card">
    <div class="ic-title">2. Voz Passiva Sintética (Pronominal)</div>
    <p>Estrutura <code>[Verbo Transitivo Direto em 3ª Pessoa] + [Pronome Apassivador -se] + [Sujeito Paciente]</code>. Exemplo: <em>&ldquo;Estabelecem-se quatro invariantes contábeis em centavos inteiros para o livro-razão <code>warranty_pool_ledger</code>.&rdquo;</em></p>
  </div>
  <div class="info-card">
    <div class="ic-title">3. Sujeito Inanimado Agentivo</div>
    <p>Atribuição direta da transformação de estado ao módulo executável, função pura, gatilho SQL ou teorema formal. Exemplo: <em>&ldquo;O utilitário <code>image_metadata_stripper.dart</code> extirpa sem recodificação os segmentos binários <code>APP1/EXIF</code> antes do envio.&rdquo;</em></p>
  </div>
</div>

<h3 id="sec-1-2-3">1.2.3. Estrutura Formal de Proposição Denotativa Empiricamente Falsificável</h3>
<p>
  A objetividade denotativa exige mais do que neutralidade pronominal: cada afirmação de desempenho, segurança, usabilidade ou economia unitária deve constituir um <strong>predicado quantificado decidível</strong>. Formalmente, toda proposição técnica bem-formada neste compêndio satisfaz a quíntupla epistemológica:
</p>

<div class="math-formula-box">
  <div class="math-display">
    P<sub>denot</sub> = &lang; A, E<sub>cont</sub>, M, &tau;, O<sub>test</sub> &rang;
  </div>
</div>

<p>
  na qual <span class="math-inline">A</span> identifica univocamente o <strong>artefato computacional</strong> (caminho físico no repositório, classe, RPC ou tabela); <span class="math-inline">E<sub>cont</sub></span> explicita as <strong>condições de contorno e carga</strong> (como viewport estreita de <code>320px</code> sob <code>textScaler = 1.4x</code>, ou amostragem Monte Carlo de <code>10.000</code> coordenadas); <span class="math-inline">M</span> define a <strong>grandeza física, algorítmica ou financeira aferida</strong>; <span class="math-inline">&tau;</span> fixa o <strong>limiar numérico normativo fechado</strong>; e <span class="math-inline">O<sub>test</sub></span> aponta o <strong>oráculo automatizado</strong> apto a refutar a proposição em caso de regressão. A Tabela 1.3 exemplifica essa transformação em dez domínios do projeto.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="14%">Domínio</th>
      <th width="36%">Formulação Conotativa / Subjetiva / Vaga (Rejeitada)</th>
      <th width="50%">Formulação Denotativa Impessoal em 3ª Pessoa / Voz Passiva Analítica (Padrão Oficial)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Desempenho Gráfico</strong></td>
      <td><em>&ldquo;A interface do aplicativo possui excelente fluidez visual e transições incrivelmente suaves em qualquer celular.&rdquo;</em></td>
      <td><em>&ldquo;A camada de apresentação sustenta orçamento de renderização &le; 8,33 ms por quadro (120 FPS) mediante barreiras <code>RepaintBoundary</code> e execução de rotinas intensivas em <code>Isolate.run</code>.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Privacidade Geoespacial</strong></td>
      <td><em>&ldquo;O sistema protege muito bem a casa do morador, mostrando apenas uma região aproximada antes do atendimento.&rdquo;</em></td>
      <td><em>&ldquo;O endereço exato é suprimido de <code>public.jobs</code> por gatilho SQL <code>BEFORE INSERT OR UPDATE</code>, expondo-se exclusivamente centro aproximado derivado por <code>HMAC-SHA256</code> com deslocamento em <code>[151 m, 349 m]</code> e raio em <code>[500 m, 800 m]</code> até as <code>00:00:00</code> (<code>America/Sao_Paulo</code>) da data agendada.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Integridade Contábil</strong></td>
      <td><em>&ldquo;A carteira digital calcula os saldos perfeitamente sem nunca perder nenhum centavo nas transferências.&rdquo;</em></td>
      <td><em>&ldquo;Os lançamentos em <code>ledger_lines</code> são persistidos em centavos inteiros <code>BIGINT</code> sob restrição transacional de soma algébrica nula (<code>&Sigma; cents = 0</code>) e chave única de idempotência (<code>idempotency_key</code>).&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Segurança de Segredos</strong></td>
      <td><em>&ldquo;As senhas de finalização do serviço ficam bem escondidas para ninguém conseguir descobrir pelo banco.&rdquo;</em></td>
      <td><em>&ldquo;Os atributos <code>checkout_pin_hash</code> e <code>job_presence_secret</code> são confinados na tabela <code>private.job_forensic_secrets</code> com <code>FORCE ROW LEVEL SECURITY</code> e privilégios revogados para os papéis <code>anon</code> e <code>authenticated</code> (blindagem <code>[SEC-02]</code>).&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Biometria e Custos Cloud</strong></td>
      <td><em>&ldquo;O filtro inteligente economiza bastante dinheiro descartando fotos ruins antes de chamar o servidor.&rdquo;</em></td>
      <td><em>&ldquo;A triagem heurística Tier-0 executada localmente em <code>Isolate.run</code> barra capturas sem rosto, sem foco laplaciano ou sem vivacidade a custo marginal de nuvem igual a <code>R$ 0,00</code>, mantendo o consumo de inferência remota em <code>R$ 0,034</code> por ordem ativa.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Criptografia Documental</strong></td>
      <td><em>&ldquo;O leitor de QR Code da CNH confere de verdade se o documento do motorista é oficial e autêntico.&rdquo;</em></td>
      <td><em>&ldquo;O módulo <code>crypto_doc_validator.py</code> aplica super-resolução bicúbica <code>2x</code> e equalização <code>CLAHE</code>, descomprime o payload <code>zlib</code> limitado a <code>64 KiB</code> e valida a assinatura digital <code>CMS/PKCS#7</code> (<code>ECDSA P-256</code> / <code>RSA-2048</code>) perante a cadeia ICP-Brasil/DENATRAN.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Tributação e Take Rate</strong></td>
      <td><em>&ldquo;O modelo tributário do negócio é muito vantajoso porque paga imposto só sobre o que realmente ganha.&rdquo;</em></td>
      <td><em>&ldquo;Em conformidade com o pronunciamento CPC 47 (IFRS 15) e o Subitem 10.05 da LC 116/2003, a incidência do Simples Nacional (Anexo III, <code>6,0%</code> inicial) restringe-se à receita líquida de intermediação (<code>13,5%</code> sobre mão de obra), segregando repasses a terceiros e reembolso fiscal de peças (<code>0,0%</code>).&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Acessibilidade Visual</strong></td>
      <td><em>&ldquo;As cores escuras da tela e as medalhas cinzas foram escolhidas com ótimo gosto para facilitar a leitura.&rdquo;</em></td>
      <td><em>&ldquo;O sistema cromático <em>Quiet Luxury Dark Mode</em> assegura razão de contraste &ge; 4,5:1 (WCAG 2.1 AA) e &ge; 7,0:1 em tipografia primária (<code>#EAEFF6</code> sobre <code>#0E1218</code>), renderizando insígnias bloqueadas em prata legível <code>#CBD5E1</code> sobre <code>#1E293B</code>.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Layout Responsivo</strong></td>
      <td><em>&ldquo;O cabeçalho da tela de detalhes foi arrumado para o texto não ficar espremido junto com os botões.&rdquo;</em></td>
      <td><em>&ldquo;Em <code>detalhe_servico_cliente_screen.dart</code>, o cabeçalho estrutura-se em dois andares independentes dentro do container central de <code>480px</code>: pílula de categoria e <code>StatusChip</code> no primeiro pavimento, e título descritivo com <code>width: double.infinity</code> no segundo pavimento, suportando <code>textScaler</code> até <code>1.4x</code> em <code>320px</code> sem truncamento.&rdquo;</em></td>
    </tr>
    <tr>
      <td><strong>Conformidade LGPD</strong></td>
      <td><em>&ldquo;Quando o cliente sai do aplicativo, ele recebe um arquivo completo com tudo o que fez antes de sumir do banco.&rdquo;</em></td>
      <td><em>&ldquo;Previamente à execução da RPC <code>purge_account</code>, a Edge Function <code>excluir-conta</code> sintetiza dossiê PDF vetorial A4 (<code>dossie.ts</code>) escopado por perfil (<code>client | provider | all</code>), abortando atomicamente o expurgo caso a entrega SMTP confirme falha.&rdquo;</em></td>
    </tr>
  </tbody>
</table>

<h3 id="sec-1-2-4">1.2.4. Normas Estilísticas para Tabelas Científicas, Equações Matemáticas e Citações Técnicas em Ciência da Computação</h3>
<p>
  Em alinhamento às diretrizes editoriais da <em>ACM Computing Surveys</em>, da <em>IEEE Transactions on Software Engineering</em>, da norma <strong>ABNT NBR 14724</strong> e das normas de apresentação tabular do IBGE, todos os elementos não-prosaicos deste Tratado obedecem a quatro convenções formais invariantes:
</p>
<ol>
  <li><strong>Autossuficiência Semântica de Tabelas e Figuras:</strong> nenhuma tabela ou figura é inserida como elemento solto; cada uma é anunciada previamente no parágrafo condutor, possui numeração sequencial hierárquica por capítulo (ex.: <em>Tabela 1.1</em>, <em>Figura 6.3</em>), cabeçalhos de coluna explícitos com unidades de medida inequívocas (<code>ms</code>, <code>MB</code>, <code>BIGINT centavos</code>, <code>m</code>, <code>bits</code>, <code>%</code>) e repetição automática de cabeçalho (<code>display: table-header-group</code>) quando o quadro transpõe quebras de folha A4.</li>
  <li><strong>Integração Sintática e Homogeneidade Dimensional de Equações:</strong> expressões algébricas destacadas em blocos formais (<code>.math-formula-box</code>) integram-se gramaticalmente à oração que as precede e sucede, definindo-se imediatamente o domínio matemático de cada símbolo introduzido (<span class="math-inline">&isin; &#8484;<sup>+</sup></span>, <span class="math-inline">&isin; [0, 1)</span>, <span class="math-inline">&isin; {0, 1}<sup>256</sup></span>) e respeitando-se estritamente a notação assintótica de Landau (<span class="math-inline">O(1)</span> para operações de tempo constante, <span class="math-inline">O(log N + K)</span> para buscas espaciais indexadas com <span class="math-inline">K</span> candidatos refinados).</li>
  <li><strong>Citação Canônica de Normas, Diplomas Legais e Literatura Científica:</strong> referências teóricas citam autor e ano de publicação original (Akerlof, 1970; Nielsen, 1994; Popper, 1959; Buxton, 2007; Mavin et al., 2009; Hevner et al., 2004; Osterwalder &amp; Pigneur, 2010); normas técnicas indicam código oficial do organismo emissor e edição (<code>ISO/IEC/IEEE 29148:2018</code>, <code>ABNT NBR 5674:2012</code>); e diplomas legais especificam número da lei, artigo e inciso aplicável (<code>Lei nº 13.709/2018, Art. 6º, III e Art. 18, V–VI</code>).</li>
  <li><strong>Referenciação Exata de Artefatos Executáveis:</strong> todo componente de código, migração SQL ou suíte de teste é grafado em fonte monoespaçada (<code>&lt;code&gt;</code>) utilizando o nome físico exato existente na árvore do repositório oficial, vedando-se nomes fictícios ou aproximados.</li>
</ol>

<!-- ======================================================================= -->
<!-- SEÇÃO 1.3                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-1-3">
  <span class="sh-tag">SEÇÃO 1.3 &bull; MÉTODO HIPOTÉTICO-DEDUTIVO, VERIFICABILIDADE E MATRIZ MESTRA</span>
  <h2>1.3. Estruturação Lógica Hipotético-Dedutiva e Matriz Mestra de Rastreabilidade Científica Epistemológica (<span class="mono">v2.11.0</span>)</h2>
  <p>Falsificacionismo popperiano, <em>Design Science Research</em>, taxonomia formal de oráculos de verificação e matriz mestra encadeando problemas empíricos, hipóteses, requisitos, código real e suítes automatizadas.</p>
</div>

<h3 id="sec-1-3-1">1.3.1. O Método Hipotético-Dedutivo na Engenharia de Software Experimental e <em>Design Science Research</em></h3>
<p>
  Em oposição ao desenvolvimento empírico assistemático baseado em tentativa e erro não controlado, a engenharia científica de sistemas computacionais conjuga o <strong>Método Hipotético-Dedutivo</strong> (Karl Popper, 1959) ao paradigma de <strong><em>Design Science Research</em> (DSR)</strong> em Ciência da Computação e Sistemas de Informação (Hevner et al., 2004; Wieringa, 2014). Sob esse paradigma, cada protocolo arquitetural, modelo econômico ou primitiva criptográfica introduzida no ecossistema Desperrengue constitui uma <strong>hipótese científica e arquitetural falsificável</strong> projetada para neutralizar uma classe mensurável de anomalias do mundo real.
</p>

<div class="svg-diagram-box" id="fig-01">
  <svg viewBox="0 0 920 250" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama do Ciclo Hipotético-Dedutivo e Fechamento Epistemológico no Desperrengue v2.11.0">
    <defs>
      <linearGradient id="hdDark" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="100%" stop-color="#1E3A8A"/>
      </linearGradient>
      <marker id="hdArr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#1E3A8A"/>
      </marker>
      <marker id="hdArrBack" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#10B981"/>
      </marker>
    </defs>
    <rect x="2" y="2" width="916" height="246" rx="10" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="2" y="2" width="916" height="34" rx="10" fill="url(#hdDark)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="11" font-weight="800">
      CADEIA EPISTEMOLÓGICA HIPOTÉTICO-DEDUTIVA E FECHAMENTO DE RASTREABILIDADE BIDIRECIONAL (POPPER &amp; DSR)
    </text>

    <!-- Elo 1 -->
    <rect x="18" y="54" width="160" height="118" rx="8" fill="#FFFFFF" stroke="#0F172A" stroke-width="1.5"/>
    <rect x="18" y="54" width="160" height="24" rx="8" fill="#0F172A"/>
    <text x="98" y="70" text-anchor="middle" fill="#38BDF8" font-family="Segoe UI, Arial, sans-serif" font-size="9.2" font-weight="800">1. PROBLEMA REAL (P_real)</text>
    <text x="98" y="94" text-anchor="middle" fill="#1E293B" font-family="Segoe UI, Arial, sans-serif" font-size="8.2" font-weight="700">Pesquisa N = 46 &amp; Red Team</text>
    <text x="98" y="111" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">Seleção adversa (Akerlof),</text>
    <text x="98" y="124" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">exposição domiciliar GPS,</text>
    <text x="98" y="137" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">coação, fraude e bitributação</text>
    <text x="98" y="158" text-anchor="middle" fill="#0F172A" font-family="Consolas, monospace" font-size="7.5" font-weight="700">Caps. 2 e 3</text>

    <!-- Elo 2 -->
    <rect x="200" y="54" width="164" height="118" rx="8" fill="#FFFFFF" stroke="#1E3A8A" stroke-width="1.5"/>
    <rect x="200" y="54" width="164" height="24" rx="8" fill="#1E3A8A"/>
    <text x="282" y="70" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="9.2" font-weight="800">2. HIPÓTESE (H_arq)</text>
    <text x="282" y="94" text-anchor="middle" fill="#1E293B" font-family="Segoe UI, Arial, sans-serif" font-size="8.2" font-weight="700">Teoria Formal Falsificável</text>
    <text x="282" y="111" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">HMAC-SHA256 256 bits,</text>
    <text x="282" y="124" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">Smart Split 0% + Escrow PIN,</text>
    <text x="282" y="137" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">Isolate Tier-0 + ICP-Brasil</text>
    <text x="282" y="158" text-anchor="middle" fill="#1E3A8A" font-family="Consolas, monospace" font-size="7.5" font-weight="700">ADRs 0001..0022</text>

    <!-- Elo 3 -->
    <rect x="386" y="54" width="160" height="118" rx="8" fill="#FFFFFF" stroke="#0284C7" stroke-width="1.5"/>
    <rect x="386" y="54" width="160" height="24" rx="8" fill="#0284C7"/>
    <text x="466" y="70" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="9.2" font-weight="800">3. REQUISITOS (R_norm)</text>
    <text x="466" y="94" text-anchor="middle" fill="#1E293B" font-family="Segoe UI, Arial, sans-serif" font-size="8.2" font-weight="700">ISO 29148 + 25010 + EARS</text>
    <text x="466" y="111" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">42 RFs monossêmicos,</text>
    <text x="466" y="124" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">25 RNFs quantificados,</text>
    <text x="466" y="137" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">12 US Gherkin + WSJF</text>
    <text x="466" y="158" text-anchor="middle" fill="#0284C7" font-family="Consolas, monospace" font-size="7.5" font-weight="700">Cap. 4 &amp; Cap. 5</text>

    <!-- Elo 4 -->
    <rect x="568" y="54" width="160" height="118" rx="8" fill="#FFFFFF" stroke="#EA580C" stroke-width="1.5"/>
    <rect x="568" y="54" width="160" height="24" rx="8" fill="#EA580C"/>
    <text x="648" y="70" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="9.2" font-weight="800">4. CÓDIGO REAL (I_cod)</text>
    <text x="648" y="94" text-anchor="middle" fill="#1E293B" font-family="Segoe UI, Arial, sans-serif" font-size="8.2" font-weight="700">Clean Arch &amp; PostgreSQL 17</text>
    <text x="648" y="111" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">app/lib/ (120 FPS), 27+3 SQL,</text>
    <text x="648" y="124" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">5 Deno Edge Functions,</text>
    <text x="648" y="137" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">kyc_engine/ Python FastAPI</text>
    <text x="648" y="158" text-anchor="middle" fill="#EA580C" font-family="Consolas, monospace" font-size="7.5" font-weight="700">Cap. 6 (Seções 6.1–6.2)</text>

    <!-- Elo 5 -->
    <rect x="750" y="54" width="152" height="118" rx="8" fill="#FFFFFF" stroke="#059669" stroke-width="1.5"/>
    <rect x="750" y="54" width="152" height="24" rx="8" fill="#059669"/>
    <text x="826" y="70" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="9.2" font-weight="800">5. ORÁCULO (A_test)</text>
    <text x="826" y="94" text-anchor="middle" fill="#1E293B" font-family="Segoe UI, Arial, sans-serif" font-size="8.2" font-weight="700">Tentativa de Refutação</text>
    <text x="826" y="111" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">762 Flutter (816 HEAD),</text>
    <text x="826" y="124" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">64 pytest, 12/14 SQL Geo,</text>
    <text x="826" y="137" text-anchor="middle" fill="#475569" font-family="Segoe UI, Arial, sans-serif" font-size="7.7">17 PDF LGPD, 630 MD links</text>
    <text x="826" y="158" text-anchor="middle" fill="#059669" font-family="Consolas, monospace" font-size="7.5" font-weight="700">exit code = 0</text>

    <!-- Setas progressivas -->
    <line x1="178" y1="113" x2="198" y2="113" stroke="#1E3A8A" stroke-width="2" marker-end="url(#hdArr)"/>
    <line x1="364" y1="113" x2="384" y2="113" stroke="#1E3A8A" stroke-width="2" marker-end="url(#hdArr)"/>
    <line x1="546" y1="113" x2="566" y2="113" stroke="#1E3A8A" stroke-width="2" marker-end="url(#hdArr)"/>
    <line x1="728" y1="113" x2="748" y2="113" stroke="#1E3A8A" stroke-width="2" marker-end="url(#hdArr)"/>

    <!-- Arco de retroalimentação / corroboração empírica -->
    <path d="M 826 174 L 826 218 L 98 218 L 98 176" fill="none" stroke="#10B981" stroke-width="1.8" stroke-dasharray="6 4" marker-end="url(#hdArrBack)"/>
    <rect x="195" y="205" width="540" height="24" rx="5" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1"/>
    <text x="465" y="220" text-anchor="middle" fill="#065F46" font-family="Segoe UI, Arial, sans-serif" font-size="8.3" font-weight="800">
      RASTREABILIDADE REGRESSIVA &amp; CORROBORAÇÃO EMPÍRICA (ZERO REQUISITOS ÓRFÃOS / ZERO GOLD-PLATING)
    </text>
  </svg>
  <div class="svg-caption">Figura 1.1 — Arquitetura Epistemológica Hipotético-Dedutiva (Popper, 1959) conjugada à <em>Design Science Research</em> (Hevner et al., 2004): encadeamento determinístico entre dores empíricas, hipóteses formais, especificação EARS/ISO, código de produção e oráculos automatizados de falsificação.</div>
</div>

<div class="innovation-box">
  <div class="ib-header">Invariante de Fechamento Epistemológico: Ausência de Requisitos Órfãos e de <em>Gold-Plating</em></div>
  <p>
    Seja <span class="math-inline">R</span> o conjunto finito de requisitos especificados no Capítulo 4, <span class="math-inline">I</span> o conjunto de módulos implementados no Capítulo 6 e <span class="math-inline">T</span> o conjunto de suítes automatizadas de verificação. O projeto impõe duas relações sobrejetoras simultâneas: (i) <strong>Rastreabilidade Regressiva</strong> (<span class="math-inline">&forall; r &isin; R, &exist; (p, h) &isin; P<sub>real</sub> &times; H<sub>arq</sub></span>), vedando funcionalidades arbitrárias divorciadas de dores reais verificadas; e (ii) <strong>Rastreabilidade Progressiva Completa</strong> (<span class="math-inline">&forall; r &isin; R, &exist; i &isin; I &and; &exist; t &isin; T</span>), extinguindo tanto requisitos meramente declarativos sem código correspondente quanto código de produção desprovido de cobertura por asserções automatizadas.
  </p>
</div>

<h3 id="sec-1-3-2">1.3.2. Critérios Formais de Verificabilidade, Refutabilidade e Taxonomia de Oráculos Automatizados</h3>
<p>
  Segundo a cláusula <code>5.2.8</code> da norma <strong>ISO/IEC/IEEE 29148:2018</strong>, uma especificação somente é cientificamente válida se existir um procedimento finito, objetivo e economicamente executável capaz de demonstrar se o artefato construído satisfaz ou viola a declaração. Para evitar não-determinismo (<em>flaky tests</em>), todos os oráculos do repositório operam com relógios determinísticos injetáveis, sementes pseudoaleatórias controladas e asserções algébricas exatas, distribuídos em seis modalidades complementares:
</p>
<ul>
  <li><strong>Oráculo Algébrico e Criptográfico Unitário (<span class="math-inline">O<sub>unit</sub></span>):</strong> valida propriedades puras de conservação em centavos (<code>Money.allocate</code>), dígitos verificadores Módulo 11 (CPF, CNPJ e chave NF-e de 44 dígitos), distância de Hamming em 64 bits, assinaturas <code>ECDSA P-256</code> ICP-Brasil e decriptação autenticada <code>AES-256-GCM</code>.</li>
  <li><strong>Oráculo Geométrico e de Acessibilidade de Widgets (<span class="math-inline">O<sub>widget</sub></span>):</strong> instancia árvores completas Flutter em viewports restritas (<code>320px &times; 640px</code>) com fator de escala tipográfica <code>textScaler = 1.4x</code>, verificando zero ocorrências de <code>RenderFlex overflowed</code>, contraste cromático e ocultação estrita de endereços bloqueados.</li>
  <li><strong>Oráculo Estocástico de Monte Carlo (<span class="math-inline">O<sub>mc</sub></span>):</strong> submete funções de ofuscação espacial (<code>_geo_fuzzy_center</code> via <code>HMAC-SHA256</code>) a <code>10.000</code> execuções independentes para comprovar empiricamente que 100% das amostras respeitam os limites geométricos fechados <span class="math-inline">d<sub>off</sub> &isin; [151 m, 349 m]</span> e <span class="math-inline">R<sub>pub</sub> &isin; [500 m, 800 m]</span>.</li>
  <li><strong>Oráculo Transacional e de Segurança Relacional (<span class="math-inline">O<sub>sql</sub></span>):</strong> audita políticas <code>RLS</code> e <code>FORCE RLS</code>, revogação de privilégios para <code>anon/PUBLIC</code>, fixação de <code>search_path = public</code> em rotinas <code>SECURITY DEFINER</code> e invariantes de soma zero e solvência sob concorrência no PostgreSQL 17.</li>
  <li><strong>Oráculo Estrutural Binário de Documentos (<span class="math-inline">O<sub>pdf</sub></span>):</strong> inspeciona cabeçalhos <code>%PDF-1.x</code>, tabelas de referência cruzada <code>xref</code>, dimensões físicas A4 (<code>MediaBox</code>), paginação sem sobreposição (até 29 páginas e 200+ registros em <code>test-dossie.mjs</code>) e selos criptográficos <code>SHA-256</code>.</li>
  <li><strong>Oráculo Estático de Grafo Documental e Arquitetural (<span class="math-inline">O<sub>static</sub></span>):</strong> percorre recursivamente a árvore do repositório para assegurar integridade de 100% dos links hipertextuais (<code>check-md-links.mjs</code>) e ausência de flags de simulação em builds de produção (<code>eng_static_guards_test.dart</code>).</li>
</ul>

<h3 id="sec-1-3-3">1.3.3. Matriz Mestra de Rastreabilidade Científica Epistemológica (<span class="mono">v2.11.0</span>)</h3>
<p>
  A Tabela 1.4 consolida a espinha dorsal epistemológica do ecossistema Desperrengue até a versão <code>v2.11.0</code>, conectando formalmente os quinze subsistemas estruturantes desde a formulação do problema real até as asserções exatas de teste automatizado que os corroboram no repositório.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Problema Real Identificado (<span class="math-inline">P<sub>real</sub></span>)</th>
      <th width="21%">Hipótese Científica / Arquitetural Falsificável (<span class="math-inline">H<sub>arq</sub></span>)</th>
      <th width="14%">Requisitos Associados (<span class="mono">Cap. 4</span>)</th>
      <th width="25%">Implementação Real no Código (<span class="mono">c:/00_Desperrengue</span>)</th>
      <th width="24%">Asserção de Teste Automatizado (<span class="math-inline">A<sub>test</sub></span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>[E-01] Exposição Prematura do Domicílio:</strong> publicar rua, número e GPS exato na abertura do pedido expõe moradores (<code>60,7%</code> receiam estranhos) a reconhecimento prévio indevido por terceiros não contratados ou dias antes do atendimento.</td>
      <td>Se o banco suprimir coordenadas exatas de <code>public.jobs</code> e projetar círculo determinístico (<code>500m–800m</code>) via <code>HMAC-SHA256</code> com segredo CSPRNG de 256 bits isolado em <code>private.*</code>, liberando o endereço somente às <code>00:00:00</code> (<code>America/Sao_Paulo</code>) da data agendada ao prestador contratado e re-ofuscando após a conclusão, elimina-se a superfície de oráculo espacial e temporal.</td>
      <td><code>RF-GEO-01</code>, <code>RF-GEO-02</code>, <code>RNF-SEG-01</code>, <code>RN-GEO-01..04</code> (<code>ADR-0022</code>)</td>
      <td>Migração <code>026</code> (<code>20261113100000_temporal_geo_privacy_lock.sql</code>): <code>private.geo_privacy_secrets</code>, <code>_geo_fuzzy_center</code>, <code>_job_privacy_phase</code>, <code>_can_see_exact_location</code>, <code>get_job_location_for_viewer</code>; widgets em <code>geo_privacy_widgets.dart</code> (<code>ProtectedAreaMapCard</code>, <code>GeoLockNotice</code>, <code>ProtectedAreaMapSheet</code>, <code>ProviderLocationPanel</code> e <code>ProviderLocationBuilder</code>).</td>
      <td><code>scripts/test-geo-privacy-sql.mjs</code> (<code>12/12</code> na <code>v2.11.0</code>; <code>14/14</code> no <code>HEAD</code>, Monte Carlo <code>10.000</code> amostras: <code>dist &isin; [151m, 349m]</code>) + <code>geo_privacy_policy_engine_test.dart</code>, <code>temporal_geo_privacy_lock_widgets_test.dart</code>, <code>provider_geo_privacy_ui_test.dart</code> e <code>supabase/tests/geo_privacy_lock.sql</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-02] Seleção Adversa e Venda Predatória de Leads:</strong> plataformas baseadas em venda de moedas para desbloqueio de contatos geram rejeição de <code>100,0%</code> entre prestadores autônomos (<code>18/18</code>) e afugentam técnicos qualificados.</td>
      <td>Se a distribuição de chamados operar com custo zero por lead e cobrança exclusivamente no êxito sobre mão de obra (<code>13,5% + 1,5%</code>), aliada a despacho geoespacial equiprovável em anéis (<code>0,4–8,0 km</code>) e identidade verificada bilateral, maximiza-se a liquidez qualificada e atinge-se <code>LTV/CAC = 9,65x</code> com <em>break-even</em> em <code>40 OS/mês</code> (<code>M3</code>).</td>
      <td><code>RF-MKT-01</code>, <code>RF-ORC-01</code>, <code>RN-MZ-01</code>, <code>RN-AF-01</code></td>
      <td>Migrações <code>002</code>, <code>004</code>, <code>017</code> e <code>023</code>: tabelas <code>jobs</code>, <code>quotes</code>, <code>provider_profiles</code>, índice GIN <code>provider_profiles_specialty_slugs_gin</code>, despacho por anéis equiprováveis e RPC <code>accept_quote</code>.</td>
      <td><code>client_flow_widgets_test.dart</code>, <code>tag_match_test.dart</code>, <code>supabase/tests/category_match_smoke.sql</code>, <code>supabase/tests/expanded_categories_smoke.sql</code> e modelagem econométrica auditada no Capítulo 3.</td>
    </tr>
    <tr>
      <td><strong>[E-03] Bitributação Econômica sobre Peças e Insumos:</strong> aplicar comissão percentual única sobre o valor global do orçamento pune serviços intensivos em reposição de componentes e induz desintermediação (<em>bypass</em> por fora do aplicativo).</td>
      <td>Se o orçamento for particionado em Mão de Obra (<code>15,0%</code> total) e Materiais/Peças (<code>0,0%</code> condicionado a NF-e/NFC-e válida de 44 dígitos Módulo 11), com auditoria assíncrona SEFAZ após <code>26h</code> e <em>clawback</em> automático de <code>15%</code> sobre notas canceladas, anula-se o incentivo econômico à evasão sem abrir brecha para fraude fiscal.</td>
      <td><code>RF-FIN-01</code> (<em>Smart Split</em>), <code>RN-MZ-02</code>, <code>RN-AF-05</code>, <code>RNF-CONF-02</code></td>
      <td>Migração <code>023</code> (<code>20261110234000_zero_trust_bilateral_antifraud_v285.sql</code>) e <code>030</code>: tabela <code>job_fiscal_documents</code>, validador Módulo 11 (<code>nfe_access_key.dart</code> e CNPJ), RPC <code>audit_sefaz_phase2_cancellation_and_clawback</code> e endpoint <code>/v1/smart-split/verify-invoice</code>.</td>
      <td><code>eng_smart_split_cents_test.dart</code>, <code>eng_money_and_failure_test.dart</code>, <code>nfe_access_key_test.dart</code>, <code>material_receipt_capture_screen_test.dart</code>, <code>provider_real_receipts_services_test.dart</code> e <code>supabase/tests/forensic_photo_and_fiscal.sql</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-04] Risco Moral Bilateral no Pagamento Presencial:</strong> adiantamento via PIX direto expõe o morador ao abandono de obra; pagamento pós-serviço sem trava expõe o técnico à inadimplência (<code>55,6%</code> relatam prejuízo com &ldquo;clientes fantasmas&rdquo;).</td>
      <td>Se o valor integral permanecer retido em custódia fiduciária (<em>Smart Escrow</em>) antes do início da execução e sua liberação exigir prova criptográfica presencial via PIN de 4 dígitos (<code>bcrypt</code>) mais maturação escalonada conforme escore de confiança (<code>RTS</code>), neutraliza-se simetricamente o inadimplemento de ambas as pontas.</td>
      <td><code>RF-ESC-01</code>, <code>RF-ESC-02</code>, <code>RNF-CONF-01</code>, <code>RN-MZ-03</code></td>
      <td>Migrações <code>005</code>, <code>013</code>, <code>020</code> e <code>027 [SEC-02]</code>: <code>client_wallets</code>, <code>private.job_forensic_secrets</code>, <code>complete_job_and_schedule_escrow</code>, <code>escrow_maturation_entries</code> e Edge Function <code>pix-webhook</code> (<code>confirm_topup</code>).</td>
      <td><code>wallet_test.dart</code>, <code>completion_redesign_test.dart</code>, <code>fintech_warranty_security_test.dart</code> e <code>supabase/tests/client_wallet_smoke.sql</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-05] Coação Física Domiciliar na Liquidação Financeira:</strong> exigir recusa explícita no aplicativo diante de intimidação presencial coloca em risco a integridade física do morador ou do prestador no interior da residência.</td>
      <td>Se o motor de liquidação reconhecer a digitação invertida do PIN de 4 dígitos (ex.: <code>4819 &rarr; 9184</code>) como sinal esteganográfico de coação, renderizando tela verde indistinguível de conclusão bem-sucedida enquanto bloqueia silenciosamente o saque (<code>FROZEN_UNDER_DURESS</code>) e preserva telemetria forense, protege-se a vida humana sem perda patrimonial.</td>
      <td><code>RF-SEG-03</code> (Cofre Dual Anti-Coação), <code>RN-AF-08</code>, <code>RNF-SEG-04</code></td>
      <td><code>app/lib/core/security/zero_trust_bilateral_security_engine.dart</code> (<code>evaluatePinSubmission</code>, detecção de palíndromos na geração do PIN e estado silencioso <code>FROZEN_UNDER_DURESS</code>) + isolamento em <code>private.job_forensic_secrets</code>.</td>
      <td><code>red_team_warranty_and_kyc_forensics_test.dart</code> e <code>fintech_warranty_security_test.dart</code> (asserções determinísticas para PIN canônico, PIN reverso sob coação, rejeição de PINs palindrômicos e tentativas inválidas).</td>
    </tr>
    <tr>
      <td><strong>[E-06] Inexecução Prática da Garantia Legal de 90 Dias (CDC Art. 26, II):</strong> no mercado informal (<code>96,4%</code>), defeitos recorrentes após o pagamento resultam em bloqueio no mensageiro e prejuízo integral ao morador (<code>92,9%</code> demandam garantia efetiva).</td>
      <td>Se um <em>carve-out</em> contábil automático de <code>1,5%</code> sobre a mão de obra capitalizar um livro-razão mutualista imutável (<code>warranty_pool_ledger</code>) regido por 4 invariantes em <code>BIGINT</code> e 3 camadas graduais de resolução (autocomposição, retrabalho geoespacial <span class="math-inline">O(log N + K)</span> e cobertura atuarial), assegura-se garantia de 90 dias com ponto de equilíbrio em <code>66,67</code> serviços por sinistro integral.</td>
      <td><code>RF-GAR-01</code>, <code>RF-GAR-02</code>, <code>RN-CAM-01..03</code>, <code>RNF-CONF-03</code></td>
      <td>Migração <code>020</code> (<code>20261108110000_high_perf_warranty_antifraud_engine.sql</code>) e <code>021</code>: tabelas <code>warranty_pool_ledger</code>, <code>job_mediations</code>, RPCs <code>open_warranty_mediation</code>, <code>trigger_layer3_rework</code> e ordenação de locks <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span>.</td>
      <td><code>fintech_warranty_security_test.dart</code> e <code>red_team_warranty_and_kyc_forensics_test.dart</code> (validação dos 4 invariantes contábeis, solvência <code>running_balance_cents &ge; 0</code> e ausência de <em>deadlocks</em>).</td>
    </tr>
    <tr>
      <td><strong>[E-07] Fraude de Identidade, Falsificação Documental e Custo Proibitivo de Bureaus KYC:</strong> validações manuais ou chamadas irrestritas de IA em nuvem sobre capturas borradas/fraudadas inviabilizam a margem unitária ou aprovam identidades sintéticas (<em>deepfakes</em> / <em>replay</em>).</td>
      <td>Se a verificação combinar: (1) filtro Tier-0 local em <code>Isolate.run</code> a custo <code>R$ 0,00</code>; (2) visão estruturada Gemini 4 Argon High com proteção anti-<em>prompt-injection</em>; (3) decodificação criptográfica VIO/ICP-Brasil (<code>CMS PKCS#7 ECDSA P-256</code>) + SERPRO mTLS 1.3; e (4) 5 <em>Hard Vetos</em> determinísticos + Gemini 4 Carbon High com Top-3 fatores SHAP (LGPD Art. 20), bloqueiam-se fraudes documentais mantendo custo marginal de nuvem em <code>R$ 0,034</code>.</td>
      <td><code>RF-KYC-01..04</code>, <code>RN-KYC-01..06</code>, <code>RNF-SEG-02</code> (<code>ADR-0021</code>)</td>
      <td><code>document_ocr_and_liveness_service.dart</code>, Edge Functions <code>kyc-argon-vision-gate</code> e <code>kyc-carbon-webhook</code>, microsserviço Python FastAPI <code>kyc_engine/app/services/</code> (<code>crypto_doc_validator.py</code>, <code>serpro_datavalid.py</code>, <code>fraud_orchestrator.py</code>, <code>vision_ocr_argon.py</code> + cofre WORM <code>AES-256-GCM</code> em <code>security.py</code>) e migração <code>025</code>.</td>
      <td><code>kyc_engine/tests/</code> (<strong>64/64 testes <code>pytest</code></strong> em 3 suítes: <code>test_carbon_security_and_crypto.py</code> [16], <code>test_end_to_end_pipeline_redteam.py</code> [10], <code>test_vision_ocr_argon.py</code> [38]) + <code>argon_carbon_kyc_and_ux_test.dart</code> e <code>red_team_warranty_and_kyc_forensics_test.dart</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-08] Vazamento de Coordenadas EXIF em Fotos e Reuso Fraudulento de Evidências:</strong> câmeras móveis embutem latitude/longitude exata em cabeçalhos <code>EXIF</code> de fotos de portfólio/chamados, enquanto fraudadores reutilizam fotos antigas da internet como falsa prova de serviço concluído.</td>
      <td>Se todo upload de imagem atravessar sanitizador binário sem perdas (<em>lossless fail-closed</em>) que extirpa segmentos <code>EXIF/GPS/XMP/IPTC</code> no cliente e calcular assinatura perceptual <code>dHash</code> de 64 bits comparada em <span class="math-inline">O(1)</span> via <code>POPCNT(h1 # h2)</code> no PostgreSQL, impedem-se simultaneamente vazamentos geográficos em mídia e duplicação de evidências.</td>
      <td><code>RF-FOR-01</code>, <code>RNF-SEG-03</code>, <code>RNF-DES-03</code></td>
      <td><code>app/lib/core/utils/image_metadata_stripper.dart</code>, <code>perceptual_hash_guard.dart</code> (recorte de <code>12%</code> e filtro de textura <code>MAD</code>), migrações <code>020</code> e <code>030</code> (<code>hamming_distance_64</code> com máscara <code>INT64_MIN</code> e RPC <code>register_forensic_photo</code>) + bucket privado <code>forensic-evidence</code> (<code>[SEC-09]</code>).</td>
      <td><code>eng_image_metadata_stripper_test.dart</code>, <code>eng_media_upload_sanitize_test.dart</code>, <code>red_team_warranty_and_kyc_forensics_test.dart</code>, <code>supabase/tests/forensic_photo_and_fiscal.sql</code> e verificações <code>13–14</code> de <code>scripts/test-geo-privacy-sql.mjs</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-09] Superfície de Ataque Interna em SGBD Multi-Tenant (IDOR, Escalada de Privilégio e <em>Search-Path Hijacking</em>):</strong> funções <code>SECURITY DEFINER</code> sem <code>search_path</code> fixo ou tabelas auxiliares expostas ao PostgREST permitem leitura cruzada de segredos ou acionamento indevido de rotinas financeiras.</td>
      <td>Se uma auditoria <em>Red Team</em> aplicar 9 blindagens sistemáticas (<code>[SEC-01]</code> a <code>[SEC-09]</code>) — revogando privilégios públicos em <em>workers</em> internos, forçando <code>auth.uid()</code> contra IDOR, isolando segredos em <code>private.*</code> e fixando <code>SET search_path = public</code> em todas as &ge;35 rotinas <code>SECURITY DEFINER</code> — fecha-se a superfície de escalada horizontal e vertical no PostgreSQL.</td>
      <td><code>RNF-SEG-05</code>, <code>RNF-CONF-04</code></td>
      <td>Migração <code>027</code> (<code>20261113110000_security_hardening_audit.sql</code>): <code>[SEC-01]</code> a <code>[SEC-09]</code> cobrindo 6 tabelas forenses/financeiras, <code>private.job_forensic_secrets</code>, 8 RPCs críticas, 3 <em>workers</em> internos e &ge;35 funções auditadas.</td>
      <td><code>scripts/test-geo-privacy-sql.mjs</code> (asserções estáticas e funcionais sobre grants, <code>RLS</code>, <code>FORCE RLS</code> e <code>search_path</code>) + <code>supabase/tests/security_smoke.sql</code> e <code>eng_static_guards_test.dart</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-10] Atrito de Cadastro Duplo entre Morador e Prestador:</strong> exigir contas e e-mails distintos para contratar serviços domésticos e ofertar serviços técnicos fragmenta a base de usuários e duplica custos de verificação biométrica.</td>
      <td>Se a identidade for unificada sobre chave primária única (<code>profiles.id = auth.uid()</code>) com chaveamento transacional instantâneo Multi-Modo (<code>client &harr; provider</code>) e herança automática de KYC biométrico já aprovado (+30 pontos em <code>RTS</code>), reduz-se o atrito de ativação cruzada a zero retrabalho documental.</td>
      <td><code>RF-AUT-01</code>, <code>RF-AUT-02</code>, <code>ADR-0004</code>, <code>ADR-0005</code></td>
      <td>Migrações <code>001</code> (<code>20261009120000_unify_profiles_and_kyc.sql</code>), <code>004</code> (<code>enroll_mode</code>, <code>set_last_mode</code>) e <code>021</code> (herança bilateral de <code>cpf_verified</code> e <code>liveness_verified</code> em <code>submit_client_kyc</code>).</td>
      <td><code>user_profile_test.dart</code>, <code>account_screens_test.dart</code> e <code>supabase/tests/security_smoke.sql</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-11] Engasgos de Quadro (<em>Jank</em>) e Latência Visual em Redes Móveis Instáveis:</strong> decodificação síncrona de imagens na <em>UI thread</em> e recarregamento repetitivo de avatares/portfólios degradam a taxa de quadros abaixo de 60 Hz e elevam o abandono.</td>
      <td>Se a renderização combinar <code>RepaintBoundary</code>, pré-busca proativa com cancelamento em rolagem rápida (<code>EagerImagePrefetcher</code>), cache duplo L1/L2 de <code>0 ms</code> (<code>InstantImageCacheEngine</code>) e mutação otimista especulativa (<code>&lt; 50 ms</code>) com <em>streams</em> resilientes exponenciais, preserva-se fluidez de <code>120 FPS</code> (<code>8,33 ms/quadro</code>).</td>
      <td><code>RNF-DES-01</code>, <code>RNF-DES-02</code>, <code>RNF-USA-02</code></td>
      <td><code>instant_image_cache_engine.dart</code> (contendo <code>InstantImageCacheEngine</code>, <code>InstantCachedImage</code> e <code>EagerImagePrefetcher</code>), <code>unread_orders_badge_controller.dart</code> (<span class="math-inline">O(1)</span>) e <code>resilient_stream.dart</code>.</td>
      <td><code>carbon_geo_badges_and_image_cache_test.dart</code>, <code>eng_image_cache_privacy_test.dart</code>, <code>eng_unread_badge_test.dart</code> e <code>eng_resilience_and_policy_test.dart</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-12] Colisão Tipográfica em Telas Pequenas (<span class="mono">320px</span>) e Poluição de Mapas de Rastreamento:</strong> cabeçalhos de linha única truncam títulos longos quando combinados com chips de status sob acessibilidade (<code>textScaler 1.4x</code>), e cards opacos encobrem a rota no mapa ao vivo.</td>
      <td>Se o layout impuser container responsivo centralizado (<code>maxWidth: 480</code>), cabeçalho estruturado em <strong>2 andares</strong> em <code>Detalhe do serviço</code> (chips acima, <code>headline</code> 100% largura abaixo) e modal cartográfico dedicado com <code>&ge; 80%</code> de área livre de mapa (cascata dupla OSRM + fallback geodésico <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos), extinguem-se <em>overflows</em> e obstruções espaciais.</td>
      <td><code>RNF-USA-01</code>, <code>RNF-USA-03</code>, <code>RF-MAP-01</code></td>
      <td><code>detalhe_servico_cliente_screen.dart</code> (linhas <code>329–387</code>), <code>order_live_map_modal_screen.dart</code> e sistema de tokens <code>app_tokens.dart</code>.</td>
      <td><code>ux_client_and_shared_polish_test.dart</code>, <code>orders_map_ux_and_instant_media_test.dart</code> e <code>ui_polish_test.dart</code> (incluindo regressão de <em>overflow</em> em <code>320px</code> com <code>textScaler = 1.4x</code>).</td>
    </tr>
    <tr>
      <td><strong>[E-13] Perda do Histórico Técnico de Manutenção Predial:</strong> recibos informais dispersos impedem proprietários, inquilinos e síndicos de comprovar manutenções preventivas/corretivas exigidas pela <strong>ABNT NBR 5674</strong> e pela Lei do Inquilinato (Lei 8.245/1991).</td>
      <td>Se cada ordem de serviço concluída puder ser compilada localmente em <code>Isolate.run</code> em um <strong>Passaporte Oficial de Manutenção do Imóvel</strong> vetorial (<code>%PDF-1.4</code>) contendo qualificação técnica, insumos fiscais, garantia e hash criptográfico <code>SHA-256</code> (<code>DSP-PASS-*</code>), transforma-se o histórico doméstico em ativo documental auditável.</td>
      <td><code>RF-DOC-01</code>, <code>RNF-SUP-02</code></td>
      <td><code>app/lib/core/services/desperrengue_official_pdf_service.dart</code> (gerador vetorial puro <code>%PDF-1.4</code> executado fora da <em>thread</em> principal via <code>off_thread.dart</code>).</td>
      <td><code>client_history_test.dart</code> e <code>fintech_warranty_security_test.dart</code> (validação estrutural de cabeçalho <code>%PDF-1.4</code>, objetos <code>xref</code>, integridade de campos e selo <code>DSP-PASS-*</code>).</td>
    </tr>
    <tr>
      <td><strong>[E-14] Tensão entre Direito ao Esquecimento (LGPD Art. 18) e Portabilidade / Auditoria Pós-Serviço:</strong> exclusões destrutivas sem entrega prévia de histórico lesam a portabilidade do titular, ao passo que travas de imutabilidade forense podem bloquear a anonimização legal.</td>
      <td>Se o fluxo de encerramento gerar previamente dossiê PDF A4 escopado (<code>client | provider | all</code>), abortar a deleção caso o disparo por e-mail falhe e reconciliar os gatilhos de imutabilidade pós-conclusão para admitir exclusivamente a anonimização controlada de <code>purge_account</code>, cumprem-se simultaneamente os Arts. 16 e 18 da LGPD.</td>
      <td><code>RF-LGPD-01</code>, <code>RF-LGPD-02</code> (<code>ADR-0013</code>)</td>
      <td><code>supabase/functions/excluir-conta/index.ts</code> + <code>dossie.ts</code> (<code>pdf-lib</code>) e migrações <code>012</code>, <code>018</code> e <code>027 [SEC-07]</code> (<code>account_dossier</code>, <code>_deletion_blockers</code>, <code>purge_account</code>).</td>
      <td><code>scripts/test-dossie.mjs</code> (<strong>17/17 testes vetoriais PDF aprovados</strong>, incluindo paginação de 200+ itens em 29 páginas A4) + <code>supabase/tests/offboarding_showcase_smoke.sql</code>, <code>supabase/tests/scoped_deletion_smoke.sql</code> e <code>offboarding_boot_theme_test.dart</code>.</td>
    </tr>
    <tr>
      <td><strong>[E-15] Baixa Retenção Recorrente e Medalhas Inativas Ilegíveis em Tema Escuro:</strong> marketplaces utilitários sofrem erosão de engajamento entre chamados esporádicos, e ícones bloqueados de baixo contraste tornam-se invisíveis em fundos escuros.</td>
      <td>Se o ecossistema cobrir <strong>33 categorias residenciais</strong> com ícones vetoriais <em>Duotone</em> e instituir matriz bilateral de <strong>112 medalhas</strong> (<code>90</code> do Profissional + <code>22</code> do Cliente) renderizadas com estado bloqueado em prata de alto contraste (<code>#CBD5E1</code> sobre <code>#1E293B</code>) e desbloqueado em ligas metálicas vibrantes, estimula-se recorrência multi-categoria preservando legibilidade WCAG.</td>
      <td><code>RF-GAM-01</code>, <code>RF-CAT-01</code>, <code>RNF-USA-04</code> (<code>ADR-0012</code>)</td>
      <td><code>marketplace_models.dart</code> (<code>kCategories</code> = 33), <code>achievements.dart</code> (90), <code>client_achievements.dart</code> (22), <code>achievement_widgets.dart</code> (<code>AchievementMedalForge</code>) e migrações <code>011</code> e <code>019</code>.</td>
      <td><code>achievements_test.dart</code>, <code>orders_and_client_achievements_test.dart</code>, <code>ux_client_and_shared_polish_test.dart</code>, <code>supabase/tests/achievements_smoke.sql</code> e auditoria integral de links documentais (<code>scripts/check-md-links.mjs</code>: <strong>630/630 links íntegros</strong>).</td>
    </tr>
  </tbody>
</table>

<p>
  Consolidados o vocabulário técnico monossêmico, os moldes sintáticos EARS/ISO 29148, a morfossintaxe impessoal denotativa em terceira pessoa e a cadeia hipotético-dedutiva de verificação, o Capítulo 2 aplica esse arcabouço científico à investigação empírica de mercado, à análise microeconômica das falhas estruturais dos serviços domiciliares no Brasil e à formulação estratégica da proposta de valor do ecossistema Desperrengue.
</p>
</section>
`;

import {
  svgLowFiSketches,
  svgMidFiWireframes,
  svgHiFiScreensAndTokens,
} from './svg_ch5_ch6_ux_arch.mjs';

export const ch5Html = String.raw`
<!-- ======================================================================= -->
<!-- CAPÍTULO 5 — PROJETO DE INTERFACE (UI/UX), PROTOTIPAÇÃO EM 3 NÍVEIS E   -->
<!--              AUDITORIA PELAS 10 HEURÍSTICAS DE JAKOB NIELSEN            -->
<!-- ======================================================================= -->
<section class="chapter-section" id="cap-5">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 5</div>
  <div class="cb-body">
    <h2>PROJETO DE INTERFACE (UI/UX), PROTOTIPAÇÃO EVOLUTIVA EM 3 NÍVEIS E AUDITORIA PELAS 10 HEURÍSTICAS DE JAKOB NIELSEN</h2>
    <p>Engenharia Semiótica e Interação Humano-Computador (IHC), Ergonomia Cognitiva e Motora (Leis de Fitts e Hick-Hyman), Evolução Estrutural Low-Fi / Mid-Fi / Hi-Fi, Catálogo de Telas de Produção, Design System <em>Quiet Luxury Dark Mode</em> (WCAG 2.1 AAA), Sistema Iconográfico <em>Duotone</em> de 33 Categorias, Forja Vetorial das 112 Medalhas (<code>#CBD5E1</code> vs. Ligas Vibrantes) e Auditoria Exaustiva de Usabilidade (H1 a H10) até a <code>v2.11.0</code>.</p>
  </div>
</div>

<p>
  Em sistemas ciberfísicos e plataformas de intermediação transacional de alta criticidade — nos quais cidadãos autorizam o ingresso de prestadores técnicos em seus domicílios e custodiam recursos financeiros sob liquidação instantânea —, a camada de <strong>Interação Humano-Computador (IHC)</strong> não desempenha papel meramente cosmético, mas atua como <strong>fronteira primária de segurança operacional, inclusão cognitiva e mitigação de assimetria informacional</strong>. Sob o arcabouço teórico da <strong>Engenharia Semiótica</strong> formulada por Clarisse Sieckenius de Souza (2005), a interface de usuário constitui um artefato de metacomunicação unidirecional por meio do qual a engenharia do sistema transmite continuamente ao intérprete humano quem o sistema é, como suas invariantes criptográficas e contábeis operam e quais ações são seguras em cada estado contratual.
</p>

<p>
  Neste capítulo, formaliza-se a trajetória completa de concepção, refinamento geométrico e materialização em código do subsistema de interface do <strong>Desperrengue (<code>v2.11.0</code>)</strong>. Documenta-se rigorosamente a evolução em três níveis de fidelidade — <strong>Nível 1 (Esboços Conceituais <em>Low-Fi Sketches</em>)</strong>, <strong>Nível 2 (<em>Wireframes</em> Estruturais <em>Mid-Fi</em> e Topologia Completa de Telas)</strong> e <strong>Nível 3 (Mockups de Alta Fidelidade <em>Hi-Fi</em> e Engenharia do Design System <em>Quiet Luxury Dark Mode</em>)</strong> —, culminando na <strong>Auditoria Científica Exaustiva pelas 10 Heurísticas de Usabilidade de Jakob Nielsen (H1 a H10)</strong>, integralmente rastreada aos arquivos reais em <code>app/lib/</code> e às suítes de verificação automatizada em <code>app/test/</code>.
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 5.1 — PROTOTIPAÇÃO NÍVEL 1: ESBOÇOS CONCEITUAIS (LOW-FI SKETCHES) -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-5-1">
  <span class="sh-tag">SEÇÃO 5.1 &bull; PROTOTIPAÇÃO EVOLUTIVA NÍVEL 1 &bull; BUXTON, LEI DE FITTS, LEI DE HICK-HYMAN E ZONA DO POLEGAR</span>
  <h2>5.1. Prototipação Nível 1 — Esboços Conceituais (<em>Low-Fi Sketches</em>)</h2>
  <p>Fundamentação matemática da ergonomia motora e cognitiva em dispositivos móveis, mapeamento biomecânico da zona de alcance do polegar e decisões arquiteturais precoces de descarte de complexidade (<em>Design by Subtraction</em>).</p>
</div>

<h3 id="sec-5-1-1">5.1.1. Epistemologia do Esboço Conceitual e Modelagem Matemática da Interação Motora e Cognitiva</h3>
<p>
  Conforme demonstrado por Bill Buxton em <em>Sketching User Experiences</em> (2007), a prototipação de baixa fidelidade (<em>Low-Fidelity Sketching</em>) cumpre função epistemológica distinta da prototipação avaliativa tardia: enquanto artefatos de alta fidelidade testam detalhes de acabamento, o esboço em traço rápido explora o espaço combinatório de conceitos a custo marginal próximo de zero, permitindo invalidar topologias de navegação defeituosas antes do comprometimento de linhas de código. No projeto do Desperrengue, a fase <em>Low-Fi</em> foi regida simultaneamente pelas evidências empíricas da pesquisa bilateral (<span class="math-inline">N = 46</span>) e por três modelos formais clássicos da Ciência da Computação e da Psicofísica Aplicada:
</p>

<ol>
  <li>
    <strong>Lei de Fitts na Formulação da Teoria da Informação de Shannon-MacKenzie (1954 / 1992):</strong> O tempo biomecânico médio de movimento <span class="math-inline">MT</span> necessário para que o dedo do usuário atinja um alvo interativo de largura efetiva <span class="math-inline">W</span> situado a uma distância euclidiana <span class="math-inline">D</span> do ponto de repouso do polegar cresce logaritmicamente com o <em>Índice de Dificuldade</em> (<span class="math-inline">ID</span>, medido em bits):
    <div class="math-formula-box">
      <div class="math-display">
        MT = a + b &middot; ID = a + b &middot; log<sub>2</sub>(D / W + 1) &nbsp;&nbsp;&nbsp;[bits]
      </div>
    </div>
    onde <span class="math-inline">a</span> e <span class="math-inline">b</span> são constantes empíricas do dispositivo de entrada táctil. Em situações de urgência residencial — como o rompimento súbito de uma tubulação hidráulica ou curto-circuito no quadro elétrico (modo <code>SOS</code>) —, o usuário encontra-se sob estresse agudo, com tremor motor periférico e atenção dividida. Para minimizar <span class="math-inline">MT</span>, os esboços <em>Low-Fi</em> determinaram que o gatilho primário de relato por voz e emergência deve simultaneamente <strong>maximizar a dimensão de captura <span class="math-inline">W &ge; 56 dp</span></strong> (superando o mínimo normativo de <span class="math-inline">48 dp</span> do Material Design 3 e de <span class="math-inline">44 pt</span> da Apple HIG) e <strong>minimizar a distância <span class="math-inline">D &rarr; 0</span></strong> mediante posicionamento direto na zona natural de repouso do polegar.
  </li>
  <li>
    <strong>Lei de Hick-Hyman e Redução da Entropia Informacional Decisória (1952 / 1953):</strong> O tempo de reação cognitiva <span class="math-inline">RT</span> exigido para que um ser humano selecione uma alternativa dentre <span class="math-inline">n</span> estímulos de probabilidades <span class="math-inline">p<sub>i</sub></span> é linearmente proporcional à entropia de Shannon <span class="math-inline">H(X)</span> do conjunto de escolhas visíveis na tela:
    <div class="math-formula-box">
      <div class="math-display">
        RT = a<sub>H</sub> + b<sub>H</sub> &middot; H(X) = a<sub>H</sub> + b<sub>H</sub> &middot; &Sigma;<sub>i=1..n</sub> p<sub>i</sub> log<sub>2</sub>(1 / p<sub>i</sub> + 1) &nbsp;&nbsp;&rArr;&nbsp;&nbsp; (equiprovável) &nbsp; RT = a<sub>H</sub> + b<sub>H</sub> &middot; log<sub>2</sub>(n + 1)
      </div>
    </div>
    Caso o morador fosse obrigado, no primeiro segundo de um sinistro doméstico, a inspecionar manualmente uma lista plana não estruturada das <strong>33 categorias técnicas</strong> (<span class="math-inline">ID<sub>Hick</sub> = log<sub>2</sub>(34) &approx; 5,09 bits</span>), o tempo decisório explodiria e induziria erros de classificação (ex.: confundir reparo de aquecedor a gás com encanador geral). A solução arquitetada já no <em>Low-Fi</em> substituiu a busca exaustiva pela <strong>abertura assistida por voz em linguagem natural</strong> acoplada ao classificador determinístico local (<code>SmartTriageService</code> em <code>app/lib/core/services/smart_triage_service.dart</code>), colapsando a decisão inicial para uma escolha binária de baixíssima entropia (<span class="math-inline">n = 2</span>: confirmar a categoria sugerida ou ajustar, reduzindo <span class="math-inline">H(X)</span> para <span class="math-inline">&approx; 1,58 bits</span> e garantindo tempo integral de abertura <span class="math-inline">t &le; 50,4 s &lt; 60,0 s</span>).
  </li>
  <li>
    <strong>Biomecânica da Zona de Alcance do Polegar de Steven Hoober (2013 / 2017):</strong> Estudos observacionais em larga escala conduzidos por Hoober demonstraram que <strong><code>49%</code> dos usuários operam smartphones com apenas uma mão</strong>, apoiando a base do aparelho nos quatro dedos e utilizando exclusivamente a varredura radial do polegar, enquanto outros <code>36%</code> seguram o dispositivo com uma mão em berço e tocam com a outra. Esse padrão divide a tela vertical em três regiões ergonômicas: <strong>(a) Zona Natural / Fácil</strong> (arco inferior central, de alcance imediato sem reposicionamento da pegada); <strong>(b) Zona de Estiramento</strong> (faixa intermediária e cantos inferiores extremos); e <strong>(c) Zona Difícil / Fora de Alcance</strong> (terço superior da tela, que exige mudança de empunhadura ou uso forçado das duas mãos). Nos esboços de Nível 1 do Desperrengue, baniu-se o antipadrão de menus tipo "hambúrguer" ocultos no canto superior esquerdo (<span class="math-inline">D</span> máximo na zona difícil), alocando <code>100%</code> das ações transacionais frequentes — navegação entre abas, botão de abertura por voz/SOS, envio gratuito de orçamento e confirmação de PIN de custódia — no arco inferior da Zona Natural do Polegar.
  </li>
</ol>

${svgLowFiSketches}

<h3 id="sec-5-1-2">5.1.2. Decisões Iniciais de Descarte de Complexidade (<em>Design by Subtraction</em>) na Fase Low-Fi</h3>
<p>
  A principal contribuição científica da prototipação de Nível 1 consistiu na eliminação deliberada de fluxos que, embora comuns em aplicativos legados de serviços, foram apontados pela pesquisa empírica (<span class="math-inline">N = 46</span>) como geradores de abandono, desconfiança ou rejeição econômica. A Tabela 5.1 documenta as seis decisões estruturais de descarte e substituição tomadas nos esboços conceituais e consolidadas no código-fonte.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="18%">Fluxo / Conceito Explorado</th>
      <th width="26%">Antipadrão Descartado no Nível 1 (Low-Fi)</th>
      <th width="24%">Fundamentação Empírica e Ergonômica</th>
      <th width="32%">Solução Arquitetural Adotada no Desperrengue (v2.11.0)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Modelo de Monetização de Oferta</strong></td>
      <td>Loja virtual de pacotes de moedas/créditos pré-pagos para desbloquear telefone do cliente.</td>
      <td>Rejeitado por <strong><code>100,0%</code> (18/18)</strong> dos prestadores; gera perda financeira com <em>clientes fantasmas</em> (<code>55,6%</code>).</td>
      <td><strong>Orçamento 100% Gratuito (Zero Moedas):</strong> submissão livre em <code>provider_job_screen.dart</code>; comissão incide apenas sobre o serviço efetivamente liquidado.</td>
    </tr>
    <tr>
      <td><strong>2. Estrutura do Orçamento</strong></td>
      <td>Campo monetário único agregando mão de obra e peças sob a mesma taxa percentual.</td>
      <td>Causa opacidade ao morador (<code>46,4%</code>) e confisco fiscal sobre insumos comprados pelo técnico (<code>16,7%</code>).</td>
      <td><strong>Particionamento <em>Smart Split</em> Bipartido:</strong> campos separados <code>labor_cents</code> (15% total) e <code>materials_cents</code> (<strong><code>0,0%</code> de taxa</strong> mediante NF-e em <code>material_receipt_capture_screen.dart</code>).</td>
    </tr>
    <tr>
      <td><strong>3. Exibição Cartográfica Pré-Serviço</strong></td>
      <td>Marcador pontual (pino GPS exato) e exibição imediata de rua, número e apartamento no radar aberto.</td>
      <td>Viola a segurança domiciliar (<code>60,7%</code> temem estranhos) e permite reconhecimento prévio indevido do imóvel.</td>
      <td><strong><em>Temporal &amp; Spatial Geo-Privacy Lock</em>:</strong> exibição exclusiva de círculo <code>HMAC-SHA256</code> de <code>500m–800m</code> até as <code>00:00:00</code> do dia agendado (<code>geo_privacy_widgets.dart</code>).</td>
    </tr>
    <tr>
      <td><strong>4. Abertura de Chamado e Triagem</strong></td>
      <td>Formulário burocrático multipágina exigindo preenchimento manual de especificações técnicas complexas.</td>
      <td>Eleva a entropia de Hick-Hyman (<span class="math-inline">5,09 bits</span>) e inviabiliza acionamento rápido sob estresse em emergências <code>SOS</code>.</td>
      <td><strong>Wizard Assistido por Voz (<span class="math-inline">&lt; 60 s</span>):</strong> ditado em <code>voice_dictation.dart</code> + pontuação em <code>smart_transcript_formatter.dart</code> + sugestão em <code>smart_triage_service.dart</code>.</td>
    </tr>
    <tr>
      <td><strong>5. Arquitetura de Contas Cliente/Pro</strong></td>
      <td>Dois aplicativos distintos nas lojas ou exigência de dois cadastros com e-mails/CPFs duplicados.</td>
      <td>Multiplica o atrito de <em>onboarding</em> e força cidadãos que contratam e prestam serviços a repetir o KYC biométrico.</td>
      <td><strong>Conta Unificada <em>Dual-Mode</em> com Herança KYC:</strong> alternância em <span class="math-inline">O(1)</span> no perfil reutilizando <code>kyc_status = 'verified'</code> e mudando o acento cromático (<code>#FF8F52 &harr; #74A7FF</code>).</td>
    </tr>
    <tr>
      <td><strong>6. Liquidação e Segurança Presencial</strong></td>
      <td>Botão simples "Concluir Serviço" acionável unilateralmente pelo prestador ou pagamento direto fora do app.</td>
      <td>Gera Risco Moral pós-pagamento (<code>53,6%</code>), calote (<code>22,2%</code>) e vulnerabilidade a coação presencial no domicílio.</td>
      <td><strong>Checkout por PIN Criptográfico de 4 Dígitos + <em>Silent Duress PIN</em>:</strong> liberação atômica via hash em <code>private.job_forensic_secrets</code> e congelamento silencioso se digitado invertido.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 5.2 — PROTOTIPAÇÃO NÍVEL 2: WIREFRAMES ESTRUTURAIS (MID-FI)       -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-5-2">
  <span class="sh-tag">SEÇÃO 5.2 &bull; PROTOTIPAÇÃO EVOLUTIVA NÍVEL 2 &bull; ARQUITETURA DA INFORMAÇÃO, GRID 480PX E TOPOLOGIA DE TELAS</span>
  <h2>5.2. Prototipação Nível 2 — <em>Wireframes</em> Estruturais (<em>Mid-Fi</em>)</h2>
  <p>Engenharia de layout responsivo centralizado (<code>max-width: 480px</code>), anatomia do cabeçalho estrutural de 2 andares em <code>Detalhe do serviço</code>, viewport cartográfico com 80% de área livre, carrosséis elásticos e catálogo completo de telas de produção.</p>
</div>

<h3 id="sec-5-2-1">5.2.1. Arquitetura da Informação e Container Central Responsivo (<span class="mono">max-width: 480px</span>)</h3>
<p>
  Superada a validação conceitual de Nível 1, a prototipação de <strong>Nível 2 (<em>Mid-Fi Wireframes</em>)</strong> concentrou-se na geometria de distribuição espacial, na hierarquia tipográfica estrutural e na eliminação matemática de anomalias de layout (como <em>RenderFlex overflow</em>, truncamento de vocábulos extensos por reticências prematuras e obstrução de mapas por cartões sobrepostos). Para garantir paridade absoluta entre a distribuição <strong>Android Nativa (APK)</strong> e a variante <strong>Web Progressiva (PWA Desktop e Mobile)</strong> a partir de uma base única de código Flutter, instituiu-se no nó raiz da aplicação (<code>app/lib/main.dart</code> e <code>app/lib/core/ui/app_scaffold.dart</code>) o confinamento geométrico centralizado:
</p>

<div class="math-formula-box">
  <div class="math-display">
    W<sub>container</sub>(W<sub>viewport</sub>) = min(W<sub>viewport</sub>, 480,0 px) &nbsp;&nbsp;com&nbsp;&nbsp; Margin<sub>horizontal</sub> = max(0, (W<sub>viewport</sub> &minus; 480,0) / 2)
  </div>
</div>

<p>
  Essa restrição estrutural — materializada por <code>Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), ...))</code> — resolve três problemas clássicos de interfaces multiplataforma: <strong>(i) Estabilidade do Comprimento de Linha Tipográfica:</strong> impede que blocos de texto e cláusulas de orçamento se estendam por <code>1.920 px</code> em monitores <em>widescreen</em>, preservando a faixa ergonômica ideal de leitura de <code>45 a 75 caracteres por linha</code>; <strong>(ii) Preservação da Lei de Fitts no Desktop/Web:</strong> mantém botões de ação primária, seletores de categoria e caixas de PIN agrupados no eixo óptico central do usuário, evitando deslocamentos extremos de cursor; e <strong>(iii) Testabilidade Determinística de Viewport:</strong> assegura que toda tela homologada na faixa de <code>320 px</code> (smartphones compactos ou modo de acessibilidade ampliado) a <code>480 px</code> mantenha proporções idênticas em qualquer sistema operacional.
</p>

${svgMidFiWireframes}

<h3 id="sec-5-2-2">5.2.2. Anatomia do Cabeçalho Estrutural de 2 Andares na Tela <span class="mono">Detalhe do serviço</span></h3>
<p>
  Durante os testes de estresse tipográfico em <em>wireframes</em> de Nível 2, identificou-se uma falha estrutural recorrente em aplicativos de marketplace quando executados em telas estreitas (<code>320 px</code> de largura lógica) combinadas ao fator de ampliação de fonte de acessibilidade do sistema operacional (<code>MediaQuery.textScalerOf(context)</code> até <code>1.4x</code>): quando o emblema da categoria, o título do chamado e o selo de status (<code>StatusChip</code>) compartilham uma mesma linha horizontal (<code>Row</code> simples), vocábulos técnicos extensos da língua portuguesa — tais como <em>"Impermeabilização"</em> (17 caracteres), <em>"Ar-Condicionado"</em> ou <em>"Desentupimento"</em> — colidem com o chip de status (ex.: <code>"AGUARDANDO ORÇAMENTO"</code>), provocando truncamento severo do título a menos de 8 caracteres visíveis ou erro de estouro de layout (<em>overflow</em>).
</p>

<p>
  Para erradicar definitivamente esse defeito, a tela <code>DetalheServicoClienteScreen</code> (<code>app/lib/features/client/presentation/detalhe_servico_cliente_screen.dart</code>, em conjunto com o formatador semântico <code>SmartOrderHeadlineFormatter</code> em <code>app/lib/core/utils/order_utils.dart</code>) foi projetada sobre uma <strong>arquitetura de cabeçalho estrutural de 2 andares desacoplados</strong>:
</p>

<ul>
  <li>
    <strong>1º Andar — Faixa Superior de Metadados e Estado (<code>Wrap</code> / <code>Row</code> Flexível):</strong> Dedicada exclusivamente à identificação taxonômica e ao estado transacional da ordem. À esquerda, posiciona-se a pílula da categoria contendo o emblema vetorial <code>CategoryBrandEmblem</code> (tamanho compacto <code>22 px</code>) e o rótulo da especialidade; à direita, posiciona-se o <code>StatusChip</code> semântico (ex.: <code>ABERTO</code>, <code>CONTRATADO</code>, <code>EM EXECUÇÃO</code>, <code>CONCLUÍDO</code>) acompanhado, quando aplicável, da insígnia pulsante <code>SOS</code>. Por utilizar empacotamento elástico, caso a escala de fonte atinja <code>1.4x</code> em tela de <code>320 px</code>, os chips acomodam-se sem jamais comprimir o título principal.
  </li>
  <li>
    <strong>2º Andar — Faixa Inferior de Título Principal em Largura Integral (<code>100% Width Headline</code>):</strong> Separado por espaçamento vertical de <code>10 dp</code>, o segundo andar reserva <code>100%</code> da largura útil do cartão para o enunciado descritivo da ordem (sintetizado por <code>SmartOrderHeadlineFormatter.formatHeadline()</code>, que remove prefixos redundantes de categoria e capitaliza a sentença técnica). Isso permite que títulos completos como <em>"Substituição de Disjuntor Geral DR e Balanceamento de Fases no QDC"</em> disponham de até duas linhas inteiras com tipografia <code>headline</code> de alto peso (<code>fontWeight: FontWeight.w800</code>), atingindo <strong>zero truncamento em 100% dos cenários de teste</strong> (validado na suíte <code>app/test/ux_client_and_shared_polish_test.dart</code>).
  </li>
</ul>

<h3 id="sec-5-2-3">5.2.3. Engenharia do Viewport Cartográfico com <span class="mono">&ge; 80%</span> de Área Livre e Carrosséis Elásticos de Conquistas</h3>
<p>
  Dois outros marcos arquiteturais consolidados na prototipação <em>Mid-Fi</em> governam a percepção espacial e a escalabilidade de componentes:
</p>

<ol>
  <li>
    <strong>Viewport de Mapa Ao Vivo com <span class="math-inline">&ge; 80%</span> de Área Útil Desobstruída (<code>OrderLiveMapModalScreen</code>):</strong> Em interfaces convencionais de rastreamento, barras superiores espessas, cartões intermediários flutuantes e painéis inferiores fixos costumam consumir mais de <code>55%</code> da altura vertical da tela, reduzindo o mapa a uma fresta ilegível. No Desperrengue (<code>app/lib/features/shared/presentation/order_live_map_modal_screen.dart</code> e <code>app/lib/features/shared/presentation/service_map_widgets.dart</code>), o canvas cartográfico ocupa <code>100%</code> do <code>Stack</code> de fundo, enquanto os elementos sobrepostos são estritamente limitados a uma pílula translúcida compacta no topo (<code>&le; 6%</code> da altura) e a um <em>bottom sheet</em> colapsável na base (<code>&le; 12% a 18%</code> da altura quando recolhido), preservando <strong>mais de <code>80%</code> (exatos <code>81,2%</code> a <code>84,0%</code>) da área útil da viewport totalmente livre para a leitura cartográfica</strong>. Adicionalmente, o traçado de rota implementa <strong>cascata dupla de servidores OSRM</strong> (<code>accurate_geo_routing_service.dart</code> e <code>real_time_route_and_traffic_service.dart</code>) com comutação instantânea (<span class="math-inline">0 ms</span>) para uma <strong>curva geodésica suave <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos</strong> (arco de Bézier quadrático com flecha ortogonal calibrada) caso haja instabilidade de rede externa.
  </li>
  <li>
    <strong>Carrosséis Horizontais de Conquistas com Borda Gradiente e Altura Elástica (<code>_EdgeFadeMedalCarousel</code>):</strong> Para apresentar as <strong>112 medalhas</strong> do ecossistema sem gerar páginas verticais intermináveis, o módulo <code>app/lib/features/shared/presentation/achievement_widgets.dart</code> organiza as insígnias em carrosséis horizontais por trilha temática. A fim de evitar cortes verticais quando o usuário ativa fontes grandes de acessibilidade, a altura <span class="math-inline">H<sub>carrossel</sub></span> do container não é estática, mas governada pela função linear contínua do fator de escala tipográfica <span class="math-inline">s = textScaler.scale(1.0)</span>:
    <div class="math-formula-box">
      <div class="math-display">
        H<sub>carrossel</sub>(s) = 152,0 + max(0,0 , s &minus; 1,0) &times; 56,0 &nbsp;&nbsp;[dp]
      </div>
    </div>
    Nas extremidades laterais da pista rolável, aplica-se um <code>ShaderMask</code> com gradiente de opacidade (<code>BlendMode.dstIn</code>) que dissolve suavemente os últimos <code>18 px</code> do cartão adjacente, fornecendo <em>affordance</em> perceptual imediata de continuidade horizontal sem poluir a tela com setas mecânicas.
  </li>
</ol>

<h3 id="sec-5-2-4">5.2.4. Catálogo Completo de Telas e Topologia de Navegação de Produção (<span class="mono">app/lib/features/</span>)</h3>
<p>
  A árvore de navegação de produção do aplicativo unificado (<code>app/lib/main.dart</code> e <code>app/lib/features/</code>) é orquestrada por uma sequência determinística de portões de ciclo de vida — <code>BootGate</code> (inicialização assíncrona em <code>app_initialization_service.dart</code>) &rarr; <code>UpdateGate</code> (verificação OTA segura em <code>app_version_and_update_service.dart</code>) &rarr; <code>AuthGate</code> (<code>auth_gate.dart</code>) &rarr; <code>PostAuthRouter</code> (<code>post_auth_router.dart</code>) — que direciona o titular autenticado para o shell correspondente ao seu papel ativo (<code>ClientShell</code> ou <code>ProviderShell</code>). A Tabela 5.2 documenta o catálogo completo dos módulos de tela implementados em produção na versão <code>v2.11.0</code>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Domínio de Navegação</th>
      <th width="29%">Arquivos Reais em <code>app/lib/features/</code></th>
      <th width="33%">Responsabilidade Funcional e Estrutural na Jornada</th>
      <th width="22%">Suíte de Teste Associada</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Boot, Auth, OTP e KYC Biométrico</strong></td>
      <td><code>auth_gate.dart</code>, <code>login_screen.dart</code>, <code>cadastro_dados_basicos.dart</code>, <code>cadastro_verificacao_otp.dart</code>, <code>role_selection_screen.dart</code>, <code>verificacao_step1_frente.dart</code>..<code>step5_finalizacao.dart</code>, <code>post_auth_router.dart</code></td>
      <td>Autenticação PKCE, confirmação OTP, escolha inicial de modo (com herança automática em contas existentes) e assistente KYC em 5 passos com portão óptico Tier-0 em <code>Isolate.run</code> e tradutor sem jargão.</td>
      <td><code>account_screens_test.dart</code>,<br/><code>argon_carbon_kyc_and_ux_test.dart</code></td>
    </tr>
    <tr>
      <td><strong>2. Shell e Jornada do Morador (Modo Cliente)</strong></td>
      <td><code>client_shell.dart</code>, <code>home_screens.dart</code>, <code>request_wizard.dart</code>, <code>voice_dictation.dart</code>, <code>published_overlay.dart</code>, <code>client_orders_tab.dart</code>, <code>detalhe_servico_cliente_screen.dart</code>, <code>order_tracking_screen.dart</code></td>
      <td>Navegação com acento <code>#FF8F52</code>, abertura de chamado por voz (<span class="math-inline">&lt; 60s</span>) nas 33 categorias, cabeçalho de 2 andares, comparação de propostas e acompanhamento em tempo real.</td>
      <td><code>client_flow_widgets_test.dart</code>,<br/><code>ux_client_and_shared_polish_test.dart</code></td>
    </tr>
    <tr>
      <td><strong>3. Pagamento PIX, Checkout PIN e Passaporte</strong></td>
      <td><code>payment_widgets.dart</code>, <code>wallet_chip.dart</code>, <code>insufficient_funds_sheet.dart</code>, <code>completion_screens.dart</code>, <code>historico_servicos_cliente_screen.dart</code>, <code>provider_public_profile_screen.dart</code>, <code>provider_search_screen.dart</code></td>
      <td>Depósito em <em>Smart Escrow</em> PIX (<code>BIGINT</code>), recarga rápida de diferença exata, liberação por PIN de 4 dígitos (com suporte a <em>Silent Duress PIN</em>) e exportação do Passaporte ABNT NBR 5674.</td>
      <td><code>completion_redesign_test.dart</code>,<br/><code>client_history_test.dart</code>,<br/><code>wallet_test.dart</code></td>
    </tr>
    <tr>
      <td><strong>4. Shell, Radar e Execução do Prestador (Modo Pro)</strong></td>
      <td><code>provider_shell.dart</code>, <code>provider_setup_screens.dart</code>, <code>provider_job_screen.dart</code>, <code>provider_execution_screens.dart</code>, <code>material_receipt_capture_screen.dart</code>, <code>dossie_servico_profissional_screen.dart</code></td>
      <td>Navegação com acento <code>#74A7FF</code>, radar <span class="math-inline">O(log N + K)</span> sem compra de moedas, check-in HMAC no dia agendado, captura de NF-e de 44 dígitos (<code>0%</code> taxa em peças) e dossiê técnico.</td>
      <td><code>provider_ux_polish_test.dart</code>,<br/><code>material_receipt_capture_screen_test.dart</code>,<br/><code>provider_real_receipts_services_test.dart</code></td>
    </tr>
    <tr>
      <td><strong>5. Carteira Profissional, Saque PIX e Portfólio</strong></td>
      <td><code>wallet_tab.dart</code>, <code>pix_withdraw_screen.dart</code>, <code>provider_profile_screens.dart</code>, <code>provider_portfolio_widgets.dart</code></td>
      <td>Demonstração de saldos (custódia, maturação <code>D+0/D+2/D+5..7</code> e líquido disponível), saque PIX para chave vinculada ao CPF/CNPJ homologado e vitrine LIFO antes/depois.</td>
      <td><code>eng_portfolio_sync_test.dart</code>,<br/><code>fintech_warranty_security_test.dart</code></td>
    </tr>
    <tr>
      <td><strong>6. Módulos Compartilhados: Geo-Lock, Mapa 80%, 112 Medalhas e LGPD</strong></td>
      <td><code>order_live_map_modal_screen.dart</code>, <code>geo_privacy_widgets.dart</code>, <code>service_map_widgets.dart</code>, <code>achievement_widgets.dart</code>, <code>fintech_warranty_widgets.dart</code>, <code>chat_screen.dart</code>, <code>delete_account_screen.dart</code>, <code>support_screens.dart</code></td>
      <td>Mapa com <span class="math-inline">&ge; 80%</span> de área livre (OSRM + arco <span class="math-inline">C<sup>&infin;</sup></span>), cartões de área protegida (<code>500m–800m</code> até <code>00:00</code> SP), galeria das 112 medalhas (<code>#CBD5E1</code>), garantia em 3 camadas e exclusão escopada com Dossiê PDF.</td>
      <td><code>orders_map_ux_and_instant_media_test.dart</code>,<br/><code>temporal_geo_privacy_lock_widgets_test.dart</code>,<br/><code>dossier_test.dart</code></td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- SEÇÃO 5.3 — PROTOTIPAÇÃO NÍVEL 3: HI-FI E ENGENHARIA DO DESIGN SYSTEM   -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-5-3">
  <span class="sh-tag">SEÇÃO 5.3 &bull; PROTOTIPAÇÃO EVOLUTIVA NÍVEL 3 &bull; QUIET LUXURY DARK MODE, WCAG 2.1 AAA, 33 ÍCONES DUOTONE E 112 MEDALHAS</span>
  <h2>5.3. Prototipação Nível 3 — Telas de Alta Fidelidade (<em>Hi-Fi</em>) e Engenharia do Design System (<em>Quiet Luxury Dark Mode</em>)</h2>
  <p>Especificação formal dos tokens cromáticos e tipográficos, provas fotométricas de contraste WCAG AA/AAA, sistema iconográfico vetorial <em>Duotone</em> das 33 categorias, forja cromática das 112 medalhas (<code>#CBD5E1</code> vs. ligas vibrantes) e telas Hi-Fi de Radar e Smart Escrow.</p>
</div>

<h3 id="sec-5-3-1">5.3.1. Filosofia Estética <em>Quiet Luxury Dark Mode</em> e Fotometria de Contraste WCAG 2.1 AA/AAA</h3>
<p>
  Na transição para a prototipação de <strong>Nível 3 (Alta Fidelidade — <em>Hi-Fi</em>)</strong>, codificada integralmente em <code>app/lib/core/ui/app_tokens.dart</code> e <code>app/lib/core/ui/app_theme.dart</code> (documentada no <code>ADR-0014</code>), instituiu-se a linguagem visual <strong><em>Quiet Luxury Dark Mode</em></strong> (com suporte dual completo ao tema claro de alto contraste). Em vez de utilizar preto puro amoled (<code>#000000</code>) — que provoca <em>haloing</em> astigmatismo-induzido e arrasto de pixels (<em>black smearing</em>) em painéis OLED durante rolagens a <code>120 Hz</code> —, a arquitetura cromática adota uma escala progressiva de <strong>ardósia meia-noite profunda (<em>Deep Obsidian Slate</em>)</strong> que codifica a elevação espacial no eixo <span class="math-inline">Z</span> por luminância sutil: plano de fundo primário em <code>#0E1218</code>, superfícies secundárias em <code>#141A22</code>, cartões estruturais em <code>#1A212B</code> e modais elevados em <code>#232C39</code>, delimitados por bordas de precisão de <code>1,0 px</code> em <code>#2B3646</code>.
</p>

<p>
  Para comprovar matematicamente a legibilidade sob as diretrizes internacionais <strong>W3C WCAG 2.1 (<em>Web Content Accessibility Guidelines</em>)</strong>, cada componente sRGB normalizado <span class="math-inline">C<sub>sRGB</sub> &isin; [0, 1]</span> (onde <span class="math-inline">C<sub>sRGB</sub> = C<sub>8bit</sub> / 255</span>) é submetido à função de transferência eletro-óptica inversa para obtenção da luminância relativa linear <span class="math-inline">L</span> e da razão de contraste fotométrico <span class="math-inline">CR(L<sub>1</sub>, L<sub>2</sub>)</span>:
</p>

<div class="math-formula-box">
  <div class="math-display">
    c<sub>lin</sub> = (C<sub>sRGB</sub> / 12,92) se C<sub>sRGB</sub> &le; 0,04045 &nbsp;;&nbsp; ((C<sub>sRGB</sub> + 0,055) / 1,055)<sup>2,4</sup> caso contrário<br/>
    L = 0,2126 R<sub>lin</sub> + 0,7152 G<sub>lin</sub> + 0,0722 B<sub>lin</sub> &nbsp;&nbsp;&rArr;&nbsp;&nbsp; CR(L<sub>fg</sub>, L<sub>bg</sub>) = (max(L<sub>fg</sub>, L<sub>bg</sub>) + 0,05) / (min(L<sub>fg</sub>, L<sub>bg</sub>) + 0,05)
  </div>
</div>

<p>
  Adicionalmente, a classe <code>AppTokens</code> implementa três operadores algébricos puros sobre o espaço de cor perceptual <strong>HSL</strong> para síntese dinâmica de superfícies sem perda de contraste: <code>tonal(Color c, double amount)</code> (interpolação controlada com a superfície base), <code>desaturate(Color c, {double maxSaturation = 0.55})</code> (prevenção de vibração cromática excessiva em modo escuro) e <code>contrast(Color bg)</code> (seleção automática de tinta com base no limiar fotométrico de luminância). A Tabela 5.3 apresenta o catálogo completo e auditado dos tokens semânticos de cor do Desperrengue (<code>v2.11.0</code>).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="16%">Token Semântico (<code>AppTokens</code>)</th>
      <th width="13%">Hex Dark Mode (Padrão)</th>
      <th width="13%">Hex Light Mode (Alternativo)</th>
      <th width="16%">Contraste Auditado (Dark s/ <code>#0E1218</code>)</th>
      <th width="12%">Nível WCAG 2.1</th>
      <th width="30%">Papel Funcional e Semiótico na Interface</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>background</code></td>
      <td><strong><code>#0E1218</code></strong></td>
      <td><code>#FFFFFF</code></td>
      <td><span class="math-inline">L = 0,0080</span> (Base Z=0)</td>
      <td>Referência</td>
      <td>Canvas profundo anti-<em>smearing</em> para rolagem a <code>120 Hz</code>.</td>
    </tr>
    <tr>
      <td><code>surface</code></td>
      <td><strong><code>#141A22</code></strong></td>
      <td><code>#F4F6FA</code></td>
      <td><span class="math-inline">L = 0,0116</span> (Elevação Z=1)</td>
      <td>Estrutural</td>
      <td>Barras de navegação, <em>headers</em> e áreas de agrupamento.</td>
    </tr>
    <tr>
      <td><code>card</code></td>
      <td><strong><code>#1A212B</code></strong></td>
      <td><code>#FFFFFF</code></td>
      <td><span class="math-inline">L = 0,0162</span> (Elevação Z=2)</td>
      <td>Estrutural</td>
      <td>Contêineres de ordens de serviço, orçamentos e carteira.</td>
    </tr>
    <tr>
      <td><code>raised</code></td>
      <td><strong><code>#232C39</code></strong></td>
      <td><code>#EEF2F7</code></td>
      <td><span class="math-inline">L = 0,0248</span> (Elevação Z=3)</td>
      <td>Estrutural</td>
      <td>Modais, <em>bottom sheets</em>, pílulas interativas e diálogos de PIN.</td>
    </tr>
    <tr>
      <td><code>border</code></td>
      <td><strong><code>#2B3646</code></strong></td>
      <td><code>#E5E7EB</code></td>
      <td>Delimitação sutil <code>1,0 px</code></td>
      <td>AA UI</td>
      <td>Separação geométrica nítida sem poluição de sombras pesadas.</td>
    </tr>
    <tr>
      <td><code>text</code></td>
      <td><strong><code>#EAEFF6</code></strong></td>
      <td><code>#111827</code></td>
      <td><strong><code>15,6 : 1</code></strong> (s/ card: <code>13,9:1</code>)</td>
      <td><strong>AAA Máximo</strong></td>
      <td>Tipografia primária de títulos, valores em Reais e cláusulas.</td>
    </tr>
    <tr>
      <td><code>textMuted</code></td>
      <td><strong><code>#A3AEC0</code></strong></td>
      <td><code>#5E6673</code></td>
      <td><strong><code>7,8 : 1</code></strong> (Light: <code>5,7:1</code>)</td>
      <td><strong>AAA / AA+</strong></td>
      <td>Rótulos secundários, carimbos de tempo e legendas técnicas.</td>
    </tr>
    <tr>
      <td><code>clientAccent</code></td>
      <td><strong><code>#FF8F52</code></strong></td>
      <td><code>#F26B0F</code></td>
      <td><strong><code>8,3 : 1</code></strong></td>
      <td><strong>AAA</strong></td>
      <td>Identidade semiótica exclusiva do <strong>Modo Cliente (Morador)</strong>.</td>
    </tr>
    <tr>
      <td><code>providerAccent</code></td>
      <td><strong><code>#74A7FF</code></strong></td>
      <td><code>#1B3A78</code></td>
      <td><strong><code>8,1 : 1</code></strong></td>
      <td><strong>AAA</strong></td>
      <td>Identidade semiótica exclusiva do <strong>Modo Profissional (Técnico)</strong>.</td>
    </tr>
    <tr>
      <td><code>brand</code></td>
      <td><strong><code>#6FA8F0</code></strong></td>
      <td><code>#003366</code></td>
      <td><strong><code>7,9 : 1</code></strong></td>
      <td><strong>AAA</strong></td>
      <td>Acento institucional neutro, foco de formulário e links.</td>
    </tr>
    <tr>
      <td><code>success</code> / <code>Ink</code></td>
      <td><strong><code>#3CCB8C</code></strong> / <code>#86E3BC</code></td>
      <td><code>#2FB67C</code></td>
      <td><strong><code>9,4 : 1</code></strong> (s/ soft <code>#12322A</code>)</td>
      <td><strong>AAA</strong></td>
      <td>Custódia PIX confirmada, KYC aprovado e isenção <code>0%</code> peças.</td>
    </tr>
    <tr>
      <td><code>warning</code> / <code>Ink</code></td>
      <td><strong><code>#EFCB6B</code></strong> / <code>#F1D089</code></td>
      <td><code>#E5C566</code></td>
      <td><strong><code>11,8 : 1</code></strong> (s/ soft <code>#362D14</code>)</td>
      <td><strong>AAA</strong></td>
      <td>Alertas preventivos, maturação de saldo e relógio Geo-Lock.</td>
    </tr>
    <tr>
      <td><code>danger</code></td>
      <td><strong><code>#FF7A80</code></strong></td>
      <td><code>#C0262D</code></td>
      <td><strong><code>7,4 : 1</code></strong> (s/ soft <code>#38191E</code>)</td>
      <td><strong>AAA</strong></td>
      <td>Chamados de emergência <code>SOS</code>, bloqueios e ações destrutivas.</td>
    </tr>
    <tr>
      <td><code>security</code></td>
      <td><strong><code>#52B7C0</code></strong></td>
      <td><code>#2A7F86</code></td>
      <td><strong><code>8,2 : 1</code></strong></td>
      <td><strong>AAA</strong></td>
      <td>Círculo de <em>Geo-Privacy Lock</em>, selos criptográficos e garantia 90d.</td>
    </tr>
    <tr>
      <td><code>medalLocked</code></td>
      <td><strong><code>#CBD5E1</code></strong></td>
      <td><code>#CBD5E1</code></td>
      <td><strong><code>9,8 : 1</code></strong> (s/ base <code>#1E293B</code>)</td>
      <td><strong>AAA</strong></td>
      <td>Prata clara de alta legibilidade para as medalhas bloqueadas.</td>
    </tr>
  </tbody>
</table>

${svgHiFiScreensAndTokens}

<h3 id="sec-5-3-2">5.3.2. Escala Tipográfica Funcional e Alinhamento Tabular Monetário</h3>
<p>
  A hierarquia tipográfica definida em <code>app/lib/core/ui/app_theme.dart</code> estrutura-se sobre fontes sem serifa de elevada altura de <span class="math-inline">x</span> (<em>x-height</em>) otimizadas para renderização subpixel em telas móveis densas, compreendendo sete níveis formais: <code>display</code> (<code>26 sp</code>, peso <code>800</code>, <code>letterSpacing: -0.6</code>, para saldos principais de carteira e marcos de conclusão), <code>headline</code> (<code>20 sp</code>, peso <code>800</code>, altura de linha <code>1.25</code>, para o 2º andar do cabeçalho de ordens), <code>title</code> (<code>16 sp</code>, peso <code>700</code>, para cabeçalhos de cartões), <code>body</code> (<code>14 sp</code>, peso <code>400/500</code>, altura de linha <code>1.45</code>, para descrições e cláusulas de garantia), <code>label</code> (<code>12,5 sp</code>, peso <code>700</code>, para botões e abas), <code>caption</code> (<code>11,5 sp</code>, peso <code>500</code>, para metadados secundários) e <code>mono</code> (<code>JetBrains Mono / Courier</code> com <code>FontFeature.tabularFigures()</code> obrigatório). O uso de algarismos tabulares de largura fixa garante que listagens financeiras do <em>Smart Split</em> (<code>R$ 220,00</code> de mão de obra vs. <code>R$ 100,00</code> de peças) e cronômetros regressivos (<code>00:00:00</code>) jamais sofram trepidação horizontal (<em>layout jitter</em>) durante atualizações de estado a <code>120 FPS</code>.
</p>

<h3 id="sec-5-3-3">5.3.3. Sistema Iconográfico Vetorial <em>Duotone</em> das 33 Categorias de Serviço</h3>
<p>
  Em conformidade com o requisito não funcional <code>RNF-04</code>, o Desperrengue baniu o uso de pacotes de ícones genéricos e heterogêneos, desenvolvendo um <strong>sistema iconográfico vetorial proprietário em estilo <em>Duotone</em></strong> para representar as <strong>33 categorias residenciais homologadas</strong> (definidas na constante canônica <code>kCategories</code> em <code>app/lib/core/models/marketplace_models.dart</code> e renderizadas por <code>app/lib/core/ui/duotone_service_icons.dart</code> e <code>app/lib/core/ui/category_brand_emblem.dart</code>).
</p>

<p>
  Cada emblema <code>CategoryBrandEmblem</code> (e sua variante de alto contraste <code>DarkGlassDuotoneBadge</code>) é construído por composição geométrica em três planos ópticos sobre um <code>CustomPainter</code> isolado por <code>RepaintBoundary</code>: <strong>(1º Plano de Base — <em>Dark Glass Squircle</em>):</strong> superelipse contínua com fundo escuro translúcido (<code>#1E293B &rarr; #0F172A</code>), brilho especular radial no quadrante superior esquerdo e borda fina colorida segundo a família semântica; <strong>(2º Plano — Glifo Vetorial <em>Duotone</em>):</strong> camada secundária preenchida com opacidade tonal de <code>22% a 28%</code> combinada ao traço primário nítido de <code>100%</code> de opacidade; e <strong>(3º Plano — <em>Corner Sub-Badge</em>):</strong> microinsígnia contextual de especialidade. As 33 categorias distribuem-se em <strong>6 famílias cromáticas</strong> que aceleram a busca visual pré-atentiva:
</p>

<ul>
  <li><strong>Família 1 — Energia, Climatização e Gás (Âmbar / Ouro Elétrico <code>#F59E0B</code>):</strong> <em>Elétrica</em>, <em>Ar-Condicionado</em>, <em>Aquecedor a Gás</em>, <em>Energia Solar</em> e <em>Eletrodomésticos</em>;</li>
  <li><strong>Família 2 — Água, Redes Hidráulicas e Saneamento (Ciano Oceânico <code>#06B6D4</code>):</strong> <em>Hidráulica</em>, <em>Desentupimento</em>, <em>Caça-Vazamento</em>, <em>Limpeza de Caixa d'Água</em>, <em>Piscina</em> e <em>Impermeabilização</em>;</li>
  <li><strong>Família 3 — Estrutura Civil, Acabamento e Marcenaria (Laranja Terracota <code>#F97316</code>):</strong> <em>Alvenaria / Pedreiro</em>, <em>Pintura</em>, <em>Gesso e Drywall</em>, <em>Marcenaria</em>, <em>Montador de Móveis</em>, <em>Serralheria</em>, <em>Vidraçaria</em>, <em>Pisos e Revestimentos</em>, <em>Telhado e Calhas</em> e <em>Marido de Aluguel</em>;</li>
  <li><strong>Família 4 — Conservação Domiciliar, Limpeza e Bem-Estar (Esmeralda <code>#10B981</code>):</strong> <em>Diarista / Limpeza Residencial</em>, <em>Limpeza Pós-Obra</em>, <em>Higienização de Estofados</em>, <em>Passadoria</em>, <em>Jardinagem</em>, <em>Dedetização / Controle de Pragas</em> e <em>Redes de Proteção</em>;</li>
  <li><strong>Família 5 — Tecnologia, Automação e Segurança Eletrônica (Índigo / Violeta <code>#6366F1</code>):</strong> <em>Redes e Wi-Fi / TI</em>, <em>Câmeras e Alarmes (CFTV)</em>, <em>Fechadura Digital</em> e <em>Automação Residencial / Portão Eletrônico</em>;</li>
  <li><strong>Família 6 — Urgência de Acesso e Logística Leve (Rosa / Coral <code>#F43F5E</code>):</strong> <em>Chaveiro 24h / SOS</em> e <em>Pequenos Fretes / Mudanças Internas</em>.</li>
</ul>

<h3 id="sec-5-3-4">5.3.4. Engenharia Visual das 112 Medalhas de Conquistas: Estado Bloqueado (<span class="mono">#CBD5E1</span>) vs. Desbloqueado</h3>
<p>
  O ecossistema de gamificação meritocrática do Desperrengue totaliza exatamente <strong>112 medalhas auditáveis</strong>, compostas por:
</p>
<ul>
  <li>
    <strong>90 Medalhas do Profissional (<code>app/lib/core/models/achievements.dart</code>):</strong> estruturadas ortogonalmente em <strong>9 categorias de excelência técnica &times; 10 níveis progressivos</strong> (patamares canônicos de <code>[1, 10, 25, 50, 100, 500, 1.000, 2.500, 5.000, 10.000]</code> marcos verificados), cobrindo volume de ordens concluídas, avaliações cinco estrelas, prontidão em emergências <code>SOS</code>, pontualidade, fidelização de clientes, integridade fiscal em <em>Smart Split</em> e histórico zero sinistros;
  </li>
  <li>
    <strong>22 Medalhas do Cliente / Morador (<code>app/lib/core/models/client_achievements.dart</code>):</strong> computadas em passagem única linear <span class="math-inline">O(N)</span> sobre o histórico predial do morador e distribuídas em <strong>6 trilhas temáticas</strong> (<em>Primeiros Passos / Guardião do Lar</em> [5 níveis], <em>Mestre do Áudio / Voz</em> [1 nível], <em>Zelo Preventivo Recorrente</em> [4 níveis], <em>Pagador Pontual PIX</em> [4 níveis], <em>Avaliador Justo</em> [3 níveis] e <em>Voz da Vizinhança / Indicação</em> [5 níveis], somando <span class="math-inline">5 + 1 + 4 + 4 + 3 + 5 = 22</span> insígnias).
  </li>
</ul>

<p>
  Um erro clássico de design em interfaces de modo escuro consiste em renderizar medalhas ainda não conquistadas em tons de cinza chumbo escuro (ex.: <code>#334155</code> ou <code>#1E293B</code>) sobre cartões igualmente escuros (<code>#1A212B</code>), resultando em razões de contraste pífias (<span class="math-inline">CR &lt; 1,6 : 1</span>) que tornam a silhueta da conquista invisível e frustram a motivação gamificada (Efeito Zeigarnik). Para solucionar esse problema com rigor óptico, o componente <code>AchievementMedalForge</code> (implementado em <code>app/lib/core/ui/profile_and_achievement_emblems.dart</code> e <code>app/lib/features/shared/presentation/achievement_widgets.dart</code>, validado por <code>app/test/carbon_geo_badges_and_image_cache_test.dart</code>) impõe uma <strong>codificação visual bimodal de alto contraste</strong>:
</p>

<ol>
  <li>
    <strong>Estado Bloqueado em Cinza Claro Prateado (<code>#CBD5E1</code> — <em>Sandblasted Titanium Silver</em>):</strong> Toda medalha ainda pendente de desbloqueio tem seu glifo central e detalhes internos obrigatoriamente desenhados no token <strong><code>#CBD5E1</code></strong> (<span class="math-inline">R=203, G=213, B=225</span>) sobre escudo de base <code>#1E293B</code>, atingindo <strong>contraste fotométrico de <code>9,8 : 1</code> (WCAG 2.1 Nível AAA)</strong>. O aro externo recebe acabamento metálico frio em <code>#94A3B8</code> e uma cápsula inferior discreta exibe o ícone vetorial de cadeado em <code>#E2E8F0</code>. Dessa forma, o usuário identifica instantaneamente qual é o ícone da conquista futura, mas sabe sem qualquer ambiguidade que ela ainda se encontra bloqueada.
  </li>
  <li>
    <strong>Estado Desbloqueado em Ligas Metálicas Vibrantes e Iluminação Especular:</strong> Assim que o requisito é atingido, o cadeado desaparece, a saturação é restaurada a <code>100%</code> e o escudo ascende através de cinco ligas metálicas progressivas — <strong>Bronze (<code>#D97706 &rarr; #92400E</code>)</strong>, <strong>Prata Polida (<code>#F1F5F9 &rarr; #64748B</code>)</strong>, <strong>Ouro Imperial (<code>#FDE047 &rarr; #B45309</code>)</strong>, <strong>Platina (<code>#E0E7FF &rarr; #4338CA</code>)</strong> e <strong>Diamante Ciano (<code>#67E8F9 &rarr; #1D4ED8</code>)</strong> — acompanhadas de halo luminoso periférico e estrelas de nível no topo do brasão.
  </li>
</ol>

<h3 id="sec-5-3-5">5.3.5. Especificação das Telas Hi-Fi de Radar Geoespacial (<span class="mono">500m–800m</span>) e Modal Smart Escrow por PIN de 4 Dígitos</h3>
<p>
  A Figura 5.3 sintetiza os dois fluxos de maior densidade criptográfica e transacional na camada <em>Hi-Fi</em>:
</p>
<ul>
  <li>
    <strong>Interface Cartográfica Protegida por <em>Geo-Privacy Lock</em> (<code>ProtectedAreaMapCard</code> e <code>ProtectedAreaMapSheet</code>):</strong> Nas fases <code>PUBLIC_FUZZY</code> e <code>HIRED_PRE_DAY_LOCKED</code>, o motor <code>GeoPrivacyPolicyEngine</code> (<code>app/lib/core/security/geo_privacy_policy_engine.dart</code>) consome o payload da RPC <code>get_job_location_for_viewer</code> em modo estrito <em>fail-closed</em>. A tela substitui qualquer marcador pontual de residência por um perímetro circular translúcido em ciano de segurança (<code>#52B7C0</code> com preenchimento de <code>14%</code> e borda tracejada de <code>2,0 px</code>) com raio determinístico entre <code>500 m</code> e <code>800 m</code> centrado em <code>_geo_fuzzy_center</code>, acompanhado de pílula de status que informa o desbloqueio automático às <code>00:00:00 America/Sao_Paulo</code> do dia do serviço.
  </li>
  <li>
    <strong>Modal de Liquidação Atômica <em>Smart Escrow</em> por PIN de 4 Dígitos (<code>completion_screens.dart</code>):</strong> No encerramento presencial, o modal apresenta quatro células de foco individual (<code>46 x 52 dp</code>, borda <code>#6FA8F0</code> que transiciona para <code>#3CCB8C</code> ao completar o 4º dígito) acompanhadas do demonstrativo contábil em centavos <code>BIGINT</code> (repasse líquido de <code>85,0%</code> da mão de obra + <code>100,0%</code> das peças fiscais isentas, retenção de <code>13,5%</code> da plataforma e <em>carve-out</em> de <code>1,5%</code> para o <code>warranty_pool_ledger</code>). Caso o código inserido corresponda ao reverso exato do PIN não-palíndromo (<em>Silent Duress PIN</em>), a interface renderiza a mesma transição visual verde de sucesso para proteger a integridade física do morador no local, enquanto a RPC sinaliza <code>FROZEN_UNDER_DURESS</code> no banco de dados.
  </li>
</ul>

<!-- ======================================================================= -->
<!-- SEÇÃO 5.4 — AUDITORIA PELAS 10 HEURÍSTICAS DE JAKOB NIELSEN (H1 A H10)  -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-5-4">
  <span class="sh-tag">SEÇÃO 5.4 &bull; AUDITORIA CIENTÍFICA DE USABILIDADE &bull; AS 10 HEURÍSTICAS DE JAKOB NIELSEN (H1 A H10) NO CÓDIGO REAL</span>
  <h2>5.4. Auditoria Completa pelas 10 Heurísticas de Usabilidade de Jakob Nielsen (H1 a H10)</h2>
  <p>Inspeção analítica ponto a ponto das dez heurísticas canônicas de engenharia de usabilidade (Nielsen, 1994), demonstrando os módulos Dart, máquinas de estados, invariantes e suítes de testes reais do repositório que materializam cada princípio.</p>
</div>

<p>
  Para validar cientificamente a qualidade ergonômica e semiótica da interface construída, submeteu-se a totalidade das telas e fluxos do <strong>Desperrengue (<code>v2.11.0</code>)</strong> à auditoria formal pelas <strong>10 Heurísticas de Usabilidade de Jakob Nielsen</strong> (Nielsen &amp; Molich, 1990; Nielsen, 1994). Diferentemente de avaliações subjetivas superficiais, a análise a seguir demonstra, para cada heurística <strong>H1 a H10</strong>, o mecanismo computacional exato implementado em <code>app/lib/</code> e o respectivo oráculo automatizado em <code>app/test/</code> que impede regressões.
</p>

<h3 id="sec-5-4-h1">5.4.1. H1 — Visibilidade do Status do Sistema (<em>Visibility of System Status</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> O sistema deve manter o usuário constantemente informado sobre o que está acontecendo no interior da máquina transacional, fornecendo <em>feedback</em> visual, semântico e temporal imediato dentro de limites cognitivos estritos (<span class="math-inline">&le; 100 ms</span> para percepção de instantaneidade, <span class="math-inline">&le; 1,0 s</span> para continuidade de fluxo mental).
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Máquina de Estados Visível em Tempo Real (<code>DetalheServicoClienteScreen</code> e <code>ProviderExecutionScreens</code>):</strong> Em <code>app/lib/features/client/presentation/detalhe_servico_cliente_screen.dart</code> e <code>app/lib/features/provider/presentation/provider_execution_screens.dart</code>, toda ordem exibe no 1º andar do cabeçalho o <code>StatusChip</code> colorido semanticamente (mapeado por <code>app/lib/core/ui/job_labels.dart</code>) acoplado a uma linha do tempo progressiva que reflete instantaneamente via <strong>Supabase Realtime WebSockets</strong> (<code>app/lib/core/utils/resilient_stream.dart</code>) cada transição: <code>open &rarr; hired &rarr; in_progress &rarr; completed</code>.
  </li>
  <li>
    <strong>Transparência da Trava Geoespacial e Cronômetro Regressivo até <code>00:00</code> SP (<code>geo_privacy_widgets.dart</code>):</strong> Quando uma ordem agendada encontra-se na fase <code>HIRED_PRE_DAY_LOCKED</code>, os componentes <code>ProtectedAreaMapCard</code>, <code>GeoLockNotice</code> e <code>ProtectedAreaMapSheet</code> informam explicitamente ao prestador e ao morador que o endereço exato está protegido pelo protocolo de segurança e exibem o instante exato de destravamento (<code>00:00:00 America/Sao_Paulo</code> do dia do serviço), eliminando dúvidas sobre o motivo de a rua e o número ainda não estarem visíveis.
  </li>
  <li>
    <strong>Visibilidade Contábil de Custódia e Maturação (<code>wallet_tab.dart</code> e <code>fintech_warranty_widgets.dart</code>):</strong> A carteira do profissional discrimina com precisão de centavos (<code>BIGINT</code>) o saldo retido em <em>Smart Escrow</em>, o saldo em maturação (<code>D+0</code>, <code>D+2</code> ou <code>D+5..D+7</code>), o reembolso isento de materiais (<code>0%</code> de taxa) e a vigência dos <code>90 dias</code> de garantia legal.
  </li>
  <li>
    <strong>Contadores de Não Lidos em <span class="math-inline">O(1)</span> e Imagens a <span class="math-inline">0 ms</span>:</strong> O controlador <code>UnreadOrdersBadgeController</code> (<code>app/lib/core/state/unread_orders_badge_controller.dart</code>) atualiza insígnias de eventos não lidos em tempo constante <span class="math-inline">O(1)</span>, enquanto o motor <code>InstantImageCacheEngine</code> (<code>app/lib/core/services/instant_image_cache_engine.dart</code>) entrega avatares e fotos a <span class="math-inline">0 ms</span> a partir da memória L1 (<code>96 MiB</code>), banindo telas em branco.
  </li>
</ul>

<h3 id="sec-5-4-h2">5.4.2. H2 — Correspondência entre o Sistema e o Mundo Real (<em>Match Between System and the Real World</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> A interface deve falar a linguagem cotidiana do usuário — com palavras, frases, metáforas e conceitos familiares ao domínio físico — em vez de expor termos orientados à implementação interna de engenharia.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Tradutor Léxico Zero-Jargão no KYC e na Interface (<code>kyc_human_feedback_translator.dart</code>):</strong> Em estrito cumprimento ao requisito <code>RNF-03</code>, o módulo <code>app/lib/core/ui/kyc_human_feedback_translator.dart</code> intercepta códigos criptográficos, vetos biométricos e fatores matemáticos SHAP provenientes do <code>kyc_engine</code> e os converte em orientações humanas diretas e acolhedoras (ex.: em vez de exibir <code>"LAP_VAR_BELOW_THRESHOLD_42.1"</code> ou <code>"CMS_PKCS7_SIGNATURE_MISMATCH"</code>, orienta: <em>"A foto da CNH ficou um pouco desfocada. Apoie o documento sobre uma mesa bem iluminada e tente novamente"</em>).
  </li>
  <li>
    <strong>Triagem Semântica em Linguagem Natural Falada (<code>voice_dictation.dart</code> e <code>smart_triage_service.dart</code>):</strong> O morador não precisa conhecer a taxonomia normativa da construção civil; ao relatar em voz coloquial <em>"o cano debaixo da pia da cozinha estourou e está alagando"</em>, o pipeline <code>SmartTranscriptFormatter</code> (<code>app/lib/core/utils/smart_transcript_formatter.dart</code>) pontua a frase e o <code>SmartTriageService</code> mapeia imediatamente o relato para <strong>Hidráulica + Urgência SOS</strong>.
  </li>
  <li>
    <strong>Metáforas Visuais <em>Duotone</em> e Passaporte Predial:</strong> Os 33 emblemas em <code>duotone_service_icons.dart</code> reproduzem ferramentas e símbolos universais do cotidiano brasileiro, e o histórico técnico do imóvel adota a metáfora familiar de um <strong>Passaporte Oficial de Manutenção do Imóvel</strong> (<code>desperrengue_official_pdf_service.dart</code>).
  </li>
</ul>

<h3 id="sec-5-4-h3">5.4.3. H3 — Controle e Liberdade do Usuário (<em>User Control and Freedom</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> Usuários frequentemente acionam opções por engano ou mudam de intenção e necessitam de uma "saída de emergência" claramente sinalizada para desfazer, editar ou encerrar estados sem depender de suporte burocrático.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Alternância Instantânea <em>Dual-Mode</em> sem Reautenticação (<code>user_profile.dart</code> e <code>provider_shell.dart</code>):</strong> O usuário detém liberdade plena para comutar a qualquer instante entre o <strong>Modo Cliente</strong> e o <strong>Modo Profissional</strong> com um único toque, sem perda de sessão ou repetição de cadastro.
  </li>
  <li>
    <strong>Persistência Automática de Rascunho e Edição Livre Pré-Publicação (<code>draft_store.dart</code>):</strong> Durante a criação de um chamado em <code>request_wizard.dart</code>, o serviço <code>DraftStore</code> (<code>app/lib/core/services/draft_store.dart</code>) preserva localmente o relato de voz transcrito, o endereço e os parâmetros caso o usuário feche o modal acidentalmente, permitindo retomar, corrigir o texto ditado ou descartar o rascunho com um toque.
  </li>
  <li>
    <strong>Autonomia de Privacidade e Exclusão Granular Escopada (<code>delete_account_screen.dart</code>):</strong> Na tela <code>app/lib/features/shared/presentation/delete_account_screen.dart</code>, em vez de impor um bloqueio binário "tudo ou nada", o sistema oferece três escopos independentes de exclusão (apenas perfil <code>client</code>, apenas perfil <code>provider</code> ou conta completa <code>both</code>), precedidos pelo envio automático do <strong>Dossiê PDF de Portabilidade LGPD</strong> (<code>supabase/functions/excluir-conta/dossie.ts</code>).
  </li>
  <li>
    <strong>Saída Física Segura sob Ameaça (<em>Silent Duress PIN</em> em <code>zero_trust_bilateral_security_engine.dart</code>):</strong> No cenário extremo de coação presencial durante o encerramento de uma ordem, a liberdade e a integridade física do morador são preservadas pela digitação do PIN de 4 dígitos invertido, que simula liberação normal na tela enquanto congela silenciosamente o repasse (<code>FROZEN_UNDER_DURESS</code>).
  </li>
</ul>

<h3 id="sec-5-4-h4">5.4.4. H4 — Consistência e Padrões (<em>Consistency and Standards</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> Os usuários não devem precisar adivinhar se palavras, cores, ícones ou ações diferentes significam a mesma coisa; o sistema deve obedecer rigorosamente às convenções internas de seu Design System e às normas externas do domínio.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Codificação Cromática Bimodal de Papel (<code>#FF8F52</code> vs. <code>#74A7FF</code>):</strong> Em <code>100%</code> das telas da plataforma (<code>app_tokens.dart</code>), o acento laranja energético (<code>#FF8F52</code> no escuro / <code>#F26B0F</code> no claro) sinaliza invariavelmente ações e contextos do <strong>Morador Contratante</strong>, enquanto o acento azul técnico (<code>#74A7FF</code> no escuro / <code>#1B3A78</code> no claro) sinaliza o <strong>Prestador Profissional</strong>, impedindo confusão de papéis na conta unificada.
  </li>
  <li>
    <strong>Padronização Semântica das 112 Medalhas (<code>#CBD5E1</code>):</strong> Tanto nas 90 medalhas do profissional (<code>achievements.dart</code>) quanto nas 22 medalhas do cliente (<code>client_achievements.dart</code>), a forja vetorial <code>AchievementMedalForge</code> aplica exatamente a mesma gramática visual: prata clara legível <strong><code>#CBD5E1</code></strong> com cadeado <code>#E2E8F0</code> para conquistas bloqueadas e ligas metálicas vibrantes para conquistas alcançadas.
  </li>
  <li>
    <strong>Guardas Estáticas de Arquitetura e UI (<code>eng_static_guards_test.dart</code>):</strong> A suíte automatizada <code>app/test/eng_static_guards_test.dart</code> varre a árvore de código em <code>app/lib/</code> para impor que nenhum componente viole os padrões de cache de mídia (<code>InstantCachedImage</code>), formatação monetária inteira (<code>money.dart</code>) ou isolamento de segredos.
  </li>
</ul>

<h3 id="sec-5-4-h5">5.4.5. H5 — Prevenção de Erros (<em>Error Prevention</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> Melhor do que exibir boas mensagens de erro é projetar a arquitetura de interação de modo a <strong>impedir matematicamente que a condição de erro, fraude ou vazamento ocorra</strong> em primeiro lugar.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Validação Algorítmica Local de Chave NF-e de 44 Dígitos (<code>nfe_access_key.dart</code>):</strong> Na tela <code>MaterialReceiptCaptureScreen</code> (<code>app/lib/features/provider/presentation/material_receipt_capture_screen.dart</code>), antes de permitir o envio de comprovante fiscal para isenção de <code>0%</code> no <em>Smart Split</em>, o validador <code>app/lib/core/utils/nfe_access_key.dart</code> verifica localmente o comprimento exato de 44 dígitos numéricos, a Unidade Federativa, a data de emissão, o dígito verificador do CNPJ emissor e o <strong>dígito verificador Módulo 11 da NF-e</strong>, bloqueando chaves inválidas ou erros de digitação antes da requisição de rede.
  </li>
  <li>
    <strong>Portão Biométrico e Óptico Tier-0 em <code>Isolate.run</code> (<code>zero_trust_bilateral_security_engine.dart</code>):</strong> Durante o KYC em <code>verificacao_step1_frente.dart</code> a <code>verificacao_step3_selfie.dart</code>, o app calcula localmente a variância do operador Laplaciano (<span class="math-inline">&nabla;<sup>2</sup>I</span>) e a exposição luminosa, impedindo o envio de fotos borradas ou escuras a custo zero.
  </li>
  <li>
    <strong>Erradicação de Erros de Ponto Flutuante e Colisão de Horários (<code>money.dart</code> e <code>scheduling_service.dart</code>):</strong> O formatador <code>currency_input_formatter.dart</code> e a classe <code>money.dart</code> operam estritamente sobre inteiros de 64 bits em centavos (eliminando dízimas IEEE 754), o gerador de PIN proíbe códigos palíndromos (para que o <em>Silent Duress PIN</em> nunca colida com o PIN normal) e o <code>SchedulingService</code> (<code>app/lib/core/services/scheduling_service.dart</code>) bloqueia agendamentos com sobreposição temporal.
  </li>
  <li>
    <strong>Expurgo Automático <em>Fail-Closed</em> de Metadados EXIF/GPS (<code>image_metadata_stripper.dart</code>):</strong> O usuário jamais corre o risco de vazar acidentalmente a coordenada GPS de sua residência ao anexar uma foto da galeria, pois o <code>ImageMetadataStripper</code> remove <code>100%</code> dos blocos <code>APP1/EXIF</code> antes do upload.
  </li>
</ul>

<h3 id="sec-5-4-h6">5.4.6. H6 — Reconhecimento em vez de Memorização (<em>Recognition Rather Than Recall</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> A carga sobre a memória de trabalho humana (limitada a <span class="math-inline">4 &plusmn; 1</span> <em>chunks</em> segundo Cowan, 2001) deve ser minimizada tornando objetos, opções, emblemas e premissas visíveis ou imediatamente recuperáveis no contexto da decisão.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Reconhecimento Pré-Atentivo pelas 33 Insígnias <em>Duotone</em> e Cabeçalho de 2 Andares:</strong> Em vez de exigir que o usuário lembre códigos ou leia tabelas densas, cada ordem exibe no 1º andar do cabeçalho o emblema colorido da sua família técnica (<code>CategoryBrandEmblem</code>) ao lado do status atual, e no 2º andar o título descritivo integral sem truncamento.
  </li>
  <li>
    <strong>Comparação Visual Direta de Propostas e Portfólio Sincronizado (<code>provider_public_profile_screen.dart</code>):</strong> Ao avaliar orçamentos, o morador visualiza lado a lado na mesma tela o <em>Reputation Trust Score</em> (RTS), as medalhas desbloqueadas, a galeria de fotos antes/depois (<code>provider_portfolio_widgets.dart</code>) e a partição exata entre mão de obra e peças, sem precisar alternar entre telas para memorizar valores.
  </li>
  <li>
    <strong>Silhuetas Visíveis <code>#CBD5E1</code> nas Conquistas Pendentes:</strong> Na galeria de conquistas, o uso do cinza claro prateado <code>#CBD5E1</code> com barra de progresso explícita (ex.: <code>7 / 10 serviços concluídos</code>) permite reconhecer visualmente o próximo marco de carreira sem consultar manuais externos.
  </li>
</ul>

<h3 id="sec-5-4-h7">5.4.7. H7 — Flexibilidade e Eficiência de Uso (<em>Flexibility and Efficiency of Use</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> Aceleradores — invisíveis ou não intrusivos para o usuário novato — devem permitir que usuários experientes ou sob restrição severa de tempo executem tarefas frequentes com velocidade superior, adaptando o sistema a múltiplos contextos de operação.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Acelerador Multimodal por Voz (<span class="math-inline">&lt; 60 s</span>) vs. Seleção Guiada:</strong> Usuários com pressa ou pouca familiaridade com teclados virtuais abrem um chamado completo ditando por voz em menos de um minuto (<code>voice_dictation.dart</code> + <code>smart_triage_widgets.dart</code>), enquanto usuários que preferem navegação táctil dispõem de busca instantânea com sinônimos normalizados (<code>app/lib/core/utils/tag_normalizer.dart</code>, validado por <code>tag_alias_parity_test.dart</code>).
  </li>
  <li>
    <strong>Pré-Busca Proativa de Mídia (<code>EagerImagePrefetcher</code>) e Renderização a <code>120 FPS</code>:</strong> Em <code>app/lib/core/services/instant_image_cache_engine.dart</code>, o <code>EagerImagePrefetcher</code> antecipa em segundo plano (controlado por semáforo de concorrência) a decodificação dos avatares e portfólios dos prestadores listados, garantindo transição instantânea (<span class="math-inline">0 ms</span>) ao abrir qualquer perfil, mantendo o orçamento de quadro em <span class="math-inline">&Delta;t &le; 8,33 ms</span> via <code>RepaintBoundary</code> e <code>Isolate.run</code> (<code>off_thread.dart</code>).
  </li>
  <li>
    <strong>Filtros Rápidos de Radar e Conquistas:</strong> O prestador filtra oportunidades por raio e categoria em complexidade <span class="math-inline">O(log N + K)</span> (<code>provider_filters.dart</code>), e ambos os perfis filtram as 112 medalhas instantaneamente por estado (<em>Todas</em>, <em>Conquistadas</em>, <em>Em Progresso</em>).
  </li>
</ul>

<h3 id="sec-5-4-h8">5.4.8. H8 — Estética e Design Minimalista (<em>Aesthetic and Minimalist Design</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> As interfaces não devem conter informações irrelevantes ou raramente necessárias; cada unidade extra de informação visual em uma tela compete com as unidades relevantes e diminui sua visibilidade relativa (relação sinal-ruído de Tufte).
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Preservação de <span class="math-inline">&ge; 80%</span> de Área Limpa no Mapa Ao Vivo (<code>OrderLiveMapModalScreen</code>):</strong> A remoção de cartões opacos redundantes sobre o mapa garante que mais de quatro quintos da tela exibam exclusivamente a malha viária e a geometria da rota ou do círculo de privacidade, concentrando os controles em uma única folha inferior colapsável.
  </li>
  <li>
    <strong>Disciplina Visual <em>Quiet Luxury Dark Mode</em> e Divulgação Progressiva (<em>Progressive Disclosure</em>):</strong> O sistema elimina banners publicitários, pop-ups gamificados intrusivos e gradientes saturados de baixa legibilidade. Detalhes periciais complexos (como chaves criptográficas de 44 dígitos, hashes <code>SHA-256</code> do Passaporte Predial e regras das 3 camadas de garantia) são organizados em cartões expansíveis sob demanda (<code>fintech_warranty_widgets.dart</code>), mantendo a superfície primária limpa e silenciosa.
  </li>
</ul>

<h3 id="sec-5-4-h9">5.4.9. H9 — Ajuda aos Usuários para Reconhecer, Diagnosticar e Recuperar-se de Erros</h3>
<p>
  <strong>Princípio Teórico:</strong> As mensagens de erro devem ser expressas em linguagem clara (sem códigos obscuros), indicar precisamente a causa do problema e oferecer construtivamente um caminho imediato de resolução ou recuperação automática.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Diagnóstico Construtivo e Acionável em Falhas de Saldo, KYC e NF-e:</strong> Quando o morador tenta contratar um orçamento cujo valor supera seu saldo atual em carteira, o componente <code>InsufficientFundsSheet</code> (<code>app/lib/features/client/presentation/insufficient_funds_sheet.dart</code>) calcula exatamente a diferença faltante em centavos e apresenta o botão direto de recarga PIX para concluir a contratação sem perder a proposta selecionada. De igual modo, em <code>kyc_human_feedback_translator.dart</code> e <code>app_failure.dart</code> (<code>app/lib/core/utils/app_failure.dart</code>), qualquer rejeição documental explica qual requisito óptico falhou e habilita o botão imediato de nova captura.
  </li>
  <li>
    <strong>Auto-Recuperação Silenciosa de Rede e Cartografia (<em>Self-Healing</em>):</strong> Quando ocorrem oscilações de sinal 4G/5G, o usuário não é interrompido por diálogos fatais de desconexão: o <code>ResilientStream</code> reconecta em segundo plano via <em>exponential backoff com jitter</em> e o <code>OrderLiveMapModalScreen</code> alterna automaticamente da rota OSRM para o arco geodésico <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos, mantendo a experiência ininterrupta.
  </li>
</ul>

<h3 id="sec-5-4-h10">5.4.10. H10 — Ajuda e Documentação (<em>Help and Documentation</em>)</h3>
<p>
  <strong>Princípio Teórico:</strong> Ainda que o sistema seja projetado para ser operado sem leitura prévia de manuais, é indispensável prover documentação contextual concisa, orientada à tarefa do usuário e acessível no exato ponto de dúvida contratual ou regulatória.
</p>
<p>
  <strong>Materialização no Código Real do Desperrengue:</strong>
</p>
<ul>
  <li>
    <strong>Microdocumentação Contextual nos Pontos de Decisão Crítica:</strong> Nos momentos em que surgem dúvidas naturais — <em>"Por que meu endereço não aparece no mapa antes do dia?"</em>, <em>"Como funciona a isenção de 0% sobre peças?"</em> ou <em>"Quando devo informar o PIN de 4 dígitos?"</em> —, os componentes <code>GeoLockNotice</code> (<code>geo_privacy_widgets.dart</code>) e os painéis explicativos de custódia/garantia (<code>fintech_warranty_widgets.dart</code>) exibem resumos claros de duas linhas diretamente no contexto da tela.
  </li>
  <li>
    <strong>Central de Suporte, Mediação Guiada e Documentação Oficial Auditada (<code>support_screens.dart</code>):</strong> O módulo <code>app/lib/features/shared/presentation/support_screens.dart</code> oferece central estruturada de ajuda, perguntas frequentes (FAQ) segmentadas por papel (Morador vs. Prestador), fluxo guiado de abertura das 3 camadas da Garantia de 90 Dias e acesso transparente às políticas de privacidade LGPD, apoiado pelos artefatos documentais técnicos versionados no repositório (<code>docs/Projeto de Interface.md</code> e <code>docs/GAMIFICACAO.md</code>).
  </li>
</ul>

<h3 id="sec-5-4-matriz">5.4.11. Matriz Síntese de Conformidade Heurística de Jakob Nielsen (H1 a H10 — <span class="mono">v2.11.0</span>)</h3>
<p>
  A Tabela 5.4 consolida a auditoria das 10 Heurísticas de Jakob Nielsen, correlacionando cada princípio aos módulos reais de código, às métricas quantificadas da norma ISO/IEC 25010 e às suítes de testes automatizados que comprovam sua conformidade integral.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="7%">ID</th>
      <th width="20%">Heurística de Jakob Nielsen (1994)</th>
      <th width="27%">Materialização Concreta na Interface do Desperrengue</th>
      <th width="25%">Arquivos Reais em <code>app/lib/</code></th>
      <th width="21%">Métrica &amp; Suíte de Teste em <code>app/test/</code></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong><code>H1</code></strong></td>
      <td><strong>Visibilidade do Status do Sistema</strong></td>
      <td><code>StatusChip</code> no 1º andar, stepper Realtime, relógio Geo-Lock <code>00:00</code> SP, badge <span class="math-inline">O(1)</span> e mídia L1 a <span class="math-inline">0 ms</span>.</td>
      <td><code>detalhe_servico_cliente_screen.dart</code>, <code>geo_privacy_widgets.dart</code>, <code>instant_image_cache_engine.dart</code></td>
      <td>Hit L1 = <code>0 ms</code>; Badge <span class="math-inline">O(1)</span>.<br/><code>eng_unread_badge_test.dart</code>, <code>temporal_geo_privacy_lock_widgets_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H2</code></strong></td>
      <td><strong>Correspondência com o Mundo Real</strong></td>
      <td>Tradutor zero-jargão p/ KYC/SHAP, triagem por voz coloquial, 33 ícones <em>Duotone</em> e Passaporte Predial.</td>
      <td><code>kyc_human_feedback_translator.dart</code>, <code>duotone_service_icons.dart</code>, <code>smart_triage_service.dart</code></td>
      <td><code>0</code> jargões técnicos na UI.<br/><code>argon_carbon_kyc_and_ux_test.dart</code>, <code>smart_triage_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H3</code></strong></td>
      <td><strong>Controle e Liberdade do Usuário</strong></td>
      <td>Chave <em>Dual-Mode</em> instantânea, rascunho automático, exclusão escopada LGPD com Dossiê PDF e <em>Silent Duress PIN</em>.</td>
      <td><code>draft_store.dart</code>, <code>delete_account_screen.dart</code>, <code>zero_trust_bilateral_security_engine.dart</code></td>
      <td>Comutação <span class="math-inline">O(1)</span>; 3 escopos LGPD.<br/><code>address_and_draft_test.dart</code>, <code>dossier_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H4</code></strong></td>
      <td><strong>Consistência e Padrões</strong></td>
      <td>Tokens semânticos (<code>#FF8F52</code> Cliente vs. <code>#74A7FF</code> Pro), grid <code>480px</code> e 112 medalhas bloqueadas em <code>#CBD5E1</code>.</td>
      <td><code>app_tokens.dart</code>, <code>app_theme.dart</code>, <code>profile_and_achievement_emblems.dart</code></td>
      <td>Contraste <code>15,6:1</code> / <code>9,8:1</code> AAA.<br/><code>eng_static_guards_test.dart</code>, <code>achievements_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H5</code></strong></td>
      <td><strong>Prevenção de Erros</strong></td>
      <td>Validador NF-e 44d Módulo 11, portão KYC Tier-0 Laplaciano, moeda inteira <code>BIGINT</code> e strip 100% EXIF GPS.</td>
      <td><code>nfe_access_key.dart</code>, <code>money.dart</code>, <code>image_metadata_stripper.dart</code>, <code>scheduling_service.dart</code></td>
      <td>Erro IEEE 754 = <code>0</code>; EXIF = <code>0</code>.<br/><code>nfe_access_key_test.dart</code>, <code>eng_image_metadata_stripper_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H6</code></strong></td>
      <td><strong>Reconhecimento em vez de Memorização</strong></td>
      <td>Emblemas cromáticos por família no cabeçalho de 2 andares, vitrine RTS/portfólio e silhuetas legíveis <code>#CBD5E1</code>.</td>
      <td><code>category_brand_emblem.dart</code>, <code>provider_public_profile_screen.dart</code>, <code>achievement_widgets.dart</code></td>
      <td>Reconhecimento <span class="math-inline">&lt; 200 ms</span>.<br/><code>carbon_geo_badges_and_image_cache_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H7</code></strong></td>
      <td><strong>Flexibilidade e Eficiência de Uso</strong></td>
      <td>Abertura por voz em <span class="math-inline">&lt; 60s</span>, pré-busca <code>EagerImagePrefetcher</code>, <code>Isolate.run</code> e fluidez a <code>120 FPS</code> (<span class="math-inline">8,33 ms</span>).</td>
      <td><code>voice_dictation.dart</code>, <code>smart_transcript_formatter.dart</code>, <code>off_thread.dart</code></td>
      <td>Abertura <span class="math-inline">&le; 50,4 s &lt; 60 s</span>.<br/><code>smart_transcript_formatter_test.dart</code>, <code>eng_address_privacy_and_offthread_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H8</code></strong></td>
      <td><strong>Estética e Design Minimalista</strong></td>
      <td><em>Quiet Luxury Dark Mode</em>, mapa ao vivo com <span class="math-inline">&ge; 80%</span> de área livre e divulgação progressiva de detalhes fiscais.</td>
      <td><code>order_live_map_modal_screen.dart</code>, <code>service_map_widgets.dart</code>, <code>light_island.dart</code></td>
      <td>Mapa livre <span class="math-inline">&ge; 80%</span>; <code>0</code> overflow.<br/><code>orders_map_ux_and_instant_media_test.dart</code>, <code>ui_polish_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H9</code></strong></td>
      <td><strong>Reconhecer, Diagnosticar e Recuperar-se de Erros</strong></td>
      <td><code>InsufficientFundsSheet</code> com recarga exata, reconexão Realtime <em>backoff + jitter</em> e rota geodésica <span class="math-inline">C<sup>&infin;</sup></span> fallback.</td>
      <td><code>insufficient_funds_sheet.dart</code>, <code>resilient_stream.dart</code>, <code>app_failure.dart</code></td>
      <td>Fallback rota = <code>0 ms</code>.<br/><code>eng_resilience_and_policy_test.dart</code>, <code>eng_money_and_failure_test.dart</code></td>
    </tr>
    <tr>
      <td><strong><code>H10</code></strong></td>
      <td><strong>Ajuda e Documentação</strong></td>
      <td>Avisos contextuais de <em>Geo-Privacy Lock</em>, guia interativo da Garantia de 90 Dias (3 camadas) e FAQ segmentado.</td>
      <td><code>support_screens.dart</code>, <code>fintech_warranty_widgets.dart</code>, <code>geo_privacy_widgets.dart</code></td>
      <td>Cobertura de 100% dos fluxos.<br/><code>ux_client_and_shared_polish_test.dart</code>, <code>fintech_warranty_security_test.dart</code></td>
    </tr>
  </tbody>
</table>
</section>
`;

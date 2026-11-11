export const aiPart2Html = `
<!-- ======================================================================= -->
<!-- CAPÍTULO 3 — INOVAÇÕES DISRUPTIVAS #1 A #5                              -->
<!-- ======================================================================= -->
<div class="page-break"></div>
<div id="ai-cap-3" class="chapter-banner">
  <div class="cb-num">CAPÍTULO 3</div>
  <div class="cb-body">
    <h2>Inovações Disruptivas #1 a #5: Diagnóstico Acústico-Espectral, Atuária Dinâmica PIX D+0, Visão 3D e Auditoria Fiscal</h2>
    <p>Engenharia detalhada dos 5 primeiros sistemas exclusivos que fundem processamento de sinais físicos, visão computacional e garantias financeiras.</p>
  </div>
</div>

<!-- INOVAÇÃO #1 -->
<div class="innovation-box">
  <div class="ib-header">3.1. INOVAÇÃO #1 — Motor de Diagnóstico Aero-Acústico e Vibro-Espectral (FFT + Mel-Spectrogram On-Device Acoplado ao Smart Split)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Marketplaces convencionais exigem apenas fotos estáticas. Contudo, 62% das patologias críticas em climatização (ar-condicionado split), linha branca (lavadoras/geladeiras), quadros elétricos e tubulações embutidas são <strong>invisíveis externamente</strong>, mas emitem assinaturas aero-acústicas e vibracionais determinísticas. Fraudadores exploram essa cegueira condenando compressores ou motores inteiros (<code>R$ 1.200+</code>) quando o defeito real é um capacitor de partida ou rolamento de <code>R$ 45,00</code>.
  </p>
  <ul>
    <li><strong>Aquisição Sincronizada Dual-Sensor (5 Segundos):</strong> O cliente encosta ou aproxima o smartphone a 15 cm do equipamento/parede por 5 segundos. O app captura áudio PCM linear 16-bit a $f_s = 44.100\text{ Hz}$ via pacote <code>record</code> e aceleração triaxial $(a_x, a_y, a_z)$ a $f_{\text{imu}} = 200\text{ Hz}$ via <code>sensors_plus</code>.</li>
    <li><strong>Formulação Matemática do Processamento Espectral (Worker Isolate):</strong> Aplica-se janelamento de Hann $w[n] = 0,5\big(1 - \cos(2\pi n / (N-1))\big)$ com $N = 2048$ amostras e <em>hop size</em> $H = 512$, calculando a Transformada de Fourier de Tempo Curto (STFT) e projetando o espectro de potência em $M = 64$ bandas na escala perceptual Mel:
      <div class="math-formula-box">
        $$S_{\text{Mel}}(m, \tau) = \ln\left(\epsilon + \sum_{k=0}^{N/2} H_m(k) \cdot \left|\sum_{n=0}^{N-1} x[n + \tau H]\, w[n]\, e^{-j 2\pi k n / N}\right|^2\right), \quad \text{Mel}(f) = 2595 \log_{10}\left(1 + \frac{f}{700}\right)$$
      </div>
    </li>
    <li><strong>Física das Assinaturas Detectadas:</strong>
      <br/>&bull; <em>Arco Elétrico / Mau Contato em Disjuntor (NR-10):</em> Energia impulsiva banda-larga entre $2\text{ kHz}$ e $12\text{ kHz}$ modulada em $120\text{ Hz}$ ($2 \times f_{\text{rede}}$);
      <br/>&bull; <em>Capacitor de Partida Degradado em Compressor:</em> Zumbido estacionário puro em $60\text{ Hz}$ e harmônicos ímpares ($180\text{ Hz}, 300\text{ Hz}$) sem rampa de rotação;
      <br/>&bull; <em>Cavitação e Vazamento Pressurizado Interno na Parede:</em> Ruído estocástico contínuo estacionário na faixa de $400\text{ Hz}$ a $1.800\text{ Hz}$ com curtose espectral $\kappa_f &lt; 2,1$;
      <br/>&bull; <em>Folga Axial em Rolamento de Lavadora/Bomba:</em> Picos periódicos na frequência de passagem de esferas (BPFO/BPFI) no acelerômetro IMU ($18\text{ Hz}$ a $85\text{ Hz}$).
    </li>
    <li><strong>Acoplamento Direto com a Custódia Fintech:</strong> O classificador <code>dsp_acoustic_fault_v1.tflite</code> gera um <strong>Laudo Preliminar Criptografado</strong> anexado à OS e define uma <strong>Trava de Teto de Insumos (<em>Smart Split Cap</em>)</strong>. Se o diagnóstico espectral aponta 93% de probabilidade de falha apenas no capacitor, e o técnico tenta submeter no local um orçamento condenando o compressor inteiro, o app exige obrigatoriamente o vídeo macro do teste ôhmico dos terminais C-S-R no multímetro antes de liberar a alteração!</li>
  </ul>
</div>

<!-- INOVAÇÃO #2 -->
<div class="innovation-box">
  <div class="ib-header">3.2. INOVAÇÃO #2 — Subscrição Atuarial Dinâmica de Custódia (PIX D+0 Instantâneo via Modelo de Sobrevivência de Cox + LightGBM)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Todas as plataformas aplicam regras estáticas de liquidação (ex.: "todo profissional nível 3 recebe em D+5"). Isso ignora que o risco de acionamento de garantia pós-serviço varia drasticamente conforme a natureza de cada Ordem de Serviço. O Desperrengue introduz o primeiro <strong>Motor de Subscrição Atuarial por Transação em Tempo Real (<em>Per-Job Real-Time Actuarial Underwriting</em>)</strong>.
  </p>
  <ul>
    <li><strong>Vetor de Entrada de 28 Dimensões ($\mathbf{x}_i \in \mathbb{R}^{28}$):</strong> No exato milissegundo em que o cliente digita o PIN de 4 dígitos para aprovar o serviço, a Edge Function constrói o vetor $\mathbf{x}_i$ combinando: (1) Score Bayesiano do prestador naquela subcategoria específica; (2) Score de qualidade visual contrafactual $Q_{\text{visual}}$ do par <code>Before/After</code>; (3) Existência e validação SEFAZ da nota fiscal de peças; (4) Razão entre tempo real de execução e tempo mediano histórico da categoria; (5) Índice de severidade climática local (precipitação/raios nas últimas 24h via Open-Meteo); (6) Histórico de disputas do imóvel/cliente.</li>
    <li><strong>Equação de Risco Proporcional de Cox + Gradient Boosting (ONNX):</strong> Calcula-se a probabilidade acumulada de retrabalho nos próximos $\Delta t = 90\text{ dias}$:
      <div class="math-formula-box">
        $$\hat{p}_{\text{rework}}(\Delta t \mid \mathbf{x}_i) = 1 - \exp\left(-H_0(\Delta t) \cdot \exp\big(f_{\text{LGBM}}(\mathbf{x}_i)\big)\right), \quad \text{Prêmio Atuarial: } \pi_i = \text{clip}\big(\alpha_0 + \gamma \cdot \hat{p}_{\text{rework}},\, 0,002,\, 0,035\big)$$
      </div>
    </li>
    <li><strong>Liquidação Instantânea PIX D+0 sem Risco Moral:</strong>
      <br/>&bull; Se $\hat{p}_{\text{rework}} \le 1,5\%$ (serviço bem documentado, peça certificada na SEFAZ, foto <code>After</code> íntegra e tempo coerente): o sistema converte automaticamente a retenção de <code>D+5</code> ou <code>D+2</code> em <strong>PIX Instantâneo D+0 (dinheiro na conta em 3 segundos)</strong> mediante retenção de micro-prêmio atuarial de apenas $0,25\%$ destinado ao <code>warranty_pool_ledger</code>;
      <br/>&bull; Se $\hat{p}_{\text{rework}} &gt; 8,0\%$ (ex.: reparo complexo de infiltração concluído em apenas 9 minutos sem nota de material): o motor bloqueia a antecipação e mantém a maturação escalonada auditada, protegendo o caixa do Fundo de Garantia!</li>
  </ul>
</div>

<!-- INOVAÇÃO #3 -->
<div class="page-break"></div>
<div class="innovation-box">
  <div class="ib-header">3.3. INOVAÇÃO #3 — Orçamentador Volumétrico 3D por Profundidade Monocular (Depth-Anything-V2 + Lista de Materiais SINAPI)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Em serviços de pintura, gesso, assentamento de porcelanato, impermeabilização e telhados, o orçamento depende diretamente da <strong>metragem quadrada ($\text{m}^2$) ou linear ($\text{m}$)</strong>. Clientes não sabem medir paredes ou compram material errado, e profissionais perdem horas em visitas presenciais improdutivas apenas para tirar medidas.
  </p>
  <ul>
    <li><strong>Reconstrução Métrica Monocular + Gravidade IMU:</strong> Utilizando uma única foto ou varredura curta de 3 segundos com a câmera do celular, o modelo embarcado <code>depth_anything_v2_small_indoor.tflite</code> estima o mapa denso de profundidade métrica $Z(u,v)$ para cada pixel $(u,v)$. Combinado com a matriz intrínseca da câmera $\mathbf{K}$ (extraída dos metadados EXIF: distância focal $f_x, f_y$ e centro óptico $c_x, c_y$) e o vetor gravitacional do acelerômetro $\mathbf{g}$, cada pixel é retroprojetado para coordenadas métricas 3D reais $(X, Y, Z)$ em metros:
      <div class="math-formula-box">
        $$\begin{bmatrix} X(u,v) \\ Y(u,v) \\ Z(u,v) \end{bmatrix} = Z(u,v) \cdot \mathbf{K}^{-1} \begin{bmatrix} u \\ v \\ 1 \end{bmatrix} = Z(u,v) \cdot \begin{bmatrix} (u - c_x)/f_x \\ (v - c_y)/f_y \\ 1 \end{bmatrix}, \quad \text{Área Real } A = \iint_{\Omega_{\text{parede}}} \left\| \frac{\partial \mathbf{P}}{\partial u} \times \frac{\partial \mathbf{P}}{\partial v} \right\|_2 \, du\,dv$$
      </div>
    </li>
    <li><strong>Geração Automática da Bill of Materials (BOM) Auditada pelo SINAPI/IBGE:</strong> A partir da área $A$ ($\text{m}^2$) e da classe do serviço, o motor consulta a tabela de coeficientes técnicos da construção civil (SINAPI):
      <br/>&bull; <em>Exemplo Prático (Pintura Acrílica em Parede Interna de $18,4\text{ m}^2$):</em> O sistema calcula automaticamente: $18,4\text{ m}^2 \times 2\text{ demãos} \times 0,11\text{ L/m}^2 = 4,05\text{ L}$ de tinta acrílica (1 galão de $3,6\text{ L}$ + margem) + $2,2\text{ kg}$ de massa corrida + 1 rolo de lã antirrespingo, ancorando a faixa justa de mão de obra ($V_{\text{MO}} \in [\text{R\$ } 280, \text{R\$ } 390]$) e materiais ($V_{\text{Mat}} \in [\text{R\$ } 145, \text{R\$ } 210]$).</li>
  </ul>
</div>

<!-- INOVAÇÃO #4 -->
<div class="innovation-box">
  <div class="ib-header">3.4. INOVAÇÃO #4 — Auditor Visual Contrafactual Siamesa (MobileCLIP + Homografia RANSAC nas Fotos Antes &times; Depois)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> O hash perceptual <code>dHash</code> 64-bit já implementado no Desperrengue impede que o profissional envie a <em>mesma foto</em> duas vezes. Porém, um fraudador sofisticado poderia tirar a foto do "Antes" na parede defeituosa do cliente e tirar a foto do "Depois" apontando para <strong>outra parede limpa da mesma casa</strong> (ou fazer uma gambiarra com fita isolante). O <code>dHash</code> veria duas fotos diferentes e aprovaria!
  </p>
  <ul>
    <li><strong>Estágio 1 — Verificação Geométrica de Mesmo Locus Físico (ORB + RANSAC em <code>opencv_dart</code>):</strong> O algoritmo extrai 500 descritores binários invariantes a escala <code>ORB</code> da região periférica de fundo (azulejos, quinas, batentes, tubulação adjacente) nas fotos <code>Before</code> e <code>After</code> e estima a matriz de homografia projetiva $\mathbf{H} \in \mathbb{R}^{3 \times 3}$ via <code>RANSAC</code>:
      <div class="math-formula-box">
        $$\text{Taxa de Inliers Geométricos } \rho_{\text{inliers}} = \frac{1}{|M|} \sum_{(\mathbf{p}_i, \mathbf{q}_i) \in M} \mathbb{I}\Big( \big\| \mathbf{q}_i - \pi(\mathbf{H}\,\tilde{\mathbf{p}}_i) \big\|_2 &lt; \varepsilon_{\text{px}} \Big) \ge 0,22$$
      </div>
      Se $\rho_{\text{inliers}} &lt; 0,22$, o app detecta na hora que a foto do "Depois" foi tirada em outro cômodo/local e solicita nova captura enquadrando o mesmo ponto!</li>
    <li><strong>Estágio 2 — Verificação Semântica Contrafactual de Reparo (<code>MobileCLIP-S1</code>):</strong> Com o alinhamento espacial confirmado, os embeddings visuais $\mathbf{e}_{\text{before}}, \mathbf{e}_{\text{after}} \in \mathbb{R}^{512}$ são projetados contra os vetores textuais de estado patológico $\mathbf{t}_{\text{defeito}}$ e estado reparado normativo $\mathbf{t}_{\text{reparado}}$:
      <div class="math-formula-box">
        $$Q_{\text{visual}} = \sigma\Big( \tau \cdot \big[ \cos(\mathbf{e}_{\text{after}}, \mathbf{t}_{\text{reparado}}) - \cos(\mathbf{e}_{\text{after}}, \mathbf{t}_{\text{defeito}}) \big] + \tau \cdot \big[ \cos(\mathbf{e}_{\text{before}}, \mathbf{t}_{\text{defeito}}) - \cos(\mathbf{e}_{\text{after}}, \mathbf{t}_{\text{defeito}}) \big] \Big) \times 100$$
      </div>
      Esse índice $Q_{\text{visual}} \in [0, 100]$ é gravado no Passaporte ABNT NBR 5674 do imóvel e exibido ao cliente na tela do PIN de 4 dígitos.</li>
  </ul>
</div>

<!-- INOVAÇÃO #5 -->
<div class="innovation-box">
  <div class="ib-header">3.5. INOVAÇÃO #5 — Agente Fiscal Multimodal SEFAZ/DANFE com Decomposição Linha-a-Linha por Código NCM (Anti-Lavagem de Comissão)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> No modelo <em>Smart Split</em> ($15\%$ sobre Mão de Obra e $0\%$ sobre Materiais), mesmo validando a chave de 44 dígitos na SEFAZ, um profissional mal-intencionado poderia comprar na loja de materiais uma <strong>furadeira nova para uso próprio</strong> ou insumos de outra obra na mesma Nota Fiscal para inflar artificialmente $V_{\text{Materiais}}$ (isento de taxa) e reduzir $V_{\text{MãoDeObra}}$.
  </p>
  <ul>
    <li><strong>Decomposição Estruturada do XML Fiscal + Classificação NCM (Nomenclatura Comum do Mercosul):</strong> Quando o profissional escaneia o QR Code da NFC-e ou código de barras da NF-e via <code>mobile_scanner</code>:
      <ol>
        <li>A Edge Function <code>sefaz-xml-auditor</code> valida a assinatura digital ICP-Brasil do XML na SEFAZ e extrai todos os nós <code>&lt;det nItem="k"&gt;</code> contendo descrição (<code>xProd</code>), código <code>NCM</code> de 8 dígitos, <code>CFOP</code> e valor (<code>vProd</code>);</li>
        <li><strong>Filtro Determinístico de Bem de Capital vs. Insumo Consumível:</strong> Itens com NCM do Capítulo 82/84/85 correspondentes a ferramentas manuais ou elétricas permanentes (ex.: NCM <code>8205.59.00</code> alicates/chaves, <code>8467.21.00</code> furadeiras/marteletes, <code>9030.31.00</code> multímetros) são <strong>automaticamente glosados de $V_{\text{Materiais}}$</strong> por pertencerem ao ferramental próprio do prestador;</li>
        <li><strong>Cruzamento Semântico Multimodal (NF-e $\times$ BOM $\times$ Foto After):</strong> O Gemini 2.5 Flash verifica em <code>400 ms</code> se cada insumo restante na nota fiscal guarda correspondência causal com a categoria da OS e com os componentes visíveis na foto do "Depois", liberando a isenção de $0\%$ exclusivamente para os materiais legitimamente aplicados no imóvel do cliente!</li>
      </ol>
    </li>
  </ul>
</div>
`;

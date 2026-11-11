export const aiPart3Html = `
<!-- ======================================================================= -->
<!-- CAPÍTULO 4 — INOVAÇÕES DISRUPTIVAS #6 A #10                             -->
<!-- ======================================================================= -->
<div class="page-break"></div>
<div id="ai-cap-4" class="chapter-banner">
  <div class="cb-num">CAPÍTULO 4</div>
  <div class="cb-body">
    <h2>Inovações Disruptivas #6 a #10: Crédito Vinculado PIX-Insumo, Grafos Anti-Lavagem, Gêmeo Digital e Arbitragem</h2>
    <p>Sistemas avançados de capital de giro autoliquidável, defesa contra redes de fraude em grafos, manutenção preditiva e mediação algorítmica.</p>
  </div>
</div>

<!-- INOVAÇÃO #6 -->
<div class="innovation-box">
  <div class="ib-header">4.1. INOVAÇÃO #6 — Capital de Giro Instantâneo "PIX-Insumo Garantido" Restrito por MCC e Validado em Tempo Real por IA</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> O maior gargalo operacional de qualquer marketplace de serviços residenciais é a compra de peças durante o atendimento. Se o profissional precisa comprar um disjuntor DR e cabos que custam <code>R$ 380,00</code>, mas não tem esse saldo livre no banco, ele pede um "PIX adiantado por fora" ao cliente. O cliente sente medo de sofrer golpe (o técnico sumir com o dinheiro) e a plataforma perde o controle da transação.
  </p>
  <ul>
    <li><strong>Arquitetura de Liquidação Vinculada em Malha Fechada (<em>Closed-Loop Escrow Material Advance</em>):</strong>
      <ol>
        <li>O cliente deposita o valor total aprovado ($V_{\text{Total}} = V_{\text{MO}} + V_{\text{Mat}}$) na Camada 1 do Escrow do Desperrengue;</li>
        <li>Com o check-in GPS do profissional confirmado no imóvel ($\le 150\text{ m}$), o Motor de Crédito Comportamental por IA libera um <strong>Limite de Compra de Insumos Uso-Único (<code>PIX-Insumo Garantido</code>)</strong> exatamente limitado a $V_{\text{Mat}}$;</li>
        <li><strong>Trava Tripla Anti-Desvio no Pagamento da Loja:</strong> Para pagar na loja de materiais de construção/elétrica/hidráulica, o profissional escaneia no app do Desperrengue: (a) a NFC-e recém-emitida no caixa da loja (validada em 1,2s na SEFAZ pelo Agente da Inovação #5) <strong>e</strong> (b) o QR Code PIX dinâmico da loja;</li>
        <li>O backend BaaS do Desperrengue confere criptograficamente se o <strong>CNPJ do recebedor do PIX é idêntico ao CNPJ emissor da NFC-e na SEFAZ</strong> e se o <code>MCC</code> (<em>Merchant Category Code</em>) / CNAE pertence ao comércio de materiais (CNAE 4744-0 / MCC <code>5211, 5251, 5065, 5072</code>). Confirmada a igualdade $\text{CNPJ}_{\text{PIX}} \equiv \text{CNPJ}_{\text{NFC-e}}$, o Desperrengue liquida o PIX diretamente para a loja em 2 segundos!</li>
      </ol>
    </li>
    <li><strong>Resultado Econômico Revolucionário:</strong> Risco de desvio = <code>0,00%</code> (o dinheiro nunca passa pela conta pessoal do técnico antes da compra, indo direto do Escrow para o CNPJ da loja mediante NFC-e válida); o cliente tem certeza absoluta de que sua peça foi comprada com nota fiscal; e o profissional trabalha sem precisar tirar 1 centavo do próprio bolso!</li>
  </ul>
</div>

<!-- INOVAÇÃO #7 -->
<div class="innovation-box">
  <div class="ib-header">4.2. INOVAÇÃO #7 — Radar Anti-Colusão por Redes Neurais em Grafos Temporais (T-GAT + Processos Pontuais de Hawkes)</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Quadrilhas de lavagem de dinheiro e autofinanciamento de cartão de crédito clonado (<em>Card Cash-Out Rings</em>) operam criando contas falsas de clientes e prestadores que não transacionam apenas em pares diretos ($A \leftrightarrow B$), mas em <strong>ciclos triangulares ou poligonais</strong> ($A \to B \to C \to D \to A$) usando aparelhos distintos para burlar regras estáticas de 1 salto.
  </p>
  <ul>
    <li><strong>Grafo Heterogêneo Temporal $G_t = (\mathcal{V}_t, \mathcal{E}_t)$ no PostgreSQL:</strong> Os vértices $\mathcal{V}_t$ representam 6 tipos de entidades: <code>Usuário</code>, <code>Chave Hardware TEE</code>, <code>Sub-rede ASN/IP</code>, <code>Torre Celular / BSSID Wi-Fi</code>, <code>Hash Cartão/PIX</code> e <code>Célula Espacial Geohash-7</code>.</li>
    <li><strong>Excitação Mútua por Processo de Hawkes + Centralidade de Ciclo:</strong> A intensidade temporal de transações suspeitas entre subgrafos é modelada por um Processo Pontual Auto-Excitável de Hawkes:
      <div class="math-formula-box">
        $$\lambda_{u,v}(t) = \mu_{u,v} + \sum_{t_k &lt; t} \alpha \, \exp\big(-\beta (t - t_k)\big) \cdot \psi(\mathbf{h}_u, \mathbf{h}_v), \quad \text{Score de Anel } \mathcal{C}_{\text{ring}}(u) = \sum_{\ell=2}^{4} \gamma^\ell \big(\mathbf{A}_t^\ell\big)_{uu}$$
      </div>
      onde $(\mathbf{A}_t^\ell)_{uu}$ mede o peso dos caminhos fechados de comprimento $\ell \in \{2, 3, 4\}$ que retornam ao mesmo cluster físico/financeiro. Qualquer transação com $\mathcal{C}_{\text{ring}}(u) &gt; \theta_{\text{crit}}$ tem a liquidação PIX retida preventivamente antes que o dinheiro saia da instituição de pagamento.</li>
  </ul>
</div>

<!-- INOVAÇÃO #8 -->
<div class="page-break"></div>
<div class="innovation-box">
  <div class="ib-header">4.3. INOVAÇÃO #8 — Gêmeo Digital Preditivo do Imóvel (ABNT NBR 5674) com Curva de Confiabilidade de Weibull</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Todos os aplicativos de serviços sofrem de baixa frequência de uso espontâneo porque esperam o equipamento quebrar para o cliente abrir o app. O Desperrengue transforma o Passaporte ABNT NBR 5674 em um <strong>Gêmeo Digital Preditivo Vivo (<em>Predictive Home Asset Digital Twin</em>)</strong>.
  </p>
  <ul>
    <li><strong>Cadastro Automático por Visão Computacional:</strong> Durante qualquer atendimento (ou pelo próprio morador), o OCR local (<code>google_mlkit_text_recognition</code>) lê a etiqueta de identificação do ar-condicionado, aquecedor a gás, pressurizador, inversor solar ou quadro de disjuntores, registrando fabricante, modelo, potência e data de instalação na tabela <code>home_assets_digital_twin</code>.</li>
    <li><strong>Modelagem Matemática de Falha por Distribuição de Weibull Condicionada ao Clima:</strong> A taxa de falha instantânea (<em>Hazard Rate</em>) de cada equipamento $j$ na idade operacional $t$ (em dias desde a última manutenção) é calculada continuamente via <code>pg_cron</code>:
      <div class="math-formula-box">
        $$h_j(t \mid \mathbf{z}_{\text{clima}}) = \frac{\beta_j}{\eta_j} \left(\frac{t}{\eta_j}\right)^{\beta_j - 1} \cdot \exp\big(\gamma_1 \cdot \text{TempMedia}_{30d} + \gamma_2 \cdot \text{Umidade}_{30d} + \gamma_3 \cdot \text{SurtosRede}\big)$$
      </div>
      onde $\beta_j &gt; 1$ é o parâmetro de forma de desgaste mecânico/térmico (ex.: $\beta = 2,4$ para capacitores eletrolíticos e $\beta = 1,9$ para saturação de filtros de split) e $\eta_j$ é a vida característica nominal.</li>
    <li><strong>Orquestração Financeira de Horário de Vale (<em>Off-Peak Yield Management</em>):</strong> Quando a probabilidade de falha nos próximos 30 dias ultrapassa $P_{\text{falha}}(t, t+30) \ge 35\%$, a IA envia ao morador um alerta preventivo inteligente oferecendo <strong>Manutenção Preventiva Programada em Dias de Baixa Demanda (Terça/Quarta à tarde) com 20% de Desconto na Taxa de Serviço e Extensão de Garantia de 180 Dias</strong>. Isso gera receita recorrente previsível para o profissional nos horários ociosos e evita emergências caras para o cliente!</li>
  </ul>
</div>

<!-- INOVAÇÃO #9 -->
<div class="innovation-box">
  <div class="ib-header">4.4. INOVAÇÃO #9 — Copiloto de Campo Hands-Free por Voz Contínua (Sherpa-ONNX + Function Calling) para o Profissional</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> No mundo real, o eletricista está no alto de uma escada com luvas isolantes e o encanador está sob a pia com as mãos molhadas ou sujas de vedante. Exigir que ele digite textos longos de laudo técnico, preencha planilhas de Smart Split na tela ou toque no botão de câmera reduz a adesão e atrasa o serviço.
  </p>
  <ul>
    <li><strong>Arquitetura <em>Zero-Touch Voice-to-Action</em>:</strong> O modo de execução do profissional integra o motor offline <code>sherpa_onnx</code> (modelo Zipformer/Moonshine pt-BR quantizado em <code>28 MB</code> com detector de atividade vocal Silero VAD):
      <br/>&bull; O profissional fala com as mãos livres: <em>"Copiloto Desperrengue, registra que troquei o disjuntor bipolar de 40 ampères e refiz os terminais queimados, separa R$ 160 de mão de obra e R$ 58 de peças, e bate a foto do depois em 3 segundos"</em>;
      <br/>&bull; O parser de <em>Function Calling</em> converte a fala em chamadas estruturadas: (1) preenche automaticamente o relatório técnico normativo ABNT NBR 5410; (2) popula os campos exatos de <code>labor_amount = 160.00</code> e <code>materials_amount = 58.00</code>; (3) aciona o temporizador sonoro (<code>flutter_tts</code>: <em>"Capturando foto em 3, 2, 1..."</em>) e dispara o obturador com estabilização inercial IMU!</li>
  </ul>
</div>

<!-- INOVAÇÃO #10 -->
<div class="innovation-box">
  <div class="ib-header">4.5. INOVAÇÃO #10 — Juiz Arbitral Multimodal de Disputas com Equilíbrio de Barganha de Nash em &lt; 90 Segundos</div>
  <p>
    <strong>Por que nenhuma outra Fintech/Marketplace possui:</strong> Em plataformas tradicionais, quando um cliente contesta um serviço, o valor fica congelado por semanas esperando análise humana subjetiva, gerando alto custo operacional (SAC jurídico/técnico) e insatisfação bilateral.
  </p>
  <ul>
    <li><strong>Perícia Automatizada Multimodal (RAG + Gemini 2.5 Pro 1M Context):</strong> Ao abrir uma mediação na Camada 2/3, a Edge Function <code>ai-dispute-arbitrator</code> reúne instantaneamente todas as provas criptográficas da OS: (1) Fotos do pedido inicial com Pino Focal e descrição do cliente; (2) Laudo espectral/3D inicial; (3) Par de fotos <code>Before/After</code> com score de homografia $\rho_{\text{inliers}}$ e qualidade $Q_{\text{visual}}$; (4) XML da SEFAZ dos materiais; (5) Telemetria GPS/IMU de permanência no local; (6) Histórico integral do chat e fotos do defeito pós-serviço.</li>
    <li><strong>Cálculo da Proposta de Acordo pelo Equilíbrio de Barganha de Nash Assimétrico:</strong> Com base na probabilidade pericial de responsabilidade técnica $p_{\text{resp}} \in [0, 1]$ inferida pelo modelo sobre as evidências físicas e nos artigos 18 e 20 do Código de Defesa do Consumidor (Lei nº 8.078/90), o motor maximiza o produto de utilidade líquida entre cliente ($U_C$) e profissional ($U_P$) evitando o custo de oportunidade do litígio ($d_C, d_P$):
      <div class="math-formula-box">
        $$s^* = \arg\max_{s \in [0, V_{\text{MO}}]} \big( U_C(s) - d_C \big)^{1 - p_{\text{resp}}} \cdot \big( U_P(V_{\text{MO}} - s) - d_P \big)^{p_{\text{resp}}}$$
      </div>
      Em menos de <strong>90 segundos</strong>, ambas as partes recebem no app um <strong>Laudo Pericial Preliminar Transparente</strong> propondo, por exemplo: (Opção A) Retorno Técnico Prioritário Gratuito em 6h mantendo $100\%$ do repasse; ou (Opção B) Abatimento proporcional imediato de $s^*$ com encerramento amigável instantâneo sem penalizar o score de reputação se aceito em 15 minutos!</li>
  </ul>
</div>
`;

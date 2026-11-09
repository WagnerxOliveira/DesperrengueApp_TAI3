# Documento de Contexto, Fundamentação Econômica, Lean Canvas e Norteadores Estratégicos — Desperrengue (`v2.8.1`)

> **Classificação Epistemológica:** Tratado de Economia da Informação, Modelagem Estratégica de Negócios (*Lean Canvas* — Ash Maurya), Teoria de Compatibilidade de Incentivos e Governança Institucional  
> **Referencial Teórico:** George Akerlof (*The Market for "Lemons"*, 1970) · Ash Maurya (*Running Lean*, 2012) · Lei do Inquilinato (Lei nº 8.245/1991) · Norma Técnica **ABNT NBR 5674**  
> **Implementação Auditada:** [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql) · [`20261108120000_client_kyc_biometrics_and_ocr.sql`](../supabase/migrations/20261108120000_client_kyc_biometrics_and_ocr.sql) · [`document_ocr_and_liveness_service.dart`](../app/lib/core/services/document_ocr_and_liveness_service.dart) · [`desperrengue_official_pdf_service.dart`](../app/lib/core/services/desperrengue_official_pdf_service.dart)

---

## 1. Introdução e Problema de Pesquisa (O Fenômeno de Seleção Adversa de Akerlof)

O setor brasileiro de manutenção predial e serviços residenciais caracteriza-se por elevada demanda inelástica, porém opera sob severa fricção informacional e informalidade. Em sua obra seminal *The Market for "Lemons": Quality Uncertainty and the Market Mechanism* (1970), George Akerlof demonstra que, em mercados marcados por **assimetria informacional pré-contratual**, a incapacidade de o contratante distinguir *ex ante* entre profissionais de alta qualificação técnica ($Q_{\text{alta}}$) e agentes oportunistas ou não qualificados ($Q_{\text{baixa}}$) força a convergência dos preços para uma média depreciada ($\bar{P}$), expulsando os melhores especialistas do mercado.

Nas plataformas de classificados e aplicativos de intermediação de primeira geração (baseados na venda de *leads* ou "moedas de orçamento"), verificam-se quatro falhas estruturais graves:

1. **Penalização Financeira do Trabalhador Autônomo (Venda de *Leads* sem Garantia):** Prestadores são obrigados a comprar pacotes de "moedas" antecipadamente apenas para desbloquear o contato de um cliente, sem qualquer garantia de fechamento do serviço, gerando prejuízo líquido recorrente para o trabalhador.
2. **Insegurança Física e Domiciliar do Cliente (*Ataques Sybil* e Falsidade Ideológica):** A ausência de prova de vida biométrica 3D e de validação criptográfica de documentos permite que indivíduos mal-intencionados ingressem em residências sem triagem civil confiável ou recriem perfis após execuções defeituosas.
3. **Desintermediação Induzida por Bitributação de Insumos (*Platform Leakage / Bypass*):** A cobrança de comissões lineares (`20%` a `30%`) sobre o valor bruto total do serviço — incluindo peças e materiais comprados pelo técnico — confisca a margem da mão de obra e força as partes a transacionarem fora da plataforma.
4. **Desamparo Pós-Serviço (*Risco Moral*) e Perda de Memória Técnica do Imóvel:** Pagamentos diretos sem custódia (*Escrow*) deixam o morador desprotegido contra vícios ocultos que surgem horas após a saída do técnico, além de não gerarem lastro documental padronizado segundo a norma **ABNT NBR 5674** para vistorias imobiliárias e seguradoras.

```mermaid
flowchart LR
    classDef legacy fill:#31102F,stroke:#F43F5E,stroke-width:2px,color:#FFF1F2;
    classDef desp fill:#064E3B,stroke:#10B981,stroke-width:2px,color:#ECFDF5;

    subgraph Legacy["Marketplaces de 1ª Geração (Seleção Adversa de Akerlof)"]
        L1["Cobrança por Moedas/Leads\n+ Ausência de KYC Biométrico 3D"]:::legacy --> L2["Taxa Linear sobre Peças (20%–30%)\n-> Fuga de Especialistas e Bypass"]:::legacy
        L2 --> L3["Desamparo em Vícios Ocultos\ne Zero Memória Técnica Predial"]:::legacy
    end

    subgraph Desperrengue["Arquitetura Desperrengue v2.8.1 (Solução Estrutural)"]
        D1["Zero Custo por Orçamento + KYC Ao Vivo\n(YCbCr/EAR/Yaw + Scanner ID-1 a R$ 0,00)"]:::desp --> D2["Smart Split Assimétrico\n(0% Taxa em Peças + 1,5% Carve-Out Pool)"]:::desp
        D2 --> D3["Garantia 3 Camadas (D+5 + Clawback)\n+ Passaporte ABNT NBR 5674 (SHA-256)"]:::desp
    end

    Legacy -.->|"Superação Algorítmica"| Desperrengue
```

---

## 2. A Solução Proposta e a Demonstração Matemática da Compatibilidade de Incentivos

O **Desperrengue** soluciona simultaneamente as falhas de seleção adversa, risco moral e evasão (*bypass*) por meio de uma arquitetura de **Oferta Direcionada em Cascata (*Tiered Waterfall*)**, **Custódia Condicional (*Smart Escrow*)** e **Particionamento Orçamentário Assimétrico (*Anti-Bypass Smart Split*)**.

Considere uma Ordem de Serviço cujo Volume Bruto Transacionado é decomposto na soma entre a parcela de **Mão de Obra** ($V_{\text{MO}}$) e a parcela de **Materiais/Peças comprovados por nota** ($V_{\text{Mat}}$):

$$\text{GMV}_{\text{Total}} = V_{\text{MO}} + V_{\text{Mat}}$$

Em plataformas legadas com comissão linear $\tau_{\text{legado}} = 0,20$ (`20%`) incidente indiscriminadamente sobre o valor total:

$$\text{Retenção}_{\text{legado}} = 0,20 \cdot \left(V_{\text{MO}} + V_{\text{Mat}}\right)$$

Se um reparo elétrico envolve $V_{\text{MO}} =$ `R$ 200,00` e $V_{\text{Mat}} =$ `R$ 300,00` ($\text{GMV}_{\text{Total}} =$ `R$ 500,00`), a cobrança linear confisca `R$ 100,00` — o que representa **exatos `50,0%` da remuneração pelo trabalho intelectual e operacional do técnico** (`R$ 100,00` $\div$ `R$ 200,00`).

No **Desperrengue**, a equação de retenção incide **exclusivamente sobre a mão de obra** ($\tau_{\text{App}} \in [0,12;\, 0,15]$, sendo `1,5%` segregado automaticamente via *Carve-Out* para capitalizar o Fundo de Garantia) e aplica **alíquota estrita de `0,0%` sobre materiais**:

$$\text{Retenção}_{\text{Desperrengue}} = \tau_{\text{App}} \cdot V_{\text{MO}} + 0,00 \cdot V_{\text{Mat}}$$

No mesmo exemplo ($\tau_{\text{App}} = 0,15$), a retenção total cai de `R$ 100,00` para apenas **`R$ 30,00`** (`6,0%` do GMV total, sendo `R$ 27,00` receita líquida da plataforma e `R$ 3,00` alocados ao Fundo de Garantia). Simultaneamente, permanecer dentro da plataforma entrega utilidade líquida estritamente superior ($U_{\text{InApp}}$ $>$ $U_{\text{Bypass}}$) para ambos os polos:

* **Para o Cliente:** Garantia Operacional em 3 Camadas (com retrabalho gratuito por segundo especialista em caso de falha) e emissão automática do **Passaporte Oficial de Manutenção do Imóvel (`ABNT NBR 5674`)** com assinatura criptográfica SHA-256 (`DSP-PASS-*`).
* **Para o Profissional:** Orçamentos `100%` gratuitos (zero compra de moedas), proteção contra inadimplência via *Smart Escrow*, isenção integral sobre peças (`0%`), evolução no *Relative Trust Score* ($RTS$) e liquidação via PIX instantâneo (`D+0`) nos Tiers de elite.

### 2.1. Gráfico Matemático: Confisco de Margem em Plataformas Legadas vs. *Smart Split* Desperrengue

O gráfico `xychart-beta` abaixo demonstra como o modelo tradicional destrói a margem líquida do trabalhador à medida que a proporção de peças ($V_{\text{Mat}}$) cresce em uma ordem de serviço com $V_{\text{MO}} =$ `R$ 200,00` fixos, enquanto o *Smart Split* do **Desperrengue** preserva inalterada a remuneração líquida de `R$ 170,00` (`85%` de $V_{\text{MO}}$) independentemente do valor dos materiais:

```mermaid
xychart-beta
    title "Margem Líquida da Mão de Obra do Prestador (V_MO = R$ 200) conforme Aumento do Custo de Peças (R$)"
    x-axis "Valor de Peças e Materiais na Ordem de Serviço (R$)" ["R$ 0", "R$ 100", "R$ 200", "R$ 300", "R$ 400", "R$ 500", "R$ 600"]
    y-axis "Ganho Líquido Real do Prestador sobre Mão de Obra (R$)" 0 --> 200
    line "Desperrengue Smart Split (0% Taxa em Peças -> R$ 170 Fixos)" [170, 170, 170, 170, 170, 170, 170]
    line "Apps Legados (Taxa Linear 20% sobre Total -> Colapso da Margem)" [160, 140, 120, 100, 80, 60, 40]
```

---

## 3. Lean Canvas — Arquitetura Estratégica em 9 Blocos (Ash Maurya)

A modelagem de negócios do **Desperrengue** estrutura-se nos **9 blocos canônicos do *Lean Canvas*** (Ash Maurya, *Running Lean*), integrando engenharia financeira, visão computacional *on-device* e certificação predial em um sistema autossustentável.

### 3.1. Diagrama Vetorial de Acoplamento Sistêmico dos 9 Blocos do Lean Canvas

```mermaid
flowchart TB
    classDef prob fill:#31102F,stroke:#F43F5E,stroke-width:2px,color:#FFF1F2;
    classDef seg fill:#1E1B4B,stroke:#818CF8,stroke-width:2px,color:#EEF2FF;
    classDef uvp fill:#064E3B,stroke:#10B981,stroke-width:3px,color:#ECFDF5;
    classDef sol fill:#0F172A,stroke:#38BDF8,stroke-width:2px,color:#F0F9FF;
    classDef fin fill:#422006,stroke:#F59E0B,stroke-width:2px,color:#FEF3C7;

    subgraph TOP["EIXO DE PRODUTO, MERCADO E DEFENSABILIDADE TECNOLÓGICA"]
        direction LR
        B1["<b>1. PROBLEMA</b><br/>• Venda predatória de moedas/leads<br/>• Risco domiciliar sem KYC 3D<br/>• Evasão por taxa sobre peças<br/>• Sem memória ABNT NBR 5674"]:::prob
        B4["<b>4. SOLUÇÃO</b><br/>• Waterfall O(log N+K) 1º, 2º, 3º<br/>• Liveness Frontal + Scanner ID-1<br/>• Smart Escrow + PIN 4 Dígitos<br/>• Passaporte PDF SHA-256"]:::sol
        B3["<b>3. PROPOSTA ÚNICA DE VALOR (UVP)</b><br/>• <b>Cliente:</b> Especialista auditado 3D<br/>em <60s + Garantia 3 Camadas + ABNT<br/>• <b>Prestador:</b> 0 custo por orçamento,<br/>0% taxa em peças e PIX garantido"]:::uvp
        B9["<b>9. VANTAGEM INJUSTA</b><br/>• KYC/Liveness/OCR a R$ 0,00 (Edge)<br/>• Pool 1,5% (Break-Even 67 jobs)<br/>• Grafo Zero-Linkage + dHash O(1)<br/>• Lock-in Passaporte do Imóvel"]:::sol
        B2["<b>2. SEGMENTOS DE CLIENTES</b><br/>• <b>B2C Demanda:</b> Moradores/Famílias<br/>• <b>B2C Oferta:</b> Técnicos (33 categorias)<br/>• <b>B2B:</b> Imobiliárias, Condomínios<br/>e Seguradoras Residenciais"]:::seg
    end

    subgraph MID["EIXO DE TRAÇÃO E TELEMETRIA DE CRESCIMENTO"]
        direction LR
        B8["<b>8. MÉTRICAS-CHAVE (KPIs)</b><br/>• GMV Total (V_MO vs. V_Mat)<br/>• Cobertura do Pool (ICA >= 1,5x)<br/>• SLA SOS (<60s) & Resolução Camada 1<br/>• Score RTS, LTV/CAC (9,65x) e Payback"]:::sol
        B5["<b>5. CANAIS DE DISTRIBUIÇÃO</b><br/>• Viralidade B2B/B2C do Passaporte PDF<br/>• Condomínios, Síndicos e Imobiliárias<br/>• Parcerias SENAI / CREA / CFT<br/>• Play Store, App Store e Web PWA"]:::seg
    end

    subgraph BOT["EIXO DE SUSTENTABILIDADE ECONÔMICO-FINANCEIRA (UNIT ECONOMICS)"]
        direction LR
        B7["<b>7. ESTRUTURA DE CUSTOS</b><br/>• <b>KYC/Biometria/OCR: R$ 0,00 (On-Device)</b><br/>• Cloud Supabase PostgreSQL + Resend SMTP<br/>• Gateway PIX (1,5% GMV) & CAC (R$ 42,00)<br/>• Break-Even Operacional: Mês 3 (40 jobs)"]:::fin
        B6["<b>6. FONTES DE RECEITA</b><br/>• Take Rate Assimétrico (12%–15% só em V_MO)<br/>• 0,0% sobre Peças | 1,5% Carve-Out Garantia<br/>• Prêmio de Emergência SOS (< 60s)<br/>• SaaS B2B Imobiliárias/Seguradoras + Float"]:::fin
    end

    B1 --> B4 --> B3
    B2 --> B3
    B9 --> B3
    B4 --> B8
    B3 --> B5 --> B2
    B8 --> B7
    B5 --> B6
    B7 <-->|"ROI Ano 1: +124,2% | LTV/CAC: 9,65x"| B6
```

---

### 3.2. Quadro Visual Canônico do Lean Canvas (Matriz Executiva de Largura Total)

A matriz abaixo reproduz a disposição geométrica exata do pôster oficial do **Lean Canvas** (5 colunas superiores acopladas às 2 bases financeiras inferiores), renderizada de forma 100% responsiva e sem cortes horizontais:

<table>
  <thead>
    <tr>
      <th width="20%" align="left">1. PROBLEMA</th>
      <th width="20%" align="left">4. SOLUÇÃO</th>
      <th width="20%" align="left">3. PROPOSTA ÚNICA DE VALOR (UVP)</th>
      <th width="20%" align="left">9. VANTAGEM INJUSTA</th>
      <th width="20%" align="left">2. SEGMENTOS DE CLIENTES</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2" valign="top">
        <b>Dores Críticas:</b><br/>
        • <b>Venda Predatória de Leads:</b> Técnicos pagam "moedas" antecipadas para orçar sem garantia de fechar.<br/>
        • <b>Insegurança Domiciliar:</b> Entrada de desconhecidos sem biometria 3D ou validação civil.<br/>
        • <b>Bitributação de Peças:</b> Taxas lineares (<code>20%–30%</code>) sobre materiais forçam o <i>bypass</i>.<br/>
        • <b>Vícios Ocultos e Sem Laudo:</b> Sem custódia pós-serviço nem prontuário <b>ABNT NBR 5674</b>.<br/><br/>
        <b>Alternativas Existentes:</b><br/>
        • Catálogos de venda de moedas (GetNinjas e similares);<br/>
        • Grupos informais de WhatsApp;<br/>
        • Indicações verbais sem garantia financeira ou técnica.
      </td>
      <td valign="top">
        • <b>Despacho Cego &amp; Waterfall:</b> Podagem axial <code>O(log N + K)</code> em <code>&lt; 60s</code> com mapa ordenado (<code>1º, 2º, 3º</code>).<br/>
        • <b>KYC Bilateral 3D:</b> Câmera frontal ao vivo (3 desafios físicos) + Scanner ISO ID-1 (<code>0°..270°</code>) + OCR.<br/>
        • <b>Smart Escrow + 3 Camadas:</b> Liberação por PIN de 4 dígitos, 4ª aba <i>Em Mediação</i> e retrabalho gratuito.<br/>
        • <b>Passaporte do Imóvel:</b> Laudo PDF vetorial com selo <code>SHA-256</code>.
      </td>
      <td rowspan="2" valign="top">
        <b>Para o Cliente Residencial:</b><br/>
        <i>"Especialistas verificados por biometria 3D na sua porta em menos de 60 segundos, com pagamento protegido por PIN, Garantia Real em 3 Camadas e Passaporte Oficial do Imóvel (ABNT NBR 5674)."</i><br/><br/>
        <b>Para o Profissional:</b><br/>
        <i>"Orçamentos 100% gratuitos (zero moedas), 0% de taxa sobre peças e materiais, pagamento garantido em custódia e saque PIX D+0 por mérito."</i><br/><br/>
        <b>Conceito de Alto Nível:</b><br/>
        <code>Fintech Smart Escrow + Certificadora Predial ABNT NBR 5674 para Manutenção Residencial</code>.
      </td>
      <td valign="top">
        • <b>Visão Computacional a <code>R$ 0,00</code>:</b> Liveness 3D, Scanner ID-1, Face Match 128-D e OCR executados 100% <i>on-device</i> em <i>Worker Isolates</i>.<br/>
        • <b>Blindagem de 14 Travas:</b> Guarda <code>dHash + MAD</code> 64-bit <code>O(1)</code>, Grafo <i>Zero-Linkage</i>, <i>Clawback</i> e <i>Circuit Breaker</i>.<br/>
        • <b>Autossuficiência Atuarial:</b> Retenção de <code>1,5%</code> paga 1 retrabalho integral a cada <code>67</code> ordens.<br/>
        • <b>Lock-in Patrimonial:</b> Histórico imutável do imóvel.
      </td>
      <td rowspan="2" valign="top">
        <b>Demanda (B2C):</b><br/>
        • Proprietários, locatários e famílias urbanas que necessitam de reparos urgentes ou preventivos.<br/><br/>
        <b>Oferta (Profissionais):</b><br/>
        • Eletricistas, encanadores, técnicos de HVAC, chaveiros e autônomos/MEIs nas <b>33 categorias</b>.<br/><br/>
        <b>Institucional (B2B):</b><br/>
        • Imobiliárias (vistoria Lei nº 8.245/91), condomínios e seguradoras.<br/><br/>
        <b>Early Adopters:</b><br/>
        • Técnicos certificados (NR-10/SENAI) avessos à compra de moedas e condomínios residenciais.
      </td>
    </tr>
    <tr>
      <td valign="top">
        <b>8. MÉTRICAS-CHAVE (KPIs)</b><br/><br/>
        • <b>GMV Total</b> segregado em Mão de Obra e Materiais;<br/>
        • <b>Índice de Cobertura Atuarial (ICA):</b> <code>&gt;= 1,50x</code>;<br/>
        • <b>SLA SOS:</b> <code>&lt; 60s</code> (<code>98,4%</code>);<br/>
        • <b>Resolução Camada 1:</b> <code>&gt;= 75%</code>;<br/>
        • <b>LTV / CAC:</b> <code>9,65x</code> (Payback em <code>1,2</code> pedidos).
      </td>
      <td valign="top">
        <b>5. CANAIS DE TRAÇÃO</b><br/><br/>
        • <b>Loop Viral B2B/B2C:</b> Laudos PDF do Passaporte enviados a imobiliárias e seguradoras;<br/>
        • <b>Condomínios e Síndicos:</b> Credenciamento de prestadores pré-auditados;<br/>
        • <b>Lojas &amp; Busca Local:</b> Google Play, App Store, PWA e Ads por CEP.
      </td>
    </tr>
    <tr>
      <td colspan="2" valign="top">
        <b>7. ESTRUTURA DE CUSTOS (OPEX &amp; UNIT ECONOMICS)</b><br/><br/>
        • <b>Custo Marginal de KYC, Biometria 3D e OCR: <code>R$ 0,00 / usuário</code></b> (processamento neural local na CPU/NPU do celular, economizando de <code>R$ 2,50</code> a <code>R$ 6,80</code> por validação frente a bureaus externos).<br/>
        • <b>Infraestrutura Cloud Enxuta:</b> Cluster Supabase PostgreSQL (RPCs nativas e índices GIST/GIN) + mensageria autenticada Resend SMTP (<code>R$ 140/mês</code>).<br/>
        • <b>Custos Variáveis Transacionais:</b> Liquidação PIX/Gateway (<code>1,5%</code> GMV) e tributação otimizada via Simples Nacional apenas sobre a taxa de intermediação (<code>6,0%</code> a <code>11,33%</code> s/ receita própria).<br/>
        • <b>Investimento de Aquisição:</b> <code>CAC = R$ 42,00</code> | <b>Ponto de Equilíbrio (Break-Even):</b> atingido no <b>Mês 3</b> com apenas <code>40</code> serviços/mês.
      </td>
      <td colspan="3" valign="top">
        <b>6. FONTES DE RECEITA (REVENUE STREAMS &amp; SMART SPLIT)</b><br/><br/>
        • <b>1. Take Rate Assimétrico sobre Mão de Obra (<code>12%</code> a <code>15%</code> s/ <code>V_MO</code>):</b> Incide exclusivamente sobre o serviço técnico, preservando <b>alíquota <code>0,0%</code> sobre peças e materiais (<code>V_Mat</code>)</b>. Dos <code>15,0%</code> brutos sobre a mão de obra, <code>13,5%</code> constituem Receita Líquida Operacional da plataforma e <code>1,5%</code> constituem o <i>Carve-Out</i> automático do Fundo de Garantia.<br/>
        • <b>2. Prêmio de Conveniência em Chamados SOS (<code>&lt; 60 segundos</code>):</b> Adicional de despacho imediato para emergências críticas (rompimento hidráulico, pane elétrica, chaveiro 24h).<br/>
        • <b>3. Licenciamento B2B (Passaporte ABNT NBR 5674) e Float Financeiro:</b> Assinaturas para imobiliárias/seguradoras auditarem prontuários de imóveis + rendimento de <code>100% CDI</code> sobre o saldo em custódia (<i>Smart Escrow</i> 24h e Reserva de Maturação <code>D+5 / D+7</code>).
      </td>
    </tr>
  </tbody>
</table>

---

### 3.3. Gráficos Matemáticos de Sustentação Financeira e Operacional do Lean Canvas

#### A. Decomposição Unitária de Receita e Custódia — Bloco 6 do Lean Canvas (Ordem Padrão de `R$ 500,00`)
O diagrama `pie showData` abaixo ilustra a repartição exata de uma ordem de serviço residencial de `R$ 500,00` (`R$ 300,00` de Mão de Obra + `R$ 200,00` de Peças com Nota), evidenciando que **`91,0%` (`R$ 455,00`) são repassados diretamente ao trabalhador**:

```mermaid
pie showData
    title "Alocação Financeira Smart Split de uma Ordem de R$ 500,00 (Bloco 6 do Lean Canvas)"
    "Mão de Obra Líquida do Profissional (85% de V_MO = R$ 255,00)" : 255.00
    "Reembolso Integral de Peças/Materiais (Taxa 0% = R$ 200,00)" : 200.00
    "Receita Líquida Operacional Desperrengue (13,5% de V_MO = R$ 40,50)" : 40.50
    "Carve-Out Atuarial Fundo de Garantia (1,5% de V_MO = R$ 4,50)" : 4.50
```

#### B. Curva de Tração, Receita Bruta e Saldo de Caixa Acumulado no Ano 1 — Blocos 7 e 8 do Lean Canvas
O gráfico `xychart-beta` a seguir projeta o crescimento mensal auditado (Mês 1 ao Mês 12, conforme [`docs/planilhas/fluxo_de_caixa_12m.csv`](planilhas/fluxo_de_caixa_12m.csv)), demonstrando a superação do *Break-Even* no **Mês 3**, o *Payback* integral do aporte inicial (`R$ 2.500,00`) no **Mês 6** e o fechamento do Ano 1 com **`R$ 5.605,54` de caixa livre (`ROI = +124,2%`)**:

```mermaid
xychart-beta
    title "Evolução Mensal da Receita da Plataforma vs. Saldo de Caixa Acumulado no Ano 1 (R$)"
    x-axis "Meses do Ano 1 de Operação" ["M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12"]
    y-axis "Valor Financeiro em Reais (R$)" 0 --> 6500
    bar "Receita Bruta Mensal da Plataforma (R$)" [324, 540, 864, 1188, 1620, 2052, 3024, 3780, 4536, 5292, 5796, 6300]
    line "Saldo de Caixa Acumulado (c/ Seed R$ 2.500)" [1474, 1314, 1418, 1587, 2107, 2979, 2348, 2346, 2674, 3431, 4309, 5606]
```

---

### 3.4. Dossiê Analítico Profundo dos 9 Blocos do Lean Canvas (Especificação 1 a 9)

| Nº | Bloco do Lean Canvas | Diagnóstico Estrutural e Mecanismo Algorítmico Implementado | Métricas de Validação e Rastreabilidade no Código |
| :---: | :--- | :--- | :--- |
| **01** | **Problema** | **1. Extorsão de Liquidez por Moedas:** Prestadores pagam antecipadamente por *leads* frios sem conversão garantida.<br/>**2. Vulnerabilidade Domiciliar:** Ausência de validação facial 3D e documental expõe famílias a riscos de segurança.<br/>**3. Bitributação de Materiais e *Bypass*:** Taxar peças (`20%–30%`) destrói a margem do técnico e induz ao acordo fora do app.<br/>**4. Assimetria Pós-Serviço e Depreciação Predial:** Falta de *Escrow* para vícios ocultos e ausência de laudo **ABNT NBR 5674**. | • Taxa de perda em apps de moedas: `> 65%` dos *leads* pagos não convertem.<br/>• Confisco efetivo sobre mão de obra no modelo legado: `35%` a `50%`. |
| **02** | **Segmentos de Clientes** | **1. Demanda B2C:** Proprietários, inquilinos e famílias urbanas com demanda de urgência (`SOS`) ou manutenção recorrente.<br/>**2. Oferta Técnica (33 Categorias):** Eletricistas NR-10, encanadores, técnicos de ar-condicionado, chaveiros, montadores e serralheiros.<br/>**3. Institucional B2B:** Imobiliárias (vistorias de entrada/saída sob a Lei nº 8.245/91), síndicos condominiais e seguradoras residenciais. | • Catálogo expandido de `33` categorias técnicas em [`expanded_categories_smoke.sql`](../supabase/tests/expanded_categories_smoke.sql).<br/>• Perfil unificado Multi-Modo (`client` $\leftrightarrow$ `provider`). |
| **03** | **Proposta Única de Valor (UVP)** | **Bilateral e Simétrica:**<br/>• **Ao Cliente:** Atendimento em `< 60s` por profissional com biometria 3D auditada, custódia protegida por PIN de 4 dígitos, Garantia em 3 Camadas e Passaporte Oficial do Imóvel.<br/>• **Ao Profissional:** Orçamentos `100%` gratuitos, `0%` de comissão sobre peças/materiais e liquidação PIX `D+0` por mérito ($RTS \ge 85$). | • Utilidade estrita: $U_{\text{InApp}}$ $>$ $U_{\text{Bypass}}$.<br/>• Bônus imediato de `+30 pts` no $RTS$ ao concluir o KYC biométrico. |
| **04** | **Solução** | **1. Despacho Geoespacial $O(\log N + K)$:** Podagem por *Bounding Box* + *Tiered Waterfall* (`1º, 2º, 3º`) + ditado por voz.<br/>**2. KYC e Prova de Vida *In-App*:** Câmera frontal ao vivo (3 desafios físicos $YCbCr/\text{EAR}/\text{Yaw}$) + Scanner ISO ID-1 (`0°..270°`) + OCR.<br/>**3. Custódia *Smart Escrow* e 4ª Aba *Em Mediação*:** Comparador forense triplo (`ANTES \| DEPOIS \| RECLAMAÇÃO`) + `dHash` 64 bits.<br/>**4. Certificação Predial:** Geração de PDF vetorial com selo criptográfico SHA-256 (`DSP-PASS-*`). | • [`client_setup_screen.dart`](../app/lib/features/client/presentation/client_setup_screen.dart)<br/>• [`document_ocr_and_liveness_service.dart`](../app/lib/core/services/document_ocr_and_liveness_service.dart)<br/>• [`fintech_warranty_widgets.dart`](../app/lib/features/shared/presentation/fintech_warranty_widgets.dart) |
| **05** | **Canais** | **1. Crescimento Viral pelo Produto (*Product-Led Growth*):** Cada Passaporte PDF exportado para uma imobiliária ou seguradora atua como vetor orgânico de aquisição B2B/B2C.<br/>**2. Parcerias Hiperlocais:** Credenciamento em condomínios horizontais/verticais e instituições certificadoras (SENAI / CREA / CFT).<br/>**3. Ecossistema Digital:** Google Play Store (`.aab`), Apple App Store (`.ipa`), Web PWA (`480px`) e mídia geolocalizada por CEP. | • [`desperrengue_official_pdf_service.dart`](../app/lib/core/services/desperrengue_official_pdf_service.dart)<br/>• [`PLAY_STORE.md`](PLAY_STORE.md) |
| **06** | **Fontes de Receita** | **1. *Take Rate* Assimétrico (`12%` a `15%` apenas sobre $V_{\text{MO}}$):** Taxa `0%` sobre materiais ($V_{\text{Mat}}$); dos `15%` sobre mão de obra, `13,5%` são receita líquida da plataforma e `1,5%` capitalizam o Fundo de Garantia.<br/>**2. Taxa de Urgência SOS (`< 60s`):** Prêmio de priorização imediata.<br/>**3. SaaS B2B e *Float* Financeiro:** Homologação de vistorias para imobiliárias/seguradoras e rendimento `100% CDI` sobre a custódia. | • RPC `settle_escrow_with_carveout_and_maturation` em [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql).<br/>• [`Planos de Negocio e Tributação.md`](Planos%20de%20Negocio%20e%20Tributa%C3%A7%C3%A3o.md) |
| **07** | **Estrutura de Custos** | **1. Custo Marginal Zero de KYC/Visão Computacional (`R$ 0,00`):** Execução local via ML Kit + `Isolate.run` na NPU/CPU do celular.<br/>**2. Infraestrutura Cloud de Baixo Custo Fixo:** Supabase PostgreSQL + Storage RLS + Resend SMTP (`R$ 140,00/mês` na fase inicial).<br/>**3. Eficiência Fiscal do *Smart Split*:** Tributação restrita à receita própria de intermediação (`6,0%` a `11,33%`), sem bitributar o repasse do prestador. | • Economia de `R$ 2,50` a `R$ 6,80` por cadastro frente a bureaus terceirizados.<br/>• `CAC = R$ 42,00` \| *Break-Even* no Mês 3 (`40` ordens/mês). |
| **08** | **Métricas-Chave** | **1. Financeiras e Atuariais:** $\text{GMV}_{\text{Total}}$, Fração de Mão de Obra ($V_{\text{MO}}$), Índice de Cobertura Atuarial ($\text{ICA} \ge 1,50\times$) e relação $\text{LTV}/\text{CAC} = 9,65\times$.<br/>**2. Operacionais e de Qualidade:** SLA de Despacho SOS (`< 60s`), Taxa de Resolução Amigável na Camada 1 ($\ge 75\%$) e Liquidação via PIN ($\ge 80\%$).<br/>**3. Segurança Forense:** Taxa de bloqueio de fotos repetidas/sintéticas (`dHash <= 5` ou `MAD < 4.0` = `100%`). | • Telemetria SQL auditada em [`Balanced Scorecard (BSC).md`](Balanced%20Scorecard%20(BSC).md) e [`planilhas/bsc_desperrengue.csv`](planilhas/bsc_desperrengue.csv). |
| **09** | **Vantagem Injusta (*Unfair Advantage*)** | **1. Engenharia Forense *On-Device* (`R$ 0,00`):** Pipeline proprietário de Liveness 3D, Scanner ISO ID-1 com ROI central (`80%` + núcleo `12%`) e Face Match 128-D sem dependência de APIs pagas.<br/>**2. Inviabilidade Matemática de Fraudes ($\mathbb{E}[\text{Payoff}] < 0$):** Grafo *Zero-Linkage*, Reserva `D+5`, *Clawback* e *Circuit Breaker* (`15%`).<br/>**3. Memória Patrimonial Acumulada:** O Passaporte **ABNT NBR 5674** cria *switching cost* crescente a cada serviço registrado no imóvel. | • Validado por `529` testes Dart e `577` asserções SQL em [`TESTING.md`](TESTING.md). |

---

## 4. Norteadores Estratégicos: Missão, Visão e Valores Institucionais

A governança estratégica e as decisões de arquitetura de software do **Desperrengue** são regidas por três pilares institucionais permanentes:

```mermaid
mindmap
  root(("Norteadores Estratégicos<br/>Desperrengue (v2.8.1)"))
    ("Missão Institucional")
      ("Blindar a segurança domiciliar das famílias")
      ("Custódia financeira e Garantia em 3 Camadas")
      ("Certificação técnica ABNT NBR 5674")
      ("Valorizar o autônomo: zero moedas e 0% taxa em peças")
    ("Visão de Futuro")
      ("Infraestrutura padrão de manutenção na América Latina")
      ("Erradicação do modelo predatório de venda de leads")
      ("Padrão de vistoria para imobiliárias e seguradoras")
    ("Valores Inegociáveis")
      ("1. Justiça Econômica (Smart Split Assimétrico)")
      ("2. Segurança Criptográfica e Biometria 3D")
      ("3. Solvência e Transparência Contábil (Append-Only)")
      ("4. Performance 120 FPS e Complexidade O(log N + K)")
```

* **Missão Institucional:** Democratizar e blindar a segurança na contratação de serviços residenciais no Brasil, protegendo o patrimônio das famílias por meio de custódia financeira, biometria ativa e certificação técnica (**ABNT NBR 5674**), ao mesmo tempo em que dignifica e valoriza o profissional autônomo através de relações econômicas justas, isentas de cobrança por *leads* ou taxação sobre insumos.
* **Visão de Futuro:** Consolidar-se como a infraestrutura tecnológica e financeira padrão (*de facto standard*) de manutenção predial e residencial na América Latina, reconhecida pela erradicação do modelo predatório de venda de orçamentos, pela solvência atuarial de sua Garantia de 3 Camadas e pela validade institucional do Passaporte Oficial do Imóvel perante o mercado imobiliário e securitário.
* **Valores Inegociáveis:**
  1. **Justiça Econômica e Compatibilidade de Incentivos:** O trabalhador autônomo jamais deve pagar para tentar trabalhar; a plataforma só é remunerada quando o serviço é efetivamente executado, sem jamais confiscar o reembolso de peças e materiais (`0%` de taxa).
  2. **Segurança Criptográfica e Forense em Primeiro Lugar:** Nenhum agente opera no ecossistema sem validação civil bilateral simétrica (Prova de Vida 3D ao vivo, Scanner ISO ID-1, Face Match 128-D e Módulo 11) e comprovação óptica imutável (`dHash` 64 bits e selo SHA-256).
  3. **Solvência e Transparência Contábil:** Todas as movimentações de custódia, *Carve-Out* (`1,5%`), maturação (`D+0` a `D+7`) e *Clawback* obedecem a invariantes matemáticas auditáveis em livro-razão *append-only*.
  4. **Excelência de Performance e Simplicidade de Uso:** Complexidade algorítmica sofisticada no *backend* ($O(\log N + K)$ e $O(1)$) e em *Worker Isolates* traduzida em uma experiência fluida a `120 FPS`, acessível inclusive por ditado de voz.

---

## 5. Síntese das Inovações Tecnológicas e Alinhamento com os ODS (Agenda 2030 ONU)

| Falha Estrutural do Setor | Mecanismo Computacional Implementado no Desperrengue | Referência no Código-Fonte | Alinhamento ODS (Agenda 2030 ONU) |
| :--- | :--- | :--- | :--- |
| **Falsificação de Identidade e Ataques Sybil** | Prova de Vida Facial Ao Vivo ($YCbCr + \text{EAR} + \text{Yaw}$), Scanner ISO/IEC 7810 ID-1 com ROI central (`80%`) e núcleo (`12%`), Face Match 128-D multi-orientação e `cpf_hash` único. | [`document_ocr_and_liveness_service.dart`](../app/lib/core/services/document_ocr_and_liveness_service.dart), [`20261108120000_client_kyc_biometrics_and_ocr.sql`](../supabase/migrations/20261108120000_client_kyc_biometrics_and_ocr.sql) | **ODS 16** (Paz, Justiça e Instituições Eficazes — Identidade Legal e Prevenção à Fraude) |
| **Evasão por Taxação Indevida de Peças e Venda de Leads** | *Anti-Bypass Smart Split*: `13,5%` operacional + `1,5%` *Carve-out* sobre `labor_amount_cents` e `0,0%` sobre `materials_amount_cents`, com orçamentos `100%` gratuitos. | [`fintech_warranty_models.dart`](../app/lib/core/models/fintech_warranty_models.dart), [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql) | **ODS 8** (Trabalho Decente e Crescimento Econômico — Valorização do Autônomo) |
| **Insolvência de Fundos de Garantia por Conluio** | Retenção escalonada (`D+7 / D+5 / D+2`), *Clawback* automático sobre o infrator, Grafo *Zero-Linkage* e deduplicação forense `dHash` 64-bit em $O(1)$. | [`perceptual_hash_guard.dart`](../app/lib/core/security/perceptual_hash_guard.dart), `public.trigger_layer3_rework` | **ODS 9** (Indústria, Inovação e Infraestrutura Resiliente) |
| **Perda de Histórico Técnico das Edificações** | Emissão automatizada em *Worker Isolate* do **Passaporte Oficial de Manutenção do Imóvel** em PDF vetorial segundo a **ABNT NBR 5674** e **Lei 8.245/91**. | [`desperrengue_official_pdf_service.dart`](../app/lib/core/services/desperrengue_official_pdf_service.dart) | **ODS 11** (Cidades e Comunidades Sustentáveis — Preservação do Patrimônio Edificado) |

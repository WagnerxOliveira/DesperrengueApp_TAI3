# Balanced Scorecard (BSC) e Telemetria Executiva em Tempo Real — Desperrengue (`v2.8.1`)

> **Classificação Epistemológica:** Tratado de Governança Estratégica, Gestão por Indicadores (KPIs/OKRs) e Telemetria Analítica em Banco de Dados  
> **Modelo Teórico:** Balanced Scorecard (Kaplan & Norton, 1996) estruturado em 4 Perspectivas Causais  
> **Implementação Auditada:** [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql) · [`20261108120000_client_kyc_biometrics_and_ocr.sql`](../supabase/migrations/20261108120000_client_kyc_biometrics_and_ocr.sql)

---

## 1. Taxonomia Estratégica das 4 Perspectivas do BSC (`mindmap`)

O sistema de gestão estratégica do **Desperrengue** traduz a arquitetura de engenharia de software e blindagem financeira em métricas auditáveis extraídas diretamente das tabelas transacionais do PostgreSQL (`profiles`, `jobs`, `warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations` e `kyc_submissions`).

```mermaid
mindmap
  root(("Balanced Scorecard<br/>Desperrengue (v2.8.1)"))
    ("1. Perspectiva Financeira<br/>(Solvência e Margem)")
      ("F1: Índice de Cobertura Atuarial (ICA >= 1,5x)")
      ("F2: Margem Operacional Líquida Pós-Carve-Out (13,5% V_MO)")
      ("F3: Taxa de Recuperação via Clawback (>= 85%)")
      ("F4: Relação LTV / CAC (>= 9,0x)")
    ("2. Perspectiva do Cliente e Patrimônio<br/>(Confiança e Retenção)")
      ("C1: Taxa de Resolução na Camada 1 (>= 75%)")
      ("C2: Tempo Médio de Despacho SOS (< 60s)")
      ("C3: Adoção do Passaporte ABNT NBR 5674")
      ("C4: Índice de Liquidação por PIN Presencial")
    ("3. Perspectiva de Processos Internos<br/>(Baixa Latência e Antifraude)")
      ("P1: Latência de Busca Geoespacial O(log N + K) (< 12 ms)")
      ("P2: Taxa de Bloqueio Forense dHash + MAD (100% Sintéticos)")
      ("P3: Eficácia do Grafo Zero-Linkage (0% Conluio)")
      ("P4: SLA de Mediação Assíncrona (<= 24h)")
    ("4. Perspectiva de Aprendizado e Tecnologia<br/>(Edge AI e Reputação)")
      ("A1: Custo Marginal de KYC/Liveness On-Device (R$ 0,00)")
      ("A2: Evolução Média do Score RTS da Rede (>= 78 pts)")
      ("A3: Orçamento de Quadro UI a 120 Hz (<= 8,33 ms)")
      ("A4: Cobertura Determinística de Testes (529 Dart + 577 SQL)")
```

---

## 2. Mapa Estratégico de Causa e Efeito entre as 4 Perspectivas (`flowchart BT`)

O diagrama abaixo formaliza a cadeia causal ascendente (*Bottom-Up Cause-and-Effect Chain*): a excelência algorítmica na base tecnológica (**Aprendizado e Tecnologia**) viabiliza processos internos de baixa latência e risco zero (**Processos Internos**), que geram confiança bilateral e retenção patrimonial (**Clientes**), culminando em solvência atuarial e alta rentabilidade (**Financeira**).

```mermaid
flowchart BT
    classDef learn fill:#1E1B4B,stroke:#818CF8,stroke-width:2px,color:#EEF2FF;
    classDef proc fill:#0F172A,stroke:#38BDF8,stroke-width:2px,color:#F0F9FF;
    classDef cust fill:#064E3B,stroke:#10B981,stroke-width:2px,color:#ECFDF5;
    classDef fin fill:#31102F,stroke:#F43F5E,stroke-width:2px,color:#FFF1F2;

    subgraph L4["4. PERSPECTIVA DE APRENDIZADO, CRESCIMENTO E INFRAESTRUTURA ALGORÍTMICA"]
        A1["Visão Computacional On-Device em Worker Isolates<br/>(Liveness 3D + Scanner ID-1 + Face Match 128-D a R$ 0,00)"]:::learn
        A2["Gatilho Incremental O(1) de Reputação<br/>(trg_sync_profile_trust_and_rank -> RTS 0..100)"]:::learn
    end

    subgraph L3["3. PERSPECTIVA DE PROCESSOS INTERNOS E BLINDAGEM ANTIFRAUDE"]
        P1["Podagem Axial O(log N + K) + Tiered Waterfall<br/>(Despacho Geoespacial Ordenado em < 12 ms)"]:::proc
        P2["Guarda Forense dHash 64-Bit + MAD (O(1) Bitwise)<br/>+ Grafo Zero-Linkage + Circuit Breaker 15%"]:::proc
        P3["Pipeline Especulativo de Evidências<br/>(Check-Out Percebido < 50 ms a 120 FPS)"]:::proc
    end

    subgraph L2["2. PERSPECTIVA DO CLIENTE E VALORIZAÇÃO PATRIMONIAL"]
        C1["Atendimento de Emergência SOS < 60s<br/>com Identidade Civil Bilateral Auditada"]:::cust
        C2["Garantia Operacional de 3 Camadas<br/>(SLA 24h + Retrabalho Autônomo Gratuito)"]:::cust
        C3["Emissão do Passaporte Oficial do Imóvel<br/>(ABNT NBR 5674 + Selo SHA-256)"]:::cust
    end

    subgraph L1["1. PERSPECTIVA FINANCEIRA E SOLVÊNCIA ATUARIAL"]
        F1["Erradicação do Platform Leakage<br/>(Smart Split: 0% em Peças + Liquidação PIX D+0)"]:::fin
        F2["Autossuficiência do Fundo de Garantia<br/>(Carve-Out 1,5% V_MO -> Break-Even N = 67 Jobs)"]:::fin
        F3["Maximização de LTV/CAC (9,65x)<br/>e Margem de Contribuição > 78%"]:::fin
    end

    A1 --> P2
    A1 --> F3
    A2 --> P1
    P1 --> C1
    P3 --> C1
    P2 --> C2
    C1 --> F1
    C2 --> F2
    C3 --> F3
    F1 --> F3
    F2 --> F3
```

---

## 3. Matriz Normativa de Indicadores (KPIs), Fórmulas Algébricas e Consultas SQL

Cada indicador do Balanced Scorecard possui uma equação matemática formal e é computado diretamente sobre o estado relacional do banco de dados PostgreSQL:

| ID | Indicador (KPI) | Equação Matemática Formal | Meta Operacional (Target) | Fonte Relacional / Auditoria SQL |
| :--- | :--- | :--- | :---: | :--- |
| **F1** | **Índice de Cobertura Atuarial ($\text{ICA}$)** | $\text{ICA} = \frac{\sum \text{Créditos}_{\text{CarveOut 1,5\%}} + \sum \text{Recuperações}_{\text{Clawback}}}{\sum \text{Débitos}_{\text{Rework Camada 3}}}$ | $\ge 1,50\times$ | Tabela `public.warranty_pool_ledger` (`entry_type`) |
| **F2** | **Taxa de Inadimplência de Garantia Líquida** | $\lambda_{\text{NetLoss}} = \frac{\sum \text{Débitos}_{\text{Rework}} - \sum \text{Clawback}_{\text{Pago}}}{\sum \text{GMV}_{\text{Total}}}$ | $\le 0,25\%$ | `warranty_pool_ledger` $\bowtie$ `profiles.clawback_debt_cents` |
| **F3** | **Eficiência do *Smart Split* ($\eta_{\text{Split}}$)** | $\eta_{\text{Split}} = \frac{\sum V_{\text{Mat}}}{\sum (V_{\text{MO}} + V_{\text{Mat}})}$ (fração isenta de taxa que retém o prestador) | $25\% \text{ a } 45\%$ | `public.jobs` (`labor_amount_cents`, `materials_amount_cents`) |
| **C1** | **Resolução Amigável na Camada 1 ($\text{ FCR}_{\text{Cam1}}$)** | $\text{FCR}_{\text{Cam1}} = \frac{\text{Mediações Resolvidas pelo Prestador Original}}{\text{Total de Mediações Abertas}}$ | $\ge 75,0\%$ | `public.job_mediations` (`status = 'resolved_layer1'`) |
| **C2** | **Taxa de Liquidação Expressa por PIN Presencial** | $\tau_{\text{PIN}} = \frac{\text{Jobs Liquidados via PIN 4 Dígitos}}{\text{Total de Jobs Concluídos}}$ | $\ge 80,0\%$ | `public.jobs` (`completion_pin_hash IS NOT NULL`) |
| **P1** | **Eficácia de Rejeição de Mídia Sintética / Duplicada** | $\tau_{\text{Forense}} = 1 - \frac{\text{Fotos Falsas Aprovadas}}{\text{Tentativas de Upload com } D_H \le 5 \lor \text{MAD} < 4,0}$ | **$100,0\%$** | `hamming_distance_64` + `PerceptualHashGuard` |
| **P2** | **Cumprimento do SLA de Mediação ($24\text{h}$)** | $\tau_{\text{SLA}} = \frac{\text{Mediações Decididas em } \Delta t \le 24\text{h}}{\text{Total de Mediações}}$ | **$100,0\%$** | RPC `process_autonomous_escrow_and_mediation_queues` |
| **A1** | **Custo Unitário de Validação KYC + Liveness** | $C_{\text{KYC}} = \frac{\text{Despesa com APIs Externas de Biometria/OCR}}{\text{Total de Submissões em } \texttt{kyc\_submissions}}$ | **$\text{BRL } 0,00$** | `document_ocr_and_liveness_service.dart` (*On-Device*) |
| **A2** | **Parcela da Rede em *Tiers* de Elite ($RTS \ge 70$)** | $\tau_{\text{Elite}} = \frac{\text{Prestadores com } \texttt{waterfall\_tier\_rank} \in \{1, 2, 3\}}{\text{Total de Prestadores Ativos}}$ | $\ge 65,0\%$ | `public.profiles` (`relative_trust_score`, `waterfall_tier_rank`) |

---

## 4. Blueprint Visual do Painel de Telemetria Executiva BSC

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│           PAINEL DE TELEMETRIA EXECUTIVA BSC — DESPERRENGUE FINTECH & ANTIFRAUDE             │
├──────────────────────────────────────────────┬───────────────────────────────────────────────┤
│ [1] PERSPECTIVA FINANCEIRA & ATUARIAL        │ [2] PERSPECTIVA DO CLIENTE & PATRIMÔNIO       │
│ ──────────────────────────────────────────── │ ───────────────────────────────────────────── │
│ • Índice Cobertura Pool (ICA):  2,14x [OK]   │ • SLA Despacho SOS (< 60s):     98,4% [ELITE] │
│ • Break-Even Carve-Out (1,5%):  66,7 Jobs    │ • Resolução Amigável Camada 1:  81,2% [OK]    │
│ • Disjuntor (Circuit Breaker):  FECHADO (0%) │ • Liquidação PIN 4 Dígitos:     86,5% [OK]    │
│ • Margem Líquida Pós-Pool:      13,5% V_MO   │ • Passaportes ABNT Emitidos:    Ativo SHA-256 │
├──────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ [3] PROCESSOS INTERNOS & FORENSE             │ [4] APRENDIZADO, IA & ALGORITMOS              │
│ ──────────────────────────────────────────── │ ───────────────────────────────────────────── │
│ • Latência Geoespacial (p99):   7,8 ms [OK]  │ • Custo Unitário KYC/Liveness:  R$ 0,00 [OK]  │
│ • Bloqueio dHash<=5 / MAD<4.0:  100,0% [OK]  │ • Frame Budget UI (120 Hz):     <= 8,33 ms    │
│ • Conluio Grafo Zero-Linkage:   0 Casos [OK] │ • Testes Dart Automatizados:    529 / 529 PASS│
│ • Deadlocks Transacionais (4P): 0 Casos [OK] │ • Asserções SQL Smoke Suite:    577 / 577 PASS│
└──────────────────────────────────────────────┴───────────────────────────────────────────────┘
```

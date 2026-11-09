# Engenharia de Qualidade, Verificação Formal, Testes Red Team e Auditoria Forense — Desperrengue (`v2.8.1`)

> **Classificação Epistemológica:** Tratado de Engenharia de Testes Automatizados, Verificação de Invariantes Contábeis, Simulação Adversarial (*Red Team*) e Validação de Visão Computacional  
> **Escopo Quantitativo Auditado:** `26` Suítes Dart/Flutter (`529` testes aprovados) · `9` Suítes Smoke SQL (`577` asserções relacionais) · `1` Suíte Node.js Dossiê PDF (`17` testes) · `1` Validador de Hiperlinks Markdown (`0` links quebrados)  
> **Implementação Auditada:** [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart) · [`fintech_warranty_security_test.dart`](../app/test/fintech_warranty_security_test.dart) · [`test-dossie.mjs`](../scripts/test-dossie.mjs)

---

## 1. Arquitetura da Pirâmide de Verificação Contínua (CI/CD)

A estratégia de garantia de qualidade do **Desperrengue** fundamenta-se na verificação determinística em múltiplas camadas, assegurando que nenhuma alteração em regras de negócio financeiras, algoritmos geoespaciais ou pipelines de visão computacional seja integrada à *branch* principal sem satisfazer integralmente as suítes de regressão.

```mermaid
flowchart TB
    classDef sql fill:#0F172A,stroke:#38BDF8,stroke-width:2px,color:#F8FAFC;
    classDef dart fill:#064E3B,stroke:#10B981,stroke-width:2px,color:#ECFDF5;
    classDef red fill:#31102F,stroke:#F43F5E,stroke-width:2px,color:#FFF1F2;
    classDef gate fill:#1E1B4B,stroke:#818CF8,stroke-width:2px,color:#EEF2FF;

    subgraph L1["CAMADA 1: Verificação Formal e Estrutural de Banco de Dados (577 Asserções)"]
        S1["9 Suítes SQL Smoke Tests (supabase/tests/*_smoke.sql)"]:::sql
        S2["Invariantes DDL, Constraints CHECK, Índices GIST/GIN/B-Tree e Políticas RLS"]:::sql
        S3["Gatilhos O(1) (trg_sync_profile_trust_and_rank) e RPCs SECURITY DEFINER"]:::sql
    end

    subgraph L2["CAMADA 2: Suítes Unitárias, Algorítmicas e de Interface Flutter (529 Testes em 26 Arquivos)"]
        D1["Testes de Complexidade e Serviços Core (Smart Split, Haversine, Passaporte ABNT)"]:::dart
        D2["Testes de Componentes de Interface (4ª Aba Em Mediação, Mapa 1º/2º/3º, Carteira Bipartida)"]:::dart
    end

    subgraph L3["CAMADA 3: Baterias Adversariais Red Team e Visão Computacional Forense"]
        R1["6 Testes Red Team de Blindagem Financeira (fintech_warranty_security_test.dart)"]:::red
        R2["6 Testes Forenses de Biometria, ROI dHash+MAD, OCR e Concorrência (red_team_warranty_and_kyc_forensics_test.dart)"]:::red
    end

    subgraph L4["CAMADA 4: Validação Documental e Pipeline GitHub Actions"]
        G1["flutter analyze (0 warnings/errors)"]:::gate
        G2["node scripts/test-dossie.mjs (17/17 testes PDF)"]:::gate
        G3["node scripts/check-md-links.mjs (0 links quebrados)"]:::gate
    end

    L1 --> L2 --> L3 --> L4
```

---

## 2. Especificação Analítica dos 6 Testes Adversariais *Red Team* Financeiros ([`fintech_warranty_security_test.dart`](../app/test/fintech_warranty_security_test.dart) e [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart))

As suítes [`fintech_warranty_security_test.dart`](../app/test/fintech_warranty_security_test.dart) e [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart) simulam vetores de ataque financeiro e tentativas de violação das invariantes contábeis do motor de *Smart Escrow* e Garantia de 3 Camadas:

| ID do Teste | Vetor de Ataque Simulado | Dados de Entrada e Condições de Contorno | Asserção Matemática e Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **RT-FIN-01** | **Violação de Conservação no *Smart Split* e Taxação Indevida de Materiais** | Ordem de serviço com $V_{\text{MO}} = \text{R\$ } 300,00$ ($30.000\text{ c}$), $V_{\text{Mat}} = \text{R\$ } 200,00$ ($20.000\text{ c}$), $\tau_{\text{App}} = 15\%$ e $\alpha_{\text{CarveOut}} = 1,5\%$. | Verifica que a taxa sobre materiais é exatamente $\text{R\$ } 0,00$, a comissão bruta é $\text{R\$ } 45,00$, o *Carve-Out* do Fundo é $\text{R\$ } 4,50$, a receita líquida do app é $\text{R\$ } 40,50$ e o repasse ao prestador é $\text{R\$ } 455,00$, satisfazendo $\sum \text{Partes} = \text{R\$ } 500,00$. |
| **RT-FIN-02** | **Ataque de Dupla Liquidação (*Double-Spending* / Replay de RPC)** | Execução concorrente ou repetida da liquidação sobre um mesmo `job_id` já marcado como `settled` ou `settled_pending_maturation`. | Garante idempotência estrita: a segunda chamada é rejeitada sem gerar novo crédito em `escrow_maturation_entries` nem duplicar o lançamento `carve_out_credit` em `warranty_pool_ledger`. |
| **RT-FIN-03** | **Tentativa de *Hit-and-Run* em *Cold-Start* (Saque Imediato por Conta Nova)** | Prestador recém-cadastrado ($RTS = 40 < 55$, *Tier 5*) conclui serviço e tenta sacar o saldo imediatamente via PIX (`D+0`). | O motor de maturação retém obrigatoriamente o repasse no estado `maturing` por `D+7` ($168\text{h}$). Apenas prestadores com $RTS \ge 85$ (*Tiers 1 e 2*) obtêm liberação `D+0` / `D+2`. |
| **RT-FIN-04** | **Ataque de Mídia Duplicada / Tela Sintética no Check-Out (`RN-AF-04`)** | Submissão de foto `After` idêntica ou quase idêntica à foto `Before` ($D_H \le 5$) ou imagem sintética lisa ($\text{MAD} < 4,0$). | O `PerceptualHashGuard` calcula o `dHash` de 64 bits sobre a ROI central ($80\%$) e bloqueia instantaneamente o envio quando $D_H(H_{\text{Before}}, H_{\text{After}}) \le 5$ ou $\text{MAD} < 4,0$. |
| **RT-FIN-05** | **Ataque de Conluio Triplo na Camada 3 (*Collusion Ring* $A\text{-}B\text{-}C$)** | Cliente $A$ recusa reparo de $B$ e aciona Camada 3 tentando direcionar o retrabalho para o cúmplice $C$ (que compartilha histórico prévio, `device_fingerprint` ou sub-rede IP `/24`). | O algoritmo de Despacho Cego poda $C$ via Grafo *Zero-Linkage*, atribui o chamado a um prestador independente $H$ ($RTS \ge 85$), bloqueia $B$ e inscreve $100\%$ do custo em `clawback_debt_cents`. |
| **RT-FIN-06** | **Ataque de Drenagem Massiva do Pool (*Pool Drain* / Violação do Teto Atuarial)** | Rajada de acionamentos de retrabalho cujo somatório ultrapassa $15\%$ do saldo do Fundo de Garantia em janela de $24\text{h}$ ou excede $1,20 \cdot V_{\text{MO}}$. | O teto unitário limita o débito a $\min(\text{Saldo}_{\text{Pool}}, 1,20 \cdot V_{\text{MO}})$ e o **Disjuntor Transacional (*Circuit Breaker*)** suspende novos débitos automáticos quando o dreno em $24\text{h}$ atinge $15\%$. |

---

## 3. Especificação Analítica dos 6 Testes Forenses de Biometria, Visão Computacional e Concorrência ([`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart))

A bateria forense em [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart) valida matematicamente as correções de visão computacional, criptografia de identidade e concorrência sob carga:

| ID do Teste | Domínio Algorítmico Auditado | Cenário Experimental e Vetores de Entrada | Invariante Verificada e Critério de Aprovação |
| :--- | :--- | :--- | :--- |
| **CV-KYC-01** | **Validação Algébrica de CPF (Módulo 11) e Hash Irreversível com *Pepper*** | CPFs válidos reais, CPFs com dígitos verificadores corrompidos e CPFs formados por repetições (`000.000.000-00` a `999.999.999-99`). | Rejeita $100\%$ das sequências repetidas ($\|\{\text{dígitos}\}\| = 1$) e dígitos inválidos em $O(1)$, gerando hash determinístico SHA-256 de 64 caracteres hexadecimais com `DSP-CPF-PEPPER-2026`. |
| **CV-KYC-02** | **Detecção Forense de Rosto Humano Real vs. Monitor/VS Code ($YCbCr$ + Laplaciano)** | Comparação entre matriz de pixels de código-fonte/monitor escuro (como o frame de VS Code aos `00:39` da auditoria) e retrato humano real com crominância de pele. | Rejeita deterministicamente a tela de computador ($\tau_{\text{Skin}} < 0,12$) e aprova o rosto humano real ($\tau_{\text{Skin}} \in [0,12; 0,88]$ e $\sigma^2_{\text{Laplacian}} \ge 18,0$). |
| **CV-KYC-03** | **Invariância da ROI Central ($80\%$) do `dHash + MAD` a Fundos Ruidosos** | Dois cartões sintéticos sólidos posicionados sobre fundos de madeira/mesa distintos (bordas ruidosas, centro liso) vs. documento real com linhas de texto e foto. | Com recorte de ROI central ($80\%$), o cartão sintético sobre mesa apresenta $\text{MAD}_{\text{ROI}} < 4,0$ e é **bloqueado**, enquanto o documento real apresenta $\text{MAD}_{\text{ROI}} \ge 4,0$ e $D_H(\text{Frente}, \text{Verso}) > 5$, sendo **aprovado**. |
| **CV-KYC-04** | **Extração Heurística OCR de CNH/RG (Horizontal e Vertical) e Validação Cruzada** | Textos brutos extraídos de CNH e RG contendo rótulos institucionais (`REPUBLICA FEDERATIVA`, `CARTEIRA NACIONAL`, `HABILITACAO`, `ASSINATURA`) e variações de acentuação. | Filtra todas as *stopwords* governamentais, extrai corretamente nome civil, CPF e RG/CNH e valida a similaridade de Jaccard ($\ge 0,50$) e igualdade estrita de CPF com os dados digitados. |
| **CV-KYC-05** | **Similaridade de Cosseno 128-D Não-Negativa (*Multi-Angle Face Match*)** | Vetores L2-normalizados $\vec{v} \in \mathbb{R}_{\ge 0}^{128}$ da mesma pessoa em ângulos ligeiramente distintos vs. vetores de identidades ou objetos distintos. | Confirma que $\cos(\theta) \in [0,0; 1,0]$ (sempre não-negativo), aprovando o titular legítimo ($\max \cos(\theta) \ge 0,68$) e rejeitando impostores ($\max \cos(\theta) < 0,68$). |
| **CV-KYC-06** | **Teste de Carga e Concorrência Assíncrona (50 Submissões Simultâneas)** | Disparo paralelo de $N = 50$ operações concorrentes de avaliação KYC, cálculo de `dHash` 64 bits, distância de Hamming e *Face Match* via `Future.wait`. | Zero *race conditions*, zero corrupção de estado em memória, latência média sub-milissegundo por avaliação e consistência determinística de $100\%$ dos resultados. |

---

## 4. Catálogo Completo das 26 Suítes de Teste Flutter/Dart (`529` Testes)

| # | Arquivo de Suíte em `app/test/` | Domínio Funcional Verificado | Status |
| :---: | :--- | :--- | :---: |
| **01** | [`account_screens_test.dart`](../app/test/account_screens_test.dart) | Exclusão segura de conta LGPD (`delete_own_account_scoped`), autenticação e telas de conta. | `PASS` |
| **02** | [`achievements_test.dart`](../app/test/achievements_test.dart) | Conquistas, troféus e progressão de gamificação do usuário. | `PASS` |
| **03** | [`address_and_draft_test.dart`](../app/test/address_and_draft_test.dart) | Persistência de histórico de endereços, CEP e rascunhos de chamados. | `PASS` |
| **04** | [`chat_test.dart`](../app/test/chat_test.dart) | Mensageria assíncrona em tempo real entre cliente e prestador. | `PASS` |
| **05** | [`client_flow_widgets_test.dart`](../app/test/client_flow_widgets_test.dart) | Componentes visuais da jornada do cliente e abertura de ordens de serviço. | `PASS` |
| **06** | [`client_history_test.dart`](../app/test/client_history_test.dart) | Histórico de serviços concluídos e Passaporte Oficial de Manutenção (`ABNT NBR 5674`). | `PASS` |
| **07** | [`completion_redesign_test.dart`](../app/test/completion_redesign_test.dart) | Fluxo de conclusão técnica, comprovação fotográfica `Before/After` e nota fiscal. | `PASS` |
| **08** | [`dossier_test.dart`](../app/test/dossier_test.dart) | Exportação de dossiê PDF vetorial e verificação de integridade SHA-256. | `PASS` |
| **09** | [`fintech_warranty_security_test.dart`](../app/test/fintech_warranty_security_test.dart) | **Suíte Fintech & Garantia:** 3 Camadas, *Smart Split*, Reserva `D+5`, 4ª Aba *"Em Mediação"* e PIN 4 dígitos. | `PASS` |
| **10** | [`geocode_test.dart`](../app/test/geocode_test.dart) | Geocodificação reversa e direta com tolerância a falhas. | `PASS` |
| **11** | [`geo_privacy_and_portfolio_test.dart`](../app/test/geo_privacy_and_portfolio_test.dart) | Privacidade geoespacial, raio de atuação e portfólio do profissional. | `PASS` |
| **12** | [`location_pin_test.dart`](../app/test/location_pin_test.dart) | Marcadores geoespaciais no mapa e ordenação sequencial (`1º, 2º, 3º`). | `PASS` |
| **13** | [`offboarding_boot_theme_test.dart`](../app/test/offboarding_boot_theme_test.dart) | Guardas de inicialização (`BootGate`), tema *Quiet Luxury Dark* e *offboarding*. | `PASS` |
| **14** | [`orders_and_client_achievements_test.dart`](../app/test/orders_and_client_achievements_test.dart) | Máquina de estados de pedidos do cliente e desbloqueio de conquistas. | `PASS` |
| **15** | [`precise_geocoder_test.dart`](../app/test/precise_geocoder_test.dart) | Podagem axial por *Bounding Box* $O(\log N + K)$ e distância esférica de Haversine. | `PASS` |
| **16** | [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart) | **Bateria Red Team & Forense:** Conluio triplo, *Clawback*, *Circuit Breaker*, Liveness 3D, Scanner ID-1, ROI `dHash+MAD`, Face Match 128-D e carga de 50 submissões. | `PASS` |
| **17** | [`review_rules_test.dart`](../app/test/review_rules_test.dart) | Regras de avaliação bilateral e impacto no *Relative Trust Score* ($RTS$). | `PASS` |
| **18** | [`scheduling_test.dart`](../app/test/scheduling_test.dart) | Agendamento de serviços, janelas temporais e SLAs de atendimento. | `PASS` |
| **19** | [`smart_transcript_formatter_test.dart`](../app/test/smart_transcript_formatter_test.dart) | Formatação inteligente de transcrição de voz (*Speech-to-Text*) e higienização de texto. | `PASS` |
| **20** | [`smart_triage_test.dart`](../app/test/smart_triage_test.dart) | Motor de triagem assistida e classificação semântica de urgências SOS. | `PASS` |
| **21** | [`tag_alias_parity_test.dart`](../app/test/tag_alias_parity_test.dart) | Paridade bijetiva de sinônimos e *aliases* das 33 categorias técnicas. | `PASS` |
| **22** | [`tag_match_test.dart`](../app/test/tag_match_test.dart) | Algoritmo de casamento de especialidades (`GIN` array overlap) entre chamado e prestador. | `PASS` |
| **23** | [`ui_polish_test.dart`](../app/test/ui_polish_test.dart) | Responsividade no container `480px`, animações a $120\text{ Hz}$ e ergonomia visual. | `PASS` |
| **24** | [`update_test.dart`](../app/test/update_test.dart) | Guarda de versão mínima obrigatória (`UpdateGate`) e invalidação de cache PWA. | `PASS` |
| **25** | [`user_profile_test.dart`](../app/test/user_profile_test.dart) | Sincronização de perfil unificado Multi-Modo, avatar e status KYC. | `PASS` |
| **26** | [`wallet_test.dart`](../app/test/wallet_test.dart) | Carteira digital bipartida (PIX imediato `D+0` vs. Reserva em Maturação `D+5`). | `PASS` |

---

## 5. Catálogo das 9 Suítes SQL Smoke Tests (`577` Asserções)

| # | Arquivo em `supabase/tests/` | Escopo de Verificação Relacional |
| :---: | :--- | :--- |
| **01** | [`security_smoke.sql`](../supabase/tests/security_smoke.sql) | Isolamento Row-Level Security (RLS), `warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations`, `kyc_submissions` e RPCs antifraude. |
| **02** | [`scoped_deletion_smoke.sql`](../supabase/tests/scoped_deletion_smoke.sql) | Expurgo seguro de conta do titular autenticado (`delete_own_account_scoped`) sem violação contábil. |
| **03** | [`client_wallet_smoke.sql`](../supabase/tests/client_wallet_smoke.sql) | Contabilidade de carteira, *Smart Escrow*, *Smart Split* e invariantes de saldo não-negativo. |
| **04** | [`category_match_smoke.sql`](../supabase/tests/category_match_smoke.sql) | Índices `GIN`, casamento de especialidades técnicas e podagem geoespacial $O(\log N + K)$. |
| **05** | [`expanded_categories_smoke.sql`](../supabase/tests/expanded_categories_smoke.sql) | Taxonomia completa das 33 categorias técnicas residenciais e restrições de domínio. |
| **06** | [`review_system_smoke.sql`](../supabase/tests/review_system_smoke.sql) | Sistema de avaliações, gatilho incremental $O(1)$ (`trg_sync_profile_trust_and_rank`) e cálculo de $RTS$. |
| **07** | [`achievements_smoke.sql`](../supabase/tests/achievements_smoke.sql) | Regras de concessão de conquistas, insígnias e progressão de *Tiered Waterfall* (`1..5`). |
| **08** | [`scheduled_start_smoke.sql`](../supabase/tests/scheduled_start_smoke.sql) | Ciclo de vida temporal de ordens agendadas, janelas de *check-in* e expiração de SLA. |
| **09** | [`offboarding_showcase_smoke.sql`](../supabase/tests/offboarding_showcase_smoke.sql) | Extração agregada de dados para geração de dossiê e auditoria de encerramento. |

---

## 6. Protocolo de Execução Reprodutível via Terminal

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                 RELATÓRIO CONSOLIDADO DE EXECUÇÃO DAS SUÍTES AUTOMATIZADAS                   │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│  $ cd app && flutter analyze                                                                 │
│  Analyzing app...                                                                            │
│  No issues found! (ran in 3.8s)                                                       [PASS] │
│                                                                                              │
│  $ cd app && flutter test                                                                    │
│  00:18 +529: All tests passed! (26 test suites, 529 assertions)                       [PASS] │
│                                                                                              │
│  $ node scripts/test-dossie.mjs                                                              │
│  # tests 17 | # pass 17 | # fail 0                                                    [PASS] │
│                                                                                              │
│  $ node scripts/check-md-links.mjs                                                           │
│  Checked all Markdown relative links across repository: 0 broken links.               [PASS] │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

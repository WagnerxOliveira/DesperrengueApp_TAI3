# ADR-0020: Fundo de Garantia em Três Camadas, Motor Antifraude Determinístico ($O(1)$ / $O(\log N)$) e Onboarding Biométrico com OCR Documental

* **Status:** Aceito (complementa [ADR-0006](0006-pagamento-mock-com-custodia-e-pin.md), [ADR-0007](0007-privacidade-por-minimizacao-de-dados.md) e [ADR-0018](0018-carteira-ledger-e-pix-sandbox.md))
* **Data:** 2026-11-08

## Contexto

O modelo inicial de custódia (*escrow*) liberada por PIN resolvia o risco de inadimplência imediata, mas deixava em aberto cinco desafios críticos de engenharia de sistemas distribuídos, economia de incentivos e segurança da informação:

1. **Risco de Desintermediação (*Bypass*) em Serviços com Insumos:** Quando a taxa da plataforma incide sobre o valor bruto total (incluindo peças caras adquiridas pelo prestador), a margem líquida do trabalhador é severamente comprimida, incentivando a negociação fora do aplicativo.
2. **Sustentabilidade Atuarial da Garantia Legal de 90 Dias:** Caso ocorra falha técnica após a liberação do pagamento e o prestador original abandone o reparo, a plataforma precisa acionar um segundo profissional sem drenar seu próprio caixa operacional e sem abrir brechas para ataques de conluio triplo (*Pool Siphoning*).
3. **Paradoxo de Segurança do Marco Zero (*Cold-Start*):** Em uma cidade recém-inaugurada, inexistem prestadores veteranos (Ouro/Diamante) e o fundo de reserva começa com saldo zero.
4. **Identidade Civil e Biométrica Unilateral:** Apenas o prestador passava por verificação documental, enquanto o contratante (*Cliente*) informava apenas nome e telefone declaratórios, inviabilizando a prevenção de ataques Sybil, a trava de titularidade PIX (*Same-Holder Lock*) e a emissão de laudos patrimoniais auditados (ABNT NBR 5674).
5. **Latência e Bloqueio da Thread Gráfica:** A execução de algoritmos de visão computacional (segmentação cromática, nitidez Laplaciana, hashing perceptual e OCR) e consultas geográficas trigonométricas em toda a base degradaria a fluidez da interface e a escalabilidade do banco de dados.

## Decisão

Implementou-se uma arquitetura integrada em quatro camadas (migrações `20261108110000_high_perf_warranty_antifraud_engine.sql` e `20261108120000_client_kyc_biometrics_and_ocr.sql`, serviços `WarrantyEscrowService`, `PerceptualHashGuard`, `DocumentOcrAndLivenessService`, `LiveCameraFrameBridge` e `DesperrengueOfficialPdfService`):

1. **Segregação Orçamentária (*Smart Split*):** Divisão de cada Ordem de Serviço em Carteira A (`labor_amount`, sobre a qual incidem $13,5\%$ de taxa operacional + $1,5\%$ de aporte ao Fundo de Garantia) e Carteira B (`materials_amount`, isenta de taxa — $0\%$ — mediante cupom fiscal).
2. **Fundo Autossustentável de Garantia em 3 Camadas (`RN-CAM-01` a `RN-CAM-03`):**
   - **Camada 1:** Custódia integral (`LOCKED_100`) condicionada a evidências ópticas georreferenciadas e PIN de 4 dígitos (ou liberação automática em 24h via `auto_release_at`).
   - **Camada 2:** Reserva paramétrica de $1,5\%$ sobre a mão de obra escriturada em `public.warranty_pool_ledger` ($N_{\text{equilíbrio}} = 66,67$ serviços).
   - **Camada 3:** Acionamento de retrabalho por sorteio cego no servidor (`trigger_layer3_rework`), financiado prioritariamente por *Clawback* da fila de maturação (`escrow_maturation_entries` em $D+7/D+5/D+2$) do prestador faltoso e limitado por *constraint* a $100\%$ de `labor_amount`.
3. **Resolução do Marco Zero (`RN-MZ-01` a `RN-MZ-05`):** Cálculo materializado em $O(1)$ do *Relative Trust Score* ($RTS \in [0, 100]$) e classificação automática na cascata de 5 degraus (`waterfall_tier_rank` 1 a 5) pelo trigger `trg_sync_profile_trust_and_rank()`.
4. **Visão Computacional e Biometria Facial Ativa no Onboarding (`ClientSetupScreen`):**
   - Validação aritmética de CPF por Módulo 11 em $O(1)$ (`is_valid_cpf`).
   - Câmera frontal ao vivo renderizada no interior do `ClipOval` com amostragem a cada $140\text{ ms}$, segmentação de pele humana em espaço $YCbCr$, filtro anti-monitor (`blueMonitorRatio < 0.25`) e 3 desafios biomecânicos reais.
   - Scanner documental guiado na proporção **ISO/IEC 7810 ID-1** (`DocumentGuidedScannerModal`) com recorte estrito da Região de Interesse (*Core ROI Inset* de $12\%$), distinção entre Frente e Verso por `dHash` ($9\times 8$) combinado com $\text{MAD}_{64\times 64}$ e variância inter-quadrantes, aferição de nitidez Laplaciana ($\sigma_{\text{Lap}}^2 \ge 110,0$), *Face Match* multi-orientação ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em espaço 128-D não-negativo ($S_{\cos} \ge 0,78$) e transcrição automática via OCR.
5. **Engenharia de Baixa Latência e Prevenção de *Deadlocks*:**
   - Processamento de imagem e geração de PDFs `%PDF-1.4` executados fora da thread principal via `Isolate.run`.
   - Podagem espacial por *Axial Bounding Box* ($\Delta\text{lat}, \Delta\text{lng}$) sobre o índice `idx_profiles_rescue_waterfall_bbox` antes da fórmula de Haversine, reduzindo o despacho de $O(N \log N)$ para $O(\log N + K)$.
   - Ordem Canônica Estrita de Bloqueios Pessimistas (`1º jobs` $\rightarrow$ `2º job_mediations` $\rightarrow$ `3º escrow_maturation_entries` $\rightarrow$ `4º profiles`) e fila assíncrona com `FOR UPDATE SKIP LOCKED LIMIT 100`.

## Alternativas Avaliadas

* **APIs Comerciais Externas de KYC e Liveness (idwall, Facetec, Unico):** Descartadas para o estágio atual devido ao custo variável elevado por validação (R$ 2,50 a R$ 8,00 por onboarding), que inviabilizaria a operação *Lean* de custo zero. Optou-se por implementar o motor óptico determinístico em Dart puro executado em *Worker Isolates* locais.
* **Cálculo Dinâmico de $RTS$ e Haversine em Tempo de Leitura sobre Toda a Tabela:** Descartado por exibir complexidade $O(N \cdot H)$ e degradar sob concorrência; substituído por materialização via trigger em $O(1)$ e podagem por *Bounding Box* em $O(\log N + K)$.

## Consequências

* **Positivas:** Blindagem matemática contra os 6 vetores de fraude; neutralização de falsos positivos de duplicidade documental na mesma mesa; similaridade facial estritamente contida em $[0\%, 100\%]$; compartilhamento automático do selo biométrico (+30 pts $RTS$) quando o cliente atua também como profissional.
* **Negativas / Trade-offs:** Maior complexidade algorítmica nos serviços de visão computacional e nas RPCs transacionais, mitigada por cobertura exaustiva de testes automatizados (`red_team_warranty_and_kyc_forensics_test.dart` e `fintech_warranty_security_test.dart`).

## Verificação

* `flutter analyze` com `0` avisos.
* `flutter test` com `529/529` testes aprovados, incluindo a suíte `app/test/red_team_warranty_and_kyc_forensics_test.dart` e `app/test/fintech_warranty_security_test.dart`.

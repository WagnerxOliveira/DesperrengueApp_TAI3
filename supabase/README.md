# Supabase Backend — Núcleo Relacional, Custódia em 3 Camadas e Motor Antifraude (PostgreSQL 17)

Projeto Gerenciado: **Desperrengue** (`eisfkemgooqbgqljvwvs`, região `sa-east-1`, PostgreSQL 17).

Toda a lógica financeira, as invariantes contábeis do Fundo de Garantia em 3 Camadas (`RN-CAM-01` a `RN-CAM-03`), a mitigação determinística dos 6 vetores de fraude (`RN-AF-01` a `RN-AF-14`), a resolução do paradoxo do Marco Zero (`RN-MZ-01` a `RN-MZ-05`) e a homologação biométrica/OCR (`submit_client_kyc`) são impostas diretamente no banco de dados mediante políticas **RLS (*Row Level Security*)**, restrições `CHECK`, *triggers* de complexidade $O(1)$ e funções **`SECURITY DEFINER`** ([ADR-0003](../docs/adr/0003-regras-de-negocio-no-banco-via-rpc.md) e [ADR-0020](../docs/adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md)).

---

## 1. Modelo Relacional e Estruturas de Dados (21 Migrações)

Uma mesma conta em `public.profiles` pode operar como **Cliente** (`is_client`) e como **Profissional** (`is_provider`), compartilhando a identidade civil e biométrica auditada.

| Tabela / Objeto | Responsabilidade Arquitetural e Invariantes de Segurança |
| :--- | :--- |
| `profiles` | Perfil unificado do usuário. Contém flags de modo (`is_client`, `is_provider`), identidade civil/biométrica auditada (`cpf_hash` único, `cpf_masked`, `verified_full_name`, `liveness_verified`, `liveness_score`, `face_liveness_hash`, `ocr_verified`, `kyc_biometric_verified`, `pix_key_cpf_matched`), variáveis de confiança do Marco Zero (`trust_tier`, `is_trusted_anchor`, `external_trust_score` $RTS \in [0,100]$, `waterfall_tier_rank` $1..5$, `completed_jobs_count`, `abandoned_warranty_count`), disjuntor de risco (`has_open_dispute`) e saldos da carteira bipartida do prestador (`available_wallet_balance`, `maturing_wallet_balance`, `clawback_debt_balance`). |
| `provider_profiles` | Dados operacionais do prestador: título, especialidades normalizadas, valor/hora, taxa de visita, raio de atendimento, média Bayesiana (`rating_avg`, `rating_count`) e `jobs_done` (protegidos por trigger). |
| `kyc_submissions` | Registro forense imutável de validações documentais e biométricas (`role_scope` $\in \{\text{'client'}, \text{'provider'}, \text{'both'}\}$, `document_type`, `doc_front_phash`, `doc_back_phash`, `selfie_liveness_phash`, `liveness_challenges_passed`, `ocr_extracted_payload`, `laplacian_sharpness_score`, `glare_ratio_pct`, `face_match_cosine_similarity`). |
| `jobs` | Ordem de Serviço. Contém segregação contábil *Smart Split* (`labor_amount`, `materials_amount`), estado da custódia (`escrow_status`), hash do PIN (`checkout_pin_hash`), gatilho de liberação automática (`auto_release_at`), vigência da garantia de 90 dias (`warranty_expires_at`), assinaturas visuais `pHash` de 64 bits (`checkin_photo_phash`, `checkout_photo_phash`), distâncias Haversine (`checkin_gps_distance_m`, `checkout_gps_distance_m`) e rastreabilidade de retrabalho de Camada 3 (`is_warranty_rework`, `parent_job_id`, `original_faulty_provider_id`). |
| `warranty_pool_ledger` | **Livro-razão imutável (*Append-Only*) do Fundo de Garantia (Camadas 2 e 3).** Registra `CARVEOUT_CONTRIBUTION_1_5_PCT`, `REWORK_PAYOUT_DEBIT`, `CLAWBACK_RECOVERY_CREDIT` e `COLD_START_SEED_RESERVE`. Blindado pelas restrições `chk_invariant_1_coverage_cap` ($\text{amount} \le \text{labor\_reference\_cap}$) e `chk_invariant_2_identity_disjunction` ($\text{rescuer} \ne \text{original} \land \text{rescuer} \ne \text{client}$). |
| `escrow_maturation_entries` | **Fila de maturação progressiva de repasses ($D+7 / D+5 / D+2$).** Segrega `gross_labor_amount`, `materials_reimbursement_amount` ($0\%$ taxa), `platform_operational_fee` ($13,5\%$), `warranty_carveout_fee` ($1,5\%$) e `net_provider_amount`, transitando entre `MATURING`, `FROZEN_BY_DISPUTE`, `AVAILABLE_FOR_PIX` e `CLAWED_BACK`. |
| `job_mediations` | **Máquina de estados determinística de 5 fases da aba *"Em Mediação"*.** Controla `PHASE_1_OPENED_AND_FROZEN` a `PHASE_5_SETTLED_AND_CERTIFIED`, categoria da reclamação, `defect_photo_phash`, distância GPS, `original_provider_deadline_at` (SLA de 6 horas) e desfecho (`resolution_outcome`). |
| `forensic_certificates` | Certificados digitais de garantia e prontuário do imóvel (`certificate_code`, `sha256_integrity_seal`, `checkin_phash`, `checkout_phash`, `warranty_until`). |
| `client_wallets` · `ledger_txns` · `ledger_lines` · `wallet_statement` · `pix_topups` | Carteira do cliente em centavos inteiros (`bigint`), livro-razão de partida dobrada com soma zero e recarga Pix idempotente ([ADR-0018](../docs/adr/0018-carteira-ledger-e-pix-sandbox.md)). |
| `job_addresses` · `job_geo` · `job_secrets` | Isolamento de endereço completo, coordenadas confirmadas por pino/geocodificação ([ADR-0019](../docs/adr/0019-agendamento-geofence-chat-dossies.md)) e PIN secreto de 4 dígitos ([ADR-0007](../docs/adr/0007-privacidade-por-minimizacao-de-dados.md)). |
| `quotes` · `job_invites` · `job_evidence` · `reviews` · `messages` · `provider_achievements` | Orçamentos (máx. 3), convites com expiração automática, evidências fotográficas, avaliações cegas (48h), chat idempotente e 90 conquistas escalonadas. |

---

## 2. Funções Matemáticas Puras $O(1)$, Triggers Materializados e RPCs `SECURITY DEFINER`

### 2.1. Funções Imutáveis de Complexidade Constante $O(1)$
- `public.hamming_distance_64(hash_a BIGINT, hash_b BIGINT) RETURNS INTEGER`: Calcula a distância de Hamming entre dois hashes perceptuais de 64 bits via operador `XOR` (`#`) e laço de Brian Kernighan (`x := x & (x - 1)`).
- `public.calculate_relative_trust_score(...) RETURNS NUMERIC(5,2)`: Calcula o *Relative Trust Score* ($RTS \in [0, 100]$) combinando KYC biométrico ($+30$), maturidade MEI $\ge 6\text{ meses}$ ($+20$), certificação técnica ($+20$), histórico inicial ($\min(6N, 30)$) e penalidade por abandono ($-50$ por ocorrência).
- `public.is_valid_cpf(p_cpf TEXT) RETURNS BOOLEAN`: Valida aritméticamente os dois dígitos verificadores do CPF pelo algoritmo oficial de Módulo 11 e rejeita sequências repetidas em $O(1)$.
- `public.trg_sync_profile_trust_and_rank()`: Trigger `BEFORE INSERT OR UPDATE` em `public.profiles` que materializa instantaneamente `external_trust_score` e `waterfall_tier_rank` ($1$ a $5$), garantindo leitura em $O(1)$.

### 2.2. Procedimentos Remotos Transacionais (`SECURITY DEFINER`)

| Função RPC | Papel que Invoca | Semântica Transacional, Guardas e Ordem de Bloqueios |
| :--- | :--- | :--- |
| `submit_client_kyc(...)` | Cliente autenticado | Valida CPF Mod-11 (`ERR_INVALID_CPF_MOD11`), gera `cpf_hash` (`SHA-256` com *pepper*) e máscara LGPD, verifica unicidade Anti-Sybil (`ERR_DUPLICATE_CPF_IDENTITY`), valida distância de Hamming entre Frente e Verso (`ERR_DUPLICATE_FRONT_BACK_PHOTO`), nitidez Laplaciana $\ge 110,0$ (`ERR_BLURRY_DOCUMENT_IMAGE`), reflexo $\le 8,5\%$ (`ERR_EXCESSIVE_GLARE`), prova de vida $\ge 85\%$ (`ERR_LIVENESS_FAILED`) e *Face Match* $\ge 0,78$ (`ERR_FACE_MISMATCH`). Atualiza `profiles` e compartilha `kyc_biometric_verified = TRUE` (+30 pts $RTS$). |
| `complete_job_and_schedule_escrow(...)` | Prestador contratado | Adquire lock `1. jobs`. Verifica geofence ($\le 150\text{ m}$ — `ERR_GEOFENCE_VIOLATION`) e `hamming_distance_64(checkin_photo_phash, p_checkout_phash) >= 5` (`ERR_DUPLICATE_FORENSIC_PHOTO`). Se o PIN de 4 dígitos for informado e válido, conclui o serviço e invoca `settle_escrow_with_carveout_and_maturation`; caso contrário, agenda `auto_release_at = NOW() + INTERVAL '24 hours'`. |
| `settle_escrow_with_carveout_and_maturation(p_job_id)` | Interna / Servidor | Adquire locks `1. jobs -> 4. profiles`. Calcula $13,5\%$ operacional e $1,5\%$ Fundo de Garantia exclusivamente sobre `labor_amount` ($0\%$ sobre `materials_amount`), abate eventual dívida de *Clawback* (`CLAWBACK_RECOVERY_CREDIT`), aporta $1,5\%$ em `warranty_pool_ledger` (`CARVEOUT_CONTRIBUTION_1_5_PCT`) e insere registro em `escrow_maturation_entries` com janela $D+2$ (Âncora), $D+5$ (Padrão) ou $D+7$ (Trainee). |
| `open_warranty_mediation(...)` | Cliente titular | Adquire locks `1. jobs -> 2. job_mediations -> 3. escrow_maturation_entries -> 4. profiles`. Verifica vigência de 90 dias, geofence ($\le 150\text{ m}$) e não-reciclagem das fotos de Antes/Depois (`hamming_distance_64 >= 5`). Congela o repasse (`FROZEN_BY_DISPUTE`), abre o SLA de 6 horas do prestador original e ativa o *Circuit Breaker* (`has_open_dispute = TRUE`). |
| `trigger_layer3_rework(...)` | Cliente / Worker | Verifica chave de idempotência. Adquire locks na **Ordem Canônica (`1. jobs -> 2. job_mediations -> 3. escrow_maturation_entries -> 4. profiles`)**. Verifica teto de $100\%$ de `labor_amount` (`ERR_COVERAGE_CAP_EXCEEDED`). Executa busca em cascata de 5 degraus com podagem por *Axial Bounding Box* ($O(\log N + K)$), disjunção tripla (`device_fingerprint_hash`, `cpf_hash`, `face_liveness_hash`), Grafo Zero-Link e *cooldown* de 24h. Executa *Clawback* prioritário, incrementa `abandoned_warranty_count`, cria a nova OS de retrabalho e escritura o débito em `warranty_pool_ledger`. |
| `process_autonomous_escrow_and_mediation_queues()` | Worker `pg_cron` | Processa em lotes não-bloqueantes (`FOR UPDATE SKIP LOCKED LIMIT 100`) a liberação automática de serviços após 24h (`auto_release_at <= NOW()`) e a conversão de saldos maturados (`available_at <= NOW()`) para saldo livre PIX (`AVAILABLE_FOR_PIX`). |
| Demais RPCs do Ciclo Operacional | Cliente / Prestador / Admin | `enroll_mode`, `complete_setup`, `submit_kyc`, `activate_provider`, `invite_providers`, `accept_quote`, `pay_job_mock`, `start_job`, `complete_job_with_pin`, `submit_review`, `my_client_wallet`, `create_topup`, `confirm_topup`, `account_deletion_status`, `purge_account`. |

---

## 3. Índices de Alta Seletividade e Podagem Espacial

| Índice | Definição e Complexidade Assintótica |
| :--- | :--- |
| `idx_profiles_rescue_waterfall_bbox` | `ON public.profiles (waterfall_tier_rank ASC, last_latitude, last_longitude) WHERE is_provider = TRUE AND has_open_dispute = FALSE AND trust_tier <> 'SUSPENDED'` — Viabiliza podagem espacial em $O(\log N + K)$ antes do cálculo trigonométrico de Haversine. |
| `idx_profiles_cpf_hash_unique` | `UNIQUE ON public.profiles (cpf_hash) WHERE cpf_hash IS NOT NULL` — Prevenção determinística de ataques Sybil em $O(1)$. |
| `idx_profiles_face_liveness_hash` | `ON public.profiles (face_liveness_hash) WHERE face_liveness_hash IS NOT NULL` — Rastreabilidade de unicidade biométrica em $O(1)$. |
| `idx_jobs_auto_release_queue` | `ON public.jobs (auto_release_at ASC) WHERE status = 'awaiting_approval' AND escrow_status = 'LOCKED_100'` — Varredura de fila autônoma em $O(B \log S)$. |
| `idx_escrow_maturation_queue` | `ON public.escrow_maturation_entries (available_at ASC) WHERE maturation_status = 'MATURING'` — Liquidação de maturação em $O(B \log S)$. |
| `idx_mediations_sla_6h_queue` | `ON public.job_mediations (original_provider_deadline_at ASC) WHERE current_phase IN (...)` — Monitoramento de expiração do SLA de 6 horas. |

---

## 4. Aplicação de Migrações e Execução dos Testes SQL

```bash
# Aplicar migração específica via Management API do Supabase CLI
supabase db query --linked -f supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql
supabase db query --linked -f supabase/migrations/20261108120000_client_kyc_biometrics_and_ocr.sql

# Executar baterias transacionais de fumaça (sempre abortadas ao final com ROLLBACK; critério: FALHAS=0)
supabase db query --linked -f supabase/tests/security_smoke.sql
supabase db query --linked -f supabase/tests/client_wallet_smoke.sql
supabase db query --linked -f supabase/tests/scheduled_start_smoke.sql
supabase db query --linked -f supabase/tests/scoped_deletion_smoke.sql
```

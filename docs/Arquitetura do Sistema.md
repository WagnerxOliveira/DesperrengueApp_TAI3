# Arquitetura do Sistema — Desperrengue (`v2.8.1`)

Documento de especificação arquitetural do sistema **Desperrengue**, estruturado segundo o modelo **C4** (Contexto, Contêineres, Componentes e Código/Dados) e alinhado à versão de produção `v2.8.1+202611082`.

> Para a especificação matemática do motor de Garantia em 3 Camadas, análise assintótica *Big-O* e pipeline de Visão Computacional, consulta-se [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) e o [`ADR-0020`](adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md).

---

## 1. Visão Geral e Matriz Tecnológica

O **Desperrengue** é uma plataforma *multi-sided* de contratação de serviços residenciais imediatos e agendados com **Fundo de Garantia Auto-Sustentável em 3 Camadas**, **Smart Split Anti-Bypass (15% mão de obra / 0% peças com NF)**, **Biometria Facial Ao Vivo + Scanner Documental ISO ID-1** e **Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674)**.

| Camada | Tecnologia Adotada | Papel Arquitetural no Ecossistema |
| :--- | :--- | :--- |
| **Cliente Mobile & Web (PWA)** | Flutter `3.47.x` (Dart `>=3.4.0 <4.0.0`), Material 3 | Base de código unificada para Android (APK/AAB) e Web (PWA em GitHub Pages com trava responsiva `480px`). |
| **Gerenciamento de Estado** | `flutter_riverpod` (`^2.5.1`) | Injeção de dependências determinística, *streams* reativos e isolamento de testes de widgets. |
| **Visão Computacional & Isolates** | `Isolate.run`, `camera`, `image_picker`, `PerceptualHashGuard`, `DocumentOcrAndLivenessService` | Execução paralela em memória isolada de `dHash` 64-bit, `MAD` $64\times 64$, Laplaciano, segmentação de pele $YCbCr$, Face Match 128-D multi-ângulo e OCR documental. |
| **Autenticação** | Supabase Auth (GoTrue) | Fluxo OAuth2/PKCE, confirmação de e-mail, recuperação de senha e emissão de JWTs assinados. |
| **Banco de Dados & Motor Contábil** | PostgreSQL 17 (Supabase) — **21 migrações SQL** | Persistência relacional com *Row Level Security* (RLS), *Append-Only Ledgers*, funções `SECURITY DEFINER` e ordenação canônica de bloqueios. |
| **Armazenamento de Objetos** | Supabase Storage (`job-photos`, `avatars`, `pro-verifications`, `forensic-evidence`) | Buckets segregados com políticas RLS por prefixo `auth.uid()` e URLs assinadas temporárias para dossiês KYC e forenses. |
| **Motor Documental PDF** | `PropertyMaintenancePassportPdf` (`%PDF-1.4` nativo) | Geração vetorial determinística em memória de certificados ABNT NBR 5674 e Lei do Inquilinato (Lei 8.245/91). |
| **Qualidade & CI/CD** | GitHub Actions (`ci.yml`, `pages-pwa.yml`, `release-apk.yml`, `supabase-migrate.yml`) | Execução automatizada de **529 testes Flutter**, **577 asserções SQL**, **17 testes de PDF** e verificação de links Markdown. |

---

## 2. Diagrama de Contexto (C4 — Nível 1)

```mermaid
flowchart LR
    Cliente["👤 Usuário Cliente\n(Solicita serviços, valida KYC/Biometria,\naprova via PIN de 4 dígitos e emite Passaporte)"]
    Profissional["🛠️ Usuário Profissional / Socorrista\n(Executa serviços, envia checklist Antes/Depois,\nrecebe via Smart Split e atua na Camada 3)"]
    Desperrengue["📱 Ecossistema Desperrengue\n(App Flutter + Worker Isolates +\nMotor Contábil & Antifraude Supabase)"]
    ViaCEP["📮 API ViaCEP\n(Enriquecimento de CEP)"]
    Nominatim["🗺️ OpenStreetMap / Nominatim\n(Geocodificação Reversa)"]

    Cliente -->|"HTTPS / WSS"| Desperrengue
    Profissional -->|"HTTPS / WSS"| Desperrengue
    Desperrengue -->|"REST JSON"| ViaCEP
    Desperrengue -->|"REST JSON"| Nominatim
```

---

## 3. Diagrama de Contêineres e Componentes (C4 — Níveis 2 e 3)

```mermaid
flowchart TB
    subgraph ClientApp["Aplicação Cliente (Flutter 3.47 — Android & PWA)"]
        UI["Camada Presentation\n- ClientSetupScreen (KYC 4 Etapas)\n- ClientHomeScreen & ProHomeScreen (4 Abas)\n- JobMediationTab & Pin4Modal\n- PropertyPassportInteractiveView"]
        CV["Camada Worker Isolates (Paralelismo)\n- PerceptualHashGuard (dHash 64-bit + EXIF)\n- DocumentOcrAndLivenessService (YCbCr + Face Match 128-D)\n- PropertyMaintenancePassportPdf (%PDF-1.4)"]
        Pipe["Camada de Serviços & Resiliência\n- SpeculativeEvidencePipeline (GPS 30s + Upload)\n- OfflineOutbox & TelemetryService"]
    end

    subgraph Backend["Plataforma Backend (Supabase / PostgreSQL 17)"]
        GoTrue["Supabase Auth\n(JWT + PKCE)"]
        PostgREST["PostgREST + RPCs SECURITY DEFINER\n- lock_escrow_with_smart_split\n- open_job_mediation_claim\n- respond_to_job_mediation\n- resolve_mediation_and_trigger_layer3\n- submit_client_kyc_biometrics_and_ocr"]
        PG[("PostgreSQL 17\n- profiles (RTS + waterfall_tier_rank)\n- jobs & job_mediations\n- escrow_maturation_entries\n- warranty_pool_ledger\n- forensic_certificates")]
        Buckets[("Supabase Storage\n- job-photos (público)\n- avatars (público)\n- pro-verifications (privado)\n- forensic-evidence (privado)")]
    end

    UI --> CV
    UI --> Pipe
    Pipe --> GoTrue
    Pipe --> PostgREST
    Pipe --> Buckets
    PostgREST --> PG
```

---

## 4. Modelo Entidade-Relacionamento Completo (`v2.8.1`)

O esquema relacional consolida **21 migrações versionadas** em [`supabase/migrations/`](../supabase/migrations/), abrangendo o ciclo de vida operacional, o motor contábil de garantia em 3 camadas, a custódia forense e o KYC biométrico unificado:

```mermaid
erDiagram
    PROFILES ||--o{ JOBS : "client_id / professional_id"
    PROFILES ||--o{ PROPOSALS : "professional_id"
    PROFILES ||--o{ FAVORITES : "client_id / professional_id"
    PROFILES ||--o{ PROFESSIONAL_AVAILABILITY : "professional_id"
    PROFILES ||--o{ FORENSIC_CERTIFICATES : "uploader_id"
    JOBS ||--o{ PROPOSALS : "job_id"
    JOBS ||--o{ MESSAGES : "job_id"
    JOBS ||--o| REVIEWS : "job_id (1:1)"
    JOBS ||--o{ ESCROW_MATURATION_ENTRIES : "job_id"
    JOBS ||--o{ WARRANTY_POOL_LEDGER : "job_id"
    JOBS ||--o{ JOB_MEDIATIONS : "job_id"
    JOBS ||--o{ FORENSIC_CERTIFICATES : "job_id"
    JOB_MEDIATIONS ||--o{ WARRANTY_POOL_LEDGER : "mediation_id"

    PROFILES {
        uuid id PK
        text role "client | professional"
        text full_name
        text cpf_hash UK "SHA-256 Anti-Sybil"
        text face_liveness_hash UK "Biometria 128-D Hash"
        boolean client_kyc_verified
        text verification_status "unverified..verified"
        numeric relative_trust_score "RTS [0..100] O(1)"
        smallint waterfall_tier_rank "Tier [1..5] O(1)"
        numeric pending_maturation_balance "Saldo D+5/D+7/D+2"
        numeric technical_debt_balance "Divida Camada 3"
    }

    JOBS {
        uuid id PK
        uuid client_id FK
        uuid professional_id FK
        text status "open | in_progress | in_mediation | completed | cancelled"
        numeric labor_amount "Taxa 15% (13.5% op + 1.5% pool)"
        numeric materials_amount "Taxa 0% c/ NF (<= 60% total)"
        timestamptz warranty_layer1_expires_at
        timestamptz warranty_layer2_expires_at
    }

    ESCROW_MATURATION_ENTRIES {
        uuid id PK
        uuid job_id FK
        uuid professional_id FK
        numeric net_professional_amount
        text status "locked_in_maturation | frozen_mediation | released | diverted_to_layer3"
        timestamptz matures_at
    }

    WARRANTY_POOL_LEDGER {
        uuid id PK
        text entry_type "seed_reserve | carveout_credit_1_5pct | layer3_claim_debit | debt_recovery_credit"
        numeric signed_amount
        uuid job_id FK
        uuid mediation_id FK
        text idempotency_key UK
    }

    JOB_MEDIATIONS {
        uuid id PK
        uuid job_id FK
        text phase "evidence_submitted | awaiting_pro_response | repair_scheduled | resolved_by_pro | sla_breached | layer3_rescuer_dispatched"
        smallint active_warranty_layer "1 | 2 | 3"
        timestamptz sla_deadline_at "SLA 4 horas"
        uuid rescuer_professional_id FK
    }

    FORENSIC_CERTIFICATES {
        uuid id PK
        uuid job_id FK
        text sha256_hash
        bigint perceptual_hash_64 "dHash 64-bit O(1)"
        boolean exif_tamper_detected
    }
```

---

## 5. Governança de Segurança, Desempenho e Conformidade Legal

1. **Unificação Cadastral Multi-Modo**: Como `client` e `professional` compartilham a mesma linha em `public.profiles` (`id = auth.uid()`), a aprovação no onboarding biométrico do cliente (`client_kyc_verified = true`, `cpf_hash` e `face_liveness_hash`) propaga automaticamente $+30\text{ pontos}$ para o $RTS$ ao alternar para o modo Profissional.
2. **Exclusão Escopada LGPD (`delete_own_account_scoped`)**: Implementada na migração [`20261107100000_scoped_account_deletion.sql`](../supabase/migrations/20261107100000_scoped_account_deletion.sql), permite a revogação granular de um papel (`client` ou `professional`) com anonimização de PII ou a purga integral da conta quando se trata do último papel ativo.
3. **Passaporte Oficial de Manutenção do Imóvel**: Em conformidade com a **ABNT NBR 5674** e a **Lei Federal nº 8.245/91**, sintetiza apenas ordens de serviço reais e auditadas em documento vetorial `%PDF-1.4` com selos SHA-256, sem qualquer injeção de dados fictícios.

# Roadmap de Engenharia — Evolução do Sistema Desperrengue (`v2.8.1`)

Este documento registra a evolução das fases de engenharia do projeto **Desperrengue**, detalhando os épicos concluídos em produção e as frentes de expansão futura.

---

## 1. Resumo Executivo de Progresso

| Fase / Épico | Escopo Arquitetural | Status Atual |
| :--- | :--- | :---: |
| **Fase 1 (`E-01` a `E-04`)** | Fundação Full-Stack, 21 Migrações SQL, RLS Estrito, CI/CD, PWA e APK Beta Automatizado | ✅ **100% Concluído** |
| **Fase 2 (`E-05a` a `E-05e`)** | Catálogo de 33 Categorias, Propostas Dinâmicas, Agenda Semanal, Chat em Tempo Real e Exclusão Escopada LGPD | ✅ **100% Concluído** |
| **Fase 3 (`E-05f`)** | **Fundo de Garantia em 3 Camadas (`RN-CAM-01..03`)**, **Smart Split Anti-Bypass**, **Motor Antifraude (`RN-AF-01..14`)**, **Marco Zero (`RN-MZ-01..05`)** e **Passaporte do Imóvel (ABNT NBR 5674)** | ✅ **100% Concluído (`v2.8.0`)** |
| **Fase 4 (`E-05g`)** | **Câmera Frontal Ao Vivo (`ClipOval` $YCbCr$)**, **Scanner Guiado ISO ID-1**, **Face Match Multi-Ângulo 128-D ($\ge 78\%$)** e **Transcrição OCR Visível** | ✅ **100% Concluído (`v2.8.1`)** |
| **Fase 5 (`E-06` a `E-08`)** | Liquidação Bancária Homologada no Bacen (SPI/DICT), Telemetria *Crash-Reporting* Externa e Publicação na Google Play Store | 🔜 **Planejado (Pós-Banca)** |

---

## 2. Detalhamento dos Épicos Concluídos (`E-01` a `E-05g`)

### 2.1. `E-05f` — Engenharia Financeira de Garantia em 3 Camadas e Motor Antifraude ($O(1) / O(\log N)$)
- Implementação das tabelas `public.warranty_pool_ledger`, `public.escrow_maturation_entries`, `public.job_mediations` e `public.forensic_certificates` na migração [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql).
- Implementação do **Smart Split Anti-Bypass**: sobretaxa de $15.0\%$ exclusiva sobre a mão de obra ($13.5\%$ operacional + $1.5\%$ fundo garantidor) e $0.0\%$ sobre peças e materiais com nota fiscal (respeitando $M \le 0.60 \cdot \text{Gross}$).
- Implementação da 4ª aba **"Em Mediação"** (`JobMediationTab`), do modal de **PIN Presencial de 4 dígitos**, da **Carteira Bipartida** e da guarda forense `PerceptualHashGuard` (`dHash` de 64 bits + inspeção EXIF em *Worker Isolate*).
- Implementação do **Passaporte Oficial de Manutenção do Imóvel** (`PropertyMaintenancePassportPdf`) em conformidade com a **ABNT NBR 5674** e a **Lei Federal nº 8.245/91**.

### 2.2. `E-05g` — Biometria Facial Ao Vivo, Scanner Documental ISO ID-1 e OCR Visível
- Implementação da migração [`20261108120000_client_kyc_biometrics_and_ocr.sql`](../supabase/migrations/20261108120000_client_kyc_biometrics_and_ocr.sql) com validação algorítmica de CPF (Módulo 11), `cpf_hash` e `face_liveness_hash` únicos e RPC `submit_client_kyc_biometrics_and_ocr`.
- Implementação da câmera frontal ao vivo (`_LiveFrontOvalLivenessCameraModal`), do scanner documental guiado ISO/IEC 7810 ID-1 (`DocumentGuidedScannerModal`), do recorte central de 12% (*Core ROI Inset*), do Face Match multi-ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em espaço 128-D não-negativo e do card visível `_OcrTranscribedSummaryCard`.

---

## 3. Próximos Épicos Planejados (`E-06` a `E-08`)

1. **`E-06` — Integração Direta com PSP Homologado no Banco Central (SPI / DICT)**:
   - Conectar as RPCs `lock_escrow_with_smart_split` e `release_matured_escrow_batch` a webhooks assinados de instituição de pagamento participante do SPI para liquidação PIX automatizada e consulta DICT em tempo real.
2. **`E-07` — Observabilidade Distribuída (Sentry / OpenTelemetry)**:
   - Exportar os eventos estruturados do `TelemetryService` para coletor OpenTelemetry externo com rastreamento de latência de RPCs e *Worker Isolates*.
3. **`E-08` — Homologação Comercial na Google Play Console**:
   - Submissão do *Android App Bundle* (`app-release.aab`) assinado seguindo o roteiro técnico documentado em [`docs/PLAY_STORE.md`](PLAY_STORE.md).

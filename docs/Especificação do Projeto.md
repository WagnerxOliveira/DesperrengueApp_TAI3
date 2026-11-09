# Especificação Técnica e Normativa do Projeto — Desperrengue (`v2.8.1`)

Especificação formal de requisitos funcionais, requisitos não-funcionais, regras de negócio atuariais (`RN-CAM-01` a `RN-CAM-03`), blindagem antifraude (`RN-AF-01` a `RN-AF-14`) e resolução de *Cold-Start* (`RN-MZ-01` a `RN-MZ-05`) do sistema **Desperrengue**.

---

## 1. Perfis de Atores e Unificação Multi-Modo

O sistema modela dois papéis operacionais principais que coexistem sobre uma única identidade civil e biométrica em `public.profiles`:

1. **Usuário Cliente (`role = 'client'`)**: Proprietário ou locatário de imóvel residencial que contrata serviços em **33 categorias**, realiza o onboarding biométrico ao vivo com scanner documental ISO ID-1 e OCR, aprova visitas técnicas mediante **PIN Presencial de 4 dígitos**, aciona a **Garantia em 3 Camadas** pela 4ª aba *"Em Mediação"* e emite o **Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674)**.
2. **Usuário Profissional / Socorrista (`role = 'professional'`)**: Prestador técnico credenciado que envia propostas com **Smart Split** (mão de obra vs. peças com nota fiscal), executa o checklist fotográfico forense (*Antes e Depois*), gerencia sua **Carteira Bipartida** (saldo livre PIX vs. saldo em maturação $D+7/D+5/D+2$) e, quando elegível ao **Nível Ouro** ($RTS \ge 85$), atua como **Profissional Socorrista** na Camada 3.

---

## 2. Catálogo de Requisitos Funcionais Implementados (`RF-01` a `RF-24`)

| Código | Requisito Funcional | Módulo / Implementação Real | Status |
| :--- | :--- | :--- | :---: |
| `RF-01` | Autenticação segura (Cadastro, Login, Confirmação de E-mail e Reset de Senha via PKCE) | `app/lib/features/auth/` + Supabase Auth | ✅ Concluído |
| `RF-02` | Onboarding do Cliente em 4 Etapas com CPF Módulo 11, ViaCEP, Biometria Facial Ao Vivo (`ClipOval`) e Scanner ISO ID-1 + OCR | `client_setup_screen.dart` + `document_ocr_and_liveness_service.dart` | ✅ Concluído |
| `RF-03` | Credenciamento Profissional em 5 Etapas com Âncoras Externas (SENAI/CREA/CFT/NR-10/NR-35) e PIX *Same-Holder Lock* | `app/lib/features/pro/presentation/verificacao/` | ✅ Concluído |
| `RF-04` | Alternância Multi-Modo (*Client* $\leftrightarrow$ *Professional*) com compartilhamento automático de $+30\text{ pts}$ de KYC/Biometria no $RTS$ | `profile_screen.dart` + `trg_profiles_compute_rts_and_tier` | ✅ Concluído |
| `RF-05` | Abertura de Chamados nas **33 categorias residenciais** com fotos, geolocalização, nível de urgência e agendamento | `create_job_bottom_sheet.dart` + `service_categories.dart` | ✅ Concluído |
| `RF-06` | Busca Geoespacial em $O(\log N + K)$ (*Axial Bounding Box Pruning*) e ordenação *Waterfall* em 5 Tiers | `search_professionals_bbox` (`20261108110000`) | ✅ Concluído |
| `RF-07` | Decomposição Financeira **Smart Split Anti-Bypass** ($13.5\%$ operacional + $1.5\%$ garantia sobre mão de obra; $0\%$ sobre materiais c/ NF $\le 60\%$) | `fintech_warranty_models.dart` + `lock_escrow_with_smart_split` | ✅ Concluído |
| `RF-08` | **Camada 1 de Garantia (`RN-CAM-01`)**: Retenção automática em maturação ($D+7$, $D+5$ ou $D+2$) e Carteira Bipartida | `escrow_maturation_entries` + `BipartiteWalletCard` | ✅ Concluído |
| `RF-09` | **Camada 2 de Garantia (`RN-CAM-02`)**: 4ª Aba *"Em Mediação"* com SLA regressivo de 4h e janela de reparo de 24h | `JobMediationTab` + `open_job_mediation_claim` + `respond_to_job_mediation` | ✅ Concluído |
| `RF-10` | **Camada 3 de Garantia (`RN-CAM-03`)**: Acionamento do Fundo Garantidor (`warranty_pool_ledger`), despacho de Socorrista e dívida técnica | `resolve_mediation_and_trigger_layer3` | ✅ Concluído |
| `RF-11` | Guarda Forense de Câmera Nativa com `dHash` de 64 bits (Hamming $\le 5$ em $O(1)$) e inspeção de adulteração EXIF | `perceptual_hash_guard.dart` + `forensic_certificates` | ✅ Concluído |
| `RF-12` | Validação Presencial por **PIN Criptográfico de 4 Dígitos** para conclusão de garantia | `Pin4WarrantyVerificationModal` | ✅ Concluído |
| `RF-13` | Emissão do **Passaporte Oficial de Manutenção do Imóvel** em `%PDF-1.4` (ABNT NBR 5674 e Lei 8.245/91) com princípio *Zero Fake Data* | `property_maintenance_passport_pdf.dart` | ✅ Concluído |
| `RF-14` | Exclusão Escopada de Conta em conformidade com a LGPD (`client`, `professional` ou total) | `delete_own_account_scoped` (`20261105140000`) | ✅ Concluído |

---

## 3. Requisitos Não-Funcionais e Restrições de Engenharia (`RNF-01` a `RNF-10`)

1. **`RNF-01` — Desempenho de Interface a 60 FPS**: Cronômetros regressivos e animações de câmera operam confinados em `RepaintBoundary` com `ValueListenableBuilder`, garantindo tempo de *raster thread* $\le 16.6\text{ ms}$.
2. **`RNF-02` — Paralelismo em Memória Isolada**: Toda inferência de visão computacional e geração de PDF executa-se em *Worker Isolates* via `Isolate.run` com limite de *heap* $\le 6.5\text{ MB}$ por quadro ($1280 \times 1280\text{ px}$).
3. **`RNF-03` — Ausência Matemática de Deadlocks**: Aquisição canônica de bloqueios pessimistas na ordem `jobs -> job_mediations -> escrow_maturation_entries -> profiles`.
4. **`RNF-04` — Imutabilidade de Registros Contábeis**: Tabelas de custódia financeira e forense protegidas por triggers *append-only*.
5. **`RNF-05` — Portabilidade Responsiva (`480px`)**: Compatibilidade integral entre Android nativo e PWA iOS/Desktop com trava de largura máxima de `480px`.

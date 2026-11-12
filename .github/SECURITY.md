# Política de Segurança, Blindagem Antifraude e Custódia Forense (`SECURITY.md`)

Este documento especifica a arquitetura de defesa em profundidade, o controle de acesso relacional (*Row Level Security*), a mitigação determinística dos **6 Vetores de Fraude (`RN-AF-01` a `RN-AF-14`)**, a **Arquitetura KYC Zero-Trust Híbrida (`Gemini 4 Argon High` + `Carbon High`)** e as garantias de conformidade com a **LGPD (Lei Federal nº 13.709/2018)** implementadas no ecossistema **Desperrengue** (`v2.8.6`).

---

## 1. Superfície de Autenticação e Autorização Relacional (RLS)

1. **Autenticação OAuth2 / PKCE**: Toda sessão de usuário é autenticada via Supabase Auth (GoTrue) utilizando fluxo PKCE e tokens JWT assinados criptograficamente.
2. **Isolamento por *Row Level Security* (RLS)**: Todas as tabelas do esquema `public` operam com `ENABLE ROW LEVEL SECURITY`. Nenhuma tabela sensível (`warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations`, `forensic_certificates`, `kyc_submissions`, `kyc_webhook_events`) aceita comandos `UPDATE` ou `DELETE` diretos provenientes do cliente autenticado.
3. **Mutação Exclusiva via RPCs `SECURITY DEFINER`**: Operações contábeis, transições da máquina de estados de mediação e submissões/vereditos de KYC biométrico (`public.submit_client_kyc` e `public.apply_verified_carbon_kyc_verdict`) são executadas exclusivamente por funções PL/pgSQL declaradas com `SECURITY DEFINER` e `SET search_path = public`, prevenindo ataques de *search_path hijacking* e escalação horizontal de privilégios.

---

## 2. Mitigação Determinística dos 6 Vetores de Fraude (`RN-AF-01` a `RN-AF-14`)

| Vetor de Ameaça | Regras | Controles Criptográficos e Algorítmicos Ativos |
| :--- | :--- | :--- |
| **1. Conluio Cliente-Profissional (*Cash-Out*)** | `RN-AF-01..04` | Proibição de reembolso em espécie ao cliente; cobertura da Camada 3 restrita ao pagamento direto de **Profissional Socorrista** independente; detecção de ciclos em grafo bipartido (`client_id`, `professional_id`, `device_fingerprint`, `ip_prefix_24`, `pix_holder_cpf_hash`); suspensão imediata por dívida técnica (`suspended_debt`). |
| **2. Sabotagem Pós-Serviço pelo Cliente** | `RN-AF-05..07` | Exigência de **Checklist Fotográfico Antes e Depois** com certificado `forensic_certificates`; validação de **Lacre de Garantia Virtual**; obrigatoriedade de **PIN Presencial de 4 dígitos** gerado no aparelho do cliente para encerrar visita de garantia. |
| **3. Reciclagem de Evidências Fotográficas** | `RN-AF-08..10` | Captura exclusiva via sensor físico (`ImageSource.camera`); bloqueio de metadados EXIF de editores/mensageiros (`WhatsApp`, `Telegram`, `Photoshop`, `Canva`, `GIMP`) e `DateTimeOriginal > 15 min`; **Distância de Hamming (`dHash` 64-bit) $\le 5$ bits** em $O(1)$ via `compute_hamming_distance_64`. |
| **4. *Bypass* por Inflação de Material** | `RN-AF-11..12` | Trava relacional e de domínio $M \le 0.60 \cdot (L + M)$; exigência de comprovante fiscal (`materials_receipt_url`) auditado por Chave NF-e de 44 dígitos (Módulo 11) e CNPJ (Módulo 11) em [`vision_ocr_argon.py`](../kyc_engine/app/services/vision_ocr_argon.py); cobertura de garantia restrita estritamente ao valor de mão de obra ($L$). |
| **5. Golpe do "Falso Socorrista"** | `RN-AF-13` | Elegibilidade restrita a prestadores **Nível Ouro** ($RTS \ge 85$, $\ge 15$ serviços concluídos com $0\%$ de disputa e distância geodésica/grafo disjunta). |
| **6. Ataque Sybil e Laranjas** | `RN-AF-14` | Índices únicos B-Tree sobre `cpf_hash` (SHA-256 / HMAC-SHA256 + *Pepper*) e `face_liveness_hash` em `public.profiles`; trava **PIX Same-Holder Lock** (`pix_key_cpf_matched = TRUE`). |

---

## 3. Segurança Biométrica, Criptografia VIO/ICP-Brasil e Arquitetura KYC Zero-Trust (`ADR-0021`)

Documentado no [`ADR-0021`](../docs/adr/0021-arquitetura-kyc-zero-trust-argon-carbon.md) e implementado em [`document_ocr_and_liveness_service.dart`](../app/lib/core/services/document_ocr_and_liveness_service.dart), [`kyc_session_anti_swap_guard.dart`](../app/lib/core/security/kyc_session_anti_swap_guard.dart), [`client_setup_screen.dart`](../app/lib/features/client/presentation/client_setup_screen.dart) e no microsserviço [`kyc_engine/`](../kyc_engine/app/main.py):

1. **Prova de Vida Ao Vivo (`_LiveFrontOvalLivenessCameraModal`) e Antispoofing *On-Device***:
   - Bloqueia ataques de apresentação (*Presentation Attacks* com fotos impressas ou telas de monitores/notebooks) combinando segmentação de pele humana no espaço $YCbCr$ ($77 \le Cb \le 127$, $133 \le Cr \le 173$), filtro de radiância azul de telas (`blueMonitorRatio < 0.25`), variância Laplaciana ($\sigma_{\text{Lap}}^2 \ge 95.0$) e desafios biomecânicos sequenciais na câmera frontal.
   - Aplica recorte central de 12% (*Core ROI Inset*) no scanner ISO ID-1 e exige divergência estrutural entre Frente e Verso ($\text{Hamming} \ge 10\text{ bits}$, $\text{MAD}_{64\times 64} \ge 0.055$ e $\Delta\sigma_{\text{quadrantes}}^2 \ge 0.040$), além de Face Match multi-ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em espaço 128-D não-negativo com similaridade $\ge 78.0\%$.
2. **Protocolo Anti-Swap (`180s` TTL) e Atestação de Hardware ([`security.py`](../kyc_engine/app/core/security.py))**:
   - Emite desafio assinado por `HMAC-SHA256` (`session_nonce` de uso único em `LRUCache`, janela temporal estrita $\Delta t \le 180\text{ s}$ entre Liveness e captura documental) e valida `request_hash = SHA256(user_id || session_nonce || selfie_hash || doc_front_hash || doc_back_hash || doc_capture_timestamp)` em tempo constante (`hmac.compare_digest`).
   - Rejeita 100% de uploads oriundos de galeria (`capture_source != "LIVE_CAMERA"`), bloqueia drivers de câmera virtual (`OBS VirtualCam`, `Magisk VCam`, `ManyCam`, `DroidCam`) e verifica Google Play Integrity (`MEETS_STRONG_INTEGRITY`) / Apple `DCAppAttestService` (aplicando alçada restrita `WEB_LIMITED_ALCADA` em clientes Web/PWA).
3. **Grounding Espacial 2D, Blindagem Anti-*Visual Prompt Injection* e Criptografia VIO/ICP-Brasil ([`vision_ocr_argon.py`](../kyc_engine/app/services/vision_ocr_argon.py) & [`crypto_doc_validator.py`](../kyc_engine/app/services/crypto_doc_validator.py))**:
   - O `ArgonDocumentVisionService` (`thinking_level="HIGH"`) corrige rotações de $0^\circ, 90^\circ, 180^\circ, 270^\circ$, recorta o QR Code VIO em **PNG sem perda (*lossless*)** e bloqueia qualquer tentativa de *Visual Prompt Injection* colada no documento (`adversarial_prompt_injection_detected == True` força `is_readable = False`).
   - O `GovCryptographicDocumentValidator` aplica super-resolução bicúbica $2\times$ + `CLAHE`, descompressão `zlib` protegida contra *zip-bombs* ($\le 64\text{ KiB}$), verificação matemática de envelopes `ASN.1/DER CMS PKCS#7 SignedData` e assinaturas `ECDSA P-256` (`IEEE P1363` $\leftrightarrow$ `DER`) / `RSA-2048` contra a cadeia ICP-Brasil/SENATRAN, trava anti-clonagem bit-a-bit (`qr_cpf == ocr_cpf == typed_cpf`) e *Passive Authentication* NFC (`EF.SOD` + `DG1`/`DG2` conforme ICAO Doc 9303).
4. **Os 5 Hard Vetos Determinísticos Pré-LLM, SERPRO mTLS 1.3 e Webhook Assinado ([`fraud_orchestrator.py`](../kyc_engine/app/services/fraud_orchestrator.py), [`serpro_datavalid.py`](../kyc_engine/app/services/serpro_datavalid.py) & [`kyc-carbon-webhook`](../supabase/functions/kyc-carbon-webhook/index.ts))**:
   - O `CarbonFraudOrchestrator` executa 5 Hard Vetos determinísticos em Python puro antes de acionar o LLM (impedindo qualquer aprovação por alucinação), consulta o SERPRO Datavalid via pool persistente `TLS 1.3` mútuo com certificado ICP-Brasil A1 e *Circuit Breaker*, e dispara o veredito assinado por `HMAC-SHA256` (`X-KYC-Signature` + `X-KYC-Timestamp`) para a Edge Function `kyc-carbon-webhook` e migração [`20261112150000_carbon_kyc_webhook_bridge.sql`](../supabase/migrations/20261112150000_carbon_kyc_webhook_bridge.sql).

---

## 4. Proteção de Dados Pessoais, Criptografia WORM e Conformidade LGPD

1. **Minimização e Pseudonimização de CPF com *Pepper* + Redação Automática de Logs**: O número bruto do CPF é validado pelo algoritmo Módulo 11, convertido em `HMAC-SHA256` com `cpf_pepper` secreto (`cpf_hash`) acompanhado apenas da máscara visual `***.XXX.XXX-**` (`cpf_masked`). O filtro `PiiRedactingLogFilter` em [`security.py`](../kyc_engine/app/core/security.py) intercepta `logging.LogRecord` e mascara em tempo real qualquer CPF ou token OAuth2/Bearer antes da gravação em stdout/SIEM.
2. **Criptografia de Evidências WORM (`AES-256-GCM` via `HKDF-SHA256`) e Isolamento de Buckets**: Cada evidência documental destinada ao armazenamento de auditoria é cifrada por envelope autenticado `AES-256-GCM` com chave efêmera derivada por `HKDF-SHA256` (`salt` de 16 bytes, `nonce` de 12 bytes, `AAD` vinculado a `user_id`/`session_nonce`), além do isolamento nos buckets privados `kyc-documents`, `pro-verifications` e `forensic-evidence` (`public = false`).
3. **Direito à Explicação (`Art. 20 da LGPD`) e Eliminação Escopada (`Art. 18, VI da LGPD`)**: Todo veredito automatizado registra obrigatoriamente os **Top-3 Fatores SHAP** (`shap_top_3_factors`) para auditoria regulatória enquanto exibe orientações acolhedoras em português sem jargão técnico via [`kyc_human_feedback_translator.dart`](../app/lib/core/ui/kyc_human_feedback_translator.dart). A função `public.delete_own_account_scoped(p_scope)` permite revogar seletivamente o perfil `client` ou `professional` preservando apenas os registros contábeis imutáveis exigidos por lei.

---

## 5. Reporte de Vulnerabilidades

Vulnerabilidades de segurança identificadas devem ser reportadas de forma privada através da aba **Security Advisories** do repositório GitHub oficial, incluindo passos determinísticos de reprodução e evidências técnicas.

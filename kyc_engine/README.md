# Desperrengue Zero-Trust KYC & Smart Split Engine (`kyc_engine`)

Microsserviço criptográfico, óptico e biométrico Zero-Trust em **Python 3.11+ / FastAPI** responsável pelo funil de verificação de identidade civil (CNH Digital/Física, Nova CIN, RG e Passaporte) e auditoria fiscal do **Smart Split (0% de comissão sobre materiais consumíveis)**.

## Arquitetura em Camadas (Funil Econômico Zero-Trust)

1. **Estágio 0 — Sessão Anti-Swap (`<= 180s`), Câmera Ao Vivo e Atestação de Hardware (`app/core/security.py`)**:
   - Desafio assinado via `HMAC-SHA256` vinculando `user_id | session_nonce | issued_at` com uso único (antirreplay).
   - Janela temporal estrita: `0 <= (t_liveness - t0) <= 90s`, `0 <= (t_doc - t_liveness) <= 180s` e `(now - t0) <= 180s`.
   - Verificação em tempo constante (`hmac.compare_digest`) do `request_hash` (`SHA-256` sobre identidade, nonce e hashes das capturas).
   - Bloqueio determinístico de uploads de galeria (`capture_source != "LIVE_CAMERA"`), câmeras virtuais (`OBS`, `VCam`, `ManyCam`, `DroidCam`) e dispositivos sem integridade (`Play Integrity MEETS_STRONG_INTEGRITY` no Android, `DCAppAttestService` no iOS, e alçada contida `WEB_LIMITED_ALCADA` em Web/PWA).

2. **Estágio 1 — Triagem Óptica, Grounding Espacial 2D e OCR Estruturado (`Gemini 4 Argon High`)**:
   - Auto-rotação canônica (`0°`, `90°`, `180°`, `270°`), detecção de Moiré/replay de tela, colagem tipográfica e defesa contra *Visual Prompt Injection*.
   - Ancoragem espacial `[0..1000]` da Foto 3x4 (`JPEG quality=95`) e do QR Code VIO (`PNG lossless`).
   - Validação matemática O(1) de CPF Módulo 11, CNPJ Módulo 11, Chave NF-e de 44 dígitos Módulo 11 e MRZ ICAO Doc 9303 (`7-3-1`).

3. **Estágio 2 — Criptografia Governamental VIO/ICP-Brasil e NFC ICAO 9303 (`app/services/crypto_doc_validator.py`)**:
   - Super-resolução óptica `2x` bicúbica + `CLAHE (2.2, 8x8)` + limiarização adaptativa Gaussiana com decodificador C++ `zxingcpp` e fallback OpenCV.
   - Descompressão `zlib` blindada contra *zip-bombs* (`max_length = 65536` bytes com rejeição imediata em `unconsumed_tail`).
   - Verificação de envelopes `ASN.1 / DER CMS (PKCS#7 SignedData)`, conversão de assinaturas `ECDSA P-256 (IEEE P1363 r||s <-> DER)` e `RSA PKCS#1 v1.5 / RSA-PSS` encadeadas a raízes X.509 confiáveis.
   - **Trava Anti-Clonagem Bit-a-Bit**: `qr_cpf == ocr_cpf == typed_cpf`.
   - **Passive Authentication NFC (`EF.SOD`)**: verificação da assinatura CMS DS/CSCA e recálculo `SHA-256` sobre `DG1` (MRZ) e `DG2` (Face ISO/IEC 19794-5).

4. **Estágio 3 — Triangulação Biométrica SERPRO Datavalid mTLS (`app/services/serpro_datavalid.py`)**:
   - Pool persistente `httpx.AsyncClient` sobre `TLS 1.3` estrito + certificado cliente ICP-Brasil A1.
   - Cache concorrente de token OAuth2 protegido por `asyncio.Lock()` (double-checked locking) e **Circuit Breaker** determinístico (`CLOSED -> OPEN -> HALF_OPEN`).

5. **Estágio 4 — Orquestrador de Risco Carbon High & Custódia WORM (`app/services/fraud_orchestrator.py` & `app/main.py`)**:
   - **5 Hard Vetos Determinísticos Pré-LLM** em Python puro (o modelo jamais pode aprovar ou sobrescrever uma violação matemática, biométrica ou criptográfica).
   - Correlação final com `Gemini 4 Carbon High` (`thinking_level="HIGH"`), 3 fatores objetivos de explicabilidade (**LGPD Art. 20**) e mensagem 100% humana sem jargões técnicos.
   - Custódia forense WORM com envelope `HKDF-SHA256` (`salt=16B`, `info="desperrengue-kyc-worm-v2"`) + `AES-256-GCM` (`nonce=12B` + `AAD`) e disparo de webhook assinado `HMAC-SHA256` para a Edge Function `kyc-carbon-webhook`.

## Execução dos Testes Automatizados

```bash
pip install -r kyc_engine/requirements.txt
PYTHONPATH=kyc_engine pytest kyc_engine/tests/ -v
```

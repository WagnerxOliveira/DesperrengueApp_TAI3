# Changelog — Histórico Técnico de Versões

Todas as alterações arquiteturais, algorítmicas e de banco de dados do projeto **Desperrengue** são documentadas neste arquivo, seguindo o padrão [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [2.8.1] — 2026-11-08

### Adicionado
- **Câmera Frontal Ao Vivo em Moldura Oval (`_LiveFrontOvalLivenessCameraModal`)**: Captura nativa in-app exclusiva na lente frontal (`CameraLensDirection.front` / WebRTC `facingMode: "user"`) com execução sequencial de 3 desafios biomecânicos reais (centralização facial, rotação lateral e piscada ativa), crominância de pele $YCbCr$, filtro anti-monitor (`blueMonitorRatio < 0.25`) e variância Laplaciana $\sigma_{\text{Lap}}^2 \ge 95.0$.
- **Scanner Documental Guiado ISO/IEC 7810 ID-1 (`DocumentGuidedScannerModal`)**: Moldura retangular na proporção canônica `1.586 : 1` para captura guiada de Frente e Verso de RG, CNH ou CIN com cantoneiras néon e checklist visual.
- **Recorte Central de 12% (*Core ROI Inset*) e Diferenciação Frente/Verso em 3 Camadas**: Isolamento da região central do documento antes do cálculo da Distância de Hamming `dHash` ($\ge 10\text{ bits}$), Diferença Absoluta Média em grade $64 \times 64$ ($\text{MAD}_{64\times 64} \ge 0.055$) e delta de variância de quadrantes ($\ge 0.040$).
- **Face Match Multi-Ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em Espaço 128-D Não-Negativo**: Alinhamento rotacional ortogonal da foto 3x4 do documento contra o descritor 128-D L2-normalizado da selfie ao vivo, garantindo $S_{\cos} \in [0\%, 100\%]$ e limiar estrito $\ge 78.0\%$.
- **Card Visível de Transcrição OCR (`_OcrTranscribedSummaryCard`)**: Exibição auditável do Nome Civil, CPF, RG/CNH, Data de Nascimento, percentual de Face Match e compatibilidade nominal ($\ge 80\%$) na Etapa 4 do `ClientSetupScreen`.
- **Documentação Científica Formal (`ADR-0020`)**: Formalização integral da arquitetura em linguagem técnico-científica de Ciência da Computação em todos os arquivos Markdown do repositório.

---

## [2.8.0] — 2026-11-08

### Adicionado
- **Fundo de Garantia Auto-Sustentável em 3 Camadas (`RN-CAM-01` a `RN-CAM-03`)**:
  - **Camada 1**: Retenção programada em maturação ($D+7 / D+5 / D+2$) na tabela `public.escrow_maturation_entries` com congelamento instantâneo (`frozen_mediation`).
  - **Camada 2**: Retorno Técnico Prioritário de 30 a 90 dias com SLA de resposta de 4 horas úteis e janela de reparo de 24 horas na tabela `public.job_mediations`.
  - **Camada 3**: Cobertura pelo livro-razão `public.warranty_pool_ledger` com acionamento de **Profissional Socorrista** e aplicação de dívida técnica (`suspended_debt`) ao prestador infrator.
- **Motor Contábil Smart Split Anti-Bypass**: Decomposição entre mão de obra ($13.5\%$ operacional + $1.5\%$ fundo de garantia) e peças/materiais com nota fiscal ($0.0\%$ de taxa, limitado a $\le 60\%$ do valor bruto).
- **Mitigação Determinística dos 6 Vetores de Golpe (`RN-AF-01` a `RN-AF-14`)**: Grafo anti-conluio, checklist Antes/Depois com PIN presencial de 4 dígitos, guarda criptográfica `PerceptualHashGuard` (`dHash` 64-bit com Distância de Hamming $\le 5$ bits em $O(1)$ e inspeção EXIF), trava de material $\le 60\%$, elegibilidade Nível Ouro para Socorrista e bloqueio Anti-Sybil (`cpf_hash`, `face_liveness_hash` e PIX *Same-Holder Lock*).
- **Resolução do Paradoxo do Marco Zero (`RN-MZ-01` a `RN-MZ-05`)**: Cálculo incremental em $O(1)$ do *Relative Trust Score* ($RTS \in [0, 100]$) e do `waterfall_tier_rank` ($1 \dots 5$), âncoras de confiança externa (SENAI/CREA/CFT/NR-10/NR-35), reserva semente com *Circuit Breaker* ($>1.2\%$) e *cooldown* de saque de 24h.
- **4ª Aba Operacional "Em Mediação" (`JobMediationTab`) e Carteira Bipartida**: Isolamento de repintura a $60\text{ FPS}$ (`RepaintBoundary` + `ValueListenableBuilder<Duration>`) e pipeline especulativo `SpeculativeEvidencePipeline` (GPS warm-up de 30s + upload concorrente idempotente).
- **Passaporte Oficial de Manutenção do Imóvel (`PropertyMaintenancePassportPdf`)**: Jornada interativa com princípio *Zero Fake Data* e exportação vetorial `%PDF-1.4` em conformidade com a **ABNT NBR 5674** e a **Lei Federal nº 8.245/91**.
- **Migrações SQL `20261108110000` e `20261108120000`**: Elevação da base relacional para **21 migrações SQL**, **529 testes Flutter** e **577 asserções SQL**.

---

## [2.5.0] a [2.7.0] — 2026-11-05 a 2026-11-07

### Adicionado
- **Exclusão Escopada de Conta LGPD (`20261105140000_scoped_account_deletion.sql`)**: RPC `delete_own_account_scoped` permitindo excluir apenas o perfil `client` ou `professional` com preservação da contraparte, ou purga total no último perfil.
- **Engenharia de Ícones Adaptativos (`app_icon_integrity_test.dart`)**: Redimensionamento matemático na zona segura de 66% do Android One UI, iOS e PWA.

---

## [1.1.0] a [2.4.0] — 2026-10-09 a 2026-11-04

### Adicionado
- Consolidação das migrações `20261009120000` a `20261104210000`: esquema base de `profiles`, `jobs`, `proposals`, `messages`, `reviews`, `favorites`, `notifications`, `professional_availability`, storage RLS privado para KYC (`pro-verifications`), recibos auditáveis, 33 categorias de serviço e suíte CI/CD com publicação automática de PWA e APK Beta.

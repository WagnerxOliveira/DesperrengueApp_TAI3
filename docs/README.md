# Catálogo Sistemático e Guia de Leitura Científica do Diretório `docs/`

Este documento constitui o índice taxonômico, o mapa conceitual e o guia de navegação da documentação técnico-científica do ecossistema **Desperrengue** (`v2.8.1+202611082`), catalogando a finalidade de todos os **20 documentos Markdown principais** e das **5 subpastas especializadas** contidas em `docs/`.

---

## 1. Mapa Taxonômico da Documentação (`mindmap`)

```mermaid
mindmap
  root((Biblioteca Científica\nDesperrengue v2.8.1))
    Arquitetura & Algoritmos
      ARCHITECTURE.md
      Arquitetura do Sistema.md
      adr/ (0000 a 0020)
    Requisitos, Contexto & UI/UX
      Especificação do Projeto.md
      Documento de Contexto.md
      Projeto de Interface.md
      onboarding_profissional.md
      specs/ & ui_ux/
    Engenharia Financeira & Estratégia
      Fluxo de Caixa.md
      Planos de Negocio e Tributação.md
      GAMIFICACAO.md
      Analise de Ambientes e SWOT.md
      Balanced Scorecard (BSC).md
      planilhas/
    Qualidade, Operação & Release
      TESTING.md
      TESTE_COM_AMIGOS.md
      SETUP.md & setup/
      PLAY_STORE.md
      registro_dominio_resend.md
      ROADMAP.md & CHANGELOG.md
      Template.md
```

---

## 2. Catálogo Sistemático dos 20 Arquivos `.md` de `docs/`

| # | Documento em `docs/` | Categoria Epistemológica | Síntese do Conteúdo Técnico-Científico |
| :---: | :--- | :--- | :--- |
| `01` | [`README.md`](README.md) | Índice Sistemático | Taxonomia documental completa, sumário executivo de `docs/` e subpastas e matriz de leitura por perfil técnico. |
| `02` | [`ARCHITECTURE.md`](ARCHITECTURE.md) | Arquitetura de Software e Algoritmos | Decomposição nas 4 camadas, provas algébricas *Big-O* (*Axial Bounding Box* $O(\log N + K)$, Hamming Bitwise $O(1)$, Triggers $O(1)$), *Worker Isolates* a $120\text{ Hz}$ e prova por teoria dos grafos de ausência de *deadlocks*. |
| `03` | [`Arquitetura do Sistema.md`](Arquitetura%20do%20Sistema.md) | Topologia Distribuída e Banco de Dados | Topologia Cliente-Servidor-Edge, dicionário de dados completo das 6 tabelas centrais, as 4 invariantes declarativas, os 9 índices estratégicos e catálogo de RPCs. |
| `04` | [`Especificação do Projeto.md`](Especifica%C3%A7%C3%A3o%20do%20Projeto.md) | Engenharia de Requisitos e Normas | Personas, User Stories (`US`), Requisitos `RF`/`RNF`, Regras de Camada (`RN-CAM-01..03`), Regras Antifraude (`RN-AF-01..14`), Marco Zero (`RN-MZ-01..05`), KYC (`RN-KYC-01..06`) e Matriz de Rastreabilidade Código $\times$ Teste. |
| `05` | [`Documento de Contexto.md`](Documento%20de%20Contexto.md) | Fundamentação Teórica, **Lean Canvas** e Estratégia | Problema, Solução, **Lean Canvas (Quadro Matricial e Tabela dos 9 Blocos)**, Missão, Visão e Valores, Seleção Adversa de Akerlof e Paradoxo da Desintermediação (*Anti-Bypass Smart Split*). |
| `06` | [`Projeto de Interface.md`](Projeto%20de%20Interface.md) | Engenharia de IHC e Design System | Estética *Quiet Luxury Dark*, container `480px`, *wireframes* Unicode das 4 etapas do `ClientSetupScreen`, mapa com contador `1º, 2º, 3º`, 4ª aba *"Em Mediação"* com `ForensicSplitViewComparator` e carteira bipartida. |
| `07` | [`onboarding_profissional.md`](onboarding_profissional.md) | Visão Computacional, Biometria e KYC | Arquitetura de Identidade Civil Unificada Multi-Modo ($+30\text{ pts}$ no $RTS$) e equações matemáticas dos 6 validadores forenses (Módulo 11, $YCbCr$, $\text{EAR}$, $\text{Yaw}$, Laplaciano $3\times 3$, `dHash + MAD` sobre ROI 12% e Face Match 128-D). |
| `08` | [`GAMIFICACAO.md`](GAMIFICACAO.md) | Engenharia de Reputação e Teoria de Incentivos | Fórmula exata do *Relative Trust Score* ($RTS \in [0, 100]$), progressão de tiers e Profissionais Âncora, acoplamento com velocidade de liquidação e Cascata de 5 Degraus (`waterfall_tier_rank`). |
| `09` | [`Fluxo de Caixa.md`](Fluxo%20de%20Caixa.md) | Contabilidade de Custódia e Liquidez Atuarial | Equações de fluxo de caixa do *Smart Escrow*, segregação de $1,5\%$ ($N = 66,67$), contabilidade da reserva de maturação e recuperação via *Clawback* (`clawback_debt_balance`). |
| `10` | [`Planos de Negocio e Tributação.md`](Planos%20de%20Negocio%20e%20Tributa%C3%A7%C3%A3o.md) | Economia da Plataforma e Engenharia Tributária | Segregação contábil do *Smart Split* no Brasil (evitando bitributação sobre repasse do prestador e insumos), linhas de receita B2C/B2B (Passaporte ABNT NBR 5674) e *Unit Economics*. |
| `11` | [`Analise de Ambientes e SWOT.md`](Analise%20de%20Ambientes%20e%20SWOT.md) | Inteligência Competitiva | Análise PESTEL, 5 Forças de Porter e Matriz SWOT Cruzada fundamentada na visão computacional *on-device* a custo marginal R$ 0,00 e blindagem antifraude. |
| `12` | [`Balanced Scorecard (BSC).md`](Balanced%20Scorecard%20(BSC).md) | Governança Estratégica e Telemetria | Mapa Estratégico de Causa-Efeito nas 4 perspectivas de Kaplan & Norton com fórmulas SQL de KPIs extraídas em tempo real do PostgreSQL. |
| `13` | [`TESTING.md`](TESTING.md) | Verificação Formal e Suíte *Red Team* | Arquitetura das 26 suítes Dart (`529` testes) e 9 suítes SQL (`577` asserções), detalhando os 6 testes *Red Team* de fraude financeira e os 6 testes forenses de visão computacional e OCR. |
| `14` | [`TESTE_COM_AMIGOS.md`](TESTE_COM_AMIGOS.md) | Homologação Empírica em Campo | Roteiro científico de validação em aparelhos Android e iOS: câmera frontal no oval, scanner CNH na horizontal e vertical, ditado por voz, mapa, PIN de 4 dígitos, mediação e Passaporte PDF. |
| `15` | [`SETUP.md`](SETUP.md) | Provisionamento e Build | Instruções determinísticas de configuração do Flutter SDK, variáveis Supabase, aplicação das 21 migrações SQL e compilação Web/Android/iOS. |
| `16` | [`PLAY_STORE.md`](PLAY_STORE.md) | Engenharia de Release Mobile | Configuração de permissões nativas (`CAMERA`, `ACCESS_FINE_LOCATION`, `RECORD_AUDIO`), assinatura AAB, conformidade LGPD Art. 11 para biometria e ícones adaptativos na *Safe-Zone*. |
| `17` | [`registro_dominio_resend.md`](registro_dominio_resend.md) | Infraestrutura de Mensageria e DNS | Arquitetura de envio de e-mails transacionais e códigos OTP via Resend + Supabase Auth e configuração criptográfica de registros DNS (`DKIM`, `SPF`, `DMARC`). |
| `18` | [`ROADMAP.md`](ROADMAP.md) | Planejamento Evolutivo (`gantt`) | Linha do tempo técnica das fases concluídas até novembro de 2026 e horizontes futuros (expansão B2B imobiliárias/seguradoras e IA preditiva). |
| `19` | [`CHANGELOG.md`](CHANGELOG.md) | Registro Cronológico de Versões | Histórico auditável de todas as versões (`v1.1.0` a `v2.8.1`), migrações SQL, correções de visão computacional e otimizações de performance. |
| `20` | [`Template.md`](Template.md) | Padrão Metadocumental Científico | Modelo estrutural normativo (cabeçalho técnico, resumo, fundamentação matemática, especificação de código, complexidade *Big-O* e checklist) para novos documentos. |

---

## 3. Catálogo das 5 Subpastas Especializadas de `docs/`

1. **[`docs/adr/`](adr/README.md) — *Architecture Decision Records* (`ADR-0000` a `ADR-0020`)**:
   - Registro histórico imutável das 20 decisões arquiteturais do projeto, culminando no [`ADR-0020`](adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md) (Fundo de Garantia em 3 Camadas, Motor Antifraude $O(1)/O(\log N)$ e KYC Biométrico Ao Vivo com Scanner ISO ID-1 e OCR).
2. **[`docs/planilhas/`](planilhas/) — Modelagem Quantitativa em CSV**:
   - Contém [`bsc_desperrengue.csv`](planilhas/bsc_desperrengue.csv) (métricas do Balanced Scorecard) e [`fluxo_de_caixa_12m.csv`](planilhas/fluxo_de_caixa_12m.csv) (projeção financeira de 12 meses com *Smart Split* e *Carve-out* de $1,5\%$).
3. **[`docs/setup/`](setup/) — Guias de Provisionamento por Sistema Operacional**:
   - Procedimentos detalhados de instalação de *toolchains* para [`windows.md`](setup/windows.md), [`linux.md`](setup/linux.md) e [`macos.md`](setup/macos.md).
4. **[`docs/specs/`](specs/) — Especificações Analíticas de Telas**:
   - Fichas técnicas detalhadas das interfaces em [`cliente_telas.md`](specs/cliente_telas.md), [`profissional_telas.md`](specs/profissional_telas.md) e [`comum_telas.md`](specs/comum_telas.md).
5. **[`docs/ui_ux/hi-fi_prototyping/`](ui_ux/hi-fi_prototyping/) — Acervo de Prototipação de Alta Fidelidade**:
   - Artefatos visuais organizados por jornada operacional (`0_telas_de_login` a `7_Gestao_de_Perfil_e_Gamificacao`, `cliente/` e `profissional/`).

---

## 4. Matriz de Leitura Recomendada por Perfil Técnico

| Perfil do Leitor / Auditor | Sequência de Leitura Recomendada |
| :--- | :--- |
| **Arquitetos de Software e Engenheiros de Sistemas Distribuídos** | [`../README.md`](../README.md) $\to$ [`ARCHITECTURE.md`](ARCHITECTURE.md) $\to$ [`Arquitetura do Sistema.md`](Arquitetura%20do%20Sistema.md) $\to$ [`adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md`](adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md) |
| **Especialistas em Segurança, Criptografia e Visão Computacional** | [`onboarding_profissional.md`](onboarding_profissional.md) $\to$ [`../.github/SECURITY.md`](../.github/SECURITY.md) $\to$ [`TESTING.md`](TESTING.md) |
| **Auditores Financeiros, Economistas e Avaliadores de Negócios** | [`Documento de Contexto.md`](Documento%20de%20Contexto.md) $\to$ [`Planos de Negocio e Tributação.md`](Planos%20de%20Negocio%20e%20Tributa%C3%A7%C3%A3o.md) $\to$ [`Fluxo de Caixa.md`](Fluxo%20de%20Caixa.md) $\to$ [`Balanced Scorecard (BSC).md`](Balanced%20Scorecard%20(BSC).md) |
| **Engenheiros de Qualidade (QA) e Homologadores Mobile** | [`SETUP.md`](SETUP.md) $\to$ [`TESTING.md`](TESTING.md) $\to$ [`TESTE_COM_AMIGOS.md`](TESTE_COM_AMIGOS.md) $\to$ [`PLAY_STORE.md`](PLAY_STORE.md) |

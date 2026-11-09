# Índice Geral da Documentação Técnico-Científica — Desperrengue

Catálogo estruturado de todos os artefatos documentais do repositório **Desperrengue**. Para a síntese executiva e matemática dos oito domínios arquiteturais do sistema, consulte o [README principal na raiz do repositório](../README.md).

> **Diretrizes de Padronização.** Os documentos de engenharia adotam nomenclatura em `MAIÚSCULAS.md` ou `kebab-case.md`, enquanto os entregáveis acadêmicos preservam a denominação curricular das etapas do projeto. A integridade referencial de todos os links relativos é verificada automaticamente no pipeline de integração contínua (`node scripts/check-md-links.mjs`).

---

## 1. Guia de Entrada e Governança de Engenharia

| Documento | Escopo Técnico |
| :--- | :--- |
| [SETUP.md](SETUP.md) | Configuração do ambiente de desenvolvimento, variáveis `--dart-define`, execução do cliente Flutter e conexão com o Supabase. |
| [CONTRIBUTING.md](../.github/CONTRIBUTING.md) | Fluxo de trabalho Git (*Trunk-Based Development*), *Conventional Commits*, Definição de Pronto (DoD) e regras para migrações SQL. |
| [TESTING.md](TESTING.md) | Estratégia de verificação em pirâmide: `529` testes automatizados em Dart/Widgets/Visão Computacional/*Red Team*, `577` asserções SQL e `17` testes de PDF. |
| [SECURITY.md](../.github/SECURITY.md) | Política de segurança da informação (ISO/IEC 27001 e ISO/IEC 29147), modelo de ameaças, controles antifraude e conformidade LGPD. |
| [CODE_OF_CONDUCT.md](../.github/CODE_OF_CONDUCT.md) | Normas de conduta e colaboração técnica. |
| Guias por Sistema Operacional | [Windows](setup/windows.md) · [macOS](setup/macos.md) · [Linux](setup/linux.md) |

---

## 2. Arquitetura de Software, Banco de Dados e Visão Computacional

| Documento | Escopo Técnico |
| :--- | :--- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Especificação arquitetural completa: arquitetura em 4 camadas, diagramas C4, modelo relacional de 21 migrações, Fundo de Garantia em 3 Camadas, mitigação dos 6 vetores de fraude, resolução do Marco Zero, biometria facial ativa ($YCbCr$), scanner ISO ID-1 com OCR e complexidade assintótica ($O(1)$ / $O(\log N)$). |
| [Arquitetura do Sistema.md](Arquitetura%20do%20Sistema.md) | Documento arquitetural consolidado: justificativa da stack tecnológica, contêineres C4, invariantes transacionais e pipeline CI/CD. |
| [Registros de Decisão de Arquitetura (ADRs 0001–0020)](adr/README.md) | Histórico imutável de decisões estruturais, incluindo o [ADR-0020](adr/0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md) (Garantia 3 Camadas, Motor Antifraude e KYC Biométrico/OCR). |
| [App Flutter (`../app/README.md`)](../app/README.md) | Organização dos pacotes em `app/lib/`, *Worker Isolates*, componentes da 4ª aba *"Em Mediação"* e carteira bipartida. |
| [Backend Supabase (`../supabase/README.md`)](../supabase/README.md) | Esquema relacional, livros-razão imutáveis, funções matemáticas $O(1)$, índices B-Tree/GIN e RPCs `SECURITY DEFINER`. |
| [Onboarding e Verificação KYC](onboarding_profissional.md) | Arquitetura de captura documental, prova de vida facial ativa (*Active Liveness*), scanner guiado ISO/IEC 7810 ID-1, *Face Match* 128-D e transcrição OCR. |

---

## 3. Produto, Reputação Bayesiana e Economia de Incentivos

| Documento | Escopo Técnico |
| :--- | :--- |
| [ROADMAP.md](ROADMAP.md) | Planejamento evolutivo de curto, médio e longo prazo e rastreamento de épicos concluídos. |
| [GAMIFICACAO.md](GAMIFICACAO.md) | Conquistas escalonadas (90 medalhas), ranqueamento por Média Bayesiana Empírica, multiplicador de SLA limitado e modelagem de *unit economics*. |
| [CHANGELOG.md](CHANGELOG.md) | Registro cronológico e semântico de todas as versões, funcionalidades e correções de segurança (até a `v2.8.1+202611082`). |

---

## 4. Modelagem de Negócios, Estratégia e Finanças

| Documento | Escopo Técnico |
| :--- | :--- |
| [Documento de Contexto.md](Documento%20de%20Contexto.md) | Formulação do problema de assimetria de informação, solução proposta, Lean Canvas e diretrizes estratégicas. |
| [Especificação do Projeto.md](Especificação%20do%20Projeto.md) | Modelagem de personas, histórias de usuário, requisitos funcionais (RF) e não-funcionais (RNF). |
| [Planos de Negocio e Tributação.md](Planos%20de%20Negocio%20e%20Tributação.md) | Estrutura de custos, enquadramento tributário no Simples Nacional (CNAE `7490-1/04`), *Smart Split* ($0\%$ sobre insumos) e reserva de garantia ($1,5\%$). |
| [Analise de Ambientes e SWOT.md](Analise%20de%20Ambientes%20e%20SWOT.md) | Análise macroambiental PESTEL, *benchmarking* competitivo, Matriz SWOT e estratégias cruzadas contra *bypass* e fraude. |
| [Balanced Scorecard (BSC).md](Balanced%20Scorecard%20(BSC).md) · [CSV](planilhas/bsc_desperrengue.csv) | Mapa estratégico de causa e efeito e 16 objetivos distribuídos nas 4 perspectivas de Kaplan e Norton. |
| [Fluxo de Caixa.md](Fluxo%20de%20Caixa.md) · [CSV](planilhas/fluxo_de_caixa_12m.csv) | Projeção financeira de 12 meses, ponto de equilíbrio (*break-even*), *payback* e eficiência fiscal do *split*. |

---

## 5. Projeto de Interface, Design System e Operação

| Documento | Escopo Técnico |
| :--- | :--- |
| [Projeto de Interface.md](Projeto%20de%20Interface.md) | Fluxograma completo de telas (*User Flow*), rastreabilidade entre protótipos e implementação Flutter, onboarding biométrico e mediação. |
| [Template.md](Template.md) | Sistema de tokens semânticos (`AppTokens`), tematização dinâmica por modo (Laranja/Azul), modo escuro WCAG e catálogo de componentes. |
| [Fichas Analíticas de Telas](specs/cliente_telas.md) | [Jornada do Cliente](specs/cliente_telas.md) · [Jornada do Profissional](specs/profissional_telas.md) · [Telas Comuns](specs/comum_telas.md) · [Protótipos Hi-Fi](ui_ux/hi-fi_prototyping/) |
| [Publicação na Google Play](PLAY_STORE.md) | Procedimentos de assinatura `.aab`, trilha de teste interno e declarações de segurança de dados. |
| [Distribuição Beta e Testes em Campo](TESTE_COM_AMIGOS.md) | Entrega contínua via GitHub Releases / GitHub Pages (PWA) e atualização in-app (`UpdateGate`). |
| [Autenticação de Domínio e E-mail Transacional](registro_dominio_resend.md) | Configuração de registros DNS (SPF, DKIM e DMARC) para o domínio `desperrengue.tech` no serviço Resend. |

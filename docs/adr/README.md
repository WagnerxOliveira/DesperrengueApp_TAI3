# Architecture Decision Records (ADR)

Registro histórico e normativo das decisões arquiteturalmente significativas do sistema **Desperrengue**, estruturado segundo o modelo de Michael Nygard (*Title, Status, Context, Decision, Consequences*) estendido com **alternativas avaliadas** e **critérios formais de verificação**.

## Diretrizes de Governança Documental

1. **Imutabilidade Histórica:** Um registro ADR aceito preserva o contexto decisório de sua época. Quando uma decisão evolui ou é ampliada, registra-se um **novo ADR** com referência explícita aos documentos precedentes.
2. **Nomenclatura Canônica:** Numeração sequencial de quatro dígitos no formato `NNNN-titulo-em-kebab-case.md`.
3. **Critério de Relevância:** Formaliza-se um ADR sempre que uma decisão impacta invariantes de segurança, esquema relacional, complexidade algorítmica, contratos entre camadas ou sustentabilidade econômica do marketplace.
4. **Verificação Automatizada:** Todos os hiperlinks internos entre ADRs e especificações são auditados continuamente pelo script `node scripts/check-md-links.mjs` no pipeline de integração contínua.
5. **Modelo Base:** [`0000-modelo.md`](0000-modelo.md).

## Índice de Decisões Arquiteturais

| ADR | Título | Status | Data |
| :-- | :-- | :-- | :-- |
| [0001](0001-baas-supabase-como-backend.md) | Supabase (BaaS) como backend relacional e transacional único | Aceito | 2026-09-19 |
| [0002](0002-flutter-como-cliente-movel-unico.md) | Flutter como cliente multiplataforma (Android, iOS e Web/PWA) | Aceito | 2026-09-19 |
| [0003](0003-regras-de-negocio-no-banco-via-rpc.md) | Regras de negócio no banco via RLS, *triggers* e RPCs `SECURITY DEFINER` | Aceito | 2026-10-09 |
| [0004](0004-unificacao-de-perfis-e-nomes-em-ingles.md) | Unificação de perfis em `public.profiles` e identificadores em inglês | Aceito | 2026-10-09 |
| [0005](0005-modelo-multi-modo-por-flags.md) | Modelo multi-modo (Cliente e Profissional) por *flags* booleanas | Aceito | 2026-10-19 |
| [0006](0006-pagamento-mock-com-custodia-e-pin.md) | Pagamento em custódia (*escrow*) e liberação presencial por PIN | Aceito (ampliado por 0018 e 0020) | 2026-10-19 |
| [0007](0007-privacidade-por-minimizacao-de-dados.md) | Privacidade por minimização: tabelas segregadas, trava temporal e *views* | Aceito (ampliado por 0022) | 2026-10-19 |
| [0008](0008-migrations-sem-docker-e-teste-transacional.md) | *Migrations* versionadas e bateria de testes SQL transacionais abortados | Aceito | 2026-10-09 |
| [0009](0009-roteamento-por-funcao-pura-e-authgate.md) | Roteamento determinístico por função pura (`destinationFor`) e `AuthGate` | Aceito | 2026-10-09 |
| [0010](0010-webhook-autenticado-por-segredo-no-vault.md) | *Webhook* do banco para Edge Function autenticado por segredo no Vault | Aceito | 2026-10-09 |
| [0011](0011-avaliacoes-cegas-bayes-e-selos.md) | Avaliações bidirecionais cegas, ranqueamento Bayesiano e selos automáticos | Aceito | 2026-10-23 |
| [0012](0012-conquistas-do-profissional.md) | Conquistas escalonadas: catálogo no cliente e desbloqueio por *trigger* | Aceito | 2026-10-23 |
| [0013](0013-exclusao-de-conta-lgpd-e-dossie.md) | Exclusão de conta escopada (LGPD) com trava financeira e Dossiê em PDF | Aceito | 2026-10-29 |
| [0014](0014-design-tokens-e-modo-escuro.md) | Design tokens semânticos, tema tri-state e modo escuro com contraste WCAG | Aceito | 2026-10-29 |
| [0015](0015-abertura-do-app-splash-init-e-sessao-segura.md) | Abertura do app: splash coreografada, init paralela e sessão segura | Aceito | 2026-10-29 |
| [0016](0016-vitrine-de-cases-lifo.md) | Vitrine de cases (portfólio LIFO), curadoria e Case de Sucesso | Aceito | 2026-10-29 |
| [0017](0017-distribuicao-beta-e-atualizacao-no-app.md) | Distribuição contínua (APK Beta / PWA) e verificação de atualização in-app | Aceito | 2026-10-29 |
| [0018](0018-carteira-ledger-e-pix-sandbox.md) | Carteira do cliente, livro-razão de partida dobrada e Pix sandbox | Aceito | 2026-10-29 |
| [0019](0019-agendamento-geofence-chat-dossies.md) | Serviço agendado vs. em execução, dupla trava (relógio + Haversine) e dossiês | Aceito (ampliado por 0022) | 2026-11-05 |
| [0020](0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md) | Fundo de Garantia em 3 Camadas, Motor Antifraude $O(1)/O(\log N)$ e KYC Biométrico/OCR | Aceito (ampliado por 0021) | 2026-11-08 |
| [0021](0021-arquitetura-kyc-zero-trust-argon-carbon.md) | Arquitetura KYC Zero-Trust Híbrida (Argon High + Carbon High), Criptografia VIO/ICP-Brasil, Anti-Swap 180s e SHAP LGPD | Aceito | 2026-11-12 |
| [0022](ADR-0022-temporal-geo-privacy-lock.md) | Trava Temporal e Espacial de Privacidade Geográfica (*Temporal & Spatial Geo-Privacy Lock*), HMAC-SHA256 Server-Side e Sanitização EXIF (LGPD) | Aceito | 2026-11-12 |
| [0023](0023-founder-sovereign-cockpit-dual-apk.md) | Cockpit Soberano do Fundador (*Founder Sovereign Cockpit & War Room*), Isolamento Físico Dual-APK Zero-Footprint, Trava de 3 Delegados, Contabilidade CPC 47 (`BIGINT`) e 5 Motores de Programação Dinâmica | Aceito | 2026-11-14 |

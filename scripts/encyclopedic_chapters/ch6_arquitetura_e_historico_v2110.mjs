import {
  svgC4ContextAndContainers,
  svgCleanArchitecture4Layers,
  svgGeoPrivacyAndEscrowSequence,
  svgKycZeroTrustArchitecture,
} from './svg_ch5_ch6_ux_arch.mjs';

export const ch6Html = String.raw`
<!-- ======================================================================= -->
<!-- CAPÍTULO 6 — ARQUITETURA DE SOFTWARE COMPLETA E HISTÓRICO ATÉ v2.11.0   -->
<!-- ======================================================================= -->
<section class="chapter-section" id="cap-6">
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 6</div>
  <div class="cb-body">
    <h2>ARQUITETURA DE SOFTWARE COMPLETA E HISTÓRICO PASSO A PASSO DE TUDO O QUE FOI CONSTRUÍDO NO PROJETO ATÉ A v2.11.0</h2>
    <p>Descrição arquitetural normatizada segundo a ISO/IEC/IEEE 42010:2022 (Modelo C4 Níveis 1–3, Catálogo ADR-0001..0022 e Clean Architecture em 4 Camadas a 120 FPS), engenharia relacional das 27 migrações PostgreSQL 17, catálogo de RPCs SECURITY DEFINER, 4 invariantes contábeis BIGINT, 9 blindagens Red Team, Geo-Privacy Lock, KYC Zero-Trust e memorial passo a passo em 9 fases evolutivas até a v2.11.0.</p>
  </div>
</div>

<p>
  Este capítulo final consolida a materialização física, algorítmica, criptográfica e transacional de todos os fundamentos epistemológicos, econômicos, normativos e ergonômicos desenvolvidos nos Capítulos 1 a 5. Toda especificação aqui formalizada corresponde biunivocamente ao código-fonte real de produção no repositório oficial (<code>c:/00_Desperrengue</code>), abrangendo o cliente unificado multiplataforma em Flutter/Dart (<code>app/lib/</code>), o núcleo relacional e geoespacial em PostgreSQL 17 (<code>supabase/migrations/</code>), a malha serverless em Deno/TypeScript (<code>supabase/functions/</code>) e o microsserviço criptográfico de visão computacional e biometria governamental em Python/FastAPI (<code>kyc_engine/</code>).
</p>

<!-- ======================================================================= -->
<!-- SEÇÃO 6.1                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-6-1">
  <span class="sh-tag">SEÇÃO 6.1 &bull; ISO/IEC/IEEE 42010, ADRs 0001–0022, MODELO C4 (L1–L3) E CLEAN ARCHITECTURE</span>
  <h2>6.1. Arquitetura de Software Segundo a Norma ISO/IEC/IEEE 42010, C4 Model (Contexto, Containers e Componentes) e Clean Architecture em 4 Camadas</h2>
  <p>Visões arquiteturais padronizadas, catálogo integral dos 22 ADRs, topologia distribuída de containers e componentes internos, orquestração gráfica a 120 FPS (8,33 ms/quadro), cache de 0 ms e Isolates Tier-0.</p>
</div>

<h3 id="sec-6-1-1">6.1.1. Enquadramento Normativo ISO/IEC/IEEE 42010:2022 e Pontos de Vista Arquiteturais</h3>
<p>
  Em estrita observância à norma internacional <strong>ISO/IEC/IEEE 42010:2022</strong> (<em>Systems and software engineering &mdash; Architecture description</em>), a arquitetura do ecossistema Desperrengue é decomposta em quatro <strong>Pontos de Vista Arquiteturais</strong> (<em>Architecture Viewpoints</em>) ortogonais, cada qual endereçando um subconjunto explícito de <strong>Preocupações</strong> (<em>Concerns</em>) manifestadas pelas <strong>Partes Interessadas</strong> (moradores contratantes, profissionais autônomos/MEIs, engenharia de segurança <em>Red Team</em>, auditoria contábil/fiscal e autoridade regulatória LGPD). A Tabela 6.1 sintetiza essa correspondência estrutural.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="20%">Ponto de Vista (ISO 42010)</th>
      <th width="24%">Partes Interessadas &amp; Preocupações</th>
      <th width="28%">Modelos e Representações Adotados</th>
      <th width="28%">Registros de Decisão Chave (<span class="mono">docs/adr/</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Visão de Contexto, Containers e Componentes (C4 L1–L3)</strong></td>
      <td>Arquitetos de sistemas, operações DevSecOps e auditores externos: fronteiras de confiança, protocolos TLS/mTLS e soberania de dados.</td>
      <td>Modelo C4 em 3 níveis (Contexto Sistêmico, Topologia de Containers Distribuídos e Decomposição Interna de Componentes).</td>
      <td><code>ADR-0001</code>, <code>ADR-0002</code>, <code>ADR-0004</code>, <code>ADR-0005</code>, <code>ADR-0021</code>.</td>
    </tr>
    <tr>
      <td><strong>Visão em Camadas e Concorrência (Clean Arch)</strong></td>
      <td>Engenheiros mobile/web: desacoplamento do domínio, testabilidade determinística, fluidez a <code>120 FPS</code> e ausência de bloqueio da <em>UI thread</em>.</td>
      <td>Arquitetura Limpa em 4 Camadas Concêntricas com inversão de dependência e offload paralelo em <code>Isolate.run</code> (<code>off_thread.dart</code>).</td>
      <td><code>ADR-0009</code>, <code>ADR-0014</code>, <code>ADR-0015</code>, <code>ADR-0016</code>, <code>ADR-0017</code>, <code>ADR-0020</code>.</td>
    </tr>
    <tr>
      <td><strong>Visão Transacional, Contábil e Concorrente</strong></td>
      <td>Engenharia financeira e jurídica: exatidão em centavos, eliminação de <em>race conditions</em>, solvência do fundo de garantia e conformidade CPC 47.</td>
      <td>Escrituração de partidas dobradas em <code>BIGINT</code>, 4 invariantes de <code>warranty_pool_ledger</code> e grafo acíclico de locks <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span>.</td>
      <td><code>ADR-0003</code>, <code>ADR-0006</code>, <code>ADR-0008</code>, <code>ADR-0011</code>, <code>ADR-0012</code>, <code>ADR-0018</code>, <code>ADR-0019</code>, <code>ADR-0020</code>.</td>
    </tr>
    <tr>
      <td><strong>Visão Criptográfica e Privacidade Zero-Trust</strong></td>
      <td>Moradores, profissionais e encarregado LGPD: sigilo de endereço domiciliar, proteção anti-coação, não-repúdio ICP-Brasil e expurgo portável.</td>
      <td>Esquema isolado <code>private.*</code>, <code>HMAC-SHA256</code> espacial/temporal, Cofre Dual Anti-Coação, sanitização EXIF e cofre WORM <code>AES-256-GCM</code>.</td>
      <td><code>ADR-0007</code>, <code>ADR-0010</code>, <code>ADR-0013</code>, <code>ADR-0021</code>, <code>ADR-0022</code>.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-1-2">6.1.2. Catálogo Completo dos Registros de Decisão Arquitetural (<span class="mono">ADR-0001</span> a <span class="mono">ADR-0022</span>)</h3>
<p>
  Todas as vinte e duas decisões arquiteturais estruturantes do projeto encontram-se formalmente versionadas em <code>docs/adr/</code> seguindo o molde canônico de Michael Nygard (Contexto, Decisão, Alternativas Rejeitadas e Consequências). A Tabela 6.2 apresenta o catálogo integral auditado de <code>ADR-0001</code> a <code>ADR-0022</code>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="9%">ID ADR</th>
      <th width="34%">Arquivo Físico Real (<span class="mono">docs/adr/</span>)</th>
      <th width="29%">Decisão Arquitetural Institucionalizada</th>
      <th width="28%">Racional Técnico e Consequência Sistêmica</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>ADR-0001</code></td>
      <td><code>0001-baas-supabase-como-backend.md</code></td>
      <td>Adoção do PostgreSQL 17 gerenciado (Supabase <code>sa-east-1</code>) com Auth, PostgREST, Realtime e Storage integrados.</td>
      <td>Reduz latência nacional (&lt;25 ms no Sudeste), provê ACID relacional nativo e unifica autenticação JWT com <code>RLS</code> no kernel do banco.</td>
    </tr>
    <tr>
      <td><code>ADR-0002</code></td>
      <td><code>0002-flutter-como-cliente-movel-unico.md</code></td>
      <td>Base única de código em Flutter/Dart compilada nativamente para Android (APK) e Web responsiva (PWA).</td>
      <td>Elimina divergência de regras entre plataformas, habilita rasterização determinística a 120 Hz e unifica 762+ testes de domínio/UI.</td>
    </tr>
    <tr>
      <td><code>ADR-0003</code></td>
      <td><code>0003-regras-de-negocio-no-banco-via-rpc.md</code></td>
      <td>Concentração de transições críticas de estado e validações financeiras em <em>stored procedures</em> PL/pgSQL.</td>
      <td>Garante atomicidade transacional sob premissa <em>untrusted client</em>, impedindo manipulação de estados por clientes adulterados.</td>
    </tr>
    <tr>
      <td><code>ADR-0004</code></td>
      <td><code>0004-unificacao-de-perfis-e-nomes-em-ingles.md</code></td>
      <td>Unificação identitária em <code>public.profiles</code> (<code>id = auth.uid()</code>) e padronização do esquema SQL em inglês técnico.</td>
      <td>Extingue duplicação cadastral entre tabelas separadas e previne ambiguidades de junção referencial.</td>
    </tr>
    <tr>
      <td><code>ADR-0005</code></td>
      <td><code>0005-modelo-multi-modo-por-flags.md</code></td>
      <td>Arquitetura <em>Multi-Mode</em> por papéis habilitados na mesma conta (<code>client &harr; provider</code> via <code>enroll_mode</code>).</td>
      <td>Permite que qualquer morador atue como prestador (e vice-versa) sem segundo login, herdando verificação KYC já homologada.</td>
    </tr>
    <tr>
      <td><code>ADR-0006</code></td>
      <td><code>0006-pagamento-mock-com-custodia-e-pin.md</code></td>
      <td>Desenho inicial da máquina de estados de custódia condicionada a PIN presencial de 4 dígitos.</td>
      <td>Estabeleceu o contrato formal de aceite físico presencial posteriormente evoluído para o ledger <code>BIGINT</code> e cofre privado.</td>
    </tr>
    <tr>
      <td><code>ADR-0007</code></td>
      <td><code>0007-privacidade-por-minimizacao-de-dados.md</code></td>
      <td>Princípio de <em>Privacy by Design</em> e minimização de exposição de dados pessoais (LGPD Art. 6º, III).</td>
      <td>Restringe payloads públicos ao estritamente necessário, preparando a separação entre <code>jobs</code>, <code>job_addresses</code> e <code>private.*</code>.</td>
    </tr>
    <tr>
      <td><code>ADR-0008</code></td>
      <td><code>0008-migrations-sem-docker-e-teste-transacional.md</code></td>
      <td>Migrações SQL sequenciais puras e suítes de fumaça transacionais (<code>BEGIN ... ROLLBACK</code>) auto-verificáveis.</td>
      <td>Permite auditoria determinística completa do esquema SQL em qualquer ambiente CI/CD sem dependências pesadas.</td>
    </tr>
    <tr>
      <td><code>ADR-0009</code></td>
      <td><code>0009-roteamento-por-funcao-pura-e-authgate.md</code></td>
      <td>Roteamento pós-autenticação governado por funções puras testáveis (<code>auth_gate.dart</code> e <code>post_auth_router.dart</code>).</td>
      <td>Torna determinística a navegação entre onboarding KYC, modo Cliente, modo Profissional e fluxos de recuperação.</td>
    </tr>
    <tr>
      <td><code>ADR-0010</code></td>
      <td><code>0010-webhook-autenticado-por-segredo-no-vault.md</code></td>
      <td>Autenticação de <em>webhooks</em> serverless mediante segredos simétricos verificados em tempo constante.</td>
      <td>Bloqueia falsificação de eventos de aprovação de e-mail, liquidação PIX e vereditos assíncronos de KYC.</td>
    </tr>
    <tr>
      <td><code>ADR-0011</code></td>
      <td><code>0011-avaliacoes-cegas-bayes-e-selos.md</code></td>
      <td>Avaliações bilaterais duplo-cegas reveladas simultaneamente e ranking ponderado por média Bayesiana empírica.</td>
      <td>Neutraliza notas retaliatórias e corrige distorções estatísticas de prestadores recém-ingressos com poucas amostras.</td>
    </tr>
    <tr>
      <td><code>ADR-0012</code></td>
      <td><code>0012-conquistas-do-profissional.md</code></td>
      <td>Sistema determinístico de gamificação em múltiplos eixos e dez degraus logarítmicos (<code>1</code> a <code>10.000</code>).</td>
      <td>Substitui bonificações arbitrárias por progressão meritocrática auditável via gatilho pós-serviço (expandida a 112 medalhas).</td>
    </tr>
    <tr>
      <td><code>ADR-0013</code></td>
      <td><code>0013-exclusao-de-conta-lgpd-e-dossie.md</code></td>
      <td>Direito de exclusão escopada precedido pela emissão e envio obrigatório de Dossiê PDF A4 portável (<code>dossie.ts</code>).</td>
      <td>Concilia os Arts. 16 e 18 da LGPD: entrega portabilidade integral ao titular e aborta a deleção se o envio por e-mail falhar.</td>
    </tr>
    <tr>
      <td><code>ADR-0014</code></td>
      <td><code>0014-design-tokens-e-modo-escuro.md</code></td>
      <td>Sistema semântico de tokens visuais (<code>app_tokens.dart</code>) ancorado na paleta <em>Quiet Luxury Dark Mode</em>.</td>
      <td>Assegura contraste WCAG 2.1 AA/AAA, distinção cromática imediata entre Cliente (laranja) e Profissional (azul) e fadiga ocular mínima.</td>
    </tr>
    <tr>
      <td><code>ADR-0015</code></td>
      <td><code>0015-abertura-do-app-splash-init-e-sessao-segura.md</code></td>
      <td>Inicialização assíncrona resiliente (<code>app_initialization_service.dart</code>) e armazenamento seguro de sessão.</td>
      <td>Elimina telas brancas de partida a frio e protege tokens de sessão contra corrupção ou travamento em redes degradadas.</td>
    </tr>
    <tr>
      <td><code>ADR-0016</code></td>
      <td><code>0016-vitrine-de-cases-lifo.md</code></td>
      <td>Portfólio profissional real imutável pós-conclusão com ordenação LIFO Top-3 somada a até 5 destaques curados.</td>
      <td>Impede vitrines enganosas com fotos externas não vinculadas a serviços reais auditados na plataforma.</td>
    </tr>
    <tr>
      <td><code>ADR-0017</code></td>
      <td><code>0017-distribuicao-beta-e-atualizacao-no-app.md</code></td>
      <td>Atualização <em>Over-The-Air</em> (OTA) via manifesto assinado e <em>host pinning</em> estrito em domínios oficiais do GitHub.</td>
      <td>Viabiliza evolução ágil do APK Android e expurgo sincronizado de <em>ServiceWorker</em> PWA sem risco de <em>supply-chain</em>.</td>
    </tr>
    <tr>
      <td><code>ADR-0018</code></td>
      <td><code>0018-carteira-ledger-e-pix-sandbox.md</code></td>
      <td>Carteira digital baseada em livro-razão de partidas dobradas em centavos <code>BIGINT</code> e cobrança PIX EMV BR Code CRC16.</td>
      <td>Extingue erros binários IEEE 754 e garante conservação contábil estrita (<code>&Sigma; cents = 0</code>) com chaves de idempotência.</td>
    </tr>
    <tr>
      <td><code>ADR-0019</code></td>
      <td><code>0019-agendamento-geofence-chat-dossies.md</code></td>
      <td>Separação formal entre agendamento futuro e início presencial validado por geofence esférico Haversine + dossiês bilaterais.</td>
      <td>Impede início remoto fictício de serviços presenciais e bloqueia evasão prematura de contatos no chat.</td>
    </tr>
    <tr>
      <td><code>ADR-0020</code></td>
      <td><code>0020-garantia-3-camadas-antifraude-e-kyc-biometrico-ocr.md</code></td>
      <td>Fundo Garantidor de <code>1,5%</code> em 3 camadas, <em>Smart Split</em> <code>0%</code> peças e triagem biométrica/OCR Tier-0 em <code>Isolate.run</code>.</td>
      <td>Viabiliza garantia real de 90 dias (CDC) com solvência atuarial (<code>66,67</code> OS) e custo marginal zero na triagem local.</td>
    </tr>
    <tr>
      <td><code>ADR-0021</code></td>
      <td><code>0021-arquitetura-kyc-zero-trust-argon-carbon.md</code></td>
      <td>Pipeline KYC híbrido combinando Gemini 4 Argon High, validação VIO/ICP-Brasil + SERPRO mTLS 1.3 e Gemini 4 Carbon High SHAP.</td>
      <td>Une rigor criptográfico governamental contra falsificação documental à explicabilidade algorítmica exigida pelo Art. 20 da LGPD.</td>
    </tr>
    <tr>
      <td><code>ADR-0022</code></td>
      <td><code>0022-temporal-geo-privacy-lock.md</code></td>
      <td>Protocolo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> com <code>HMAC-SHA256</code> (256 bits em <code>private.*</code>) até as <code>00:00</code> do dia agendado.</td>
      <td>Suprime rua/número/GPS exato no servidor antes da meia-noite local (<code>America/Sao_Paulo</code>) do atendimento e re-ofusca após conclusão.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-1-3">6.1.3. Modelo C4 — Níveis 1 e 2: Contexto Sistêmico e Topologia de Containers Distribuídos</h3>
<p>
  O ecossistema opera sob uma topologia distribuída orientada a contratos estritos, na qual o terminal móvel/web atua sob premissa <em>Zero-Trust</em> (<em>untrusted client</em>), delegando 100% das decisões de autorização, custódia fiduciária, ofuscação espacial e homologação biométrica às camadas de servidor protegidas por criptografia autenticada. A Figura 6.1 (<code>#fig-15</code>) apresenta o contexto sistêmico externo e os cinco containers internos de execução.
</p>

<div class="svg-diagram-box">
  ${svgC4ContextAndContainers}
  <div class="svg-caption">Figura 6.1 — Arquitetura Distribuída C4 (Contexto Sistêmico e Containers): Aplicativo Unificado Flutter 3.47 (Android OTA &amp; PWA 480px), Núcleo PostgreSQL 17 com Esquema Isolado <code>private.*</code>, Malha das 5 Deno Edge Functions Reais, Microsserviço Python FastAPI <code>kyc_engine</code> e Integrações Governamentais/Financeiras.</div>
</div>

<p>
  A Tabela 6.3 detalha o papel operacional e as garantias de fronteira de cada container e das cinco funções serverless em <code>supabase/functions/</code>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Container / Função Real</th>
      <th width="18%">Tecnologia &amp; Runtime</th>
      <th width="60%">Contrato Arquitetural, Segurança de Fronteira e Responsabilidades</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Aplicativo Unificado Multi-Modo</strong><br/>(<code>app/lib/</code>)</td>
      <td>Flutter <code>3.47</code> / Dart <code>3.13</code> (Android APK + PWA Web)</td>
      <td>Interface única para Cliente e Profissional com chaveamento instantâneo de papel (<code>enroll_mode</code> / <code>set_last_mode</code>), orçamento gráfico de <code>8,33 ms/quadro</code> (<code>120 FPS</code>), container responsivo de <code>480px</code>, pré-triagem biométrica local em <code>Isolate.run</code>, emissão offline do Passaporte ABNT NBR 5674 e atualização OTA segura (<code>app_version_and_update_service.dart</code>).</td>
    </tr>
    <tr>
      <td><strong>Núcleo Transacional, Geoespacial e Realtime</strong><br/>(<code>supabase/migrations/</code>)</td>
      <td>PostgreSQL <code>17</code> + PostgREST + GoTrue + Realtime (<code>sa-east-1</code>)</td>
      <td>Autoridade única de estado ACID, autenticação JWT (<code>auth.uid()</code>), políticas estritas de <em>Row Level Security</em> (<code>RLS</code> e <code>FORCE RLS</code>), cofres internos <code>private.geo_privacy_secrets</code> e <code>private.job_forensic_secrets</code>, livros-razão em centavos <code>BIGINT</code> e difusão assíncrona via WebSockets (<code>supabase_realtime</code>).</td>
    </tr>
    <tr>
      <td><strong>Edge Function 1:</strong><br/><code>enviar-email-aprovacao</code></td>
      <td>Deno / TypeScript (<code>supabase/functions/</code>)</td>
      <td>Autentica gatilho administrativo por segredo em tempo constante (<code>x-webhook-secret</code>) e dispara notificação transacional via API Resend contendo <em>deep link</em> (<code>desperrengue://onboarding/ativar</code>) para ativação imediata do prestador homologado.</td>
    </tr>
    <tr>
      <td><strong>Edge Function 2:</strong><br/><code>excluir-conta</code> (<code>index.ts</code> + <code>dossie.ts</code>)</td>
      <td>Deno / TypeScript + <code>pdf-lib</code> puro</td>
      <td>Implementa o encerramento ético e legal (LGPD Art. 18, V e VI) escopado por papel (<code>client | provider | all</code>): consulta <code>_deletion_blockers</code> e <code>account_dossier</code>, compila em memória o <strong>Dossiê Oficial de Despedida A4</strong> em PDF vetorial, transmite-o ao e-mail do titular e <strong>aborta atomicamente</strong> a chamada a <code>purge_account</code> caso o envio SMTP falhe.</td>
    </tr>
    <tr>
      <td><strong>Edge Function 3:</strong><br/><code>kyc-argon-vision-gate</code></td>
      <td>Deno / TypeScript + Gemini 4 Argon High</td>
      <td>Portão multimodal estruturado invocado com <code>thinkingLevel=&quot;HIGH&quot;</code> e <code>temperature=0.0</code>: executa <em>2D spatial grounding</em> normalizado (<code>[0..1000]</code>), isola texto extraído em delimitador <code>&lt;untrusted_visual_ocr_stream&gt;</code> contra <em>Visual Prompt Injection</em>, opera nos modos <code>kyc_document</code> e <code>smart_split_invoice</code> e converte falhas em orientações humanas sem jargão técnico.</td>
    </tr>
    <tr>
      <td><strong>Edge Function 4:</strong><br/><code>kyc-carbon-webhook</code></td>
      <td>Deno / TypeScript (<code>crypto.subtle</code>)</td>
      <td>Ponte <em>Zero-Trust</em> entre o microsserviço Python e o PostgreSQL: valida assinatura <code>HMAC-SHA256</code> via comparação resistente a ataques de temporização (<code>timingSafeEqual</code>), impõe janela anti-<em>replay</em> estrita (<code>|now &minus; X-KYC-Timestamp| &le; 300 s</code>) e invoca com <code>service_role</code> a RPC idempotente <code>apply_verified_carbon_kyc_verdict</code>.</td>
    </tr>
    <tr>
      <td><strong>Edge Function 5:</strong><br/><code>pix-webhook</code></td>
      <td>Deno / TypeScript</td>
      <td>Receptor autenticado de liquidações do arranjo PIX (<code>x-webhook-secret</code>): converte notificações do PSP em chamadas transacionais idempotentes à RPC <code>confirm_topup</code>, creditando <code>client_wallets.available_cents</code> mediante escrituração de partidas dobradas.</td>
    </tr>
    <tr>
      <td><strong>Microsserviço Criptográfico KYC &amp; Fiscal</strong><br/>(<code>kyc_engine/app/</code>)</td>
      <td>Python <code>3.12+</code> / FastAPI / OpenCV / <code>cryptography</code> / <code>httpx</code></td>
      <td>Expõe <code>GET /healthz</code>, <code>POST /v1/kyc/session/init</code>, <code>POST /v1/kyc/verify-full</code> e <code>POST /v1/smart-split/verify-invoice</code>: executa validação VIO/ICP-Brasil (<code>crypto_doc_validator.py</code>), consulta SERPRO Datavalid mTLS 1.3 (<code>serpro_datavalid.py</code>), orquestra 5 <em>Hard Vetos</em> + Gemini 4 Carbon High SHAP (<code>fraud_orchestrator.py</code>) e grava trilha forense em cofre WORM <code>AES-256-GCM</code> (<code>security.py</code>).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-1-4">6.1.4. Modelo C4 — Nível 3: Decomposição Interna de Componentes (<span class="mono">app/lib/</span>, <span class="mono">supabase/functions/</span> e <span class="mono">kyc_engine/app/</span>)</h3>
<p>
  Descendo ao <strong>Nível 3 do Modelo C4 (Visão de Componentes)</strong>, a Tabela 6.4 mapeia os módulos internos reais que compõem os três subsistemas de código imperativo do repositório, explicitando suas interfaces públicas, algoritmos encapsulados e dependências internas.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="18%">Subsistema / Diretório</th>
      <th width="29%">Módulos / Componentes Reais</th>
      <th width="53%">Responsabilidade Algorítmica, Interfaces e Contratos de Segurança</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Front-End: Núcleo de Segurança &amp; Criptografia</strong><br/>(<code>app/lib/core/security/</code>)</td>
      <td><code>geo_privacy_policy_engine.dart</code>,<br/><code>kyc_session_anti_swap_guard.dart</code>,<br/><code>perceptual_hash_guard.dart</code>,<br/><code>zero_trust_bilateral_security_engine.dart</code></td>
      <td>Interpretação local imutável das 4 fases do <em>Geo-Privacy Lock</em>; guarda anti-troca de sessão entre liveness e envio de documento; cálculo de hash perceptual <code>dHash</code> de 64 bits com ROI central de <code>12%</code> e filtro de textura <code>MAD</code>; e motor do <strong>Cofre Dual Anti-Coação</strong> (PIN reverso), custódia de componentes e cálculo de <em>slashing</em> SOS.</td>
    </tr>
    <tr>
      <td><strong>Front-End: Serviços de Alta Performance &amp; Isolates</strong><br/>(<code>app/lib/core/services/</code>)</td>
      <td><code>instant_image_cache_engine.dart</code>,<br/><code>document_ocr_and_liveness_service.dart</code>,<br/><code>desperrengue_official_pdf_service.dart</code>,<br/><code>real_time_route_and_traffic_service.dart</code>,<br/><code>app_version_and_update_service.dart</code></td>
      <td>Cache de imagem <code>0 ms</code> (L1 RAM <code>96 MB</code> + L2 <code>SharedPreferences</code>, RAM-only p/ <code>storage:</code>) e <code>EagerImagePrefetcher</code>; biometria e OCR Tier-0 em <code>Isolate.run</code>; síntese vetorial <code>%PDF-1.4</code> do Passaporte ABNT NBR 5674; roteamento em cascata dupla OSRM + fallback geodésico <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos; e atualização OTA com <em>host pinning</em> no GitHub.</td>
    </tr>
    <tr>
      <td><strong>Front-End: Utilitários Puros &amp; Controladores O(1)</strong><br/>(<code>app/lib/core/utils/</code> &amp; <code>state/</code>)</td>
      <td><code>money.dart</code>, <code>nfe_access_key.dart</code>,<br/><code>image_metadata_stripper.dart</code>,<br/><code>resilient_stream.dart</code>, <code>off_thread.dart</code>,<br/><code>unread_orders_badge_controller.dart</code></td>
      <td>Aritmética monetária inteira em centavos e rateio pelo maior resto; validação Módulo 11 de chave fiscal de 44 dígitos; extração binária <em>lossless fail-closed</em> de segmentos <code>EXIF/GPS/XMP/IPTC</code>; reconexão WebSocket com <em>backoff</em> exponencial; e decremento otimista <span class="math-inline">O(1)</span> de contadores de pedidos não lidos.</td>
    </tr>
    <tr>
      <td><strong>Front-End: Módulos de Apresentação por Domínio</strong><br/>(<code>app/lib/features/*/presentation/</code>)</td>
      <td><code>detalhe_servico_cliente_screen.dart</code>,<br/><code>order_live_map_modal_screen.dart</code>,<br/><code>geo_privacy_widgets.dart</code>,<br/><code>achievement_widgets.dart</code>,<br/><code>material_receipt_capture_screen.dart</code></td>
      <td>Telas e componentes desacoplados sob container central de <code>480px</code>: cabeçalho de 2 andares sem truncamento em <code>320px/1.4x</code>; mapa ao vivo com &ge;80% de área desobstruída; cards de área protegida <code>500m–800m</code>; forja vetorial das 112 medalhas (<code>#CBD5E1</code> bloqueadas); e captura honesta de notas fiscais (<code>MANUAL_KEY</code> / <code>QR_CODE</code>).</td>
    </tr>
    <tr>
      <td><strong>Microsserviço Python KYC: Camada Core &amp; Schemas</strong><br/>(<code>kyc_engine/app/core/</code> &amp; <code>models/</code>)</td>
      <td><code>main.py</code>, <code>config.py</code>,<br/><code>security.py</code>, <code>schemas_argon.py</code></td>
      <td>Roteador FastAPI assíncrono, validação estrita de variáveis de ambiente e certificados mTLS, emissão/verificação de tokens Anti-Swap HMAC (<code>TTL &le; 180 s</code>), empacotador criptográfico WORM <code>KWV2</code> (<code>HKDF-SHA256</code> + <code>AES-256-GCM</code>) e contratos Pydantic v2 imutáveis para grounding espacial 2D.</td>
    </tr>
    <tr>
      <td><strong>Microsserviço Python KYC: Motores de Verificação</strong><br/>(<code>kyc_engine/app/services/</code>)</td>
      <td><code>vision_ocr_argon.py</code>,<br/><code>crypto_doc_validator.py</code>,<br/><code>serpro_datavalid.py</code>,<br/><code>fraud_orchestrator.py</code></td>
      <td>Cliente estruturado Gemini 4 Argon High com sanitização anti-injeção visual; decodificador QR VIO (<code>2x bicubic + CLAHE + zlib &le; 64 KiB + CMS PKCS#7 ECDSA P-256/RSA-2048</code>) e chip NFC <code>EF.SOD</code>; cliente governamental <code>SerproDatavalidMtlsClient</code> (TLS 1.3 ICP-Brasil A1 + <em>Circuit Breaker</em>); e <code>CarbonFraudOrchestrator</code> (5 <em>Hard Vetos</em> + Gemini 4 Carbon High + Top-3 fatores SHAP).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-1-5">6.1.5. Clean Architecture em 4 Camadas Concêntricas, Orçamento de 120 FPS e Isolates Tier-0</h3>
<p>
  No interior do aplicativo unificado, a organização modular obedece à <strong>Regra Estrita de Dependência Concêntrica</strong> combinada à segregação física entre o <em>UI Isolate</em> (dedicado exclusivamente à árvore de widgets e composição Impeller/Skia dentro do orçamento rígido de <code>8,33 ms/quadro</code> a <code>120 Hz</code>) e <em>Worker Isolates</em> paralelos acionados via <code>Isolate.run</code> (<code>off_thread.dart</code>). A Figura 6.2 (<code>#fig-16</code>) esquematiza os fluxos unidirecionais e os mecanismos de latência zero entre as quatro camadas.
</p>

<div class="svg-diagram-box">
  ${svgCleanArchitecture4Layers}
  <div class="svg-caption">Figura 6.2 — Clean Architecture em 4 Camadas Concêntricas em <code>app/lib/</code>: Apresentação Reativa a 120 FPS (8,33 ms), Estado Especulativo O(1), Isolates Computacionais de Domínio/Visão Computacional Tier-0 e Infraestrutura Resiliente Multi-Provedor.</div>
</div>

<!-- ======================================================================= -->
<!-- SEÇÃO 6.2                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-6-2">
  <span class="sh-tag">SEÇÃO 6.2 &bull; ENGENHARIA DE BANCO DE DADOS, RPCS SECURITY DEFINER E ZERO-TRUST</span>
  <h2>6.2. Engenharia de Banco de Dados e Segurança: As 27 Migrações SQL Completas, Dicionário de Dados, RPCs SECURITY DEFINER, 4 Invariantes Contábeis, 9 Blindagens Red Team, Geo-Privacy Lock e KYC Zero-Trust</h2>
  <p>Auditoria integral do esquema PostgreSQL 17, catálogo de stored procedures privilegiadas, provas formais de conservação financeira e ausência de deadlocks, isolamento criptográfico em esquemas privados e pipeline biométrico governamental.</p>
</div>

<h3 id="sec-6-2-1">6.2.1. Catálogo Cronológico Exaustivo das 27 Migrações SQL Canônicas (<span class="mono">supabase/migrations/</span>)</h3>
<p>
  A evolução relacional até o marco canônico <code>v2.11.0</code> compreende exatamente <strong>27 migrações SQL idempotentes e sequenciais</strong> numeradas cronologicamente de <code>20261009120000</code> a <code>20261113110000</code>. A Tabela 6.5 documenta individualmente cada migração, suas estruturas DDL, funções RPC/gatilhos e garantias arquiteturais.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="5%">#</th>
      <th width="31%">Arquivo de Migração SQL Exato</th>
      <th width="27%">Tabelas, Visões e Estruturas Criadas/Alteradas</th>
      <th width="37%">RPCs, Gatilhos e Invariantes Transacionais / Segurança</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>001</code></td>
      <td><code>20261009120000_unify_profiles_and_kyc.sql</code></td>
      <td><code>public.profiles</code> (PK = <code>auth.uid()</code>), <code>app_settings</code>, <code>kyc_submissions</code></td>
      <td>Gatilho <code>profiles_protect_columns</code> contra auto-promoção de privilégio; helpers <code>is_admin</code>, <code>is_active_provider</code>, <code>is_client</code>; RPCs <code>submit_kyc</code> e <code>activate_provider</code>.</td>
    </tr>
    <tr>
      <td><code>002</code></td>
      <td><code>20261009120100_jobs_quotes_hardening.sql</code></td>
      <td><code>public.jobs</code>, <code>public.quotes</code> (endurecimento de constraints e RLS)</td>
      <td>Predicados <code>owns_job</code> e <code>has_quoted_job</code>; gatilho <code>quotes_before_insert</code>; transições atômicas <code>accept_quote</code> e <code>cancel_job</code> sob bloqueio de linha.</td>
    </tr>
    <tr>
      <td><code>003</code></td>
      <td><code>20261009120200_kyc_storage.sql</code></td>
      <td>Bucket privado <code>storage.buckets ('kyc_documentos')</code></td>
      <td>Privatização estrita (<code>public = false</code>) e políticas RLS em <code>storage.objects</code> segregando leitura/escrita por pasta do próprio <code>auth.uid()</code> e administradores.</td>
    </tr>
    <tr>
      <td><code>004</code></td>
      <td><code>20261019120000_multi_mode_service_flow.sql</code></td>
      <td><code>provider_profiles</code>, <code>provider_portfolio</code>, <code>provider_certificates</code>, <code>notifications</code>, <code>job_addresses</code>, <code>payments</code>, <code>reviews</code>, <code>support_tickets</code>, <code>messages</code></td>
      <td>Arquitetura Dual-Role na mesma conta: RPCs <code>enroll_mode</code>, <code>set_last_mode</code>, <code>pay_job_mock</code>, <code>provider_finish_job</code>, <code>client_approve_job</code> e <code>admin_resolve_dispute</code>.</td>
    </tr>
    <tr>
      <td><code>005</code></td>
      <td><code>20261019130000_invites_pin_evidence.sql</code></td>
      <td><code>job_invites</code>, <code>job_secrets</code>, <code>job_evidence</code></td>
      <td>Geração de PIN presencial de 4 dígitos (<code>gen_job_pin</code>), liquidação mediante prova <code>complete_job_with_pin</code> e fluxo emergencial SOS (<code>request_emergency_mock</code>, <code>accept_emergency</code>).</td>
    </tr>
    <tr>
      <td><code>006</code></td>
      <td><code>20261019140000_realtime_reviews_withdraw.sql</code></td>
      <td>Publicação <code>supabase_realtime</code> sobre tabelas transacionais</td>
      <td>RPCs <code>withdraw_quote</code> e <code>reject_quote</code>; abertura controlada de leitura pública para avaliações homologadas e sincronização instantânea de chat/status.</td>
    </tr>
    <tr>
      <td><code>007</code></td>
      <td><code>20261019150000_flow_fixes.sql</code></td>
      <td>Refinamento transacional em <code>job_secrets</code>, <code>jobs</code> e <code>quotes</code></td>
      <td>Preservação de contagem de tentativas inválidas de PIN fora de <code>RAISE EXCEPTION</code> destrutivo em <code>complete_job_with_pin</code> e blindagem de estados terminais em <code>cancel_job</code>.</td>
    </tr>
    <tr>
      <td><code>008</code></td>
      <td><code>20261019160000_quotes_withdrawn_status.sql</code></td>
      <td>Restrição <code>CHECK</code> de status em <code>public.quotes</code></td>
      <td>Inclusão formal do estado <code>withdrawn</code> no domínio relacional de propostas comerciais, harmonizando banco e cliente Dart.</td>
    </tr>
    <tr>
      <td><code>009</code></td>
      <td><code>20261022100000_self_service_guards.sql</code></td>
      <td>Constraints e gatilhos em <code>quotes</code>, <code>job_invites</code> e <code>jobs</code></td>
      <td>Trava anti-<em>self-dealing</em> (conluio consigo mesmo): impede que um usuário em modo profissional envie orçamento, receba convite ou aceite SOS de chamado aberto pelo próprio <code>auth.uid()</code>.</td>
    </tr>
    <tr>
      <td><code>010</code></td>
      <td><code>20261023100000_review_system.sql</code></td>
      <td><code>reviews</code> (v2 bilateral duplo-cega), visão/RPC <code>client_reputation</code></td>
      <td>Suavização Bayesiana empírica ponderada por <code>platform_avg_rating</code> em <code>refresh_provider_reputation</code>; revelação simultânea <code>reveal_job_reviews</code> e direito de resposta <code>reply_to_review</code>.</td>
    </tr>
    <tr>
      <td><code>011</code></td>
      <td><code>20261023200000_achievements.sql</code></td>
      <td><code>public.provider_achievements</code> (<code>9 &times; 10 = 90</code> níveis)</td>
      <td>Gatilho transacional pós-conclusão <code>jobs_achievements</code> avaliando limiares <code>[1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000]</code> em 9 eixos profissionais.</td>
    </tr>
    <tr>
      <td><code>012</code></td>
      <td><code>20261029100000_offboarding_wallet_showcase.sql</code></td>
      <td><code>account_deletion_log</code>, <code>withdrawals</code>, <code>provider_case_pins</code></td>
      <td>Offboarding LGPD auditável (<code>account_dossier</code>, <code>purge_account</code>), saque profissional (<code>my_wallet</code>, <code>request_withdrawal</code>) e vitrine pública curada (<code>provider_showcase</code>, <code>pin_case</code>).</td>
    </tr>
    <tr>
      <td><code>013</code></td>
      <td><code>20261030100000_client_wallet_ledger.sql</code></td>
      <td><code>client_wallets</code>, <code>ledger_txns</code>, <code>ledger_lines</code>, <code>pix_topups</code></td>
      <td>Motor contábil de partidas dobradas em centavos <code>BIGINT</code> (<code>_ledger_post</code> exige <code>&Sigma; cents = 0</code> e <code>UNIQUE idempotency_key</code>); gerador PIX EMV BR Code (<code>_brcode</code> + <code>_crc16</code>), <code>create_topup</code> e <code>confirm_topup</code>.</td>
    </tr>
    <tr>
      <td><code>014</code></td>
      <td><code>20261030120000_scheduled_start_chat_dossier.sql</code></td>
      <td><code>public.job_geo</code>, extensão de <code>messages</code> e visões de dossiê</td>
      <td>Cálculo geodésico esférico <code>haversine_m</code>, validação presencial de início <code>start_job</code>, guarda anti-evasão de contato <code>_messages_guard</code> e RPCs <code>provider_job_dossier</code> / <code>client_job_dossier</code>.</td>
    </tr>
    <tr>
      <td><code>015</code></td>
      <td><code>20261030130000_job_location_pin.sql</code></td>
      <td>Atributos de precisão e origem em <code>job_geo</code></td>
      <td>RPC <code>set_job_location</code> priorizando pino confirmado manualmente pelo morador no mapa (<code>client_pin</code>) sobre inferências imprecisas de CEP.</td>
    </tr>
    <tr>
      <td><code>016</code></td>
      <td><code>20261105100000_client_geocode_location.sql</code></td>
      <td>Hierarquia de precisão geoespacial em <code>job_geo</code></td>
      <td>Persistência formal de níveis de exatidão (<code>rooftop/pin &gt; street &gt; neighborhood &gt; locality</code>), eliminando regressão de coordenadas por re-geocodificação inferior.</td>
    </tr>
    <tr>
      <td><code>017</code></td>
      <td><code>20261106120000_category_match_orders_dossier.sql</code></td>
      <td>Coluna indexada <code>specialty_slugs</code> + índice GIN em <code>provider_profiles</code></td>
      <td>Normalização canônica sem acentos (<code>norm_tag</code>), predicado <code>provider_matches_category</code> acelerado por índice <code>GIN</code> e gatilho de notificação regional <code>jobs_notify_area_providers</code>.</td>
    </tr>
    <tr>
      <td><code>018</code></td>
      <td><code>20261107100000_scoped_account_deletion.sql</code></td>
      <td>Evolução de <code>account_deletion_log</code> e perfis escopados</td>
      <td>Deleção granular LGPD por escopo (<code>_normalize_deletion_scope</code>: <code>client | provider | all</code>) e verificação prévia de pendências ativas (<code>_deletion_blockers</code>).</td>
    </tr>
    <tr>
      <td><code>019</code></td>
      <td><code>20261107120000_expanded_categories.sql</code></td>
      <td>Catálogo expandido para <strong>33 categorias técnicas residenciais</strong></td>
      <td>Mapeamento completo de sinônimos e profissões em <code>norm_tag</code> / <code>provider_matches_category</code> sincronizado com <code>kCategories</code> no cliente Flutter.</td>
    </tr>
    <tr>
      <td><code>020</code></td>
      <td><code>20261108110000_high_perf_warranty_antifraud_engine.sql</code></td>
      <td><code>warranty_pool_ledger</code>, <code>escrow_maturation_entries</code>, <code>job_mediations</code>, <code>forensic_certificates</code> + 7 índices B-Tree estratégicos</td>
      <td>Motor de Garantia 3 Camadas (<code>1,5%</code> <em>carve-out</em>, 4 invariantes <code>BIGINT</code>), <code>hamming_distance_64</code> <span class="math-inline">O(1)</span>, escore <code>calculate_relative_trust_score</code> (<code>0..100</code>), ordem canônica de locks <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span> e fila <code>FOR UPDATE SKIP LOCKED</code>.</td>
    </tr>
    <tr>
      <td><code>021</code></td>
      <td><code>20261108120000_client_kyc_biometrics_and_ocr.sql</code></td>
      <td>Índices <code>idx_profiles_cpf_hash_unique</code> e <code>idx_profiles_face_liveness_hash</code></td>
      <td>Validador algébrico <code>is_valid_cpf</code> (Módulo 11), RPC <code>submit_client_kyc</code> (+30 pontos em <code>RTS</code> e herança Multi-Modo), trava anti-laranja PIX (<code>pix_key_cpf_matched</code>) e filtro espacial <em>Axial Bounding Box</em> <span class="math-inline">O(log N + K)</span> em <code>trigger_layer3_rework</code>.</td>
    </tr>
    <tr>
      <td><code>022</code></td>
      <td><code>20261110140000_real_portfolio_5_curated_and_notes.sql</code></td>
      <td><code>provider_case_pins</code> (até 5 destaques) e notas complementares em <code>jobs</code></td>
      <td>Gatilhos de imutabilidade forense pós-conclusão (<code>jobs_enforce_post_completion_immutability</code>, <code>job_evidence_enforce_post_completion_immutability</code>), vitrine LIFO Top-3 + 5 fixados e <code>set_job_complementary_notes</code>.</td>
    </tr>
    <tr>
      <td><code>023</code></td>
      <td><code>20261110234000_zero_trust_bilateral_antifraud_v285.sql</code></td>
      <td><code>kyc_liveness_nonces</code>, <code>job_fiscal_documents</code>, colunas de custódia de peças e copresença</td>
      <td>Zero-Trust 2ª Ordem: desafio <em>Screen-Flash</em> + atestação de hardware, validação NF-e/NFC-e 44 dígitos + auditoria SEFAZ <code>&gt;26h</code> com <em>clawback</em> de <code>15%</code>, despacho em anéis equiprováveis (<code>0,4–8,0 km</code>), <code>record_component_custody_and_proof_of_leave</code>, <code>cancel_sos_with_displacement_slashing</code> e <code>verify_bilateral_copresence_handshake</code>.</td>
    </tr>
    <tr>
      <td><code>024</code></td>
      <td><code>20261111130000_realtime_jobs_notifications_and_photo_captions.sql</code></td>
      <td>Coluna <code>photo_annotations</code> (<code>JSONB</code>) em <code>jobs</code> e ajuste Realtime</td>
      <td>Persistência estruturada de legendas técnicas por evidência fotográfica, RPC <code>mark_notification_read</code> e otimização de <code>REPLICA IDENTITY</code> para difusão em tempo real.</td>
    </tr>
    <tr>
      <td><code>025</code></td>
      <td><code>20261112150000_carbon_kyc_webhook_bridge.sql</code></td>
      <td><code>public.kyc_webhook_events</code> (registro imutável anti-replay)</td>
      <td>RPC <code>apply_verified_carbon_kyc_verdict</code> (<code>SECURITY DEFINER</code>) integrando idempotentemente os vereditos assinados pelo motor Python <code>kyc_engine</code> e recalculando o <code>RTS</code>.</td>
    </tr>
    <tr>
      <td><code>026</code></td>
      <td><code>20261113100000_temporal_geo_privacy_lock.sql</code></td>
      <td>Esquema <code>private</code> e tabela <code>private.geo_privacy_secrets</code> (CSPRNG 256 bits)</td>
      <td>Protocolo <strong>Temporal &amp; Spatial Geo-Privacy Lock</strong> (<code>ADR-0022</code>): gatilhos <code>aa_jobs_geo_privacy_before/after</code> limpando coordenadas exatas de <code>public.jobs</code>, <code>_geo_fuzzy_center</code> via <code>HMAC-SHA256</code> (<code>500m–800m</code>), máquina de 4 fases <code>_job_privacy_phase</code> (<code>00:00:00 America/Sao_Paulo</code>), <code>_can_see_exact_location</code> e RPC <code>get_job_location_for_viewer</code>.</td>
    </tr>
    <tr>
      <td><code>027</code></td>
      <td><code>20261113110000_security_hardening_audit.sql</code></td>
      <td><code>private.job_forensic_secrets</code>, bucket privado <code>forensic-evidence</code> e endurecimento global</td>
      <td>Aplicação integral das <strong>9 Blindagens da Auditoria Red Team</strong> (<code>[SEC-01]</code> a <code>[SEC-09]</code>): RLS em 6 tabelas críticas, extração de hashes de PIN de <code>public.jobs</code>, anti-IDOR em 8 RPCs, revogação de <em>workers</em> internos, HMAC de copresença, reconciliação LGPD e <code>SET search_path = public</code> em &ge;35 funções <code>SECURITY DEFINER</code>.</td>
    </tr>
  </tbody>
</table>

<div class="innovation-box">
  <div class="ib-header">Nota de Auditoria em Tempo Real: Sincronização Pós-v2.11.0 no Branch Principal (Migrações Operacionais 028 a 030)</div>
  <p>
    Em adição às <strong>27 migrações canônicas</strong> que definem o marco arquitetural <code>v2.11.0</code> (<code>7074adb</code>), a inspeção direta do estado operacional <code>HEAD</code> (<code>53882c8</code>, patch <code>v2.11.1+202611132</code>) registra três migrações complementares de endurecimento de produção que preservam intactos todos os invariantes da <code>v2.11.0</code>:
    (i) <strong><code>028</code> — <code>20261113120000_disable_checkin_sandbox.sql</code></strong> (desativa <code>checkin_sandbox</code> em produção, exigindo geofence Haversine real);
    (ii) <strong><code>029</code> — <code>20261113125000_jobs_updated_at.sql</code></strong> (normaliza carimbo monotônico <code>updated_at</code> em <code>public.jobs</code> e remove sobrecarga legada de retrabalho); e
    (iii) <strong><code>030</code> — <code>20261113130000_forensic_photo_and_fiscal_hardening.sql</code></strong> (institui a RPC <code>register_forensic_photo</code>, aplica máscara de bit de sinal <code>INT64_MIN</code> em <code>hamming_distance_64</code> e formaliza o canal honesto <code>MANUAL_KEY</code> / <code>QR_CODE</code> com status inicial <code>PENDING_SEFAZ</code> em <code>job_fiscal_documents</code>).
  </p>
</div>

<h3 id="sec-6-2-2">6.2.2. Dicionário Completo de Dados Relacionais (<span class="mono">public.*</span> e <span class="mono">private.*</span>) e Índices Estratégicos</h3>
<p>
  O modelo físico separa rigorosamente entidades públicas governadas por políticas <code>RLS</code> por linha (esquema <code>public</code>) de segredos criptográficos inacessíveis à API PostgREST (esquema <code>private</code>). A Tabela 6.6 consolida o dicionário relacional das tabelas nucleares, tipos PostgreSQL 17, constraints e índices de alto desempenho.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="21%">Esquema.Tabela</th>
      <th width="34%">Colunas Principais e Tipos Nativos PostgreSQL 17</th>
      <th width="23%">Chaves, Constraints <span class="mono">CHECK</span> e Isolamento RLS</th>
      <th width="22%">Índices B-Tree, Parciais, GIN e Espaciais</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>public.profiles</code></td>
      <td><code>id UUID</code>, <code>full_name TEXT</code>, <code>roles TEXT[]</code>, <code>last_mode TEXT</code>, <code>cpf_hash TEXT</code>, <code>face_liveness_hash BIGINT</code>, <code>relative_trust_score NUMERIC(5,2)</code>, <code>kyc_status TEXT</code></td>
      <td><code>PK (id = auth.uid())</code>; <code>CHECK (relative_trust_score BETWEEN 0 AND 100)</code>; gatilho <code>profiles_protect_columns</code>; <code>RLS</code> ativa.</td>
      <td><code>idx_profiles_cpf_hash_unique</code> (<code>UNIQUE WHERE cpf_hash IS NOT NULL</code>), <code>idx_profiles_face_liveness_hash</code>, B-Tree composto de ranking/RTS.</td>
    </tr>
    <tr>
      <td><code>public.provider_profiles</code></td>
      <td><code>user_id UUID</code>, <code>bio TEXT</code>, <code>specialty_slugs TEXT[]</code>, <code>base_lat DOUBLE PRECISION</code>, <code>base_lng DOUBLE PRECISION</code>, <code>bayesian_rating NUMERIC(4,2)</code>, <code>completed_jobs_count INT</code></td>
      <td><code>PK/FK (user_id &rarr; profiles.id)</code>; <code>RLS</code> pública de leitura para perfis ativos, escrita restrita ao titular.</td>
      <td><code>provider_profiles_specialty_slugs_gin</code> (<strong>índice GIN</strong> em array de slugs canônicos) + índice B-Tree composto <code>(base_lat, base_lng)</code> para <em>Axial Bounding Box</em> <span class="math-inline">O(log N + K)</span>.</td>
    </tr>
    <tr>
      <td><code>public.jobs</code></td>
      <td><code>id UUID</code>, <code>client_id UUID</code>, <code>provider_id UUID</code>, <code>category_slug TEXT</code>, <code>status TEXT</code>, <code>scheduled_for TIMESTAMPTZ</code>, <code>is_emergency BOOLEAN</code>, <code>labor_cents BIGINT</code>, <code>materials_cents BIGINT</code>, <code>address_summary TEXT</code>, <code>photo_annotations JSONB</code></td>
      <td><code>PK (id)</code>; <code>CHECK (client_id &lt;&gt; provider_id)</code>; coordenadas exatas e hashes de PIN mantidos <code>NULL</code> por gatilhos <code>aa_jobs_geo_privacy_*</code> e <code>ab_jobs_forensic_secrets_*</code>.</td>
      <td>Índices B-Tree parciais por <code>(status, category_slug, scheduled_for)</code>, <code>(client_id, created_at DESC)</code> e <code>(provider_id, status)</code>.</td>
    </tr>
    <tr>
      <td><code>public.job_geo</code> &amp;<br/><code>public.job_addresses</code></td>
      <td><code>job_id UUID</code>, <code>exact_lat DOUBLE PRECISION</code>, <code>exact_lng DOUBLE PRECISION</code>, <code>fuzzy_lat DOUBLE PRECISION</code>, <code>fuzzy_lng DOUBLE PRECISION</code>, <code>fuzzy_radius_m INT</code>, <code>street TEXT</code>, <code>number TEXT</code>, <code>complement TEXT</code>, <code>cep TEXT</code>, <code>precision_level TEXT</code></td>
      <td><code>PK/FK (job_id &rarr; jobs.id)</code>; leitura direta bloqueada para terceiros; exposição governada exclusivamente por <code>_can_see_exact_location</code> e <code>get_job_location_for_viewer</code>.</td>
      <td><code>PK B-Tree (job_id)</code> para junção em tempo indexado <span class="math-inline">O(log N)</span> durante resolução autorizada de endereço.</td>
    </tr>
    <tr>
      <td><code>private.geo_privacy_secrets</code> &amp;<br/><code>private.job_forensic_secrets</code></td>
      <td><code>secret_id INT</code>, <code>secret_key BYTEA</code> (32 bytes CSPRNG);<br/><code>job_id UUID</code>, <code>checkout_pin_hash TEXT</code> (<code>bcrypt</code>), <code>duress_pin_hash TEXT</code>, <code>job_presence_secret TEXT</code></td>
      <td>Esquema <code>private</code> fora do PostgREST; <code>ENABLE RLS</code> + <code>FORCE ROW LEVEL SECURITY</code> com zero políticas públicas e <code>REVOKE ALL FROM PUBLIC, anon, authenticated</code>.</td>
      <td><code>PK (secret_id)</code> e <code>PK (job_id)</code> acessíveis unicamente por funções <code>SECURITY DEFINER</code> auditadas com <code>search_path = public</code>.</td>
    </tr>
    <tr>
      <td><code>public.client_wallets</code>, <code>ledger_txns</code> &amp; <code>ledger_lines</code></td>
      <td><code>user_id UUID</code>, <code>available_cents BIGINT</code>, <code>escrow_cents BIGINT</code>;<br/><code>txn_id UUID</code>, <code>idempotency_key TEXT</code>;<br/><code>line_id UUID</code>, <code>account_code TEXT</code>, <code>cents BIGINT</code></td>
      <td><code>CHECK (available_cents &ge; 0 AND escrow_cents &ge; 0)</code>; <code>UNIQUE (idempotency_key)</code>; invariante transacional <code>&Sigma; cents = 0</code> em <code>_ledger_post</code>; <code>RLS</code> estrita (<code>[SEC-01]</code>).</td>
      <td>Índice único B-Tree em <code>idempotency_key</code> e índice composto <code>(user_id, created_at DESC)</code> para extrato instantâneo <code>wallet_statement</code>.</td>
    </tr>
    <tr>
      <td><code>public.warranty_pool_ledger</code></td>
      <td><code>entry_id UUID</code>, <code>job_id UUID</code>, <code>mediation_id UUID</code>, <code>entry_type TEXT</code> (<code>CARVEOUT_CREDIT | PAYOUT_DEBIT | CLAWBACK_RECOVERY</code>), <code>amount_cents BIGINT</code>, <code>running_balance_cents BIGINT</code></td>
      <td>Livro-razão <em>append-only</em>: <code>CHECK (amount_cents &gt; 0)</code>, <code>CHECK (running_balance_cents &ge; 0)</code>; gatilho bloqueia <code>UPDATE/DELETE</code>; <code>RLS</code> restrita a auditoria (<code>[SEC-01]</code>).</td>
      <td>Índice único parcial <code>uq_warranty_carveout_per_job</code> (<code>job_id WHERE entry_type = 'CARVEOUT_CREDIT'</code>) impedindo dupla retenção de <code>1,5%</code>.</td>
    </tr>
    <tr>
      <td><code>public.escrow_maturation_entries</code> &amp; <code>job_mediations</code></td>
      <td><code>id UUID</code>, <code>job_id UUID</code>, <code>provider_id UUID</code>, <code>net_payout_cents BIGINT</code>, <code>matures_at TIMESTAMPTZ</code>, <code>status TEXT</code> (<code>HOLDING | FROZEN_MEDIATION | FROZEN_UNDER_DURESS | RELEASED</code>), <code>mediation_layer INT</code></td>
      <td><code>CHECK (net_payout_cents &ge; 0)</code>; <code>CHECK (mediation_layer BETWEEN 1 AND 3)</code>; <code>RLS</code> por parte envolvida (<code>client_id / provider_id</code>) em <code>[SEC-01]</code>.</td>
      <td>Índices parciais de fila ativa <code>idx_escrow_maturation_ready</code> (<code>matures_at WHERE status = 'HOLDING'</code>) para varredura <code>SKIP LOCKED</code> sem <em>table scan</em>.</td>
    </tr>
    <tr>
      <td><code>public.job_fiscal_documents</code> &amp; <code>forensic_certificates</code></td>
      <td><code>id UUID</code>, <code>job_id UUID</code>, <code>access_key_44 CHAR(44)</code>, <code>issuer_cnpj CHAR(14)</code>, <code>materials_cents BIGINT</code>, <code>sefaz_status TEXT</code>;<br/><code>dhash_64 BIGINT</code>, <code>sha256_hex CHAR(64)</code></td>
      <td><code>UNIQUE (access_key_44)</code> (impede reuso da mesma NF-e em outro chamado); validação Módulo 11 no banco; imutabilidade pós-conclusão.</td>
      <td>Índice B-Tree em <code>(sefaz_status, created_at)</code> para auditoria SEFAZ Fase 2 (<code>&gt; 26h</code>) e índice de hashes perceptuais por categoria/região.</td>
    </tr>
    <tr>
      <td><code>public.kyc_webhook_events</code> &amp; <code>kyc_liveness_nonces</code></td>
      <td><code>event_id TEXT</code>, <code>user_id UUID</code>, <code>verdict TEXT</code>, <code>shap_top3 JSONB</code>, <code>payload_hmac TEXT</code>;<br/><code>nonce UUID</code>, <code>flash_sequence TEXT[]</code>, <code>expires_at TIMESTAMPTZ</code></td>
      <td><code>PK (event_id)</code> assegurando idempotência estrita contra entregas duplicadas de webhook; expiração curta de nonces anti-<em>replay</em>; <code>RLS</code> blindada (<code>[SEC-01]</code>).</td>
      <td>Índices B-Tree em <code>(user_id, created_at DESC)</code> e <code>(expires_at)</code> para limpeza determinística de sessões expiradas.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-2-3">6.2.3. Catálogo das Principais Stored Procedures e RPCs <span class="mono">SECURITY DEFINER</span> do Núcleo Transacional</h3>
<p>
  Em conformidade com <code>ADR-0003</code> e a blindagem <code>[SEC-08]</code> (que fixa <code>SET search_path = public</code> em mais de 35 rotinas privilegiadas), nenhuma regra sensível de negócio depende da boa-fé do código cliente. A Tabela 6.7 especifica o contrato formal das principais RPCs <code>SECURITY DEFINER</code> em produção.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="27%">Assinatura da RPC (<span class="mono">SECURITY DEFINER</span>)</th>
      <th width="19%">Guarda de Autorização</th>
      <th width="54%">Ordem de Bloqueio, Pós-Condições Atômicas e Invariantes Garantidas</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>enroll_mode(p_mode TEXT)</code> &amp;<br/><code>set_last_mode(p_mode TEXT)</code></td>
      <td><code>authenticated</code> (<code>id = auth.uid()</code>)</td>
      <td>Habilita papel adicional (<code>client | provider</code>) sobre o perfil unificado sem recadastro e persiste o modo ativo, herdando automaticamente homologação KYC prévia.</td>
    </tr>
    <tr>
      <td><code>submit_client_kyc(...)</code> &amp;<br/><code>apply_verified_carbon_kyc_verdict(...)</code></td>
      <td><code>authenticated</code> /<br/><code>service_role</code> (Webhook)</td>
      <td>Valida CPF (Módulo 11), unicidade global de <code>cpf_hash</code> com <em>pepper</em> e <code>face_liveness_hash</code>, grava evento idempotente em <code>kyc_webhook_events</code>, vincula <code>pix_key_cpf_matched = TRUE</code> e recalcula o <code>RTS</code> (+30 pontos).</td>
    </tr>
    <tr>
      <td><code>get_job_location_for_viewer(p_job_id UUID)</code></td>
      <td><code>authenticated</code> (oráculo zero de 1 argumento)</td>
      <td>Consulta <code>_job_privacy_phase</code> em <code>America/Sao_Paulo</code> e <code>_can_see_exact_location(p_job_id)</code>: retorna JSON canônico de 16 chaves contendo apenas círculo <code>HMAC-SHA256</code> (<code>500m–800m</code>) quando bloqueado, ou logradouro completo a partir das <code>00:00:00</code> do dia agendado para as partes legítimas.</td>
    </tr>
    <tr>
      <td><code>accept_quote(p_quote_id UUID)</code> &amp;<br/><code>accept_emergency(p_job_id UUID)</code></td>
      <td><code>authenticated</code> (titular do chamado / prestador ativo)</td>
      <td>Bloqueia <span class="math-inline">R<sub>1</sub> (jobs)</span>, verifica trava anti-<em>self-dealing</em> (<code>client_id &lt;&gt; provider_id</code>), transfere saldo de <code>available_cents</code> para <code>escrow_cents</code> via <code>_ledger_post</code> e gera segredo de PIN isolado em <code>private.job_forensic_secrets</code>.</td>
    </tr>
    <tr>
      <td><code>start_job(p_job_id UUID, p_lat FLOAT8, p_lng FLOAT8)</code></td>
      <td><code>authenticated</code> (<code>provider_id = auth.uid()</code>)</td>
      <td>Em produção (<code>checkin_sandbox = FALSE</code> na migração <code>028</code>), calcula distância esférica <code>haversine_m</code> contra <code>public.job_geo</code>, impedindo início remoto fora do perímetro físico do imóvel.</td>
    </tr>
    <tr>
      <td><code>complete_job_and_schedule_escrow(p_job_id UUID, p_pin TEXT, ...)</code></td>
      <td><code>authenticated</code> (anti-IDOR <code>[SEC-03]</code>)</td>
      <td>Compara <code>p_pin</code> contra <code>private.job_forensic_secrets</code>: se canônico, aplica <em>Smart Split</em> (<code>13,5%</code> plataforma + <code>1,5%</code> <code>warranty_pool_ledger</code> + <code>0,0%</code> peças com NF-e) e agenda <code>escrow_maturation_entries</code>; se PIN reverso, aciona silenciosamente <code>FROZEN_UNDER_DURESS</code>.</td>
    </tr>
    <tr>
      <td><code>settle_escrow_with_carveout_and_maturation(...)</code> &amp; <code>process_autonomous_escrow_...()</code></td>
      <td>Restrito a <code>service_role</code> / interno (<code>[SEC-04]</code>)</td>
      <td>Respeita estritamente <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span> com <code>FOR UPDATE SKIP LOCKED</code>, liquidando entradas maduras (<code>matures_at &le; now()</code>) não bloqueadas por mediação ou coação.</td>
    </tr>
    <tr>
      <td><code>audit_sefaz_phase2_cancellation_and_clawback(...)</code></td>
      <td>Restrito a <code>service_role</code> (<code>[SEC-04]</code>)</td>
      <td>Revalida chaves de 44 dígitos em <code>job_fiscal_documents</code> após janela legal de <code>26h</code>; caso detecte cancelamento extemporâneo da NF-e/NFC-e na SEFAZ, executa <em>clawback</em> automático da isenção de <code>15%</code> e penaliza o <code>RTS</code>.</td>
    </tr>
    <tr>
      <td><code>open_warranty_mediation(...)</code> &amp;<br/><code>trigger_layer3_rework(p_mediation_id UUID)</code></td>
      <td><code>authenticated</code> (titular validado <code>[SEC-03/06]</code>)</td>
      <td>Congela repasse pendente, instaura mediação de 90 dias (Camadas 1 a 3) e, na Camada 3, executa busca espacial <em>Axial Bounding Box</em> <span class="math-inline">O(log N + K)</span> sobre <code>public.job_geo</code> para convocar novo especialista custeado por <code>warranty_pool_ledger</code>.</td>
    </tr>
    <tr>
      <td><code>verify_bilateral_copresence_handshake(...)</code> &amp; <code>register_forensic_photo(...)</code></td>
      <td><code>authenticated</code> (partes contratuais do chamado)</td>
      <td>Valida prova criptográfica presencial derivada por <code>HMAC-SHA256</code> com segredo privado (<code>[SEC-05]</code>) e registra evidência fotográfica sanitizada com verificação <span class="math-inline">O(1)</span> de unicidade perceptual via <code>hamming_distance_64</code> (migração <code>030</code>).</td>
    </tr>
    <tr>
      <td><code>account_dossier(p_scope TEXT)</code> &amp;<br/><code>purge_account(p_scope TEXT)</code></td>
      <td><code>authenticated</code> / <code>service_role</code> (<code>excluir-conta</code>)</td>
      <td>Extrai histórico integral escopado (<code>client | provider | all</code>) para síntese do PDF A4 portável e, somente após confirmação de entrega SMTP, anonimiza dados pessoais reconciliando os gatilhos de imutabilidade pós-conclusão (<code>[SEC-07]</code>).</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-2-4">6.2.4. Os 4 Invariantes Financeiros em Centavos (<span class="mono">BIGINT</span>) e Prova Formal de Ausência de Deadlocks</h3>
<p>
  Toda a infraestrutura contábil do Desperrengue abole tipos de ponto flutuante binário IEEE 754 (<code>FLOAT</code> / <code>DOUBLE PRECISION</code>), nos quais dízimas periódicas em base 2 (<span class="math-inline">0,10 + 0,20 &ne; 0,30</span>) corrompem saldos acumulados. Tanto em Dart (<code>money.dart</code>) quanto no PostgreSQL 17, 100% dos valores monetários pertencem ao conjunto dos inteiros de 64 bits em centavos (<code>BIGINT</code>). Sobre esse domínio algébrico, o livro-razão <code>warranty_pool_ledger</code> e as carteiras de custódia obedecem a quatro invariantes formais:
</p>

<div class="math-formula-box">
  <div class="math-display">
    (I<sub>1</sub>) &forall; e &isin; L<sub>pool</sub> : e.amount_cents &isin; &#8484;<sup>+</sup> &nbsp;&and;&nbsp;
    (I<sub>2</sub>) &forall; tx &isin; T<sub>ledger</sub> : &Sigma;<sub>i=1</sub><sup>k</sup> l<sub>i</sub>.cents = 0 &nbsp;&and;&nbsp;
    (I<sub>3</sub>) B(t<sub>n</sub>) = B(t<sub>n&minus;1</sub>) + &sigma;(e<sub>n</sub>) &middot; e<sub>n</sub>.amount_cents &ge; 0
  </div>
</div>

<ol>
  <li><strong>Invariante <span class="math-inline">I<sub>1</sub></span> — Positividade Estrita, Inteiros de 64 Bits e Rateio Exato pelo Maior Resto:</strong> toda entrada em <code>warranty_pool_ledger</code> exige <code>amount_cents &gt; 0</code>. Dada mão de obra <span class="math-inline">M<sub>cents</sub></span> e materiais comprovados <span class="math-inline">P<sub>cents</sub></span>, o <em>carve-out</em> mutualista é <span class="math-inline">C<sub>pool</sub> = &lfloor;(M<sub>cents</sub> &times; 150 + 5000) / 10000&rfloor;</span> (<code>1,50%</code>), a receita líquida da plataforma é <span class="math-inline">R<sub>plat</sub> = &lfloor;(M<sub>cents</sub> &times; 1350 + 5000) / 10000&rfloor;</span> (<code>13,50%</code>) e o repasse líquido ao prestador é <span class="math-inline">L<sub>prov</sub> = (M<sub>cents</sub> &minus; R<sub>plat</sub> &minus; C<sub>pool</sub>) + P<sub>cents</sub></span>, preservando conservação exata centavo a centavo (<span class="math-inline">R<sub>plat</sub> + C<sub>pool</sub> + L<sub>prov</sub> = M<sub>cents</sub> + P<sub>cents</sub></span>).</li>
  <li><strong>Invariante <span class="math-inline">I<sub>2</sub></span> — Partidas Dobradas Soma-Zero e Idempotência Criptográfica:</strong> a rotina interna <code>_ledger_post</code> aborta qualquer transação cujo somatório algébrico de linhas (<code>&Sigma; ledger_lines.cents</code>) seja diferente de zero, enquanto <code>UNIQUE(idempotency_key)</code> em <code>ledger_txns</code> e <code>uq_warranty_carveout_per_job</code> impedem duplicidade em retentativas de rede.</li>
  <li><strong>Invariante <span class="math-inline">I<sub>3</sub></span> — Imutabilidade <em>Append-Only</em> e Solvência Monotônica Não Negativa:</strong> <code>warranty_pool_ledger</code> bloqueia <code>UPDATE</code> e <code>DELETE</code> por gatilho e valida sob bloqueio transacional que <code>running_balance_cents &ge; 0</code>, apresentando ponto de equilíbrio atuarial de <span class="math-inline">1 / 0,015 = 66,67</span> ordens concluídas para cada cobertura integral de Camada 3.</li>
  <li><strong>Invariante <span class="math-inline">I<sub>4</sub></span> — Maturação Escalonada Acoplada ao <code>RTS</code>:</strong> <code>escrow_maturation_entries</code> retém repasses sob <code>HOLDING</code> conforme a reputação relativa (<span class="math-inline">RTS &isin; [0, 100]</span>: <code>D+0</code> alto escore, <code>D+2</code> padrão, <code>D+5..D+7</code> novo prestador) e congela instantaneamente a liquidação sob <code>FROZEN_MEDIATION</code> ou <code>FROZEN_UNDER_DURESS</code>.</li>
</ol>

<h4 id="sec-6-2-4-deadlock">Teorema de Ausência de Deadlocks por Ordenação Canônica Estrita de Recursos</h4>
<p>
  Para extinguir estruturalmente a condição de espera circular de Coffman entre liquidações concorrentes, disputas de garantia e atualizações de escore, todas as transações PL/pgSQL adquirem bloqueios pessimistas (<code>SELECT ... FOR UPDATE</code>) respeitando a ordem total estrita instituída na migração <code>020</code>:
</p>

<div class="math-formula-box">
  <div class="math-display">
    R<sub>1</sub> (<code>public.jobs</code>) &nbsp;&prec;&nbsp; R<sub>2</sub> (<code>public.job_mediations</code>) &nbsp;&prec;&nbsp; R<sub>3</sub> (<code>public.escrow_maturation_entries</code>) &nbsp;&prec;&nbsp; R<sub>4</sub> (<code>public.profiles</code>)
  </div>
</div>

<p>
  <strong>Demonstração Formal:</strong> Suponha, por absurdo, a formação de um ciclo dirigido <span class="math-inline">T<sub>1</sub> &rarr; T<sub>2</sub> &rarr; &hellip; &rarr; T<sub>k</sub> &rarr; T<sub>1</sub></span> no grafo de espera <span class="math-inline">G = (V, E)</span>. Toda aresta <span class="math-inline">(T<sub>a</sub>, T<sub>b</sub>) &isin; E</span> exige que <span class="math-inline">T<sub>a</sub></span> detenha recurso de nível <span class="math-inline">R<sub>i(a)</sub></span> enquanto solicita recurso <span class="math-inline">R<sub>j(b)</sub></span> retido por <span class="math-inline">T<sub>b</sub></span>. Como toda aquisição respeita <span class="math-inline">i(a) &lt; j(b)</span> (e ordenação lexicográfica crescente de <code>UUID</code> no interior da mesma tabela), a transitividade ao longo do ciclo implicaria <span class="math-inline">R<sub>i(1)</sub> &prec; R<sub>i(1)</sub></span>, contradizendo a irreflexividade de uma ordem estrita. Portanto, <span class="math-inline">G</span> é invariavelmente um <strong>Grafo Acíclico Dirigido (DAG)</strong> livre de <em>deadlocks</em>, operando ainda com <code>FOR UPDATE SKIP LOCKED</code> nos <em>workers</em> assíncronos.
</p>

<h3 id="sec-6-2-5">6.2.5. As 9 Blindagens Aplicadas na Auditoria Red Team do Banco de Dados (Migração <span class="mono">027</span>)</h3>
<p>
  Previamente à emissão da versão <code>v2.11.0</code>, o banco de dados completo foi submetido a auditoria ofensiva <em>Red Team</em> voltada à mitigação de exposição PostgREST, força bruta offline sobre PINs curtos, IDOR, <em>search-path hijacking</em> e adulteração de provas fotográficas. A Tabela 6.8 detalha as nove blindagens implementadas em <code>20261113110000_security_hardening_audit.sql</code>.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="11%">Código</th>
      <th width="27%">Vetor de Ameaça Identificado (<em>Red Team</em>)</th>
      <th width="62%">Blindagem Criptográfica e Relacional Implementada (<span class="mono">20261113110000_security_hardening_audit.sql</span>)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><span class="badge-high">SEC-01</span></td>
      <td>Exposição residual de tabelas financeiras e forenses na API PostgREST</td>
      <td>Ativação mandatória de <code>ENABLE ROW LEVEL SECURITY</code>, revogação total de privilégios para <code>anon</code>/<code>PUBLIC</code> e criação de políticas mínimas por parte envolvida sobre <strong>6 tabelas críticas</strong> (<code>warranty_pool_ledger</code>, <code>escrow_maturation_entries</code>, <code>job_mediations</code>, <code>forensic_certificates</code>, <code>kyc_liveness_nonces</code>, <code>job_fiscal_documents</code>) e tabelas auxiliares de carteira.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-02</span></td>
      <td>Ataque de força bruta offline sobre hash do PIN de 4 dígitos (<span class="math-inline">10<sup>4</sup></span> combinações) caso <code>public.jobs</code> seja lida</td>
      <td>Criação do cofre <code>private.job_forensic_secrets</code> (com <code>RLS + FORCE RLS</code> e zero permissões externas) e dos gatilhos <code>ab_jobs_forensic_secrets_before/after</code>, que interceptam e movem <code>checkout_pin_hash</code> e <code>job_presence_secret</code> para o esquema privado, mantendo as colunas correspondentes em <code>public.jobs</code> permanentemente <code>NULL</code>.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-03</span></td>
      <td><em>Insecure Direct Object Reference</em> (IDOR) em RPCs <code>SECURITY DEFINER</code></td>
      <td>Injeção de verificação estrita de identidade (<code>auth.uid() IS NOT NULL</code> e vínculo contratual efetivo <code>client_id / provider_id</code>) somada a <code>REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon</code> em <strong>8 RPCs transacionais críticas</strong> (incluindo <code>complete_job_and_schedule_escrow</code> e <code>open_warranty_mediation</code>).</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-04</span></td>
      <td>Invocação externa não autorizada de rotinas autônomas de liquidação e fisco</td>
      <td>Revogação completa de permissão <code>EXECUTE</code> para <code>PUBLIC</code>, <code>anon</code> e <code>authenticated</code> sobre os motores internos <code>settle_escrow_with_carveout_and_maturation</code>, <code>process_autonomous_escrow_and_mediation_queues</code> e <code>audit_sefaz_phase2_cancellation_and_clawback</code>, restringindo-os a <code>service_role</code> e chamadas internas.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-05</span></td>
      <td>Previsibilidade de fallback no <em>handshake</em> de copresença física</td>
      <td>Substituição de qualquer derivação baseada em <code>job_id::TEXT</code> puro em <code>verify_bilateral_copresence_handshake</code> por prova criptográfica <code>HMAC-SHA256</code> ancorada na chave de 256 bits de <code>private.geo_privacy_secrets</code> e no segredo isolado em <code>private.job_forensic_secrets</code>.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-06</span></td>
      <td>Acionamento indevido de retrabalho Camada 3 e falha de leitura após supressão de GPS em <code>jobs</code></td>
      <td>Adição de guarda de autorização do solicitante em <code>trigger_layer3_rework</code> e migração da leitura da origem espacial da busca <span class="math-inline">O(log N + K)</span> diretamente para <code>public.job_geo</code> (visto que <code>public.jobs.latitude/longitude</code> permanecem <code>NULL</code> sob o Geo-Privacy Lock).</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-07</span></td>
      <td>Conflito entre gatilhos de imutabilidade pós-conclusão e direito de eliminação LGPD (Art. 18)</td>
      <td>Reconciliação controlada nos gatilhos <code>jobs_enforce_post_completion_immutability</code> para permitir exclusivamente a anonimização de dados pessoais comandada por <code>purge_account</code> via variável de sessão segura transacional, além do endurecimento de <code>profiles_protect_columns()</code>.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-08</span></td>
      <td><em>Search-Path Hijacking</em> em funções privilegiadas <code>SECURITY DEFINER</code></td>
      <td>Fixação explícita de <code>SET search_path = public</code> e saneamento de permissões de execução em 17 funções auxiliares e de gatilho adicionais, totalizando <strong>&ge; 35 rotinas <code>SECURITY DEFINER</code></strong> integralmente blindadas contra substituição maliciosa de operadores ou tabelas temporárias.</td>
    </tr>
    <tr>
      <td><span class="badge-high">SEC-09</span></td>
      <td>Enumeração ou adulteração pós-upload de fotos periciais de check-in/check-out</td>
      <td>Provisionamento do bucket privado <code>forensic-evidence</code> (<code>public = false</code>, limite de <code>15 MB</code>, MIME restrito a JPEG/PNG/WebP) com políticas RLS em <code>storage.objects</code> limitadas às partes do chamado via URLs assinadas temporárias e bloqueio absoluto de <code>UPDATE</code> e <code>DELETE</code> por usuários comuns.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-2-6">6.2.6. Protocolo Criptográfico <em>Temporal &amp; Spatial Geo-Privacy Lock</em> (<span class="mono">ADR-0022</span>)</h3>
<p>
  O protocolo <strong>Temporal &amp; Spatial Geo-Privacy Lock</strong> (migração <code>026</code> — <code>20261113100000_temporal_geo_privacy_lock.sql</code>) erradica a exposição prematura de domicílios diretamente no servidor PostgreSQL. A Figura 6.3 (<code>#fig-17</code>) representa o fluxo criptográfico completo de ofuscação, liberação <em>just-in-time</em> às <code>00:00:00</code> do dia agendado, custódia <em>Smart Escrow</em> e re-ofuscação pós-serviço.
</p>

<div class="svg-diagram-box">
  ${svgGeoPrivacyAndEscrowSequence}
  <div class="svg-caption">Figura 6.3 — Diagrama de Sequência Criptográfica e Transacional: Ofuscação Espacial <code>HMAC-SHA256</code> (Raio 500m–800m), Máquina de Estados Temporal (<code>00:00:00 America/Sao_Paulo</code>), Custódia <em>Smart Escrow</em> com PIN de 4 Dígitos / Cofre Anti-Coação e Re-Ofuscação LGPD Pós-Conclusão.</div>
</div>

<p>
  Pelo Princípio de Kerckhoffs, utilizar um hash sem chave como <code>SHA-256(job_id)</code> permitiria inversão trivial em <span class="math-inline">O(1)</span> por qualquer cliente que conheça o <code>job_id</code>. Por essa razão, <code>_geo_fuzzy_center</code> utiliza chave CSPRNG de 256 bits (<code>gen_random_bytes(32)</code>) confinada em <code>private.geo_privacy_secrets</code> para computar <span class="math-inline">D = HMAC-SHA256(K<sub>geo</sub>, id<sub>job</sub>)</span>, derivando três variáveis uniformes independentes <span class="math-inline">u<sub>1</sub>, u<sub>2</sub>, u<sub>3</sub> &isin; [0, 1)</span>:
</p>

<div class="math-formula-box">
  <div class="math-display">
    R<sub>pub</sub> = 500 + &lfloor;301 &middot; u<sub>1</sub>&rfloor; &isin; [500 <span class="m-rm">m</span>, 800 <span class="m-rm">m</span>], &nbsp;&nbsp;
    d<sub>off</sub> = 151 + 198 &middot; u<sub>2</sub> &isin; [151 <span class="m-rm">m</span>, 349 <span class="m-rm">m</span>], &nbsp;&nbsp;
    &theta; = 2&pi; &middot; u<sub>3</sub> &isin; [0, 2&pi;)
  </div>
</div>

<div class="math-formula-box">
  <div class="math-display">
    &phi;<sub>fuzzy</sub> = &phi;<sub>real</sub> + (d<sub>off</sub> &middot; cos &theta;) / 111.320, &nbsp;&nbsp;&nbsp;
    &lambda;<sub>fuzzy</sub> = &lambda;<sub>real</sub> + (d<sub>off</sub> &middot; sin &theta;) / (111.320 &middot; cos(&phi;<sub>real</sub> &middot; &pi; / 180))
  </div>
</div>

<p>
  A máquina determinística <code>_job_privacy_phase</code> governa quatro estados ancorados no fuso oficial <code>America/Sao_Paulo</code> (<code>UTC-3</code>): (1) <strong><code>PUBLIC_FUZZY</code></strong> (pedido em cotação: exibe apenas <code>Bairro, Cidade - UF</code> e círculo aproximado com margem de segurança interna <span class="math-inline">R<sub>pub</sub> &minus; d<sub>off</sub> &ge; 151 m</span>); (2) <strong><code>HIRED_PRE_DAY_LOCKED</code></strong> (orçamento aceito antes da data agendada: endereço completo permanece oculto até para o profissional contratado, informando <code>unlocks_at</code>); (3) <strong><code>SERVICE_DAY_UNLOCKED</code></strong> (a partir das <code>00:00:00</code> do dia agendado, ou no ato do aceite em emergências SOS: endereço completo liberado exclusivamente às duas partes contratuais com disparo de <code>notify_service_day_address_unlocked</code>); e (4) <strong><code>POST_COMPLETION_RELOCKED</code></strong> (re-ofuscação automática após conclusão ou cancelamento em observância ao Art. 6º, III da LGPD).
</p>

<h3 id="sec-6-2-7">6.2.7. Arquitetura KYC Biométrica e Documental Zero-Trust (<span class="mono">ADR-0021</span>), Sanitização EXIF e Cofre Dual Anti-Coação</h3>
<p>
  A homologação de identidade combina filtragem local de custo zero a validação criptográfica governamental e IA multimodal auditável, conforme ilustrado na Figura 6.4 (<code>#fig-18</code>).
</p>

<div class="svg-diagram-box">
  ${svgKycZeroTrustArchitecture}
  <div class="svg-caption">Figura 6.4 — Pipeline Biométrico e Documental KYC Zero-Trust: Triagem Local Tier-0 em <code>Isolate.run</code> (R$ 0,00), Portão Multimodal Gemini 4 Argon High, Validação Criptográfica VIO/ICP-Brasil (<code>CMS PKCS#7 ECDSA P-256</code>) + SERPRO Datavalid mTLS 1.3, Orquestrador Gemini 4 Carbon High com Top-3 Fatores SHAP (LGPD Art. 20) e Cofre WORM <code>AES-256-GCM</code>.</div>
</div>

<ol>
  <li><strong>Tier-0 Local em <code>Isolate.run</code> (<code>R$ 0,00</code>):</strong> <code>document_ocr_and_liveness_service.dart</code> valida foco Laplaciano, pele <code>YCbCr</code>, piscada (<code>EAR</code>), rotação cefálica (<code>Yaw</code>), <em>embedding</em> facial 128-D e desafio dinâmico <em>Screen-Flash</em> com atestação de hardware (Play Integrity / App Attest).</li>
  <li><strong>Sessão Anti-Swap e Portão Gemini 4 Argon High:</strong> <code>POST /v1/kyc/session/init</code> emite token HMAC (<code>TTL &le; 180 s</code>, vivacidade <code>&le; 90 s</code>) e <code>kyc-argon-vision-gate</code> (<code>vision_ocr_argon.py</code>) executa <em>2D spatial grounding</em> (<code>temperature=0.0</code>, <code>thinkingLevel=&quot;HIGH&quot;</code>) confinando OCR em <code>&lt;untrusted_visual_ocr_stream&gt;</code> contra <em>Visual Prompt Injection</em>.</li>
  <li><strong>Criptografia VIO / ICP-Brasil e Chip NFC (<code>EF.SOD</code>):</strong> <code>crypto_doc_validator.py</code> aplica super-resolução bicúbica <code>2x</code> + <code>CLAHE</code>, descompressão <code>zlib &le; 64 KiB</code> (anti-<em>zip-bomb</em>) e verificação <code>ASN.1/DER CMS PKCS#7</code> (<code>ECDSA P-256</code> / <code>RSA-2048</code>) contra a cadeia ICP-Brasil/DENATRAN, impondo igualdade tripla <code>qr_cpf == ocr_cpf == typed_cpf</code>.</li>
  <li><strong>Consulta SERPRO Datavalid mTLS 1.3 + Orquestrador Gemini 4 Carbon High SHAP:</strong> <code>serpro_datavalid.py</code> consulta a base federal via mTLS 1.3 ICP-Brasil A1 com <em>Circuit Breaker</em>; <code>fraud_orchestrator.py</code> aplica 5 <em>Hard Vetos</em> determinísticos pré-LLM seguidos da análise forense <strong>Gemini 4 Carbon High</strong> com <strong>Top-3 Fatores SHAP</strong> (LGPD Art. 20), selando o veredito em cofre WORM <code>KWV2</code> (<code>HKDF-SHA256</code> + <code>AES-256-GCM</code> em <code>security.py</code>) e ponte HMAC <code>kyc-carbon-webhook</code>.</li>
  <li><strong>Sanitização EXIF <em>Lossless</em> e Cofre Dual Anti-Coação:</strong> complementarmente, <code>image_metadata_stripper.dart</code> remove 100% dos metadados <code>EXIF/GPS/XMP/IPTC</code> antes do upload (<em>fail-closed</em>), enquanto <code>zero_trust_bilateral_security_engine.dart</code> protege a vida humana em domicílio por meio do <em>Silent Duress PIN</em> reverso (<code>FROZEN_UNDER_DURESS</code>).</li>
</ol>

<!-- ======================================================================= -->
<!-- SEÇÃO 6.3                                                               -->
<!-- ======================================================================= -->
<div class="section-header-banner" id="sec-6-3">
  <span class="sh-tag">SEÇÃO 6.3 &bull; MEMORIAL CRONOLÓGICO EXAUSTIVO EM 9 FASES E VALIDAÇÃO EMPÍRICA</span>
  <h2>6.3. Relatório Cronológico Passo a Passo de Tudo o Que Foi Construído no Projeto (Da Fundação até a <span class="mono">v2.11.0</span>) e Quadro Consolidado de Validação Empírica</h2>
  <p>Documentação detalhada das 9 fases evolutivas de engenharia — arquivos, migrações SQL, algoritmos, protocolos de segurança, UX e testes — encerrando com o balanço oficial das baterias automatizadas do repositório.</p>
</div>

<h3 id="sec-6-3-1">6.3.1. Memorial Passo a Passo Exaustivo em 9 Fases Evolutivas (Da Fundação até a <span class="mono">v2.11.0</span>)</h3>
<p>
  A engenharia do ecossistema Desperrengue percorreu <strong>nove fases evolutivas sequenciais</strong> disciplinadas por integração contínua, migrações transacionais idempotentes e testes adversariais regressivos. Cada fase abaixo detalha exatamente o problema superado, os módulos e migrações SQL construídos e as garantias introduzidas no repositório.
</p>

<h4 id="sec-6-3-1-f1">Fase 1 — Fundação Cloud BaaS, Cliente Único Flutter e Unificação Identitária (<span class="mono">v1.0.0 &rarr; v1.5.0</span> &bull; Migrações <span class="mono">001–003</span> &bull; <span class="mono">ADR-0001..0004</span>)</h4>
<p>
  Na etapa inaugural de fundação, instituiu-se a infraestrutura em nuvem sobre PostgreSQL 17 na região brasileira <code>sa-east-1</code> (<code>ADR-0001</code>) acoplada a uma base única multiplataforma em Flutter/Dart (<code>ADR-0002</code>). A migração <code>001</code> (<code>20261009120000_unify_profiles_and_kyc.sql</code>) unificou a identidade civil em <code>public.profiles</code> vinculada diretamente a <code>auth.uid()</code> (<code>ADR-0004</code>), implantou o gatilho <code>profiles_protect_columns</code> impedindo auto-atribuição de privilégios administrativos e estruturou a fila inicial <code>kyc_submissions</code>. Na sequência imediata, a migração <code>002</code> endureceu as políticas <code>RLS</code> e transições atômicas de <code>public.jobs</code> e <code>public.quotes</code> (<code>accept_quote</code>, <code>cancel_job</code>), enquanto a migração <code>003</code> isolou documentos sensíveis no bucket privado <code>kyc_documentos</code> (<code>public = false</code>).
</p>

<h4 id="sec-6-3-1-f2">Fase 2 — Arquitetura Multi-Modo Unificada, SOS Emergencial, PIN Presencial de 4 Dígitos e Realtime (<span class="mono">v1.6.0 &rarr; v2.1.0</span> &bull; Migrações <span class="mono">004–009</span> &bull; <span class="mono">ADR-0005..0010</span>)</h4>
<p>
  Superada a fundação cadastral, a migração <code>004</code> (<code>20261019120000_multi_mode_service_flow.sql</code>) materializou a arquitetura <strong>Multi-Modo</strong> (<code>ADR-0005</code>): através das RPCs <code>enroll_mode</code> e <code>set_last_mode</code> e dos roteadores puros <code>auth_gate.dart</code> e <code>post_auth_router.dart</code> (<code>ADR-0009</code>), um mesmo cidadão passou a alternar instantaneamente entre as interfaces de Cliente (<code>client_shell.dart</code>) e Profissional (<code>provider_shell.dart</code>). Criaram-se as tabelas <code>provider_profiles</code>, <code>provider_portfolio</code>, <code>provider_certificates</code>, <code>job_addresses</code>, <code>notifications</code>, <code>messages</code> e <code>support_tickets</code>, além da Edge Function <code>enviar-email-aprovacao</code> (<code>ADR-0010</code>). As migrações <code>005</code> a <code>009</code> introduziram convites diretos (<code>job_invites</code>), o despacho de urgência <strong>SOS</strong> (<code>accept_emergency</code>), a liquidação presencial mediante <strong>PIN de 4 dígitos</strong> com contador de tentativas preservado fora de rollback destrutivo (<code>complete_job_with_pin</code>), canais WebSocket <code>supabase_realtime</code> e as travas anti-<em>self-dealing</em> (<code>client_id &lt;&gt; provider_id</code>).
</p>

<h4 id="sec-6-3-1-f3">Fase 3 — Reputação Duplo-Cega Bayesiana, Gamificação Inicial, Vitrine LIFO e Dossiê PDF LGPD (<span class="mono">v2.2.0 &rarr; v2.3.0</span> &bull; Migrações <span class="mono">010–012</span> &bull; <span class="mono">ADR-0011..0013, 0016</span>)</h4>
<p>
  Para eliminar avaliações retaliatórias e distorções de ranking em amostras pequenas, a migração <code>010</code> (<code>20261023100000_review_system.sql</code>) implantou o motor de <strong>Avaliação Bilateral Duplo-Cega</strong> (<code>reveal_job_reviews</code>, janela de 48h) combinado à <strong>Suavização Bayesiana Empírica</strong> ponderada pela média global <code>platform_avg_rating</code> em <code>refresh_provider_reputation</code> (<code>ADR-0011</code>, <code>review_rules_test.dart</code>). A migração <code>011</code> inaugurou o motor relacional de conquistas (<code>provider_achievements</code>, 90 níveis acionados pelo gatilho <code>jobs_achievements</code>). Em seguida, a migração <code>012</code> e a Edge Function <code>supabase/functions/excluir-conta/</code> (<code>index.ts</code> + <code>dossie.ts</code> em <code>pdf-lib</code> puro) instituíram o encerramento ético LGPD (<code>ADR-0013</code>): geração em memória do <strong>Dossiê Oficial de Despedida A4</strong> validado por <strong>17 testes vetoriais</strong> em <code>scripts/test-dossie.mjs</code>, bloqueando <code>purge_account</code> caso o envio por e-mail falhe, além da vitrine profissional <code>provider_showcase</code> (<code>ADR-0016</code>).
</p>

<h4 id="sec-6-3-1-f4">Fase 4 — Quiet Luxury Dark Mode, Ledger de Partidas Dobradas <span class="mono">BIGINT</span>, PIX EMV CRC16 e Geofence Haversine (<span class="mono">v2.4.0 &rarr; v2.5.5</span> &bull; Migrações <span class="mono">013–016</span> &bull; <span class="mono">ADR-0014, 0015, 0018, 0019</span>)</h4>
<p>
  Esta fase consolidou a maturidade visual e fiduciária da plataforma. No front-end, instituiu-se o Design System <em>Quiet Luxury Dark Mode</em> em <code>app_tokens.dart</code> e <code>app_theme.dart</code> (<code>#0E1218</code> base, <code>#141A22</code> superfície, <code>#EAEFF6</code> tipografia AAA, acento laranja para Cliente e azul para Profissional, <code>ADR-0014</code>) e a inicialização segura em <code>app_initialization_service.dart</code> (<code>ADR-0015</code>). No núcleo financeiro, a migração <code>013</code> (<code>20261030100000_client_wallet_ledger.sql</code>) e <code>money.dart</code> substituíram simulações por um <strong>Livro-Razão de Partidas Dobradas em Centavos Inteiros <code>BIGINT</code></strong> (<code>client_wallets</code>, <code>ledger_txns</code> com <code>idempotency_key</code> única e <code>ledger_lines</code> exigindo <code>&Sigma; cents = 0</code>), acompanhado da geração nativa de payload <strong>PIX Copia-e-Cola EMV BR Code CRC16-CCITT</strong> (<code>_brcode</code> / <code>_crc16</code>) e liquidação via Edge Function <code>pix-webhook</code> (<code>confirm_topup</code>, <code>ADR-0018</code>). As migrações <code>014</code> a <code>016</code> adicionaram <code>public.job_geo</code>, validação presencial de check-in por distância esférica <code>haversine_m</code> (<code>start_job</code>), proteção anti-evasão no chat (<code>_messages_guard</code>), dossiês operacionais bilaterais e hierarquia determinística de geocodificação (<code>precise_geocoder.dart</code> e pino confirmado <code>client_pin</code>, <code>ADR-0019</code>).
</p>

<h4 id="sec-6-3-1-f5">Fase 5 — Índice GIN de Especialidades, Exclusão Escopada, 33 Categorias Duotone, 112 Medalhas (<span class="mono">#CBD5E1</span>) e OTA (<span class="mono">v2.6.0 &rarr; v2.6.5</span> &bull; Migrações <span class="mono">017–019</span> &bull; <span class="mono">ADR-0017</span>)</h4>
<p>
  Para escalar a descoberta de especialistas sem varreduras sequenciais lentas, a migração <code>017</code> introduziu normalização canônica sem diacríticos (<code>norm_tag</code>) e o índice invertido <strong>GIN</strong> <code>provider_profiles_specialty_slugs_gin</code> com notificações regionais automáticas (<code>jobs_notify_area_providers</code>). A migração <code>018</code> refinou a conformidade LGPD permitindo exclusão granular escopada por papel (<code>client | provider | all</code> via <code>_normalize_deletion_scope</code> e <code>_deletion_blockers</code>), preservando o papel remanescente quando desejado pelo usuário. A migração <code>019</code>, sincronizada com <code>marketplace_models.dart</code> e <code>duotone_service_icons.dart</code>, expandiu o catálogo para <strong>33 categorias residenciais</strong> com iconografia vetorial <em>Duotone</em>. Simultaneamente, consolidou-se a matriz bilateral de <strong>112 medalhas</strong> (<code>90</code> do Profissional em <code>achievements.dart</code> + <code>22</code> do Cliente em <code>client_achievements.dart</code>), renderizadas em <code>achievement_widgets.dart</code> (<code>AchievementMedalForge</code>) com token prata de alto contraste <code>#CBD5E1</code> para insígnias bloqueadas e ligas metálicas vibrantes para desbloqueadas, além da distribuição <strong>OTA</strong> segura em <code>app_version_and_update_service.dart</code> e <code>pwa_cache_buster_web.dart</code> (<code>ADR-0017</code>).
</p>

<h4 id="sec-6-3-1-f6">Fase 6 — Motor de Garantia 3 Camadas (1,5%), Busca Espacial O(log N + K), KYC Local Tier-0, Passaporte ABNT e UI 120 FPS (<span class="mono">v2.7.0 &rarr; v2.8.2</span> &bull; Migrações <span class="mono">020–022</span> &bull; <span class="mono">ADR-0020</span>)</h4>
<p>
  Na sexta fase, construiu-se o motor fiduciário de alta performance da migração <code>020</code> (<code>20261108110000_high_perf_warranty_antifraud_engine.sql</code>): o livro-razão imutável <code>warranty_pool_ledger</code> (capitalizado por <em>carve-out</em> de <code>1,5%</code> sobre mão de obra sob os 4 invariantes <code>BIGINT</code>), a fila <code>escrow_maturation_entries</code> (<code>D+0/D+2/D+5..D+7</code>), a máquina <code>job_mediations</code> de <strong>Garantia Legal de 90 Dias em 3 Camadas</strong>, a função <span class="math-inline">O(1)</span> <code>hamming_distance_64</code>, o cálculo do <code>Relative Trust Score</code> (<code>0..100</code>) e a ordenação anti-<em>deadlock</em> <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span>. A migração <code>021</code> adicionou validação algébrica de CPF, herança Multi-Modo de KYC (+30 pontos em <code>RTS</code>), trava anti-laranja PIX (<code>pix_key_cpf_matched</code>) e busca geoespacial <em>Axial Bounding Box</em> em <span class="math-inline">O(log N + K)</span> para retrabalho de Camada 3, conjugada ao serviço local <code>document_ocr_and_liveness_service.dart</code> em <code>Isolate.run</code> (custo nuvem <code>R$ 0,00</code>). A migração <code>022</code> instituiu imutabilidade forense pós-conclusão e curadoria LIFO Top-3 + 5 fixados; <code>desperrengue_official_pdf_service.dart</code> passou a emitir em <code>Isolate.run</code> o <strong>Passaporte Predial Oficial ABNT NBR 5674</strong> (<code>%PDF-1.4</code> com selo <code>DSP-PASS-*</code>); e a camada gráfica atingiu orçamento estável de <strong><code>120 FPS</code> (<code>8,33 ms/quadro</code>)</strong> com <code>RepaintBoundary</code>, <code>instant_image_cache_engine.dart</code> (<code>0 ms</code>), <code>EagerImagePrefetcher</code> e <code>unread_orders_badge_controller.dart</code> <span class="math-inline">O(1)</span>.
</p>

<h4 id="sec-6-3-1-f7">Fase 7 — Zero-Trust Bilateral de 2ª Ordem: Smart Split Fiscal SEFAZ, Cofre Anti-Coação, Strip EXIF e dHash (<span class="mono">v2.8.5 &rarr; v2.8.6</span> &bull; Migrações <span class="mono">023–024</span>)</h4>
<p>
  Para blindar o ecossistema contra fraudes sofisticadas de segunda ordem e ameaças físicas presenciais, a migração <code>023</code> (<code>20261110234000_zero_trust_bilateral_antifraud_v285.sql</code>) e <code>zero_trust_bilateral_security_engine.dart</code> introduziram: (i) o particionamento <strong>Smart Split</strong> com <code>0,0%</code> de taxa sobre materiais comprovados por NF-e/NFC-e de 44 dígitos (<code>nfe_access_key.dart</code>, tabela <code>job_fiscal_documents</code>) protegido por auditoria assíncrona SEFAZ Fase 2 após <code>26h</code> e <em>clawback</em> automático de <code>15%</code> sobre notas canceladas; (ii) o <strong>Cofre Dual Anti-Coação</strong> (<em>Silent Duress PIN</em> reverso que exibe tela verde normal ao coator enquanto congela silenciosamente o repasse sob <code>FROZEN_UNDER_DURESS</code>); (iii) custódia atômica de peças substituídas e penalidade de deslocamento contra cancelamentos abusivos de SOS (<code>cancel_sos_with_displacement_slashing</code>); (iv) copresença física bilateral (<code>verify_bilateral_copresence_handshake</code>) e despacho por anéis equiprováveis (<code>0,4–8,0 km</code>); e (v) privacidade e perícia de mídia via <code>image_metadata_stripper.dart</code> (remoção <em>lossless fail-closed</em> de <code>EXIF/GPS</code>) e <code>perceptual_hash_guard.dart</code> (<code>dHash</code> 64 bits), complementados pelas legendas estruturadas <code>photo_annotations</code> na migração <code>024</code>.
</p>

<h4 id="sec-6-3-1-f8">Fase 8 — Microsserviço Python <span class="mono">kyc_engine</span> (Argon + VIO/ICP-Brasil + SERPRO mTLS 1.3 + Carbon SHAP) e Refinamento Ergonômico (<span class="mono">v2.9.0 &rarr; v2.9.5</span> &bull; Migração <span class="mono">025</span> &bull; <span class="mono">ADR-0021</span>)</h4>
<p>
  Na oitava fase, implantou-se o pipeline governamental e multimodal de identidade (<code>ADR-0021</code>): construíram-se as Edge Functions <code>kyc-argon-vision-gate</code> (Gemini 4 Argon High com proteção <code>&lt;untrusted_visual_ocr_stream&gt;</code> e tradutor humano <code>kyc_human_feedback_translator.dart</code>) e <code>kyc-carbon-webhook</code> (<code>timingSafeEqual</code> + migração <code>025</code> <code>kyc_webhook_events</code>), integradas ao microsserviço dedicado Python 3.12 FastAPI <code>kyc_engine/</code> (<code>crypto_doc_validator.py</code> para QR VIO ICP-Brasil <code>CMS PKCS#7 ECDSA P-256</code> e anti-<em>zip-bomb</em> <code>64 KiB</code>; <code>serpro_datavalid.py</code> sob mTLS 1.3 ICP-Brasil A1; <code>fraud_orchestrator.py</code> com 5 <em>Hard Vetos</em> + Gemini 4 Carbon High + Top-3 fatores SHAP para o Art. 20 da LGPD; e cofre WORM <code>KWV2</code> <code>AES-256-GCM</code> em <code>security.py</code>, coberto por <strong>64 testes <code>pytest</code></strong>). No front-end, padronizou-se o container central responsivo de <code>480px</code>, redesenhou-se o cabeçalho de <strong>2 andares</strong> em <code>detalhe_servico_cliente_screen.dart</code> eliminando colisões tipográficas em <code>320px / 1.4x</code>, e construiu-se <code>order_live_map_modal_screen.dart</code> preservando <strong>&ge; 80% de área livre de mapa</strong> com cascata dupla OSRM e curva geodésica <span class="math-inline">C<sup>&infin;</sup></span> de 36 segmentos.
</p>

<h4 id="sec-6-3-1-f9">Fase 9 — Protocolo <em>Temporal &amp; Spatial Geo-Privacy Lock</em> e as 9 Blindagens Red Team de Produção (<span class="mono">v2.10.0 &rarr; v2.11.0</span> + Sync <span class="mono">v2.11.1</span> &bull; Migrações <span class="mono">026–027</span> + <span class="mono">028–030</span> &bull; <span class="mono">ADR-0022</span>)</h4>
<p>
  Culminando na linha de base canônica <code>v2.11.0</code>, a migração <code>026</code> (<code>20261113100000_temporal_geo_privacy_lock.sql</code>), o motor Dart <code>geo_privacy_policy_engine.dart</code> e os componentes de <code>geo_privacy_widgets.dart</code> instituíram o protocolo <strong>Temporal &amp; Spatial Geo-Privacy Lock</strong> (<code>ADR-0022</code>): supressão total de coordenadas exatas em <code>public.jobs</code>, chave secreta CSPRNG de 256 bits em <code>private.geo_privacy_secrets</code>, projeção determinística <code>HMAC-SHA256</code> (deslocamento <code>151m–349m</code> em círculo de <code>500m–800m</code>), retenção estrita de logradouro/número até as <code>00:00:00 America/Sao_Paulo</code> da data agendada e re-ofuscação automática pós-conclusão. Imediatamente a seguir, a migração <code>027</code> (<code>20261113110000_security_hardening_audit.sql</code>) executou as <strong>9 Blindagens Red Team</strong> (<code>[SEC-01]</code> a <code>[SEC-09]</code>: cofre <code>private.job_forensic_secrets</code>, bucket privado <code>forensic-evidence</code>, travas anti-IDOR, revogação de <em>workers</em> internos, reconciliação LGPD e fixação de <code>search_path = public</code> em &ge;35 rotinas <code>SECURITY DEFINER</code>), corroboradas por simulação Monte Carlo de <code>10.000</code> amostras em <code>scripts/test-geo-privacy-sql.mjs</code> e complementadas no <code>HEAD</code> operacional pelas migrações <code>028–030</code> (desativação de <code>checkin_sandbox</code>, <code>register_forensic_photo</code> e status honesto <code>PENDING_SEFAZ</code>).
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="14%">Fase / Marco</th>
      <th width="15%">Migrações / ADRs</th>
      <th width="38%">Principais Artefatos e Módulos Construídos</th>
      <th width="33%">Garantias Formais e Testes Introduzidos</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Fase 1</strong><br/><code>v1.0 &rarr; v1.5</code></td>
      <td>SQL <code>001–003</code><br/><code>ADR-0001..0004</code></td>
      <td><code>profiles</code> (<code>auth.uid()</code>), <code>jobs</code>, <code>quotes</code>, bucket privado <code>kyc_documentos</code>.</td>
      <td>Isolamento <code>RLS</code> inicial, anti-escalada <code>profiles_protect_columns</code> e atomicidade em propostas.</td>
    </tr>
    <tr>
      <td><strong>Fase 2</strong><br/><code>v1.6 &rarr; v2.1</code></td>
      <td>SQL <code>004–009</code><br/><code>ADR-0005..0010</code></td>
      <td><code>client_shell.dart</code>, <code>provider_shell.dart</code>, <code>enviar-email-aprovacao</code>, SOS e PIN 4 dígitos.</td>
      <td>Chaveamento Multi-Modo sem segundo cadastro, anti-<em>self-dealing</em> e WebSockets Realtime.</td>
    </tr>
    <tr>
      <td><strong>Fase 3</strong><br/><code>v2.2 &rarr; v2.3</code></td>
      <td>SQL <code>010–012</code><br/><code>ADR-0011..0013, 0016</code></td>
      <td><code>reviews</code> v2 Bayesiano, <code>provider_achievements</code>, <code>excluir-conta/dossie.ts</code>.</td>
      <td>Avaliações duplo-cegas sem retaliação e <strong>17/17 testes PDF</strong> do Dossiê LGPD (<code>test-dossie.mjs</code>).</td>
    </tr>
    <tr>
      <td><strong>Fase 4</strong><br/><code>v2.4 &rarr; v2.5.5</code></td>
      <td>SQL <code>013–016</code><br/><code>ADR-0014, 0015, 0018, 0019</code></td>
      <td><code>app_tokens.dart</code>, <code>money.dart</code>, <code>client_wallets</code>, <code>ledger_lines</code>, <code>pix-webhook</code>, <code>job_geo</code>.</td>
      <td>Zero ponto flutuante IEEE 754 (<code>&Sigma; cents = 0</code> em <code>BIGINT</code>), PIX CRC16 e geofence Haversine.</td>
    </tr>
    <tr>
      <td><strong>Fase 5</strong><br/><code>v2.6 &rarr; v2.6.5</code></td>
      <td>SQL <code>017–019</code><br/><code>ADR-0017</code></td>
      <td>Índice GIN <code>norm_tag</code>, 33 categorias <em>Duotone</em>, 112 medalhas (<code>#CBD5E1</code>), OTA GitHub.</td>
      <td>Busca de especialidades indexada, deleção escopada (<code>client|provider|all</code>) e <em>host pinning</em> OTA.</td>
    </tr>
    <tr>
      <td><strong>Fase 6</strong><br/><code>v2.7 &rarr; v2.8.2</code></td>
      <td>SQL <code>020–022</code><br/><code>ADR-0020</code></td>
      <td><code>warranty_pool_ledger</code>, <code>document_ocr_and_liveness_service.dart</code>, <code>desperrengue_official_pdf_service.dart</code>, <code>instant_image_cache_engine.dart</code>.</td>
      <td>4 invariantes contábeis, ordem <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span>, busca <span class="math-inline">O(log N + K)</span>, Passaporte ABNT PDF e UI <code>120 FPS</code> / <code>0 ms</code>.</td>
    </tr>
    <tr>
      <td><strong>Fase 7</strong><br/><code>v2.8.5 &rarr; v2.8.6</code></td>
      <td>SQL <code>023–024</code></td>
      <td><code>zero_trust_bilateral_security_engine.dart</code>, <code>nfe_access_key.dart</code>, <code>image_metadata_stripper.dart</code>, <code>perceptual_hash_guard.dart</code>.</td>
      <td><em>Smart Split</em> <code>0%</code> peças + <em>clawback</em> SEFAZ <code>&gt;26h</code>, Cofre Anti-Coação, strip EXIF <em>lossless</em> e <code>dHash</code> <span class="math-inline">O(1)</span>.</td>
    </tr>
    <tr>
      <td><strong>Fase 8</strong><br/><code>v2.9.0 &rarr; v2.9.5</code></td>
      <td>SQL <code>025</code><br/><code>ADR-0021</code></td>
      <td><code>kyc_engine/</code> Python FastAPI, <code>kyc-argon-vision-gate</code>, <code>kyc-carbon-webhook</code>, <code>detalhe_servico_cliente_screen.dart</code>, <code>order_live_map_modal_screen.dart</code>.</td>
      <td><strong>64/64 testes <code>pytest</code></strong> (VIO ICP-Brasil + SERPRO mTLS 1.3 + SHAP LGPD), cabeçalho 2 andares e mapa &ge;80% livre.</td>
    </tr>
    <tr>
      <td><strong>Fase 9</strong><br/><code>v2.10 &rarr; v2.11.0</code> (+<code>v2.11.1</code>)</td>
      <td>SQL <code>026–027</code> (+<code>028–030</code>)<br/><code>ADR-0022</code></td>
      <td><code>private.geo_privacy_secrets</code>, <code>private.job_forensic_secrets</code>, <code>geo_privacy_policy_engine.dart</code>, <code>geo_privacy_widgets.dart</code>.</td>
      <td>Ofuscação <code>HMAC-SHA256</code> até <code>00:00</code> SP, 9 blindagens <code>[SEC-01..09]</code>, <strong>12/12 (14/14 HEAD) SQL Geo-Privacy</strong> e <strong>762 (816 HEAD) testes Flutter</strong>.</td>
    </tr>
  </tbody>
</table>

<h3 id="sec-6-3-2">6.3.2. Quadro Consolidado Oficial de Validação Empírica (<span class="mono">v2.11.0</span>) e Termo de Certificação Arquitetural</h3>
<p>
  Em conformidade com o método hipotético-dedutivo estabelecido no Capítulo 1, a totalidade dos subsistemas documentados neste Tratado é continuamente corroborada por seis baterias automatizadas independentes executadas com código de saída zero (<code>exit code = 0</code>), consolidadas na Tabela 6.10.
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="23%">Frente de Verificação Empírica</th>
      <th width="23%">Comando / Suíte Executável</th>
      <th width="18%">Resultado Auditado (<span class="mono">v2.11.0</span>)</th>
      <th width="36%">Escopo Técnico e Invariantes Cobertos pelas Asserções</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Suíte Completa Mobile/Web Flutter &amp; Dart</strong></td>
      <td><code>flutter test</code><br/>(diretório <code>app/test/</code>)</td>
      <td><span class="badge-ok">762 / 762 PASS</span><br/><small>(45 suítes; <code>816/816</code> em 48 suítes no <code>HEAD</code>)</small></td>
      <td>Modelos de domínio, aritmética inteira <code>Money</code>, 112 medalhas (<code>#CBD5E1</code>), 33 categorias, <code>InstantImageCacheEngine</code>, strip EXIF, <code>PerceptualHashGuard</code>, Cofre Anti-Coação, Passaporte ABNT PDF, Geo-Privacy UI, cabeçalho de 2 andares (<code>320px / 1.4x</code>) e mapa 80% livre.</td>
    </tr>
    <tr>
      <td><strong>2. Pipeline Criptográfico &amp; IA Python KYC</strong></td>
      <td><code>pytest kyc_engine</code><br/>(diretório <code>kyc_engine/tests/</code>)</td>
      <td><span class="badge-ok">64 / 64 PASS</span><br/><small>(3 suítes <em>Red Team</em>)</small></td>
      <td>Assinaturas ICP-Brasil VIO (<code>CMS PKCS#7 ECDSA P-256</code>), defesa anti-<em>zip-bomb</em> <code>64 KiB</code>, anti-<em>Prompt Injection</em> Argon High, cliente SERPRO mTLS 1.3 + <em>Circuit Breaker</em>, 5 <em>Hard Vetos</em> Carbon High, Top-3 SHAP e cofre WORM <code>AES-256-GCM</code>.</td>
    </tr>
    <tr>
      <td><strong>3. Migrações Transacionais PostgreSQL 17</strong></td>
      <td><code>supabase/migrations/</code> +<br/><code>supabase/tests/*.sql</code></td>
      <td><span class="badge-ok">27 / 27 PASS</span><br/><small>(<code>30/30</code> no <code>HEAD</code> + 11 suítes smoke)</small></td>
      <td>Idempotência DDL, integridade referencial, partidas dobradas soma-zero (<code>BIGINT</code>), 4 invariantes de <code>warranty_pool_ledger</code>, ordem de locks <span class="math-inline">R<sub>1</sub> &prec; R<sub>2</sub> &prec; R<sub>3</sub> &prec; R<sub>4</sub></span>, <code>RLS / FORCE RLS</code> e as 9 blindagens <code>[SEC-01]..[SEC-09]</code>.</td>
    </tr>
    <tr>
      <td><strong>4. Auditoria Criptográfica &amp; Monte Carlo Geo-Privacy</strong></td>
      <td><code>node scripts/test-geo-privacy-sql.mjs</code></td>
      <td><span class="badge-ok">12 / 12 PASS</span><br/><small>(<code>14/14</code> no <code>HEAD</code>; <code>10.000</code> amostras)</small></td>
      <td>Segredo CSPRNG 256 bits isolado em <code>private.geo_privacy_secrets</code>, simulação Monte Carlo comprovando deslocamento em <code>[151 m, 349 m]</code> e raio em <code>[500 m, 800 m]</code>, fases <code>00:00:00 America/Sao_Paulo</code> e oráculo zero.</td>
    </tr>
    <tr>
      <td><strong>5. Síntese Vetorial do Dossiê Portável LGPD</strong></td>
      <td><code>node scripts/test-dossie.mjs</code></td>
      <td><span class="badge-ok">17 / 17 PASS</span><br/><small>(6 PDFs A4 multi-página)</small></td>
      <td>Validação estrutural e visual de PDFs gerados por <code>supabase/functions/excluir-conta/dossie.ts</code> nos escopos <code>client</code>, <code>provider</code> e <code>all</code>, incluindo estresse de paginação com 200+ itens em 29 páginas A4 sem truncamento.</td>
    </tr>
    <tr>
      <td><strong>6. Integridade Hipertextual da Documentação</strong></td>
      <td><code>node scripts/check-md-links.mjs</code></td>
      <td><span class="badge-ok">630 / 630 PASS</span><br/><small>(0 links quebrados)</small></td>
      <td>Verificação exaustiva de todas as referências cruzadas, caminhos relativos de código, ADRs, guias operacionais e âncoras na árvore documental completa do projeto.</td>
    </tr>
  </tbody>
</table>

<div class="doc-closing-box">
  <div class="dcb-title">TERMO DE ENCERRAMENTO CIENTÍFICO E CERTIFICAÇÃO ARQUITETURAL — ECOSSISTEMA DESPERRENGUE (v2.11.0)</div>
  <p>
    Certifica-se, para os devidos fins acadêmicos, científicos, corporativos e de auditoria de engenharia de software, que os seis capítulos integrantes deste <strong>Tratado Enciclopédico de Engenharia de Software, Ciência da Computação, Segurança e Negócios — Ecossistema Desperrengue (<code>v2.11.0</code>)</strong> refletem com fidedignidade estrita os algoritmos, esquemas relacionais, protocolos criptográficos, modelos econométricos e suítes automatizadas de verificação presentes no repositório oficial.
  </p>
  <p>
    <strong>Coautoria Científica e Arquitetura de Sistemas:</strong> Wagner Oliveira &amp; Gabriel &bull; <strong>Linha de Base Auditada:</strong> <code>v2.11.0+202611131</code> (com rastreamento operacional até <code>HEAD 53882c8</code>) &bull; <strong>Conformidade Integral:</strong> ISO/IEC/IEEE 29148 &bull; ISO/IEC 25010 &bull; ISO/IEC/IEEE 42010 &bull; CPC 47 / IFRS 15 &bull; LGPD (Lei 13.709/2018) &bull; CDC (Lei 8.078/1990) &bull; ABNT NBR 5674:2012 &bull; W3C WCAG 2.1.
  </p>
</div>
</section>
`;

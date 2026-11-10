export const part2Html = `
<!-- ======================================================================= -->
<!-- CAPÍTULO 5 — CATÁLOGO DE APIS INTERNAS, EDGE FUNCTIONS E EXTERNAS       -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-5"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 05</div>
  <div class="cb-body">
    <h2>CATÁLOGO DE APIS INTERNAS (RPCS PL/PGSQL), EDGE FUNCTIONS E APIS EXTERNAS</h2>
    <p>Especificação completa dos endpoints transacionais SECURITY DEFINER, microsserviços serverless Deno e integrações REST/WebRTC.</p>
  </div>
</div>

<h3>5.1. Catálogo Exaustivo de APIs Internas — RPCs PL/pgSQL (<span class="mono">SECURITY DEFINER</span>)</h3>
<p>
  Para impedir qualquer adulteração contábil ou escalação de privilégios pelo cliente móvel/web, nenhuma tabela crítica aceita <code>UPDATE</code> ou <code>DELETE</code> direto via REST. Toda mutação ocorre através de <strong>Remote Procedure Calls (RPCs)</strong> expostas pelo PostgREST com <code>SECURITY DEFINER</code> e <code>SET search_path = public</code>:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="26%">RPC / Função (<code>public.*</code>)</th>
      <th width="26%">Parâmetros de Entrada</th>
      <th width="12%">Retorno</th>
      <th width="36%">Regras de Negócio, Invariantes e Locks Executados</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>is_valid_cpf</code></td>
      <td><code>p_cpf TEXT</code></td>
      <td><code>BOOLEAN</code></td>
      <td>Higieniza máscara, bloqueia sequências repetidas (<code>000..00</code> a <code>999..99</code>) e valida os 2 dígitos verificadores Módulo 11 em <code>O(1)</code>.</td>
    </tr>
    <tr>
      <td><code>hamming_distance_64</code></td>
      <td><code>hash_a BIGINT, hash_b BIGINT</code></td>
      <td><code>INTEGER</code></td>
      <td>Calcula <code>x := hash_a # hash_b</code> e conta os bits divergentes pelo algoritmo de Brian Kernighan (<code>x := x &amp; (x - 1)</code>) em <code>O(1)</code>.</td>
    </tr>
    <tr>
      <td><code>calculate_relative_trust_score</code></td>
      <td><code>p_kyc, p_mei_months, p_tech_cert, p_completed, p_abandoned</code></td>
      <td><code>NUMERIC(5,2)</code></td>
      <td>Computa o score <code>RTS &isin; [0, 100]</code>: <code>+30</code> (KYC), <code>+20</code> (MEI &ge; 6m), <code>+20</code> (Certificação), <code>+6/OS</code> (até <code>+30</code>) e <code>-50</code> por garantia abandonada.</td>
    </tr>
    <tr>
      <td><code>submit_client_kyc</code></td>
      <td><code>p_cpf_raw, p_typed_full_name, p_ocr_full_name, p_doc_front_phash, p_doc_back_phash, p_selfie_phash, p_liveness_score, p_face_match_similarity, ...</code></td>
      <td><code>JSONB</code></td>
      <td>Valida CPF Módulo 11, impede duplicidade Anti-Sybil de <code>cpf_hash</code>, exige Hamming Frente/Verso <code>&ge; 5</code>, Laplaciano <code>&ge; 110</code>, Glare <code>&le; 8,5%</code>, Liveness <code>&ge; 85%</code> e Face Match <code>&ge; 0,78</code>; ativa <code>liveness_verified</code>, <code>ocr_verified</code> e <code>pix_key_cpf_matched = TRUE</code>.</td>
    </tr>
    <tr>
      <td><code>complete_job_and_schedule_escrow</code></td>
      <td><code>p_job_id, p_provider_id, p_checkout_phash, p_checkout_gps_distance_m, p_client_pin_plain</code></td>
      <td><code>JSONB</code></td>
      <td>Adquire Lock 1 (<code>jobs</code>), valida geofence <code>&le; 150 m</code> e Hamming <code>&ge; 5</code> contra a foto de check-in; se o PIN de 4 dígitos bater com <code>checkout_pin_hash</code>, liquida no ato; senão, agenda <code>auto_release_at = NOW() + 24h</code>.</td>
    </tr>
    <tr>
      <td><code>settle_escrow_with_carveout_and_maturation</code></td>
      <td><code>p_job_id UUID</code></td>
      <td><code>VOID</code></td>
      <td>Executa o <em>Smart Split</em>: retém <code>13,5%</code> operacional e <code>1,5%</code> para <code>warranty_pool_ledger</code> sobre <code>labor_amount</code> (<code>0%</code> sobre <code>materials_amount</code>), abate <code>clawback_debt_balance</code> se existir e agenda maturação <code>D+2 / D+5 / D+7</code>.</td>
    </tr>
    <tr>
      <td><code>open_warranty_mediation</code></td>
      <td><code>p_job_id, p_client_id, p_claim_category, p_defect_description, p_defect_photo_url, p_defect_photo_phash, p_defect_gps_distance_m</code></td>
      <td><code>UUID</code></td>
      <td>Adquire Locks Canônicos (<code>1.jobs &rarr; 2.mediations &rarr; 3.escrow &rarr; 4.profiles</code>), valida geofence <code>&le; 150 m</code> e Hamming <code>&ge; 5</code>, congela o saldo em maturação (<code>FROZEN_BY_DISPUTE</code>) e ativa o disjuntor <code>has_open_dispute = TRUE</code>.</td>
    </tr>
    <tr>
      <td><code>trigger_layer3_rework</code></td>
      <td><code>p_mediation_id, p_rework_labor_budget, p_idempotency_key</code></td>
      <td><code>UUID</code></td>
      <td>Verifica idempotência, valida teto <code>&le; 100%</code> de <code>labor_amount</code>, seleciona 2º especialista via Podagem Axial <code>O(log N + K)</code> + Grafo Zero-Linkage + Cooldown 24h, executa <em>Clawback First</em> sobre a retenção do 1º prestador e cria a OS de retrabalho.</td>
    </tr>
    <tr>
      <td><code>process_autonomous_escrow_and_mediation_queues</code></td>
      <td><code>()</code> (Sem argumentos — Worker Cron)</td>
      <td><code>JSONB</code></td>
      <td>Varre filas em lotes de 100 via <code>FOR UPDATE SKIP LOCKED</code>, convertendo serviços com SLA de 24h expirado sem disputa e liberando saldos maturados (<code>D+N</code>) para saque PIX imediato.</td>
    </tr>
    <tr>
      <td><code>save_curated_portfolio_5</code></td>
      <td><code>p_urls TEXT[], p_notes JSONB</code></td>
      <td><code>JSONB</code></td>
      <td>Salva atomicamente a seleção de até 5 fotos de destaque do portfólio do especialista em <code>profiles.curated_portfolio_urls</code> e suas notas técnicas em <code>provider_portfolio_notes</code>.</td>
    </tr>
    <tr>
      <td><code>check_account_deletion_status</code> &amp; <code>delete_own_account_scoped</code></td>
      <td><code>p_scope TEXT ('client' | 'provider' | 'all')</code></td>
      <td><code>JSONB</code></td>
      <td>Verifica bloqueadores financeiros (saldo disponível &gt; 0, custódia retida ou serviço ativo) e executa anonimização seletiva de PII conforme o Art. 18 da LGPD.</td>
    </tr>
  </tbody>
</table>

<h3>5.2. Microsserviços Serverless (Supabase Edge Functions) e APIs Externas Consumidas</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="25%">Serviço / API</th>
      <th width="18%">Protocolo / Tipo</th>
      <th width="57%">Detalhamento Técnico de Integração e Tratamento de Falhas</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>supabase/functions/pix-webhook</code></td>
      <td>Edge Function (Deno HTTPS POST)</td>
      <td>Recebe callbacks de liquidação PIX do gateway bancário, valida assinatura/token e invoca de forma idempotente a confirmação de recarga na carteira do cliente (<code>pix_topups</code> &rarr; <code>client_wallets</code>), disparando evento Realtime para a UI.</td>
    </tr>
    <tr>
      <td><code>supabase/functions/enviar-email-aprovacao</code></td>
      <td>Edge Function + Resend REST API</td>
      <td>Dispara e-mails transacionais HTML com identidade visual oficial via <code>api.resend.com</code> (domínio <code>desperrengue.tech</code> autenticado por DKIM/SPF/DMARC) quando o dossiê KYC do profissional é aprovado, contendo deep link <code>br.com.desperrengue.app://login-callback</code>.</td>
    </tr>
    <tr>
      <td><code>supabase/functions/excluir-conta</code></td>
      <td>Edge Function (Admin Service Role)</td>
      <td>Executa a remoção final da credencial em <code>auth.users</code> após a RPC <code>delete_own_account_scoped</code> confirmar a ausência de pendências financeiras e anonimizar os dados públicos.</td>
    </tr>
    <tr>
      <td><strong>ViaCEP REST API</strong> (<code>viacep.com.br</code>)</td>
      <td>HTTPS GET JSON</td>
      <td>Consulta instantânea de logradouro, bairro, município, UF e código IBGE a partir do CEP de 8 dígitos no cadastro do imóvel e do profissional.</td>
    </tr>
    <tr>
      <td><strong>Nominatim / OpenStreetMap Geocoder</strong> (<code>PreciseGeocoder</code>)</td>
      <td>HTTPS GET JSON (Cascata 3 Níveis)</td>
      <td>Converte endereços estruturados em coordenadas <code>(lat, lng)</code> com busca em cascata (1º Rua + Número + Cidade; 2º Rua + Bairro + Cidade; 3º Centroide do CEP), garantindo pino exato no mapa mesmo em ruas recém-numeradas.</td>
    </tr>
    <tr>
      <td><strong>GitHub Releases API</strong> (<code>AppUpdateService</code>)</td>
      <td>HTTPS GET JSON</td>
      <td>Consulta <code>/repos/WagnerxOliveira/DesperrengueApp_TAI3/releases/tags/beta-latest</code> no boot do app para comparar o <code>buildNumber</code> e oferecer atualização OTA automática do APK.</td>
    </tr>
    <tr>
      <td><strong>WebRTC MediaDevices &amp; Speech-to-Text Nativo</strong></td>
      <td>Hardware / Browser Native APIs</td>
      <td>Streaming de câmera frontal/traseira em tempo real para biometria e scanner de documentos, e ditado por voz em português para abertura de chamados em menos de 60 segundos.</td>
    </tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- CAPÍTULO 6 — VISÃO COMPUTACIONAL ON-DEVICE, BIOMETRIA 3D E OCR          -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-6"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 06</div>
  <div class="cb-body">
    <h2>VISÃO COMPUTACIONAL ON-DEVICE, PROVA DE VIDA FACIAL AO VIVO (LIVENESS 3D) E OCR ISO ID-1</h2>
    <p>Engenharia biométrica executada 100% localmente em Worker Isolates (custo marginal R$ 0,00), antispoofing de monitores e Face Match 128-D multi-orientação.</p>
  </div>
</div>

<h3>6.1. Blueprint Vetorial do Pipeline de Biometria Ao Vivo e Scanner Documental ISO ID-1</h3>
<div class="svg-diagram-box">
  <svg viewBox="0 0 880 310" width="100%" xmlns="http://www.w3.org/2000/svg">
    <!-- Lado Esquerdo: Câmera Frontal Oval -->
    <rect x="14" y="12" width="420" height="286" rx="12" fill="#0F172A" stroke="#38BDF8" stroke-width="1.5"/>
    <text x="30" y="36" fill="#38BDF8" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">ETAPA 3 — CÂMERA FRONTAL AO VIVO (MOLDURA OVAL)</text>
    <ellipse cx="145" cy="165" rx="76" ry="102" fill="#1E293B" stroke="#10B981" stroke-width="3" stroke-dasharray="8,4"/>
    <!-- Olhos e Eixo Yaw -->
    <ellipse cx="118" cy="142" rx="14" ry="7" fill="none" stroke="#F8FAFC" stroke-width="2"/>
    <circle cx="118" cy="142" r="3" fill="#38BDF8"/>
    <ellipse cx="172" cy="142" rx="14" ry="7" fill="none" stroke="#F8FAFC" stroke-width="2"/>
    <circle cx="172" cy="142" r="3" fill="#38BDF8"/>
    <path d="M 145 148 L 141 176 L 151 178" fill="none" stroke="#94A3B8" stroke-width="2"/>
    <path d="M 122 204 Q 145 220 168 204" fill="none" stroke="#FF6D00" stroke-width="2.5"/>
    <!-- Textos Explicativos Liveness -->
    <text x="240" y="72" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">1. Segmentação Epidérmica YCbCr:</text>
    <text x="240" y="88" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">• 77 &le; Cb &le; 127 e 133 &le; Cr &le; 173</text>
    <text x="240" y="103" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">• Fração de pele no oval: 22% a 82%</text>
    <text x="240" y="128" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">2. Antispoofing de Monitor/Telas:</text>
    <text x="240" y="144" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">• Rejeita excesso de canal azul LCD</text>
    <text x="240" y="159" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">  (blueMonitorRatio &lt; 0,25)</text>
    <text x="240" y="184" fill="#F8FAFC" font-size="11" font-weight="bold" font-family="Segoe UI, sans-serif">3. Desafios Físicos Sequenciais:</text>
    <text x="240" y="200" fill="#6EE7B7" font-size="10" font-family="Segoe UI, sans-serif">• Piscada: EAR &lt; 0,18 &rarr; EAR &gt; 0,25</text>
    <text x="240" y="215" fill="#6EE7B7" font-size="10" font-family="Segoe UI, sans-serif">• Rotação 3D: |&theta;_yaw| &ge; 18,0°</text>
    <text x="240" y="230" fill="#6EE7B7" font-size="10" font-family="Segoe UI, sans-serif">• Retorno ao centro (&le; 6°) + Captura</text>
    <rect x="240" y="246" width="176" height="32" rx="6" fill="#064E3B" stroke="#10B981"/>
    <text x="250" y="266" fill="#ECFDF5" font-size="10" font-weight="bold" font-family="Segoe UI, sans-serif">Selo: DSP-LIVE-SHA256 (On-Device)</text>

    <!-- Lado Direito: Scanner ISO ID-1 -->
    <rect x="446" y="12" width="420" height="286" rx="12" fill="#0F172A" stroke="#FF6D00" stroke-width="1.5"/>
    <text x="462" y="36" fill="#FF8A2B" font-size="12" font-weight="bold" font-family="Segoe UI, sans-serif">ETAPA 4 — SCANNER GUIADO ISO/IEC 7810 ID-1 (1,586:1)</text>
    <!-- Moldura Externa ID-1 -->
    <rect x="466" y="54" width="380" height="145" rx="10" fill="#1E293B" stroke="#F8FAFC" stroke-width="2"/>
    <!-- Core ROI Inset 12% -->
    <rect x="488" y="68" width="336" height="117" rx="6" fill="#0B1120" stroke="#38BDF8" stroke-width="1.5" stroke-dasharray="6,4"/>
    <text x="498" y="84" fill="#38BDF8" font-size="9.5" font-weight="bold" font-family="Segoe UI, sans-serif">CORE ROI INSET (12% MARGEM INTERNA — IGNORA MESA DE MADEIRA)</text>
    <!-- Foto 3x4 no Documento -->
    <rect x="500" y="94" width="58" height="76" rx="4" fill="#1E3A8A" stroke="#60A5FA" stroke-width="1.5"/>
    <text x="509" y="128" fill="#FFFFFF" font-size="9" font-weight="bold" font-family="Segoe UI, sans-serif">FOTO 3x4</text>
    <text x="506" y="142" fill="#93C5FD" font-size="8" font-family="Segoe UI, sans-serif">128-D L2</text>
    <text x="506" y="154" fill="#93C5FD" font-size="8" font-family="Segoe UI, sans-serif">0°|90°|180°|270°</text>
    <!-- Campos OCR -->
    <text x="572" y="106" fill="#E2E8F0" font-size="10" font-weight="bold" font-family="Segoe UI, sans-serif">REPÚBLICA FEDERATIVA DO BRASIL • CNH / RG / CIN</text>
    <text x="572" y="124" fill="#6EE7B7" font-size="9.5" font-family="Segoe UI, sans-serif">• Nome Civil Extraído (Token Match &ge; 80%)</text>
    <text x="572" y="140" fill="#6EE7B7" font-size="9.5" font-family="Segoe UI, sans-serif">• CPF Extraído == CPF Etapa 1 (Módulo 11)</text>
    <text x="572" y="156" fill="#6EE7B7" font-size="9.5" font-family="Segoe UI, sans-serif">• Nitidez Laplaciana &sigma;² &ge; 110 | Glare &le; 8,5%</text>
    <text x="572" y="172" fill="#FDBA74" font-size="9.5" font-weight="bold" font-family="Segoe UI, sans-serif">• Face Match Cosseno 128-D &ge; 78,0%</text>

    <!-- Rodapé Explicativo Scanner -->
    <text x="466" y="222" fill="#F8FAFC" font-size="10.5" font-weight="bold" font-family="Segoe UI, sans-serif">Trava Anti-Duplicidade Frente &times; Verso e Anti-Falso-Positivo:</text>
    <text x="466" y="238" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">• Combina Distância de Hamming (dHash 64-bit) + Diferença Absoluta Média</text>
    <text x="466" y="253" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">  (MAD_64x64) + Variância de Quadrantes exclusivamente dentro do Core ROI (12%),</text>
    <text x="466" y="268" fill="#CBD5E1" font-size="10" font-family="Segoe UI, sans-serif">  impedindo que a mesma face do documento passe como Frente e Verso.</text>
  </svg>
</div>

<h3>6.2. Formulação Matemática dos Validadores de Visão Computacional (<span class="mono">document_ocr_and_liveness_service.dart</span>)</h3>
<ol>
  <li>
    <strong>Segmentação de Crominância Epidérmica Humana no Espaço <code>YCbCr</code> e Bloqueio de Monitores:</strong><br/>
    Para impedir que o usuário aponte a câmera para um monitor de computador (exibindo código no VS Code), uma parede ou uma folha impressa, cada pixel <code>(R, G, B)</code> no interior da elipse normalizada <code>(x &minus; c<sub>x</sub>)<sup>2</sup> / a<sup>2</sup> + (y &minus; c<sub>y</sub>)<sup>2</sup> / b<sup>2</sup> &le; 1</code> é projetado no espaço de luminância-crominância:
    <div class="math-formula-box">
      Y = 0,299R + 0,587G + 0,114B &nbsp;&bull;&nbsp; C<sub>b</sub> = 128 &minus; 0,168736R &minus; 0,331264G + 0,5B &nbsp;&bull;&nbsp; C<sub>r</sub> = 128 + 0,5R &minus; 0,418688G &minus; 0,081312B<br/>
      Pixel Epidérmico Válido &hArr; (77 &le; C<sub>b</sub> &le; 127) &and; (133 &le; C<sub>r</sub> &le; 173) &and; (42 &le; Y &le; 235)
    </div>
    O frame só avança nos desafios se a razão de pele satisfizer <code>0,22 &le; &tau;<sub>skin</sub> &le; 0,82</code>, a emissão azulada de telas LCD/OLED satisfizer <code>&tau;<sub>blueMonitor</sub> &lt; 0,25</code> e houver simetria bilateral entre os hemisférios faciais esquerdo e direito.
  </li>
  <li>
    <strong>Cinemática da Piscada Bilateral (<code>EAR</code>) e Rotação Cefálica 3D (<code>Yaw</code>):</strong><br/>
    A abertura palpebral é monitorada pela <em>Eye Aspect Ratio</em> sobre os 6 marcos oculares <code>p<sub>1</sub>..p<sub>6</sub></code>:
    <div class="math-formula-box">
      EAR = ( ||p<sub>2</sub> &minus; p<sub>6</sub>||<sub>2</sub> + ||p<sub>3</sub> &minus; p<sub>5</sub>||<sub>2</sub> ) / ( 2 &bull; ||p<sub>1</sub> &minus; p<sub>4</sub>||<sub>2</sub> ) &nbsp;&bull;&nbsp; Transição Validada: EAR<sub>base</sub> &gt; 0,25 &rarr; EAR<sub>fechado</sub> &lt; 0,18 &rarr; EAR<sub>retorno</sub> &gt; 0,25
    </div>
  </li>
  <li>
    <strong>Nitidez por Convolução Laplaciana <code>3 &times; 3</code> e Face Match 128-D Não-Negativo Multi-Orientação:</strong><br/>
    No scanner documental ISO ID-1, a imagem recortada passa pela convolução com o kernel Laplaciano <code>L = [[0, 1, 0], [1, -4, 1], [0, 1, 0]]</code>, exigindo variância <code>&sigma;<sub>L</sub><sup>2</sup> &ge; 110,0</code>. Para o <strong>Face Match 1:1</strong> entre a selfie ao vivo e a foto <code>3 &times; 4</code> do documento (que pode ter sido fotografado a <code>0&deg;, 90&deg;, 180&deg;</code> ou <code>270&deg;</code>), o algoritmo avalia as 4 orientações canônicas sobre vetores de características estritamente não-negativos de 128 dimensões (<code>A<sub>k</sub> &ge; 0, B<sub>k</sub> &ge; 0</code>), garantindo que a Similaridade de Cosseno pertença ao intervalo <code>[0%, 100%]</code> e exigindo <code>max<sub>&theta; &isin; {0&deg;, 90&deg;, 180&deg;, 270&deg;}</sub> S<sub>cos</sub>(A, B<sub>&theta;</sub>) &ge; 78,0%</code>.
  </li>
</ol>

<!-- ======================================================================= -->
<!-- CAPÍTULO 7 — TODAS AS FUNCIONALIDADES, MVP E BACKLOG EVOLUTIVO          -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-7"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 07</div>
  <div class="cb-body">
    <h2>ECOSSISTEMA COMPLETO DE FUNCIONALIDADES, MVP (PRODUTO MÍNIMO VIÁVEL) E BACKLOG</h2>
    <p>Mapeamento detalhado de todas as telas e fluxos dos modos Cliente e Profissional, definição do MVP entregue e backlog priorizado de evolução.</p>
  </div>
</div>

<h3>7.1. Mapeamento Exaustivo de Todas as Funcionalidades Implementadas (<span class="mono">v2.8.2</span>)</h3>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="20%">Módulo / Eixo</th>
      <th width="28%">Funcionalidade / Tela</th>
      <th width="52%">Descrição Técnica e Experiência do Usuário Implementada</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5"><strong>1. Modo Cliente<br/>(Demanda Residencial)</strong></td>
      <td><strong>Onboarding KYC em 4 Etapas</strong> (<code>ClientSetupScreen</code>)</td>
      <td>(1) Identificação civil com validação aritmética de CPF Módulo 11 em tempo real; (2) Endereço georreferenciado via CEP; (3) Biometria facial ao vivo na moldura oval (3 desafios); (4) Scanner ISO ID-1 (Frente e Verso) com Face Match 128-D e card de transcrição OCR visível.</td>
    </tr>
    <tr>
      <td><strong>Triagem Multimodal &amp; Ditado por Voz (&lt; 60s)</strong></td>
      <td>Busca inteligente nas <strong>33 categorias técnicas</strong> com reconhecimento de voz (<code>speech_to_text</code>), formatação automática do relato (<code>SmartTranscriptFormatter</code>), captura de fotos/vídeo do problema e escolha entre urgência imediata (<code>SOS</code>) ou agendamento.</td>
    </tr>
    <tr>
      <td><strong>Mapa Ordenado por Mérito (<code>1º, 2º, 3º</code>)</strong></td>
      <td>Exibe no mapa vetorial os especialistas disponíveis na região ordenados pelo <em>Tiered Waterfall</em> e nota real, permitindo convite direto ou recebimento de propostas no <code>WaitingQuotesScreen</code>.</td>
    </tr>
    <tr>
      <td><strong>Carteira Digital &amp; Checkout Smart Escrow</strong></td>
      <td>Recarga instantânea via QR Code PIX (com chave de idempotência anti-duplo-clique), máscara de privacidade (<code>R$ •••••</code>), verificação automática de déficit (<code>InsufficientFundsBottomSheet</code>) e geração do PIN presencial de 4 dígitos para aprovar o serviço.</td>
    </tr>
    <tr>
      <td><strong>Passaporte Oficial do Imóvel (ABNT NBR 5674)</strong></td>
      <td>Tela <em>Prontuário da Casa</em> seguindo a diretriz <em>Zero Fake Data</em> (jornada educativa para imóveis sem histórico e linha do tempo auditada para serviços concluídos), com exportação em 1 toque de laudo PDF vetorial (<code>%PDF-1.4</code>) assinado com hash <code>SHA-256</code> (<code>DSP-PASS-*</code>).</td>
    </tr>
    <tr>
      <td rowspan="6"><strong>2. Modo Profissional<br/>(Oferta Técnica)</strong></td>
      <td><strong>Credenciamento Profissional &amp; Reuso KYC (+30 pts)</strong></td>
      <td>Fluxo de verificação em etapas com reaproveitamento automático da biometria/OCR caso o usuário já tenha validado sua identidade no modo Cliente, concedendo <code>+30 pts</code> imediatos no <code>RTS</code>.</td>
    </tr>
    <tr>
      <td><strong>Painel Executivo de Alta Performance (<code>DashboardTab</code>)</strong></td>
      <td>Interface limpa, sem jargões técnicos desnecessários e sem cartões duplicados: exibe saudação humanizada, chave <em>Disponível para novos serviços</em>, métricas financeiras clicáveis, meta semanal ajustável e atalhos para as <strong>Ferramentas Rápidas do Especialista</strong>.</td>
    </tr>
    <tr>
      <td><strong>Calculadora de Orçamento Smart Split</strong></td>
      <td>Ferramenta interativa para simular orçamentos separando Mão de Obra e Materiais/Peças (0% de taxa), calculando instantaneamente o líquido a receber pelo especialista sem qualquer erro de layout em teclados móveis.</td>
    </tr>
    <tr>
      <td><strong>Dossiê &amp; Vitrine Curada de 5 Fotos + Notas</strong></td>
      <td>Gerenciador de portfólio (<code>ProviderPortfolioCuratorSheet</code>) que permite selecionar até 5 fotos reais de serviços, adicionar notas técnicas explicativas e visualizá-las em tela cheia com zoom (<code>InteractiveViewer</code>) a partir do bucket público/privado.</td>
    </tr>
    <tr>
      <td><strong>Mural Interativo de Selos &amp; Avaliações Cegas</strong></td>
      <td>Em <em>Minhas avaliações</em> (<code>BadgeWall</code>), tocar em qualquer selo conquistado ou próximo selo (ex.: <em>Super Profissional</em>, <em>Sempre Pontual</em>, <em>Preço Honesto</em>) abre um modal elegante detalhando o requisito exato, a barra de progresso e dicas práticas para conquistá-lo.</td>
    </tr>
    <tr>
      <td><strong>Carteira Bipartida &amp; Histórico Estável</strong></td>
      <td>Aba <code>WalletTab</code> com separação entre <em>Saldo Disponível (PIX Livre)</em> e <em>Em Proteção Pós-Serviço</em>, itens clicáveis em <em>Próximas liberações</em> e tela <code>ProviderFullHistoryScreen</code> com faixa horizontal de filtros de altura fixa (46px) que nunca desloca a lista para baixo.</td>
    </tr>
    <tr>
      <td rowspan="2"><strong>3. Módulos Compartilhados &amp; Governança</strong></td>
      <td><strong>4ª Aba Condicional "Em Mediação"</strong></td>
      <td>Ativada dinamicamente quando há disputa aberta; exibe a máquina de estados de 5 fases, o cronômetro regressivo de SLA (6h/24h) e o <strong>Comparador Forense Triplo (<code>ANTES | DEPOIS | RECLAMAÇÃO</code>)</strong> com selos <code>dHash</code> 64-bit e distância GPS.</td>
    </tr>
    <tr>
      <td><strong>Troca Instantânea de Papel &amp; Exclusão Escopada LGPD</strong></td>
      <td>Alternância em 1 toque entre Cliente e Profissional (<code>RoleSelectionScreen</code>) lembrando o último perfil usado, e exclusão segura de conta por escopo (excluir apenas Cliente, apenas Profissional ou Conta Inteira) com trava protetora de saldo.</td>
    </tr>
  </tbody>
</table>

<h3>7.2. Definição Formal do MVP (Produto Mínimo Viável) vs. Backlog Evolutivo do Produto</h3>
<p>
  O <strong>MVP (Produto Mínimo Viável)</strong> do Desperrengue foi projetado não como um protótipo frágil, mas como um <strong>Minimum Lovable &amp; Trustworthy Product (MLTP)</strong>, pois em serviços domiciliares e custódia financeira não se pode lançar sem segurança física e contábil. Todo o escopo dos <strong>Épicos E1 a E6 (MVP Core + Blindagem Fintech + Biometria 3D + Passaporte ABNT) encontra-se 100% concluído, testado e em produção na versão <code>v2.8.2</code></strong>. Abaixo apresenta-se a matriz consolidada do MVP entregue e do <strong>Backlog Evolutivo Priorizado (Épicos E7 a E10 — Horizonte 2027)</strong>:
</p>

<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="10%">ID</th>
      <th width="26%">Épico / Item de Backlog</th>
      <th width="14%">Classificação</th>
      <th width="12%">Prioridade / Peso</th>
      <th width="38%">Critérios de Aceitação e Entregáveis Técnicos</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>E1–E2</code></td>
      <td><strong>Autenticação PKCE, Perfil Unificado Multi-Modo e Catálogo de 33 Categorias com Voz</strong></td>
      <td><span class="badge-ok">MVP ENTREGUE</span></td>
      <td>P0 &bull; Crítico (100%)</td>
      <td>Login e-mail/Google, alternância Cliente/Prestador, ditado por voz &lt; 60s, geocodificação em cascata e mapa ordenado (1º, 2º, 3º).</td>
    </tr>
    <tr>
      <td><code>E3–E4</code></td>
      <td><strong>Custódia Smart Escrow, Smart Split (0% Peças) e Garantia em 3 Camadas</strong></td>
      <td><span class="badge-ok">MVP ENTREGUE</span></td>
      <td>P0 &bull; Crítico (100%)</td>
      <td>Livro-razão <code>warranty_pool_ledger</code> (1,5% carve-out), maturação D+2/D+5/D+7, PIN de 4 dígitos, 4ª aba "Em Mediação" e despacho cego de Camada 3.</td>
    </tr>
    <tr>
      <td><code>E5–E6</code></td>
      <td><strong>Biometria Facial Ao Vivo, Scanner OCR ISO ID-1 e Passaporte ABNT NBR 5674</strong></td>
      <td><span class="badge-ok">MVP ENTREGUE</span></td>
      <td>P0 &bull; Crítico (100%)</td>
      <td>Liveness oval (YCbCr/EAR/Yaw), Scanner ID-1 (0°..270°), Face Match 128-D &ge; 78%, <code>dHash + MAD</code> em ROI 12% e exportação PDF <code>%PDF-1.4</code> SHA-256.</td>
    </tr>
    <tr>
      <td><code>BL-01</code></td>
      <td><strong>Portal Web &amp; API Gateway B2B para Imobiliárias e Seguradoras</strong></td>
      <td><span class="badge-plan">BACKLOG Q1/27</span></td>
      <td>P1 &bull; Alta (13 Story Pts)</td>
      <td>Dashboard multi-inquilino para imobiliárias validarem lotes de Passaportes ABNT NBR 5674 na entrega de chaves via webhook e QR Code.</td>
    </tr>
    <tr>
      <td><code>BL-02</code></td>
      <td><strong>Integração Direta SEFAZ (Consulta NF-e 44 Dígitos) e Split Direto com Lojas de Materiais</strong></td>
      <td><span class="badge-plan">BACKLOG Q1/27</span></td>
      <td>P1 &bull; Alta (13 Story Pts)</td>
      <td>Validação criptográfica automática de notas fiscais de materiais na SEFAZ e pagamento direto do <em>Escrow</em> para o CNPJ da loja de construção.</td>
    </tr>
    <tr>
      <td><code>BL-03</code></td>
      <td><strong>Attestation Criptográfica de Hardware (Play Integrity API &amp; Apple App Attest)</strong></td>
      <td><span class="badge-plan">BACKLOG Q2/27</span></td>
      <td>P1 &bull; Alta (8 Story Pts)</td>
      <td>Verificação de integridade de bootloader e assinatura de hardware em todas as RPCs sensíveis para bloquear emuladores e câmeras virtuais injetadas.</td>
    </tr>
    <tr>
      <td><code>BL-04</code></td>
      <td><strong>Planos de Manutenção Preventiva Condominial e Assinatura Recorrente (PIX Automático)</strong></td>
      <td><span class="badge-plan">BACKLOG Q2/27</span></td>
      <td>P2 &bull; Média (8 Story Pts)</td>
      <td>Alertas automáticos de revisão de ar-condicionado, limpeza de caixa d'água e reaperto de QDC elétrico conforme calendário da ABNT NBR 5674.</td>
    </tr>
  </tbody>
</table>
`;

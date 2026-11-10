export const part4Html = `
<!-- ======================================================================= -->
<!-- CAPÍTULO 12 — ESPECIFICAÇÃO FORMAL DE TODAS AS REGRAS NORMATIVAS (RN)   -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-12"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 12</div>
  <div class="cb-body">
    <h2>ESPECIFICAÇÃO NORMATIVA EXAUSTIVA (RN-CAM, RN-AF, RN-MZ, RN-KYC) E RASTREABILIDADE</h2>
    <p>Detalhamento individual de todas as 28 regras normativas de engenharia, parâmetros de calibração e matriz de rastreabilidade código &times; teste.</p>
  </div>
</div>

<h3>12.1. Catálogo Completo das 14 Regras Normativas Antifraude (<span class="mono">RN-AF-01</span> a <span class="mono">RN-AF-14</span>)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="12%">Código</th>
      <th width="26%">Designação Normativa</th>
      <th width="62%">Implementação Determinística no PostgreSQL e no Cliente Flutter</th>
    </tr>
  </thead>
  <tbody>
    <tr><td><code>RN-AF-01</code></td><td>Proibição de Saque em Espécie do Fundo Garantidor</td><td>Na Camada 3, o saldo do <code>warranty_pool_ledger</code> jamais é transferido em espécie para a conta bancária do cliente; ele remunera exclusivamente a execução técnica de um 2º profissional independente.</td></tr>
    <tr><td><code>RN-AF-02</code></td><td>Despacho Algorítmico Cego Ponderado no Servidor</td><td>Na Camada 3 (<code>trigger_layer3_rework</code>), o cliente não escolhe quem fará o retrabalho; a seleção ocorre no servidor usando <code>hashtextextended(p.id::TEXT || p_mediation_id::TEXT, 0)</code> como desempate pseudoaleatório determinístico.</td></tr>
    <tr><td><code>RN-AF-03</code></td><td>Podagem por Disjunção em Grafo Zero-Linkage</td><td>Exclui da Camada 3 qualquer prestador que compartilhe <code>device_fingerprint_hash</code>, <code>cpf_hash</code>, <code>face_liveness_hash</code> ou histórico prévio em <code>public.jobs</code> tanto com o cliente quanto com o 1º prestador.</td></tr>
    <tr><td><code>RN-AF-04</code></td><td>Inversão da Fonte Pagadora (<em>Clawback First</em>) e Penalidade RTS</td><td>Confisca prioritariamente a retenção em maturação (<code>CLAWED_BACK</code>) do 1º prestador infrator, subtrai <code>-50 pontos</code> no seu score <em>RTS</em> e inscreve eventual diferença em <code>clawback_debt_balance</code>.</td></tr>
    <tr><td><code>RN-AF-05</code></td><td>Check-in e Check-out Geolocalizados (&le; 150m)</td><td>Exige captura de coordenadas GNSS a uma distância máxima de <code>150,0 metros</code> do endereço do serviço (<code>checkin_gps_distance_m</code> e <code>checkout_gps_distance_m</code>) com emissão de <code>forensic_certificates</code>.</td></tr>
    <tr><td><code>RN-AF-06</code></td><td>Liquidação Presencial Irrevogável por PIN de 4 Dígitos</td><td>A digitação do PIN de 4 dígitos fornecido presencialmente pelo cliente valida <code>crypt(p_client_pin_plain, checkout_pin_hash)</code> e converte imediatamente o serviço para maturação sem necessidade de aguardar 24h.</td></tr>
    <tr><td><code>RN-AF-07</code></td><td>Liberação Automática por Decurso de SLA de 24 Horas</td><td>Caso o cliente se omita após o check-out fotográfico válido e não abra contestação fundamentada em 24 horas (<code>auto_release_at</code>), o worker assíncrono libera automaticamente o pagamento para a fila de maturação.</td></tr>
    <tr><td><code>RN-AF-08</code></td><td>Obrigatoriedade de Sensor Óptico Físico Nativo</td><td>Todos os fluxos de check-in, check-out, abertura de garantia e KYC bloqueiam o seletor de galeria de arquivos nos fluxos forenses, impondo captura direta da lente física (<code>ImageSource.camera</code>).</td></tr>
    <tr><td><code>RN-AF-09</code></td><td>Bloqueio de Localização Simulada (<em>Anti-Mock GPS</em>)</td><td>Inspeciona a flag de sistema <code>Position.isMocked</code> do pacote <code>geolocator</code>, rejeitando imediatamente submissões originadas de aplicativos de falsificação de coordenadas.</td></tr>
    <tr><td><code>RN-AF-10</code></td><td>Deduplicação Óptica por Distância de Hamming 64-Bit (&ge; 5 bits)</td><td>Calcula o <code>dHash</code> perceptual de 64 bits de cada evidência e rejeita em <code>O(1)</code> qualquer imagem de conclusão ou defeito cuja distância de Hamming em relação às fotos anteriores seja inferior a 5 bits (<code>ERR_RECYCLED_CHECKOUT_PHOTO</code>).</td></tr>
    <tr><td><code>RN-AF-11</code></td><td>Particionamento Assimétrico <em>Smart Split</em> com Comprovante</td><td>Segrega estritamente <code>labor_amount</code> (sujeito a 13,5% + 1,5%) e <code>materials_amount</code> (sujeito a 0% de taxa mediante nota/recibo de insumos), impedindo bitributação e evasão.</td></tr>
    <tr><td><code>RN-AF-12</code></td><td>Teto Estrito de Cobertura de Retrabalho (Invariante 1)</td><td>A constraint declarativa <code>chk_invariant_1_coverage_cap</code> garante que nenhum pagamento de retrabalho da Camada 3 ultrapasse 100% do valor de mão de obra da OS original (<code>amount &le; labor_reference_cap</code>).</td></tr>
    <tr><td><code>RN-AF-13</code></td><td>Reserva Estendida Cold-Start (D+7), Disjuntor e Cooldown 24h</td><td>Aplica maturação de 7 dias para iniciantes (<code>TRAINEE</code>), ativa <code>has_open_dispute = TRUE</code> no ato da reclamação e exige intervalo mínimo de 24 horas entre resgates de Camada 3 pelo mesmo socorrista (<code>idx_jobs_rescuer_cooldown_24h</code>).</td></tr>
    <tr><td><code>RN-AF-14</code></td><td>Bloqueio Anti-Sybil por CPF Salgado, Biometria 128-D e PIX Lock</td><td>Impede recriação de contas por banidos através do índice único <code>idx_profiles_cpf_hash_unique</code> (<code>SHA-256 + Pepper</code>), índice facial <code>idx_profiles_face_liveness_hash</code> e trava de titularidade bancária <code>pix_key_cpf_matched = TRUE</code>.</td></tr>
  </tbody>
</table>

<h3>12.2. Catálogo dos 5 Pilares do Marco Zero (<span class="mono">RN-MZ-01</span> a <span class="mono">RN-MZ-05</span>) e 6 Regras KYC (<span class="mono">RN-KYC-01</span> a <span class="mono">RN-KYC-06</span>)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="14%">Código</th>
      <th width="28%">Pilar / Regra Forense</th>
      <th width="58%">Especificação Técnica e Parâmetros Matemáticos</th>
    </tr>
  </thead>
  <tbody>
    <tr><td><code>RN-MZ-01</code></td><td>Reserva Rotativa Escalonada (<em>Tiered Rolling Reserve</em>)</td><td>Janela de maturação ajustada ao nível de risco: <strong>D+2</strong> para <code>VERIFIED_ANCHOR</code>, <strong>D+5</strong> para <code>STANDARD</code> (&ge; 3 serviços concluídos) e <strong>D+7</strong> para <code>TRAINEE</code> (&lt; 3 serviços).</td></tr>
    <tr><td><code>RN-MZ-02</code></td><td>Cálculo em <code>O(1)</code> do <em>Relative Trust Score</em> (<em>RTS</em>)</td><td>Função imutável que pondera sinais intrínsecos (+30 pts KYC/OCR, +20 pts MEI &ge; 6 meses, +20 pts Certificação Técnica SENAI/CREA/NR) e histórico (+6 pts/OS até +30 pts; -50 pts por abandono).</td></tr>
    <tr><td><code>RN-MZ-03</code></td><td>Cascata Hierárquica de 5 Degraus (<code>waterfall_tier_rank</code>)</td><td>Degrau 1: Âncora Verificado; Degrau 2: &ge; 5 OS e 0 abandonos; Degrau 3: 1 a 4 OS e 0 abandonos; Degrau 4: 0 OS mas <em>RTS</em> &ge; 70 (credenciado qualificado no Dia 1); Degrau 5: demais contas.</td></tr>
    <tr><td><code>RN-MZ-04</code></td><td>Reserva Semente (<em>Seed Reserve</em>) e Disjuntor Atômico</td><td>Rubrica inicial <code>COLD_START_SEED_RESERVE</code> no livro-razão combinada ao bloqueio imediato de saques e despachos quando <code>has_open_dispute = TRUE</code>.</td></tr>
    <tr><td><code>RN-MZ-05</code></td><td>Credenciamento de Âncoras e Quarentena Anti-Monopólio</td><td>Habilita operação segura em cidades recém-inauguradas via <code>is_trusted_anchor = TRUE</code> e impede concentração de chamados de garantia com quarentena de 24h.</td></tr>
    <tr><td><code>RN-KYC-01</code></td><td>Validação Aritmética Módulo 11 de CPF e Hash Único</td><td>Rejeita CPFs com dígitos repetidos ou DV inválido no cliente e no banco (<code>public.is_valid_cpf</code>), gravando apenas <code>cpf_masked</code> e <code>cpf_hash</code>.</td></tr>
    <tr><td><code>RN-KYC-02</code></td><td>Prova de Vida Ao Vivo na Moldura Oval (Câmera Frontal)</td><td>Exige pele humana <em>YCbCr</em> (22%–82%), bloqueia monitores (<code>blueMonitorRatio &lt; 0,25</code>), valida piscada (<code>EAR &lt; 0,18 &rarr; &gt; 0,25</code>) e rotação 3D (<code>|Yaw| &ge; 18°</code>).</td></tr>
    <tr><td><code>RN-KYC-03</code></td><td>Scanner Documental Guiado ISO/IEC 7810 ID-1</td><td>Proporção geométrica <code>1,586 : 1</code> (85,60 &times; 53,98 mm), nitidez Laplaciana &sigma;&sup2; &ge; 110,0 e índice de estouro de flash/reflexo especular &le; 8,5%.</td></tr>
    <tr><td><code>RN-KYC-04</code></td><td>Recorte <em>Core ROI Inset 12%</em> e Anti-Duplicidade Frente/Verso</td><td>Remove 12% das bordas antes do cálculo de <code>dHash</code> 64-bit e <code>MAD_64x64</code>, eliminando interferência de mesas/fundos e bloqueando Frente == Verso.</td></tr>
    <tr><td><code>RN-KYC-05</code></td><td>Face Match 1:1 Multi-Orientação (0°, 90°, 180°, 270°)</td><td>Compara o descritor 128-D não-negativo da selfie contra as 4 rotações canônicas da foto 3&times;4 do documento, exigindo similaridade de cosseno &ge; 78,0%.</td></tr>
    <tr><td><code>RN-KYC-06</code></td><td>Transcrição Visível OCR e Compatibilidade Nominal (&ge; 80%)</td><td>Exibe os campos extraídos na tela de confirmação e valida interseção de tokens do nome civil &ge; 80% contra os dados informados na Etapa 1.</td></tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- CAPÍTULO 13 — CATÁLOGO DAS 33 CATEGORIAS E SUÍTE DE 1.110 TESTES        -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-13"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 13</div>
  <div class="cb-body">
    <h2>TAXONOMIA DAS 33 CATEGORIAS TÉCNICAS, ÁRVORE DO PROJETO E ENGENHARIA DE Q.A. (1.110 ASSERÇÕES)</h2>
    <p>Mapeamento completo das especialidades atendidas, organização física dos diretórios e cobertura de testes automatizados (533 Flutter + 577 SQL).</p>
  </div>
</div>

<h3>13.1. Taxonomia Oficial das 33 Categorias Técnicas Residenciais (<span class="mono">expanded_categories.sql</span>)</h3>
<p>
  O motor de triagem por voz e correspondência de tags (validado por <code>tag_alias_parity_test.dart</code> e <code>tag_match_test.dart</code>) cobre <strong>33 especialidades residenciais</strong> agrupadas em 6 domínios operacionais:
</p>
<div class="cards-2col">
  <div class="info-card">
    <div class="ic-title">1. Elétrica, Climatização &amp; Energia (7 Categorias)</div>
    <p>&bull; Eletricista Residencial e Predial (NR-10)<br/>&bull; Instalação e Manutenção de Ar-Condicionado (HVAC)<br/>&bull; Automação Residencial e Casa Inteligente<br/>&bull; Energia Solar Fotovoltaica (Manutenção)<br/>&bull; Interfonia, CFTV e Alarmes Eletrônicos<br/>&bull; Cabeamento Estruturado e Redes Wi-Fi<br/>&bull; Conserto de Eletrodomésticos de Linha Branca</p>
  </div>
  <div class="info-card">
    <div class="ic-title">2. Hidráulica, Gás &amp; Desentupimento (6 Categorias)</div>
    <p>&bull; Encanador e Bombeiro Hidráulico<br/>&bull; Caça-Vazamentos Não-Invasivo<br/>&bull; Desentupimento de Redes e Esgoto<br/>&bull; Aquecedores a Gás e Pressurizadores<br/>&bull; Limpeza e Impermeabilização de Caixa d'Água<br/>&bull; Instalação de Louças, Metais e Filtros</p>
  </div>
  <div class="info-card">
    <div class="ic-title">3. Chaveiro, Segurança Física &amp; Esquadrias (5 Categorias)</div>
    <p>&bull; Chaveiro 24 Horas e Fechaduras Biométricas<br/>&bull; Vidraçaria, Box de Banheiro e Espelhos<br/>&bull; Serralheria (Portões, Grades e Solda)<br/>&bull; Motores de Portão Eletrônico<br/>&bull; Redes de Proteção para Janelas e Sacadas</p>
  </div>
  <div class="info-card">
    <div class="ic-title">4. Marcenaria, Montagem &amp; Acabamentos (8 Categorias)</div>
    <p>&bull; Montador de Móveis Convencionais e Corporativos<br/>&bull; Marceneiro (Reparos, Dobradiças e Corrediças)<br/>&bull; Marido de Aluguel (Instalações Rápidas, Cortinas, Suportes)<br/>&bull; Pintor Residencial e Texturas<br/>&bull; Gesseiro e Drywall (Forros e Sancas)<br/>&bull; Pedreiro e Pequenos Reparos de Alvenaria<br/>&bull; Assentamento de Pisos, Porcelanatos e Rejuntes<br/>&bull; Impermeabilização e Infiltrações</p>
  </div>
  <div class="info-card">
    <div class="ic-title">5. Telhados, Áreas Externas &amp; Ambiental (4 Categorias)</div>
    <p>&bull; Telhadista, Calhas e Rufos<br/>&bull; Jardinagem, Poda e Paisagismo<br/>&bull; Manutenção e Tratamento de Piscinas<br/>&bull; Dedetização e Controle Integrado de Pragas</p>
  </div>
  <div class="info-card">
    <div class="ic-title">6. Higienização Técnica &amp; Mudanças (3 Categorias)</div>
    <p>&bull; Limpeza Pós-Obra e Limpeza Pesada Técnica<br/>&bull; Higienização e Impermeabilização de Estofados<br/>&bull; Pequenos Fretes e Mudanças Internas</p>
  </div>
</div>

<h3>13.2. Matriz Completa das 26 Suítes de Testes Automatizados (<span class="mono">533 Testes Dart + 577 SQL = 1.110 Verificações</span>)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="34%">Arquivo de Teste Automatizado</th>
      <th width="14%">Escopo</th>
      <th width="52%">Invariantes, Componentes e Fluxos Auditados</th>
    </tr>
  </thead>
  <tbody>
    <tr><td><code>fintech_warranty_security_test.dart</code></td><td>Fintech &amp; Escrow</td><td>Valida Smart Split (0% peças, 13,5% op, 1,5% pool), equilíbrio atuarial (67 jobs), maturação D+2/D+5/D+7 e transições das 5 fases de mediação.</td></tr>
    <tr><td><code>red_team_warranty_and_kyc_forensics_test.dart</code></td><td>Red Team &amp; CV</td><td>Testa ataques de conluio triplo, foto repetida (<code>dHash</code>), fundo de madeira (Core ROI 12%), monitor azul (Liveness), Face Match 128-D multi-ângulo e CPF Módulo 11.</td></tr>
    <tr><td><code>offboarding_boot_theme_test.dart</code></td><td>Boot, Tema &amp; LGPD</td><td>Contraste WCAG AAA/AA, boot paralelo <code>Future.wait</code>, <code>SecureSessionStorage</code>, validação de chaves PIX (CPF/CNPJ/Tel/Email/UUID), vitrine e splash.</td></tr>
    <tr><td><code>wallet_test.dart</code></td><td>Carteira &amp; PIX</td><td>Aritmética exata em centavos inteiros, máscara monetária, trava de déficit (<code>FundsCheck</code>), idempotência de geração PIX e extrato semântico.</td></tr>
    <tr><td><code>account_screens_test.dart</code></td><td>Conta &amp; Saque</td><td>Saque PIX com declaração de titularidade, bloqueio de valor acima do saldo e exclusão escopada de conta (Cliente vs. Profissional).</td></tr>
    <tr><td><code>dossier_test.dart</code> &amp; <code>client_history_test.dart</code></td><td>ABNT NBR 5674</td><td>Geração do Passaporte do Imóvel em PDF vetorial (<code>%PDF-1.4</code>), selo <code>SHA-256</code>, diretriz <em>Zero Fake Data</em> e linha do tempo de manutenção.</td></tr>
    <tr><td><code>client_flow_widgets_test.dart</code> &amp; <code>completion_redesign_test.dart</code></td><td>Fluxo de Serviço</td><td>Abertura de chamado, comparação de orçamentos, check-in/out fotográfico, modal de PIN de 4 dígitos e tela de conclusão.</td></tr>
    <tr><td><code>smart_triage_test.dart</code> &amp; <code>smart_transcript_formatter_test.dart</code></td><td>Voz &amp; Triagem IA</td><td>Formatação gramatical automática de transcrições de voz e classificação determinística nas 33 categorias técnicas.</td></tr>
    <tr><td><code>precise_geocoder_test.dart</code>, <code>geocode_test.dart</code> &amp; <code>location_pin_test.dart</code></td><td>Geodésia &amp; Mapa</td><td>Geocodificação em cascata de 3 níveis, proteção de privacidade geográfica pré-aceite e renderização de pinos ordenados.</td></tr>
    <tr><td><code>review_rules_test.dart</code> &amp; <code>achievements_test.dart</code></td><td>Reputação &amp; Selos</td><td>Avaliações cegas bilaterais (48h), cálculo de progresso de conquistas e abertura do modal informativo de cada selo no <code>BadgeWall</code>.</td></tr>
    <tr><td><code>ui_polish_test.dart</code>, <code>update_test.dart</code> &amp; <code>user_profile_test.dart</code></td><td>UX/UI &amp; OTA</td><td>Central de suporte com mediações ativas, visualizador de fotos em tela cheia, saudação humanizada (sem e-mail bruto) e atualização OTA.</td></tr>
    <tr><td><code>supabase/tests/*.sql</code> (9 Suítes SQL)</td><td>PostgreSQL 17</td><td><strong>577 asserções SQL</strong> testando RLS, triggers, constraints declarativas, funções <code>SECURITY DEFINER</code> e integridade do livro-razão diretamente no banco.</td></tr>
  </tbody>
</table>

<!-- ======================================================================= -->
<!-- CAPÍTULO 14 — PESTEL, 5 FORÇAS DE PORTER, SWOT/TOWS E BSC               -->
<!-- ======================================================================= -->
<div class="page-break" id="cap-14"></div>
<div class="chapter-banner">
  <div class="cb-num">CAPÍTULO 14</div>
  <div class="cb-body">
    <h2>INTELIGÊNCIA COMPETITIVA: PESTEL, 5 FORÇAS DE PORTER, MATRIZ SWOT/TOWS E BALANCED SCORECARD</h2>
    <p>Governança corporativa, posicionamento estratégico no mercado brasileiro e telemetria executiva nas 4 perspectivas de Kaplan &amp; Norton.</p>
  </div>
</div>

<h3>14.1. Síntese das Cinco Forças Competitivas de Porter e Matriz SWOT Cruzada (TOWS)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="26%">Força Competitiva / Eixo SWOT</th>
      <th width="16%">Intensidade</th>
      <th width="58%">Fosso Tecnológico (<em>Moat</em>) e Resposta Estratégica do Desperrengue</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1. Ameaça de Novos Entrantes</strong></td>
      <td><span class="badge-ok">BAIXA</span></td>
      <td>Replicar um motor de KYC/Liveness 3D + OCR 100% <em>on-device</em> a custo R$ 0,00 combinado a um livro-razão PostgreSQL com 14 travas antifraude e Passaporte ABNT NBR 5674 exige alta densidade de engenharia multidisciplinar.</td>
    </tr>
    <tr>
      <td><strong>2. Ameaça de Substitutos e <em>Bypass</em> (Acerto por Fora)</strong></td>
      <td><span class="badge-ok">BAIXA</span></td>
      <td>O <em>Smart Split</em> (0% de taxa sobre peças) elimina o principal motivo financeiro do <em>bypass</em>; além disso, transacionar fora do app faz o cliente perder a Garantia de 3 Camadas e o selo SHA-256 do Passaporte do Imóvel, e faz o técnico perder a proteção contra calote e pontos no <em>RTS</em>.</td>
    </tr>
    <tr>
      <td><strong>3. Poder de Barganha dos Prestadores (Oferta)</strong></td>
      <td><span class="badge-plan">MODERADO</span></td>
      <td>Fidelizados pelo fim das "moedas de orçamento", pela isenção sobre materiais e pela progressão meritocrática para liquidação PIX rápida (<code>D+2 / D+0</code>) e prioridade no topo da cascata de despacho.</td>
    </tr>
    <tr>
      <td><strong>4. Poder de Barganha dos Clientes e Imobiliárias</strong></td>
      <td><span class="badge-plan">MODERADO</span></td>
      <td>Forte <em>lock-in</em> patrimonial: à medida que o imóvel acumula certificados forenses no Passaporte ABNT NBR 5674, o custo de troca (<em>switching cost</em>) para plataformas informais torna-se proibitivo.</td>
    </tr>
    <tr>
      <td><strong>5. Rivalidade entre Concorrentes Atuais</strong></td>
      <td><span class="badge-high">OCEANO AZUL</span></td>
      <td>Enquanto concorrentes legados disputam venda de leads sem garantia (Quadrante Inferior Esquerdo), o Desperrengue opera isolado no Quadrante Superior Direito (Despacho &lt; 60s + Custódia e Garantia Real em 3 Camadas).</td>
    </tr>
  </tbody>
</table>

<h3>14.2. Painel Consolidado de Telemetria do Balanced Scorecard (BSC — Kaplan &amp; Norton)</h3>
<table class="data-table compact-table">
  <thead>
    <tr>
      <th width="22%">Perspectiva do BSC</th>
      <th width="28%">Indicador-Chave (KPI)</th>
      <th width="16%">Meta / Target</th>
      <th width="34%">Fórmula e Fonte de Auditoria no Sistema</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2"><strong>1. Financeira &amp; Atuarial</strong></td>
      <td>Índice de Cobertura Atuarial (<code>ICA</code>)</td>
      <td><code>&ge; 1,50&times;</code> (Atual: <code>2,14&times;</code>)</td>
      <td>Soma de créditos <em>Carve-Out</em> (1,5%) + recuperações <em>Clawback</em> dividida pelos débitos de retrabalho em <code>warranty_pool_ledger</code>.</td>
    </tr>
    <tr>
      <td>Relação <code>LTV / CAC</code> &amp; Margem Líquida</td>
      <td><code>9,65&times;</code> / <code>&gt; 78%</code></td>
      <td><code>LTV = R$ 405,40</code> sobre <code>CAC = R$ 42,00</code> (Payback em 1,2 pedidos e Break-Even operacional no Mês 3).</td>
    </tr>
    <tr>
      <td rowspan="2"><strong>2. Cliente &amp; Patrimônio</strong></td>
      <td>SLA de Despacho de Emergência SOS</td>
      <td><code>&lt; 60 segundos</code> (<code>98,4%</code>)</td>
      <td>Tempo decorrido entre a publicação do chamado SOS por voz e a notificação da cascata via <code>idx_profiles_rescue_waterfall_bbox</code>.</td>
    </tr>
    <tr>
      <td>Resolução Amigável na Camada 1/2</td>
      <td><code>&ge; 75,0%</code> (Atual: <code>81,2%</code>)</td>
      <td>Fração de mediações resolvidas diretamente pelo prestador original dentro do SLA de 6h/24h a custo R$ 0,00 para o fundo.</td>
    </tr>
    <tr>
      <td rowspan="2"><strong>3. Processos Internos &amp; Forense</strong></td>
      <td>Rejeição de Fotos Recicladas / Sintéticas</td>
      <td><code>100,0%</code> Determinístico</td>
      <td>Bloqueio em <code>O(1)</code> via <code>hamming_distance_64 &lt; 5</code>, <code>MAD_64x64</code> em Core ROI 12% e filtro <code>blueMonitorRatio &lt; 0,25</code>.</td>
    </tr>
    <tr>
      <td>Contenção de Conluio e Deadlocks SQL</td>
      <td><code>0 Casos</code> (100% Bloqueio)</td>
      <td>Grafo <em>Zero-Linkage</em> na Camada 3 e ordem canônica de locks <code>1.jobs &rarr; 2.mediations &rarr; 3.escrow &rarr; 4.profiles</code>.</td>
    </tr>
    <tr>
      <td rowspan="2"><strong>4. Aprendizado &amp; Tecnologia</strong></td>
      <td>Custo Marginal de KYC, Biometria 3D e OCR</td>
      <td><code>R$ 0,00 / usuário</code></td>
      <td>Execução 100% local na CPU/NPU do dispositivo via <code>Isolate.run</code> (<code>DocumentOcrAndLivenessService</code>).</td>
    </tr>
    <tr>
      <td>Orçamento de Quadro UI &amp; Cobertura QA</td>
      <td><code>&le; 8,33 ms</code> (120 Hz)</td>
      <td>Validado por <strong>533 testes Dart/Flutter</strong> e <strong>577 asserções SQL</strong> passando integralmente no pipeline CI/CD.</td>
    </tr>
  </tbody>
</table>

<div class="doc-closing-box">
  <div class="dcb-title">DECLARAÇÃO DE CONFORMIDADE ARQUITETURAL E CIENTÍFICA — DESPERRENGUE v2.8.2</div>
  <p>
    Este tratado consolida de forma integral, exata e verificável toda a engenharia de software, modelagem de banco de dados, complexidade de algoritmos, visão computacional, blindagem antifraude, plano de negócios, auditoria de segurança Red Team e horizonte de inovação do ecossistema <strong>Desperrengue</strong> até o presente momento (<code>v2.8.2+202611101</code>).
  </p>
</div>
`;

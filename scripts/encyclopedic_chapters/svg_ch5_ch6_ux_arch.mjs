// ============================================================================
// DIAGRAMAS VETORIAIS CIENTÍFICOS SVG — CAPÍTULOS 5 E 6 (UX/UI E ARQUITETURA)
// Projeto Desperrengue (v2.11.0) — Low-Fi, Mid-Fi, Hi-Fi, C4, Clean Arch, Geo & KYC
// ============================================================================

export const svgLowFiSketches = String.raw`
<div class="svg-diagram-box" id="fig-12">
  <svg viewBox="0 0 920 450" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Prototipação Nível 1 Esboços Conceituais Low-Fi Sketches em Traço Técnico">
    <defs>
      <pattern id="sketchGrid" width="16" height="16" patternUnits="userSpaceOnUse">
        <path d="M 16 0 L 0 0 0 16" fill="none" stroke="#E2E8F0" stroke-width="0.7"/>
      </pattern>
      <linearGradient id="lowFiHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#1E293B"/>
        <stop offset="50%" stop-color="#334155"/>
        <stop offset="100%" stop-color="#1E293B"/>
      </linearGradient>
    </defs>

    <!-- Notebook Graph Paper Background -->
    <rect x="0" y="0" width="920" height="450" rx="8" fill="#FCFBF7" stroke="#94A3B8" stroke-width="1.5"/>
    <rect x="8" y="38" width="904" height="404" fill="url(#sketchGrid)"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#lowFiHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#lowFiHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.8" font-weight="800" letter-spacing="0.7">PROTOTIPAÇÃO NÍVEL 1 — ESBOÇOS CONCEITUAIS (LOW-FI SKETCHES) &bull; ERGONOMIA DE POLEGAR E LEI DE FITTS</text>

    <!-- SKETCH 1: HOME + THUMB ZONE + VOICE SOS (x=18, w=210) -->
    <rect x="18" y="48" width="210" height="346" rx="18" fill="#FFFFFF" stroke="#475569" stroke-width="2" stroke-dasharray="6,2"/>
    <line x1="98" y1="58" x2="148" y2="58" stroke="#64748B" stroke-width="2.5" stroke-linecap="round"/>
    <text x="123" y="74" text-anchor="middle" fill="#1E293B" font-family="Courier New, monospace" font-size="8.5" font-weight="700">[SKETCH A: HOME &amp; VOZ SOS]</text>

    <!-- Dual-Mode Toggle Sketch -->
    <rect x="30" y="84" width="186" height="24" rx="12" fill="#F1F5F9" stroke="#475569" stroke-width="1.2" stroke-dasharray="3,2"/>
    <rect x="33" y="87" width="92" height="18" rx="9" fill="#CBD5E1" stroke="#334155" stroke-width="1"/>
    <text x="79" y="99" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="7.5" font-weight="700">MODO CLIENTE</text>
    <text x="168" y="99" text-anchor="middle" fill="#64748B" font-family="Courier New, monospace" font-size="7.5">PROFISSIONAL</text>

    <!-- Category Grid Sketch (2x2 placeholder) -->
    <rect x="30" y="116" width="88" height="44" rx="4" fill="none" stroke="#64748B" stroke-width="1.2"/>
    <line x1="30" y1="116" x2="118" y2="160" stroke="#CBD5E1" stroke-width="1"/>
    <text x="74" y="141" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.5" font-weight="700">[Elétrica]</text>

    <rect x="128" y="116" width="88" height="44" rx="4" fill="none" stroke="#64748B" stroke-width="1.2"/>
    <line x1="128" y1="116" x2="216" y2="160" stroke="#CBD5E1" stroke-width="1"/>
    <text x="172" y="141" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.5" font-weight="700">[Hidráulica]</text>

    <rect x="30" y="166" width="88" height="44" rx="4" fill="none" stroke="#64748B" stroke-width="1.2"/>
    <text x="74" y="191" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.5" font-weight="700">[Diarista]</text>

    <rect x="128" y="166" width="88" height="44" rx="4" fill="none" stroke="#64748B" stroke-width="1.2"/>
    <text x="172" y="191" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.5" font-weight="700">[+30 Categ.]</text>

    <!-- Ergonomic Thumb Zone Arc (Steven Hoober) -->
    <path d="M 22 360 A 150 150 0 0 1 224 235 L 224 360 Z" fill="#FEF3C7" fill-opacity="0.55" stroke="#D97706" stroke-width="1.3" stroke-dasharray="4,3"/>
    <text x="123" y="242" text-anchor="middle" fill="#92400E" font-family="Courier New, monospace" font-size="7.3" font-weight="700">ZONA NATURAL DO POLEGAR</text>
    <text x="123" y="252" text-anchor="middle" fill="#92400E" font-family="Courier New, monospace" font-size="6.8">(Hoober: 49% uso 1 mão)</text>

    <!-- Big Voice SOS CTA in Thumb Zone -->
    <rect x="32" y="266" width="182" height="62" rx="10" fill="#FFF7ED" stroke="#EA580C" stroke-width="2"/>
    <circle cx="62" cy="297" r="16" fill="#FFEDD5" stroke="#EA580C" stroke-width="1.5"/>
    <text x="62" y="301" text-anchor="middle" fill="#9A3412" font-family="Courier New, monospace" font-size="9" font-weight="700">MIC</text>
    <text x="140" y="289" text-anchor="middle" fill="#9A3412" font-family="Courier New, monospace" font-size="8.2" font-weight="700">RELATAR POR VOZ</text>
    <text x="140" y="301" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.2">Normal ou SOS (&lt;60s)</text>
    <text x="140" y="313" text-anchor="middle" fill="#64748B" font-family="Courier New, monospace" font-size="6.8">Alvo W=56dp (Lei Fitts)</text>

    <!-- Bottom Nav Sketch -->
    <rect x="30" y="344" width="186" height="32" rx="6" fill="#F8FAFC" stroke="#64748B" stroke-width="1.2"/>
    <text x="123" y="364" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7.5" font-weight="700">[Início] [Pedidos] [Carteira] [Perfil]</text>

    <!-- SKETCH 2: DUAL-MODE + GEO-PRIVACY RADAR (x=242, w=210) -->
    <rect x="242" y="48" width="210" height="346" rx="18" fill="#FFFFFF" stroke="#475569" stroke-width="2" stroke-dasharray="6,2"/>
    <line x1="322" y1="58" x2="372" y2="58" stroke="#64748B" stroke-width="2.5" stroke-linecap="round"/>
    <text x="347" y="74" text-anchor="middle" fill="#1E293B" font-family="Courier New, monospace" font-size="8.5" font-weight="700">[SKETCH B: RADAR &amp; GEO-LOCK]</text>

    <!-- Mode Switched Indicator -->
    <rect x="254" y="84" width="186" height="24" rx="12" fill="#F1F5F9" stroke="#475569" stroke-width="1.2"/>
    <text x="298" y="99" text-anchor="middle" fill="#64748B" font-family="Courier New, monospace" font-size="7.5">CLIENTE</text>
    <rect x="342" y="87" width="95" height="18" rx="9" fill="#DBEAFE" stroke="#1D4ED8" stroke-width="1.2"/>
    <text x="389" y="99" text-anchor="middle" fill="#1E3A8A" font-family="Courier New, monospace" font-size="7.5" font-weight="700">MODO PRO (KYC)</text>

    <!-- Map Sketch with Fuzzy Circle -->
    <rect x="254" y="116" width="186" height="156" rx="6" fill="#F8FAFC" stroke="#64748B" stroke-width="1.2"/>
    <line x1="254" y1="155" x2="440" y2="195" stroke="#CBD5E1" stroke-width="1.5"/>
    <line x1="310" y1="116" x2="365" y2="272" stroke="#CBD5E1" stroke-width="1.5"/>
    <circle cx="347" cy="186" r="46" fill="#DBEAFE" fill-opacity="0.5" stroke="#1D4ED8" stroke-width="1.8" stroke-dasharray="5,3"/>
    <text x="347" y="178" text-anchor="middle" fill="#1E3A8A" font-family="Courier New, monospace" font-size="7.5" font-weight="700">RAIO 500m–800m</text>
    <text x="347" y="190" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7">(Sem pino exato!)</text>
    <text x="347" y="202" text-anchor="middle" fill="#991B1B" font-family="Courier New, monospace" font-size="6.8" font-weight="700">Trancado até 00:00</text>
    <text x="347" y="258" text-anchor="middle" fill="#475569" font-family="Courier New, monospace" font-size="7">Descarte: Pino GPS bruto banido</text>

    <!-- Job Summary Card Sketch -->
    <rect x="254" y="280" width="186" height="96" rx="6" fill="#FFFFFF" stroke="#475569" stroke-width="1.3"/>
    <text x="262" y="296" fill="#0F172A" font-family="Courier New, monospace" font-size="7.8" font-weight="700">Chamado: Curto no Quadro</text>
    <text x="262" y="309" fill="#334155" font-family="Courier New, monospace" font-size="7.1">Distância aprox: ~1,4 km</text>
    <text x="262" y="321" fill="#065F46" font-family="Courier New, monospace" font-size="7.1" font-weight="700">Custo p/ Orçar: R$ 0,00 (Grátis)</text>
    <rect x="264" y="332" width="166" height="32" rx="6" fill="#EFF6FF" stroke="#1D4ED8" stroke-width="1.5"/>
    <text x="347" y="352" text-anchor="middle" fill="#1E3A8A" font-family="Courier New, monospace" font-size="8" font-weight="700">[ENVIAR ORÇAMENTO GRÁTIS]</text>

    <!-- SKETCH 3: SMART SPLIT QUOTE (x=466, w=210) -->
    <rect x="466" y="48" width="210" height="346" rx="18" fill="#FFFFFF" stroke="#475569" stroke-width="2" stroke-dasharray="6,2"/>
    <line x1="546" y1="58" x2="596" y2="58" stroke="#64748B" stroke-width="2.5" stroke-linecap="round"/>
    <text x="571" y="74" text-anchor="middle" fill="#1E293B" font-family="Courier New, monospace" font-size="8.5" font-weight="700">[SKETCH C: SMART SPLIT 0%]</text>

    <rect x="478" y="86" width="186" height="66" rx="6" fill="#F8FAFC" stroke="#475569" stroke-width="1.2"/>
    <text x="486" y="102" fill="#0F172A" font-family="Courier New, monospace" font-size="7.6" font-weight="700">1. MÃO DE OBRA (labor_cents)</text>
    <rect x="486" y="108" width="170" height="24" rx="4" fill="#FFFFFF" stroke="#334155" stroke-width="1"/>
    <text x="494" y="124" fill="#0F172A" font-family="Courier New, monospace" font-size="8.5" font-weight="700">R$ 220,00</text>
    <text x="486" y="144" fill="#475569" font-family="Courier New, monospace" font-size="6.9">Taxa 15% (13,5% App + 1,5% Garantia)</text>

    <rect x="478" y="160" width="186" height="82" rx="6" fill="#F0FDF4" stroke="#059669" stroke-width="1.3"/>
    <text x="486" y="176" fill="#065F46" font-family="Courier New, monospace" font-size="7.6" font-weight="700">2. MATERIAIS / PEÇAS (0% TAXA)</text>
    <rect x="486" y="182" width="170" height="24" rx="4" fill="#FFFFFF" stroke="#059669" stroke-width="1"/>
    <text x="494" y="198" fill="#065F46" font-family="Courier New, monospace" font-size="8.5" font-weight="700">R$ 100,00 (100% Repasse)</text>
    <rect x="486" y="212" width="170" height="22" rx="4" fill="#DCFCE7" stroke="#059669" stroke-width="1" stroke-dasharray="3,2"/>
    <text x="571" y="226" text-anchor="middle" fill="#065F46" font-family="Courier New, monospace" font-size="7.2" font-weight="700">[+ Anexar NF-e 44 dígitos]</text>

    <rect x="478" y="250" width="186" height="58" rx="6" fill="#FFFBEB" stroke="#D97706" stroke-width="1.2"/>
    <text x="486" y="265" fill="#92400E" font-family="Courier New, monospace" font-size="7.4" font-weight="700">RESUMO TRANSPARENTE:</text>
    <text x="486" y="278" fill="#334155" font-family="Courier New, monospace" font-size="7.1">&bull; Total Morador: R$ 320,00</text>
    <text x="486" y="290" fill="#065F46" font-family="Courier New, monospace" font-size="7.1" font-weight="700">&bull; Líquido Técnico: R$ 287,00</text>
    <text x="486" y="302" fill="#475569" font-family="Courier New, monospace" font-size="6.8">&bull; Fundo Garantidor 90d: R$ 3,30</text>

    <rect x="478" y="318" width="186" height="58" rx="6" fill="#FEF2F2" stroke="#EF4444" stroke-width="1"/>
    <text x="486" y="332" fill="#991B1B" font-family="Courier New, monospace" font-size="7.2" font-weight="700">DECISÃO LOW-FI (DESCARTE):</text>
    <text x="486" y="344" fill="#7F1D1D" font-family="Courier New, monospace" font-size="6.9">Eliminado campo único de preço</text>
    <text x="486" y="355" fill="#7F1D1D" font-family="Courier New, monospace" font-size="6.9">que causava bitributação sobre</text>
    <text x="486" y="366" fill="#7F1D1D" font-family="Courier New, monospace" font-size="6.9">insumos e rejeição de 100%.</text>

    <!-- SKETCH 4: SMART ESCROW PIN 4 DIGITS & DURESS (x=690, w=212) -->
    <rect x="690" y="48" width="212" height="346" rx="18" fill="#FFFFFF" stroke="#475569" stroke-width="2" stroke-dasharray="6,2"/>
    <line x1="771" y1="58" x2="821" y2="58" stroke="#64748B" stroke-width="2.5" stroke-linecap="round"/>
    <text x="796" y="74" text-anchor="middle" fill="#1E293B" font-family="Courier New, monospace" font-size="8.5" font-weight="700">[SKETCH D: CHECKOUT PIN 4D]</text>

    <rect x="702" y="86" width="188" height="48" rx="6" fill="#ECFDF5" stroke="#059669" stroke-width="1.2"/>
    <text x="796" y="103" text-anchor="middle" fill="#065F46" font-family="Courier New, monospace" font-size="7.6" font-weight="700">CUSTÓDIA PIX ATIVA: R$ 320,00</text>
    <text x="796" y="116" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7">Liberar somente após vistoria</text>
    <text x="796" y="127" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="7">e fotos finais anexadas.</text>

    <!-- 4 Digit PIN Boxes Sketch -->
    <text x="796" y="152" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="7.8" font-weight="700">DIGITE O PIN DO MORADOR:</text>
    <rect x="712" y="160" width="36" height="42" rx="6" fill="#F8FAFC" stroke="#0F172A" stroke-width="1.6"/>
    <text x="730" y="187" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="16" font-weight="700">4</text>

    <rect x="756" y="160" width="36" height="42" rx="6" fill="#F8FAFC" stroke="#0F172A" stroke-width="1.6"/>
    <text x="774" y="187" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="16" font-weight="700">8</text>

    <rect x="800" y="160" width="36" height="42" rx="6" fill="#F8FAFC" stroke="#0F172A" stroke-width="1.6"/>
    <text x="818" y="187" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="16" font-weight="700">1</text>

    <rect x="844" y="160" width="36" height="42" rx="6" fill="#F8FAFC" stroke="#0F172A" stroke-width="1.6"/>
    <text x="862" y="187" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="16" font-weight="700">9</text>

    <!-- Duress Explanation Box -->
    <rect x="702" y="212" width="188" height="66" rx="6" fill="#FFF7ED" stroke="#EA580C" stroke-width="1.2" stroke-dasharray="4,2"/>
    <text x="710" y="227" fill="#9A3412" font-family="Courier New, monospace" font-size="7.3" font-weight="700">MODO COAÇÃO (SILENT DURESS):</text>
    <text x="710" y="240" fill="#334155" font-family="Courier New, monospace" font-size="6.9">&bull; Normal (4819) &rarr; Libera Saque</text>
    <text x="710" y="252" fill="#991B1B" font-family="Courier New, monospace" font-size="6.9" font-weight="700">&bull; Reverso (9184) &rarr; Tela Verde</text>
    <text x="710" y="264" fill="#334155" font-family="Courier New, monospace" font-size="6.8">falsa + congela saque (FROZEN)</text>
    <text x="710" y="274" fill="#475569" font-family="Courier New, monospace" font-size="6.6">(PINs palíndromos bloqueados)</text>

    <!-- Confirm CTA -->
    <rect x="702" y="288" width="188" height="40" rx="8" fill="#059669" stroke="#064E3B" stroke-width="1.5"/>
    <text x="796" y="307" text-anchor="middle" fill="#FFFFFF" font-family="Courier New, monospace" font-size="8.2" font-weight="700">[LIBERAR CUSTÓDIA PIX]</text>
    <text x="796" y="319" text-anchor="middle" fill="#D1FAE5" font-family="Courier New, monospace" font-size="6.8">+ Ativar Garantia Legal 90 Dias</text>

    <text x="796" y="352" text-anchor="middle" fill="#475569" font-family="Courier New, monospace" font-size="7">Lei de Hick-Hyman: Decisão</text>
    <text x="796" y="363" text-anchor="middle" fill="#475569" font-family="Courier New, monospace" font-size="7">binária simples sem menus ocultos</text>

    <!-- Bottom Engineering Annotation Strip -->
    <rect x="18" y="402" width="884" height="36" rx="5" fill="#1E293B"/>
    <text x="460" y="417" text-anchor="middle" fill="#F8FAFC" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="700">FUNDAMENTAÇÃO TEÓRICA LOW-FI (BUXTON, 2007; FITTS, 1954; HICK, 1952; HOOBER, 2013):</text>
    <text x="460" y="430" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Alvos críticos posicionados no arco inferior do polegar (W &ge; 48–56dp), redução da entropia decisória H(X) por voz e descarte precoce de fluxos especulativos.</text>
  </svg>
  <div class="svg-caption">Figura 5.1 — Prototipação Nível 1 (Esboços Conceituais Low-Fi Sketches): Ergonomia da Zona do Polegar com SOS por Voz, Alternância Dual-Mode, Smart Split Sem Moedas e Checkout por PIN de 4 Dígitos.</div>
</div>
`;

export const svgMidFiWireframes = String.raw`
<div class="svg-diagram-box" id="fig-13">
  <svg viewBox="0 0 920 455" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Prototipação Nível 2 Wireframes Estruturais Mid-Fi em Escala de Cinza Técnica">
    <defs>
      <linearGradient id="midFiHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#334155"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <linearGradient id="edgeFadeL" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#CBD5E1" stop-opacity="0.9"/>
        <stop offset="100%" stop-color="#CBD5E1" stop-opacity="0"/>
      </linearGradient>
      <linearGradient id="edgeFadeR" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#CBD5E1" stop-opacity="0"/>
        <stop offset="100%" stop-color="#CBD5E1" stop-opacity="0.9"/>
      </linearGradient>
    </defs>

    <rect x="0" y="0" width="920" height="455" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#midFiHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#midFiHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.6" font-weight="800" letter-spacing="0.7">PROTOTIPAÇÃO NÍVEL 2 — WIREFRAMES ESTRUTURAIS (MID-FI) &bull; GRID 480PX, CABEÇALHO 2 ANDARES E MAPA 80%</text>

    <!-- WIREFRAME 1: DETALHE DO SERVIÇO + CABEÇALHO DE 2 ANDARES + CONSTRAINEDBOX 480PX (x=16, w=290) -->
    <rect x="16" y="46" width="290" height="360" rx="8" fill="#E2E8F0" stroke="#64748B" stroke-width="1.5"/>
    <!-- Dimension Callout: max-width: 480px -->
    <line x1="36" y1="60" x2="286" y2="60" stroke="#0F172A" stroke-width="1.2"/>
    <line x1="36" y1="55" x2="36" y2="65" stroke="#0F172A" stroke-width="1.2"/>
    <line x1="286" y1="55" x2="286" y2="65" stroke="#0F172A" stroke-width="1.2"/>
    <rect x="86" y="51" width="150" height="16" rx="3" fill="#0F172A"/>
    <text x="161" y="62" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">ConstrainedBox(maxWidth: 480)</text>

    <!-- Central 480px Viewport Container -->
    <rect x="36" y="72" width="250" height="324" rx="6" fill="#FFFFFF" stroke="#475569" stroke-width="1.5"/>
    <rect x="36" y="72" width="250" height="22" rx="6" fill="#334155"/>
    <text x="161" y="86" text-anchor="middle" fill="#F8FAFC" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">WF-01: DetalheServicoClienteScreen</text>

    <!-- 2-STORY STRUCTURAL HEADER -->
    <rect x="44" y="100" width="234" height="86" rx="5" fill="#F8FAFC" stroke="#475569" stroke-width="1.4"/>
    <text x="52" y="113" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">CABEÇALHO ESTRUTURAL DE 2 ANDARES (ZERO TRUNCAMENTO)</text>

    <!-- Story 1: Category Emblem + StatusChip -->
    <rect x="52" y="119" width="132" height="22" rx="11" fill="#E2E8F0" stroke="#64748B" stroke-width="1"/>
    <circle cx="64" cy="130" r="7" fill="#94A3B8"/>
    <text x="76" y="133" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">1º Andar: Impermeabilização</text>

    <rect x="190" y="119" width="80" height="22" rx="11" fill="#CBD5E1" stroke="#475569" stroke-width="1"/>
    <text x="230" y="133" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[EM EXECUÇÃO]</text>

    <!-- Story 2: Full Width Headline -->
    <rect x="52" y="147" width="218" height="32" rx="4" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1" stroke-dasharray="3,2"/>
    <text x="58" y="160" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">2º Andar (100% Largura): Infiltração</text>
    <text x="58" y="172" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">na Laje Superior e Vedação de Calha</text>

    <!-- Stepper / Timeline Wireframe -->
    <rect x="44" y="194" width="234" height="44" rx="5" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1"/>
    <circle cx="68" cy="212" r="6" fill="#334155"/>
    <line x1="74" y1="212" x2="122" y2="212" stroke="#334155" stroke-width="2"/>
    <circle cx="128" cy="212" r="6" fill="#334155"/>
    <line x1="134" y1="212" x2="182" y2="212" stroke="#334155" stroke-width="2"/>
    <circle cx="188" cy="212" r="7" fill="#0F172A" stroke="#64748B" stroke-width="2"/>
    <line x1="195" y1="212" x2="242" y2="212" stroke="#CBD5E1" stroke-width="2" stroke-dasharray="3,2"/>
    <circle cx="248" cy="212" r="6" fill="#E2E8F0" stroke="#94A3B8" stroke-width="1.5"/>
    <text x="68" y="230" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Aberto</text>
    <text x="128" y="230" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Custódia</text>
    <text x="188" y="230" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Execução</text>
    <text x="248" y="230" text-anchor="middle" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">PIN 90d</text>

    <!-- Smart Split Financial Breakdown Wireframe -->
    <rect x="44" y="246" width="234" height="76" rx="5" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1.2"/>
    <text x="52" y="261" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">BLOCO FINANCEIRO SMART SPLIT (BIGINT)</text>
    <text x="52" y="276" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Mão de Obra (Taxa 15%): ................. R$ 220,00</text>
    <text x="52" y="290" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Materiais NF-e (Taxa 0,0%): ............ R$ 100,00</text>
    <line x1="52" y1="297" x2="270" y2="297" stroke="#CBD5E1" stroke-width="1"/>
    <text x="52" y="311" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Total Protegido em Custódia: .......... R$ 320,00</text>

    <!-- Primary Action Button Wireframe -->
    <rect x="44" y="330" width="234" height="54" rx="6" fill="#E2E8F0" stroke="#475569" stroke-width="1.3"/>
    <text x="161" y="348" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">[ABRIR RADAR AO VIVO / INFORMAR PIN]</text>
    <text x="161" y="362" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="7">Paridade Mobile Nativo &amp; PWA Desktop (480px)</text>
    <text x="161" y="374" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Sem barras laterais órfãs em monitores widescreen</text>

    <!-- WIREFRAME 2: MAPA EM TELA CHEIA COM 80% DE ÁREA LIVRE + BOTTOM SHEET COLAPSÁVEL (x=316, w=288) -->
    <rect x="316" y="46" width="288" height="360" rx="8" fill="#FFFFFF" stroke="#475569" stroke-width="1.5"/>
    <rect x="316" y="46" width="288" height="22" rx="8" fill="#334155"/>
    <text x="460" y="60" text-anchor="middle" fill="#F8FAFC" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">WF-02: OrderLiveMapModalScreen (&ge; 80% Livre)</text>

    <!-- Unobstructed 80% Map Canvas -->
    <rect x="324" y="74" width="272" height="248" rx="6" fill="#E2E8F0" stroke="#64748B" stroke-width="1.2"/>
    <!-- Street grid lines -->
    <line x1="324" y1="125" x2="596" y2="155" stroke="#CBD5E1" stroke-width="2.5"/>
    <line x1="324" y1="220" x2="596" y2="190" stroke="#CBD5E1" stroke-width="2.5"/>
    <line x1="395" y1="74" x2="435" y2="322" stroke="#CBD5E1" stroke-width="2.5"/>
    <line x1="515" y1="74" x2="485" y2="322" stroke="#CBD5E1" stroke-width="2.5"/>

    <!-- Top Floating Pill (Compacta) -->
    <rect x="334" y="82" width="252" height="26" rx="13" fill="#FFFFFF" fill-opacity="0.92" stroke="#475569" stroke-width="1.2"/>
    <text x="460" y="98" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">[&larr;] Radar Live OSRM / Arco Geodésico C&infin; (ETA: 8 min)</text>

    <!-- Route Curve (36-segment C^infinity Bezier representation) -->
    <path d="M 368 258 Q 435 140 536 168" fill="none" stroke="#334155" stroke-width="3" stroke-dasharray="6,4"/>
    <circle cx="368" cy="258" r="9" fill="#0F172A" stroke="#FFFFFF" stroke-width="2"/>
    <text x="368" y="280" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">Técnico</text>

    <circle cx="536" cy="168" r="28" fill="#94A3B8" fill-opacity="0.35" stroke="#334155" stroke-width="1.5" stroke-dasharray="4,2"/>
    <circle cx="536" cy="168" r="7" fill="#334155" stroke="#FFFFFF" stroke-width="2"/>
    <text x="536" y="208" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">Destino / Geo-Lock</text>

    <!-- 80% Viewport Dimension Badge -->
    <rect x="380" y="232" width="168" height="32" rx="5" fill="#0F172A" fill-opacity="0.88"/>
    <text x="464" y="246" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">ÁREA CARTÓGRAFICA &ge; 80% LIVRE</text>
    <text x="464" y="258" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Sem cards opacos bloqueando a malha viária</text>

    <!-- Collapsible Bottom Sheet (<= 20% height) -->
    <rect x="324" y="326" width="272" height="72" rx="8" fill="#FFFFFF" stroke="#334155" stroke-width="1.5"/>
    <rect x="436" y="332" width="48" height="4" rx="2" fill="#94A3B8"/>
    <text x="336" y="350" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">Bottom Sheet Colapsável (&le; 20% Viewport)</text>
    <text x="336" y="364" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; Telemetria de deslocamento + Botão Centralizar Rota</text>
    <text x="336" y="377" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; Isolado em RepaintBoundary a 120 FPS (8,33 ms/frame)</text>
    <text x="336" y="390" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">&bull; Pré-dia: exibe ProtectedAreaMapSheet (500m–800m)</text>

    <!-- WIREFRAME 3: CARROSSEL HORIZONTAL DE CONQUISTAS & ACESSIBILIDADE 1.4X (x=614, w=290) -->
    <rect x="614" y="46" width="290" height="360" rx="8" fill="#FFFFFF" stroke="#475569" stroke-width="1.5"/>
    <rect x="614" y="46" width="290" height="22" rx="8" fill="#334155"/>
    <text x="759" y="60" text-anchor="middle" fill="#F8FAFC" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">WF-03: _EdgeFadeMedalCarousel (112 Medalhas)</text>

    <!-- Profile Summary Wireframe -->
    <rect x="624" y="76" width="270" height="58" rx="6" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1.2"/>
    <circle cx="652" cy="105" r="18" fill="#CBD5E1" stroke="#475569" stroke-width="1.5"/>
    <text x="652" y="108" text-anchor="middle" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">L1 0ms</text>
    <text x="680" y="94" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">Galeria Unificada de Conquistas</text>
    <text x="680" y="107" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">90 Profissional (9&times;10) + 22 Cliente = 112</text>
    <text x="680" y="120" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="7">Filtro rápido: [Todas] [Desbloqueadas] [Pendentes]</text>

    <!-- Horizontal Carousel 1 with ShaderMask Edge Fade -->
    <text x="624" y="150" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">TRILHA 1 — EXCELÊNCIA E ASSIDUIDADE (SHADERMASK FADE)</text>
    <rect x="624" y="156" width="270" height="92" rx="6" fill="#F1F5F9" stroke="#64748B" stroke-width="1.2"/>

    <!-- Medal Card 1 (Unlocked) -->
    <rect x="634" y="164" width="74" height="76" rx="5" fill="#FFFFFF" stroke="#334155" stroke-width="1.4"/>
    <circle cx="671" cy="190" r="15" fill="#94A3B8" stroke="#0F172A" stroke-width="1.5"/>
    <text x="671" y="193" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="800">ATIVA</text>
    <text x="671" y="218" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">Nível 1 (1 OS)</text>
    <text x="671" y="230" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Desbloqueada</text>

    <!-- Medal Card 2 (Unlocked) -->
    <rect x="716" y="164" width="74" height="76" rx="5" fill="#FFFFFF" stroke="#334155" stroke-width="1.4"/>
    <circle cx="753" cy="190" r="15" fill="#94A3B8" stroke="#0F172A" stroke-width="1.5"/>
    <text x="753" y="193" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="800">ATIVA</text>
    <text x="753" y="218" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">Nível 2 (10 OS)</text>
    <text x="753" y="230" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Desbloqueada</text>

    <!-- Medal Card 3 (Locked #CBD5E1) -->
    <rect x="798" y="164" width="74" height="76" rx="5" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="3,2"/>
    <circle cx="835" cy="190" r="15" fill="#CBD5E1" stroke="#64748B" stroke-width="1.2"/>
    <text x="835" y="193" text-anchor="middle" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="6.5" font-weight="800">#CBD5E1</text>
    <text x="835" y="218" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">Nível 3 (25 OS)</text>
    <text x="835" y="230" text-anchor="middle" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Bloqueada (Lock)</text>

    <!-- Edge Fade Indicators -->
    <rect x="624" y="156" width="12" height="92" fill="url(#edgeFadeL)"/>
    <rect x="882" y="156" width="12" height="92" fill="url(#edgeFadeR)"/>

    <!-- Dynamic Height Formula & Accessibility Box -->
    <rect x="624" y="258" width="270" height="138" rx="6" fill="#F8FAFC" stroke="#475569" stroke-width="1.3"/>
    <text x="632" y="274" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">ENGENHARIA DE LAYOUT E ACESSIBILIDADE MID-FI:</text>
    <text x="632" y="290" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">Altura Elástica Anti-Overflow:</tspan> O carrossel calcula</text>
    <text x="640" y="301" fill="#0F172A" font-family="Courier New, monospace" font-size="7" font-weight="700">H = 152 + max(0, textScale - 1.0) * 56</text>
    <text x="640" y="313" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">absorvendo fontes ampliadas em até <tspan font-weight="700">1.4x</tspan> sem cortar</text>
    <text x="640" y="324" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">títulos nem barras de progresso.</text>
    <text x="632" y="340" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">Borda Gradiente ShaderMask:</tspan> Sinaliza continuidade</text>
    <text x="640" y="351" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">horizontal (affordance de swipe) sem setas intrusivas.</text>
    <text x="632" y="367" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">Viewport Estreito 320px:</tspan> Zero RenderFlex overflow</text>
    <text x="640" y="378" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">validado por testes automatizados de widget.</text>

    <!-- Bottom Strip -->
    <rect x="16" y="414" width="888" height="32" rx="5" fill="#0F172A"/>
    <text x="460" y="434" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">ARQUITETURA DA INFORMAÇÃO MID-FI: Hierarquia visual determinística, separação de metadados em 2 andares e preservação de &ge;80% do mapa.</text>
  </svg>
  <div class="svg-caption">Figura 5.2 — Prototipação Nível 2 (Wireframes Estruturais Mid-Fi): Grid Responsivo Centralizado (480px), Cabeçalho de 2 Andares em Detalhe do Serviço, Mapa com 80% de Área Livre e Carrosséis Horizontais de Conquistas.</div>
</div>
`;

export const svgHiFiScreensAndTokens = String.raw`
<div class="svg-diagram-box" id="fig-14">
  <svg viewBox="0 0 920 500" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Prototipação Nível 3 Mockups Hi-Fi Quiet Luxury Dark Mode Tokens 33 Categorias Duotone e 112 Medalhas">
    <defs>
      <linearGradient id="hiFiHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0E1218"/>
        <stop offset="50%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0E1218"/>
      </linearGradient>
      <linearGradient id="goldMedalGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#FDE047"/>
        <stop offset="50%" stop-color="#F59E0B"/>
        <stop offset="100%" stop-color="#B45309"/>
      </linearGradient>
      <linearGradient id="diamondMedalGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#67E8F9"/>
        <stop offset="50%" stop-color="#3B82F6"/>
        <stop offset="100%" stop-color="#4338CA"/>
      </linearGradient>
      <linearGradient id="darkGlassGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#1E293B"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
    </defs>

    <!-- Main Dark Canvas -->
    <rect x="0" y="0" width="920" height="500" rx="8" fill="#0E1218" stroke="#2B3646" stroke-width="1.8"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#hiFiHdr)"/>
    <line x1="0" y1="36" x2="920" y2="36" stroke="#2B3646" stroke-width="1.2"/>
    <text x="460" y="23" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="10.6" font-weight="800" letter-spacing="0.7">PROTOTIPAÇÃO NÍVEL 3 (HI-FI) &bull; DESIGN SYSTEM QUIET LUXURY DARK MODE, 33 EMBLEMAS DUOTONE E 112 MEDALHAS</text>

    <!-- PANEL 1 (LEFT): EXACT COLOR TOKENS & TYPOGRAPHY (x=14, y=46, w=282, h=440) -->
    <rect x="14" y="46" width="282" height="440" rx="8" fill="#141A22" stroke="#2B3646" stroke-width="1.3"/>
    <text x="26" y="66" fill="#6FA8F0" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">1. TOKENS SEMÂNTICOS EXATOS (app_tokens.dart)</text>

    <!-- Swatches Grid (2 columns of 6 swatches) -->
    <!-- Col A -->
    <rect x="24" y="76" width="22" height="18" rx="4" fill="#0E1218" stroke="#6FA8F0" stroke-width="1"/>
    <text x="52" y="88" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#0E1218</text>
    <text x="98" y="88" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">background</text>

    <rect x="24" y="99" width="22" height="18" rx="4" fill="#141A22" stroke="#2B3646" stroke-width="1"/>
    <text x="52" y="111" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#141A22</text>
    <text x="98" y="111" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">surface</text>

    <rect x="24" y="122" width="22" height="18" rx="4" fill="#1A212B" stroke="#2B3646" stroke-width="1"/>
    <text x="52" y="134" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#1A212B</text>
    <text x="98" y="134" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">card</text>

    <rect x="24" y="145" width="22" height="18" rx="4" fill="#232C39" stroke="#2B3646" stroke-width="1"/>
    <text x="52" y="157" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#232C39</text>
    <text x="98" y="157" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">raised</text>

    <rect x="24" y="168" width="22" height="18" rx="4" fill="#EAEFF6" stroke="#2B3646" stroke-width="1"/>
    <text x="52" y="180" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#EAEFF6</text>
    <text x="98" y="180" fill="#3CCB8C" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">text (15,6:1)</text>

    <rect x="24" y="191" width="22" height="18" rx="4" fill="#A3AEC0" stroke="#2B3646" stroke-width="1"/>
    <text x="52" y="203" fill="#EAEFF6" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#A3AEC0</text>
    <text x="98" y="203" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">textMuted</text>

    <!-- Col B -->
    <rect x="158" y="76" width="22" height="18" rx="4" fill="#FF8F52"/>
    <text x="186" y="88" fill="#FF8F52" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#FF8F52</text>
    <text x="232" y="88" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">clientAccent</text>

    <rect x="158" y="99" width="22" height="18" rx="4" fill="#74A7FF"/>
    <text x="186" y="111" fill="#74A7FF" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#74A7FF</text>
    <text x="232" y="111" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">proAccent</text>

    <rect x="158" y="122" width="22" height="18" rx="4" fill="#3CCB8C"/>
    <text x="186" y="134" fill="#3CCB8C" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#3CCB8C</text>
    <text x="232" y="134" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">success</text>

    <rect x="158" y="145" width="22" height="18" rx="4" fill="#EFCB6B"/>
    <text x="186" y="157" fill="#EFCB6B" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#EFCB6B</text>
    <text x="232" y="157" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">warning</text>

    <rect x="158" y="168" width="22" height="18" rx="4" fill="#FF7A80"/>
    <text x="186" y="180" fill="#FF7A80" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#FF7A80</text>
    <text x="232" y="180" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">danger</text>

    <rect x="158" y="191" width="22" height="18" rx="4" fill="#52B7C0"/>
    <text x="186" y="203" fill="#52B7C0" font-family="Courier New, monospace" font-size="7.5" font-weight="700">#52B7C0</text>
    <text x="232" y="203" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7">security</text>

    <line x1="24" y1="218" x2="284" y2="218" stroke="#2B3646" stroke-width="1"/>

    <!-- 33 Duotone Service Icons Sample (6 Chromatic Families) -->
    <text x="26" y="234" fill="#6FA8F0" font-family="Inter, Segoe UI, sans-serif" font-size="8.6" font-weight="800">2. EMBLEMAS DUOTONE (33 CATEGORIAS / 6 FAMÍLIAS)</text>

    <!-- 6 Squircle DarkGlassDuotoneBadges -->
    <!-- 1. Energia (Amber) -->
    <rect x="24" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#F59E0B" stroke-width="1.4"/>
    <polygon points="45,250 36,264 43,264 41,276 50,262 43,262" fill="#FBBF24"/>
    <text x="43" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Elétrica</text>

    <!-- 2. Água (Cyan) -->
    <rect x="68" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#06B6D4" stroke-width="1.4"/>
    <path d="M 87 251 C 87 251, 78 263, 78 268 A 9 9 0 0 0 96 268 C 96 263, 87 251, 87 251 Z" fill="#38BDF8"/>
    <text x="87" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Hidráulica</text>

    <!-- 3. Estrutura (Orange) -->
    <rect x="112" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#F97316" stroke-width="1.4"/>
    <rect x="121" y="254" width="20" height="9" rx="1" fill="#FB923C"/>
    <rect x="121" y="265" width="9" height="8" rx="1" fill="#FDBA74"/>
    <rect x="132" y="265" width="9" height="8" rx="1" fill="#FDBA74"/>
    <text x="131" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Alvenaria</text>

    <!-- 4. Cuidado/Limpeza (Emerald) -->
    <rect x="156" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#10B981" stroke-width="1.4"/>
    <circle cx="175" cy="263" r="9" fill="#34D399" fill-opacity="0.35" stroke="#34D399" stroke-width="1.5"/>
    <circle cx="175" cy="263" r="4" fill="#6EE7B7"/>
    <text x="175" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Diarista</text>

    <!-- 5. Tecnologia (Indigo) -->
    <rect x="200" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#6366F1" stroke-width="1.4"/>
    <rect x="209" y="254" width="20" height="14" rx="2" fill="none" stroke="#818CF8" stroke-width="1.6"/>
    <line x1="214" y1="272" x2="224" y2="272" stroke="#A5B4FC" stroke-width="1.6"/>
    <text x="219" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Redes/TI</text>

    <!-- 6. Mobilidade/SOS (Rose) -->
    <rect x="244" y="244" width="38" height="38" rx="10" fill="url(#darkGlassGrad)" stroke="#F43F5E" stroke-width="1.4"/>
    <circle cx="263" cy="259" r="5" fill="none" stroke="#FB7185" stroke-width="1.6"/>
    <line x1="263" y1="264" x2="263" y2="274" stroke="#FDA4AF" stroke-width="1.8"/>
    <text x="263" y="293" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Chaveiro</text>

    <line x1="24" y1="304" x2="284" y2="304" stroke="#2B3646" stroke-width="1"/>

    <!-- SIDE-BY-SIDE 112 MEDALS COMPARISON (#CBD5E1 vs. UNLOCKED VIBRANT) -->
    <text x="26" y="320" fill="#6FA8F0" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">3. FORJA DAS 112 MEDALHAS (90 PRO + 22 CLIENTE)</text>

    <!-- Left Medal: LOCKED (#CBD5E1) -->
    <rect x="24" y="328" width="126" height="146" rx="6" fill="#1A212B" stroke="#94A3B8" stroke-width="1.2"/>
    <text x="87" y="343" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">ESTADO BLOQUEADO</text>
    <!-- Shield/Medal base #1E293B with #94A3B8 rim and #CBD5E1 icon -->
    <circle cx="87" cy="382" r="26" fill="#1E293B" stroke="#94A3B8" stroke-width="2.5"/>
    <polygon points="87,364 92,375 104,376 95,384 97,396 87,390 77,396 79,384 70,376 82,375" fill="#CBD5E1"/>
    <!-- Padlock Pill #E2E8F0 -->
    <rect x="96" y="394" width="18" height="14" rx="4" fill="#1E293B" stroke="#E2E8F0" stroke-width="1.2"/>
    <circle cx="105" cy="401" r="2.5" fill="#E2E8F0"/>
    <text x="87" y="424" text-anchor="middle" fill="#CBD5E1" font-family="Courier New, monospace" font-size="7.8" font-weight="700">Token: #CBD5E1</text>
    <text x="87" y="436" text-anchor="middle" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Base #1E293B | Aro #94A3B8</text>
    <text x="87" y="448" text-anchor="middle" fill="#3CCB8C" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Contraste 9,8:1 (AAA)</text>
    <text x="87" y="460" text-anchor="middle" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Cadeado sutil #E2E8F0</text>

    <!-- Right Medal: UNLOCKED (VIBRANT GOLD / DIAMOND) -->
    <rect x="158" y="328" width="126" height="146" rx="6" fill="#1A212B" stroke="#F59E0B" stroke-width="1.4"/>
    <text x="221" y="343" text-anchor="middle" fill="#FDE047" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">DESBLOQUEADA (OURO)</text>
    <circle cx="221" cy="382" r="28" fill="#F59E0B" fill-opacity="0.18"/>
    <circle cx="221" cy="382" r="25" fill="url(#goldMedalGrad)" stroke="#FEF08A" stroke-width="2.2"/>
    <polygon points="221,363 226,374 238,375 229,383 231,395 221,389 211,395 213,383 204,375 216,374" fill="#FFFFFF"/>
    <text x="221" y="424" text-anchor="middle" fill="#F4C650" font-family="Courier New, monospace" font-size="7.8" font-weight="700">Ligas Metálicas</text>
    <text x="221" y="436" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Bronze, Prata, Ouro,</text>
    <text x="221" y="448" text-anchor="middle" fill="#67E8F9" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Platina e Diamante</text>
    <text x="221" y="460" text-anchor="middle" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="6.5">Brilho especular dinâmico</text>

    <!-- PANEL 2 (CENTER): HI-FI MOCKUP 1 — LIVE RADAR + GEO-PRIVACY 500m-800m (x=308, y=46, w=292, h=440) -->
    <rect x="308" y="46" width="292" height="440" rx="16" fill="#0E1218" stroke="#2B3646" stroke-width="2"/>
    <!-- Top Bar -->
    <rect x="320" y="58" width="268" height="32" rx="8" fill="#1A212B" stroke="#2B3646" stroke-width="1"/>
    <circle cx="336" cy="74" r="5" fill="#52B7C0"/>
    <text x="348" y="77" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">HI-FI 1: Radar &amp; Geo-Privacy Lock (500m–800m)</text>

    <!-- Dark Cartographic Canvas (80% viewport feel) -->
    <rect x="320" y="96" width="268" height="252" rx="10" fill="#111823" stroke="#2B3646" stroke-width="1.2"/>
    <!-- Dark Vector Roads -->
    <path d="M 320 145 L 588 185 M 320 265 L 588 220 M 385 96 L 420 348 M 510 96 L 475 348" stroke="#1E293B" stroke-width="5"/>
    <path d="M 320 205 L 588 135 M 445 96 L 455 348" stroke="#1A2433" stroke-width="2.5"/>

    <!-- Geo-Privacy Circle (500m-800m HMAC-SHA256) -->
    <circle cx="454" cy="212" r="68" fill="#52B7C0" fill-opacity="0.14" stroke="#52B7C0" stroke-width="2" stroke-dasharray="6,4"/>
    <circle cx="454" cy="212" r="34" fill="#52B7C0" fill-opacity="0.08" stroke="#52B7C0" stroke-width="1" stroke-dasharray="2,3"/>
    <!-- Shield Lock Center Badge (No exact house pin!) -->
    <rect x="404" y="188" width="100" height="46" rx="8" fill="#0E1218" fill-opacity="0.92" stroke="#52B7C0" stroke-width="1.5"/>
    <text x="454" y="203" text-anchor="middle" fill="#52B7C0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">ÁREA PROTEGIDA</text>
    <text x="454" y="215" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">Raio HMAC 500m–800m</text>
    <text x="454" y="227" text-anchor="middle" fill="#EFCB6B" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Destrava às 00:00 SP</text>

    <!-- Floating Privacy Pill on Map -->
    <rect x="330" y="106" width="248" height="24" rx="12" fill="#12322A" stroke="#3CCB8C" stroke-width="1"/>
    <text x="454" y="121" text-anchor="middle" fill="#86E3BC" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">Fase: HIRED_PRE_DAY_LOCKED &bull; Imune a Triangulação</text>

    <!-- Bottom Sheet Hi-Fi Card -->
    <rect x="320" y="356" width="268" height="118" rx="10" fill="#1A212B" stroke="#2B3646" stroke-width="1.3"/>
    <rect x="434" y="362" width="40" height="4" rx="2" fill="#2B3646"/>
    <text x="332" y="380" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">Reparo de Quadro Elétrico Trifásico</text>
    <rect x="518" y="369" width="58" height="16" rx="8" fill="#362D14" stroke="#EFCB6B" stroke-width="0.8"/>
    <text x="547" y="380" text-anchor="middle" fill="#F1D089" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">AGENDADO</text>

    <text x="332" y="396" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Endereço exato, número e apto ocultos por criptografia</text>
    <text x="332" y="408" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">até 00:00:00 (America/Sao_Paulo) do dia do atendimento.</text>

    <rect x="332" y="418" width="244" height="44" rx="7" fill="#232C39" stroke="#74A7FF" stroke-width="1.2"/>
    <text x="454" y="436" text-anchor="middle" fill="#74A7FF" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">CUSTÓDIA PIX CONFIRMADA: R$ 320,00</text>
    <text x="454" y="450" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="7">Mão de Obra R$ 220,00 + Peças NF-e R$ 100,00 (0% Taxa)</text>

    <!-- PANEL 3 (RIGHT): HI-FI MOCKUP 2 — SMART ESCROW PIN 4 DIGITS & WARRANTY MODAL (x=612, y=46, w=294, h=440) -->
    <rect x="612" y="46" width="294" height="440" rx="16" fill="#0E1218" stroke="#2B3646" stroke-width="2"/>
    <!-- Top Bar -->
    <rect x="624" y="58" width="270" height="32" rx="8" fill="#1A212B" stroke="#2B3646" stroke-width="1"/>
    <circle cx="640" cy="74" r="5" fill="#3CCB8C"/>
    <text x="652" y="77" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">HI-FI 2: Modal Smart Escrow &amp; PIN 4 Dígitos</text>

    <!-- 2-Story Header Preview in Dark Mode -->
    <rect x="624" y="96" width="270" height="62" rx="8" fill="#1A212B" stroke="#2B3646" stroke-width="1.2"/>
    <rect x="632" y="103" width="112" height="18" rx="9" fill="#232C39" stroke="#F59E0B" stroke-width="1"/>
    <text x="688" y="115" text-anchor="middle" fill="#FBBF24" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Elétrica Residencial</text>
    <rect x="802" y="103" width="84" height="18" rx="9" fill="#12322A" stroke="#3CCB8C" stroke-width="1"/>
    <text x="844" y="115" text-anchor="middle" fill="#86E3BC" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="800">EM EXECUÇÃO</text>
    <text x="632" y="136" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Substituição de Disjuntor Geral DR e</text>
    <text x="632" y="149" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Balanceamento de Fases no QDC</text>

    <!-- Smart Escrow Release Modal Card -->
    <rect x="624" y="166" width="270" height="308" rx="10" fill="#141A22" stroke="#3CCB8C" stroke-width="1.5"/>
    <rect x="624" y="166" width="270" height="28" rx="10" fill="#12322A"/>
    <text x="759" y="184" text-anchor="middle" fill="#86E3BC" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">LIBERAÇÃO ATÔMICA DE CUSTÓDIA (SMART ESCROW)</text>

    <text x="759" y="206" text-anchor="middle" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Solicite ao morador o PIN presencial de 4 dígitos:</text>

    <!-- 4 Hi-Fi Digit Boxes -->
    <rect x="646" y="216" width="46" height="52" rx="8" fill="#1A212B" stroke="#6FA8F0" stroke-width="1.8"/>
    <text x="669" y="249" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="20" font-weight="900">4</text>

    <rect x="704" y="216" width="46" height="52" rx="8" fill="#1A212B" stroke="#6FA8F0" stroke-width="1.8"/>
    <text x="727" y="249" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="20" font-weight="900">8</text>

    <rect x="762" y="216" width="46" height="52" rx="8" fill="#1A212B" stroke="#6FA8F0" stroke-width="1.8"/>
    <text x="785" y="249" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="20" font-weight="900">1</text>

    <rect x="820" y="216" width="46" height="52" rx="8" fill="#1A212B" stroke="#3CCB8C" stroke-width="2"/>
    <text x="843" y="249" text-anchor="middle" fill="#3CCB8C" font-family="Inter, Segoe UI, sans-serif" font-size="20" font-weight="900">9</text>

    <!-- Accounting Split Summary Box -->
    <rect x="636" y="278" width="246" height="84" rx="6" fill="#1A212B" stroke="#2B3646" stroke-width="1.2"/>
    <text x="646" y="294" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="700">Repasse Líquido Mão de Obra (85%):</text>
    <text x="872" y="294" text-anchor="end" fill="#3CCB8C" font-family="Courier New, monospace" font-size="7.6" font-weight="700">R$ 187,00</text>

    <text x="646" y="309" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="700">Reembolso Peças NF-e (100% / Taxa 0%):</text>
    <text x="872" y="309" text-anchor="end" fill="#3CCB8C" font-family="Courier New, monospace" font-size="7.6" font-weight="700">R$ 100,00</text>

    <text x="646" y="324" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Taxa Plataforma (13,5% MO):</text>
    <text x="872" y="324" text-anchor="end" fill="#A3AEC0" font-family="Courier New, monospace" font-size="7.4">R$ 29,70</text>

    <text x="646" y="339" fill="#52B7C0" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">Fundo Garantidor 90d (1,5% MO):</text>
    <text x="872" y="339" text-anchor="end" fill="#52B7C0" font-family="Courier New, monospace" font-size="7.4" font-weight="700">R$ 3,30</text>

    <line x1="646" y1="345" x2="872" y2="345" stroke="#2B3646" stroke-width="1"/>
    <text x="646" y="357" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Líquido Total ao Prestador (BIGINT):</text>
    <text x="872" y="357" text-anchor="end" fill="#3CCB8C" font-family="Courier New, monospace" font-size="8.2" font-weight="800">R$ 287,00</text>

    <!-- Primary Release Button -->
    <rect x="636" y="370" width="246" height="36" rx="8" fill="#3CCB8C"/>
    <text x="759" y="392" text-anchor="middle" fill="#0E1218" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="900">CONFIRMAR PIN E LIBERAR PIX</text>

    <!-- Security Footnote inside Modal -->
    <rect x="636" y="414" width="246" height="48" rx="6" fill="#232C39" stroke="#52B7C0" stroke-width="1"/>
    <text x="759" y="428" text-anchor="middle" fill="#52B7C0" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="800">PROTEÇÃO FORENSE E ANTI-COAÇÃO ATIVA</text>
    <text x="759" y="440" text-anchor="middle" fill="#EAEFF6" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Hash verificado em private.job_forensic_secrets [SEC-02].</text>
    <text x="759" y="451" text-anchor="middle" fill="#A3AEC0" font-family="Inter, Segoe UI, sans-serif" font-size="6.7">PIN invertido (9184) aciona FROZEN_UNDER_DURESS.</text>
  </svg>
  <div class="svg-caption">Figura 5.3 — Prototipação Nível 3 (Mockups Hi-Fi Quiet Luxury Dark Mode): Tokens Semânticos Exatos, Amostra dos 33 Emblemas Duotone, Comparação das 112 Medalhas (#CBD5E1 vs. Ouro), Radar com Geo-Privacy Lock (500m–800m) e Modal Smart Escrow por PIN de 4 Dígitos.</div>
</div>
`;

// ============================================================================
// CAPÍTULO 6 — 4 DIAGRAMAS DE ARQUITETURA (SEM .svg-diagram-box EXTERNO POIS
// ch6_arquitetura_e_historico_v2110.mjs JÁ OS ENVOLVE EM .svg-diagram-box)
// ============================================================================

export const svgC4ContextAndContainers = String.raw`
<svg id="fig-15" viewBox="0 0 920 470" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama C4 Níveis 1 e 2 Contexto e Containers segundo ISO IEC IEEE 42010">
  <defs>
    <linearGradient id="c4Hdr" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="50%" stop-color="#1E3A8A"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
    <marker id="c4Arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#2563EB"/>
    </marker>
    <marker id="c4ArrSec" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#059669"/>
    </marker>
  </defs>

  <rect x="0" y="0" width="920" height="470" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
  <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#c4Hdr)"/>
  <rect x="0" y="24" width="920" height="10" fill="url(#c4Hdr)"/>
  <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.5" font-weight="800" letter-spacing="0.7">MODELO C4 (NÍVEIS 1 E 2 — ISO/IEC/IEEE 42010) — CONTEXTO E CONTAINERS DO ECOSSISTEMA DESPERRENGUE (v2.11.0)</text>

  <!-- TOP ACTORS (LEVEL 1 CONTEXT) -->
  <rect x="30" y="44" width="250" height="54" rx="6" fill="#FFF7ED" stroke="#EA580C" stroke-width="1.5"/>
  <text x="155" y="61" text-anchor="middle" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">[PESSOA] MORADOR CONTRATANTE</text>
  <text x="155" y="74" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Abre chamado por voz (&lt;60s), deposita PIX em custódia,</text>
  <text x="155" y="85" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">informa PIN de 4 dígitos e emite Passaporte NBR 5674.</text>

  <rect x="335" y="44" width="250" height="54" rx="6" fill="#EFF6FF" stroke="#1D4ED8" stroke-width="1.5"/>
  <text x="460" y="61" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">[PESSOA] PRESTADOR TÉCNICO / MEI</text>
  <text x="460" y="74" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Homologa KYC VIO/SERPRO, envia propostas grátis (R$ 0),</text>
  <text x="460" y="85" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">anexa NF-e (0% taxa peças) e recebe liquidação PIX.</text>

  <rect x="640" y="44" width="250" height="54" rx="6" fill="#F0FDF4" stroke="#059669" stroke-width="1.5"/>
  <text x="765" y="61" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">[CONTA UNIFICADA DUAL-MODE]</text>
  <text x="765" y="74" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Comutação instantânea O(1) Cliente &harr; Profissional</text>
  <text x="765" y="85" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">com herança criptográfica de KYC aprovado.</text>

  <!-- Arrows from Actors to Client Container -->
  <line x1="155" y1="98" x2="155" y2="120" stroke="#2563EB" stroke-width="1.8" marker-end="url(#c4Arr)"/>
  <line x1="460" y1="98" x2="460" y2="120" stroke="#2563EB" stroke-width="1.8" marker-end="url(#c4Arr)"/>
  <line x1="765" y1="98" x2="765" y2="120" stroke="#2563EB" stroke-width="1.8" marker-end="url(#c4Arr)"/>

  <!-- SYSTEM BOUNDARY BOX (DESPERRENGUE v2.11.0) -->
  <rect x="14" y="114" width="676" height="344" rx="8" fill="#FFFFFF" stroke="#1E3A8A" stroke-width="2" stroke-dasharray="8,4"/>
  <rect x="24" y="106" width="290" height="16" rx="3" fill="#1E3A8A"/>
  <text x="169" y="117" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800"> FRONTEIRA DO SISTEMA DESPERRENGUE (C4 NÍVEL 2 — CONTAINERS) </text>

  <!-- CONTAINER 1: FLUTTER CLIENT APP (Android OTA + Web PWA) -->
  <rect x="28" y="128" width="648" height="72" rx="6" fill="#EFF6FF" stroke="#2563EB" stroke-width="1.5"/>
  <text x="352" y="144" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">[CONTAINER 1] APLICATIVO CLIENTE UNIFICADO — FLUTTER 3.47 / DART 3.13 (ANDROID NATIVO OTA + WEB PWA 480PX)</text>
  <text x="40" y="160" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">UI 120 FPS (8,33ms):</tspan> Quiet Luxury Dark Mode, RepaintBoundary seletivo, InstantCachedImage L1 (96 MiB RAM, 0 ms) + EagerImagePrefetcher.</text>
  <text x="40" y="173" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Workers Paralelos Isolate.run:</tspan> Portão KYC Tier-0 (Laplaciano a R$ 0,00), ImageMetadataStripper (100% strip EXIF/GPS) e PDF ABNT NBR 5674.</text>
  <text x="40" y="186" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Segurança &amp; Resiliência:</tspan> PKCE Auth, GeoPrivacyPolicyEngine (fail-closed), ResilientStream (backoff + jitter) e AppVersionAndUpdateService (OTA).</text>

  <!-- Arrows from Flutter App to Backend Containers -->
  <line x1="160" y1="200" x2="160" y2="226" stroke="#2563EB" stroke-width="1.8" marker-end="url(#c4Arr)"/>
  <text x="166" y="216" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">HTTPS / WSS TLS 1.3</text>

  <line x1="395" y1="200" x2="395" y2="226" stroke="#2563EB" stroke-width="1.8" marker-end="url(#c4Arr)"/>
  <text x="401" y="216" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">JWT + CORS Estrito</text>

  <line x1="575" y1="200" x2="575" y2="226" stroke="#059669" stroke-width="1.8" marker-end="url(#c4ArrSec)"/>
  <text x="581" y="216" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="6.8" font-weight="700">Token Anti-Swap</text>

  <!-- CONTAINER 2: SUPABASE CORE (Auth, PostgREST, Realtime, Storage) -->
  <rect x="28" y="228" width="248" height="104" rx="6" fill="#F0FDF4" stroke="#059669" stroke-width="1.5"/>
  <text x="152" y="244" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">[CONTAINER 2] SUPABASE GATEWAY</text>
  <text x="36" y="259" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">GoTrue Auth:</tspan> OAuth2 PKCE + JWT RS256/HS256.</text>
  <text x="36" y="272" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">PostgREST API:</tspan> Exposição tipada de views e</text>
  <text x="42" y="282" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">35+ RPCs transacionais SECURITY DEFINER.</text>
  <text x="36" y="295" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">Realtime WebSockets:</tspan> Eventos de chat, status</text>
  <text x="42" y="305" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">de custódia e telemetria de deslocamento.</text>
  <text x="36" y="318" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">Storage:</tspan> Bucket WORM forensic-evidence [SEC-09].</text>

  <!-- CONTAINER 3: 5 DENO EDGE FUNCTIONS -->
  <rect x="286" y="228" width="196" height="104" rx="6" fill="#FFFBEB" stroke="#D97706" stroke-width="1.5"/>
  <text x="384" y="244" text-anchor="middle" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">[CONTAINER 3] 5 EDGE FUNCTIONS</text>
  <text x="294" y="258" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; <tspan font-weight="700">pix-webhook:</tspan> Valida PSP e confirm_topup.</text>
  <text x="294" y="271" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; <tspan font-weight="700">kyc-argon-vision-gate:</tspan> OCR CNH e NF-e</text>
  <text x="300" y="281" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">44 dígitos (temp=0.0, anti-injection).</text>
  <text x="294" y="294" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; <tspan font-weight="700">kyc-carbon-webhook:</tspan> timingSafeEqual.</text>
  <text x="294" y="307" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; <tspan font-weight="700">excluir-conta + dossie.ts:</tspan> PDF A4 LGPD.</text>
  <text x="294" y="320" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; <tspan font-weight="700">enviar-email-aprovacao:</tspan> Notificação Resend.</text>

  <!-- CONTAINER 4: PYTHON FASTAPI KYC_ENGINE -->
  <rect x="492" y="228" width="184" height="104" rx="6" fill="#F5F3FF" stroke="#6D28D9" stroke-width="1.5"/>
  <text x="584" y="244" text-anchor="middle" fill="#4C1D95" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">[CONTAINER 4] KYC_ENGINE (PYTHON)</text>
  <text x="500" y="259" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">FastAPI + Pydantic v2:</tspan> Sessão HMAC</text>
  <text x="506" y="269" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Anti-Swap (TTL &le; 180s).</text>
  <text x="500" y="282" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">Decoder VIO ICP-Brasil:</tspan> 2x bicubic +</text>
  <text x="506" y="292" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">CLAHE + CMS/PKCS#7 ECDSA P-256.</text>
  <text x="500" y="305" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; <tspan font-weight="700">CarbonFraudOrchestrator:</tspan> 5 Hard</text>
  <text x="506" y="315" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Vetos + SHAP + Cofre WORM KWV2.</text>

  <!-- Arrows down to PostgreSQL 17 -->
  <line x1="152" y1="332" x2="152" y2="354" stroke="#059669" stroke-width="1.8" marker-end="url(#c4ArrSec)"/>
  <line x1="384" y1="332" x2="384" y2="354" stroke="#059669" stroke-width="1.8" marker-end="url(#c4ArrSec)"/>
  <line x1="584" y1="332" x2="460" y2="354" stroke="#6D28D9" stroke-width="1.5" stroke-dasharray="4,2" marker-end="url(#c4Arr)"/>

  <!-- CONTAINER 5: POSTGRESQL 17 (27 MIGRATIONS) -->
  <rect x="28" y="356" width="648" height="90" rx="6" fill="#0F172A" stroke="#38BDF8" stroke-width="1.6"/>
  <text x="352" y="373" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">[CONTAINER 5] BANCO DE DADOS RELACIONAL ACID — POSTGRESQL 17 (27 MIGRAÇÕES SQL DETERMINÍSTICAS NA v2.11.0 / 30 HEAD)</text>
  <text x="40" y="389" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">&bull; <tspan fill="#34D399" font-weight="700">Esquema Público (RLS Estrito):</tspan> profiles, jobs, job_quotes, client_wallets, escrow_maturation_entries, warranty_pool_ledger, job_mediations, achievements.</text>
  <text x="40" y="403" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">&bull; <tspan fill="#FBBF24" font-weight="700">Esquema Privado Isolado (private.*):</tspan> private.geo_privacy_secrets (CSPRNG 256-bit HMAC) e private.job_forensic_secrets (PIN hash &amp; presence secret [SEC-02]).</text>
  <text x="40" y="417" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">&bull; <tspan fill="#93C5FD" font-weight="700">Invariantes &amp; Concorrência:</tspan> Moeda inteira BIGINT, partidas dobradas soma-zero, ordem canônica de locks R1 &lt; R2 &lt; R3 &lt; R4 (0 deadlocks) e Geo-Lock 00:00 SP.</text>
  <text x="40" y="431" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; Blindagens Red Team [SEC-01] a [SEC-09]: search_path = public fixo em todas as funções SECURITY DEFINER, anti-IDOR e clawback SEFAZ pós-26h.</text>

  <!-- EXTERNAL SYSTEMS COLUMN (RIGHT SIDE, x=704, w=202) -->
  <rect x="704" y="114" width="202" height="344" rx="8" fill="#F1F5F9" stroke="#64748B" stroke-width="1.5"/>
  <rect x="704" y="114" width="202" height="22" rx="8" fill="#475569"/>
  <text x="805" y="129" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">SISTEMAS EXTERNOS HOMOLOGADOS</text>

  <!-- Ext 1: VIO / SERPRO / ICP-Brasil -->
  <rect x="714" y="144" width="182" height="60" rx="5" fill="#FFFFFF" stroke="#64748B" stroke-width="1.2"/>
  <text x="722" y="159" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">1. SERPRO Datavalid &amp; ICP-Brasil</text>
  <text x="722" y="171" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Validação biométrica oficial via</text>
  <text x="722" y="181" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">mTLS 1.3 (Certificado A1) e cadeia</text>
  <text x="722" y="191" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">de chaves públicas SENATRAN/VIO.</text>

  <!-- Ext 2: PSP PIX / BACEN & SEFAZ -->
  <rect x="714" y="212" width="182" height="60" rx="5" fill="#FFFFFF" stroke="#64748B" stroke-width="1.2"/>
  <text x="722" y="227" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">2. PSP PIX (BACEN) &amp; SEFAZ</text>
  <text x="722" y="239" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Liquidação instantânea de custódia</text>
  <text x="722" y="249" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(webhooks assinados) e consulta</text>
  <text x="722" y="259" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">de idoneidade de NF-e (44 dígitos).</text>

  <!-- Ext 3: Gemini 4 Argon High -->
  <rect x="714" y="280" width="182" height="54" rx="5" fill="#FFFFFF" stroke="#64748B" stroke-width="1.2"/>
  <text x="722" y="295" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">3. Motor Multimodal Argon High</text>
  <text x="722" y="307" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Extração visual determinística</text>
  <text x="722" y="317" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(temperature=0.0, bbox [0..1000]).</text>

  <!-- Ext 4: Resend + OSRM + GitHub Releases -->
  <rect x="714" y="342" width="182" height="60" rx="5" fill="#FFFFFF" stroke="#64748B" stroke-width="1.2"/>
  <text x="722" y="357" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">4. Resend, OSRM &amp; GitHub OTA</text>
  <text x="722" y="369" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Entrega de Dossiê PDF LGPD, rotas</text>
  <text x="722" y="379" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">cartográficas e distribuição HTTPS</text>
  <text x="722" y="389" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">de releases APK (beta-latest).</text>

  <!-- Connectors to External Systems -->
  <line x1="676" y1="265" x2="714" y2="175" stroke="#475569" stroke-width="1.4" marker-end="url(#c4Arr)"/>
  <path d="M 435 332 L 435 341 L 690 341 L 690 242 L 714 242" fill="none" stroke="#475569" stroke-width="1.4" marker-end="url(#c4Arr)"/>
  <path d="M 455 332 L 455 346 L 696 346 L 696 305 L 714 305" fill="none" stroke="#475569" stroke-width="1.4" marker-end="url(#c4Arr)"/>
  <line x1="676" y1="165" x2="714" y2="365" stroke="#475569" stroke-width="1.4" marker-end="url(#c4Arr)"/>
</svg>
`;

export const svgCleanArchitecture4Layers = String.raw`
<svg id="fig-16" viewBox="0 0 920 420" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama das 4 Camadas da Clean Architecture e Orçamento de Quadro de 120 FPS">
  <defs>
    <linearGradient id="caHdr" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="50%" stop-color="#047857"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
    <marker id="caArrDown" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#0F172A"/>
    </marker>
  </defs>

  <rect x="0" y="0" width="920" height="420" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
  <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#caHdr)"/>
  <rect x="0" y="24" width="920" height="10" fill="url(#caHdr)"/>
  <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.5" font-weight="800" letter-spacing="0.7">CLEAN ARCHITECTURE EM 4 CAMADAS CONCÊNTRICAS &bull; ISOLAMENTO DE THREADS E ORÇAMENTO 120 FPS (8,33 MS)</text>

  <!-- LAYER 1: PRESENTATION & RENDER ENGINE (120 FPS) -->
  <rect x="16" y="44" width="690" height="82" rx="6" fill="#EFF6FF" stroke="#2563EB" stroke-width="1.6"/>
  <rect x="16" y="44" width="186" height="82" rx="6" fill="#1D4ED8"/>
  <text x="109" y="72" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">CAMADA 1 — APRESENTAÇÃO</text>
  <text x="109" y="86" text-anchor="middle" fill="#BAE6FD" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">UI Thread &amp; Raster Thread</text>
  <text x="109" y="100" text-anchor="middle" fill="#FFFFFF" font-family="Courier New, monospace" font-size="7.5" font-weight="700">&Delta;t &le; 8,33 ms (120 Hz)</text>

  <text x="214" y="61" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Módulos Reais (app/lib/features/*/presentation &amp; app/lib/core/ui):</text>
  <text x="214" y="75" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Design System Quiet Luxury Dark:</tspan> app_tokens.dart, app_theme.dart, ConstrainedBox(maxWidth: 480) e cabeçalho de 2 andares.</text>
  <text x="214" y="88" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Zero Frame Drop:</tspan> RepaintBoundary seletivo em mapas (OrderLiveMapModalScreen 80% livre), cronômetros e listas roláveis.</text>
  <text x="214" y="101" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Mídia 0 ms &amp; Insígnias Vetoriais:</tspan> InstantCachedImage (L1 96 MiB), CategoryBrandEmblem (33 Duotone) e AchievementMedalForge (#CBD5E1).</text>
  <text x="214" y="114" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">&bull; Regra Arquitetural: Proibido executar I/O pesado, criptografia ou parsing binário na UI Thread (validado por eng_static_guards_test.dart).</text>

  <!-- LAYER 2: APPLICATION & STATE ORCHESTRATION -->
  <rect x="16" y="136" width="690" height="82" rx="6" fill="#F0FDF4" stroke="#059669" stroke-width="1.6"/>
  <rect x="16" y="136" width="186" height="82" rx="6" fill="#047857"/>
  <text x="109" y="164" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">CAMADA 2 — APLICAÇÃO</text>
  <text x="109" y="178" text-anchor="middle" fill="#A7F3D0" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">Controladores &amp; Políticas</text>
  <text x="109" y="192" text-anchor="middle" fill="#FFFFFF" font-family="Courier New, monospace" font-size="7.5" font-weight="700">Badge O(1) | Conquistas O(N)</text>

  <text x="214" y="153" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Módulos Reais (app/lib/core/security, controllers &amp; formatters):</text>
  <text x="214" y="167" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">GeoPrivacyPolicyEngine:</tspan> Consumo estrito de ProviderLocationView.fromRpc (fail-closed antes das 00:00:00 America/Sao_Paulo).</text>
  <text x="214" y="180" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">UnreadOrdersBadgeController:</tspan> Atualização e decremento de contadores não lidos em tempo constante O(1) amortizado em RAM.</text>
  <text x="214" y="193" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">SmartTriage &amp; SmartTranscriptFormatter:</tspan> Pontuação instantânea de voz e classificação determinística nas 33 categorias (&lt; 60s).</text>
  <text x="214" y="206" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">&bull; KycHumanFeedbackTranslator: Tradução de códigos forenses/SHAP para linguagem cidadã clara sem jargão técnico (RNF-03).</text>

  <!-- LAYER 3: DOMAIN MODELS & BACKGROUND ISOLATES (Isolate.run) -->
  <rect x="16" y="228" width="690" height="86" rx="6" fill="#FFFBEB" stroke="#D97706" stroke-width="1.6"/>
  <rect x="16" y="228" width="186" height="86" rx="6" fill="#B45309"/>
  <text x="109" y="256" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">CAMADA 3 — DOMÍNIO &amp; CV</text>
  <text x="109" y="270" text-anchor="middle" fill="#FDE68A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">Entidades &amp; Isolate.run</text>
  <text x="109" y="284" text-anchor="middle" fill="#FFFFFF" font-family="Courier New, monospace" font-size="7.5" font-weight="700">Moeda Inteira &#8484;₆₄ (Cents)</text>

  <text x="214" y="245" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Módulos Reais (app/lib/core/models, utils/off_thread.dart &amp; services):</text>
  <text x="214" y="259" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Núcleo Financeiro e Fiscal Puro:</tspan> money.dart (centavos inteiros sem erro IEEE 754) e nfe_access_key.dart (validação 44 dígitos Módulo 11).</text>
  <text x="214" y="272" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Worker 1 — KYC Tier-0 On-Device:</tspan> Variância do operador Laplaciano (nitidez), luminância e geometria em Isolate.run a custo R$ 0,00.</text>
  <text x="214" y="285" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Worker 2 — ImageMetadataStripper:</tspan> Remoção binária fail-closed de segmentos APP1/EXIF (GPS), XMP e IPTC antes de qualquer upload.</text>
  <text x="214" y="298" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">&bull; Worker 3 — DesperrengueOfficialPdfService: Compilação off-thread do Passaporte Predial vetorial %PDF-1.4 (ABNT NBR 5674 + SHA-256).</text>

  <!-- LAYER 4: INFRASTRUCTURE, PERSISTENCE, EDGE & KYC_ENGINE -->
  <rect x="16" y="324" width="690" height="82" rx="6" fill="#0F172A" stroke="#38BDF8" stroke-width="1.6"/>
  <rect x="16" y="324" width="186" height="82" rx="6" fill="#1E293B"/>
  <text x="109" y="352" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="8.8" font-weight="800">CAMADA 4 — PERSISTÊNCIA</text>
  <text x="109" y="366" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">SQL ACID, Edge &amp; KYC</text>
  <text x="109" y="380" text-anchor="middle" fill="#34D399" font-family="Courier New, monospace" font-size="7.3" font-weight="700">R1 &lt; R2 &lt; R3 &lt; R4</text>

  <text x="214" y="341" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">Infraestrutura Distribuída (supabase/migrations, functions &amp; kyc_engine):</text>
  <text x="214" y="355" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">PostgreSQL 17 (27 Migrações):</tspan> RLS forçado, 35+ RPCs SECURITY DEFINER (search_path=public) e esquemas privados isolados.</text>
  <text x="214" y="368" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">5 Deno Edge Functions:</tspan> pix-webhook, kyc-argon-vision-gate, kyc-carbon-webhook, excluir-conta (Dossiê PDF) e enviar-email-aprovacao.</text>
  <text x="214" y="381" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; <tspan font-weight="700">Microsserviço Python FastAPI kyc_engine:</tspan> QR VIO ICP-Brasil (CMS/PKCS#7), SERPRO mTLS 1.3, Carbon SHAP e Cofre WORM KWV2.</text>
  <text x="214" y="394" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">&bull; Rede Resiliente: ResilientStream (backoff exponencial + jitter), cascata dupla OSRM + fallback geodésico C&infin; e OTA GitHub HTTPS.</text>

  <!-- RIGHT SIDEBAR: DEPENDENCY RULE & VERIFICATION METRICS (x=718, w=188) -->
  <rect x="718" y="44" width="188" height="362" rx="6" fill="#FFFFFF" stroke="#0F172A" stroke-width="1.5"/>
  <rect x="718" y="44" width="188" height="24" rx="6" fill="#0F172A"/>
  <text x="812" y="60" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">REGRA DE DEPENDÊNCIA</text>

  <!-- Vertical Dependency Arrow -->
  <line x1="742" y1="82" x2="742" y2="250" stroke="#0F172A" stroke-width="2.5" marker-end="url(#caArrDown)"/>
  <text x="754" y="98" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">1. Apresentação (UI)</text>
  <text x="754" y="110" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Depende apenas de Contratos</text>

  <text x="754" y="142" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">2. Aplicação (Estado)</text>
  <text x="754" y="154" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Orquestra Casos de Uso</text>

  <text x="754" y="186" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">3. Domínio (Núcleo Puro)</text>
  <text x="754" y="198" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Zero dependência de UI/SDK</text>

  <text x="754" y="230" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">4. Infra / Persistência</text>
  <text x="754" y="242" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Implementa Adaptadores</text>

  <line x1="728" y1="264" x2="896" y2="264" stroke="#CBD5E1" stroke-width="1"/>
  <text x="812" y="280" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">ORÁCULOS DE VERIFICAÇÃO</text>

  <rect x="728" y="288" width="168" height="24" rx="4" fill="#EFF6FF"/>
  <text x="812" y="303" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">762 Testes Flutter (816 HEAD)</text>

  <rect x="728" y="316" width="168" height="24" rx="4" fill="#F5F3FF"/>
  <text x="812" y="331" text-anchor="middle" fill="#4C1D95" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">64 Testes Python pytest (KYC)</text>

  <rect x="728" y="344" width="168" height="24" rx="4" fill="#ECFDF5"/>
  <text x="812" y="359" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">12 Checks SQL Geo-Lock (14 HEAD)</text>

  <rect x="728" y="372" width="168" height="24" rx="4" fill="#FFF7ED"/>
  <text x="812" y="387" text-anchor="middle" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">17 Testes PDF LGPD + 630 Links</text>
</svg>
`;

export const svgGeoPrivacyAndEscrowSequence = String.raw`
<svg id="fig-17" viewBox="0 0 920 480" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama de Sequência e Estados Temporal e Spatial Geo-Privacy Lock Smart Escrow e Garantia 3 Camadas">
  <defs>
    <linearGradient id="seqHdr" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="50%" stop-color="#0F766E"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
    <marker id="seqArr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#0F172A"/>
    </marker>
    <marker id="seqArrGreen" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#059669"/>
    </marker>
    <marker id="seqArrRed" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#B91C1C"/>
    </marker>
  </defs>

  <rect x="0" y="0" width="920" height="480" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
  <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#seqHdr)"/>
  <rect x="0" y="24" width="920" height="10" fill="url(#seqHdr)"/>
  <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.3" font-weight="800" letter-spacing="0.6"> MÁQUINA DE ESTADOS E SEQUÊNCIA: GEO-PRIVACY LOCK (00:00 SP) &bull; SMART ESCROW BIGINT &bull; GARANTIA 3 CAMADAS</text>

  <!-- 5 LIFELINE HEADERS -->
  <rect x="18" y="42" width="144" height="32" rx="5" fill="#FFF7ED" stroke="#EA580C" stroke-width="1.4"/>
  <text x="90" y="57" text-anchor="middle" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">1. App Morador</text>
  <text x="90" y="68" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">(Cliente Contratante)</text>

  <rect x="198" y="42" width="164" height="32" rx="5" fill="#0F172A" stroke="#38BDF8" stroke-width="1.4"/>
  <text x="280" y="57" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">2. Motor Geo-Privacy SQL</text>
  <text x="280" y="68" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">private.geo_privacy_secrets</text>

  <rect x="398" y="42" width="164" height="32" rx="5" fill="#ECFDF5" stroke="#059669" stroke-width="1.4"/>
  <text x="480" y="57" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">3. Smart Escrow &amp; Split</text>
  <text x="480" y="68" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Ledgers BIGINT + SEFAZ</text>

  <rect x="598" y="42" width="144" height="32" rx="5" fill="#EFF6FF" stroke="#1D4ED8" stroke-width="1.4"/>
  <text x="670" y="57" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">4. App Prestador</text>
  <text x="670" y="68" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">(Técnico Contratado)</text>

  <rect x="770" y="42" width="134" height="32" rx="5" fill="#FEF2F2" stroke="#B91C1C" stroke-width="1.4"/>
  <text x="837" y="57" text-anchor="middle" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">5. Garantia 90d</text>
  <text x="837" y="68" text-anchor="middle" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">warranty_pool_ledger</text>

  <!-- Vertical Lifelines -->
  <line x1="90" y1="74" x2="90" y2="465" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="4,3"/>
  <line x1="280" y1="74" x2="280" y2="465" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="4,3"/>
  <line x1="480" y1="74" x2="480" y2="465" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="4,3"/>
  <line x1="670" y1="74" x2="670" y2="465" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="4,3"/>
  <line x1="837" y1="74" x2="837" y2="465" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="4,3"/>

  <!-- PHASE 1: PUBLIC_FUZZY -->
  <rect x="18" y="82" width="664" height="54" rx="5" fill="#F1F5F9" stroke="#64748B" stroke-width="1.2"/>
  <rect x="24" y="87" width="162" height="16" rx="3" fill="#0F172A"/>
  <text x="105" y="98" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">FASE 1: PUBLIC_FUZZY (RADAR)</text>
  <line x1="90" y1="112" x2="274" y2="112" stroke="#0F172A" stroke-width="1.5" marker-end="url(#seqArr)"/>
  <text x="182" y="108" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">1. Publica Ordem (Strip EXIF GPS)</text>
  <line x1="280" y1="122" x2="664" y2="122" stroke="#0F172A" stroke-width="1.5" marker-end="url(#seqArr)"/>
  <text x="472" y="118" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">2. _geo_fuzzy_center = HMAC-SHA256(job_id, K_geo) &rarr; Offset 151m–349m em Raio 500m–800m (Rua/Nº = NULL)</text>

  <!-- PHASE 2: HIRED_PRE_DAY_LOCKED & SMART ESCROW DEPOSIT -->
  <rect x="18" y="144" width="664" height="68" rx="5" fill="#FFFBEB" stroke="#D97706" stroke-width="1.2"/>
  <rect x="24" y="149" width="246" height="16" rx="3" fill="#B45309"/>
  <text x="147" y="160" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">FASE 2: HIRED_PRE_DAY_LOCKED (PRÉ-DIA 00:00)</text>
  <line x1="670" y1="172" x2="486" y2="172" stroke="#0F172A" stroke-width="1.5" marker-end="url(#seqArr)"/>
  <text x="578" y="168" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">3. Orçamento Grátis (labor + materials)</text>
  <line x1="90" y1="184" x2="474" y2="184" stroke="#059669" stroke-width="1.6" marker-end="url(#seqArrGreen)"/>
  <text x="282" y="180" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">4. Aceita e Deposita PIX (confirm_topup idempotente em BIGINT)</text>
  <line x1="280" y1="202" x2="664" y2="202" stroke="#B91C1C" stroke-width="1.5" stroke-dasharray="4,2" marker-end="url(#seqArrRed)"/>
  <text x="472" y="198" text-anchor="middle" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">5. Antes de 00:00:00 SP do service_day: Mesmo contratado, endereço exato permanece BLOQUEADO (NULL)</text>

  <!-- PHASE 3: SERVICE_DAY_UNLOCKED (00:00 SP) + SMART SPLIT NF-E -->
  <rect x="18" y="220" width="664" height="72" rx="5" fill="#ECFDF5" stroke="#059669" stroke-width="1.3"/>
  <rect x="24" y="225" width="270" height="16" rx="3" fill="#059669"/>
  <text x="159" y="236" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">FASE 3: SERVICE_DAY_UNLOCKED (ÀS 00:00:00 SP)</text>
  <line x1="280" y1="252" x2="664" y2="252" stroke="#059669" stroke-width="1.6" marker-end="url(#seqArrGreen)"/>
  <text x="472" y="248" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">6. Relógio atinge 00:00 SP (ou SOS imediato): get_job_location_for_viewer libera endereço só ao contratado</text>
  <line x1="670" y1="276" x2="486" y2="276" stroke="#0F172A" stroke-width="1.5" marker-end="url(#seqArr)"/>
  <text x="578" y="272" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">7. Check-in HMAC [SEC-05] + Upload NF-e 44d (0% Taxa Peças)</text>

  <!-- PHASE 4: CHECKOUT PIN 4 DIGITS + POST_COMPLETION_RELOCKED -->
  <rect x="18" y="300" width="886" height="82" rx="5" fill="#EFF6FF" stroke="#2563EB" stroke-width="1.4"/>
  <rect x="24" y="305" width="320" height="16" rx="3" fill="#1E3A8A"/>
  <text x="184" y="316" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">FASE 4: CHECKOUT PIN 4 DÍGITOS &amp; POST_COMPLETION_RELOCKED</text>
  <line x1="90" y1="334" x2="664" y2="334" stroke="#0F172A" stroke-width="1.5" marker-end="url(#seqArr)"/>
  <text x="377" y="330" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">8. Morador informa PIN de 4 dígitos (se invertido &rarr; FROZEN_UNDER_DURESS silencioso)</text>
  <line x1="670" y1="350" x2="486" y2="350" stroke="#059669" stroke-width="1.6" marker-end="url(#seqArrGreen)"/>
  <text x="578" y="346" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">9. Valida hash em private.job_forensic_secrets [SEC-02]</text>
  <line x1="480" y1="368" x2="831" y2="368" stroke="#059669" stroke-width="1.6" marker-end="url(#seqArrGreen)"/>
  <text x="655" y="364" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="700">10. Split Atômico: 85% MO + 100% Peças (Técnico) | 13,5% App | 1,5% warranty_pool_ledger | Re-ofusca Endereço!</text>

  <!-- PHASE 5: 3-LAYER 90-DAY WARRANTY & SEFAZ >26H AUDIT -->
  <rect x="18" y="390" width="886" height="78" rx="5" fill="#FEF2F2" stroke="#EF4444" stroke-width="1.4"/>
  <rect x="24" y="395" width="365" height="16" rx="3" fill="#991B1B"/>
  <text x="206" y="406" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">PÓS-SERVIÇO: GARANTIA 90 DIAS (3 CAMADAS) &amp; AUDITORIA SEFAZ (&gt;26H)</text>
  <text x="28" y="424" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">Worker SEFAZ (&gt;26h):</tspan> Reconsulta chave NF-e de 44 dígitos após janela de cancelamento; se inválida, aplica clawback de 15% [SEC-04].</text>
  <text x="28" y="438" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; <tspan font-weight="700">Garantia 90d (CDC Art. 26):</tspan> Camada 1 (Retorno técnico 48h) &rarr; Camada 2 (Perícia forense SHA-256 + bloqueio cautelar) &rarr; Camada 3</text>
  <text x="36" y="451" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">(trigger_layer3_rework [SEC-06]: debita warranty_pool_ledger sob ordem estrita de locks R1 &lt; R2 &lt; R3 &lt; R4 com zero deadlocks).</text>
</svg>
`;

export const svgKycZeroTrustArchitecture = String.raw`
<svg id="fig-18" viewBox="0 0 920 430" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Pipeline Criptográfico e Biométrico Zero-Trust KYC em 6 Estágios">
  <defs>
    <linearGradient id="kycHdr" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="50%" stop-color="#4C1D95"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
    <marker id="kycArr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#4C1D95"/>
    </marker>
  </defs>

  <rect x="0" y="0" width="920" height="430" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
  <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#kycHdr)"/>
  <rect x="0" y="24" width="920" height="10" fill="url(#kycHdr)"/>
  <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.5" font-weight="800" letter-spacing="0.7">ARQUITETURA DO MOTOR KYC ZERO-TRUST EM 6 ESTÁGIOS &bull; VIO ICP-BRASIL, SERPRO mTLS, SHAP E COFRE WORM</text>

  <!-- ROW 1: STAGES 1, 2, 3 -->
  <!-- Stage 1: Tier-0 Isolate.run -->
  <rect x="16" y="46" width="280" height="156" rx="6" fill="#FFFFFF" stroke="#2563EB" stroke-width="1.5"/>
  <rect x="16" y="46" width="280" height="24" rx="6" fill="#1D4ED8"/>
  <text x="156" y="62" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 1 — PORTÃO TIER-0 ON-DEVICE (R$ 0,00)</text>
  <text x="26" y="82" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Execução Paralela em Isolate.run (off_thread.dart):</text>
  <text x="32" y="94" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Inspeção matemática de nitidez pela variância do</text>
  <text x="32" y="105" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">operador Laplaciano (&nabla;&sup2;I), luminância e bordas.</text>
  <text x="26" y="120" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Sanitização e Validação Algorítmica Local:</text>
  <text x="32" y="132" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Dígitos verificadores Módulo 11 (CPF/CNH) +</text>
  <text x="32" y="143" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">ImageMetadataStripper (remove 100% EXIF GPS).</text>
  <rect x="26" y="154" width="260" height="38" rx="4" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
  <text x="156" y="169" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Economia FinOps: Barra fotos borradas a custo R$ 0,00</text>
  <text x="156" y="182" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7">antes de acionar APIs de visão ou governo.</text>

  <line x1="296" y1="124" x2="316" y2="124" stroke="#4C1D95" stroke-width="2" marker-end="url(#kycArr)"/>

  <!-- Stage 2: Anti-Swap Session + Argon Vision Gate -->
  <rect x="320" y="46" width="280" height="156" rx="6" fill="#FFFFFF" stroke="#7C3AED" stroke-width="1.5"/>
  <rect x="320" y="46" width="280" height="24" rx="6" fill="#5B21B6"/>
  <text x="460" y="62" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 2 — SESSÃO ANTI-SWAP &amp; ARGON VISION</text>
  <text x="330" y="82" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Token Efêmero Anti-Swap (POST /v1/kyc/session/init):</text>
  <text x="336" y="94" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Assinado por HMAC-SHA256 com TTL &le; 180s vinculando</text>
  <text x="336" y="105" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">user_id, nonce e hash da captura (impede troca de doc).</text>
  <text x="330" y="120" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Extração Grounded (kyc-argon-vision-gate):</text>
  <text x="336" y="132" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Gemini 4 Argon High com temperature = 0.0 e</text>
  <text x="336" y="143" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">bounding boxes normalizadas [ymin, xmin, ymax, xmax].</text>
  <rect x="330" y="154" width="260" height="38" rx="4" fill="#F5F3FF" stroke="#C4B5FD" stroke-width="1"/>
  <text x="460" y="169" text-anchor="middle" fill="#4C1D95" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Blindagem Anti-Prompt-Injection Visual:</text>
  <text x="460" y="182" text-anchor="middle" fill="#334155" font-family="Courier New, monospace" font-size="6.8">&lt;untrusted_visual_ocr_stream&gt; isolado</text>

  <line x1="600" y1="124" x2="620" y2="124" stroke="#4C1D95" stroke-width="2" marker-end="url(#kycArr)"/>

  <!-- Stage 3: VIO ICP-Brasil + NFC eMRTD + SERPRO mTLS -->
  <rect x="624" y="46" width="280" height="156" rx="6" fill="#FFFFFF" stroke="#059669" stroke-width="1.5"/>
  <rect x="624" y="46" width="280" height="24" rx="6" fill="#047857"/>
  <text x="764" y="62" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 3 — VIO ICP-BRASIL, NFC &amp; SERPRO mTLS</text>
  <text x="634" y="82" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Pré-Processamento &amp; Assinatura QR VIO SENATRAN:</text>
  <text x="640" y="94" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Upscale bicúbico 2x + CLAHE + zlib (&le; 64 KiB) +</text>
  <text x="640" y="105" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">verificação CMS/PKCS#7 (ECDSA P-256 / RSA-2048).</text>
  <text x="634" y="120" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Autenticação Passiva NFC (ICAO 9303) &amp; SERPRO:</text>
  <text x="640" y="132" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Valida EF.SOD (DG1/DG2) e consulta SerproDatavalid</text>
  <text x="640" y="143" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">via TLS 1.3 mTLS (Certificado Digital ICP-Brasil A1).</text>
  <rect x="634" y="154" width="260" height="38" rx="4" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1"/>
  <text x="764" y="169" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Invariante Triplo de Identidade Civil:</text>
  <text x="764" y="182" text-anchor="middle" fill="#0F172A" font-family="Courier New, monospace" font-size="7.2" font-weight="700">qr_cpf == ocr_cpf == typed_cpf</text>

  <!-- Connector from Stage 3 down to Stage 4 -->
  <path d="M 764 202 L 764 220 L 156 220 L 156 238" fill="none" stroke="#4C1D95" stroke-width="2" marker-end="url(#kycArr)"/>

  <!-- ROW 2: STAGES 4, 5, 6 -->
  <!-- Stage 4: Liveness + 5 Hard Vetos + Carbon SHAP -->
  <rect x="16" y="240" width="280" height="168" rx="6" fill="#FFFFFF" stroke="#D97706" stroke-width="1.5"/>
  <rect x="16" y="240" width="280" height="24" rx="6" fill="#B45309"/>
  <text x="156" y="256" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 4 — 5 HARD VETOS &amp; CARBON SHAP</text>
  <text x="26" y="276" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; 5 Hard Vetos Determinísticos Pré-LLM:</text>
  <text x="32" y="288" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(1) Divergência tripla de CPF; (2) Assinatura VIO/NFC</text>
  <text x="32" y="299" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">inválida; (3) Biometria SERPRO &lt; limiar; (4) Replay</text>
  <text x="32" y="310" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">de Liveness (&gt;90s); (5) Spoofing de tela/impressão.</text>
  <text x="26" y="325" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Explicabilidade Algorítmica (LGPD Art. 20):</text>
  <text x="32" y="337" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">CarbonFraudOrchestrator calcula os Top-3 fatores</text>
  <text x="32" y="348" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">SHAP auditáveis traduzidos sem jargão técnico.</text>
  <rect x="26" y="358" width="260" height="38" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
  <text x="156" y="373" text-anchor="middle" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Decisão Monotônica Imune a Alucinação:</text>
  <text x="156" y="386" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7">Nenhum modelo neural pode sobrepor um Hard Veto.</text>

  <line x1="296" y1="324" x2="316" y2="324" stroke="#4C1D95" stroke-width="2" marker-end="url(#kycArr)"/>

  <!-- Stage 5: WORM Vault KWV2 + Carbon Webhook -->
  <rect x="320" y="240" width="280" height="168" rx="6" fill="#FFFFFF" stroke="#0F172A" stroke-width="1.5"/>
  <rect x="320" y="240" width="280" height="24" rx="6" fill="#0F172A"/>
  <text x="460" y="256" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 5 — COFRE WORM KWV2 &amp; WEBHOOK</text>
  <text x="330" y="276" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Criptografia Autenticada Envelope KWV2:</text>
  <text x="336" y="288" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Chave efêmera derivada por HKDF-SHA256 por dossiê</text>
  <text x="336" y="299" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">+ cifra AES-256-GCM (nonce CSPRNG 96 bits + Tag</text>
  <text x="336" y="310" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">128 bits) em armazenamento WORM imutável.</text>
  <text x="330" y="325" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Notificação Segura (kyc-carbon-webhook):</text>
  <text x="336" y="337" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Assinatura HMAC verificada em tempo constante</text>
  <text x="336" y="348" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(timingSafeEqual) + janela anti-replay &le; 300s.</text>
  <rect x="330" y="358" width="260" height="38" rx="4" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1"/>
  <text x="460" y="373" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Persistência SQL (apply_verified_carbon_kyc_verdict):</text>
  <text x="460" y="386" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7">Atualiza kyc_status e recalcula Reputation Trust Score.</text>

  <line x1="600" y1="324" x2="620" y2="324" stroke="#4C1D95" stroke-width="2" marker-end="url(#kycArr)"/>

  <!-- Stage 6: Silent Duress PIN & Forensic Protection -->
  <rect x="624" y="240" width="280" height="168" rx="6" fill="#FEF2F2" stroke="#DC2626" stroke-width="1.5"/>
  <rect x="624" y="240" width="280" height="24" rx="6" fill="#991B1B"/>
  <text x="764" y="256" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">ESTÁGIO 6 — COFRE ANTI-COAÇÃO (DURESS PIN)</text>
  <text x="634" y="276" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Isolamento de Segredos (private.job_forensic_secrets):</text>
  <text x="640" y="288" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Hashes de PIN e job_presence_secret banidos de</text>
  <text x="640" y="299" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">public.jobs ([SEC-02] / [SEC-05]). Sorteio proíbe</text>
  <text x="640" y="310" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">PINs palíndromos (ex.: 1221 jamais é gerado).</text>
  <text x="634" y="325" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Protocolo Silent Duress PIN (Coação Física):</text>
  <text x="640" y="337" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Inserção invertida (4819 &rarr; 9184) exibe sucesso</text>
  <text x="640" y="348" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">visual normal na tela para proteger a vítima.</text>
  <rect x="634" y="358" width="260" height="38" rx="4" fill="#FEE2E2" stroke="#FCA5A5" stroke-width="1"/>
  <text x="764" y="373" text-anchor="middle" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="800">Ação Silenciosa: Estado FROZEN_UNDER_DURESS</text>
  <text x="764" y="386" text-anchor="middle" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="7">Bloqueia saque PIX imediatamente e preserva rastro forense.</text>
</svg>
`;

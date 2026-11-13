// ============================================================================
// DIAGRAMAS VETORIAIS CIENTÍFICOS SVG — CAPÍTULOS 2, 3 E 4 (NEGÓCIOS, LEAN E PBB)
// Projeto Desperrengue (v2.11.0) — Padronização Editorial A4 de Alta Densidade
// ============================================================================

export const svgPesquisaPublicoAlvo = String.raw`
<div class="svg-diagram-box" id="fig-02">
  <svg viewBox="0 0 920 430" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Painel Estatístico Comparativo da Pesquisa Empírica Bilateral (N=46: n1=28 Moradores e n2=18 Prestadores)">
    <defs>
      <linearGradient id="empHeaderGrad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="55%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <linearGradient id="barOrange" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#EA580C"/>
        <stop offset="100%" stop-color="#FF8F52"/>
      </linearGradient>
      <linearGradient id="barBlue" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#1D4ED8"/>
        <stop offset="100%" stop-color="#60A5FA"/>
      </linearGradient>
      <linearGradient id="barGreen" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#059669"/>
        <stop offset="100%" stop-color="#34D399"/>
      </linearGradient>
      <linearGradient id="barRed" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#B91C1C"/>
        <stop offset="100%" stop-color="#F87171"/>
      </linearGradient>
    </defs>

    <!-- Background Frame -->
    <rect x="0" y="0" width="920" height="430" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="38" rx="8" fill="url(#empHeaderGrad)"/>
    <rect x="0" y="28" width="920" height="10" fill="url(#empHeaderGrad)"/>
    <text x="460" y="24" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="11.5" font-weight="800" letter-spacing="0.8">PAINEL ESTATÍSTICO EMPÍRICO BILATERAL (AMOSTRA AUDITADA N = 46 &bull; IC 95% WILSON)</text>

    <!-- LEFT PANEL: MORADORES (n1 = 28) -->
    <rect x="14" y="48" width="440" height="368" rx="6" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="1.2"/>
    <rect x="14" y="48" width="440" height="28" rx="6" fill="#FFF7ED"/>
    <line x1="14" y1="76" x2="454" y2="76" stroke="#FDBA74" stroke-width="1.2"/>
    <circle cx="28" cy="62" r="5" fill="#EA580C"/>
    <text x="40" y="66" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="10.2" font-weight="800">ESTRATO DEMANDA — MORADORES URBANOS (n₁ = 28 | 60,9%)</text>

    <!-- Donut Chart: Canais de Descoberta -->
    <text x="95" y="95" text-anchor="middle" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="700">Canais Atuais de Busca</text>
    <!-- Donut base circle r=38, C=238.76 -->
    <circle cx="95" cy="148" r="38" fill="none" stroke="#E2E8F0" stroke-width="14"/>
    <!-- 78.6% Boca a boca = 187.7 -->
    <circle cx="95" cy="148" r="38" fill="none" stroke="#EA580C" stroke-width="14" stroke-dasharray="187.7 238.8" transform="rotate(-90 95 148)"/>
    <!-- 17.9% WhatsApp = 42.7, offset -187.7 -->
    <circle cx="95" cy="148" r="38" fill="none" stroke="#F59E0B" stroke-width="14" stroke-dasharray="42.7 238.8" stroke-dashoffset="-187.7" transform="rotate(-90 95 148)"/>
    <!-- 3.6% Apps = 8.4, offset -230.4 -->
    <circle cx="95" cy="148" r="38" fill="none" stroke="#64748B" stroke-width="14" stroke-dasharray="8.4 238.8" stroke-dashoffset="-230.4" transform="rotate(-90 95 148)"/>
    <text x="95" y="146" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="12" font-weight="800">96,4%</text>
    <text x="95" y="158" text-anchor="middle" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">INFORMAL</text>

    <!-- Legend for Donut -->
    <rect x="155" y="108" width="9" height="9" rx="2" fill="#EA580C"/>
    <text x="169" y="116" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="700">78,6% Indicação Boca a Boca (22/28)</text>
    <text x="169" y="126" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Dependência de vizinhos, porteiros e familiares</text>

    <rect x="155" y="136" width="9" height="9" rx="2" fill="#F59E0B"/>
    <text x="169" y="144" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="700">17,9% Grupos de Condomínio/WhatsApp (5/28)</text>
    <text x="169" y="154" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Sem triagem criminal, fiscal ou garantia pós-obra</text>

    <rect x="155" y="164" width="9" height="9" rx="2" fill="#64748B"/>
    <text x="169" y="172" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="700">3,6% Plataformas Digitais Legadas (1/28)</text>
    <text x="169" y="182" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Baixíssima penetração por atrito e desconfiança</text>

    <line x1="26" y1="198" x2="442" y2="198" stroke="#E2E8F0" stroke-width="1"/>
    <text x="26" y="214" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">Fricções Críticas e Adesão à Proposta (Moradores n₁ = 28)</text>

    <!-- Horizontal Bars Left -->
    <!-- Bar 1: 92.9% Aprovação Custódia + Garantia -->
    <text x="26" y="232" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Exigem Custódia PIX + Garantia 90d (26/28)</text>
    <rect x="215" y="223" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="223" width="171.8" height="11" rx="3" fill="url(#barGreen)"/>
    <text x="405" y="232" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">92,9%</text>

    <!-- Bar 2: 60.7% Receio de estranhos -->
    <text x="26" y="256" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Receio de Estranhos no Domicílio (17/28)</text>
    <rect x="215" y="247" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="247" width="112.3" height="11" rx="3" fill="url(#barOrange)"/>
    <text x="405" y="256" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">60,7%</text>

    <!-- Bar 3: 57.1% Faxina e Conservação -->
    <text x="26" y="280" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Demanda Recorrente: Limpeza/Diarista (16/28)</text>
    <rect x="215" y="271" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="271" width="105.6" height="11" rx="3" fill="url(#barOrange)"/>
    <text x="405" y="280" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">57,1%</text>

    <!-- Bar 4: 53.6% Ausência de garantia pós-serviço -->
    <text x="26" y="304" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Sem Amparo Pós-Serviço / Retrabalho (15/28)</text>
    <rect x="215" y="295" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="295" width="99.2" height="11" rx="3" fill="url(#barOrange)"/>
    <text x="405" y="304" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">53,6%</text>

    <!-- Bar 5: 46.4% Opacidade de preços e peças -->
    <text x="26" y="328" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Opacidade de Preço e Sobrepreço Peças (13/28)</text>
    <rect x="215" y="319" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="319" width="85.8" height="11" rx="3" fill="url(#barOrange)"/>
    <text x="405" y="328" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">46,4%</text>

    <!-- Bar 6: 39.3% Reparos Técnicos & Atrasos -->
    <text x="26" y="352" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Reparos Elétricos/Hidráulicos e Atrasos (11/28)</text>
    <rect x="215" y="343" width="185" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="215" y="343" width="72.7" height="11" rx="3" fill="url(#barOrange)"/>
    <text x="405" y="352" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">39,3%</text>

    <!-- Callout Box Left -->
    <rect x="26" y="366" width="416" height="38" rx="5" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1"/>
    <text x="36" y="381" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">SÍNTESE DO MORADOR:</text>
    <text x="136" y="381" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8">O mercado opera por confiança vicária analógica (96,4%). A adoção digital exige</text>
    <text x="36" y="394" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8">KYC governamental prévio, ocultação de endereço (Geo-Privacy Lock) e custódia vinculada à entrega.</text>

    <!-- RIGHT PANEL: PRESTADORES (n2 = 18) -->
    <rect x="466" y="48" width="440" height="368" rx="6" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="1.2"/>
    <rect x="466" y="48" width="440" height="28" rx="6" fill="#EFF6FF"/>
    <line x1="466" y1="76" x2="906" y2="76" stroke="#93C5FD" stroke-width="1.2"/>
    <circle cx="480" cy="62" r="5" fill="#1D4ED8"/>
    <text x="492" y="66" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="10.2" font-weight="800">ESTRATO OFERTA — PRESTADORES E MEIs (n₂ = 18 | 39,1%)</text>

    <!-- Donut Chart: Dependência de Renda -->
    <text x="547" y="95" text-anchor="middle" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="700">Composição de Renda</text>
    <circle cx="547" cy="148" r="38" fill="none" stroke="#E2E8F0" stroke-width="14"/>
    <!-- 55.6% Renda Principal = 132.8 -->
    <circle cx="547" cy="148" r="38" fill="none" stroke="#1D4ED8" stroke-width="14" stroke-dasharray="132.8 238.8" transform="rotate(-90 547 148)"/>
    <!-- 44.4% Renda Complementar = 106.0 -->
    <circle cx="547" cy="148" r="38" fill="none" stroke="#38BDF8" stroke-width="14" stroke-dasharray="106.0 238.8" stroke-dashoffset="-132.8" transform="rotate(-90 547 148)"/>
    <text x="547" y="146" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="12" font-weight="800">100%</text>
    <text x="547" y="158" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">ANTI-MOEDAS</text>

    <!-- Legend Right Donut -->
    <rect x="607" y="108" width="9" height="9" rx="2" fill="#1D4ED8"/>
    <text x="621" y="116" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="700">55,6% Renda Principal Familiar (10/18)</text>
    <text x="621" y="126" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Profissionais em tempo integral dependentes de fluxo</text>

    <rect x="607" y="136" width="9" height="9" rx="2" fill="#38BDF8"/>
    <text x="621" y="144" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="700">44,4% Renda Complementar Técnica (8/18)</text>
    <text x="621" y="154" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Atuação em janelas flexíveis e emergências (SOS)</text>

    <rect x="607" y="164" width="9" height="9" rx="2" fill="#B91C1C"/>
    <text x="621" y="172" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">100,0% Rejeitam Compra de Leads (18/18)</text>
    <text x="621" y="182" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Recusa unânime ao pedágio especulativo pré-pago</text>

    <line x1="478" y1="198" x2="894" y2="198" stroke="#E2E8F0" stroke-width="1"/>
    <text x="478" y="214" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">Perdas Econômicas e Validação de Solução (Prestadores n₂ = 18)</text>

    <!-- Horizontal Bars Right -->
    <!-- Bar 1: 100% Rejeição venda de leads -->
    <text x="478" y="232" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Rejeitam Pagar por Moedas/Desbloqueio (18/18)</text>
    <rect x="669" y="223" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="223" width="180" height="11" rx="3" fill="url(#barRed)"/>
    <text x="854" y="232" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">100,0%</text>

    <!-- Bar 2: 94.4% Adesão ao Smart Split + Escrow -->
    <text x="478" y="256" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Aprovam Taxa 0% Peças + Smart Escrow (17/18)</text>
    <rect x="669" y="247" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="247" width="169.9" height="11" rx="3" fill="url(#barGreen)"/>
    <text x="854" y="256" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">94,4%</text>

    <!-- Bar 3: 55.6% Clientes Fantasmas -->
    <text x="478" y="280" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Prejuízo com "Clientes Fantasmas" (10/18)</text>
    <rect x="669" y="271" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="271" width="100.1" height="11" rx="3" fill="url(#barBlue)"/>
    <text x="854" y="280" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">55,6%</text>

    <!-- Bar 4: 55.6% Renda Principal -->
    <text x="478" y="304" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Atividade como Fonte Principal (10/18)</text>
    <rect x="669" y="295" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="295" width="100.1" height="11" rx="3" fill="url(#barBlue)"/>
    <text x="854" y="304" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">55,6%</text>

    <!-- Bar 5: 22.2% Calote / Inadimplência -->
    <text x="478" y="328" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Vitimizados por Calote / Inadimplência (4/18)</text>
    <rect x="669" y="319" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="319" width="40.0" height="11" rx="3" fill="url(#barBlue)"/>
    <text x="854" y="328" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">22,2%</text>

    <!-- Bar 6: 16.7% Bitributação sobre peças -->
    <text x="478" y="352" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="600">Penalizados por Comissão sobre Peças (3/18)</text>
    <rect x="669" y="343" width="180" height="11" rx="3" fill="#F1F5F9"/>
    <rect x="669" y="343" width="30.1" height="11" rx="3" fill="url(#barBlue)"/>
    <text x="854" y="352" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">16,7%</text>

    <!-- Callout Box Right -->
    <rect x="478" y="366" width="416" height="38" rx="5" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
    <text x="488" y="381" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">SÍNTESE DO PRESTADOR:</text>
    <text x="598" y="381" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8">O modelo de cobrança por anúncio expulsa os melhores técnicos (100%). A isenção</text>
    <text x="488" y="394" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8">de 0% em materiais fiscais (Smart Split) + custódia pré-aprovisionada conquista 94,4% de adesão.</text>
  </svg>
  <div class="svg-caption">Figura 2.1 — Painel Estatístico Comparativo da Pesquisa Empírica Bilateral (N = 46: n₁ = 28 Moradores Demandantes vs. n₂ = 18 Prestadores Técnicos e MEIs).</div>
</div>
`;

export const svgMapaEmpatiaCliente = String.raw`
<div class="svg-diagram-box" id="fig-03">
  <svg viewBox="0 0 920 460" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Mapa de Empatia de 6 Quadrantes da Persona Cliente Morador Urbano">
    <defs>
      <linearGradient id="empCliHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#7C2D12"/>
        <stop offset="50%" stop-color="#EA580C"/>
        <stop offset="100%" stop-color="#7C2D12"/>
      </linearGradient>
    </defs>

    <rect x="0" y="0" width="920" height="460" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#empCliHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#empCliHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="11" font-weight="800" letter-spacing="0.7">MAPA DE EMPATIA DE 6 QUADRANTES — PERSONA PRIMÁRIA DE DEMANDA: MARIANA (MORADORA URBANA)</text>

    <!-- Top Quadrant 1: O QUE PENSA E SENTE (Full Width Top or Top-Center) -->
    <!-- Layout: 2x2 around central persona + 2 bottom quadrants (Dores & Ganhos) = 6 quadrants with zero overlap -->
    <!-- Q1: Top-Left: O QUE PENSA E SENTE -->
    <rect x="14" y="46" width="356" height="132" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="14" y="46" width="356" height="23" rx="6" fill="#FFF7ED"/>
    <text x="24" y="61" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">1. O QUE PENSA E SENTE? (COGNIÇÃO E AFETO)</text>
    <text x="24" y="80" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Será seguro abrir a porta do meu apartamento para um desconhecido?"</text>
    <text x="24" y="95" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Não entendo de elétrica ou hidráulica; tenho receio de pagar caro por peça barata."</text>
    <text x="24" y="110" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Se o conserto voltar a vazar amanhã, o técnico vai me bloquear no WhatsApp."</text>
    <text x="24" y="125" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Sensação de vulnerabilidade patrimonial e fadiga mental ao gerenciar imprevistos.</text>
    <text x="24" y="140" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Evidência: 60,7% receio domiciliar | 46,4% opacidade de peças | 53,6% sem garantia</text>

    <!-- Q2: Top-Right: O QUE VÊ -->
    <rect x="550" y="46" width="356" height="132" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="550" y="46" width="356" height="23" rx="6" fill="#FFF7ED"/>
    <text x="560" y="61" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">2. O QUE VÊ? (AMBIENTE E ESTÍMULOS VISUAIS)</text>
    <text x="560" y="80" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Grupos de WhatsApp do prédio cheios de pedidos urgentes sem resposta confiável.</text>
    <text x="560" y="95" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Infiltração, disjuntor desarmando ou necessidade recorrente de diarista de confiança.</text>
    <text x="560" y="110" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Orçamentos informais rabiscados ou mensagens vagas sem discriminar material.</text>
    <text x="560" y="125" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Apps tradicionais que parecem diretórios telefônicos sem responsabilidade solidária.</text>
    <text x="560" y="140" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Evidência: 96,4% dependem de canais informais (78,6% indicação + 17,9% grupos)</text>

    <!--Q3: Middle-Left: O QUE OUVE -->
    <rect x="14" y="188" width="356" height="126" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="14" y="188" width="356" height="23" rx="6" fill="#FFF7ED"/>
    <text x="24" y="203" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">3. O QUE OUVE? (INFLUÊNCIAS E RELATOS SOCIAIS)</text>
    <text x="24" y="222" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Vizinhos relatando: "Paguei 50% adiantado via PIX e o prestador nunca mais apareceu."</text>
    <text x="24" y="237" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Porteiros dizendo: "Aquele eletricista bom está com agenda lotada até o mês que vem."</text>
    <text x="24" y="252" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Imobiliárias exigindo comprovantes formais de manutenção na vistoria de saída.</text>
    <text x="24" y="267" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Noticiários alertando sobre golpes digitais e riscos de expor endereço residencial.</text>
    <text x="24" y="282" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Reflexo: Retração de consumo e adiamento de manutenções preventivas</text>

    <!-- Q4: Middle-Right: O QUE FALA E FAZ -->
    <rect x="550" y="188" width="356" height="126" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="550" y="188" width="356" height="23" rx="6" fill="#FFF7ED"/>
    <text x="560" y="203" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">4. O QUE FALA E FAZ? (COMPORTAMENTO OBSERVÁVEL)</text>
    <text x="560" y="222" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Pede 3 indicações antes de chamar alguém; tenta agendar quando não está sozinha.</text>
    <text x="560" y="237" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Grava áudios explicando o defeito e manda fotos do local pelo celular em busca de ajuda.</text>
    <text x="560" y="252" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Pergunta se o valor inclui peças e pede nota fiscal da loja de material de construção.</text>
    <text x="560" y="267" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Contrata limpeza com frequência mensal/quinzenal (57,1%) e reparos sob demanda (39,3%).</text>
    <text x="560" y="282" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Reflexo UX: Abertura por voz &lt; 60s + fotos sanitizadas EXIF + Smart Split</text>

    <!-- CENTER NODE: PERSONA AVATAR & PROFILE -->
    <rect x="380" y="76" width="160" height="208" rx="10" fill="#0F172A" stroke="#FF8F52" stroke-width="2"/>
    <circle cx="460" cy="122" r="28" fill="#1E293B" stroke="#FF8F52" stroke-width="2"/>
    <!-- Vector User Icon -->
    <circle cx="460" cy="114" r="9" fill="#FF8F52"/>
    <path d="M 443 138 C 443 127, 477 127, 477 138" fill="#FF8F52"/>
    <text x="460" y="166" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10" font-weight="800">MARIANA, 34 ANOS</text>
    <text x="460" y="179" text-anchor="middle" fill="#FDBA74" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">Moradora Contratante</text>
    <line x1="396" y1="188" x2="524" y2="188" stroke="#334155" stroke-width="1"/>
    <text x="460" y="203" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Apartamento Urbano</text>
    <text x="460" y="216" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Rotina Híbrida Intensa</text>
    <text x="460" y="229" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Usuária Intensiva PIX</text>
    <rect x="394" y="242" width="132" height="28" rx="5" fill="#1E293B" stroke="#F59E0B" stroke-width="1"/>
    <text x="460" y="254" text-anchor="middle" fill="#FDE68A" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="700">PRIORIDADE MÁXIMA:</text>
    <text x="460" y="265" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Segurança + Garantia 90d</text>

    <!-- Connector Lines from Persona to Quadrants -->
    <line x1="380" y1="115" x2="370" y2="115" stroke="#FF8F52" stroke-width="1.5"/>
    <line x1="540" y1="115" x2="550" y2="115" stroke="#FF8F52" stroke-width="1.5"/>
    <line x1="380" y1="245" x2="370" y2="245" stroke="#FF8F52" stroke-width="1.5"/>
    <line x1="540" y1="245" x2="550" y2="245" stroke="#FF8F52" stroke-width="1.5"/>
    <line x1="430" y1="284" x2="430" y2="324" stroke="#EF4444" stroke-width="1.5"/>
    <line x1="490" y1="284" x2="490" y2="324" stroke="#10B981" stroke-width="1.5"/>

    <!-- Q5: Bottom-Left: DORES (FRUSTRAÇÕES E OBSTÁCULOS) -->
    <rect x="14" y="324" width="438" height="122" rx="6" fill="#FEF2F2" stroke="#FCA5A5" stroke-width="1.3"/>
    <rect x="14" y="324" width="438" height="23" rx="6" fill="#FEE2E2"/>
    <text x="24" y="339" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">5. DORES — MEDOS, FRUSTRAÇÕES E RISCOS PERCEBIDOS</text>
    <text x="24" y="358" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Exposição prematura do endereço exato e número do apartamento a estranhos (60,7%).</text>
    <text x="24" y="373" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Risco Moral pós-pagamento: pagar adiantado e sofrer abandono ou execução defeituosa (53,6%).</text>
    <text x="24" y="388" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Assimetria informacional sobre peças: cobrança inflacionada sem nota fiscal de origem (46,4%).</text>
    <text x="24" y="403" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Atrasos crônicos sem rastreamento em tempo real (39,3%) e perda de comprovantes do imóvel.</text>
    <text x="24" y="418" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.7" font-weight="700">Impacto Econômico: Seleção Adversa de Akerlof e subconsumo de manutenção preventiva.</text>

    <!-- Q6: Bottom-Right: GANHOS (NECESSIDADES E CRITÉRIOS DE SUCESSO) -->
    <rect x="468" y="324" width="438" height="122" rx="6" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1.3"/>
    <rect x="468" y="324" width="438" height="23" rx="6" fill="#D1FAE5"/>
    <text x="478" y="339" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">6. GANHOS — DESEJOS, NECESSIDADES E MÉTRICAS DE SUCESSO</text>
    <text x="478" y="358" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Identidade civil verificada via VIO/ICP-Brasil + endereço oculto até as 00:00 do dia agendado.</text>
    <text x="478" y="373" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Custódia Smart Escrow PIX liberada apenas mediante PIN presencial de 4 dígitos (92,9% aprovação).</text>
    <text x="478" y="388" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Orçamento transparente separando Mão de Obra e Materiais com NF-e auditada (Smart Split).</text>
    <text x="478" y="403" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Garantia real de 90 dias em 3 camadas caucionada pelo Fundo Garantidor Mutualista (1,5%).</text>
    <text x="478" y="418" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.7" font-weight="700">Entregável Patrimonial: Passaporte Predial PDF vetorial segundo a ABNT NBR 5674:2012.</text>
  </svg>
  <div class="svg-caption">Figura 2.2 — Mapa de Empatia Completo de 6 Quadrantes da Persona Primária de Demanda (Morador Contratante Urbano — n₁ = 28).</div>
</div>
`;

export const svgMapaEmpatiaProfissional = String.raw`
<div class="svg-diagram-box" id="fig-04">
  <svg viewBox="0 0 920 460" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Mapa de Empatia de 6 Quadrantes da Persona Profissional Prestador Técnico e MEI">
    <defs>
      <linearGradient id="empProHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#1D4ED8"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
    </defs>

    <rect x="0" y="0" width="920" height="460" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#empProHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#empProHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="11" font-weight="800" letter-spacing="0.7">MAPA DE EMPATIA DE 6 QUADRANTES — PERSONA PRIMÁRIA DE OFERTA: CARLOS EDUARDO (TÉCNICO MEI)</text>

    <!-- Q1: Top-Left: O QUE PENSA E SENTE -->
    <rect x="14" y="46" width="356" height="132" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="14" y="46" width="356" height="23" rx="6" fill="#EFF6FF"/>
    <text x="24" y="61" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">1. O QUE PENSA E SENTE? (COGNIÇÃO E DIGNIDADE TÉCNICA)</text>
    <text x="24" y="80" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "É injusto pagar R$ 15 a R$ 40 em moedas só para ver o telefone de um curioso."</text>
    <text x="24" y="95" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Quando compro R$ 300 de peça do meu bolso, o app não pode cobrar comissão sobre ela."</text>
    <text x="24" y="110" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Trabalho direito, tenho cursos e ferramentas caras, mas sou nivelado por baixo por amadores."</text>
    <text x="24" y="125" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Ansiedade financeira por ociosidade de agenda e temor de inadimplência ao fim do serviço.</text>
    <text x="24" y="140" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Evidência: 100,0% rejeitam venda de leads | 55,6% têm a atividade como renda principal</text>

    <!-- Q2: Top-Right: O QUE VÊ -->
    <rect x="550" y="46" width="356" height="132" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="550" y="46" width="356" height="23" rx="6" fill="#EFF6FF"/>
    <text x="560" y="61" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">2. O QUE VÊ? (MERCADO E PLATAFORMAS LEGADAS)</text>
    <text x="560" y="80" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Aplicativos legados vendendo o mesmo pedido para 4 ou 5 profissionais simultaneamente.</text>
    <text x="560" y="95" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; Chamados vagos ("tomada com problema") que exigem deslocamento cego no trânsito urbano.</text>
    <text x="560" y="110" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Guerra predatória de preços promovida por perfis sem certificação técnica ou CNPJ/MEI.</text>
    <text x="560" y="125" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Custos crescentes de combustível e insumos elétricos/hidráulicos no varejo especializado.</text>
    <text x="560" y="140" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Evidência: 55,6% já perderam dinheiro e combustível com "clientes fantasmas"</text>

    <!-- Q3: Middle-Left: O QUE OUVE -->
    <rect x="14" y="188" width="356" height="126" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="14" y="188" width="356" height="23" rx="6" fill="#EFF6FF"/>
    <text x="24" y="203" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">3. O QUE OUVE? (PARES DE OFÍCIO E CLIENTES)</text>
    <text x="24" y="222" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Colegas de profissão dizendo: "Gastei R$ 200 em moedas naquele app e não fechei nenhum."</text>
    <text x="24" y="237" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Clientes pedindo desconto à vista ou dizendo "depois te faço o PIX" ao término do serviço.</text>
    <text x="24" y="252" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Lojistas recomendando emitir NF-e separada para não confundir material com serviço (LC 116).</text>
    <text x="24" y="267" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Familiares cobrando previsibilidade de receita semanal para sustento da casa.</text>
    <text x="24" y="282" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Evidência: 22,2% sofreram calote direto | 16,7% penalizados por comissão em peças</text>

    <!-- Q4: Middle-Right: O QUE FALA E FAZ -->
    <rect x="550" y="188" width="356" height="126" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="550" y="188" width="356" height="23" rx="6" fill="#EFF6FF"/>
    <text x="560" y="203" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">4. O QUE FALA E FAZ? (PRÁTICA PROFISSIONAL DIÁRIA)</text>
    <text x="560" y="222" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Fotografa o quadro elétrico/tubulação antes e depois para provar a qualidade do serviço.</text>
    <text x="560" y="237" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Prefere atender chamados em um raio logístico otimizado ao redor da sua base operacional.</text>
    <text x="560" y="252" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Separa claramente quanto custa sua mão de obra e quanto custa o material na loja.</text>
    <text x="560" y="267" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Atende urgências noturnas/finais de semana (SOS) quando há garantia de pagamento líquido.</text>
    <text x="560" y="282" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">Reflexo UX: Radar O(log N + K) + Orçamento grátis + Portfólio sincronizado</text>

    <!-- CENTER NODE: PERSONA AVATAR & PROFILE -->
    <rect x="380" y="76" width="160" height="208" rx="10" fill="#0F172A" stroke="#74A7FF" stroke-width="2"/>
    <circle cx="460" cy="122" r="28" fill="#1E293B" stroke="#74A7FF" stroke-width="2"/>
    <!-- Vector Pro Icon -->
    <circle cx="460" cy="114" r="9" fill="#74A7FF"/>
    <path d="M 443 138 C 443 127, 477 127, 477 138" fill="#74A7FF"/>
    <text x="460" y="166" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">CARLOS EDUARDO, 38</text>
    <text x="460" y="179" text-anchor="middle" fill="#93C5FD" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">Eletricista &amp; Hidráulico MEI</text>
    <line x1="396" y1="188" x2="524" y2="188" stroke="#334155" stroke-width="1"/>
    <text x="460" y="203" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">12 Anos de Experiência</text>
    <text x="460" y="216" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Certificado NR-10 / CNH VIO</text>
    <text x="460" y="229" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Renda Principal (55,6%)</text>
    <rect x="394" y="242" width="132" height="28" rx="5" fill="#1E293B" stroke="#38BDF8" stroke-width="1"/>
    <text x="460" y="254" text-anchor="middle" fill="#BAE6FD" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="700">PRIORIDADE MÁXIMA:</text>
    <text x="460" y="265" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Zero Moedas + 0% Peças</text>

    <!-- Connector Lines -->
    <line x1="380" y1="115" x2="370" y2="115" stroke="#74A7FF" stroke-width="1.5"/>
    <line x1="540" y1="115" x2="550" y2="115" stroke="#74A7FF" stroke-width="1.5"/>
    <line x1="380" y1="245" x2="370" y2="245" stroke="#74A7FF" stroke-width="1.5"/>
    <line x1="540" y1="245" x2="550" y2="245" stroke="#74A7FF" stroke-width="1.5"/>
    <line x1="430" y1="284" x2="430" y2="324" stroke="#EF4444" stroke-width="1.5"/>
    <line x1="490" y1="284" x2="490" y2="324" stroke="#10B981" stroke-width="1.5"/>

    <!-- Q5: Bottom-Left: DORES -->
    <rect x="14" y="324" width="438" height="122" rx="6" fill="#FEF2F2" stroke="#FCA5A5" stroke-width="1.3"/>
    <rect x="14" y="324" width="438" height="23" rx="6" fill="#FEE2E2"/>
    <text x="24" y="339" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">5. DORES — EXPROPRIAÇÃO DE MARGEM E RISCO OPERACIONAL</text>
    <text x="24" y="358" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Pedágio especulativo de compra antecipada de moedas/créditos sem garantia de fechamento (100%).</text>
    <text x="24" y="373" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; "Clientes fantasmas" que solicitam orçamento e abandonam o contato após gerar custo (55,6%).</text>
    <text x="24" y="388" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Inadimplência, retenção arbitrária ou pechincha forçada após o serviço já concluído (22,2%).</text>
    <text x="24" y="403" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Confisco de comissão (15%–25%) sobre o reembolso de peças compradas pelo técnico (16,7%).</text>
    <text x="24" y="418" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.7" font-weight="700">Consequência: Êxodo dos melhores profissionais para fora dos apps legados.</text>

    <!-- Q6: Bottom-Right: GANHOS -->
    <rect x="468" y="324" width="438" height="122" rx="6" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1.3"/>
    <rect x="468" y="324" width="438" height="23" rx="6" fill="#D1FAE5"/>
    <text x="478" y="339" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="9.5" font-weight="800">6. GANHOS — LIQUIDEZ GARANTIDA, JUSTIÇA FISCAL E MÉRITO</text>
    <text x="478" y="358" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Envio gratuito de orçamentos (R$ 0,00 em moedas): taxa incide exclusivamente no sucesso.</text>
    <text x="478" y="373" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Smart Split: 0,0% de comissão sobre materiais comprovados por NF-e (100% de reembolso).</text>
    <text x="478" y="388" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Pagamento já depositado em Smart Escrow PIX antes de sair de casa, liberado por PIN de 4 dígitos.</text>
    <text x="478" y="403" fill="#064E3B" font-family="Inter, Segoe UI, sans-serif" font-size="8.1">&bull; Meritocracia técnica: 90 medalhas profissionais, vitrine de portfólio e liquidação rápida D+0/D+2.</text>
    <text x="478" y="418" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.7" font-weight="700">Validação Empírica: 94,4% (17/18) de intenção imediata de migração para o Desperrengue.</text>
  </svg>
  <div class="svg-caption">Figura 2.3 — Mapa de Empatia Completo de 6 Quadrantes da Persona Primária de Oferta (Prestador Técnico Autônomo / MEI — n₂ = 18).</div>
</div>
`;

export const svgValuePropositionCanvas = String.raw`
<div class="svg-diagram-box" id="fig-05">
  <svg viewBox="0 0 920 435" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Value Proposition Canvas Bilateral do Ecossistema Desperrengue">
    <defs>
      <linearGradient id="vpcHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#047857"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <marker id="vpcArrowL" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#10B981"/>
      </marker>
      <marker id="vpcArrowR" viewBox="0 0 10 10" refX="2" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M 10 1 L 0 5 L 10 9 z" fill="#10B981"/>
      </marker>
    </defs>

    <rect x="0" y="0" width="920" height="435" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#vpcHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#vpcHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="11" font-weight="800" letter-spacing="0.7">VALUE PROPOSITION CANVAS (OSTERWALDER) — ENCAIXE ESTRATÉGICO BILATERAL (PROBLEM-SOLUTION FIT)</text>

    <!-- LEFT SIDE: MAPA DE VALOR (SQUARE) -->
    <rect x="16" y="48" width="414" height="372" rx="8" fill="#FFFFFF" stroke="#059669" stroke-width="2"/>
    <rect x="16" y="48" width="414" height="26" rx="8" fill="#059669"/>
    <text x="223" y="65" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10" font-weight="800">MAPA DE VALOR (ARQUITETURA DO PRODUTO v2.11.0)</text>

    <!-- Sub-box 1: Produtos e Serviços -->
    <rect x="26" y="84" width="394" height="104" rx="6" fill="#F0FDF4" stroke="#86EFAC" stroke-width="1.2"/>
    <text x="36" y="100" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">A. PRODUTOS E SERVIÇOS (PLATAFORMA DUAL-MODE)</text>
    <text x="36" y="116" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Smart Escrow PIX BIGINT:</tspan> Custódia contábil soma-zero + PIN presencial de 4 dígitos.</text>
    <text x="36" y="130" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Smart Split Assimétrico:</tspan> 15% Mão de Obra (13,5% + 1,5%) e 0,0% em Peças c/ NF-e.</text>
    <text x="36" y="144" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Motor KYC Zero-Trust:</tspan> Tier-0 Isolate + Argon High + QR VIO ICP-Brasil + SERPRO mTLS.</text>
    <text x="36" y="158" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Temporal &amp; Spatial Geo-Privacy Lock:</tspan> Raio HMAC 500m–800m até 00:00 do dia agendado.</text>
    <text x="36" y="172" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Garantia 90d (3 Camadas):</tspan> Retorno 48h &rarr; Perícia Forense &rarr; Fundo Garantidor (1,5%).</text>

    <!-- Sub-box 2: Criadores de Ganho -->
    <rect x="26" y="196" width="394" height="106" rx="6" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1.2"/>
    <text x="36" y="212" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">B. CRIADORES DE GANHO (GAIN CREATORS)</text>
    <text x="36" y="228" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Abertura por Voz (&lt; 60s):</tspan> Ditado natural + triagem automática nas 33 categorias Duotone.</text>
    <text x="36" y="242" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Passaporte Predial ABNT NBR 5674:</tspan> Exportação PDF vetorial com selo SHA-256.</text>
    <text x="36" y="256" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Orçamento 100% Gratuito:</tspan> Zero compra de moedas; maturação rápida D+0/D+2 por RTS.</text>
    <text x="36" y="270" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Gamificação Meritocrática:</tspan> 112 medalhas (90 Pro + 22 Cliente) e vitrine pública verificada.</text>
    <text x="36" y="284" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Engenharia 120 FPS:</tspan> Cache L1 InstantCachedImage (0 ms) e mapa ao vivo com 80% livre.</text>

    <!-- Sub-box 3: Aliviadores de Dor -->
    <rect x="26" y="310" width="394" height="100" rx="6" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1.2"/>
    <text x="36" y="326" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">C. ALIVIADORES DE DOR (PAIN RELIEVERS)</text>
    <text x="36" y="342" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Imunidade à Triangulação:</tspan> Ofuscação HMAC-SHA256 + remoção 100% de EXIF GPS.</text>
    <text x="36" y="356" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Cofre Dual Anti-Coação:</tspan> Silent Duress PIN (reverso congela saque sem alertar agressor).</text>
    <text x="36" y="370" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Fim do "Cliente Fantasma":</tspan> Deslocamento técnico apenas com custódia PIX já confirmada.</text>
    <text x="36" y="384" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Auditoria SEFAZ (&gt;26h):</tspan> Validação de NF-e de 44 dígitos + clawback contra fraude fiscal.</text>
    <text x="36" y="398" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Portabilidade LGPD Fail-Closed:</tspan> Dossiê PDF entregue por e-mail antes do expurgo.</text>

    <!-- CENTER FIT BADGE & ARROWS -->
    <line x1="432" y1="136" x2="488" y2="136" stroke="#10B981" stroke-width="2.2" marker-start="url(#vpcArrowR)" marker-end="url(#vpcArrowL)"/>
    <line x1="432" y1="248" x2="488" y2="248" stroke="#10B981" stroke-width="2.2" marker-start="url(#vpcArrowR)" marker-end="url(#vpcArrowL)"/>
    <line x1="432" y1="360" x2="488" y2="360" stroke="#10B981" stroke-width="2.2" marker-start="url(#vpcArrowR)" marker-end="url(#vpcArrowL)"/>

    <circle cx="460" cy="248" r="24" fill="#0F172A" stroke="#10B981" stroke-width="2.5"/>
    <text x="460" y="245" text-anchor="middle" fill="#34D399" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">FIT</text>
    <text x="460" y="256" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7" font-weight="700">92,9% / 94,4%</text>

    <!-- RIGHT SIDE: PERFIL DO CLIENTE E PRESTADOR (CIRCLE / SEGMENTED BOX) -->
    <rect x="490" y="48" width="414" height="372" rx="8" fill="#FFFFFF" stroke="#1E3A8A" stroke-width="2"/>
    <rect x="490" y="48" width="414" height="26" rx="8" fill="#1E3A8A"/>
    <text x="697" y="65" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10" font-weight="800">PERFIL BILATERAL DE CLIENTES (MORADOR + PRESTADOR)</text>

    <!-- Sub-box 4: Tarefas do Cliente (Jobs-to-be-Done) -->
    <rect x="500" y="84" width="394" height="104" rx="6" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.2"/>
    <text x="510" y="100" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">1. TAREFAS DO CLIENTE (JOBS-TO-BE-DONE)</text>
    <text x="510" y="116" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">[Morador Funcional]:</tspan> Resolver reparos (39,3%) e limpeza recorrente (57,1%) com rapidez.</text>
    <text x="510" y="130" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">[Morador Social/Emocional]:</tspan> Proteger a família em casa e comprovar zelo predial (NBR 5674).</text>
    <text x="510" y="144" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">[Prestador Funcional]:</tspan> Captar ordens próximas na sua especialidade sem custo especulativo.</text>
    <text x="510" y="158" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">[Prestador Financeiro]:</tspan> Receber à vista pelo trabalho e recompor 100% do capital de peças.</text>
    <text x="510" y="172" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">[Ambos]:</tspan> Transacionar com previsibilidade jurídica (CDC Art. 26 e LGPD Art. 18/20).</text>

    <!-- Sub-box 5: Ganhos Esperados -->
    <rect x="500" y="196" width="394" height="106" rx="6" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1.2"/>
    <text x="510" y="212" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">2. GANHOS ESPERADOS (CUSTOMER GAINS)</text>
    <text x="510" y="228" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Triagem sem Esforço:</tspan> Descrever o defeito falando normalmente sem saber o termo técnico.</text>
    <text x="510" y="242" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Valorização Patrimonial:</tspan> Histórico auditável das intervenções feitas no imóvel.</text>
    <text x="510" y="256" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Margem Líquida Justa:</tspan> Preservação de 85% da mão de obra e 100% do valor dos materiais.</text>
    <text x="510" y="270" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Reputação Portável:</tspan> Reconhecimento objetivo por assiduidade, rapidez SOS e nota 5 estrelas.</text>
    <text x="510" y="284" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Visibilidade em Tempo Real:</tspan> Acompanhar o deslocamento do técnico no dia da execução.</text>

    <!-- Sub-box 6: Dores Empíricas -->
    <rect x="500" y="310" width="394" height="100" rx="6" fill="#FEF2F2" stroke="#FCA5A5" stroke-width="1.2"/>
    <text x="510" y="326" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">3. DORES SEVERAS (CUSTOMER PAINS — N = 46)</text>
    <text x="510" y="342" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Vulnerabilidade Residencial (60,7%):</tspan> Medo de abrir a casa a estranhos não auditados.</text>
    <text x="510" y="356" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Risco de Calote e Abandono (53,6% / 22,2%):</tspan> Desconfiança mútua no pagamento direto.</text>
    <text x="510" y="370" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Pedágio de Leads (100% rejeição) e Clientes Fantasmas (55,6%):</tspan> Prejuízo pré-serviço.</text>
    <text x="510" y="384" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Sobrepreço e Bitributação em Peças (46,4% / 16,7%):</tspan> Distorção fiscal em insumos.</text>
    <text x="510" y="398" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">&bull; <tspan font-weight="700">Informalidade Analógica (96,4%):</tspan> Lentidão de indicações boca a boca e grupos de condomínio.</text>
  </svg>
  <div class="svg-caption">Figura 2.4 — Value Proposition Canvas (Osterwalder et al., 2014) demonstrando a correspondência bijetora entre o Perfil Bilateral (Morador + Prestador) e o Mapa de Valor do Desperrengue (v2.11.0).</div>
</div>
`;

export const svgTamSamSom = String.raw`
<div class="svg-diagram-box" id="fig-06">
  <svg viewBox="0 0 920 390" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Dimensionamento de Mercado TAM SAM SOM e Rampa Operacional do Desperrengue">
    <defs>
      <linearGradient id="tamHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <radialGradient id="tamCircleGrad" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="#DBEAFE"/>
        <stop offset="100%" stop-color="#BFDBFE"/>
      </radialGradient>
      <radialGradient id="samCircleGrad" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="#60A5FA"/>
        <stop offset="100%" stop-color="#2563EB"/>
      </radialGradient>
      <radialGradient id="somCircleGrad" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="#F97316"/>
        <stop offset="100%" stop-color="#C2410C"/>
      </radialGradient>
    </defs>

    <rect x="0" y="0" width="920" height="390" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="36" rx="8" fill="url(#tamHdr)"/>
    <rect x="0" y="26" width="920" height="10" fill="url(#tamHdr)"/>
    <text x="460" y="23" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="11" font-weight="800" letter-spacing="0.7">DIMENSIONAMENTO ECONÔMICO DE MERCADO (TAM &bull; SAM &bull; SOM) E RAMPA DE ESCALA (v2.11.0)</text>

    <!-- LEFT: CONCENTRIC CIRCLES (Anchored at Bottom-Center cx=215) -->
    <!-- TAM Circle -->
    <circle cx="205" cy="215" r="152" fill="url(#tamCircleGrad)" stroke="#1D4ED8" stroke-width="2"/>
    <text x="205" y="88" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="10" font-weight="800">TAM — MERCADO TOTAL</text>
    <text x="205" y="106" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="14" font-weight="900">R$ 142,80 Bilhões / ano</text>
    <text x="205" y="120" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="600">42,0M domicílios urbanos &times; R$ 3.400/ano</text>

    <!-- SAM Circle -->
    <circle cx="205" cy="248" r="118" fill="url(#samCircleGrad)" stroke="#1E3A8A" stroke-width="2"/>
    <text x="205" y="176" text-anchor="middle" fill="#EFF6FF" font-family="Inter, Segoe UI, sans-serif" font-size="9.2" font-weight="800">SAM — MERCADO DISPONÍVEL</text>
    <text x="205" y="193" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="13" font-weight="900">R$ 38,40 Bilhões / ano</text>
    <text x="205" y="207" text-anchor="middle" fill="#DBEAFE" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="600">19,2M lares PIX &times; 6,25 OS &times; R$ 320</text>

    <!-- SOM Circle -->
    <circle cx="205" cy="296" r="64" fill="url(#somCircleGrad)" stroke="#FFFFFF" stroke-width="2.5"/>
    <text x="205" y="276" text-anchor="middle" fill="#FFF7ED" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">SOM (36 MESES)</text>
    <text x="205" y="294" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="12" font-weight="900">R$ 45,60 Mi</text>
    <text x="205" y="308" text-anchor="middle" fill="#FFEDD5" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">GMV Anualizado</text>
    <text x="205" y="320" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">142,5 mil OS/ano</text>

    <!-- RIGHT: ANALYTICAL CARDS & UNIT ECONOMICS -->
    <!-- Card 1: TAM -->
    <rect x="382" y="52" width="522" height="76" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="382" y="52" width="8" height="76" rx="4" fill="#60A5FA"/>
    <text x="402" y="70" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.8" font-weight="800">1. TAM (Total Addressable Market) — R$ 142,80 Bilhões/ano (IBGE PNAD / SindusCon)</text>
    <text x="402" y="86" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Base Demográfica: <tspan font-weight="700">72,5 milhões</tspan> de domicílios particulares permanentes no Brasil (<tspan font-weight="700">42,0 milhões</tspan> urbanos ativos em manutenção).</text>
    <text x="402" y="100" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Dispêndio Médio Anual: <tspan font-weight="700">R$ 3.400,00/domicílio/ano</tspan> somando conservação recorrente (limpeza/diarista) e reparos técnicos prediais.</text>
    <text x="402" y="114" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">Equação: TAM = 42.000.000 domicílios &times; R$ 3.400,00/ano = R$ 142,80 Bilhões/ano.</text>

    <!-- Card 2: SAM -->
    <rect x="382" y="138" width="522" height="76" rx="6" fill="#FFFFFF" stroke="#3B82F6" stroke-width="1.3"/>
    <rect x="382" y="138" width="8" height="76" rx="4" fill="#2563EB"/>
    <text x="402" y="156" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="9.8" font-weight="800">2. SAM (Serviceable Available Market) — R$ 38,40 Bilhões/ano (33 Categorias Digitais PIX)</text>
    <text x="402" y="172" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Recorte Tecnológico e Urbano: <tspan font-weight="700">19,2 milhões</tspan> de domicílios em centros urbanos médios/grandes com bancarização PIX e smartphone.</text>
    <text x="402" y="186" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Frequência e Ticket Combinado: <tspan font-weight="700">6,25 ordens/ano</tspan> por lar &times; ticket médio global <tspan font-weight="700">R$ 320,00</tspan> (R$ 220,00 Mão de Obra + R$ 100,00 Peças).</text>
    <text x="402" y="200" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">Equação: SAM = 19.200.000 lares &times; R$ 2.000,00/ano = R$ 38,40 Bilhões/ano (Receita Plataforma 13,5% MO = R$ 3,56 Bi/ano).</text>

    <!-- Card 3: SOM & Rampa Ano 1 -->
    <rect x="382" y="224" width="522" height="82" rx="6" fill="#FFF7ED" stroke="#F97316" stroke-width="1.4"/>
    <rect x="382" y="224" width="8" height="82" rx="4" fill="#EA580C"/>
    <text x="402" y="242" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="9.8" font-weight="800">3. SOM (Serviceable Obtainable Market — Horizonte 36 Meses) — R$ 45,60 Milhões/ano GMV</text>
    <text x="402" y="258" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Captura Alvo em 36 Meses (0,119% do SAM): <tspan font-weight="700">142.500 OS/ano</tspan> a R$ 320,00 (ou 120.000 OS técnicas a R$ 380,00) = <tspan font-weight="700">R$ 45,60 Mi GMV</tspan>.</text>
    <text x="402" y="272" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="8.2">&bull; Receita Líquida Plataforma no SOM (13,5% sobre MO): <tspan font-weight="700">R$ 4,23 Milhões/ano</tspan> (+ R$ 470,25 mil/ano alocados ao Fundo Garantidor 1,5%).</text>
    <text x="402" y="286" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">&bull; Rampa Lean Ano 1 (Polo Inicial): 1.445 OS acumuladas | GMV R$ 260.100,00 | Receita Líquida R$ 26.322,30 | Superávit R$ 17.503,56.</text>
    <text x="402" y="299" fill="#64748B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">Break-Even Operacional atingido já no Mês 3 com apenas 40 OS/mês (Custo fixo enxuto R$ 635,96/mês).</text>

    <!-- Bottom KPI Strip -->
    <rect x="382" y="316" width="124" height="58" rx="6" fill="#0F172A"/>
    <text x="444" y="335" text-anchor="middle" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">RELAÇÃO LTV / CAC</text>
    <text x="444" y="354" text-anchor="middle" fill="#34D399" font-family="Inter, Segoe UI, sans-serif" font-size="14" font-weight="900">9,65x</text>
    <text x="444" y="367" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7">R$ 233,57 / R$ 24,20</text>

    <rect x="514" y="316" width="124" height="58" rx="6" fill="#0F172A"/>
    <text x="576" y="335" text-anchor="middle" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">CAC PAYBACK</text>
    <text x="576" y="354" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="14" font-weight="900">1,2 OS</text>
    <text x="576" y="367" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7">&lt; 45 dias corridos</text>

    <rect x="646" y="316" width="124" height="58" rx="6" fill="#0F172A"/>
    <text x="708" y="335" text-anchor="middle" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">BREAK-EVEN PONTO</text>
    <text x="708" y="354" text-anchor="middle" fill="#FBBF24" font-family="Inter, Segoe UI, sans-serif" font-size="14" font-weight="900">40 OS/mês</text>
    <text x="708" y="367" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7">Atingido no Mês 3</text>

    <rect x="778" y="316" width="126" height="58" rx="6" fill="#0F172A"/>
    <text x="841" y="335" text-anchor="middle" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">CUSTO CLOUD / OS</text>
    <text x="841" y="354" text-anchor="middle" fill="#F472B6" font-family="Inter, Segoe UI, sans-serif" font-size="14" font-weight="900">R$ 0,034</text>
    <text x="841" y="367" text-anchor="middle" fill="#CBD5E1" font-family="Inter, Segoe UI, sans-serif" font-size="7">KYC Tier-0 a R$ 0,00</text>
  </svg>
  <div class="svg-caption">Figura 2.5 — Dimensionamento Econômico Concêntrico de Mercado (TAM, SAM e SOM) e Indicadores Auditados de Unit Economics do Desperrengue (v2.11.0).</div>
</div>
`;

export const svgBusinessModelCanvas = String.raw`
<div class="svg-diagram-box" id="fig-07">
  <svg viewBox="0 0 920 490" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Quadro Completo dos 9 Blocos do Business Model Canvas do Desperrengue">
    <defs>
      <linearGradient id="bmcHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
    </defs>

    <rect x="0" y="0" width="920" height="490" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#bmcHdr)"/>
    <rect x="0" y="24" width="920" height="10" fill="url(#bmcHdr)"/>
    <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.8" font-weight="800" letter-spacing="0.7">BUSINESS MODEL CANVAS (9 BLOCOS DE OSTERWALDER) — ECOSSISTEMA DESPERRENGUE (v2.11.0)</text>

    <!-- Macro Pillars Strip (COMO | O QUE | PARA QUEM) -->
    <rect x="12" y="40" width="354" height="18" rx="3" fill="#DBEAFE"/>
    <text x="189" y="52" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">EIXO I — COMO? (INFRAESTRUTURA E OPERAÇÃO)</text>

    <rect x="372" y="40" width="176" height="18" rx="3" fill="#DCFCE7"/>
    <text x="460" y="52" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">EIXO II — O QUÊ? (VALOR)</text>

    <rect x="554" y="40" width="354" height="18" rx="3" fill="#FFEDD5"/>
    <text x="731" y="52" text-anchor="middle" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">EIXO III — PARA QUEM? (MERCADO E CLIENTES)</text>

    <!-- BLOCK 8: PARCERIAS PRINCIPAIS (Left Full Height of Top 2 Rows) -->
    <rect x="12" y="62" width="174" height="276" rx="5" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="12" y="62" width="174" height="22" rx="5" fill="#EFF6FF"/>
    <text x="20" y="76" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">8. PARCERIAS-CHAVE</text>
    <text x="20" y="94" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">&bull; Autoridades Certificadoras:</text>
    <text x="24" y="106" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">SERPRO Datavalid (mTLS 1.3)</text>
    <text x="24" y="117" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">e Cadeia VIO / ICP-Brasil.</text>
    <text x="20" y="133" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">&bull; Liquidação e Fiscal:</text>
    <text x="24" y="145" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">PSP PIX (Arranjo BACEN) e</text>
    <text x="24" y="156" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Webservices SEFAZ (NF-e).</text>
    <text x="20" y="172" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">&bull; Cloud &amp; Inteligência:</text>
    <text x="24" y="184" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Supabase (PostgreSQL 17 /</text>
    <text x="24" y="195" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Edge), Gemini 4 Argon High.</text>
    <text x="20" y="211" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">&bull; Cartografia e E-mail:</text>
    <text x="24" y="223" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">OSRM / OpenStreetMap e</text>
    <text x="24" y="234" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Resend (Dossiê LGPD PDF).</text>
    <text x="20" y="250" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="700">&bull; Ecossistema Urbano:</text>
    <text x="24" y="262" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Condomínios, administradoras,</text>
    <text x="24" y="273" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">imobiliárias e escolas técnicas.</text>

    <!-- BLOCK 7: ATIVIDADES-CHAVE (Top-Middle-Left) -->
    <rect x="192" y="62" width="174" height="135" rx="5" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="192" y="62" width="174" height="22" rx="5" fill="#EFF6FF"/>
    <text x="200" y="76" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">7. ATIVIDADES-CHAVE</text>
    <text x="200" y="93" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Orquestração do Smart Escrow PIX</text>
    <text x="204" y="104" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">e Smart Split (0% em materiais).</text>
    <text x="200" y="118" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Verificação KYC Zero-Trust em 6</text>
    <text x="204" y="129" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">estágios e auditoria SEFAZ &gt;26h.</text>
    <text x="200" y="143" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Proteção Geo-Privacy Lock (00:00)</text>
    <text x="204" y="154" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">e sanitização EXIF/GPS on-device.</text>
    <text x="200" y="168" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Governança das 3 camadas de</text>
    <text x="204" y="179" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">garantia (90d) e releases OTA.</text>

    <!-- BLOCK 6: RECURSOS PRINCIPAIS (Bottom-Middle-Left) -->
    <rect x="192" y="203" width="174" height="135" rx="5" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="192" y="203" width="174" height="22" rx="5" fill="#EFF6FF"/>
    <text x="200" y="217" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">6. RECURSOS PRINCIPAIS</text>
    <text x="200" y="234" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; App Flutter 120 FPS (Quiet Luxury</text>
    <text x="204" y="245" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Dark Mode) + Cache L1 0 ms.</text>
    <text x="200" y="259" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; 27 Migrações SQL ACID BIGINT,</text>
    <text x="204" y="270" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">RLS estrito e locks R1&lt;R2&lt;R3&lt;R4.</text>
    <text x="200" y="284" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Microsserviço Python FastAPI</text>
    <text x="204" y="295" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">kyc_engine + Cofre WORM KWV2.</text>
    <text x="200" y="309" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Livro-razão warranty_pool_ledger</text>
    <text x="204" y="320" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">(Fundo Garantidor Mutualista 1,5%).</text>

    <!-- BLOCK 1: PROPOSTA DE VALOR (Center Full Height) -->
    <rect x="372" y="62" width="176" height="276" rx="5" fill="#F0FDF4" stroke="#10B981" stroke-width="1.8"/>
    <rect x="372" y="62" width="176" height="22" rx="5" fill="#059669"/>
    <text x="460" y="76" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">1. PROPOSTA DE VALOR</text>
    <text x="380" y="94" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Para o Morador Urbano:</text>
    <text x="380" y="106" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Contratação Normal ou SOS por</text>
    <text x="384" y="116" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">voz em &lt;60s nas 33 categorias.</text>
    <text x="380" y="128" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Técnicos auditados (VIO/SERPRO)</text>
    <text x="384" y="138" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">+ endereço oculto até 00:00 SP.</text>
    <text x="380" y="150" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Custódia PIX liberada por PIN de</text>
    <text x="384" y="160" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">4 dígitos + Garantia real 90 dias.</text>
    <text x="380" y="172" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Passaporte Predial ABNT NBR 5674.</text>

    <line x1="382" y1="182" x2="538" y2="182" stroke="#86EFAC" stroke-width="1"/>
    <text x="380" y="196" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Para o Prestador / MEI:</text>
    <text x="380" y="208" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Zero compra de moedas/leads:</text>
    <text x="384" y="218" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">envio de orçamentos 100% grátis.</text>
    <text x="380" y="230" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Smart Split: 0,0% de comissão</text>
    <text x="384" y="240" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">sobre peças com NF-e (100% repasse).</text>
    <text x="380" y="252" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Fim dos "clientes fantasmas" e</text>
    <text x="384" y="262" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">calotes (valor já em Smart Escrow).</text>
    <text x="380" y="274" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; 90 medalhas + saque D+0/D+2.</text>

    <!-- BLOCK 4: RELACIONAMENTO COM CLIENTES (Top-Middle-Right) -->
    <rect x="554" y="62" width="174" height="135" rx="5" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="554" y="62" width="174" height="22" rx="5" fill="#FFF7ED"/>
    <text x="562" y="76" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">4. RELACIONAMENTO</text>
    <text x="562" y="93" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Confiança Institucional Automatizada</text>
    <text x="566" y="104" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">(Reputation Trust Score — RTS).</text>
    <text x="562" y="118" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Gamificação Bilateral (112 medalhas:</text>
    <text x="566" y="129" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">90 Profissional + 22 Cliente e streaks).</text>
    <text x="562" y="143" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Mediação pericial assistida nas 3</text>
    <text x="566" y="154" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">camadas de garantia (SLA 48h).</text>
    <text x="562" y="168" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Transparência LGPD (SHAP + Dossiê).</text>

    <!-- BLOCK 3: CANAIS (Bottom-Middle-Right) -->
    <rect x="554" y="203" width="174" height="135" rx="5" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="554" y="203" width="174" height="22" rx="5" fill="#FFF7ED"/>
    <text x="562" y="217" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">3. CANAIS DE DISTRIBUIÇÃO</text>
    <text x="562" y="234" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Aplicativo Android Nativo (com</text>
    <text x="566" y="245" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">atualização direta OTA verificada).</text>
    <text x="562" y="259" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Web App Progressivo (PWA Desktop</text>
    <text x="566" y="270" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&amp; Mobile responsivo 480px).</text>
    <text x="562" y="284" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Parcerias em condomínios (QR Code</text>
    <text x="566" y="295" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">em elevadores/portarias) e lojas.</text>
    <text x="562" y="309" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">&bull; Virality de Passaporte Predial PDF.</text>

    <!-- BLOCK 2: SEGMENTOS DE CLIENTES (Right Full Height) -->
    <rect x="734" y="62" width="174" height="276" rx="5" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="734" y="62" width="174" height="22" rx="5" fill="#FFF7ED"/>
    <text x="742" y="76" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">2. SEGMENTOS DE CLIENTES</text>
    <text x="742" y="94" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Lado A — Demanda (Moradores):</text>
    <text x="742" y="106" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Proprietários e inquilinos urbanos</text>
    <text x="746" y="116" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">que buscam segurança residencial.</text>
    <text x="742" y="128" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Contratantes de conservação</text>
    <text x="746" y="138" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">recorrente (57,1%) e reparos (39,3%).</text>
    <text x="742" y="150" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Síndicos e gestores patrimoniais.</text>

    <line x1="744" y1="164" x2="898" y2="164" stroke="#FDBA74" stroke-width="1"/>
    <text x="742" y="178" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">Lado B — Oferta (Prestadores):</text>
    <text x="742" y="190" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Técnicos autônomos e MEIs nas</text>
    <text x="746" y="200" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">33 categorias (Elétrica, Hidráulica,</text>
    <text x="746" y="210" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Climatização, Limpeza, Montagem...).</text>
    <text x="742" y="222" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">&bull; Profissionais de renda principal</text>
    <text x="746" y="232" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">(55,6%) e complementar (44,4%).</text>

    <line x1="744" y1="244" x2="898" y2="244" stroke="#CBD5E1" stroke-width="1"/>
    <text x="742" y="258" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">Conta Unificada Dual-Mode:</text>
    <text x="742" y="270" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Mesmo CPF alterna entre Cliente e</text>
    <text x="742" y="280" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">Profissional herdando o selo KYC.</text>

    <!-- EIXO IV HEADER: QUANTO? -->
    <rect x="12" y="344" width="896" height="18" rx="3" fill="#E2E8F0"/>
    <text x="460" y="356" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">EIXO IV — QUANTO? (ESTRUTURA DE CUSTOS OPERACIONAIS E FONTES DE RECEITA)</text>

    <!-- BLOCK 9: ESTRUTURA DE CUSTOS (Bottom-Left) -->
    <rect x="12" y="366" width="444" height="112" rx="5" fill="#FEF2F2" stroke="#FCA5A5" stroke-width="1.3"/>
    <rect x="12" y="366" width="444" height="22" rx="5" fill="#FEE2E2"/>
    <text x="22" y="380" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">9. ESTRUTURA DE CUSTOS (FINOPS SERVERLESS ENXUTO)</text>
    <text x="22" y="397" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">CAPEX Inicial de Implantação:</tspan> R$ 5.000,00 (Hardware de teste, certificado ICP-Brasil A1, domínio).</text>
    <text x="22" y="410" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">OPEX Fixo Mensal (Ano 1):</tspan> R$ 635,96/mês (Cloud Supabase/FastAPI, contabilidade e marketing orgânico).</text>
    <text x="22" y="423" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Custo Marginal Cloud:</tspan> R$ 0,034 por ordem/usuário ativo; Portão KYC Tier-0 em Isolate.run a R$ 0,00.</text>
    <text x="22" y="436" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Alocação Mutualista:</tspan> 1,5% de labor_cents segregado atomicamente no livro-razão warranty_pool_ledger.</text>
    <text x="22" y="449" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Break-Even Point: 40 OS/mês (atingido no Mês 3 da rampa operacional).</text>

    <!-- BLOCK 5: FONTES DE RECEITA (Bottom-Right) -->
    <rect x="464" y="366" width="444" height="112" rx="5" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1.3"/>
    <rect x="464" y="366" width="444" height="22" rx="5" fill="#D1FAE5"/>
    <text x="474" y="380" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">5. FONTES DE RECEITA (SMART SPLIT &amp; CPC 47 / LC 116)</text>
    <text x="474" y="397" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Take Rate sobre Mão de Obra (labor_cents):</tspan> 15,0% total = <tspan font-weight="700">13,5% Receita Líquida</tspan> + 1,5% Fundo Garantidor.</text>
    <text x="474" y="410" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Isenção sobre Materiais (materials_cents):</tspan> <tspan font-weight="700">0,0% de comissão</tspan> mediante NF-e válida de 44 dígitos (100% repasse).</text>
    <text x="474" y="423" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Taxa de Urgência (SOS):</tspan> Priorização algorítmica imediata com destravamento instantâneo de rota no aceite.</text>
    <text x="474" y="436" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6">&bull; <tspan font-weight="700">Antecipação Opcional (D+0):</tspan> Spread financeiro transparente para adiantamento de recebíveis em maturação.</text>
    <text x="474" y="449" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="700">&bull; Eficiência Fiscal: Tributação (Simples Nacional 6% / ISS) incide apenas sobre os 13,5% de intermediação.</text>
  </svg>
  <div class="svg-caption">Figura 3.1 — Business Model Canvas Completo (9 Blocos de Osterwalder &amp; Pigneur) do Ecossistema Desperrengue (v2.11.0).</div>
</div>
`;

export const svgFunilAarrrJornada = String.raw`
<div class="svg-diagram-box" id="fig-08">
  <svg viewBox="0 0 920 430" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Funil de Growth AARRR e Linha do Tempo da Jornada Bilateral do Cliente e Prestador">
    <defs>
      <linearGradient id="aarrrHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#3B82F6"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <marker id="jrnyArr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#2563EB"/>
      </marker>
    </defs>

    <rect x="0" y="0" width="920" height="430" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#aarrrHdr)"/>
    <rect x="0" y="24" width="920" height="10" fill="url(#aarrrHdr)"/>
    <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.8" font-weight="800" letter-spacing="0.7">FUNIL PIRATA AARRR (MCCLURE) E JORNADA SINCRONIZADA PONTA A PONTA (CLIENTE &harr; PRESTADOR)</text>

    <!-- LEFT PANEL: FUNIL AARRR (Trapezoids) -->
    <rect x="12" y="44" width="380" height="374" rx="6" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="1.2"/>
    <text x="202" y="64" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="9.8" font-weight="800">1. FUNIL DE GROWTH E MÉTRICAS PIRATAS (AARRR)</text>

    <!-- Stage 1: Acquisition -->
    <polygon points="18,76 386,76 378,128 26,128" fill="#1E3A8A"/>
    <text x="202" y="94" text-anchor="middle" fill="#93C5FD" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">1. AQUISIÇÃO (ACQUISITION) — CAC R$ 24,20</text>
    <text x="202" y="108" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">SEO Local ("SOS vazamento/eletricista"), QR Condomínios,</text>
    <text x="202" y="120" text-anchor="middle" fill="#DBEAFE" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Lojas de Materiais e Migração Anti-Moedas (94,4% Prestadores)</text>

    <!-- Stage 2: Activation -->
    <polygon points="28,134 376,134 368,186 36,186" fill="#1D4ED8"/>
    <text x="202" y="152" text-anchor="middle" fill="#BAE6FD" font-family="Inter, Segoe UI, sans-serif" font-size="8.2" font-weight="800">2. ATIVAÇÃO (ACTIVATION) — AHA! EM &lt; 60 SEGUNDOS</text>
    <text x="202" y="166" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Cliente: Chamado por Voz + Triagem 33 Categorias Duotone</text>
    <text x="202" y="178" text-anchor="middle" fill="#DBEAFE" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Prestador: KYC Zero-Trust aprovado + 1º Orçamento R$ 0,00</text>

    <!-- Stage 3: Retention -->
    <polygon points="38,192 366,192 358,244 46,244" fill="#2563EB"/>
    <text x="202" y="210" text-anchor="middle" fill="#FEF08A" font-family="Inter, Segoe UI, sans-serif" font-size="8.0" font-weight="800">3. RETENÇÃO (RETENTION) — HÁBITO E GAMIFICAÇÃO</text>
    <text x="202" y="224" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Âncora Recorrente de Limpeza (57,1%) + Garantia Ativa 90d</text>
    <text x="202" y="236" text-anchor="middle" fill="#DBEAFE" font-family="Inter, Segoe UI, sans-serif" font-size="7.2">112 Medalhas (#CBD5E1 &rarr; Ouro/Diamante) + Passaporte NBR 5674</text>

    <!-- Stage 4: Revenue -->
    <polygon points="48,250 356,250 348,302 56,302" fill="#059669"/>
    <text x="202" y="268" text-anchor="middle" fill="#A7F3D0" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">4. RECEITA (REVENUE) — LTV/CAC 9,65x | PAYBACK 1,2 OS</text>
    <text x="202" y="282" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Take Rate 13,5% Líquido sobre Mão de Obra (+1,5% Pool)</text>
    <text x="202" y="294" text-anchor="middle" fill="#D1FAE5" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">0,0% sobre Materiais c/ NF-e (Smart Split) + Taxa SOS</text>

    <!-- Stage 5: Referral -->
    <polygon points="58,308 346,308 338,360 66,360" fill="#EA580C"/>
    <text x="202" y="326" text-anchor="middle" fill="#FFEDD5" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">5. INDICAÇÃO (REFERRAL) — K-FACTOR VIRAL</text>
    <text x="202" y="340" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Compartilhamento no Condomínio + Portfólio Público</text>
    <text x="202" y="352" text-anchor="middle" fill="#FFEDD5" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Medalhas "Voz da Vizinhança" e "Embaixador"</text>

    <rect x="26" y="370" width="352" height="36" rx="5" fill="#F1F5F9" stroke="#CBD5E1" stroke-width="1"/>
    <text x="202" y="384" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">MOTOR FLYWHEEL BILATERAL:</text>
    <text x="202" y="397" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.4">Zero Moedas atrai os melhores Técnicos &rarr; Eleva Confiança &rarr; Atrai Moradores</text>

    <!-- RIGHT PANEL: JORNADA COMPLETA SINCRONIZADA (6 ETAPAS) -->
    <rect x="404" y="44" width="504" height="374" rx="6" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="1.2"/>
    <text x="656" y="64" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="9.8" font-weight="800">2. LINHA DO TEMPO DA JORNADA BILATERAL DE SERVIÇO (6 ESTÁGIOS)</text>

    <!-- Column Headers -->
    <rect x="416" y="74" width="142" height="20" rx="3" fill="#FFF7ED"/>
    <text x="487" y="87" text-anchor="middle" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">JORNADA DO MORADOR</text>

    <rect x="566" y="74" width="176" height="20" rx="3" fill="#0F172A"/>
    <text x="654" y="87" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">CAMADA ZERO-TRUST (SISTEMA)</text>

    <rect x="750" y="74" width="146" height="20" rx="3" fill="#EFF6FF"/>
    <text x="823" y="87" text-anchor="middle" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">JORNADA DO PRESTADOR</text>

    <!-- Row 1: T1 Abertura -->
    <rect x="416" y="100" width="142" height="44" rx="4" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1"/>
    <text x="422" y="114" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T1. Relato por Voz (&lt;60s)</text>
    <text x="422" y="125" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Dita problema + anexa foto;</text>
    <text x="422" y="135" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">escolhe Normal ou SOS.</text>

    <rect x="566" y="100" width="176" height="44" rx="4" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1"/>
    <text x="654" y="114" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">Strip EXIF + Geo-Lock PUBLIC_FUZZY</text>
    <text x="654" y="125" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Remove GPS da foto; gera círculo</text>
    <text x="654" y="135" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">HMAC 500m–800m (151m–349m offset).</text>

    <rect x="750" y="100" width="146" height="44" rx="4" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
    <text x="756" y="114" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T1. Radar O(log N + K)</text>
    <text x="756" y="125" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Vê apenas círculo aproximado</text>
    <text x="756" y="135" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">na sua categoria homologada.</text>

    <!-- Row 2: T2 Orçamento e Contratação -->
    <rect x="416" y="152" width="142" height="44" rx="4" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1"/>
    <text x="422" y="166" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T2. Aceite + Depósito PIX</text>
    <text x="422" y="177" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Compara RTS/portfólio e paga</text>
    <text x="422" y="187" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">PIX em custódia protegida.</text>

    <rect x="566" y="152" width="176" height="44" rx="4" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1"/>
    <text x="654" y="166" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">Smart Escrow + HIRED_PRE_DAY</text>
    <text x="654" y="177" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Retém labor + materials em BIGINT;</text>
    <text x="654" y="187" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">mantém endereço oculto até 00:00.</text>

    <rect x="750" y="152" width="146" height="44" rx="4" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
    <text x="756" y="166" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T2. Proposta Grátis (R$ 0)</text>
    <text x="756" y="177" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Envia orçamento bipartido sem</text>
    <text x="756" y="187" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">comprar moedas; agenda bloqueada.</text>

    <!-- Row 3: T3 Dia do Serviço (00:00 SP) -->
    <rect x="416" y="204" width="142" height="44" rx="4" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1"/>
    <text x="422" y="218" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T3. Radar Vivo (80% Mapa)</text>
    <text x="422" y="229" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Acompanha rota OSRM/C&infin; do</text>
    <text x="422" y="239" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">técnico até a chegada.</text>

    <rect x="566" y="204" width="176" height="44" rx="4" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1"/>
    <text x="654" y="218" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">SERVICE_DAY_UNLOCKED (00:00 SP)</text>
    <text x="654" y="229" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Destrava endereço exato só ao</text>
    <text x="654" y="239" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">contratado; valida Check-in HMAC.</text>

    <rect x="750" y="204" width="146" height="44" rx="4" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
    <text x="756" y="218" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T3. Deslocamento e Check-in</text>
    <text x="756" y="229" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Recebe endereço às 00:00; inicia</text>
    <text x="756" y="239" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">reparo com copresença verificada.</text>

    <!-- Row 4: T4 Execução e Smart Split NF-e -->
    <rect x="416" y="256" width="142" height="44" rx="4" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1"/>
    <text x="422" y="270" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T4. Conferência de Peças</text>
    <text x="422" y="281" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Visualiza NF-e auditada das</text>
    <text x="422" y="291" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">peças sem sobrepreço oculto.</text>

    <rect x="566" y="256" width="176" height="44" rx="4" fill="#F8FAFC" stroke="#94A3B8" stroke-width="1"/>
    <text x="654" y="270" text-anchor="middle" fill="#0F172A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">Validação NF-e 44d + Argon OCR</text>
    <text x="654" y="281" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Módulo 11 + CNPJ + isenção 0% em</text>
    <text x="654" y="291" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">materiais (+ auditoria SEFAZ &gt;26h).</text>

    <rect x="750" y="256" width="146" height="44" rx="4" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1"/>
    <text x="756" y="270" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T4. Upload NF-e e Fotos</text>
    <text x="756" y="281" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Captura nota fiscal de peças e</text>
    <text x="756" y="291" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">fotos finais antes/depois.</text>

    <!-- Row 5: T5 Checkout PIN 4 Dígitos -->
    <rect x="416" y="308" width="142" height="44" rx="4" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1"/>
    <text x="422" y="322" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T5. Informa PIN 4 Dígitos</text>
    <text x="422" y="333" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Aprova serviço presencialmente</text>
    <text x="422" y="343" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(ou usa PIN reverso anti-coação).</text>

    <rect x="566" y="308" width="176" height="44" rx="4" fill="#ECFDF5" stroke="#10B981" stroke-width="1.2"/>
    <text x="654" y="322" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">Liquidação Atômica + RELOCKED</text>
    <text x="654" y="333" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">85% MO + 100% Peças ao técnico;</text>
    <text x="654" y="343" text-anchor="middle" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">13,5% Plataforma; 1,5% Pool; re-ofusca.</text>

    <rect x="750" y="308" width="146" height="44" rx="4" fill="#ECFDF5" stroke="#6EE7B7" stroke-width="1"/>
    <text x="756" y="322" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.5" font-weight="800">T5. Recebível e Saque PIX</text>
    <text x="756" y="333" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Digita PIN; saldo entra em D+0/D+2</text>
    <text x="756" y="343" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">e atualiza RTS + 90 medalhas.</text>

    <!-- Row 6: T6 Pós-Serviço -->
    <rect x="416" y="360" width="480" height="46" rx="4" fill="#0F172A"/>
    <text x="656" y="376" text-anchor="middle" fill="#38BDF8" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">T6. PÓS-SERVIÇO: GARANTIA LEGAL 90 DIAS (3 CAMADAS) + PASSAPORTE PREDIAL ABNT NBR 5674</text>
    <text x="656" y="390" text-anchor="middle" fill="#E2E8F0" font-family="Inter, Segoe UI, sans-serif" font-size="7.3">Vigência automática CDC Art. 26 (C1 Retorno 48h &rarr; C2 Perícia Forense &rarr; C3 Cobertura Fundo 1,5%) + Emissão PDF SHA-256</text>
    <text x="656" y="401" text-anchor="middle" fill="#94A3B8" font-family="Inter, Segoe UI, sans-serif" font-size="7">Endereço permanece trancado em POST_COMPLETION_RELOCKED garantindo privacidade perpétua do domicílio.</text>
  </svg>
  <div class="svg-caption">Figura 3.2 — Funil de Marketing Digital AARRR (McClure) acoplado à Linha do Tempo Sincronizada da Jornada Bilateral (Morador, Motor Zero-Trust e Prestador).</div>
</div>
`;

export const svgPrototipacaoLeanCiclo = String.raw`
<div class="svg-diagram-box" id="fig-09">
  <svg viewBox="0 0 920 410" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Ciclo Lean Startup Construir Medir Aprender e as 4 Ferramentas Científicas de Validação">
    <defs>
      <linearGradient id="leanHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#4F46E5"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <marker id="leanArr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M 0 1 L 10 5 L 0 9 z" fill="#4F46E5"/>
      </marker>
    </defs>

    <rect x="0" y="0" width="920" height="410" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#leanHdr)"/>
    <rect x="0" y="24" width="920" height="10" fill="url(#leanHdr)"/>
    <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.8" font-weight="800" letter-spacing="0.7">METODOLOGIA LEAN STARTUP (RIES) — CICLO CONSTRUIR-MEDIR-APRENDER E 4 EXPERIMENTOS DE VALIDAÇÃO</text>

    <!-- TOP STRIP: CICLO FEEDBACK CONSTRUIR -> MEDIR -> APRENDER -->
    <rect x="16" y="44" width="888" height="62" rx="6" fill="#EEF2FF" stroke="#A5B4FC" stroke-width="1.2"/>
    
    <rect x="30" y="54" width="230" height="42" rx="5" fill="#1E1B4B"/>
    <text x="145" y="71" text-anchor="middle" fill="#A5B4FC" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">1. CONSTRUIR (BUILD — HIPÓTESES)</text>
    <text x="145" y="85" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Artefatos Mínimos Verificáveis (Low/Mid/Hi-Fi)</text>

    <line x1="264" y1="75" x2="336" y2="75" stroke="#4F46E5" stroke-width="2.2" marker-end="url(#leanArr)"/>
    <text x="300" y="68" text-anchor="middle" fill="#4338CA" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">Experimento</text>

    <rect x="342" y="54" width="236" height="42" rx="5" fill="#312E81"/>
    <text x="460" y="71" text-anchor="middle" fill="#C7D2FE" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">2. MEDIR (MEASURE — TELEMETRIA)</text>
    <text x="460" y="85" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Métricas Auditáveis (N=46, Tempo &lt;60s, Conversão)</text>

    <line x1="582" y1="75" x2="654" y2="75" stroke="#4F46E5" stroke-width="2.2" marker-end="url(#leanArr)"/>
    <text x="618" y="68" text-anchor="middle" fill="#4338CA" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="700">Dados Reais</text>

    <rect x="660" y="54" width="230" height="42" rx="5" fill="#065F46"/>
    <text x="775" y="71" text-anchor="middle" fill="#A7F3D0" font-family="Inter, Segoe UI, sans-serif" font-size="8.5" font-weight="800">3. APRENDER (LEARN — DECISÃO)</text>
    <text x="775" y="85" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="7.5">Perseverar ou Pivotar &rarr; Código v2.11.0</text>

    <!-- 4 LEAN VALIDATION TOOLS (2x2 GRID) -->
    <!-- Tool 1: Smoke Test -->
    <rect x="16" y="118" width="436" height="134" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.4"/>
    <rect x="16" y="118" width="436" height="24" rx="6" fill="#1D4ED8"/>
    <text x="26" y="134" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">FERRAMENTA 1 — SMOKE TEST (TESTE DE FUMAÇA E INTENÇÃO DE ADESÃO)</text>
    <text x="26" y="153" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Hipótese Testada:</tspan> Prestadores migram se houver 0% em peças e zero venda de moedas;</text>
    <text x="34" y="164" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">moradores contratam se houver custódia PIX e garantia de 90 dias.</text>
    <text x="26" y="179" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Execução Metodológica:</tspan> Apresentação de propostas de valor simuladas aos dois estratos</text>
    <text x="34" y="190" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">antes da codificação completa dos livros-razão contábeis.</text>
    <text x="26" y="205" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">&bull; Resultado Empírico Auditado:</text>
    <text x="34" y="217" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">92,9% (26/28) de aprovação entre moradores e 94,4% (17/18) entre prestadores (100% rejeitam</text>
    <text x="34" y="228" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">moedas). Validou a construção do Smart Escrow e do Smart Split em centavos BIGINT.</text>
    <rect x="352" y="198" width="88" height="22" rx="4" fill="#DCFCE7" stroke="#10B981" stroke-width="1"/>
    <text x="396" y="212" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">VALIDADO</text>

    <!-- Tool 2: Wizard of Oz -->
    <rect x="468" y="118" width="436" height="134" rx="6" fill="#FFFFFF" stroke="#C4B5FD" stroke-width="1.4"/>
    <rect x="468" y="118" width="436" height="24" rx="6" fill="#5B21B6"/>
    <text x="478" y="134" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">FERRAMENTA 2 — WIZARD OF OZ (MÁGICO DE OZ — TRIAGEM VOZ E OCR)</text>
    <text x="478" y="153" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Hipótese Testada:</tspan> Moradores sob estresse (ex.: vazamento SOS) preferem relatar o</text>
    <text x="486" y="164" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">problema por voz em linguagem natural em vez de preencher formulários extensos.</text>
    <text x="478" y="179" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Execução Metodológica:</tspan> Simulação assistida de interpretação de relatos falados e</text>
    <text x="486" y="190" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">conferência de notas fiscais para calibrar o dicionário semântico das 33 categorias.</text>
    <text x="478" y="205" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">&bull; Resultado Empírico e Automação no Código:</text>
    <text x="486" y="217" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">Redução do tempo de abertura para t &le; 50,4s (&lt; 60s). Automatizado em produção via</text>
    <text x="486" y="228" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">SmartTranscriptFormatter, SmartTriage e kyc-argon-vision-gate (temperature = 0.0).</text>
    <rect x="804" y="198" width="88" height="22" rx="4" fill="#DCFCE7" stroke="#10B981" stroke-width="1"/>
    <text x="848" y="212" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">AUTOMATIZADO</text>

    <!-- Tool 3: Concierge / Conserniage -->
    <rect x="16" y="264" width="436" height="134" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.4"/>
    <rect x="16" y="264" width="436" height="24" rx="6" fill="#C2410C"/>
    <text x="26" y="280" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">FERRAMENTA 3 — CONCIERGE (CONSERNIAGE — CUSTÓDIA E GARANTIA)</text>
    <text x="26" y="299" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Hipótese Testada:</tspan> A retenção até o PIN presencial e a garantia em 3 camadas eliminam</text>
    <text x="34" y="310" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">o Risco Moral sem travar a liquidez do técnico de boa-fé.</text>
    <text x="26" y="325" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Execução Metodológica:</tspan> Acompanhamento branco (passo a passo visível) do ciclo</text>
    <text x="34" y="336" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">de agendamento, ocultação de endereço pré-dia, check-in e liberação por PIN.</text>
    <text x="26" y="351" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">&bull; Resultado Empírico e Codificação SQL:</text>
    <text x="34" y="363" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">Revelou a necessidade de bloquear o endereço até 00:00 do dia agendado mesmo após aceite</text>
    <text x="34" y="374" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">(HIRED_PRE_DAY_LOCKED) e criar o Silent Duress PIN contra coação presencial.</text>
    <rect x="352" y="344" width="88" height="22" rx="4" fill="#DCFCE7" stroke="#10B981" stroke-width="1"/>
    <text x="396" y="358" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">SISTEMATIZADO</text>

    <!-- Tool 4: A/B Testing + Telemetria UX -->
    <rect x="468" y="264" width="436" height="134" rx="6" fill="#FFFFFF" stroke="#6EE7B7" stroke-width="1.4"/>
    <rect x="468" y="264" width="436" height="24" rx="6" fill="#047857"/>
    <text x="478" y="280" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="9" font-weight="800">FERRAMENTA 4 — TESTE A/B E TELEMETRIA DE INTERFACE (UX/UI)</text>
    <text x="478" y="299" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Hipótese Testada:</tspan> Contraste semântico de medalhas, cabeçalho de 2 andares e mapa</text>
    <text x="486" y="310" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">com 80% de área livre reduzem erro cognitivo e truncamento em telas de 320px.</text>
    <text x="478" y="325" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8"><tspan font-weight="700">&bull; Execução Metodológica:</tspan> Comparação A/B entre medalhas bloqueadas escuras vs. prata</text>
    <text x="486" y="336" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="8">clara (#CBD5E1), e cabeçalho de linha única vs. 2 andares em Detalhe do serviço.</text>
    <text x="478" y="351" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="700">&bull; Resultado Empírico e Padronização v2.11.0:</text>
    <text x="486" y="363" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">Eliminação de 100% dos truncamentos (textScaler 1.4x), reconhecimento das 112 medalhas em</text>
    <text x="486" y="374" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.8">&lt; 200ms (contraste 9,8:1 AAA) e fluidez cravada em 120 FPS (&le; 8,33ms/frame).</text>
    <rect x="804" y="344" width="88" height="22" rx="4" fill="#DCFCE7" stroke="#10B981" stroke-width="1"/>
    <text x="848" y="358" text-anchor="middle" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.8" font-weight="800">HOMOLOGADO</text>
  </svg>
  <div class="svg-caption">Figura 3.3 — Ciclo de Feedback Construir-Medir-Aprender (Lean Startup) e Matriz das 4 Ferramentas Científicas de Validação Aplicadas ao Desperrengue (v2.11.0).</div>
</div>
`;

export const svgPbbCanvas = String.raw`
<div class="svg-diagram-box" id="fig-11">
  <svg viewBox="0 0 920 455" width="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Product Backlog Building PBB Canvas Completo do Ecossistema Desperrengue v2.11.0">
    <defs>
      <linearGradient id="pbbHdr" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#0F172A"/>
        <stop offset="50%" stop-color="#1E3A8A"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
    </defs>

    <rect x="0" y="0" width="920" height="455" rx="8" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
    <rect x="0" y="0" width="920" height="34" rx="8" fill="url(#pbbHdr)"/>
    <rect x="0" y="24" width="920" height="10" fill="url(#pbbHdr)"/>
    <text x="460" y="22" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="10.6" font-weight="800" letter-spacing="0.7">PRODUCT BACKLOG BUILDING (PBB CANVAS — AGUIAR) — RASTREABILIDADE DO PROBLEMA AOS PBIs (v2.11.0)</text>

    <!-- 5 COLUMNS OF PBB CANVAS -->
    <!-- COL 1: CONTEXTO & PROBLEMAS (x=10, w=174) -->
    <rect x="10" y="42" width="174" height="402" rx="6" fill="#FFFFFF" stroke="#FCA5A5" stroke-width="1.3"/>
    <rect x="10" y="42" width="174" height="26" rx="6" fill="#B91C1C"/>
    <text x="97" y="59" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">1. PROBLEMAS (N = 46)</text>

    <rect x="18" y="76" width="158" height="54" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="89" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P1. Informalidade Analógica</text>
    <text x="24" y="101" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">96,4% dependem de boca a boca</text>
    <text x="24" y="111" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(78,6%) ou grupos (17,9%) lentos</text>
    <text x="24" y="121" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">e sem filtro de antecedentes.</text>

    <rect x="18" y="136" width="158" height="54" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="149" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P2. Insegurança Domiciliar</text>
    <text x="24" y="161" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">60,7% temem abrir a residência</text>
    <text x="24" y="171" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">a desconhecidos ou vazar seu</text>
    <text x="24" y="181" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">endereço exato antes do serviço.</text>

    <rect x="18" y="196" width="158" height="54" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="209" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P3. Risco Moral e Calote</text>
    <text x="24" y="221" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">53,6% sem garantia pós-reparo;</text>
    <text x="24" y="231" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">22,2% dos técnicos sofreram</text>
    <text x="24" y="241" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">inadimplência direta.</text>

    <rect x="18" y="256" width="158" height="54" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="269" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P4. Pedágio de Moedas</text>
    <text x="24" y="281" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">100,0% dos técnicos rejeitam</text>
    <text x="24" y="291" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">pagar por anúncio; 55,6% têm</text>
    <text x="24" y="301" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">prejuízo com clientes fantasmas.</text>

    <rect x="18" y="316" width="158" height="54" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="329" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P5. Bitributação em Peças</text>
    <text x="24" y="341" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">46,4% opacidade no preço de</text>
    <text x="24" y="351" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">materiais; 16,7% confiscados</text>
    <text x="24" y="361" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">por taxa sobre peças.</text>

    <rect x="18" y="376" width="158" height="58" rx="4" fill="#FEF2F2" stroke="#FECACA" stroke-width="1"/>
    <text x="24" y="389" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">P6. Perda de Memória Predial</text>
    <text x="24" y="401" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Ausência de histórico técnico</text>
    <text x="24" y="411" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">auditável para vistoria (Lei</text>
    <text x="24" y="421" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">8.245/91 e ABNT NBR 5674).</text>

    <!-- COL 2: EXPECTATIVAS (x=191, w=174) -->
    <rect x="191" y="42" width="174" height="402" rx="6" fill="#FFFFFF" stroke="#FDBA74" stroke-width="1.3"/>
    <rect x="191" y="42" width="174" height="26" rx="6" fill="#D97706"/>
    <text x="278" y="59" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">2. EXPECTATIVAS (METAS)</text>

    <rect x="199" y="76" width="158" height="54" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="89" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E1. Abertura Voz &lt; 60s</text>
    <text x="205" y="101" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Triagem natural sem jargão nas</text>
    <text x="205" y="111" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">33 categorias (Normal ou SOS)</text>
    <text x="205" y="121" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">com fluidez a 120 FPS (8,33ms).</text>

    <rect x="199" y="136" width="158" height="54" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="149" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E2. Privacidade 00:00 SP</text>
    <text x="205" y="161" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Endereço oculto em raio HMAC</text>
    <text x="205" y="171" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">500m–800m até o dia do reparo</text>
    <text x="205" y="181" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">+ strip 100% de EXIF GPS.</text>

    <rect x="199" y="196" width="158" height="54" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="209" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E3. Custódia PIX + PIN 4d</text>
    <text x="205" y="221" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Liquidação atômica em centavos</text>
    <text x="205" y="231" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">BIGINT + Silent Duress PIN</text>
    <text x="205" y="241" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">contra extorsão presencial.</text>

    <rect x="199" y="256" width="158" height="54" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="269" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E4. Zero Moedas + 0% Peças</text>
    <text x="205" y="281" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Orçamento grátis; taxa 15% só</text>
    <text x="205" y="291" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">em mão de obra e 0% em peças</text>
    <text x="205" y="301" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">com NF-e auditada na SEFAZ.</text>

    <rect x="199" y="316" width="158" height="54" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="329" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E5. Garantia Real 90 Dias</text>
    <text x="205" y="341" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">3 camadas caucionadas por</text>
    <text x="205" y="351" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">1,5% no warranty_pool_ledger</text>
    <text x="205" y="361" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">com zero deadlocks SQL.</text>

    <rect x="199" y="376" width="158" height="58" rx="4" fill="#FFFBEB" stroke="#FDE68A" stroke-width="1"/>
    <text x="205" y="389" fill="#92400E" font-family="Inter, Segoe UI, sans-serif" font-size="7.6" font-weight="800">E6. Certificação e Mérito</text>
    <text x="205" y="401" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">KYC VIO/SERPRO + Passaporte</text>
    <text x="205" y="411" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">Predial NBR 5674 + 112 medalhas</text>
    <text x="205" y="421" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(bloqueadas em #CBD5E1).</text>

    <!-- COL 3: PERSONAS (x=373, w=174) -->
    <rect x="373" y="42" width="174" height="402" rx="6" fill="#FFFFFF" stroke="#A5B4FC" stroke-width="1.3"/>
    <rect x="373" y="42" width="174" height="26" rx="6" fill="#4338CA"/>
    <text x="460" y="59" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">3. PERSONAS E ATORES</text>

    <rect x="381" y="76" width="158" height="112" rx="5" fill="#FFF7ED" stroke="#FDBA74" stroke-width="1.2"/>
    <text x="389" y="92" fill="#9A3412" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">PERSONA 1 — MORADOR</text>
    <text x="389" y="104" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="700">Mariana (Contratante Urbana)</text>
    <text x="389" y="117" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Demanda limpeza (57,1%) e</text>
    <text x="393" y="127" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">reparos técnicos (39,3%).</text>
    <text x="389" y="139" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Exige sigilo de endereço até o</text>
    <text x="393" y="149" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">dia do serviço e nota de peças.</text>
    <text x="389" y="161" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Aciona acento visual #FF8F52</text>
    <text x="393" y="171" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">e conquista 22 medalhas Cliente.</text>

    <rect x="381" y="196" width="158" height="118" rx="5" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1.2"/>
    <text x="389" y="212" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">PERSONA 2 — PRESTADOR</text>
    <text x="389" y="224" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="700">Carlos Eduardo (Técnico / MEI)</text>
    <text x="389" y="237" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Atua em 1+ das 33 categorias</text>
    <text x="393" y="247" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">(55,6% como renda principal).</text>
    <text x="389" y="259" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Envia orçamento sem moedas;</text>
    <text x="393" y="269" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">separa mão de obra e peças NF-e.</text>
    <text x="389" y="281" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Aciona acento visual #74A7FF</text>
    <text x="393" y="291" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">e progride em 90 medalhas Pro.</text>

    <rect x="381" y="322" width="158" height="112" rx="5" fill="#F0FDF4" stroke="#86EFAC" stroke-width="1.2"/>
    <text x="389" y="338" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="8" font-weight="800">ATOR 3 — MOTOR ZERO-TRUST</text>
    <text x="389" y="350" fill="#1E293B" font-family="Inter, Segoe UI, sans-serif" font-size="7.3" font-weight="700">Governança Criptográfica &amp; Fiscal</text>
    <text x="389" y="363" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; kyc_engine (VIO ICP-Brasil +</text>
    <text x="393" y="373" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">SERPRO mTLS + Carbon SHAP).</text>
    <text x="389" y="385" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Worker SEFAZ pós-26h +</text>
    <text x="393" y="395" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">clawback automático de 15%.</text>
    <text x="389" y="407" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">&bull; Máquina Geo-Lock 4 fases e</text>
    <text x="393" y="417" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="7.1">perícia forense imutável.</text>

    <!-- COL 4: ÉPICOS / FEATURES (x=555, w=174) -->
    <rect x="555" y="42" width="174" height="402" rx="6" fill="#FFFFFF" stroke="#93C5FD" stroke-width="1.3"/>
    <rect x="555" y="42" width="174" height="26" rx="6" fill="#1D4ED8"/>
    <text x="642" y="59" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">4. ÉPICOS (10 FEATURES)</text>

    <rect x="563" y="75" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="88" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-01: Dual-Mode &amp; LGPD</text>
    <text x="569" y="99" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Conta única, herança KYC, Dossiê PDF</text>

    <rect x="563" y="111" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="124" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-02: Voz &lt;60s &amp; EXIF-Strip</text>
    <text x="569" y="135" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">33 categorias Duotone, SOS, sem GPS</text>

    <rect x="563" y="147" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="160" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-03: Radar &amp; Zero Moedas</text>
    <text x="569" y="171" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Busca O(log N+K), proposta grátis, RTS</text>

    <rect x="563" y="183" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="196" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-04: Smart Split (0% Peças)</text>
    <text x="569" y="207" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">NF-e 44 dígitos Mod 11 + SEFAZ &gt;26h</text>

    <rect x="563" y="219" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="232" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-05: Smart Escrow BIGINT</text>
    <text x="569" y="243" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Custódia PIX + Checkout PIN 4 dígitos</text>

    <rect x="563" y="255" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="268" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-06: Garantia 90d (3 Camadas)</text>
    <text x="569" y="279" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Retorno 48h, Perícia, Pool 1,5%</text>

    <rect x="563" y="291" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="304" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-07: KYC Zero-Trust &amp; Duress</text>
    <text x="569" y="315" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Tier-0, Argon, VIO, Carbon, PIN reverso</text>

    <rect x="563" y="327" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="340" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-08: Geo-Privacy Lock 00:00</text>
    <text x="569" y="351" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">HMAC-SHA256 500m–800m, 4 fases</text>

    <rect x="563" y="363" width="158" height="32" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="376" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-09: Passaporte NBR 5674</text>
    <text x="569" y="387" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">PDF vetorial SHA-256 + Mapa 80%</text>

    <rect x="563" y="399" width="158" height="35" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="569" y="412" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.4" font-weight="800">EP-10: 112 Medalhas &amp; OTA APK</text>
    <text x="569" y="423" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.9">Forja #CBD5E1 vs. Ligas + Release</text>

    <!-- COL 5: PRODUCT BACKLOG ITEMS (x=736, w=174) -->
    <rect x="736" y="42" width="174" height="402" rx="6" fill="#FFFFFF" stroke="#6EE7B7" stroke-width="1.3"/>
    <rect x="736" y="42" width="174" height="26" rx="6" fill="#059669"/>
    <text x="823" y="59" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Segoe UI, sans-serif" font-size="8.4" font-weight="800">5. PBIs PRIORIZADOS (WSJF)</text>

    <rect x="744" y="75" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="87" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 7,88] PBI-01</text>
    <text x="750" y="97" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Smart Escrow PIX + PIN 4 dígitos</text>

    <rect x="744" y="107" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="119" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 6,88] PBI-02</text>
    <text x="750" y="129" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Geo-Privacy Lock HMAC até 00:00 SP</text>

    <rect x="744" y="139" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="151" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 5,88] PBI-03</text>
    <text x="750" y="161" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Smart Split 0% Peças + NF-e Mod 11</text>

    <rect x="744" y="171" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="183" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 5,80] PBI-04 &amp; 05</text>
    <text x="750" y="193" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Strip EXIF GPS + Conta Dual-Mode</text>

    <rect x="744" y="203" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="215" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 5,25] PBI-06 &amp; 07</text>
    <text x="750" y="225" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Radar Sem Moedas + Silent Duress PIN</text>

    <rect x="744" y="235" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="247" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 4,88] PBI-08 &amp; 09</text>
    <text x="750" y="257" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Wizard Voz &lt;60s + Dossiê LGPD PDF</text>

    <rect x="744" y="267" width="158" height="28" rx="4" fill="#ECFDF5" stroke="#A7F3D0" stroke-width="1"/>
    <text x="750" y="279" fill="#065F46" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[MUST | WSJF 4,60] PBI-10..12</text>
    <text x="750" y="289" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">KYC VIO/SERPRO + Pool 1,5% + SEFAZ</text>

    <rect x="744" y="299" width="158" height="28" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="750" y="311" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[SHOULD | WSJF 4,20] PBI-13 &amp; 14</text>
    <text x="750" y="321" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">Passaporte NBR 5674 + Mapa Vivo 80%</text>

    <rect x="744" y="331" width="158" height="28" rx="4" fill="#EFF6FF" stroke="#BFDBFE" stroke-width="1"/>
    <text x="750" y="343" fill="#1E3A8A" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[SHOULD | WSJF 3,20] PBI-15</text>
    <text x="750" y="353" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">112 Medalhas (#CBD5E1 vs. Ligas)</text>

    <rect x="744" y="363" width="158" height="28" rx="4" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1"/>
    <text x="750" y="375" fill="#475569" font-family="Inter, Segoe UI, sans-serif" font-size="7.2" font-weight="800">[COULD | WSJF 2,67] PBI-16</text>
    <text x="750" y="385" fill="#334155" font-family="Inter, Segoe UI, sans-serif" font-size="6.8">OTA Direto APK GitHub + Purge PWA</text>

    <rect x="744" y="395" width="158" height="39" rx="4" fill="#FEF2F2" stroke="#FCA5A5" stroke-width="1"/>
    <text x="750" y="407" fill="#991B1B" font-family="Inter, Segoe UI, sans-serif" font-size="7.1" font-weight="800">[WON'T HAVE — VETADOS]</text>
    <text x="750" y="418" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="6.6">PBI-17: Estoque Físico Próprio</text>
    <text x="750" y="428" fill="#7F1D1D" font-family="Inter, Segoe UI, sans-serif" font-size="6.6">PBI-18: Cobrança Moedas/Leads</text>
  </svg>
  <div class="svg-caption">Figura 4.2 — Product Backlog Building (PBB Canvas — Fábio Aguiar) conectando Problemas Empíricos, Expectativas, Personas, Épicos e PBIs Priorizados (MoSCoW + WSJF).</div>
</div>
`;

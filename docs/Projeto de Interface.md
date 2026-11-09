# Projeto de Interface, Engenharia de UX a 60 FPS e Design System — Desperrengue (`v2.8.1`)

Especificação da arquitetura visual, ergonomia cognitiva, isolamento de repintura a $60\text{ FPS}$ e fluxos interativos das interfaces Cliente e Profissional do sistema **Desperrengue**.

---

## 1. Fundamentos do Design System e Trava Responsiva (`480px`)

1. **Paleta Cromática de Alto Contraste (*Dark-First Industrial & Copper*)**:
   - Superfícies primárias em azul-ardósia profundo (`#0F172A` / `#1E293B`) combinadas ao acento primário âmbar-cobre (`#FF6B00` / `#F97316`), verde esmeralda (`#10B981`) para selos forenses/garantias ativas e vermelho coral (`#EF4444`) para alertas de violação de SLA.
2. **Container Responsivo Canônico (`Regra Zero`)**:
   - Em [`app/lib/main.dart`](../app/lib/main.dart), toda a aplicação é renderizada dentro de um `ConstrainedBox(constraints: BoxConstraints(maxWidth: 480))` centralizado, assegurando proporções ergonômicas idênticas entre aparelhos Android nativos, iPhones via PWA e navegadores Desktop.
3. **Engenharia de Renderização a 60 FPS**:
   - As 4 abas principais operam sob `IndexedStack` com `AutomaticKeepAliveClientMixin`.
   - Cronômetros regressivos de SLA de 4h e indicadores de captura biométrica são encapsulados em `RepaintBoundary` + `ValueListenableBuilder<Duration>`, restringindo o *dirty-marking* da árvore de *RenderObjects* a $O(1)$.

---

## 2. Arquitetura de Navegação em 4 Abas Operacionais

Tanto a `ClientHomeScreen` quanto a `ProHomeScreen` estruturam o acompanhamento de Ordens de Serviço em **quatro abas sincronizadas em tempo real**:

| Aba | Visão do Cliente (`ClientHomeScreen`) | Visão do Profissional (`ProHomeScreen`) |
| :--- | :--- | :--- |
| **1ª Aba** | **Solicitações (`open`)**: Acompanhamento de propostas recebidas e decomposição *Smart Split*. | **Disponíveis (`open`)**: Mural geoespacial ordenado pelo algoritmo *Waterfall* (5 Tiers) com envio de propostas. |
| **2ª Aba** | **Em Andamento (`in_progress`)**: Chat direto, rastreamento de execução e geração do **PIN Presencial de 4 Dígitos**. | **Em Execução (`in_progress`)**: Captura do **Checklist Fotográfico Antes e Depois** com selo `dHash` 64-bit. |
| **3ª Aba** | **Concluídos (`completed`)**: Recibo auditado, avaliação por estrelas e certificado incorporado ao **Passaporte do Imóvel**. | **Finalizados (`completed`)**: Comprovante de liquidação em carteira e histórico de reputação ($RTS$). |
| **4ª Aba** | **Em Mediação (`in_mediation`)**: Abertura de garantia com evidência forense, congelamento do *Escrow D+5*, cronômetro SLA de 4h e despacho de **Profissional Socorrista (Camada 3)**. | **Em Mediação (`in_mediation`)**: Resposta prioritária em até 4h úteis, agendamento de retorno em 24h ou oportunidades de resgate remunerado pelo Fundo Garantidor. |

---

## 3. Componentes Críticos de Experiência do Usuário (`v2.8.1`)

### 3.1. Câmera Frontal Ao Vivo em Moldura Oval (`_LiveFrontOvalLivenessCameraModal`)
- Apresenta o fluxo de vídeo ao vivo da câmera frontal recortado em elipse (`ClipOval`) com anel de progresso luminoso que guia os **3 desafios biomecânicos** (centralizar rosto, girar levemente a cabeça e piscar), exibindo telemetria em tempo real de cobertura de pele $YCbCr$ e nitidez Laplaciana.

### 3.2. Scanner Documental Guiado ISO/IEC 7810 ID-1 (`DocumentGuidedScannerModal`)
- Exibe moldura retangular na proporção exata `1.586 : 1` com cantoneiras néon, instruções de iluminação sem reflexo e validação instantânea da Frente e do Verso do documento, culminando no card auditável `_OcrTranscribedSummaryCard` na Etapa 4 do onboarding.

### 3.3. Carteira Bipartida (`BipartiteWalletCard`) e Modal de PIN de 4 Dígitos (`Pin4WarrantyVerificationModal`)
- A **Carteira Bipartida** separa visualmente o **Saldo Livre (Saque PIX Imediato)** do **Saldo em Maturação Programada ($D+7 / D+5 / D+2$)** com barra de progresso temporal e alerta de *Security Cooldown (24h)*.
- O **Modal de PIN de 4 Dígitos** exige a digitação presencial do código dinâmico gerado no aparelho do cliente para destravar a conclusão de visitas de garantia.

### 3.4. Passaporte Oficial de Manutenção do Imóvel (`PropertyPassportInteractiveView`)
- Inicia com animação *staggered* de 650ms apresentando os benefícios patrimoniais (**ABNT NBR 5674** e **Lei 8.245/91**), um simulador interativo de valorização e, para clientes com serviços reais concluídos, a linha do tempo criptográfica com exportação imediata em `%PDF-1.4`.

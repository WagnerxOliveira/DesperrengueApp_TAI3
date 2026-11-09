# Guia de Padronização Visual e Identidade de Marca (`Template.md`)

Especificação dos tokens visuais, tipografia, iconografia adaptativa e padrões de layout aplicados ao ecossistema **Desperrengue** (`v2.8.1`).

---

## 1. Tokens Cromáticos Oficiais (`AppTheme`)

A identidade visual adota o padrão **Industrial Dark & Brushed Copper**, otimizado para telas OLED/AMOLED com contraste mínimo **WCAG AA** ($\ge 4.5:1$):

| Token Semântico | Hexadecimal | Aplicação na Interface |
| :--- | :---: | :--- |
| `backgroundPrimary` | `#0B1120` | Plano de fundo principal das telas e modais forenses. |
| `surfaceCard` | `#1E293B` | Cartões de Ordem de Serviço, Carteira Bipartida e Passaporte do Imóvel. |
| `accentPrimary` | `#FF6B00` | Botões de ação primária (CTAs), cantoneiras do scanner ISO ID-1 e destaques de marca. |
| `statusSuccess` | `#10B981` | Selos de verificação biométrica aprovada, garantia ativa e conformidade ABNT NBR 5674. |
| `statusWarning` | `#F59E0B` | Indicadores de saldo em maturação ($D+5$) e alertas preventivos de SLA. |
| `statusDanger` | `#EF4444` | Violação de SLA de 4h, bloqueio forense (`dHash`/EXIF) e dívida técnica (`suspended_debt`). |

---

## 2. Tipografia e Hierarquia Informacional

- **Família Tipográfica Principal**: `Inter` / `Roboto` (Material 3 Typography Scale).
- **Valores Monetários e Cronômetros SLA**: Renderizados com `FontFeature.tabularFigures()` para garantir largura fixa de dígitos e evitar oscilação horizontal (*layout shift*) durante a contagem regressiva a $60\text{ FPS}$.
- **Hashes Criptográficos e Códigos de Certificado**: Renderizados em fonte monoespaçada para inspeção de assinaturas `SHA-256`, `dHash` e códigos `DSP-GAR-*`.

---

## 3. Engenharia do Ícone Adaptativo (Android One UI, iOS e PWA)

O ícone oficial do aplicativo (monograma geométrico **D** invertido integrado ao telhado residencial e insígnia técnica em cobre escovado sobre fundo `#0B1120`) obedece rigorosamente à **Zona de Segurança de 66% (*Safe-Zone*)** do padrão Android Adaptive Icons (`mipmap-anydpi-v26`), garantindo enquadramento sem cortes sob máscaras *squircle* (Samsung One UI), circulares (Pixel) e iOS/PWA, validado automaticamente pela suíte [`app/test/ui_polish_test.dart`](../app/test/ui_polish_test.dart).

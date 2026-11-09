# Arquitetura de Reputação Algorítmica, Score RTS e Gamificação — Desperrengue (`v2.8.1`)

Especificação matemática do sistema de reputação meritocrática, do **Relative Trust Score ($RTS \in [0, 100]$)**, do algoritmo de ranqueamento **Waterfall em 5 Tiers** e das conquistas patrimoniais de clientes e profissionais no ecossistema **Desperrengue**.

---

## 1. Motor de Reputação do Profissional: Relative Trust Score ($RTS$)

Para superar o paradoxo do *Cold-Start* sem vulnerabilizar o Fundo de Garantia em 3 Camadas, a reputação de cada profissional é governada pela função determinística $O(1)$ `public.compute_relative_trust_score` (migração [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql)):

$$RTS = \text{clamp}_{[0, 100]}\Big(30\cdot\mathbb{I}_{\text{KYC+Bio}} + 15\cdot\mathbb{I}_{\text{Cert}} + \min(25, 2.5 N_{\text{jobs}}) + 20\cdot\max(0, \frac{\bar{R} - 3.0}{2.0}) + 10\cdot\mathbb{I}_{\text{Anchor}} - 45 N_{\text{fault}}\Big)$$

| Componente | Pontuação | Regra de Concessão e Impacto Operacional |
| :--- | :---: | :--- |
| **Identidade Biométrica + OCR ($\mathbb{I}_{\text{KYC+Bio}}$)** | **$+30\text{ pts}$** | Concedido imediatamente após aprovação na Prova de Vida Ao Vivo (`ClipOval`) + Scanner ISO ID-1 + Face Match $\ge 78\%$. Compartilhado automaticamente entre os modos Cliente e Profissional. |
| **Certificação Técnica ($\mathbb{I}_{\text{Cert}}$)** | **$+15\text{ pts}$** | Validação de diploma ou credencial oficial (**SENAI, CREA, CFT, NR-10, NR-35** — `RN-MZ-05`). |
| **Histórico de Execução ($N_{\text{jobs}}$)** | **Até $+25\text{ pts}$** | Acumula $+2,5\text{ pts}$ por ordem de serviço concluída sem disputa (satura em $10$ serviços). |
| **Média de Avaliações ($\bar{R} \in [1, 5]$)** | **Até $+20\text{ pts}$** | Escala linearmente para médias acima de $3,0$ estrelas. |
| **Âncora Externa ($\mathbb{I}_{\text{Anchor}}$)** | **$+10\text{ pts}$** | Comprovação de portfólio externo ou referência técnica auditada. |
| **Penalidade por Violação de Garantia ($N_{\text{fault}}$)** | **$-45\text{ pts}$** | Aplicada a cada violação de SLA na Camada 2 que exija acionamento da Camada 3 (`RN-AF-04`). |

---

## 2. Ranqueamento Waterfall em 5 Tiers e Maturação de Escrow

O valor materializado de `relative_trust_score` determina instantaneamente a posição do profissional na cascata de busca (`waterfall_tier_rank` de $1$ a $5$) e a velocidade de liberação do seu saldo em maturação:

1. **Tier 1 — Nível Ouro (`waterfall_tier_rank = 1`)**: $RTS \ge 85$, $\ge 15$ serviços concluídos e $0$ falhas. Desbloqueia liquidação acelerada **D+2 (48h)** e elegibilidade exclusiva como **Profissional Socorrista** remunerado pela Camada 3 (`RN-AF-13`).
2. **Tier 2 — Talento Verificado em Ascensão (`waterfall_tier_rank = 2`)**: KYC Biométrico + Certificação Técnica validados ($RTS \ge 45$) em janela de *Cold-Start* ($< 5$ serviços), garantindo visibilidade justa aos novos profissionais qualificados.
3. **Tier 3 — Profissional Regular Verificado (`waterfall_tier_rank = 3`)**: $\ge 5$ serviços e $RTS \ge 60$, operando sob maturação padrão **D+5 (120h)**.
4. **Tier 4 — Novato em Maturação (`waterfall_tier_rank = 4`)**: Operação em janela **D+7 (168h)** com teto de $\text{R\$ } 350,00$ por OS (`RN-MZ-01`).
5. **Tier 5 — Conta Restrita ou Não Verificada (`waterfall_tier_rank = 5`)**: Contas sem KYC concluído ou bloqueadas por dívida técnica (`suspended_debt`).

---

## 3. Gamificação Patrimonial do Cliente: Score de Vistoria do Imóvel

No módulo **Prontuário da Casa (Passaporte Oficial de Manutenção do Imóvel)**, o cliente acumula conquistas técnicas e eleva o **Score de Vistoria Patrimonial ($0$ a $100$ pontos)** conforme realiza manutenções preventivas e corretivas auditadas segundo a **ABNT NBR 5674**, gerando valorização real comprovável perante imobiliárias e seguradoras.

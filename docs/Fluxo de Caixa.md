# Demonstrativo de Fluxo de Caixa e Dinâmica de Liquidação — Desperrengue (`v2.8.1`)

Modelagem financeira do fluxo de caixa operacional, da custódia transitória em maturação (*Escrow* $D+7 / D+5 / D+2$) e da contabilidade imutável do Fundo de Garantia em 3 Camadas (`public.warranty_pool_ledger`).

---

## 1. Segregação Contábil de Fluxos Monetários

Em conformidade com as quatro invariantes contábeis implementadas na migração [`20261108110000_high_perf_warranty_antifraud_engine.sql`](../supabase/migrations/20261108110000_high_perf_warranty_antifraud_engine.sql), toda entrada financeira oriunda de uma Ordem de Serviço é particionada instantaneamente pela RPC `public.lock_escrow_with_smart_split`:

1. **Conta Transitória de Maturação (`public.escrow_maturation_entries`)**:
   - Retém $85.0\%$ do valor de mão de obra ($L$) acrescido de $100.0\%$ do valor de peças e materiais comprovados por nota fiscal ($M$).
   - Permanece em estado `locked_in_maturation` pelo período determinado pelo tier do prestador (**D+7** para Novatos em *Cold-Start*, **D+5** para Regulares e **D+2** para Nível Ouro), sendo liberada para saque PIX (`status = 'released'`) somente se não houver disputa ativa (`frozen_mediation`).
2. **Conta de Receita Operacional Líquida da Plataforma (`13,5%` sobre $L$)**:
   - Constitui o faturamento bruto próprio da plataforma (base de incidência do Simples Nacional — Anexo III, alíquota inicial de $6.0\%$), destinado a custear infraestrutura em nuvem, armazenamento e operação.
3. **Livro-Razão do Fundo Garantidor (`1,5%` sobre $L$ — `public.warranty_pool_ledger`)**:
   - Reserva técnica autônoma alimentada por registros `carveout_credit_1_5pct` e protegida por capital semente inicial (`seed_reserve` — `RN-MZ-04`).
   - Utilizada exclusivamente para remunerar o **Profissional Socorrista** em sinistros de **Camada 3** (`layer3_claim_debit`), enquanto o valor correspondente é lançado como passivo recuperável (`technical_debt_balance` / `debt_recovery_credit`) contra o prestador original inadimplente.

---

## 2. Simulação Unitária de Transação (*Unit Economics*)

Considere uma Ordem de Serviço residencial de **R$ 500,00**, composta por **R$ 300,00** de mão de obra ($L$) e **R$ 200,00** de materiais com nota fiscal ($M = 40\% \le 60\%$):

| Rubrica Contábil | Fórmula Aplicada | Valor (R$) | Destino Relacional |
| :--- | :--- | :---: | :--- |
| **Valor Bruto Pago pelo Cliente (`gross_amount`)** | $L + M$ | **R$ 500,00** | Entrada de Custódia (*Escrow*) |
| **Repasse de Materiais c/ NF (`0%` taxa)** | $1,000 \times M$ | **R$ 200,00** | `escrow_maturation_entries.net_professional_amount` |
| **Mão de Obra Líquida do Profissional (`85%`)** | $0,850 \times L$ | **R$ 255,00** | `escrow_maturation_entries.net_professional_amount` |
| **Total Líquido do Profissional (`net_professional_amount`)** | $200,00 + 255,00$ | **R$ 455,00** | Liberado após janela $D+7/D+5/D+2$ |
| **Receita Operacional Desperrengue (`13,5%` de $L$)** | $0,135 \times L$ | **R$ 40,50** | Caixa Operacional da Plataforma |
| **Provisão do Fundo Garantidor (`1,5%` de $L$)** | $0,015 \times L$ | **R$ 4,50** | `warranty_pool_ledger` (`carveout_credit_1_5pct`) |

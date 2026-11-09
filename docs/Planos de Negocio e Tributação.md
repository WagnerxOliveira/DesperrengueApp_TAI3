# Planos de Negócio, Modelagem Atuarial e Tributação — Desperrengue (`v2.8.1`)

Especificação da arquitetura econômica, estrutura de *Smart Split* tributário (CNAE 6319-4/00), modelagem atuarial do Fundo de Garantia em 3 Camadas e prova de compatibilidade de incentivos do ecossistema **Desperrengue**.

---

## 1. Arquitetura de Receita: Smart Split Anti-Bypass

Diferentemente de marketplaces generalistas que aplicam alíquota linear sobre o valor bruto da transação, o motor contábil do **Desperrengue** (`public.lock_escrow_with_smart_split`) segrega a Ordem de Serviço em duas naturezas jurídicas e financeiras distintas:

| Rubrica da Ordem de Serviço | Alíquota Total | Destinação Contábil | Regra de Conformidade (`RN-AF-11`) |
| :--- | :---: | :--- | :--- |
| **Mão de Obra (`labor_amount` — $L$)** | **15,0%** | **13,5%** Receita Operacional da Plataforma + **1,5%** Provisão Imutável no `warranty_pool_ledger` | Base de cálculo exclusiva da comissão e do teto de cobertura da garantia. |
| **Peças e Materiais (`materials_amount` — $M$)** | **0,0%** | **100,0%** Repassado integralmente ao Profissional (Reembolso de Insumos) | Exige anexo de Nota Fiscal (`materials_receipt_url`) e trava $M \le 0,60 \cdot (L + M)$. |

### 1.1. Demonstração Matemática de Equilíbrio Atuarial ($N_{\text{equilíbrio}}$)

A provisão compulsória de $c = 1.5\%$ ($0.015$) sobre o valor de mão de obra alimenta continuamente o livro-razão `public.warranty_pool_ledger`. O número de serviços concluídos necessário para financiar integralmente 1 (um) sinistro de Camada 3 de mesmo valor médio $\bar{L}$ é:

$$N_{\text{equilíbrio}} = \frac{\bar{L}}{0.015 \cdot \bar{L}} = \frac{1}{0.015} = 66.67 \approx 67 \text{ ordens de serviço}$$

Assim, mantendo-se a taxa de acionamento de Camada 3 abaixo de $1.49\%$ das transações concluídas, o Fundo Garantidor opera em regime **superavitário e auto-sustentável**, protegido adicionalmente pelo *Circuit Breaker* automático (`RN-MZ-04`) caso a sinistralidade móvel de 30 dias supere $1.20\%$.

---

## 2. Prova de Compatibilidade de Incentivos (Anti-Evasão / Anti-Bypass)

Em Teoria dos Jogos, o cliente e o prestador optam por permanecer dentro da plataforma se, e somente se, a utilidade líquida *on-platform* superar a utilidade esperada da transação *off-platform* (por fora):

1. **Incentivo do Profissional**: Como $M$ (peças e insumos) sofre retenção de **0%**, a taxa efetiva sobre o valor global da nota cai proporcionalmente (ex.: em um serviço de $\text{R\$ } 500,00$ com $\text{R\$ } 300,00$ de mão de obra e $\text{R\$ } 200,00$ de peças, a retenção total é de $\text{R\$ } 45,00$, equivalente a apenas **$9.0\%$** do valor bruto), garantindo liquidação protegida contra inadimplência e progressão no ranking *Waterfall* ($RTS$).
2. **Incentivo do Cliente**: A contratação dentro da plataforma concede acesso imediato às **3 Camadas de Garantia** (até $\text{R\$ } 500,00$ de cobertura com despacho de Profissional Socorrista em caso de falha) e emite automaticamente o certificado **ABNT NBR 5674** no **Passaporte Oficial de Manutenção do Imóvel**, valorizando o patrimônio imobiliário em montante superior à taxa de intermediação.

---

## 3. Enquadramento Societário e Tributário (Simples Nacional — Anexo III)

- **CNAE Principal**: `6319-4/00` (*Portais, provedores de conteúdo e outros serviços de informação na internet — Intermediação de serviços via plataforma digital*).
- **Base de Cálculo de ISS e Simples Nacional (*Split Payment*)**: A base tributável da plataforma restringe-se estritamente à receita operacional de intermediação ($13.5\% \cdot L$), uma vez que os valores de mão de obra líquida ($85.0\% \cdot L$) e reembolso de materiais ($100.0\% \cdot M$) constituem fluxo de caixa transitório de terceiros custodiado em *Escrow*.
- **Alíquota Efetiva Inicial (1ª Faixa do Anexo III — Receita Bruta Anual até R$ 180.000,00)**: **6,0%** sobre a receita de intermediação, mantendo alta eficiência fiscal desde o Marco Zero.

# Manual Técnico para o Contador — CPC 47, Anexo III (6%) e NFS-e em Poços de Caldas / MG

> **Destinatário:** Escritório Contábil responsável pela abertura e escrituração da SLU do **Desperrengue** em **Poços de Caldas / MG**.
> **Objetivo Executivo:** Garantir enquadramento tributário legítimo, auditável e imune a bitributação, tributando **exclusivamente os `13,5%` de comissão da plataforma no Anexo III (`6,00%` inicial)** e assegurando distribuição de lucros **100% isenta de IRPF** ao sócio único.

Documentos correlatos neste pacote:
- [Minuta do Contrato Social SLU — Poços de Caldas / MG](./01_MINUTA_CONTRATO_SOCIAL_SLU_POCOS_DE_CALDAS.md)
- [Cláusula-Mandato Mercantil (Art. 653 CC) — Termos de Uso](./02_CLAUSULA_MANDATO_TERMOS_DE_USO_ART_653_CC.md)
- [Runbook de Virada `SANDBOX_PRE_CNPJ` -> `PRODUCTION_SLU` (D-30 a D+0)](./04_RUNBOOK_VIRADA_PRODUCAO_SLU_D30_A_D0.md)

---

## 1. Segregação Contábil de Receita em Marketplace (`CPC 47` / `NBC TG 47` / `Art. 3º LC 123/2006`)

Um erro contábil comum — e fatal para plataformas digitais — é confundir o **Volume Bruto Transacionado (`GMV`)** pago pelos clientes com a **Receita Bruta Própria** da empresa. No **Desperrengue**, a arquitetura jurídica, bancária (*Split na fonte*) e sistêmica opera sob o regime estrito de **Agente / Mandatário Mercantil** (arts. 653 a 691 do Código Civil e itens B34 a B38 da **NBC TG 47 / CPC 47**):

| Parcela do Pagamento PIX do Cliente | Percentual | Natureza Contábil & Jurídica | Compõe a Base do DAS (PGDAS-D)? | Conta Contábil Sugerida |
| :--- | :---: | :--- | :---: | :--- |
| **Repasse Líquido do Prestador** | `85,0%` (mão de obra) | Ingresso financeiro transitório de terceiro por mandato (Passivo de Repasse) | **NÃO (`0%`)** | `2.1.04.01` — Valores a Repassar a Prestadores (Mandato) |
| **Reembolso de Peças com NF-e 44d** | `100,0%` (insumos) | Mero reembolso de despesa comprovada por nota fiscal SEFAZ | **NÃO (`0%`)** | `2.1.04.02` — Reembolsos de Insumos por Conta e Ordem |
| **Fundo Garantidor Mútuo (90 dias)** | `1,5%` (mão de obra) | Retenção fiduciária vinculada a obrigação de garantia legal (CDC art. 26, II) | **NÃO** *(salvo eventual reversão definitiva incerta após prescrição contratual)* | `2.1.05.01` — Provisão Fiduciária Garantia Técnica 90d |
| **Comissão de Intermediação Desperrengue** | **`13,5%`** (mão de obra) | **Receita Bruta Operacional Própria da SLU** | **SIM (`100%` desta parcela)** | `3.1.01.01` — Receita de Intermediação e Portal Digital |

### Exemplo Numérico Real (Auditado em `BIGINT` de Centavos pelo Sistema)
Suponha um atendimento residencial de **R\$ 300,00**, sendo **R\$ 200,00** de mão de obra do eletricista e **R\$ 100,00** de disjuntor comprovado por NF-e de 44 dígitos na SEFAZ:
1. Total pago pelo cliente via PIX (`GMV`): **R\$ 300,00**;
2. Reembolso isento da peça (`NF-e 44 dígitos`): **R\$ 100,00** -> repassado integralmente ao prestador;
3. Repasse líquido da mão de obra (`85% × R$ 200,00`): **R\$ 170,00** -> crédito direto do prestador;
4. Reserva fiduciária de garantia de 90 dias (`1,5% × R$ 200,00`): **R\$ 3,00** -> conta patrimonial segregada;
5. **Receita Bruta Tributável do Desperrengue (`13,5% × R$ 200,00`): R\$ 27,00**;
6. **DAS Simples Nacional Anexo III (`6,00% × R$ 27,00`): R\$ 1,62** *(equivalente a apenas `0,54%` sobre os R\$ 300,00 movimentados — economia tributária 100% lícita de **91%** frente ao erro de tributar o GMV no Anexo V!)*.

---

## 2. Dupla Blindagem no Anexo III (`6,00%`) e Proteção contra o Anexo V (`15,5%`)

1. **Enquadramento Primário pelo CNAE `6319-4/00`:**
   - A atividade de *Portais, provedores de conteúdo e outros serviços de informação na internet* (`6319-4/00`) enquadra-se no **Anexo III** da LC nº 123/2006 (`6,00%` na 1ª faixa até `R$ 180.000,00` de receita de comissões em 12 meses, o que comporta até **R\$ 1.333.333,33 de GMV anual** na 1ª faixa!).
2. **Trava Adicional de Segurança pelo Fator R (`FS12 / RBT12 >= 28%`):**
   - Caso a fiscalização interprete qualquer fração da operação tecnológica como sujeita ao Fator R (art. 18, §§ 5º-J e 5º-M da LC nº 123/2006, apurado pelo regime de caixa conforme **Solução de Consulta COSIT nº 17/2021**), a manutenção de um **Pró-Labore mensal ao sócio único equivalente a no mínimo `28,5%` da receita bruta mensal de comissões (`13,5%`)** garante matematicamente a permanência inquestionável no **Anexo III (`6,00%`)**!
   - *Demonstração financeira da vantagem:* como a receita bruta da SLU é apenas os `13,5%` de comissão, um pró-labore de **1 salário mínimo** já cobre `>= 28%` de Fator R para uma receita de comissão de até `~R$ 5.700,00/mês` (`~R$ 42.200,00/mês` de GMV na plataforma), com custo previdenciário de apenas `11%` de INSS retido (contribuinte individual optante pelo Simples Nacional — sem os `20%` patronais de CPP!).

---

## 3. Emissão de NFS-e na Prefeitura de Poços de Caldas / MG

1. **Cadastro Municipal:** logo após o deferimento do CNPJ na JUCEMG/REDESIM, requerer a **Inscrição Municipal** e o credenciamento de emissão de **NFS-e (Nota Fiscal de Serviços Eletrônica)** junto à Secretaria Municipal da Fazenda de **Poços de Caldas / MG**, com certificado digital **e-CNPJ Tipo A1**.
2. **Parametrização da NFS-e:**
   - **Regime Especial de Tributação:** Optante pelo Simples Nacional (ISS recolhido unificadamente dentro do DAS — alíquota destacada de retenção na fonte = `0,00%` para serviços não sujeitos a substituição tributária);
   - **Valor do Serviço na NFS-e:** estritamente o valor da **taxa de intermediação (`13,5%`)** efetivamente auferida nas ordens liquidadas do período;
   - **Discriminação Padrão Recomendada no Corpo da NFS-e:**
     > *"Serviços de portal digital e intermediação tecnológica na conexão de prestadores independentes (CNAE 6319-4/00), conforme Cláusula-Mandato Mercantil (arts. 653 a 691 do Código Civil) e NBC TG 47 (CPC 47). Valor total transacionado por conta de terceiros no período: R$ [GMV] | Repasses e reembolsos de terceiros deduzidos da base própria: R$ [REPASSES] | Receita própria de intermediação tributável (13,5%): R$ [COMISSAO_13_5]."*

---

## 4. Calendário Operacional Mensal Integrado ao Aplicativo `Desperrengue CEO`

O aplicativo exclusivo **Desperrengue CEO** já gera automaticamente, em 1 toque, o **Pacote Contábil Mensal Assinado (`PDF` + `CSV` com hash de integridade `SHA-256`)** contendo conciliação tripla exata ao centavo:

| Dia do Mês | Responsável | Ação Executiva |
| :---: | :--- | :--- |
| **Dia 1º** | CEO -> Contador | Exportar na aba `Financeiro` do **Desperrengue CEO** o *Pacote Mensal do Contador* (`PDF + CSV SHA-256`) do mês encerrado e enviar ao escritório contábil junto às NFS-e emitidas. |
| **Até Dia 5** | CEO | Transferir da conta PJ (Banco Inter Empresas) para a conta PF do sócio o valor líquido do **Pró-Labore** apurado na folha do eSocial. |
| **Até Dia 20 útil** | Contador -> CEO | Pagar a guia **DAS do Simples Nacional** (e guia DARF Previdenciário/DCTFWeb do INSS `11%` sobre o pró-labore) e dar baixa em 1 toque no Calendário Executivo do app. |
| **Após Dia 20** | CEO | Consultar o **Teto Seguro de Retirada (`WithdrawableProfitCents`)** na Central de Tesouraria do **Desperrengue CEO** e transferir a **Distribuição de Lucros Isenta de IRPF** exclusivamente para o CPF titular travado no cofre. |

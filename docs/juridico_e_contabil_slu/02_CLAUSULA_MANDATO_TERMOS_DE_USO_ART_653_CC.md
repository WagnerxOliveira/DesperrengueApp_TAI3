# Cláusula-Mandato Mercantil, Custódia Escalonada e Segregação Tributária (CPC 47)

> **Fundamento Legal:** Arts. 653 a 691 do Código Civil (Lei nº 10.406/2002) · Pronunciamento Técnico **CPC 47 / NBC TG 47** (*Receita de Contrato com Cliente — Principal vs. Agente*, itens B34 a B38) · Lei Complementar nº 123/2006 · Lei nº 12.965/2014 (Marco Civil) e Lei nº 13.709/2018 (LGPD).
> **Sincronização em Tempo Real:** O aceite eletrônico desta cláusula no aplicativo público `Desperrengue` gera hash criptográfico `SHA-256` persistido no banco de dados e refletido instantaneamente no painel `Desperrengue CEO`.

Documentos correlatos neste pacote:
- [Minuta do Contrato Social SLU — Poços de Caldas / MG](./01_MINUTA_CONTRATO_SOCIAL_SLU_POCOS_DE_CALDAS.md)
- [Manual Técnico do Contador — CPC 47, Anexo III & NFS-e Poços de Caldas](./03_MANUAL_TECNICO_CONTADOR_CPC47_ANEXO_III_POCOS_MG.md)
- [Runbook de Virada `SANDBOX_PRE_CNPJ` -> `PRODUCTION_SLU` (D-30 a D+0)](./04_RUNBOOK_VIRADA_PRODUCAO_SLU_D30_A_D0.md)

---

## Texto Normativo Oficial Integrado aos Termos de Uso do `Desperrengue`

### SEÇÃO ESPECIAL — MANDATO MERCANTIL DE LIQUIDAÇÃO, REPARTIÇÃO AUTOMÁTICA (*SMART SPLIT*), FUNDO GARANTIDOR MÚTUO E REEMBOLSO DE INSUMOS

#### 1. Natureza Jurídica de Portal Digital e Atuação Estrita como Agente (CPC 47 / NBC TG 47)
**1.1.** O **DESPERRENGUE** opera exclusivamente como plataforma digital de conexão, catálogo informativo e infraestrutura tecnológica de intermediação entre **USUÁRIOS CLIENTES** (tomadores finais dos serviços residenciais) e **USUÁRIOS PROFISSIONAIS** (prestadores autônomos ou microempreendedores independentes).
**1.2.** Para todos os fins civis, consumeristas, trabalhistas, previdenciários e tributários — especialmente à luz do Pronunciamento Técnico **CPC 47 (NBC TG 47 — Receita de Contrato com Cliente, itens B34 a B38)** —, o **PROFISSIONAL** é o único **Principal** da prestação do serviço técnico contratado pelo **CLIENTE**, cabendo ao **DESPERRENGUE** exclusivamente o papel de **Agente Tecnológico e Mandatário de Cobrança**. Inexiste vínculo empregatício, subordinação jurídica, exclusividade de agenda ou habitualidade obrigatória entre o **PROFISSIONAL** e o **DESPERRENGUE** (art. 3º e art. 442-B da CLT).

#### 2. Outorga Expressa de Mandato Mercantil Especial (Arts. 653 a 691 do Código Civil)
**2.1.** Ao aderir eletronicamente aos Termos de Uso e cadastrar-se para ofertar ou contratar serviços na plataforma, o **PROFISSIONAL** outorga ao **DESPERRENGUE**, em caráter especial, irrevogável e irretratável quanto às ordens de serviço aceitas na plataforma, **MANDATO MERCANTIL ESPECIAL** (nos termos dos arts. 653, 667, 684 e 685 do Código Civil Brasileiro) com poderes específicos para, **em nome, por conta e à ordem do PROFISSIONAL**:
- **(a)** receber dos **CLIENTES**, por meio de arranjo de pagamento PIX operado por Instituição de Pagamento autorizada pelo Banco Central do Brasil, a integralidade dos valores contratados para cada atendimento;
- **(b)** manter tais valores em conta transitória de custódia operacional vinculada à execução e aprovação técnica do atendimento;
- **(c)** executar automaticamente a repartição contratual (*Split de Pagamento*) na liquidação de cada ordem concluída;
- **(d)** reter e administrar fiduciariamente a quota de contribuição ao Fundo Garantidor Mútuo de 90 (noventa) dias; e
- **(e)** processar o reembolso puro de peças e materiais comprovados por documento fiscal eletrônico idôneo.

#### 3. Regra Matemática de Repartição (*Smart Split `85% · 13,5% · 1,5%`*)
**3.1.** Sobre a parcela correspondente exclusivamente à **mão de obra do serviço prestado** (excluído o reembolso puro de materiais comprovados na forma da Cláusula 4), aplica-se a seguinte partição aritmética exata em centavos:
- **(I) `85,0%` (oitenta e cinco por cento) — Repasse Líquido do Profissional:** pertence integral e originariamente ao **PROFISSIONAL** como receita própria de sua atividade autônoma/MEI, transitando pela infraestrutura de pagamento meramente como ingresso financeiro de terceiro por mandato, **jamais integrando a receita bruta ou o faturamento do DESPERRENGUE**;
- **(II) `13,5%` (treze inteiros e cinco décimos por cento) — Taxa de Intermediação e Licenciamento Tecnológico da Plataforma:** constitui a **única e exclusiva Receita Bruta Operacional do DESPERRENGUE**, sobre a qual a plataforma emitirá a respectiva Nota Fiscal de Serviços Eletrônica (NFS-e) de intermediação/portal e recolherá seus tributos próprios (Simples Nacional — Anexo III);
- **(III) `1,5%` (um inteiro e cinco décimos por cento) — Quota Fiduciária do Fundo Garantidor Mútuo de 90 Dias:** retida por conta e ordem da coletividade de prestadores em reserva patrimonial segregada para cobertura exclusiva de reexecução técnica ou ressarcimento em mediações procedentes de garantia legal de 90 (noventa) dias (art. 26, inciso II, do Código de Defesa do Consumidor), respeitado o direito primário de saneamento (*Right-to-Cure*) pelo próprio **PROFISSIONAL** originário.

#### 4. Isenção Integral sobre Reembolso Puro de Peças e Materiais (`0%` mediante NF-e/NFC-e de 44 Dígitos)
**4.1.** Quando o atendimento demandar a compra de peças, componentes ou insumos aplicados diretamente no imóvel do **CLIENTE**, o valor correspondente terá taxa de intermediação de **`0,0%` (zero por cento)** e repasse de **`100,0%` (cem por cento)** a título de mero reembolso de despesa por conta de terceiro, desde que o **PROFISSIONAL** registre na plataforma a **Chave de Acesso de 44 (quarenta e quatro) dígitos** da Nota Fiscal Eletrônica (NF-e Modelo 55 ou NFC-e Modelo 65) válida perante a Secretaria da Fazenda (**SEFAZ**).
**4.2.** *Cláusula de Auditoria Assíncrona e Estorno Preventivo (Clawback):* Caso a auditoria eletrônica junto à SEFAZ constate cancelamento extemporâneo, inidoneidade, denegação ou divergência material da nota fiscal informada após a concessão da isenção provisória, fica o **DESPERRENGUE** expressamente autorizado por este mandato (art. 664 do Código Civil) a recompor e compensar automaticamente a diferença de comissão (`13,5%`) e de reserva de garantia (`1,5%`) sobre o saldo futuro da carteira digital do **PROFISSIONAL**.

#### 5. Prazo de Maturação Operacional e Prevenção à Fraude / Coação
**5.1.** Para proteção recíproca de **CLIENTES** e **PROFISSIONAIS** contra fraudes de pagamento, estornos bancários (*MED PIX*) e situações de coação presencial, os créditos líquidos apurados na carteira digital observarão as janelas escalonadas de maturação e segurança divulgadas no aplicativo, podendo ter sua transferência externa temporariamente suspensa em caso de abertura tempestiva de protocolo de mediação técnica ou acionamento de alerta silencioso de segurança em campo.

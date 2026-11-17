# Minuta Técnica do Contrato Social — Sociedade Limitada Unipessoal (SLU - ME)

> **Jurisdição de Registro:** Junta Comercial do Estado de Minas Gerais (**JUCEMG**) · Município de **Poços de Caldas / MG**
> **Enquadramento Tributário Alvo:** Microempresa (**ME**) · Optante pelo **Simples Nacional — Anexo III (`6,00%` inicial)**
> **Status Operacional:** Pronta para protocolo no **Marco D-30** (assim que os 4 Critérios do Sinal Verde estiverem verdes no aplicativo `Desperrengue CEO`).

Documentos correlatos neste pacote:
- [Cláusula-Mandato Mercantil (Art. 653 CC) — Termos de Uso](./02_CLAUSULA_MANDATO_TERMOS_DE_USO_ART_653_CC.md)
- [Manual Técnico do Contador — CPC 47, Anexo III & NFS-e Poços de Caldas](./03_MANUAL_TECNICO_CONTADOR_CPC47_ANEXO_III_POCOS_MG.md)
- [Runbook de Virada `SANDBOX_PRE_CNPJ` -> `PRODUCTION_SLU` (D-30 a D+0)](./04_RUNBOOK_VIRADA_PRODUCAO_SLU_D30_A_D0.md)

---

## Diretrizes Inegociáveis para o Contador antes do Protocolo na JUCEMG

1. **Natureza Jurídica `206-2` (Sociedade Empresária Limitada — Unipessoal / SLU):** constituída nos termos do art. 1.052, §§ 1º e 2º, do Código Civil (Lei nº 10.406/2002, com redação dada pela Lei nº 13.874/2019), garantindo **separação patrimonial estrita** entre os bens particulares do sócio único e as obrigações da pessoa jurídica (art. 49-A e art. 50 do Código Civil). Jamais abrir como Empresário Individual (`213-5`), pois o EI responde ilimitadamente com o CPF.
2. **Porte Empresarial Microempresa (`ME`):** jamais constituir como MEI (o CNAE `6319-4/00` é vedado ao MEI e o modelo de plataforma exige ME com opção imediata pelo Simples Nacional no prazo decadencial de 30 dias da última inscrição — Municipal/Estadual — conforme Resolução CGSN nº 140/2018).
3. **CNAE Fiscal Principal Obrigatório:**
   - **`6319-4/00` — Portais, provedores de conteúdo e outros serviços de informação na internet** (tributado no **Anexo III** da Lei Complementar nº 123/2006, faixa inicial de `6,00%` até `R$ 180.000,00` de receita bruta acumulada em 12 meses — `RBT12`).
4. **CNAE Fiscal Secundário Permitido (Apoio Administrativo sem Contaminação):**
   - **`8211-3/00` — Serviços combinados de escritório e apoio administrativo** (Anexo III direto — art. 18, § 5º-B, LC nº 123/2006).
5. **CNAEs Estritamente Proibidos no CNPJ da Plataforma:**
   - **NÃO incluir** CNAEs de execução de obras, instalações elétricas (`4321-5/00`), hidráulicas (`4322-3/01`), manutenção predial ou limpeza: quem presta o serviço técnico residencial é **exclusivamente o profissional autônomo/MEI independente**, jamais o Desperrengue.
   - **NÃO incluir** CNAEs de instituição financeira/pagamento (`64xx`/`66xx`): toda liquidação PIX e custódia regulada opera sobre infraestrutura de Instituição de Pagamento homologada pelo Banco Central do Brasil (Asaas IP S.A. / Efí S.A. / Banco Inter S.A.) sob cláusula-mandato civil (art. 653 CC).

---

## Texto Integral da Minuta do Contrato Social de Constituição de SLU

**INSTRUMENTO PARTICULAR DE CONSTITUIÇÃO DE SOCIEDADE LIMITADA UNIPESSOAL**
**[RAZÃO SOCIAL SUGERIDA: DESPERRENGUE TECNOLOGIA E PORTAL DE CONTEÚDO LTDA.]**

Pelo presente instrumento particular de constituição:

**WAGNER OLIVEIRA**, brasileiro, [estado civil], [regime de bens, se casado], [profissão], nascido em [DD/MM/AAAA], natural de [Cidade/UF], inscrito no CPF sob o nº **[CPF_DO_SOCIO_UNICO]**, portador da Cédula de Identidade RG nº [NUMERO_RG] — [ORGAO_EXPEDIDOR/UF], residente e domiciliado na [LOGRADOURO, NÚMERO, COMPLEMENTO, BAIRRO], CEP [377XX-XXX], no Município de **Poços de Caldas**, Estado de **Minas Gerais**, endereço eletrônico `wagneroliveira2395@gmail.com`;

Resolve constituir uma **Sociedade Empresária Limitada Unipessoal**, nos termos do art. 1.052, §§ 1º e 2º, e arts. 1.053 a 1.087 da Lei nº 10.406, de 10 de janeiro de 2002 (Código Civil Brasileiro), bem como da Lei Complementar nº 123, de 14 de dezembro de 2006, mediante as cláusulas e condições seguintes:

### CLÁUSULA PRIMEIRA — DA DENOMINAÇÃO SOCIAL, NOME FANTASIA E SEDE
**1.1.** A sociedade girará sob a denominação social de **DESPERRENGUE TECNOLOGIA E PORTAL DE CONTEÚDO LTDA.**, adotando o nome fantasia **“DESPERRENGUE”**.
**1.2.** A sociedade tem sede e foro jurídico no Município de **Poços de Caldas**, Estado de **Minas Gerais**, na [ENDEREÇO FISCAL OU RESIDENCIAL COM USO DE PONTO DE REFERÊNCIA / SEDE VIRTUAL FISCAL AUTORIZADA EM POÇOS DE CALDAS/MG, Nº, BAIRRO, CEP 377XX-XXX], podendo abrir, transferir ou encerrar filiais, escritórios e representações em qualquer parte do território nacional por decisão de seu sócio único.

### CLÁUSULA SEGUNDA — DO OBJETO SOCIAL E ENQUADRAMENTO ECONÔMICO
**2.1.** A sociedade tem por objeto social a **operação de portal digital na internet, provedor de conteúdo informativo e diretório eletrônico de conexão entre usuários demandantes e prestadores independentes de serviços gerais**, bem como **serviços combinados de apoio administrativo digital e gestão documental por mandato mercantil** (**CNAE Principal `6319-4/00`** e **CNAE Secundário `8211-3/00`**).
**2.2.** *Parágrafo Único — Delimitação Estrita de Atuação como Agente Digital (NBC TG 47 / CPC 47):* A sociedade atua exclusivamente como operadora tecnológica de portal de informações e mandatária operacional na cobrança por conta e ordem de terceiros (arts. 653 a 691 do Código Civil), **não executando direta ou indiretamente serviços técnicos, residenciais, de manutenção, reparo ou construção**, os quais são contratados e prestados com total autonomia técnica, econômica e jurídica pelos prestadores independentes cadastrados no portal.

### CLÁUSULA TERCEIRA — DO PRAZO DE DURAÇÃO E INÍCIO DAS ATIVIDADES
**3.1.** O prazo de duração da sociedade é **indeterminado**, iniciando suas atividades na data do arquivamento deste ato constitutivo perante a Junta Comercial do Estado de Minas Gerais (**JUCEMG**).

### CLÁUSULA QUARTA — DO CAPITAL SOCIAL E DA LIMITAÇÃO DE RESPONSABILIDADE
**4.1.** O capital social é de **R\$ 2.000,00 (dois mil reais)**, dividido em **2.000 (duas mil) quotas** no valor nominal de **R\$ 1,00 (um real)** cada uma, totalmente subscritas e integralizadas neste ato, em moeda corrente nacional, pelo sócio único **WAGNER OLIVEIRA**:

| Sócio Único | Quotas | Valor Nominal Total | Participação |
| :--- | :---: | :---: | :---: |
| **WAGNER OLIVEIRA** | `2.000` | `R$ 2.000,00` | `100,00%` |
| **TOTAL** | **`2.000`** | **`R$ 2.000,00`** | **`100,00%`** |

**4.2.** Nos exatos termos do art. 1.052, *caput* e § 1º, combinado com o art. 49-A do Código Civil Brasileiro, a responsabilidade do sócio único é **estritamente restrita ao valor de suas quotas**, estando o capital social integralmente realizado, não respondendo o patrimônio particular do sócio único pelas dívidas, obrigações sociais ou operacionais da sociedade.

### CLÁUSULA QUINTA — DA ADMINISTRAÇÃO ISOLADA E DO PRÓ-LABORE
**5.1.** A administração da sociedade caberá isoladamente ao sócio único **WAGNER OLIVEIRA**, acima qualificado, com os poderes e atribuições de **Administrador**, autorizado o uso do nome empresarial de forma individual, vedado, no entanto, o seu emprego em atividades estranhas ao interesse social ou para assumir obrigações, fianças, avais ou endossos de mero favor em benefício de terceiros.
**5.2.** O Administrador poderá perceber retirada mensal a título de **pró-labore**, fixada de acordo com a conveniência financeira e o planejamento tributário legal da sociedade, observados os limites e encargos previdenciários vigentes.

### CLÁUSULA SEXTA — DO EXERCÍCIO SOCIAL, ESCRITURAÇÃO CONTÁBIL E DISTRIBUIÇÃO DE LUCROS
**6.1.** O exercício social coincidirá com o ano civil, encerrando-se em **31 de dezembro** de cada ano, data em que serão levantados o balanço patrimonial e a demonstração do resultado econômico do exercício.
**6.2.** A sociedade manterá escrituração contábil regular (Livro Diário e Livro Razão assinados por contabilista legalmente habilitado no CRC), permitindo a apuração e **distribuição antecipada ou periódica de lucros líquidos** ao sócio único mediante balancetes intermediários de verificação, observada a legislação tributária em vigor (art. 14 da Lei Complementar nº 123/2006) e preservadas integralmente as provisões fiscais e os saldos fiduciários de terceiros sob custódia.

### CLÁUSULA SÉTIMA — DA EXTINÇÃO E SUCESSÃO
**7.1.** A sociedade não se dissolverá automaticamente pelo falecimento ou incapacidade superveniente do sócio único, hipótese em que a totalidade das quotas transmitir-se-á aos seus herdeiros ou sucessores legais na forma da lei civil, que deliberarão sobre a continuidade ou liquidação regular da empresa.

### CLÁUSULA OITAVA — DA DECLARAÇÃO DE DESIMPEDIMENTO LEGAL (ART. 1.011, § 1º, DO CÓDIGO CIVIL)
**8.1.** O Administrador ora investido declara, sob as penas da lei, que não está impedido de exercer a administração da sociedade, por lei especial, ou em virtude de condenação criminal, ou por se encontrar sob os efeitos dela, a pena que vede, ainda que temporariamente, o acesso a cargos públicos; ou por crime falimentar, de prevaricação, peita ou suborno, concussão, peculato, ou contra a economia popular, contra o sistema financeiro nacional, contra normas de defesa da concorrência, contra as relações de consumo, fé pública, ou a propriedade.

### CLÁUSULA NONA — DO ENQUADRAMENTO COMO MICROEMPRESA (ME)
**9.1.** O sócio único declara, sob as penas da lei, que a sociedade se enquadra na condição de **Microempresa (ME)**, nos termos do art. 3º, inciso I, da Lei Complementar nº 123/2006, e que inexistem quaisquer dos impedimentos previstos no § 4º do referido dispositivo legal.

### CLÁUSULA DÉCIMA — DO FORO DE ELEIÇÃO
**10.1.** Fica eleito o foro da **Comarca de Poços de Caldas, Estado de Minas Gerais**, para dirimir quaisquer dúvidas ou controvérsias oriundas do presente instrumento constitutivo, com renúncia expressa a qualquer outro, por mais privilegiado que seja.

E, por estar assim justo e constituído, assina eletronicamente o presente instrumento em via única digital (padrão ICP-Brasil / Gov.br Nível Ouro) para arquivamento perante a **JUCEMG**.

Poços de Caldas / MG, [DIA] de [MÊS] de [ANO].

___________________________________________________
**WAGNER OLIVEIRA**
Sócio Único e Administrador
CPF: [CPF_DO_SOCIO_UNICO]

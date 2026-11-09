# Documento de Contexto e Fundamentação Científica — Desperrengue (`v2.8.1`)

Análise socioeconômica, modelagem de falhas de mercado (*Assimetria de Informação* e *Risco Moral*) e fundamentação arquitetural da plataforma **Desperrengue**.

---

## 1. Contextualização e Problema de Pesquisa

O mercado brasileiro de manutenção predial e reparos residenciais caracteriza-se por severa **assimetria de informação** (Akerlof, *The Market for "Lemons"*) e **risco moral pós-contratação**. Diretórios de anúncios tradicionais limitam-se a colocar as partes em contato, transferindo integralmente ao consumidor e ao prestador honesto quatro problemas estruturais:

1. **Desamparo Pós-Serviço (Vício Oculto)**: Após o pagamento imediato em espécie ou transferência direta, o cliente perde poder de barganha caso o reparo apresente falha nas horas ou dias subsequentes.
2. **Evasão de Plataforma (*Platform Leakage* / *Bypass*)**: Plataformas que cobram comissões abusivas ($20\%$ a $30\%$) ou que tributam indevidamente o reembolso de peças e materiais incentivam matematicamente o cliente e o prestador a transacionarem por fora.
3. **Vulnerabilidade a Fraudes e Reciclagem de Evidências**: Na ausência de validação biométrica ativa, custódia criptográfica de imagens (`dHash` / EXIF) e regras atuariais, fundos de garantia convencionais sofrem esgotamento rápido por conluio ou sabotagem.
4. **Perda de Memória Técnica do Imóvel**: Manutenções elétricas, hidráulicas e estruturais não geram lastro documental padronizado segundo a **ABNT NBR 5674**, depreciando o valor patrimonial do imóvel perante imobiliárias e seguradoras.

---

## 2. Solução Proposta pela Arquitetura Desperrengue

O **Desperrengue** resolve simultaneamente essas quatro falhas de mercado por meio de quatro inovações de engenharia de software e sistemas distribuídos:

1. **Smart Split Anti-Bypass (15% Mão de Obra / 0% Peças com NF)**:
   - Ao isentar integralmente ($0.0\%$) o repasse de materiais comprovados por nota fiscal e decompor a taxa sobre a mão de obra em $13.5\%$ operacional + $1.5\%$ para o Fundo Garantidor, elimina-se a penalização fiscal do profissional e sustenta-se atuarialmente a garantia ($N_{\text{equilíbrio}} = 66.67$ serviços por sinistro integral).
2. **Garantia Auto-Sustentável em 3 Camadas (`RN-CAM-01` a `RN-CAM-03`)**:
   - **Camada 1**: Retenção programada em maturação ($D+7/D+5/D+2$) com congelamento instantâneo em caso de chamado.
   - **Camada 2**: Retorno Técnico Prioritário de 30 a 90 dias com SLA de 4h úteis na 4ª aba *"Em Mediação"*.
   - **Camada 3**: Despacho de **Profissional Socorrista (Nível Ouro)** custeado pelo livro-razão `warranty_pool_ledger`, convertendo a inadimplência do prestador original em dívida técnica (`suspended_debt`).
3. **Identidade Biométrica Ao Vivo, Scanner ISO ID-1 e Custódia Forense `O(1)`**:
   - Ambos os polos da relação contratual passam por prova de vida facial ativa ($YCbCr$ + desafios biomecânicos em câmera frontal `ClipOval`), scanner documental guiado ISO/IEC 7810 ID-1 com Face Match multi-ângulo 128-D ($\ge 78\%$) e transcrição OCR visível, enquanto todas as evidências de serviço são seladas com `SHA-256` e `dHash` de 64 bits.
4. **Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674 e Lei 8.245/91)**:
   - Cada ordem de serviço auditada converte-se automaticamente em certidão técnica no prontuário patrimonial do imóvel, exportável em `%PDF-1.4` vetorial para vistorias de locação, venda e seguro residencial.

---

## 3. Alinhamento com os Objetivos de Desenvolvimento Sustentável (ODS / ONU)

- **ODS 8 (Trabalho Decente e Crescimento Econômico)**: Formalização técnica, proteção contra calotes via *Escrow* e valorização meritocrática de prestadores qualificados (SENAI, CREA, CFT, NR-10, NR-35) através do *Relative Trust Score* ($RTS$).
- **ODS 9 (Indústria, Inovação e Infraestrutura)**: Aplicação de Visão Computacional embarcada em *Worker Isolates* e contabilidade distribuída imutável sobre infraestrutura residencial.
- **ODS 11 (Cidades e Comunidades Sustentáveis)**: Extensão da vida útil das edificações urbanas mediante manutenção preventiva rastreável pela norma **ABNT NBR 5674**.

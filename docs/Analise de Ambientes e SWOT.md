# Análise de Ambientes, Matriz SWOT e Posicionamento Estratégico — Desperrengue (`v2.8.1`)

Análise estratégica de ambientes (Macroambiente PESTEL, 5 Forças de Porter e Matriz SWOT Cruzada) fundamentada nos diferenciais de engenharia financeira e visão computacional do ecossistema **Desperrengue**.

---

## 1. Análise de Macroambiente (PESTEL)

1. **Político-Legal**: A **Lei Geral de Proteção de Dados (Lei nº 13.709/2018)**, o **Código de Defesa do Consumidor (Art. 26 — garantia legal de 90 dias)**, a **Lei do Inquilinato (Lei nº 8.245/91)** e a norma técnica **ABNT NBR 5674** criam demanda direta por plataformas que documentem formalmente as intervenções prediais e protejam dados pessoais mediante pseudonimização (`cpf_hash`) e exclusão escopada (`delete_own_account_scoped`).
2. **Econômico**: A expansão do mercado de locação residencial e a necessidade de preservação patrimonial tornam o **Smart Split Anti-Bypass** ($15\%$ sobre mão de obra e $0\%$ sobre materiais com nota fiscal) economicamente superior aos modelos de cobrança por *lead* ou comissões lineares.
3. **Tecnológico**: A maturidade de *Worker Isolates* no Flutter 3.47 e do PostgreSQL 17 viabiliza a execução local de algoritmos de Visão Computacional (`dHash` 64-bit, `MAD` $64\times 64$, crominância $YCbCr$ e Face Match 128-D multi-ângulo) com custo marginal zero de API externa.

---

## 2. Matriz SWOT (FOFA) Técnica e Operacional

| Dimensão | Fatores Estratégicos Verificados no Produto (`v2.8.1`) |
| :--- | :--- |
| **Forças (*Strengths*)** | 1. **Fundo de Garantia Auto-Sustentável em 3 Camadas (`RN-CAM-01..03`)** com equilíbrio atuarial em $66.67$ serviços.<br>2. **Smart Split Anti-Bypass** ($0\%$ de taxa sobre materiais com NF $\le 60\%$).<br>3. **Biometria Facial Ao Vivo + Scanner ISO ID-1 + OCR** executados em *Worker Isolates* com custo zero de nuvem.<br>4. **Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674)** em `%PDF-1.4`.<br>5. **Complexidade $O(1)$ e $O(\log N + K)$** no SGBD com prevenção matemática de *deadlocks*. |
| **Fraquezas (*Weaknesses*)** | 1. Necessidade de liquidez inicial (*Seed Reserve* — `RN-MZ-04`) nos primeiros $67$ chamados de cada praça.<br>2. Exigência de aparelho com câmera frontal funcional para aprovação no onboarding biométrico. |
| **Oportunidades (*Opportunities*)** | 1. Parcerias B2B com imobiliárias e seguradoras utilizando o **Passaporte do Imóvel (ABNT NBR 5674)** como laudo de vistoria.<br>2. Atração de profissionais qualificados (**SENAI, CREA, CFT, NR-10, NR-35**) via progressão rápida no *Relative Trust Score* ($RTS$). |
| **Ameaças (*Threats*)** | 1. Tentativas de conluio, sabotagem pós-serviço ou reciclagem de fotos — mitigadas determinísticamente pelas regras **`RN-AF-01` a `RN-AF-14`**.<br>2. Tentativas de evasão (*bypass*) — neutralizadas pela isenção sobre peças e pelo valor patrimonial da garantia e do Passaporte ABNT. |

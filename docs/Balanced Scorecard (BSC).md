# Balanced Scorecard (BSC) e Indicadores de Desempenho — Desperrengue (`v2.8.1`)

Estruturação dos indicadores estratégicos de desempenho (*Key Performance Indicators* — KPIs) do sistema **Desperrengue** nas quatro perspectivas clássicas de Kaplan & Norton, integrados às métricas reais do banco de dados PostgreSQL 17.

---

## 1. Mapa Estratégico nas 4 Perspectivas

| Perspectiva | Objetivo Estratégico | Indicador Mensurável no Sistema (KPI) | Meta Operacional | Fonte de Dados Relacional |
| :--- | :--- | :--- | :---: | :--- |
| **1. Financeira e Atuarial** | Garantir sustentabilidade do Fundo Garantidor e retenção transacional (*Anti-Bypass*) | **Índice de Sinistralidade de Camada 3** ($\text{Débitos Camada 3} \div \text{Receita Mão de Obra}$) | $< 1,20\%$ (Limiar do *Circuit Breaker* `RN-MZ-04`) | `public.warranty_pool_ledger` |
| **1. Financeira e Atuarial** | Maximizar o volume bruto transacionado (GMV) com transparência de insumos | **Proporção Auditada no Smart Split** ($M \le 0,60 \cdot \text{Gross}$ com nota fiscal anexada) | $100\%$ de conformidade fiscal | `public.jobs` (`labor_amount`, `materials_amount`) |
| **2. Clientes e Patrimônio** | Assegurar resolução rápida de chamados de garantia e valorização imobiliária | **Taxa de Resolução em Camada 1 e Camada 2** (sem necessidade de acionar Socorrista da Camada 3) | $\ge 98,5\%$ dos serviços | `public.job_mediations` (`phase`) |
| **2. Clientes e Patrimônio** | Expandir a adoção do prontuário técnico predial | **Emissões do Passaporte do Imóvel (ABNT NBR 5674)** e Score de Vistoria Patrimonial | $\ge 80\text{ pts}$ de Score médio | `PropertyMaintenancePassportPdf` |
| **3. Processos Internos e Segurança** | Bloquear fraudes documentais, ataques Sybil e reciclagem de evidências | **Taxa de Rejeição Automática de Evidências Adulteradas (`dHash` $\le 5$ / EXIF / Anti-Monitor)** | $100\%$ de bloqueio determinístico | `public.forensic_certificates` + `public.profiles` |
| **3. Processos Internos e Segurança** | Cumprir o SLA de resposta em mediação técnica | **Tempo Médio de Resposta na 4ª Aba ("Em Mediação")** | $\le 4\text{ horas}$ úteis (`RN-CAM-02`) | `public.job_mediations` (`sla_deadline_at`) |
| **4. Aprendizado, Tecnologia e Qualidade** | Manter excelência de engenharia, baixa latência e cobertura de testes | **Cobertura de Testes Automatizados e Estabilidade de Renderização** | **529 testes Dart**, **577 asserções SQL**, **0 issues** e $60\text{ FPS}$ | GitHub Actions (`ci.yml`) |

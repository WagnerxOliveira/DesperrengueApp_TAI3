# Runbook Cirúrgico de Virada — `SANDBOX_PRE_CNPJ` para `PRODUCTION_SLU` (`D-30` a `D+0`)

> **Regra de Ouro:** Você **NÃO** abre CNPJ enquanto os **4 Critérios do Sinal Verde** não estiverem simultaneamente cumpridos no painel `Conta -> Semáforo SLU` do aplicativo **Desperrengue CEO**. Hoje o custo fixo da operação em homologação é **R\$ 0,00**.

Documentos correlatos neste pacote:
- [Minuta do Contrato Social SLU — Poços de Caldas / MG](./01_MINUTA_CONTRATO_SOCIAL_SLU_POCOS_DE_CALDAS.md)
- [Cláusula-Mandato Mercantil (Art. 653 CC) — Termos de Uso](./02_CLAUSULA_MANDATO_TERMOS_DE_USO_ART_653_CC.md)
- [Manual Técnico do Contador — CPC 47, Anexo III & NFS-e Poços de Caldas](./03_MANUAL_TECNICO_CONTADOR_CPC47_ANEXO_III_POCOS_MG.md)

---

## 1. Contas que Você Pode Criar AGORA (Sem CNPJ · Custo R\$ 0,00)

Enquanto estamos em `SANDBOX_PRE_CNPJ`, caso deseje testar webhooks e transferências externas além do simulador determinístico interno já embutido no cofre:

1. **Asaas Sandbox (100% Gratuito, aceita cadastro de desenvolvedor com CPF, separado da Produção):**
   - Acesse `https://sandbox.asaas.com` (ambiente isolado de testes — não gera cobrança real nem exige CNPJ).
   - Gere sua chave de API de testes em *Integrações -> Chaves de API* (`ASAAS_SANDBOX_API_KEY`).
   - Em *Integrações -> Webhooks* e *Mecanismos de Segurança*, aponte para a Edge Function `https://<PROJECT_REF>.supabase.co/functions/v1/asaas-webhook-guard` informando um segredo exclusivo de 32 a 64 caracteres (`ASAAS_WEBHOOK_AUTH_TOKEN`, estritamente diferente da `ASAAS_SANDBOX_API_KEY`).
2. **Efí Bank — Ambiente de Homologação PIX mTLS (Gratuito, permite emitir certificado `.p12` de homologação com CPF):**
   - Crie conta gratuita na Efí (`https://sejaefi.com.br`), acesse o painel *API -> Minhas Aplicações -> Homologação*, gere `Client_Id`, `Client_Secret` e baixe o certificado `.p12` gratuito de homologação.
3. **Portal de Desenvolvedores Banco Inter (Opcional agora; obrigatório no Marco `D-12` com CNPJ):**
   - Documentação e simulador em `https://developers.inter.co`. A emissão das credenciais definitivas de Conta PJ ocorre após a aprovação da conta **Inter Empresas** no Marco `D-12`.

---

## 2. Sequência Executiva dos 30 Dias (`Marco D-30` até `Marco D+0`)

| Marco | Gatilho | Ação Executiva | Desembolso Estimado |
| :--- | :--- | :--- | :---: |
| **Fase 0 (Hoje)** | Imediato | Operar e validar Tesouraria Bivalente em `SANDBOX_PRE_CNPJ` + prospectar os primeiros 15–25 profissionais em Poços de Caldas. | **R\$ 0,00** |
| **Marco `D-30`** | **4 Sinais Verdes ativos** no `Desperrengue CEO` | Contratar contador, entregar a [Minuta da SLU](./01_MINUTA_CONTRATO_SOCIAL_SLU_POCOS_DE_CALDAS.md) e o [Manual CPC 47](./03_MANUAL_TECNICO_CONTADOR_CPC47_ANEXO_III_POCOS_MG.md), protocolar na JUCEMG, pedir opção imediata pelo Simples Nacional (Anexo III) e Inscrição Municipal/NFS-e em Poços de Caldas. | Taxa JUCEMG + 1ª mensalidade |
| **Marco `D-15`** | Cartão CNPJ + Inscrição Municipal ativos | Emitir por videoconferência o **Certificado Digital `e-CNPJ Tipo A1`** (arquivo `.pfx` com validade de 12 meses — **jamais** comprar token físico A3). | `~R$ 150,00` |
| **Marco `D-12`** | Arquivo `.pfx` do `e-CNPJ A1` salvo em cofre seguro | **1º)** Abrir conta PJ gratuita no **Banco Inter Empresas** (Bolso 2 — Caixa Livre da SLU) e habilitar integração API PIX PJ.<br>**2º)** Abrir e validar conta PJ de Produção no **Asaas** (Bolso 1 — Liquidação e Split) vinculando o Inter Empresas como conta bancária titular. | **R\$ 0,00** |
| **Marco `D-5`** | Contas PJ aprovadas + certificados `.pem` gerados | Executar os 3 passos técnicos da **Cerimônia de Virada** abaixo e realizar 1 corrida real de ponta a ponta no valor de **R\$ 10,00** conferindo desvio de `0` centavos na conciliação tripla. | **R\$ 10,00** *(volta para a própria conta)* |
| **Marco `D+0`** | Corrida real `100%` conciliada | Liberar operação pública em Poços de Caldas / MG com zero mensalidade fixa bancária. | **R\$ 0,00 fixo de API** |

---

## 3. Cerimônia Técnica de Virada no Marco `D-5` (Passo a Passo Exato)

### Passo 1 — Extrair Certificado Público e Chave Privada PEM do `e-CNPJ A1` / Certificado mTLS do Banco
Em terminal local seguro (fora do repositório Git — **jamais versione arquivos `.pfx` ou `.pem`!**):

```bash
# 1. Extrai o certificado público PEM (sem chave privada)
openssl pkcs12 -in certificado_pj.pfx -out mtls_client_cert.pem -clcerts -nokeys

# 2. Extrai a chave privada PEM (para uso exclusivo em Supabase Edge Function Secrets)
openssl pkcs12 -in certificado_pj.pfx -out mtls_client_key.pem -nocerts -nodes
```

### Passo 2 — Gravar os Segredos Criptografados no Supabase (`Deno v2`)

```bash
npx supabase secrets set \
  CEO_TREASURY_OPERATING_MODE="PRODUCTION_SLU" \
  ASAAS_ENV="production" \
  ASAAS_API_KEY="<CHAVE_PRODUCAO_ASAAS>" \
  ASAAS_WEBHOOK_AUTH_TOKEN="<TOKEN_EXCLUSIVO_WEBHOOK_64_CHARS>" \
  MTLS_BANK_PROVIDER="INTER_MTLS" \
  MTLS_CLIENT_CERT_PEM="$(cat mtls_client_cert.pem)" \
  MTLS_CLIENT_KEY_PEM="$(cat mtls_client_key.pem)" \
  INTER_CLIENT_ID="<INTER_CLIENT_ID_PJ>" \
  INTER_CLIENT_SECRET="<INTER_CLIENT_SECRET_PJ>" \
  INTER_CONTA_CORRENTE="<NUMERO_CONTA_INTER_PJ>"

# Apague imediatamente as cópias temporárias em disco após subir para o cofre:
shred -u mtls_client_cert.pem mtls_client_key.pem 2>/dev/null || rm -f mtls_client_cert.pem mtls_client_key.pem
```

### Passo 3 — Executar a Migração SQL Única de Destravamento da SLU
Crie uma nova migração `supabase/migrations/YYYYMMDDHHMMSS_unlock_production_slu.sql` preenchendo os 14 dígitos reais do CNPJ da SLU e os 11 dígitos reais do CPF do sócio único (a função SQL valida matematicamente os dígitos verificadores Módulo-11 de ambos antes de aceitar a virada!):

```sql
SELECT private.ceo_activate_production_slu_mode(
  p_slu_cnpj_digits      := '00000000000100', -- Substituir pelos 14 dígitos reais do CNPJ da SLU
  p_sole_partner_cpf     := '00000000000',    -- Substituir pelos 11 dígitos reais do CPF de Wagner Oliveira
  p_slu_legal_name       := 'DESPERRENGUE TECNOLOGIA E PORTAL DE CONTEUDO LTDA',
  p_municipal_reg_pocos  := 'INSCRICAO_MUNICIPAL_POCOS',
  p_settlement_bank_code := '077'             -- 077 = Banco Inter S.A. | 364 = Efí S.A.
);
```

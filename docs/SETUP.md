# Guia de Configuração, Execução e Implantação (`SETUP.md`)

Este guia especifica o procedimento técnico determinístico para configurar o ambiente de desenvolvimento, aplicar as **21 migrações SQL** no Supabase, compilar o aplicativo Flutter (`v2.8.1+202611082`) e executar as suítes de verificação formal.

---

## 1. Pré-Requisitos de Ambiente

| Ferramenta | Versão Exigida | Finalidade Técnica |
| :--- | :--- | :--- |
| **Flutter SDK** | `3.47.x` (Dart `>=3.4.0 <4.0.0`) | Compilação multiplataforma (Android nativo e Web PWA) e execução das 26 suítes de teste. |
| **Node.js** | `>= 20.x` | Execução dos verificadores de integridade documental (`check-md-links.mjs`) e PDF (`test-dossie.mjs`). |
| **Supabase CLI** *(ou SQL Editor)* | `>= 1.200.x` | Aplicação ordenada das 21 migrações SQL e execução das 9 suítes de contrato (`577` asserções). |
| **Git** | `>= 2.40.x` | Controle de versão e integração com os *workflows* do GitHub Actions. |

---

## 2. Configuração do Banco de Dados e Storage (Supabase)

O diretório [`supabase/migrations/`](../supabase/migrations/) contém **21 migrações SQL idempotentes** numeradas cronologicamente de `20261009120000_initial_schema.sql` até `20261108120000_client_kyc_biometrics_and_ocr.sql`.

### 2.1. Aplicação Automatizada via Supabase CLI
```powershell
cd C:\00_Desperrengue
supabase link --project-ref <PROJECT_REF>
supabase db push
```

### 2.2. Aplicação e Verificação das Suítes de Contrato SQL
Após aplicar as migrações, executam-se os **9 arquivos de teste SQL** localizados em [`supabase/tests/`](../supabase/tests/) (`001_schema_smoke.sql` a `009_client_kyc_biometrics_and_ocr_smoke.sql`), totalizando **577 asserções formais** sobre tabelas, triggers `O(1)`, políticas RLS e funções `SECURITY DEFINER`.

---

## 3. Configuração de Variáveis de Ambiente (`app/.env`)

Crie o arquivo `app/.env` seguindo a especificação de [`app/lib/core/constants/env.dart`](../app/lib/core/constants/env.dart):

```powershell
cd C:\00_Desperrengue\app
Copy-Item .env.example .env
```

Preencha as chaves públicas do projeto Supabase:
```dotenv
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-chave-anon-publica
APP_REDIRECT_URL=https://wagnerxoliveira.github.io/DesperrengueApp_TAI3/
```

> **Segurança de Credenciais**: A chave `service_role` **nunca** deve ser incluída no cliente Flutter ou em `app/.env`. Operações privilegiadas são executadas exclusivamente por funções PostgreSQL `SECURITY DEFINER` auditadas no banco de dados.

---

## 4. Execução Local e Compilação de Artefatos

### 4.1. Instalação de Dependências e Execução Web (PWA)
```powershell
cd C:\00_Desperrengue\app
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

### 4.2. Compilação de APK Android para Dispositivos Físicos
```powershell
cd C:\00_Desperrengue\app
flutter build apk --release --dart-define-from-file=.env
```
> Para que a câmera frontal ao vivo (`_LiveFrontOvalLivenessCameraModal`) e o scanner documental ISO ID-1 (`DocumentGuidedScannerModal`) operem em navegadores móveis (PWA), o acesso deve ocorrer obrigatoriamente sob contexto seguro (`https://` ou `http://localhost`).

---

## 5. Verificação de Qualidade antes de Commit

```powershell
# 1. Análise estática (0 issues) e 529 testes automatizados do Flutter
cd C:\00_Desperrengue\app
flutter analyze
flutter test

# 2. Verificação de links Markdown (0 quebrados) e motor PDF (17 testes)
cd C:\00_Desperrengue
node scripts/check-md-links.mjs
node scripts/test-dossie.mjs
```

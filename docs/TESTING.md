# Estratégia de Testes e Verificação Formal — Desperrengue (`v2.8.1`)

Este documento descreve a arquitetura de verificação formal, a pirâmide de testes automatizados e o protocolo de auditoria *Red Team* do ecossistema **Desperrengue**.

---

## 1. Pirâmide de Testes Automatizados

```
               /\
              /  \        Camada 4 — Auditoria Red Team & Simulação de Ataques (Dart + SQL)
             /----\       Mitigação dos 6 Vetores de Golpe (RN-AF-01..14) e Biometria/OCR
            /      \
           /--------\     Camada 3 — Contratos SQL, Invariantes Contábeis & RLS (supabase/tests/)
          /          \    577 asserções formais em 9 suítes SQL sobre as 21 migrações
         /------------\
        /              \  Camada 2 — Testes de Widgets, Fluxos & Motor PDF (app/test/ + scripts/)
       /----------------\ Renderização de abas, Mediação, Scanner ISO ID-1 e 17 testes %PDF-1.4
      /                  \
     /--------------------\ Camada 1 — Testes Unitários de Domínio & Visão Computacional (app/test/)
                            Smart Split, RTS, dHash 64-bit, MAD 64x64, YCbCr e Face Match 128-D
```

---

## 2. Estado Atual Medido (`v2.8.1+202611082`)

Todas as métricas abaixo são aferidas automaticamente a cada *push* ou *Pull Request* pelo pipeline [`.github/workflows/ci.yml`](../.github/workflows/ci.yml):

| Camada de Verificação | Ferramenta / Executor | Arquivos de Teste | Volume Medido | Status |
| :--- | :--- | :---: | :---: | :---: |
| **Análise Estática Dart** | `flutter analyze` (`flutter_lints`) | Código-fonte integral em `app/lib/` e `app/test/` | **0 issues** | ✅ 100% |
| **Testes Unitários, Widgets, CV e Red Team** | `flutter test` | **26 arquivos** em `app/test/` | **529 testes** | ✅ 529 / 529 |
| **Invariantes SQL, RPCs e Políticas RLS** | `supabase/tests/*.sql` | **9 arquivos** em `supabase/tests/` | **577 asserções** | ✅ 577 / 577 |
| **Motor de Geração PDF e Dossiê** | `node scripts/test-dossie.mjs` | `scripts/test-dossie.mjs` + `app/test/property_maintenance_passport_test.dart` | **17 testes Node + suíte Dart** | ✅ 100% |
| **Integridade de Links da Documentação** | `node scripts/check-md-links.mjs` | Todos os arquivos `.md` do repositório | **0 links quebrados** | ✅ 100% |

---

## 3. Catálogo das 26 Suítes de Teste em `app/test/`

| Arquivo de Teste | Domínio Técnico Verificado |
| :--- | :--- |
| [`red_team_warranty_and_kyc_forensics_test.dart`](../app/test/red_team_warranty_and_kyc_forensics_test.dart) | **Protocolo Red Team completo**: ataque de foto de monitor VS Code (`blueMonitorRatio`), tentativa de foto idêntica Frente/Verso (`dHash` + `MAD`), Face Match multi-ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em $[0\%, 100\%]$, divergência nominal OCR, *bypass* de material $>60\%$, foto com EXIF de WhatsApp, reciclagem de evidência (`Hamming <= 5`), cálculo de $RTS$ e cascata *Waterfall*. |
| [`fintech_warranty_security_test.dart`](../app/test/fintech_warranty_security_test.dart) | Invariantes contábeis do `SmartSplitBreakdown` ($13.5\% + 1.5\%$ em mão de obra e $0\%$ em peças), ponto de equilíbrio atuarial ($66.67$), máquina de estados da 4ª aba **"Em Mediação"**, modal de PIN de 4 dígitos, carteira bipartida e `PerceptualHashGuard`. |
| [`dossier_test.dart`](../app/test/dossier_test.dart) | Cálculo determinístico do Score de Vistoria Patrimonial, ausência de dados fictícios (*Zero Fake Data*) e geração binária de cabeçalhos `%PDF-1.4` em conformidade com a ABNT NBR 5674 e Lei 8.245/91. |
| [`ui_polish_test.dart`](../app/test/ui_polish_test.dart) | Verificação geométrica e cromática dos ícones adaptativos Android One UI (zona segura de 66%), iOS, PWA e polimento visual. |
| [`account_screens_test.dart`](../app/test/account_screens_test.dart) | Fluxos de login, cadastro, confirmação de e-mail, recuperação de senha e exclusão escopada de conta LGPD (`delete_own_account_scoped`). |
| [`offboarding_boot_theme_test.dart`](../app/test/offboarding_boot_theme_test.dart) | Portões de inicialização (`BootGate` / `UpdateGate`), temas e encerramento de perfil. |
| [`tag_alias_parity_test.dart`](../app/test/tag_alias_parity_test.dart) | Serialização das 33 categorias de serviço, sinônimos de busca e normalização de tags. |
| [`client_flow_widgets_test.dart`](../app/test/client_flow_widgets_test.dart) | Transições completas entre abertura de chamado, envio de proposta, aceite, conclusão e avaliação. |
| [`review_rules_test.dart`](../app/test/review_rules_test.dart) | Avaliações 1:1 pós-serviço, média ponderada de estrelas e regras de reputação. |
| [`chat_test.dart`](../app/test/chat_test.dart) | Mensageria assíncrona vinculada à OS, recibos de leitura e central de notificações. |
| *(Demais 16 suítes em `app/test/`)* | Validações de *deep links*, `UpdateGate`, `wallet_test.dart`, `scheduling_test.dart`, `smart_triage_test.dart`, `precise_geocoder_test.dart`, `achievements_test.dart` e *onboarding*. |

---

## 4. Catálogo das 9 Suítes de Contrato SQL em `supabase/tests/`

As suítes localizadas em [`supabase/tests/`](../supabase/tests/) validam estaticamente e transacionalmente as **21 migrações SQL** (`577` asserções formais):

1. [`security_smoke.sql`](../supabase/tests/security_smoke.sql): Tabelas nucleares, chaves estrangeiras, políticas RLS base, isolamento do bucket privado `pro-verifications`, invariantes de `warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations`, `forensic_certificates` e KYC biométrico/OCR.
2. [`client_wallet_smoke.sql`](../supabase/tests/client_wallet_smoke.sql): Ledger de carteira, retenção em maturação e garantias financeiras.
3. [`scheduled_start_smoke.sql`](../supabase/tests/scheduled_start_smoke.sql): Agendamento de serviços, chat e dossiê técnico.
4. [`category_match_smoke.sql`](../supabase/tests/category_match_smoke.sql): Pareamento de categorias, ordens e busca geoespacial.
5. [`expanded_categories_smoke.sql`](../supabase/tests/expanded_categories_smoke.sql): Catálogo expandido das 33 categorias residenciais.
6. [`review_system_smoke.sql`](../supabase/tests/review_system_smoke.sql): Sistema de avaliações 1:1 e cálculo de reputação.
7. [`achievements_smoke.sql`](../supabase/tests/achievements_smoke.sql): Conquistas e gamificação patrimonial/profissional.
8. [`offboarding_showcase_smoke.sql`](../supabase/tests/offboarding_showcase_smoke.sql): Vitrine de portfólio e encerramento de ciclo.
9. [`scoped_deletion_smoke.sql`](../supabase/tests/scoped_deletion_smoke.sql): Exclusão escopada LGPD (`delete_own_account_scoped`) e preservação de histórico contábil.

---

## 5. Comandos de Execução Local

```powershell
# 1. Executar análise estática e os 529 testes automatizados do Flutter
cd C:\00_Desperrengue\app
flutter analyze
flutter test

# 2. Executar especificamente a suíte Red Team de Garantia, Antifraude e Biometria/OCR
flutter test test/red_team_warranty_and_kyc_forensics_test.dart test/fintech_warranty_security_test.dart

# 3. Verificar integridade de todos os links Markdown e gerador de PDF na raiz
cd C:\00_Desperrengue
node scripts/check-md-links.mjs
node scripts/test-dossie.mjs
```

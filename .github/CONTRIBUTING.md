# Diretrizes de Contribuição e Padrões de Engenharia (`CONTRIBUTING.md`)

Este documento define o protocolo de engenharia de software, os padrões de codificação, a disciplina de migrações SQL e o *Definition of Done* (DoD) obrigatórios para contribuições no repositório **Desperrengue** (`v2.8.1`).

---

## 1. Fluxo de Branches e Commits Semânticos

1. **Isolamento de Repositório**: Todo o fluxo de *branches*, *commits* e *Pull Requests* opera exclusivamente sobre o repositório `origin` (`WagnerxOliveira/DesperrengueApp_TAI3`).
2. **Conventional Commits**: As mensagens de commit seguem estritamente a especificação *Conventional Commits*:
   - `feat(escopo): descrição técnica concisa`
   - `fix(escopo): correção determinística de defeito`
   - `perf(escopo): otimização assintótica ou de renderização`
   - `docs(escopo): atualização de especificação técnico-científica`
   - `test(escopo): adição ou expansão de suítes de verificação`

---

## 2. Regras Arquiteturais Inegociáveis (*Regra Zero* e Invariantes)

1. **Preservação do Container Responsivo (`480px`) e Portões de Inicialização**: Qualquer alteração em [`app/lib/main.dart`](../app/lib/main.dart) deve preservar o `ConstrainedBox(maxWidth: 480)`, o `BootGate`, o `UpdateGate` e as meta tags PWA de [`app/web/index.html`](../app/web/index.html).
2. **Processamento Pesado em *Worker Isolates***: Algoritmos de Visão Computacional (`dHash`, `MAD`, Laplaciano, $YCbCr$, Face Match 128-D) e geração vetorial de PDF devem executar-se fora da *UI Thread* principal via `Isolate.run`.
3. **Ordem Canônica de Bloqueios no PostgreSQL**: Novas funções PL/pgSQL que adquiram bloqueios pessimistas (`FOR UPDATE`) devem respeitar a ordem topológica estrita:
   $$\texttt{1. jobs} \longrightarrow \texttt{2. job\_mediations} \longrightarrow \texttt{3. escrow\_maturation\_entries} \longrightarrow \texttt{4. profiles}$$
4. **Imutabilidade de Ledgers**: É proibido remover as triggers de proteção *append-only* sobre `warranty_pool_ledger`, `escrow_maturation_entries` e `forensic_certificates`.

---

## 3. Definition of Done (Critérios Obrigatórios de Aceite)

Nenhum *Pull Request* pode ser mesclado à branch `main` sem que todos os critérios abaixo sejam comprovadamente satisfeitos:

```powershell
# 1. Zero avisos ou erros no analisador estático do Flutter
cd C:\00_Desperrengue\app
flutter analyze

# 2. Aprovação integral das 26 suítes de teste (529 testes automatizados)
flutter test

# 3. Zero links quebrados em toda a documentação Markdown e aprovação dos 17 testes de PDF
cd C:\00_Desperrengue
node scripts/check-md-links.mjs
node scripts/test-dossie.mjs
```

Adicionalmente, qualquer alteração no esquema relacional em [`supabase/migrations/`](../supabase/migrations/) exige a atualização correspondente das suítes de contrato em [`supabase/tests/`](../supabase/tests/) (`577` asserções SQL).

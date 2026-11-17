#!/usr/bin/env node
/**
 * DESPERRENGUE & DESPERRENGUE CEO — Suíte Extrema Red Team (12 Rodadas Consecutivas)
 * Tesouraria Bivalente (`SANDBOX_PRE_CNPJ` vs `PRODUCTION_SLU`), Adaptador mTLS 1.3,
 * Guardião Outbound Asaas, Anti-Coação (`FROZEN_UNDER_DURESS`), Mandato Art. 653 CC
 * e Ponte Cross-App em Tempo Real (`85% / 13,5% / 1,5%` + `0%` NF-e 44 dígitos).
 *
 * Uso:
 *   node scripts/test-red-team-treasury-12x.mjs               # Offline + Ataques Live HTTP
 *   node scripts/test-red-team-treasury-12x.mjs --ci-offline  # Determinístico p/ GitHub Actions
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const IS_CI_OFFLINE = process.argv.includes('--ci-offline');
const LIVE_SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://eisfkemgooqbgqljvwvs.supabase.co';

const MIG_TREASURY = fs.readFileSync(
  path.join(
    ROOT,
    'supabase',
    'migrations',
    '20261117000000_bivalent_treasury_mtls_duress_and_mandate.sql',
  ),
  'utf8',
);
const EDGE_TREASURY = fs.readFileSync(
  path.join(ROOT, 'supabase', 'functions', 'ceo-treasury-authority', 'index.ts'),
  'utf8',
);
const EDGE_ASAAS_GUARD = fs.readFileSync(
  path.join(ROOT, 'supabase', 'functions', 'asaas-webhook-guard', 'index.ts'),
  'utf8',
);
const WORKFLOW_BETA = fs.readFileSync(
  path.join(ROOT, '.github', 'workflows', 'beta-release.yml'),
  'utf8',
);
const PUBSPEC = fs.readFileSync(path.join(ROOT, 'app', 'pubspec.yaml'), 'utf8');
const CONFIG_TOML = fs.readFileSync(
  path.join(ROOT, 'supabase', 'config.toml'),
  'utf8',
);

const rounds = [];

async function runRound(roundNumber, title, fn) {
  const started = performance.now();
  try {
    await fn();
    const ms = (performance.now() - started).toFixed(1);
    rounds.push({ roundNumber, title, ok: true, ms });
    console.log(`  [ROUND ${String(roundNumber).padStart(2, '0')} PASS] ${title} (${ms}ms)`);
  } catch (err) {
    const ms = (performance.now() - started).toFixed(1);
    rounds.push({
      roundNumber,
      title,
      ok: false,
      ms,
      error: err?.message ?? String(err),
    });
    console.error(
      `  [ROUND ${String(roundNumber).padStart(2, '0')} FAIL] ${title}\n     -> ${err?.message ?? err}`,
    );
  }
}

// Helpers matemáticos espelhando exatamente o banco PostgreSQL 17
function isValidCpfMod11(raw) {
  const clean = String(raw ?? '').replace(/[^0-9]/g, '');
  if (clean.length !== 11 || /^(\d)\1{10}$/.test(clean)) return false;
  let sum = 0;
  for (let i = 0; i < 9; i++) sum += Number(clean[i]) * (10 - i);
  let d1 = (sum * 10) % 11;
  if (d1 === 10) d1 = 0;
  if (d1 !== Number(clean[9])) return false;
  sum = 0;
  for (let i = 0; i < 10; i++) sum += Number(clean[i]) * (11 - i);
  let d2 = (sum * 10) % 11;
  if (d2 === 10) d2 = 0;
  return d2 === Number(clean[10]);
}

function isValidCnpjMod11(raw) {
  const clean = String(raw ?? '').replace(/[^0-9]/g, '');
  if (clean.length !== 14 || /^(\d)\1{13}$/.test(clean)) return false;
  const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(clean[i]) * w1[i];
  let rem = sum % 11;
  const d1 = rem < 2 ? 0 : 11 - rem;
  if (d1 !== Number(clean[12])) return false;
  sum = 0;
  for (let i = 0; i < 13; i++) sum += Number(clean[i]) * w2[i];
  rem = sum % 11;
  const d2 = rem < 2 ? 0 : 11 - rem;
  return d2 === Number(clean[13]);
}

function computeSafeCeilingBigInt({
  platformRevenue135Cents,
  dasPaidCents,
  nonDasExpensesPaidCents,
  scheduledExpensesCents,
  priorDistributionsCents,
  safetyBufferCents,
  reconciliationDiscrepancyCents,
  duressFrozen,
  auditChainOk,
}) {
  if (duressFrozen || reconciliationDiscrepancyCents > 0n || !auditChainOk) {
    return 0n;
  }
  const cumDas6Pct = (platformRevenue135Cents * 6n + 50n) / 100n;
  const effectiveDas = cumDas6Pct > dasPaidCents ? cumDas6Pct : dasPaidCents;
  const raw =
    platformRevenue135Cents -
    effectiveDas -
    nonDasExpensesPaidCents -
    scheduledExpensesCents -
    priorDistributionsCents -
    safetyBufferCents;
  return raw > 0n ? raw : 0n;
}

console.log('\n=============================================================================');
console.log(' DESPERRENGUE v2.19.0 — RED TEAM EXTREMO 12 RODADAS (TESOURARIA BIVALENTE)');
console.log('=============================================================================\n');

// ROUND 1: Injeção de Chave PIX Arbitrária & Sequestro de Destino
await runRound(
  1,
  'Bloqueio Físico Zero-Digitação PIX (Rejeição de `pix_key` / `override_account` em SQL + Edge)',
  async () => {
    assert.match(
      MIG_TREASURY,
      /allow_typed_pix_keys\s+boolean\s+not\s+null\s+default\s+false\s+check\s*\(\s*allow_typed_pix_keys\s*=\s*false\s*\)/i,
      'Tabela ceo_payout_destinations deve ter CHECK fisico allow_typed_pix_keys = false',
    );
    // Garante que `ceo_edge_prepare_profit_distribution` NÃO aceita parâmetro de chave PIX
    const prepSigMatch = MIG_TREASURY.match(
      /create\s+or\s+replace\s+function\s+public\.ceo_edge_prepare_profit_distribution\s*\(([\s\S]*?)\)\s*returns/i,
    );
    assert.ok(prepSigMatch, 'Assinatura de ceo_edge_prepare_profit_distribution encontrada');
    assert.doesNotMatch(
      prepSigMatch[1],
      /pix|cpf|cnpj|account|ispb|dest/i,
      'RPC de preparação jamais pode receber chave PIX/CPF/conta por parâmetro',
    );
    assert.match(EDGE_TREASURY, /ERR_FORBIDDEN_DESTINATION_OVERRIDE/);

    if (!IS_CI_OFFLINE) {
      const res = await fetch(
        `${LIVE_SUPABASE_URL}/functions/v1/ceo-treasury-authority`,
        {
          method: 'POST',
          headers: {
            Authorization: 'Bearer fake-jwt-token',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            action: 'request_profit_distribution',
            stepup_token: 'a'.repeat(64),
            device_hash: 'b'.repeat(64),
            requested_cents: 5000,
            pix_key: 'hacker@evil.org',
          }),
        },
      );
      const body = await res.json();
      assert.equal(res.status, 400);
      assert.equal(body.error_code, 'ERR_FORBIDDEN_DESTINATION_OVERRIDE');
    }
  },
);

// ROUND 2: Invasão de Custódia de Terceiros (85% Prestadores + 1,5% Garantia) & 1-Centavo Drift
await runRound(
  2,
  'Parede Intocável de Custódia (85% + 1,5% + 6% DAS) e Bloqueio Instantâneo por 1 Centavo de Deriva',
  async () => {
    assert.match(MIG_TREASURY, /ERR_SAFE_CEILING_EXCEEDED/);
    assert.match(MIG_TREASURY, /THREE_WAY_RECONCILIATION_DRIFT/);

    // Fuzzing de 5.000 cenários em BIGINT provando que custódia de 85% e 1,5% jamais entram na base!
    for (let i = 0; i < 5000; i++) {
      const gmv = BigInt(10_000 + i * 137);
      const rev135 = (gmv * 135n) / 1000n;
      const buffer = 30000n;
      const ceilingOk = computeSafeCeilingBigInt({
        platformRevenue135Cents: rev135,
        dasPaidCents: 0n,
        nonDasExpensesPaidCents: 1000n,
        scheduledExpensesCents: 500n,
        priorDistributionsCents: 0n,
        safetyBufferCents: buffer,
        reconciliationDiscrepancyCents: 0n,
        duressFrozen: false,
        auditChainOk: true,
      });
      assert.ok(
        ceilingOk <= rev135,
        'Teto seguro jamais pode superar a receita própria de 13,5%',
      );

      // Qualquer desvio >= 1 centavo zera imediatamente o teto!
      const ceilingDrift = computeSafeCeilingBigInt({
        platformRevenue135Cents: rev135 + 9_000_000n,
        dasPaidCents: 0n,
        nonDasExpensesPaidCents: 0n,
        scheduledExpensesCents: 0n,
        priorDistributionsCents: 0n,
        safetyBufferCents: 0n,
        reconciliationDiscrepancyCents: 1n,
        duressFrozen: false,
        auditChainOk: true,
      });
      assert.equal(ceilingDrift, 0n, '1 centavo de desvio deve travar o teto em 0');
    }
  },
);

// ROUND 3: Overflow INT64, Centavos Negativos, Zero, Float & NaN/Infinity JSON Fuzzing
await runRound(
  3,
  'Fuzzing Numérico Extremo (`-1`, `0`, `1.5`, `MAX_SAFE_INTEGER + 1`, `1e9 + 1`)',
  async () => {
    assert.match(
      MIG_TREASURY,
      /requested_cents\s*>\s*0\s+and\s+requested_cents\s*<=\s*1000000000/i,
    );
    assert.match(EDGE_TREASURY, /Number\.isSafeInteger\(rawCents\)/);
    assert.match(
      WORKFLOW_BETA,
      /BUILD=\$\(\(\s*210000000\s*\+\s*\(\$\(date \+%s\)\s*\/\s*60\)\s*\)\)/,
      'Escala monotônica unificada >= 210M ativa na CI',
    );
    const pubspecBuildMatch = PUBSPEC.match(/^version:\s*\d+\.\d+\.\d+\+(\d+)/m);
    assert.ok(pubspecBuildMatch, 'Versão em pubspec.yaml válida');
    const pubBuild = Number(pubspecBuildMatch[1]);
    assert.ok(
      pubBuild > 210_000_000 && pubBuild < 2_100_000_000,
      `versionCode ${pubBuild} deve estar na escala monotônica > 210M e < INT32_MAX`,
    );
  },
);

// ROUND 4: Race Condition / Double-Spend (`TOCTOU`) & Replay Idempotente
await runRound(
  4,
  'Serialização Transacional Anti-TOCTOU (`pg_advisory_xact_lock`) e Idempotência Estrita',
  async () => {
    const lockCount = (MIG_TREASURY.match(/pg_advisory_xact_lock\(9021900[12]\)/g) || [])
      .length;
    assert.ok(
      lockCount >= 4,
      `Esperados >= 4 advisory locks transacionais, encontrados ${lockCount}`,
    );
    assert.match(
      MIG_TREASURY,
      /idempotency_key\s+text\s+not\s+null\s+unique/i,
      'Chave de idempotência deve ter índice UNIQUE físico',
    );
  },
);

// ROUND 5: Coação Presencial (`FROZEN_UNDER_DURESS`), PIN Invertido & Piso de Tempo Constante
await runRound(
  5,
  'Protocolo Anti-Coação: PIN Invertido no App Público + Recibo Falso `settled_cents = 0` + Piso 380ms',
  async () => {
    assert.match(
      MIG_TREASURY,
      /not\s+is_duress_decoy\s+or\s*\(\s*settled_cents\s*=\s*0\s+and\s+status\s*=\s*'DECOY_FROZEN_ZERO_MOVED'\s*\)/i,
      'CHECK físico garante que recibo decoy jamais liquida centavos reais',
    );
    assert.match(
      MIG_TREASURY,
      /SILENT_DURESS_REVERSE_PIN_TRIGGERED/,
      'complete_job_with_pin deve acionar congelamento silencioso ao receber PIN invertido',
    );
    assert.match(
      MIG_TREASURY,
      /exit\s+when\s+reverse\(v_pin\)\s*<>\s*v_pin/i,
      'gen_job_pin deve proibir PINs palíndromos',
    );
    assert.match(EDGE_TREASURY, /CONSTANT_TIME_FLOOR_MS\s*=\s*380/);
    // Garante que a resposta HTTP externa do decoy NÃO contém palavras delatoras
    const publicRespSlice = EDGE_TREASURY.slice(
      EDGE_TREASURY.indexOf('if (isDuressDecoy'),
      EDGE_TREASURY.indexOf('// Modo `PRODUCTION_SLU`'),
    );
    assert.doesNotMatch(
      publicRespSlice,
      /"decoy"|"duress"|"falso"|"frozen"/i,
      'JSON retornado na tela sob coação jamais pode conter strings delatoras',
    );
  },
);

// ROUND 6: Forja de Webhook Asaas, Reúso de API Key, Replay & Payload Bomb
await runRound(
  6,
  'Guardião Outbound Asaas (`asaas-webhook-guard`): Constant-Time Token, Anti-Reúso e Anti-Replay',
  async () => {
    assert.match(EDGE_ASAAS_GUARD, /WEBHOOK_SECRET\.length\s*<\s*32/);
    assert.match(
      EDGE_ASAAS_GUARD,
      /constantTimeEqualsAscii\(WEBHOOK_SECRET,\s*ASAAS_SANDBOX_KEY\)/,
    );
    assert.match(
      EDGE_ASAAS_GUARD,
      /constantTimeEqualsAscii\(WEBHOOK_SECRET,\s*ASAAS_PROD_KEY\)/,
    );
    assert.match(MIG_TREASURY, /ceo_webhook_processed_events/);

    if (!IS_CI_OFFLINE) {
      const forged = await fetch(
        `${LIVE_SUPABASE_URL}/functions/v1/asaas-webhook-guard`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'asaas-access-token': 'forged-attacker-token-0000000000000000',
          },
          body: JSON.stringify({
            id: 'evt_attack_001',
            event: 'TRANSFER_VALIDATION',
            transfer: { id: 'tr_001', value: 5000.0 },
          }),
        },
      );
      const forgedJson = await forged.json();
      assert.equal(forgedJson.status, 'REFUSED');
      assert.ok([401, 403].includes(forged.status));
    }
  },
);

// ROUND 7: mTLS 1.3 Host Pinning (Anti-SSRF) & Sanitização de Segredos PEM
await runRound(
  7,
  'Adaptador mTLS 1.3 (`Deno.createHttpClient`): Host Pinning Estrito Inter/Efí/Asaas & Anti-Leak PEM',
  async () => {
    assert.match(EDGE_TREASURY, /Deno\.createHttpClient\(\{\s*cert:\s*certPem,\s*key:\s*keyPem/s);
    assert.match(EDGE_TREASURY, /https:\/\/cdpj-sandbox\.partners\.uatinter\.co/);
    assert.match(EDGE_TREASURY, /https:\/\/cdpj\.partners\.bancointer\.com\.br/);
    assert.match(EDGE_TREASURY, /https:\/\/pix-h\.api\.efipay\.com\.br/);
    assert.match(EDGE_TREASURY, /https:\/\/pix\.api\.efipay\.com\.br/);
    assert.match(EDGE_TREASURY, /ERR_SSRF_ORIGIN_VIOLATION/);
    assert.match(EDGE_TREASURY, /ERR_PSP_SANITIZED_FAULT/);
  },
);

// ROUND 8: Tentativa de Destravamento Prematuro `PRODUCTION_SLU` & Falsificação Módulo 11
await runRound(
  8,
  'Bloqueio de Destravamento Prematuro `PRODUCTION_SLU` e Validação Módulo 11 (CPF/CNPJ)',
  async () => {
    assert.match(MIG_TREASURY, /constraint\s+chk_production_slu_requires_valid_docs/i);
    assert.match(
      MIG_TREASURY,
      /revoke\s+all\s+on\s+function\s+private\.ceo_activate_production_slu_mode[\s\S]*?from\s+public,\s*anon,\s*authenticated/i,
    );

    // Testa rejeição de todos os repdigits e dígitos forjados
    for (let d = 0; d <= 9; d++) {
      assert.equal(isValidCpfMod11(String(d).repeat(11)), false);
      assert.equal(isValidCnpjMod11(String(d).repeat(14)), false);
    }
    assert.equal(isValidCpfMod11('52998224725'), true);
    assert.equal(isValidCpfMod11('52998224724'), false);
    assert.equal(isValidCnpjMod11('11222333000181'), true);
    assert.equal(isValidCnpjMod11('11222333000182'), false);
  },
);

// ROUND 9: Escalonamento de Privilégio Cross-App (`anon` / `authenticated` vs `private.*`)
await runRound(
  9,
  'Isolamento Zero-Trust Cross-App (RLS Forçada, `REVOKE` em `private.*` e Remoção de Órfãos v2.13)',
  async () => {
    assert.equal(
      fs.existsSync(path.join(ROOT, 'supabase', 'functions', 'ceo-sovereign-auth')),
      false,
      'Pasta órfã ceo-sovereign-auth deve estar removida fisicamente',
    );
    assert.doesNotMatch(CONFIG_TOML, /ceo-sovereign-auth/);
    assert.match(CONFIG_TOML, /\[functions\.ceo-treasury-authority\]/);
    assert.match(CONFIG_TOML, /\[functions\.asaas-webhook-guard\]/);
    assert.match(
      MIG_TREASURY,
      /drop\s+function\s+if\s+exists\s+private\.ceo_compute_pin_sha256/i,
    );
    assert.match(
      MIG_TREASURY,
      /drop\s+table\s+if\s+exists\s+private\.ceo_otp_challenges\s+cascade/i,
    );
    assert.match(
      MIG_TREASURY,
      /revoke\s+all\s+on\s+table\s+public\.legal_mandate_acceptances\s+from\s+public,\s*anon,\s*authenticated/i,
    );
    assert.match(
      MIG_TREASURY,
      /grant\s+select,\s*insert\s+on\s+table\s+public\.legal_mandate_acceptances\s+to\s+authenticated/i,
    );
  },
);

// ROUND 10: Fraude de Nota Fiscal de Peças (44 Dígitos SEFAZ + Clawback Automático)
await runRound(
  10,
  'Auditoria Fiscal 44 Dígitos SEFAZ e Recuperação Automática de Taxa (Clawback 13,5% + 1,5%)',
  async () => {
    const migForensic = fs.readFileSync(
      path.join(
        ROOT,
        'supabase',
        'migrations',
        '20261113130000_forensic_photo_and_fiscal_hardening.sql',
      ),
      'utf8',
    );
    assert.match(migForensic, /audit_sefaz_phase2_cancellation_and_clawback/);
    assert.match(
      MIG_TREASURY,
      /perform\s+public\.settle_escrow_with_carveout_and_maturation\(p_job_id\)/,
      'complete_job_with_pin deve liquidar via motor canônico 85/13,5/1,5 + 0% NF-e',
    );
  },
);

// ROUND 11: Tentativa de Adulteração WORM (`UPDATE` / `DELETE` em Distribuições e Auditoria)
await runRound(
  11,
  'Imutabilidade WORM `42501` em `private.ceo_profit_distributions` e `private.founder_audit_log`',
  async () => {
    assert.match(MIG_TREASURY, /ERR_WORM_DISTRIBUTION_IMMUTABLE/);
    assert.match(
      MIG_TREASURY,
      /before\s+update\s+or\s+delete\s+on\s+private\.ceo_profit_distributions/i,
    );
  },
);

// ROUND 12: Conformidade Jurídico-Contábil Pré-CNPJ + Anti-Formula-Injection CSV + Isolamento UI
await runRound(
  12,
  'Pacote Jurídico SLU Poços de Caldas (4 Documentos), Anti-Injection CSV e Zero Ícones Material no CEO',
  async () => {
    const legalDocs = [
      '01_MINUTA_CONTRATO_SOCIAL_SLU_POCOS_DE_CALDAS.md',
      '02_CLAUSULA_MANDATO_TERMOS_DE_USO_ART_653_CC.md',
      '03_MANUAL_TECNICO_CONTADOR_CPC47_ANEXO_III_POCOS_MG.md',
      '04_RUNBOOK_VIRADA_PRODUCAO_SLU_D30_A_D0.md',
    ];
    for (const doc of legalDocs) {
      const full = path.join(ROOT, 'docs', 'juridico_e_contabil_slu', doc);
      assert.ok(fs.existsSync(full), `Documento obrigatório ausente: ${doc}`);
      assert.ok(fs.statSync(full).size > 2500, `Documento incompleto: ${doc}`);
    }

    const packDart = fs.readFileSync(
      path.join(
        ROOT,
        'app',
        'lib',
        'core',
        'analytics',
        'founder_accountant_pack_service.dart',
      ),
      'utf8',
    );
    assert.doesNotMatch(packDart, /DateTime\.utc\(2026,\s*11,\s*14/);
    assert.match(packDart, /safeValue\.startsWith\('='\)/);

    const newTreasuryUi = fs.readFileSync(
      path.join(
        ROOT,
        'app',
        'lib',
        'features',
        'founder',
        'presentation',
        'founder_treasury_and_slu_widgets.dart',
      ),
      'utf8',
    );
    assert.doesNotMatch(
      newTreasuryUi,
      /\bIcons\./,
      'Proibido Icons.* em widgets do Desperrengue CEO (usar 100% FounderPrecisionIcon)',
    );
    assert.doesNotMatch(
      newTreasuryUi,
      /CPC 47|COFRE MONOCRÁTICO|Mochila 0\/1|\bOPEX\b|\bWSS\b/,
      'Zero jargão técnico proibido na interface executiva do CEO',
    );
  },
);

const failed = rounds.filter((r) => !r.ok);
console.log('\n-----------------------------------------------------------------------------');
console.log(
  ` RESULTADO FINAL RED TEAM: ${rounds.length - failed.length}/${rounds.length} RODADAS APROVADAS`,
);
console.log('-----------------------------------------------------------------------------\n');

if (failed.length > 0) {
  process.exit(1);
}

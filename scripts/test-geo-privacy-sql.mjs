#!/usr/bin/env node
/**
 * DESPERRENGUE — Verificador Estático, Cumulativo Zero-Trust e Monte Carlo Geométrico
 * Alvos:
 *   - supabase/migrations/20261113100000_temporal_geo_privacy_lock.sql
 *   - supabase/migrations/20261113110000_security_hardening_audit.sql
 *   - supabase/migrations/*.sql (auditoria cumulativa de RLS/Grants/search_path)
 *   - supabase/tests/geo_privacy_lock.sql & supabase/tests/security_smoke.sql
 *
 * Uso:
 *   node scripts/test-geo-privacy-sql.mjs
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const MIGRATIONS_DIR = path.join(ROOT, 'supabase', 'migrations');
const TESTS_DIR = path.join(ROOT, 'supabase', 'tests');

const MIG_GEO = path.join(MIGRATIONS_DIR, '20261113100000_temporal_geo_privacy_lock.sql');
const MIG_SEC = path.join(MIGRATIONS_DIR, '20261113110000_security_hardening_audit.sql');
const MIG_JOBS_UPDATED = path.join(MIGRATIONS_DIR, '20261113125000_jobs_updated_at.sql');
const MIG_FORENSIC = path.join(MIGRATIONS_DIR, '20261113130000_forensic_photo_and_fiscal_hardening.sql');
const TEST_GEO = path.join(TESTS_DIR, 'geo_privacy_lock.sql');
const TEST_SMOKE = path.join(TESTS_DIR, 'security_smoke.sql');
const TEST_FORENSIC = path.join(TESTS_DIR, 'forensic_photo_and_fiscal.sql');

const results = [];
function check(name, fn) {
  try {
    fn();
    results.push({ ok: true, name });
    console.log(`  [PASS] ${name}`);
  } catch (err) {
    results.push({ ok: false, name, error: err?.message ?? String(err) });
    console.error(`  [FAIL] ${name}\n         ${err?.message ?? err}`);
  }
}

/**
 * Remove comentários (`--` e `/* ... * /`) e substitui literais `'...'` e `$tag$...$tag$`
 * por espaços preservando quebras de linha, permitindo checar parênteses fora de strings
 * e validar o balanceamento léxico completo de arquivos SQL/PLpgSQL.
 */
function lexSql(sql, label) {
  let i = 0;
  const n = sql.length;
  let parenDepth = 0;
  const stripped = [];

  while (i < n) {
    const ch = sql[i];
    const next = i + 1 < n ? sql[i + 1] : '';

    // Comentário de linha `-- ...`
    if (ch === '-' && next === '-') {
      while (i < n && sql[i] !== '\n') i++;
      continue;
    }

    // Comentário de bloco `/* ... */` (aninhável em PostgreSQL)
    if (ch === '/' && next === '*') {
      let depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (sql[i] === '/' && sql[i + 1] === '*') {
          depth++;
          i += 2;
        } else if (sql[i] === '*' && sql[i + 1] === '/') {
          depth--;
          i += 2;
        } else {
          if (sql[i] === '\n') stripped.push('\n');
          i++;
        }
      }
      assert.equal(depth, 0, `${label}: comentário /* ... */ não fechado`);
      continue;
    }

    // String simples `'...'` com escape `''`
    if (ch === "'") {
      stripped.push("''");
      i++;
      let closed = false;
      while (i < n) {
        if (sql[i] === "'") {
          if (sql[i + 1] === "'") {
            i += 2;
            continue;
          }
          closed = true;
          i++;
          break;
        }
        if (sql[i] === '\n') stripped.push('\n');
        i++;
      }
      assert.ok(closed, `${label}: literal de string simples não fechado`);
      continue;
    }

    // Dollar-quoting `$tag$...$tag$` (não confundir com parâmetro posicional `$1`)
    if (ch === '$') {
      const rest = sql.slice(i);
      const m = rest.match(/^\$([A-Za-z_][A-Za-z0-9_]*)?\$/);
      if (m) {
        const tag = m[0];
        const closeIdx = sql.indexOf(tag, i + tag.length);
        assert.notEqual(closeIdx, -1, `${label}: bloco dollar-quoted ${tag} não fechado`);
        const inner = sql.slice(i + tag.length, closeIdx);
        // Também valida recursivamente parênteses/strings dentro de blocos PL/pgSQL!
        lexInnerPlpgsql(inner, `${label} (${tag})`);
        const newlines = inner.match(/\n/g)?.length ?? 0;
        stripped.push('$$$$' + '\n'.repeat(newlines));
        i = closeIdx + tag.length;
        continue;
      }
    }

    if (ch === '(') parenDepth++;
    if (ch === ')') {
      parenDepth--;
      assert.ok(parenDepth >= 0, `${label}: parêntese ')' excedente próximo ao offset ${i}`);
    }

    stripped.push(ch);
    i++;
  }

  assert.equal(parenDepth, 0, `${label}: parênteses desbalanceados (saldo=${parenDepth})`);
  return stripped.join('');
}

function lexInnerPlpgsql(inner, label) {
  let i = 0;
  const n = inner.length;
  let parenDepth = 0;

  while (i < n) {
    const ch = inner[i];
    const next = i + 1 < n ? inner[i + 1] : '';

    if (ch === '-' && next === '-') {
      while (i < n && inner[i] !== '\n') i++;
      continue;
    }
    if (ch === '/' && next === '*') {
      let depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (inner[i] === '/' && inner[i + 1] === '*') {
          depth++;
          i += 2;
        } else if (inner[i] === '*' && inner[i + 1] === '/') {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      assert.equal(depth, 0, `${label}: comentário interno /* */ não fechado`);
      continue;
    }
    if (ch === "'") {
      i++;
      let closed = false;
      while (i < n) {
        if (inner[i] === "'") {
          if (inner[i + 1] === "'") {
            i += 2;
            continue;
          }
          closed = true;
          i++;
          break;
        }
        i++;
      }
      assert.ok(closed, `${label}: literal de string interno não fechado`);
      continue;
    }
    if (ch === '$') {
      const m = inner.slice(i).match(/^\$([A-Za-z_][A-Za-z0-9_]*)?\$/);
      if (m) {
        const tag = m[0];
        const closeIdx = inner.indexOf(tag, i + tag.length);
        assert.notEqual(closeIdx, -1, `${label}: sub-bloco ${tag} não fechado`);
        i = closeIdx + tag.length;
        continue;
      }
    }
    if (ch === '(') parenDepth++;
    if (ch === ')') {
      parenDepth--;
      assert.ok(parenDepth >= 0, `${label}: ')' interno excedente no offset ${i}`);
    }
    i++;
  }

  assert.equal(parenDepth, 0, `${label}: parênteses internos desbalanceados (saldo=${parenDepth})`);
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const toRad = (deg) => (deg * Math.PI) / 180.0;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const rLat1 = toRad(lat1);
  const rLat2 = toRad(lat2);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rLat1) * Math.cos(rLat2) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000.0 * Math.asin(Math.min(1.0, Math.sqrt(a)));
}

function sqlGeoFuzzyCenter(secretKeyBuf, jobUuid, lat, lng) {
  const mac = crypto.createHmac('sha256', secretKeyBuf).update(jobUuid, 'utf8').digest();
  const u2 = mac[4] * 256 + mac[5];
  const radiusM = 500 + Math.trunc((u2 * 301) / 65536);

  if (lat === null || lng === null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return { lat: null, lng: null, radius_m: radiusM };
  }

  const u0 = mac[0] * 256 + mac[1];
  const u1 = mac[2] * 256 + mac[3];

  const offsetM = 151.0 + (u0 / 65535.0) * 198.0;
  const bearing = (u1 / 65536.0) * 2.0 * Math.PI;
  const angDist = offsetM / 6371000.0;

  const lat1 = (lat * Math.PI) / 180.0;
  const lng1 = (lng * Math.PI) / 180.0;

  const sinLat2 = Math.max(
    -1.0,
    Math.min(1.0, Math.sin(lat1) * Math.cos(angDist) + Math.cos(lat1) * Math.sin(angDist) * Math.cos(bearing))
  );
  const lat2 = Math.asin(sinLat2);
  const lng2 =
    lng1 +
    Math.atan2(
      Math.sin(bearing) * Math.sin(angDist) * Math.cos(lat1),
      Math.cos(angDist) - Math.sin(lat1) * Math.sin(lat2)
    );

  const degLat2 = (lat2 * 180.0) / Math.PI;
  const degLng2 = (lng2 * 180.0) / Math.PI;

  const outLat = Math.max(-90.0, Math.min(90.0, Number(degLat2.toFixed(6))));
  const outLng = Number(((((degLng2 + 540.0) % 360.0) - 180.0)).toFixed(6));

  return { lat: outLat, lng: outLng, radius_m: radiusM };
}

console.log('=== DESPERRENGUE — Verificação SQL Geo-Privacy Lock & Zero-Trust ===\n');

const geoSql = fs.readFileSync(MIG_GEO, 'utf8');
const secSql = fs.readFileSync(MIG_SEC, 'utf8');
const jobsUpdatedSql = fs.readFileSync(MIG_JOBS_UPDATED, 'utf8');
const forensicSql = fs.readFileSync(MIG_FORENSIC, 'utf8');
const testGeoSql = fs.readFileSync(TEST_GEO, 'utf8');
const testSmokeSql = fs.readFileSync(TEST_SMOKE, 'utf8');
const testForensicSql = fs.readFileSync(TEST_FORENSIC, 'utf8');

check('01. Arquivos obrigatórios existem e não estão vazios', () => {
  assert.ok(geoSql.length > 10_000, '20261113100000 deve ser completa');
  assert.ok(secSql.length > 10_000, '20261113110000 deve ser completa');
  assert.ok(jobsUpdatedSql.length > 500, '20261113125000 deve ser completa');
  assert.ok(forensicSql.length > 10_000, '20261113130000 deve ser completa');
  assert.ok(testGeoSql.length > 5_000, 'geo_privacy_lock.sql deve ser completa');
  assert.ok(testForensicSql.length > 5_000, 'forensic_photo_and_fiscal.sql deve ser completa');
});

check('02. Integridade léxica (strings, dollar-quotes, comentários, parênteses e transações)', () => {
  const strippedGeo = lexSql(geoSql, '20261113100000_temporal_geo_privacy_lock.sql');
  const strippedSec = lexSql(secSql, '20261113110000_security_hardening_audit.sql');
  const strippedJobsUpdated = lexSql(jobsUpdatedSql, '20261113125000_jobs_updated_at.sql');
  const strippedForensic = lexSql(forensicSql, '20261113130000_forensic_photo_and_fiscal_hardening.sql');
  const strippedTestGeo = lexSql(testGeoSql, 'supabase/tests/geo_privacy_lock.sql');
  const strippedSmoke = lexSql(testSmokeSql, 'supabase/tests/security_smoke.sql');
  const strippedTestForensic = lexSql(testForensicSql, 'supabase/tests/forensic_photo_and_fiscal.sql');

  assert.match(strippedGeo, /^\s*begin\s*;/i, '20261113100000 deve abrir com begin;');
  assert.match(strippedGeo, /commit\s*;\s*$/i, '20261113100000 deve encerrar com commit;');
  assert.match(strippedSec, /^\s*begin\s*;/i, '20261113110000 deve abrir com begin;');
  assert.match(strippedSec, /commit\s*;\s*$/i, '20261113110000 deve encerrar com commit;');
  assert.match(strippedJobsUpdated, /^\s*begin\s*;/i, '20261113125000 deve abrir com begin;');
  assert.match(strippedJobsUpdated, /commit\s*;\s*$/i, '20261113125000 deve encerrar com commit;');
  assert.match(strippedForensic, /^\s*begin\s*;/i, '20261113130000 deve abrir com begin;');
  assert.match(strippedForensic, /commit\s*;\s*$/i, '20261113130000 deve encerrar com commit;');
  assert.match(strippedTestGeo, /^\s*begin\s*;/i, 'geo_privacy_lock.sql deve abrir com begin;');
  assert.match(strippedTestGeo, /rollback\s*;\s*$/i, 'geo_privacy_lock.sql deve encerrar com rollback;');
  assert.match(strippedTestForensic, /^\s*begin\s*;/i, 'forensic_photo_and_fiscal.sql deve abrir com begin;');
  assert.match(strippedTestForensic, /rollback\s*;\s*$/i, 'forensic_photo_and_fiscal.sql deve encerrar com rollback;');
  assert.match(strippedSmoke, /rollback\s*;\s*$/i, 'security_smoke.sql deve encerrar com rollback;');
});

check('03. Idempotência estrita em 20261113100000, 20261113110000, 20261113125000 e 20261113130000', () => {
  for (const [label, content] of [
    ['20261113100000', lexSql(geoSql, 'geo')],
    ['20261113110000', lexSql(secSql, 'sec')],
    ['20261113125000', lexSql(jobsUpdatedSql, 'jobsUpdated')],
    ['20261113130000', lexSql(forensicSql, 'forensic')],
  ]) {
    const rawCreateTables = content.match(/\bcreate\s+table\s+(?!if\s+not\s+exists\b)/gi) ?? [];
    assert.equal(rawCreateTables.length, 0, `${label}: todo CREATE TABLE deve usar IF NOT EXISTS`);

    const rawCreateSchemas = content.match(/\bcreate\s+schema\s+(?!if\s+not\s+exists\b)/gi) ?? [];
    assert.equal(rawCreateSchemas.length, 0, `${label}: todo CREATE SCHEMA deve usar IF NOT EXISTS`);

    const rawCreateIndexes = content.match(/\bcreate\s+(?:unique\s+)?index\s+(?!if\s+not\s+exists\b)/gi) ?? [];
    assert.equal(rawCreateIndexes.length, 0, `${label}: todo CREATE INDEX deve usar IF NOT EXISTS`);

    const rawFunctions = content.match(/\bcreate\s+function\b/gi) ?? [];
    assert.equal(rawFunctions.length, 0, `${label}: toda função em migration deve usar CREATE OR REPLACE FUNCTION`);

    const rawViews = content.match(/\bcreate\s+view\b/gi) ?? [];
    assert.equal(rawViews.length, 0, `${label}: toda view em migration deve usar CREATE OR REPLACE VIEW`);

    for (const m of content.matchAll(/\bcreate\s+policy\s+("?[a-z0-9_]+"?)/gi)) {
      const pol = m[1].replace(/"/g, '');
      const dropRe = new RegExp(`drop\\s+policy\\s+if\\s+exists\\s+"?${pol}"?`, 'i');
      assert.match(content, dropRe, `${label}: policy ${pol} deve ter DROP POLICY IF EXISTS antes`);
    }

    for (const m of content.matchAll(/\bcreate\s+trigger\s+([a-z0-9_]+)/gi)) {
      const trg = m[1];
      const dropRe = new RegExp(`drop\\s+trigger\\s+if\\s+exists\\s+${trg}\\b`, 'i');
      assert.match(content, dropRe, `${label}: trigger ${trg} deve ter DROP TRIGGER IF EXISTS antes`);
    }
  }
});

check('04. Zero GRANT perigoso para anon/public e search_path obrigatório em SECURITY DEFINER', () => {
  for (const [label, sql, minSecDef] of [
    ['20261113100000', geoSql, 8],
    ['20261113110000', secSql, 8],
    ['20261113125000', jobsUpdatedSql, 0],
    ['20261113130000', forensicSql, 4],
  ]) {
    const stripped = lexSql(sql, label);
    assert.doesNotMatch(
      stripped,
      /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i,
      `${label}: proibido conceder GRANT para anon ou public`
    );
    assert.doesNotMatch(
      stripped,
      /\brevoke\s+insert\s*,\s*update\s*\(/i,
      `${label}: proibido combinar 'revoke insert' sem colunas com 'update (...)' (revogaria INSERT da tabela inteira)`
    );

    const fnBlockRegex =
      /create\s+or\s+replace\s+function\s+(public\.[a-z0-9_]+)\s*\(([\s\S]*?)\)\s*returns[\s\S]*?\bas\s+\$\$[\s\S]*?\$\$\s*;/gi;
    let count = 0;
    for (const m of sql.matchAll(fnBlockRegex)) {
      const fnName = m[1];
      const header = m[0].split(/\bas\s+\$\$/i)[0];
      assert.match(
        header,
        /\bset\s+search_path\s*=\s*(?:public(?:\s*,\s*extensions)?|'')/i,
        `${label}: função ${fnName} sem SET search_path seguro`
      );
      if (/\bsecurity\s+definer\b/i.test(header)) {
        count++;
        const body = m[0].slice(m[0].toLowerCase().indexOf('as $$'));
        const bodyStripped = lexSql(body, `${label}:${fnName}`);
        assert.doesNotMatch(
          bodyStripped,
          /\bcurrent_user\b/i,
          `${label}: função SECURITY DEFINER ${fnName} NÃO pode usar current_user (sempre seria o owner postgres)`
        );
      }
      const revokeRe = new RegExp(
        `revoke\\s+all\\s+on\\s+function\\s+${fnName.replace('.', '\\.')}\\s*\\([\\s\\S]*?\\)\\s*from\\s+public\\s*,\\s*anon`,
        'i'
      );
      assert.match(sql, revokeRe, `${label}: função ${fnName} deve ter REVOKE ALL FROM public, anon`);
    }
    assert.ok(count >= minSecDef, `${label}: esperado auditar >= ${minSecDef} funções SECURITY DEFINER (auditadas: ${count})`);
  }
});

check('05. Cofres `private.geo_privacy_secrets` e `private.job_forensic_secrets` blindados', () => {
  assert.match(geoSql, /create\s+schema\s+if\s+not\s+exists\s+private\s*;/i);
  assert.match(geoSql, /revoke\s+all\s+on\s+schema\s+private\s+from\s+public,\s*anon,\s*authenticated\s*;/i);
  assert.match(geoSql, /alter\s+table\s+private\.geo_privacy_secrets\s+enable\s+row\s+level\s+security\s*;/i);
  assert.match(geoSql, /alter\s+table\s+private\.geo_privacy_secrets\s+force\s+row\s+level\s+security\s*;/i);
  assert.match(
    geoSql,
    /revoke\s+all\s+on\s+table\s+private\.geo_privacy_secrets\s+from\s+public,\s*anon,\s*authenticated\s*;/i
  );
  assert.match(geoSql, /gen_random_bytes\s*\(\s*32\s*\)/i);
  assert.doesNotMatch(geoSql, /create\s+policy[\s\S]{0,120}?private\.geo_privacy_secrets/i);

  assert.match(secSql, /alter\s+table\s+private\.job_forensic_secrets\s+enable\s+row\s+level\s+security\s*;/i);
  assert.match(secSql, /alter\s+table\s+private\.job_forensic_secrets\s+force\s+row\s+level\s+security\s*;/i);
  assert.match(
    secSql,
    /revoke\s+all\s+on\s+table\s+private\.job_forensic_secrets\s+from\s+public,\s*anon,\s*authenticated\s*;/i
  );
});

check('06. Auditoria cumulativa de RLS em TODAS as tabelas `public.*` do repositório (27 migrations)', () => {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  assert.ok(files.length >= 27, `Esperado >= 27 migrations, encontradas ${files.length}`);

  const allSql = files.map((f) => fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8')).join('\n');
  const tables = new Set();
  for (const m of allSql.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z0-9_]+)/gi)) {
    tables.add(m[1].toLowerCase());
  }
  assert.ok(tables.size >= 20, `Esperado >= 20 tabelas public.*, encontradas ${tables.size}`);

  const missingRls = [];
  for (const tbl of tables) {
    const rlsRe = new RegExp(
      `alter\\s+table\\s+(?:if\\s+exists\\s+)?public\\.${tbl}\\s+enable\\s+row\\s+level\\s+security`,
      'i'
    );
    if (!rlsRe.test(allSql)) {
      missingRls.push(tbl);
    }
  }
  assert.deepEqual(missingRls, [], `Tabelas public.* SEM RLS habilitado: ${missingRls.join(', ')}`);
});

check('07. Contrato A/B/C: máquina de estados SP, RPC 16 chaves JSON, RLS, triggers, bucket forense e comentários SQL', () => {
  const requiredKeys = [
    'viewer_role',
    'phase',
    'exact_unlocked',
    'city',
    'uf',
    'neighborhood',
    'street',
    'number',
    'complement',
    'reference',
    'cep',
    'lat',
    'lng',
    'radius_m',
    'scheduled_date',
    'unlock_at',
  ];
  for (const k of requiredKeys) {
    assert.match(
      geoSql,
      new RegExp(`'${k}'\\s*,`),
      `get_job_location_for_viewer deve retornar a chave '${k}' do Contrato C`
    );
  }

  assert.match(geoSql, /America\/Sao_Paulo/, 'Deve usar fuso America/Sao_Paulo');
  assert.match(
    geoSql,
    /revoke\s+all\s+on\s+function\s+public\._can_see_exact_location\s*\(\s*uuid\s*,\s*uuid\s*\)\s+from\s+public,\s*anon,\s*authenticated/i,
    'Sobrecarga 2-args _can_see_exact_location(uuid, uuid) deve ser revogada de authenticated (Zero-Oracle)'
  );
  assert.match(
    geoSql,
    /grant\s+execute\s+on\s+function\s+public\._can_see_exact_location\s*\(\s*uuid\s*\)\s+to\s+authenticated/i,
    'Wrapper 1-arg _can_see_exact_location(uuid) deve ser concedido a authenticated'
  );
  assert.match(geoSql, /create\s+policy\s+job_addresses_select[\s\S]*?_can_see_exact_location\s*\(\s*job_id\s*\)/i);
  assert.match(geoSql, /create\s+policy\s+job_geo_select[\s\S]*?_can_see_exact_location\s*\(\s*job_id\s*\)/i);
  assert.match(geoSql, /create\s+trigger\s+aa_jobs_geo_privacy_before/i);
  assert.match(geoSql, /create\s+trigger\s+aa_jobs_geo_privacy_after/i);
  assert.match(geoSql, /notify_service_day_address_unlocked/i);

  const commentCount = (geoSql.match(/comment\s+on\s+function\s+public\./gi) ?? []).length;
  assert.ok(commentCount >= 10, `Esperado >= 10 documentações COMMENT ON FUNCTION (encontradas: ${commentCount})`);

  assert.match(secSql, /'forensic-evidence'[\s\S]{0,120}?false/i, 'Bucket forensic-evidence deve ter public = false');
  assert.match(secSql, /create\s+policy\s+"forensic_evidence_insert"\s+on\s+storage\.objects/i);
  assert.match(secSql, /create\s+policy\s+"forensic_evidence_select"\s+on\s+storage\.objects/i);
});

check('08. Cobertura de cenários em `supabase/tests/geo_privacy_lock.sql` (owner, open, futuro, service_day, closed, alheio, anon)', () => {
  const assertions = (testGeoSql.match(/perform\s+pg_temp\.t\s*\(/gi) ?? []).length;
  assert.ok(assertions >= 40, `Esperado >= 40 asserções em geo_privacy_lock.sql (encontradas: ${assertions})`);
  for (const token of [
    'owner_full',
    'open_quoting',
    'confirmed_future',
    'service_day',
    'closed',
    'denied',
    'set local role anon',
    '2026-11-20 02:59:59+00',
    '2026-11-20 03:00:00+00',
    'ERR_IDOR_BLOCKED',
    'forensic-evidence',
  ]) {
    assert.ok(testGeoSql.includes(token), `geo_privacy_lock.sql deve cobrir: ${token}`);
  }
});

check('09. Simulação Monte Carlo (10.000 jobs aleatórios): deslocamento [150..350] m, raio [500..800] m e contenção estrita', () => {
  const secret = crypto.randomBytes(32);
  const sampleCoords = [
    [-21.787812, -46.561423], // Poços de Caldas - MG
    [-23.55052, -46.633308],  // São Paulo - SP
    [-22.906847, -43.172896], // Rio de Janeiro - RJ
    [-3.119028, -60.021731],  // Manaus - AM (próximo ao Equador)
    [-33.6866, -53.4558],     // Chuí - RS
    [0.0, 179.999],           // Borda do antimeridiano (+180 -> -180)
    [0.0, -179.999],          // Borda do antimeridiano (-180 -> +180)
  ];

  let minDist = Infinity;
  let maxDist = -Infinity;
  let minRad = Infinity;
  let maxRad = -Infinity;

  for (let i = 0; i < 10_000; i++) {
    const jobId = crypto.randomUUID();
    const [lat, lng] = sampleCoords[i % sampleCoords.length];
    const f1 = sqlGeoFuzzyCenter(secret, jobId, lat, lng);
    const f2 = sqlGeoFuzzyCenter(secret, jobId, lat, lng);

    assert.deepEqual(f1, f2, 'Determinismo violado para o mesmo job_id');
    assert.ok(Number.isInteger(f1.radius_m) && f1.radius_m >= 500 && f1.radius_m <= 800, `Raio inválido: ${f1.radius_m}`);
    assert.ok(f1.lat >= -90 && f1.lat <= 90 && f1.lng >= -180 && f1.lng <= 180, 'Coordenada fora de domínio');

    const dist = haversineMeters(lat, lng, f1.lat, f1.lng);
    assert.ok(
      dist >= 150.0 && dist <= 350.0,
      `Deslocamento fora de [150, 350] m: ${dist.toFixed(3)} m (job=${jobId})`
    );
    assert.ok(
      dist <= f1.radius_m - 150.0,
      `Imóvel próximo demais da borda do círculo: dist=${dist.toFixed(2)}m, raio=${f1.radius_m}m`
    );

    if (dist < minDist) minDist = dist;
    if (dist > maxDist) maxDist = dist;
    if (f1.radius_m < minRad) minRad = f1.radius_m;
    if (f1.radius_m > maxRad) maxRad = f1.radius_m;
  }

  // Dois pedidos diferentes no MESMO imóvel não compartilham o mesmo centro aproximado
  const sameHouseA = sqlGeoFuzzyCenter(secret, '11111111-1111-4111-8111-111111111111', -21.787812, -46.561423);
  const sameHouseB = sqlGeoFuzzyCenter(secret, '22222222-2222-4222-8222-222222222222', -21.787812, -46.561423);
  assert.notDeepEqual(
    [sameHouseA.lat, sameHouseA.lng],
    [sameHouseB.lat, sameHouseB.lng],
    'Jobs distintos no mesmo endereço devem ter centros aproximados distintos'
  );

  console.log(
    `         Monte Carlo 10.000 amostras OK: dist=[${minDist.toFixed(2)}m .. ${maxDist.toFixed(2)}m], radius=[${minRad}m .. ${maxRad}m]`
  );
});

check('10. Fronteira temporal America/Sao_Paulo (UTC-3 fixo: 02:59:59Z vs 03:00:00Z)', () => {
  const fmtSpDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const schedUtc = new Date('2026-11-20T17:00:00Z'); // 14:00 SP em 2026-11-20
  const beforeMidnightSp = new Date('2026-11-20T02:59:59Z'); // 23:59:59 SP em 2026-11-19
  const atMidnightSp = new Date('2026-11-20T03:00:00Z'); // 00:00:00 SP em 2026-11-20

  assert.equal(fmtSpDate.format(schedUtc), '2026-11-20');
  assert.equal(fmtSpDate.format(beforeMidnightSp), '2026-11-19');
  assert.equal(fmtSpDate.format(atMidnightSp), '2026-11-20');
  assert.equal(fmtSpDate.format(beforeMidnightSp) >= fmtSpDate.format(schedUtc), false);
  assert.equal(fmtSpDate.format(atMidnightSp) >= fmtSpDate.format(schedUtc), true);
});

check('11. Auditoria cumulativa de TODAS as funções SECURITY DEFINER nas 27 migrations (search_path + REVOKE anon)', () => {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  const allSql = files.map((f) => fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8')).join('\n');

  // Coleta a última definição de cada função public.<name>
  const latestFnHeaders = new Map();
  const fnAnyTagRegex =
    /create\s+(?:or\s+replace\s+)?function\s+(public\.[a-z0-9_]+)\s*\([\s\S]*?\bas\s+(\$[A-Za-z0-9_]*\$)[\s\S]*?\2\s*;/gi;
  for (const m of allSql.matchAll(fnAnyTagRegex)) {
    const fnName = m[1].toLowerCase();
    const tag = m[2];
    const header = m[0].slice(0, m[0].toLowerCase().indexOf(`as ${tag.toLowerCase()}`));
    latestFnHeaders.set(fnName, header);
  }

  const missingSearchPath = [];
  const missingRevoke = [];
  let secDefCount = 0;

  for (const [fnName, header] of latestFnHeaders.entries()) {
    if (!/\bsecurity\s+definer\b/i.test(header)) continue;
    secDefCount++;

    const hasInlineSearchPath = /\bset\s+search_path\s*=\s*(?:public(?:\s*,\s*extensions)?|'')/i.test(header);
    const hasAlterSearchPath = new RegExp(
      `alter\\s+function\\s+${fnName.replace('.', '\\.')}\\s*\\([\\s\\S]*?\\)\\s*set\\s+search_path\\s*=\\s*public`,
      'i'
    ).test(allSql);
    if (!hasInlineSearchPath && !hasAlterSearchPath) {
      missingSearchPath.push(fnName);
    }

    const shortName = fnName.replace(/^public\./, '');
    const hasRevoke =
      new RegExp(`revoke\\s+all\\s+on\\s+function[\\s\\S]{0,1200}?\\bpublic\\.${shortName}\\s*\\(`, 'i').test(allSql) ||
      allSql.toLowerCase().includes(`'${fnName}(`);
    if (!hasRevoke) {
      missingRevoke.push(fnName);
    }
  }

  assert.ok(secDefCount >= 35, `Esperado >= 35 funções SECURITY DEFINER no projeto (encontradas: ${secDefCount})`);
  assert.deepEqual(missingSearchPath, [], `Funções SECURITY DEFINER sem search_path fixo: ${missingSearchPath.join(', ')}`);
  assert.deepEqual(missingRevoke, [], `Funções SECURITY DEFINER sem REVOKE de public/anon: ${missingRevoke.join(', ')}`);
});

check('12. Cadeia limpa para `supabase db reset`/`db push`: zero `.concat(`, `public.users`, `wallet_ledger_entries` ou `m.phase` legado nas migrations', () => {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  assert.ok(files.length >= 28, `Esperado >= 28 migrations no worktree, encontradas ${files.length}`);
  for (const f of files) {
    const content = fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    lexSql(content, f);
    const noLineComments = content.replace(/--.*$/gm, '');
    assert.doesNotMatch(noLineComments, /\.concat\s*\(/i, `${f}: sintaxe JS .concat() inválida em SQL/PLpgSQL`);
    assert.doesNotMatch(noLineComments, /\bpublic\.users\b/i, `${f}: relação inexistente public.users`);
    assert.doesNotMatch(noLineComments, /\bm\.phase\b/i, `${f}: coluna inexistente m.phase em job_mediations`);
  }
  assert.doesNotMatch(
    lexSql(forensicSql, 'forensic-nocomment'),
    /\bwallet_ledger_entries\b/i,
    '20261113130000 não pode referenciar tabela inexistente wallet_ledger_entries'
  );
});

check('13. Contrato v2.11.1 (`20261113125000` + `20261113130000`): `jobs.updated_at`, `register_forensic_photo`, `MANUAL_KEY`, `PENDING_SEFAZ`, Smart Split Isenção Provisória + Clawback e suíte `forensic_photo_and_fiscal.sql`', () => {
  assert.match(
    jobsUpdatedSql,
    /alter\s+table\s+public\.jobs[\s\S]{0,80}?add\s+column\s+if\s+not\s+exists\s+updated_at\s+timestamptz/i,
    '20261113125000 deve adicionar public.jobs.updated_at'
  );
  assert.match(jobsUpdatedSql, /create\s+or\s+replace\s+function\s+public\._touch_updated_at\s*\(\s*\)/i);
  assert.match(jobsUpdatedSql, /create\s+trigger\s+jobs_touch_updated_at\s+before\s+update\s+on\s+public\.jobs/i);
  assert.match(
    forensicSql,
    /drop\s+function\s+if\s+exists\s+public\.trigger_layer3_rework\s*\(\s*uuid\s*\)\s*;/i,
    '20261113130000 deve remover sobrecarga morta trigger_layer3_rework(uuid)'
  );
  assert.match(forensicSql, /create\s+or\s+replace\s+function\s+public\.register_forensic_photo\s*\(/i);
  assert.match(forensicSql, /FORENSIC_CHECKIN_IMMUTABLE/);
  assert.match(forensicSql, /FORENSIC_PHOTO_DUPLICATE/);
  assert.match(forensicSql, /FORENSIC_PATH_INVALID/);
  assert.match(forensicSql, /9223372036854775807::bigint/, 'hamming_distance_64 deve proteger bit de sinal INT64_MIN');
  assert.match(forensicSql, /'MANUAL_KEY'/, 'job_fiscal_documents deve aceitar capture_channel = MANUAL_KEY');
  assert.match(forensicSql, /'PENDING_SEFAZ'/, 'documentos fiscais devem nascer em PENDING_SEFAZ');
  assert.match(forensicSql, /'sefaz_confirmed'\s*,\s*false/i, 'resposta RPC deve retornar sefaz_confirmed = false até conferência SEFAZ');
  assert.match(
    forensicSql,
    /d\.verification_status\s+in\s*\(\s*'PENDING_SEFAZ'\s*,\s*'VERIFIED_SEFAZ'\s*\)[\s\S]{0,120}?d\.clawback_triggered\s*=\s*false/i,
    'settle_escrow_with_carveout_and_maturation deve conceder isenção provisória para PENDING_SEFAZ/VERIFIED_SEFAZ sem clawback'
  );
  assert.match(
    forensicSql,
    /v_was_exempt_eligible\s*:=\s*\(\s*v_doc\.verification_status\s+in\s*\(\s*'PENDING_SEFAZ'\s*,\s*'VERIFIED_SEFAZ'\s*\)/i,
    'audit_sefaz_phase2_cancellation_and_clawback deve debitar clawback de 15% também sobre nota PENDING_SEFAZ cancelada/invalidada'
  );

  const forensicAssertions = (testForensicSql.match(/perform\s+pg_temp\.t\s*\(/gi) ?? []).length;
  assert.ok(
    forensicAssertions >= 24,
    `Esperado >= 24 asserções em forensic_photo_and_fiscal.sql (encontradas: ${forensicAssertions})`
  );
  for (const token of [
    'FORENSIC_CHECKIN_IMMUTABLE',
    'FORENSIC_PHOTO_DUPLICATE',
    'FORENSIC_PATH_INVALID',
    'MANUAL_KEY',
    'PENDING_SEFAZ',
    'VERIFIED_SEFAZ',
    'CANCELED_CLAWBACK',
    'REJECTED_SEFAZ',
  ]) {
    assert.ok(testForensicSql.includes(token), `forensic_photo_and_fiscal.sql deve cobrir: ${token}`);
  }
});

check('14. Varredura cumulativa de catálogo PL/pgSQL: zero função ativa referenciando tabelas/colunas fantasmas', () => {
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  assert.ok(files.length >= 29, `Esperado >= 29 migrations no worktree, encontradas ${files.length}`);

  const activeFns = new Map();
  for (const f of files) {
    const s = fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    const cleanTop = s.replace(/--.*$/gm, '');
    for (const dm of cleanTop.matchAll(/drop\s+function\s+(?:if\s+exists\s+)?(public\.[a-z0-9_]+)\s*\(([^)]*)\)/gi)) {
      const argCount = dm[2].trim() === '' ? 0 : dm[2].split(',').length;
      activeFns.delete(`${dm[1].toLowerCase()}/${argCount}`);
    }
    const fnRe =
      /create\s+(?:or\s+replace\s+)?function\s+(public\.[a-z0-9_]+)\s*\(([\s\S]*?)\)\s*returns[\s\S]*?\bas\s+(\$[A-Za-z0-9_]*\$)([\s\S]*?)\3\s*;/gi;
    for (const m of s.matchAll(fnRe)) {
      const cleanArgs = m[2].replace(/--.*$/gm, '').trim();
      const argCount = cleanArgs === '' ? 0 : cleanArgs.split(',').length;
      activeFns.set(`${m[1].toLowerCase()}/${argCount}`, { file: f, body: m[4] });
    }
  }

  const forbiddenRefs = [
    /\bpublic\.warranty_claims\b/i,
    /\bpublic\.wallet_ledger_entries\b/i,
    /\bpublic\.security_device_sessions\b/i,
    /\bphash_hamming_distance\b/i,
    /\bcheckin_phash_64\b/i,
    /\bescrow_state\b/i,
    /\bpay\.payment_method\b/i,
  ];

  for (const [sig, { file, body }] of activeFns.entries()) {
    const cleanBody = body.replace(/--.*$/gm, '');
    for (const re of forbiddenRefs) {
      assert.doesNotMatch(cleanBody, re, `Função ativa ${sig} (${file}) referencia identificador inexistente: ${re}`);
    }
  }
});

check('15. Cofre Monocrático Desperrengue CEO (`20261114180000` + `ceo_monocratic_vault_and_realtime_smoke.sql`): titularidade exclusiva `wagneroliveira2395@gmail.com`, zero delegados, PIN/OTP SHA-256 em tempo constante e triggers Realtime isolados', () => {
  const migCeoPath = path.join(MIGRATIONS_DIR, '20261114180000_ceo_monocratic_vault_and_realtime_truth.sql');
  const testCeoPath = path.join(TESTS_DIR, 'ceo_monocratic_vault_and_realtime_smoke.sql');
  assert.ok(fs.existsSync(migCeoPath), 'Migration 20261114180000_ceo_monocratic_vault_and_realtime_truth.sql obrigatória');
  assert.ok(fs.existsSync(testCeoPath), 'Suíte ceo_monocratic_vault_and_realtime_smoke.sql obrigatória');

  const migCeo = fs.readFileSync(migCeoPath, 'utf8');
  const testCeo = fs.readFileSync(testCeoPath, 'utf8');
  lexSql(migCeo, '20261114180000_ceo_monocratic_vault_and_realtime_truth.sql');
  lexSql(testCeo, 'ceo_monocratic_vault_and_realtime_smoke.sql');

  assert.match(migCeo, /lower\(btrim\(owner_email\)\)\s*=\s*'wagneroliveira2395@gmail\.com'/i);
  assert.match(migCeo, /drop\s+function\s+if\s+exists\s+public\.founder_authorize_delegate/i);
  assert.match(migCeo, /create\s+or\s+replace\s+function\s+private\.ceo_compute_pin_sha256/i);
  assert.match(migCeo, /create\s+or\s+replace\s+function\s+private\.ceo_constant_time_eq_hex/i);
  assert.match(migCeo, /create\s+or\s+replace\s+function\s+public\.ceo_register_personal_pin/i);
  assert.match(migCeo, /create\s+or\s+replace\s+function\s+public\.ceo_unlock_sovereign_vault/i);
  assert.match(migCeo, /create\s+or\s+replace\s+function\s+public\.ceo_get_live_cockpit_snapshot/i);
  assert.match(migCeo, /realtime\.send\s*\(/i);
  assert.match(migCeo, /ceo:war-room:live/);
  assert.match(migCeo, /exception\s+when\s+others\s+then\s+null/i);

  const ceoAssertions = (testCeo.match(/perform\s+pg_temp\.t\s*\(/gi) ?? []).length;
  assert.ok(ceoAssertions >= 12, `Esperado >= 12 asserções em ceo_monocratic_vault_and_realtime_smoke.sql (encontradas: ${ceoAssertions})`);
});

check('16. Cofre Soberano v2.14.0 (`20261115000000` + `ceo_master_password_and_reset_smoke.sql`): Senha Mestra Forte Split-Pepper + HMAC-SHA512 x 25k + AES-256, 2FA 6d Anti-Inbox-Bombing, Histórico 5 senhas e Deep-Link Efêmero Device-Bound', () => {
  const migPwPath = path.join(MIGRATIONS_DIR, '20261115000000_ceo_master_password_vault_and_reset_ceremony.sql');
  const testPwPath = path.join(TESTS_DIR, 'ceo_master_password_and_reset_smoke.sql');
  assert.ok(fs.existsSync(migPwPath), 'Migration 20261115000000_ceo_master_password_vault_and_reset_ceremony.sql obrigatória');
  assert.ok(fs.existsSync(testPwPath), 'Suíte ceo_master_password_and_reset_smoke.sql obrigatória');

  const migPw = fs.readFileSync(migPwPath, 'utf8');
  const testPw = fs.readFileSync(testPwPath, 'utf8');
  const strippedPw = lexSql(migPw, '20261115000000_ceo_master_password_vault_and_reset_ceremony.sql');
  const strippedTestPw = lexSql(testPw, 'ceo_master_password_and_reset_smoke.sql');

  assert.match(strippedPw, /^\s*begin\s*;/i, '20261115000000 deve abrir com begin;');
  assert.match(strippedPw, /commit\s*;\s*$/i, '20261115000000 deve encerrar com commit;');
  assert.match(strippedTestPw, /^\s*begin\s*;/i, 'ceo_master_password_and_reset_smoke.sql deve abrir com begin;');
  assert.match(strippedTestPw, /rollback\s*;\s*$/i, 'ceo_master_password_and_reset_smoke.sql deve encerrar com rollback;');

  // Nenhum GRANT para anon/public e todas as RPCs ceo_edge_* restritas a service_role
  assert.doesNotMatch(strippedPw, /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i);
  assert.match(migPw, /drop\s+function\s+if\s+exists\s+public\.ceo_register_personal_pin/i);
  assert.match(migPw, /drop\s+function\s+if\s+exists\s+public\.ceo_unlock_sovereign_vault/i);
  assert.match(migPw, /pgp_sym_encrypt_bytea/i);
  assert.match(migPw, /cipher-algo=aes256,\s*compress-algo=0/i);
  assert.match(migPw, /for\s+i\s+in\s+1\.\.25000\s+loop/i);
  assert.match(migPw, /create\s+table\s+if\s+not\s+exists\s+private\.ceo_password_history/i);
  assert.match(migPw, /create\s+table\s+if\s+not\s+exists\s+private\.ceo_security_challenges/i);
  assert.match(migPw, /create\s+table\s+if\s+not\s+exists\s+private\.ceo_password_reset_links/i);
  assert.match(migPw, /create\s+or\s+replace\s+function\s+public\.ceo_edge_inspect_reset_link_bridge/i);
  assert.match(migPw, /create\s+or\s+replace\s+function\s+public\.ceo_edge_commit_password_reset_from_link/i);

  const pwAssertions = (testPw.match(/perform\s+pg_temp\.t\s*\(/gi) ?? []).length;
  assert.ok(pwAssertions >= 20, `Esperado >= 20 asserções em ceo_master_password_and_reset_smoke.sql (encontradas: ${pwAssertions})`);
});

check('17. Hardening OTP v2.14.1 (`20261115010000` + `ceo-vault-authority`): Janela 2x Same-Device, TTL 10m, Anti-Threading `X-Entity-Ref-ID`, Single-Line `nowrap` e Diagnóstico `ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL`', () => {
  const migOtpPath = path.join(MIGRATIONS_DIR, '20261115010000_ceo_otp_hardening_and_verification_fix.sql');
  const edgeFnPath = path.join(MIGRATIONS_DIR, '..', 'functions', 'ceo-vault-authority', 'index.ts');
  assert.ok(fs.existsSync(migOtpPath), 'Migration 20261115010000_ceo_otp_hardening_and_verification_fix.sql obrigatória');
  assert.ok(fs.existsSync(edgeFnPath), 'Edge Function ceo-vault-authority/index.ts obrigatória');

  const migOtp = fs.readFileSync(migOtpPath, 'utf8');
  const edgeFn = fs.readFileSync(edgeFnPath, 'utf8');
  const strippedOtp = lexSql(migOtp, '20261115010000_ceo_otp_hardening_and_verification_fix.sql');

  assert.match(strippedOtp, /^\s*begin\s*;/i, '20261115010000 deve abrir com begin;');
  assert.match(strippedOtp, /commit\s*;\s*$/i, '20261115010000 deve encerrar com commit;');
  assert.doesNotMatch(strippedOtp, /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i);

  assert.match(migOtp, /create\s+or\s+replace\s+function\s+private\.ceo_challenge_ref_code/i);
  assert.match(migOtp, /create\s+or\s+replace\s+function\s+private\.ceo_issue_otp_challenge_internal/i);
  assert.match(migOtp, /create\s+or\s+replace\s+function\s+private\.ceo_verify_and_consume_otp_challenge/i);
  assert.match(migOtp, /ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL/);
  assert.match(migOtp, /interval\s+'10 minutes'/i);

  assert.match(edgeFn, /X-Entity-Ref-ID/);
  assert.match(edgeFn, /white-space:\s*nowrap/i);
  assert.match(edgeFn, /PROTOCOLO #/);
  assert.doesNotMatch(edgeFn, /otpCode\.slice\(0,\s*3\)[\s\S]{0,40}&nbsp;/, 'Proibido separar OTP com &nbsp; que causa quebra mobile 686 41\\n5');
});

check('18. Calendário Executivo & Ponte Realtime Integral (`20261116120000` + `ceo_calendar_agenda_and_realtime_smoke.sql`): `day:YYYY-MM-DD`, DAS dia 20 útil (Lei 14.759/2023 + FEBRABAN), Mediações Unificadas, Contas Agendadas e Forense `pay.method`', () => {
  const migCalPath = path.join(MIGRATIONS_DIR, '20261116120000_ceo_executive_calendar_agenda_and_realtime_bridge.sql');
  const testCalPath = path.join(TESTS_DIR, 'ceo_calendar_agenda_and_realtime_smoke.sql');
  assert.ok(fs.existsSync(migCalPath), 'Migration 20261116120000_ceo_executive_calendar_agenda_and_realtime_bridge.sql obrigatória');
  assert.ok(fs.existsSync(testCalPath), 'Suíte ceo_calendar_agenda_and_realtime_smoke.sql obrigatória');

  const migCal = fs.readFileSync(migCalPath, 'utf8');
  const testCal = fs.readFileSync(testCalPath, 'utf8');
  const strippedCal = lexSql(migCal, '20261116120000_ceo_executive_calendar_agenda_and_realtime_bridge.sql');
  const strippedTestCal = lexSql(testCal, 'ceo_calendar_agenda_and_realtime_smoke.sql');

  assert.match(strippedCal, /^\s*begin\s*;/i, '20261116120000 deve abrir com begin;');
  assert.match(strippedCal, /commit\s*;\s*$/i, '20261116120000 deve encerrar com commit;');
  assert.match(strippedTestCal, /^\s*begin\s*;/i, 'ceo_calendar_agenda_and_realtime_smoke.sql deve abrir com begin;');
  assert.match(strippedTestCal, /rollback\s*;\s*$/i, 'ceo_calendar_agenda_and_realtime_smoke.sql deve encerrar com rollback;');
  assert.doesNotMatch(strippedCal, /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i);

  assert.match(migCal, /create\s+or\s+replace\s+function\s+private\.ceo_das_due_date_for_competence/i);
  assert.match(migCal, /create\s+or\s+replace\s+function\s+private\.ceo_defis_due_date_for_year/i);
  assert.match(migCal, /create\s+or\s+replace\s+function\s+public\.ceo_toggle_expense_paid_status/i);
  assert.match(migCal, /create\s+trigger\s+zz_ceo_live_support_tickets/i);
  assert.match(migCal, /create\s+trigger\s+zz_ceo_live_payments/i);
  assert.match(migCal, /create\s+trigger\s+zz_ceo_live_withdrawals/i);
  assert.match(migCal, /create\s+trigger\s+zz_ceo_live_expenses_aiud/i);
  assert.match(migCal, /tax_obligations_schedule/);
  assert.match(migCal, /active_mediations/);
  assert.match(migCal, /calendar_agenda_days/);
  assert.match(migCal, /calendar_agenda_events/);
  assert.doesNotMatch(migCal, /\bpay\.payment_method\b/i);

  const calAssertions = (testCal.match(/perform\s+pg_temp\.t\s*\(/gi) ?? []).length;
  assert.ok(calAssertions >= 14, `Esperado >= 14 asserções em ceo_calendar_agenda_and_realtime_smoke.sql (encontradas: ${calAssertions})`);
});

check('19. Marco Zero Operacional do Marketplace (`20261116184500` + `marketplace_zero_slate_preserve_ceo_smoke.sql`): purga integral de Clientes/Profissionais/Híbridos + Pedidos/Transações com preservação estrita do Cofre Soberano CEO e WORM SHA-256', () => {
  const migResetPath = path.join(MIGRATIONS_DIR, '20261116184500_reset_marketplace_users_and_operational_data_preserve_ceo.sql');
  const testResetPath = path.join(TESTS_DIR, 'marketplace_zero_slate_preserve_ceo_smoke.sql');
  assert.ok(fs.existsSync(migResetPath), 'Migration 20261116184500_reset_marketplace_users_and_operational_data_preserve_ceo.sql obrigatória');
  assert.ok(fs.existsSync(testResetPath), 'Suíte marketplace_zero_slate_preserve_ceo_smoke.sql obrigatória');

  const migReset = fs.readFileSync(migResetPath, 'utf8');
  const testReset = fs.readFileSync(testResetPath, 'utf8');
  const strippedReset = lexSql(migReset, '20261116184500_reset_marketplace_users_and_operational_data_preserve_ceo.sql');
  const strippedTestReset = lexSql(testReset, 'marketplace_zero_slate_preserve_ceo_smoke.sql');

  assert.match(strippedReset, /^\s*begin\s*;/i, '20261116184500 deve abrir com begin;');
  assert.match(strippedReset, /commit\s*;\s*$/i, '20261116184500 deve encerrar com commit;');
  assert.match(strippedTestReset, /^\s*begin\s*;/i, 'marketplace_zero_slate_preserve_ceo_smoke.sql deve abrir com begin;');
  assert.match(strippedTestReset, /rollback\s*;\s*$/i, 'marketplace_zero_slate_preserve_ceo_smoke.sql deve encerrar com rollback;');
  assert.doesNotMatch(strippedReset, /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i);

  assert.match(migReset, /private\.ceo_owner_canonical_email\(\)/i);
  assert.match(migReset, /ERR_MARKETPLACE_RESET_INCOMPLETE/);
  assert.match(migReset, /ERR_AUTH_USERS_RESET_INCOMPLETE/);
  assert.match(migReset, /ERR_CEO_ACCOUNT_PROTECTION_VIOLATION/);
  assert.doesNotMatch(strippedReset, /delete\s+from\s+private\.ceo_sovereign_vault/i);
  assert.doesNotMatch(strippedReset, /delete\s+from\s+private\.ceo_crypto_pepper/i);
  assert.doesNotMatch(strippedReset, /delete\s+from\s+private\.ceo_password_history/i);
  assert.doesNotMatch(strippedReset, /delete\s+from\s+private\.founder_audit_log/i);
});

check('20. Cofre KYC Semestral Unificado (6 Meses) + Antecedentes Criminais PF + Termos Bivalentes + Trava Anti-Recobrança (`20261118150000` + `kyc-argon-vision-gate`)', () => {
  const migUnifiedPath = path.join(
    MIGRATIONS_DIR,
    '20261118150000_unified_6m_kyc_criminal_check_role_terms_and_marketplace_reset.sql'
  );
  const visionGatePath = path.join(MIGRATIONS_DIR, '..', 'functions', 'kyc-argon-vision-gate', 'index.ts');
  assert.ok(fs.existsSync(migUnifiedPath), 'Migration 20261118150000 obrigatória');
  assert.ok(fs.existsSync(visionGatePath), 'Edge Function kyc-argon-vision-gate/index.ts obrigatória');

  const migUnified = fs.readFileSync(migUnifiedPath, 'utf8');
  const visionGate = fs.readFileSync(visionGatePath, 'utf8');
  const strippedUnified = lexSql(
    migUnified,
    '20261118150000_unified_6m_kyc_criminal_check_role_terms_and_marketplace_reset.sql'
  );

  assert.match(strippedUnified, /^\s*begin\s*;/i, '20261118150000 deve abrir com begin;');
  assert.match(strippedUnified, /commit\s*;\s*$/i, '20261118150000 deve encerrar com commit;');
  assert.doesNotMatch(strippedUnified, /\bgrant\b[\s\S]{0,240}?\bto\s+(?:anon|public)\b/i);

  // Idempotência estrita em CREATE TABLE / CREATE INDEX / CREATE POLICY / CREATE TRIGGER
  const rawCreateTables = strippedUnified.match(/\bcreate\s+table\s+(?!if\s+not\s+exists\b)/gi) ?? [];
  assert.equal(rawCreateTables.length, 0, '20261118150000: todo CREATE TABLE deve usar IF NOT EXISTS');
  const rawCreateIndexes = strippedUnified.match(/\bcreate\s+(?:unique\s+)?index\s+(?!if\s+not\s+exists\b)/gi) ?? [];
  assert.equal(rawCreateIndexes.length, 0, '20261118150000: todo CREATE INDEX deve usar IF NOT EXISTS');

  // Tabela criminal_background_checks + RLS ENABLE & FORCE + Anti-Replay entre contas
  assert.match(migUnified, /create\s+table\s+if\s+not\s+exists\s+public\.criminal_background_checks/i);
  assert.match(migUnified, /alter\s+table\s+public\.criminal_background_checks\s+enable\s+row\s+level\s+security/i);
  assert.match(migUnified, /alter\s+table\s+public\.criminal_background_checks\s+force\s+row\s+level\s+security/i);
  assert.match(migUnified, /revoke\s+all\s+on\s+table\s+public\.criminal_background_checks\s+from\s+public,\s*anon,\s*authenticated/i);
  assert.match(migUnified, /ERR_CRIMINAL_CERT_REPLAY_ACROSS_ACCOUNTS/);

  // Proteção das novas colunas em profiles_protect_columns e RPCs de 6 meses / reaproveitamento
  assert.match(migUnified, /create\s+or\s+replace\s+function\s+public\.profiles_protect_columns/i);
  assert.match(migUnified, /new\.kyc_expires_at\s+is\s+distinct\s+from\s+old\.kyc_expires_at/i);
  assert.match(migUnified, /new\.criminal_record_verified\s+is\s+distinct\s+from\s+old\.criminal_record_verified/i);
  assert.match(migUnified, /new\.client_terms_accepted\s+is\s+distinct\s+from\s+old\.client_terms_accepted/i);
  assert.match(migUnified, /new\.provider_terms_accepted\s+is\s+distinct\s+from\s+old\.provider_terms_accepted/i);

  assert.match(migUnified, /create\s+or\s+replace\s+function\s+public\.is_kyc_cycle_currently_valid/i);
  assert.match(migUnified, /create\s+or\s+replace\s+function\s+public\.submit_unified_kyc_v2/i);
  assert.match(migUnified, /create\s+or\s+replace\s+function\s+public\.activate_role_reusing_valid_kyc/i);
  assert.match(migUnified, /interval\s+'6 months'/i);
  assert.match(migUnified, /ERR_KYC_EXPIRED_OR_MISSING/);

  // Limpeza completa do marketplace com preservação soberana CEO
  assert.match(migUnified, /delete\s+from\s+public\.legal_mandate_acceptances/i);
  assert.match(migUnified, /delete\s+from\s+public\.criminal_background_checks/i);
  assert.match(migUnified, /delete\s+from\s+public\.profiles/i);
  assert.match(migUnified, /private\.ceo_owner_canonical_email\(\)/i);
  assert.match(migUnified, /ERR_CEO_ACCOUNT_PROTECTION_VIOLATION/);
  assert.doesNotMatch(strippedUnified, /delete\s+from\s+private\.ceo_sovereign_vault/i);
  assert.doesNotMatch(strippedUnified, /delete\s+from\s+private\.ceo_crypto_pepper/i);
  assert.doesNotMatch(strippedUnified, /delete\s+from\s+private\.ceo_password_history/i);
  assert.doesNotMatch(strippedUnified, /delete\s+from\s+private\.founder_audit_log/i);
  assert.doesNotMatch(strippedUnified, /delete\s+from\s+public\.app_settings/i);

  // Edge Function kyc-argon-vision-gate: trava anti-recobrança + modo criminal_record
  assert.match(visionGate, /kyc_billing_lock_until/);
  assert.match(visionGate, /reused_valid_kyc:\s*true/);
  assert.match(visionGate, /api_billed:\s*false/);
  assert.match(visionGate, /mode\s*===\s*"criminal_record"/);
  assert.match(visionGate, /NOTHING_ON_RECORD/);
});

const failed = results.filter((r) => !r.ok);
console.log(`\nResumo: ${results.length - failed.length}/${results.length} verificações aprovadas.`);
if (failed.length > 0) {
  process.exit(1);
}

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
  ];

  for (const [sig, { file, body }] of activeFns.entries()) {
    const cleanBody = body.replace(/--.*$/gm, '');
    for (const re of forbiddenRefs) {
      assert.doesNotMatch(cleanBody, re, `Função ativa ${sig} (${file}) referencia identificador inexistente: ${re}`);
    }
  }
});

const failed = results.filter((r) => !r.ok);
console.log(`\nResumo: ${results.length - failed.length}/${results.length} verificações aprovadas.`);
if (failed.length > 0) {
  process.exit(1);
}

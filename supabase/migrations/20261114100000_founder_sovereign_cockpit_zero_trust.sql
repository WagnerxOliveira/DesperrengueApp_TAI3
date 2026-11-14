-- =============================================================================
-- DESPERRENGUE — Founder Sovereign Cockpit & War Room Zero-Trust Architecture
-- Migration: 20261114100000_founder_sovereign_cockpit_zero_trust.sql (v2.12.0)
--
-- ARQUITETURA ZERO-TRUST E INVARIANTES FÍSICAS DO KERNEL POSTGRESQL:
--   1. Cofre isolado no schema `private` (inacessível via PostgREST / Data API;
--      `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + `REVOKE ALL`
--      de `PUBLIC, anon, authenticated`, sem policies):
--      - `private.founder_sovereign_acl`: Assento vitalício único `SOVEREIGN_CEO`
--        (índice parcial único `uq_single_sovereign_ceo`) + trava física de kernel
--        de no máximo 3 delegados ativos (`AUTHORIZED_DELEGATE`) via trigger
--        `private.trg_enforce_max_3_founder_delegates()` com `LOCK TABLE ... IN
--        EXCLUSIVE MODE` e erro canônico `ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED`
--        (`SQLSTATE 'P0001'`). Delegados jamais podem receber `FULL_SOVEREIGN`.
--      - `private.founder_stepup_sessions`: Sessões efêmeras de step-up (15 min)
--        armazenando exclusivamente `session_token_hash` (SHA-256 hex de 64 chars,
--        zero token em texto puro em repouso), vinculadas a `auth.uid()`.
--      - `private.founder_audit_log`: Livro-razão forense estritamente append-only
--        (`BEFORE UPDATE OR DELETE` -> `42501`) encadeado por hash criptográfico
--        SHA-256 (`prev_hash` -> `row_hash`) + flag `is_intrusion_canary`.
--   2. Suporte nativo ao estado `FROZEN_UNDER_DURESS` (Silent Duress War Room) em
--      `public.jobs.escrow_status` e `public.escrow_maturation_entries.maturation_status`.
--   3. Índices de cobertura B-Tree `INCLUDE` idempotentes (`< 15 ms` Index-Only Scan)
--      sobre `public.jobs`, `public.escrow_maturation_entries`,
--      `public.warranty_pool_ledger` e `public.job_fiscal_documents`.
--   4. RPCs `SECURITY DEFINER` com `SET search_path = public, extensions`:
--      - `public.founder_bootstrap_sovereign_ceo(p_master_pin)`
--      - `public.founder_unlock_stepup_session(p_master_pin)`
--      - `public.founder_report_security_canary(p_event_code, p_details)`
--      - `public.founder_authorize_delegate(p_stepup_token, p_target_email, p_permission_scope, p_initial_pin, p_expires_in_days)`
--      - `public.founder_revoke_delegate(p_stepup_token, p_target_user_id)`
--      - `public.founder_execute_strategic_action(p_stepup_token, p_action_code, p_payload)`
--      - `public.founder_get_cockpit_snapshot(p_stepup_token, p_days_window)`
--        (`SET LOCAL transaction_read_only = on;`, aritmética 100% BIGINT em
--        centavos sob CPC 47 / IFRS 15, reconciliação de 3 vias sensível a 1
--        centavo e filtragem de escopo Zero-Trust).
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 0. Extensão aditiva idempotente das constraints de custódia para suportar
--    `FROZEN_UNDER_DURESS` (Silent Duress War Room) sem quebrar estados legados
-- -----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'jobs'
       and c.contype = 'c'
       and pg_get_constraintdef(c.oid) ilike '%escrow_status%'
  loop
    execute format('alter table public.jobs drop constraint if exists %I', r.conname);
  end loop;

  alter table public.jobs
    add constraint jobs_escrow_status_check check (
      escrow_status in (
        'NONE',
        'LOCKED_100',
        'RELEASED_TO_MATURATION',
        'FROZEN_IN_MEDIATION',
        'FROZEN_UNDER_DURESS',
        'REFUNDED_TO_CLIENT',
        'CONVERTED_TO_REWORK'
      )
    );

  for r in
    select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'escrow_maturation_entries'
       and c.contype = 'c'
       and pg_get_constraintdef(c.oid) ilike '%maturation_status%'
  loop
    execute format('alter table public.escrow_maturation_entries drop constraint if exists %I', r.conname);
  end loop;

  alter table public.escrow_maturation_entries
    add constraint escrow_maturation_entries_maturation_status_check check (
      maturation_status in (
        'MATURING',
        'FROZEN_BY_DISPUTE',
        'FROZEN_UNDER_DURESS',
        'AVAILABLE_FOR_PIX',
        'CLAWED_BACK'
      )
    );
end $$;

-- -----------------------------------------------------------------------------
-- 1. Cofre Soberano `private` (`founder_sovereign_acl`, `founder_stepup_sessions`,
--    `founder_audit_log`) com RLS Forçado e Zero Grants para API pública
-- -----------------------------------------------------------------------------
create table if not exists private.founder_sovereign_acl (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  email_snapshot   text not null check (btrim(email_snapshot) <> ''),
  seat_role        text not null check (seat_role in ('SOVEREIGN_CEO', 'AUTHORIZED_DELEGATE')),
  permission_scope text not null default 'READ_ONLY_ANALYTICS' check (
    permission_scope in (
      'FULL_SOVEREIGN',
      'READ_ONLY_ANALYTICS',
      'FINANCE_TAX_AUDITOR',
      'OPERATIONS_SECURITY'
    )
  ),
  authorized_by    uuid references auth.users(id) on delete set null,
  master_pin_hash  text not null check (btrim(master_pin_hash) <> ''),
  require_aal2     boolean not null default false,
  is_active        boolean not null default true,
  failed_attempts  integer not null default 0 check (failed_attempts >= 0),
  locked_until     timestamptz,
  expires_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint chk_founder_acl_role_scope check (
    (seat_role = 'SOVEREIGN_CEO' and permission_scope = 'FULL_SOVEREIGN')
    or (seat_role = 'AUTHORIZED_DELEGATE' and permission_scope <> 'FULL_SOVEREIGN')
  )
);

alter table private.founder_sovereign_acl enable row level security;
alter table private.founder_sovereign_acl force row level security;
revoke all on table private.founder_sovereign_acl from public, anon, authenticated;

-- Invariante Física 1: Assento vitalício único para `SOVEREIGN_CEO` ativo
create unique index if not exists uq_single_sovereign_ceo
  on private.founder_sovereign_acl (seat_role)
  where seat_role = 'SOVEREIGN_CEO' and is_active = true;

-- Invariante Física 2: Trava de kernel estrita de no máximo 3 `AUTHORIZED_DELEGATE` ativos
create or replace function private.trg_enforce_max_3_founder_delegates()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_active_delegates integer := 0;
begin
  -- Serializa mutações concorrentes na ACL soberana evitando condição de corrida (TOCTOU)
  lock table private.founder_sovereign_acl in exclusive mode;

  if new.seat_role = 'AUTHORIZED_DELEGATE' and new.permission_scope = 'FULL_SOVEREIGN' then
    raise exception 'ERR_DELEGATE_FORBIDDEN_FULL_SOVEREIGN: Delegados autorizados jamais podem receber escopo FULL_SOVEREIGN.'
      using errcode = '42501';
  end if;

  if new.seat_role = 'SOVEREIGN_CEO' then
    new.permission_scope := 'FULL_SOVEREIGN';
    new.expires_at := null;
  end if;

  if new.seat_role = 'AUTHORIZED_DELEGATE' and new.is_active = true then
    select count(*)::integer
      into v_active_delegates
      from private.founder_sovereign_acl acl
     where acl.seat_role = 'AUTHORIZED_DELEGATE'
       and acl.is_active = true
       and acl.user_id <> new.user_id;

    if v_active_delegates >= 3 then
      raise exception 'ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED: Trava física de kernel atingida (máximo absoluto de 3 delegados ativos).'
        using errcode = 'P0001';
    end if;
  end if;

  new.updated_at := now();
  return new;
end $$;

revoke all on function private.trg_enforce_max_3_founder_delegates() from public, anon, authenticated;

drop trigger if exists enforce_max_3_founder_delegates_biu on private.founder_sovereign_acl;
create trigger enforce_max_3_founder_delegates_biu
  before insert or update on private.founder_sovereign_acl
  for each row execute function private.trg_enforce_max_3_founder_delegates();

-- Sessões efêmeras de Step-Up (armazena apenas SHA-256 hex de 64 caracteres)
create table if not exists private.founder_stepup_sessions (
  session_id         uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  session_token_hash char(64) not null unique,
  permission_scope   text not null check (
    permission_scope in (
      'FULL_SOVEREIGN',
      'READ_ONLY_ANALYTICS',
      'FINANCE_TAX_AUDITOR',
      'OPERATIONS_SECURITY'
    )
  ),
  expires_at         timestamptz not null,
  created_at         timestamptz not null default now()
);

create index if not exists idx_founder_stepup_sessions_user_exp
  on private.founder_stepup_sessions (user_id, expires_at desc);

alter table private.founder_stepup_sessions enable row level security;
alter table private.founder_stepup_sessions force row level security;
revoke all on table private.founder_stepup_sessions from public, anon, authenticated;

-- Livro-razão forense imutável (append-only) com cadeia criptográfica SHA-256
create table if not exists private.founder_audit_log (
  id                  bigserial primary key,
  actor_user_id       uuid references auth.users(id) on delete set null,
  target_user_id      uuid references auth.users(id) on delete set null,
  event_code          text not null check (btrim(event_code) <> ''),
  severity            text not null default 'INFO' check (severity in ('INFO', 'WARN', 'CRITICAL')),
  is_intrusion_canary boolean not null default false,
  payload             jsonb not null default '{}'::jsonb,
  prev_hash           char(64) not null,
  row_hash            char(64) not null unique,
  created_at          timestamptz not null default now()
);

create index if not exists idx_founder_audit_log_canary_created
  on private.founder_audit_log (is_intrusion_canary, created_at desc);

alter table private.founder_audit_log enable row level security;
alter table private.founder_audit_log force row level security;
revoke all on table private.founder_audit_log from public, anon, authenticated;

create or replace function private.trg_founder_audit_log_immutable()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  raise exception 'ERR_FOUNDER_AUDIT_IMMUTABLE: O livro-razão forense private.founder_audit_log é estritamente append-only (UPDATE/DELETE bloqueados).'
    using errcode = '42501';
end $$;

revoke all on function private.trg_founder_audit_log_immutable() from public, anon, authenticated;

drop trigger if exists founder_audit_log_block_mutation on private.founder_audit_log;
create trigger founder_audit_log_block_mutation
  before update or delete on private.founder_audit_log
  for each row execute function private.trg_founder_audit_log_immutable();

create or replace function private.compute_founder_audit_hash(
  p_prev_hash text,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_event_code text,
  p_severity text,
  p_is_canary boolean,
  p_payload jsonb,
  p_created_at timestamptz
)
returns char(64)
language sql
immutable
parallel safe
set search_path = public, extensions
as $$
  select encode(
    extensions.digest(
      convert_to(
        coalesce(p_prev_hash, repeat('0', 64)) || '|' ||
        coalesce(p_actor_user_id::text, 'anon') || '|' ||
        coalesce(p_target_user_id::text, '') || '|' ||
        coalesce(p_event_code, '') || '|' ||
        coalesce(p_severity, 'INFO') || '|' ||
        coalesce(p_is_canary, false)::text || '|' ||
        coalesce(p_payload, '{}'::jsonb)::text || '|' ||
        to_char(p_created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  )::char(64);
$$;

revoke all on function private.compute_founder_audit_hash(text, uuid, uuid, text, text, boolean, jsonb, timestamptz)
  from public, anon, authenticated;

create or replace function private.trg_founder_audit_log_hash_chain()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_prev char(64);
begin
  -- Garante cadeia linear sem bifurcação sob inserções simultâneas
  lock table private.founder_audit_log in exclusive mode;

  select fal.row_hash
    into v_prev
    from private.founder_audit_log fal
   order by fal.id desc
   limit 1;

  new.prev_hash := coalesce(v_prev, repeat('0', 64)::char(64));
  new.created_at := coalesce(new.created_at, clock_timestamp());
  new.payload := coalesce(new.payload, '{}'::jsonb);
  new.severity := coalesce(new.severity, 'INFO');
  new.is_intrusion_canary := coalesce(new.is_intrusion_canary, false);

  new.row_hash := private.compute_founder_audit_hash(
    new.prev_hash,
    new.actor_user_id,
    new.target_user_id,
    new.event_code,
    new.severity,
    new.is_intrusion_canary,
    new.payload,
    new.created_at
  );

  return new;
end $$;

revoke all on function private.trg_founder_audit_log_hash_chain() from public, anon, authenticated;

drop trigger if exists founder_audit_log_hash_chain_bi on private.founder_audit_log;
create trigger founder_audit_log_hash_chain_bi
  before insert on private.founder_audit_log
  for each row execute function private.trg_founder_audit_log_hash_chain();

-- Auxiliar interno para inserção no log forense e retorno do selo SHA-256
create or replace function private.record_founder_audit_event(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_event_code text,
  p_severity text default 'INFO',
  p_is_canary boolean default false,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row private.founder_audit_log%rowtype;
begin
  insert into private.founder_audit_log (
    actor_user_id,
    target_user_id,
    event_code,
    severity,
    is_intrusion_canary,
    payload
  ) values (
    p_actor_user_id,
    p_target_user_id,
    p_event_code,
    coalesce(p_severity, 'INFO'),
    coalesce(p_is_canary, false),
    coalesce(p_payload, '{}'::jsonb)
  )
  returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id,
    'prev_hash', v_row.prev_hash,
    'row_hash', v_row.row_hash,
    'created_at', v_row.created_at
  );
end $$;

revoke all on function private.record_founder_audit_event(uuid, uuid, text, text, boolean, jsonb)
  from public, anon, authenticated;

-- Auxiliar interno para persistência explícita de Intrusion Canary (ex.: barreira Edge/Vault)
create or replace function private.record_founder_intrusion_canary(
  p_actor_user_id uuid,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return private.record_founder_audit_event(
    p_actor_user_id,
    null,
    'INTRUSION_CANARY:' || upper(coalesce(nullif(btrim(p_reason), ''), 'UNAUTHORIZED_PROBE')),
    'CRITICAL',
    true,
    coalesce(p_metadata, '{}'::jsonb)
  );
end $$;

revoke all on function private.record_founder_intrusion_canary(uuid, text, jsonb)
  from public, anon, authenticated;

-- Verificador criptográfico integral O(N) da cadeia SHA-256 (`prev_hash` -> `row_hash`)
create or replace function private.verify_founder_audit_chain()
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_expected_prev char(64) := repeat('0', 64)::char(64);
  v_recomputed    char(64);
  r_audit         record;
begin
  for r_audit in
    select fal.id,
           fal.actor_user_id,
           fal.target_user_id,
           fal.event_code,
           fal.severity,
           fal.is_intrusion_canary,
           fal.payload,
           fal.prev_hash,
           fal.row_hash,
           fal.created_at
      from private.founder_audit_log fal
     order by fal.id asc
  loop
    if r_audit.prev_hash <> v_expected_prev then
      return false;
    end if;

    v_recomputed := private.compute_founder_audit_hash(
      r_audit.prev_hash,
      r_audit.actor_user_id,
      r_audit.target_user_id,
      r_audit.event_code,
      r_audit.severity,
      r_audit.is_intrusion_canary,
      r_audit.payload,
      r_audit.created_at
    );

    if r_audit.row_hash <> v_recomputed then
      return false;
    end if;

    v_expected_prev := r_audit.row_hash;
  end loop;

  return true;
end $$;

revoke all on function private.verify_founder_audit_chain() from public, anon, authenticated;

-- Validador somente-leitura de sessão Step-Up (100% compatível com `SET LOCAL transaction_read_only = on`)
create or replace function private.validate_founder_stepup_session(
  p_stepup_token text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_clean_tok  text := btrim(coalesce(p_stepup_token, ''));
  v_tok_hash   char(64);
  v_seat_role  text;
  v_perm_scope text;
  v_email_snap text;
  v_req_aal2   boolean;
begin
  if v_uid is null then
    raise exception 'ERR_FOUNDER_UNAUTHORIZED: Sessão autenticada inexistente.'
      using errcode = '42501';
  end if;

  if char_length(v_clean_tok) <> 64 or v_clean_tok !~ '^[0-9a-fA-F]{64}$' then
    raise exception 'ERR_STEPUP_TOKEN_INVALID: Token de sessão step-up ausente ou malformado.'
      using errcode = '42501';
  end if;

  v_tok_hash := encode(extensions.digest(convert_to(lower(v_clean_tok), 'UTF8'), 'sha256'), 'hex')::char(64);

  select acl.seat_role,
         acl.permission_scope,
         acl.email_snapshot,
         acl.require_aal2
    into v_seat_role,
         v_perm_scope,
         v_email_snap,
         v_req_aal2
    from private.founder_stepup_sessions fss
    join private.founder_sovereign_acl acl
      on acl.user_id = fss.user_id
   where fss.session_token_hash = v_tok_hash
     and fss.user_id = v_uid
     and fss.expires_at > now()
     and acl.is_active = true
     and (acl.expires_at is null or acl.expires_at > now())
     and (acl.locked_until is null or acl.locked_until <= now());

  if not found then
    raise exception 'ERR_STEPUP_SESSION_INVALID_OR_REVOKED: Sessão step-up inválida, expirada ou revogada pelo Kill-Switch.'
      using errcode = '42501';
  end if;

  if v_req_aal2 and coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'ERR_AAL2_MFA_REQUIRED: Assento soberano exige segundo fator criptográfico AAL2 ativo.'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'user_id', v_uid,
    'seat_role', v_seat_role,
    'permission_scope', v_perm_scope,
    'email_snapshot', v_email_snap
  );
end $$;

revoke all on function private.validate_founder_stepup_session(text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Covering `INCLUDE` Indexes (`< 15 ms` Read-Only Index-Only Aggregation)
-- -----------------------------------------------------------------------------
create index if not exists idx_founder_jobs_cockpit_covering
  on public.jobs (status, created_at desc)
  include (
    category,
    labor_amount,
    materials_amount,
    agreed_price,
    escrow_status,
    payment_status,
    is_warranty_rework,
    warranty_expires_at,
    approved_at,
    finished_at,
    provider_id
  );

create index if not exists idx_founder_jobs_escrow_watch_covering
  on public.jobs (escrow_status, updated_at desc)
  include (
    category,
    labor_amount,
    materials_amount,
    agreed_price,
    address_summary
  )
  where escrow_status in ('LOCKED_100', 'FROZEN_IN_MEDIATION', 'FROZEN_UNDER_DURESS');

create index if not exists idx_founder_escrow_maturation_covering
  on public.escrow_maturation_entries (maturation_status, created_at desc)
  include (
    job_id,
    available_at,
    gross_labor_amount,
    materials_reimbursement_amount,
    platform_operational_fee,
    warranty_carveout_fee,
    net_provider_amount
  );

create index if not exists idx_founder_warranty_pool_covering
  on public.warranty_pool_ledger (entry_type, created_at desc)
  include (
    amount,
    labor_reference_cap,
    job_id
  );

create index if not exists idx_founder_fiscal_docs_covering
  on public.job_fiscal_documents (verification_status, created_at desc)
  include (
    job_id,
    declared_material_amount,
    access_key_44,
    clawback_triggered,
    sefaz_status_recheck
  );

-- -----------------------------------------------------------------------------
-- 3. Zero-Trust `SECURITY DEFINER` RPCs (`SET search_path = public, extensions`)
-- -----------------------------------------------------------------------------

-- 3.1 Bootstrap único do assento vitalício `SOVEREIGN_CEO` (exclusivo `is_admin()`)
create or replace function public.founder_bootstrap_sovereign_ceo(
  p_master_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid := auth.uid();
  v_pin      text := btrim(coalesce(p_master_pin, ''));
  v_email    text;
  v_pin_hash text;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão autenticada obrigatória.'
      using errcode = '28000';
  end if;

  if not public.is_admin() then
    raise exception 'ERR_FORBIDDEN_BOOTSTRAP: Apenas administrador autenticado pode inicializar o assento SOVEREIGN_CEO.'
      using errcode = '42501';
  end if;

  if char_length(v_pin) < 6 or char_length(v_pin) > 128 then
    raise exception 'ERR_WEAK_MASTER_PIN: O Master PIN soberano deve possuir entre 6 e 128 caracteres.'
      using errcode = '22023';
  end if;

  lock table private.founder_sovereign_acl in exclusive mode;

  if exists (
    select 1
      from private.founder_sovereign_acl acl
     where acl.seat_role = 'SOVEREIGN_CEO'
       and acl.is_active = true
  ) then
    raise exception 'ERR_SOVEREIGN_CEO_ALREADY_BOOTSTRAPPED: Já existe um assento SOVEREIGN_CEO ativo no kernel.'
      using errcode = 'P0001';
  end if;

  select coalesce(nullif(btrim(au.email), ''), 'ceo@desperrengue.local')
    into v_email
    from auth.users au
   where au.id = v_uid;

  v_email := coalesce(v_email, 'ceo@desperrengue.local');
  v_pin_hash := extensions.crypt(v_pin, extensions.gen_salt('bf', 10));

  insert into private.founder_sovereign_acl (
    user_id,
    email_snapshot,
    seat_role,
    permission_scope,
    authorized_by,
    master_pin_hash,
    require_aal2,
    is_active,
    failed_attempts,
    locked_until,
    expires_at
  ) values (
    v_uid,
    lower(v_email),
    'SOVEREIGN_CEO',
    'FULL_SOVEREIGN',
    v_uid,
    v_pin_hash,
    false,
    true,
    0,
    null,
    null
  )
  on conflict (user_id) do update
    set email_snapshot   = excluded.email_snapshot,
        seat_role        = 'SOVEREIGN_CEO',
        permission_scope = 'FULL_SOVEREIGN',
        authorized_by    = v_uid,
        master_pin_hash  = excluded.master_pin_hash,
        is_active        = true,
        failed_attempts  = 0,
        locked_until     = null,
        expires_at       = null,
        updated_at       = now();

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'BOOTSTRAP_SOVEREIGN_CEO',
    'INFO',
    false,
    jsonb_build_object('seat_role', 'SOVEREIGN_CEO', 'permission_scope', 'FULL_SOVEREIGN')
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', v_uid,
    'seat_role', 'SOVEREIGN_CEO',
    'permission_scope', 'FULL_SOVEREIGN'
  );
end $$;

revoke all on function public.founder_bootstrap_sovereign_ceo(text) from public, anon;
grant execute on function public.founder_bootstrap_sovereign_ceo(text) to authenticated;

comment on function public.founder_bootstrap_sovereign_ceo(text) is
  'Inicializa o único assento vitalício SOVEREIGN_CEO (exige public.is_admin() = TRUE, PIN >= 6 chars e nenhum CEO ativo prévio; hash Blowfish bf/10).';

-- 3.2 Registro explícito de Intrusion Canary persistente (sobrevive em transação própria antes de rejeição UI/Edge)
create or replace function public.founder_report_security_canary(
  p_event_code text,
  p_details jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_code  text := upper(regexp_replace(btrim(coalesce(p_event_code, 'UNAUTHORIZED_VAULT_PROBE')), '[^A-Za-z0-9_:-]', '_', 'g'));
  v_audit jsonb;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão autenticada obrigatória.'
      using errcode = '28000';
  end if;

  if octet_length(coalesce(p_details, '{}'::jsonb)::text) > 4096 then
    raise exception 'ERR_CANARY_PAYLOAD_TOO_LARGE: Payload excede 4 KB.'
      using errcode = '22023';
  end if;

  v_audit := private.record_founder_intrusion_canary(
    v_uid,
    left(coalesce(nullif(v_code, ''), 'UNAUTHORIZED_VAULT_PROBE'), 64),
    coalesce(p_details, '{}'::jsonb)
  );

  return jsonb_build_object(
    'ok', true,
    'canary_logged', true,
    'row_hash', v_audit ->> 'row_hash'
  );
end $$;

revoke all on function public.founder_report_security_canary(text, jsonb) from public, anon;
grant execute on function public.founder_report_security_canary(text, jsonb) to authenticated;

comment on function public.founder_report_security_canary(text, jsonb) is
  'Persiste um alerta silencioso is_intrusion_canary = TRUE na cadeia SHA-256 de private.founder_audit_log em transação comitada.';

-- 3.3 Desbloqueio de sessão Step-Up com verificação Blowfish e Backoff Exponencial
--     Nota arquitetural PostgreSQL:
--     - Chamadores fora da ACL soberana ativa disparam `RAISE EXCEPTION` com `SQLSTATE '42501'`
--       (em PostgreSQL, exceções não capturadas revertam subtransações locais; para persistir
--       canários antes do erro na borda, utilize `founder_report_security_canary` ou
--       `private.record_founder_intrusion_canary`).
--     - Titulares ativos na ACL que digitarem PIN incorreto recebem resposta estruturada
--       `{"ok": false, "error_code": "ERR_INVALID_MASTER_PIN" | "ERR_STEPUP_LOCKED_BACKOFF", ...}`
--       (com `stepup_token: null`), garantindo que `failed_attempts`, `locked_until` (backoff
--       exponencial a partir da 3ª falha) e o registro em `founder_audit_log` sejam COMITADOS
--       duravelmente no PostgreSQL!
create or replace function public.founder_unlock_stepup_session(
  p_master_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_pin        text := btrim(coalesce(p_master_pin, ''));
  v_acl        private.founder_sovereign_acl%rowtype;
  v_failed     integer;
  v_lock_until timestamptz;
  v_raw_token  text;
  v_tok_hash   char(64);
  v_expires_at timestamptz;
begin
  if v_uid is null then
    raise exception 'ERR_FOUNDER_UNAUTHORIZED: Sessão autenticada obrigatória para o Cofre Soberano.'
      using errcode = '42501';
  end if;

  select *
    into v_acl
    from private.founder_sovereign_acl acl
   where acl.user_id = v_uid
     for update;

  if not found
     or v_acl.is_active = false
     or (v_acl.expires_at is not null and v_acl.expires_at <= now()) then
    perform private.record_founder_intrusion_canary(
      v_uid,
      'UNAUTHORIZED_STEPUP_ATTEMPT',
      jsonb_build_object('has_seat', found)
    );
    raise exception 'ERR_FOUNDER_UNAUTHORIZED: Acesso restrito exclusivamente ao SOVEREIGN_CEO e até 3 delegados ativos.'
      using errcode = '42501';
  end if;

  if v_acl.require_aal2 and coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'ERR_AAL2_MFA_REQUIRED: Assento soberano exige autenticação multifator AAL2.'
      using errcode = '42501';
  end if;

  -- Verifica trava temporal de backoff exponencial vigente
  if v_acl.locked_until is not null and v_acl.locked_until > now() then
    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'STEPUP_UNLOCK_BLOCKED_LOCKOUT',
      'WARN',
      true,
      jsonb_build_object(
        'failed_attempts', v_acl.failed_attempts,
        'locked_until', v_acl.locked_until
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_LOCKED_BACKOFF',
      'failed_attempts', v_acl.failed_attempts,
      'locked_until', v_acl.locked_until,
      'stepup_token', null
    );
  end if;

  -- Validação em tempo constante via Blowfish (`pgcrypto.crypt`)
  if v_pin = '' or v_acl.master_pin_hash <> extensions.crypt(v_pin, v_acl.master_pin_hash) then
    v_failed := v_acl.failed_attempts + 1;
    if v_failed >= 3 then
      v_lock_until := now() + (interval '30 seconds' * power(2, least(v_failed - 3, 6)));
    else
      v_lock_until := null;
    end if;

    update private.founder_sovereign_acl
       set failed_attempts = v_failed,
           locked_until    = v_lock_until,
           updated_at      = now()
     where user_id = v_uid;

    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'STEPUP_INVALID_MASTER_PIN',
      case when v_failed >= 3 then 'CRITICAL' else 'WARN' end,
      (v_failed >= 3),
      jsonb_build_object(
        'failed_attempts', v_failed,
        'locked_until', v_lock_until
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_lock_until is not null then 'ERR_STEPUP_LOCKED_BACKOFF' else 'ERR_INVALID_MASTER_PIN' end,
      'failed_attempts', v_failed,
      'locked_until', v_lock_until,
      'stepup_token', null
    );
  end if;

  -- Sucesso: zera contador de falhas, limpa sessões vencidas e emite token efêmero de 256 bits
  update private.founder_sovereign_acl
     set failed_attempts = 0,
         locked_until    = null,
         updated_at      = now()
   where user_id = v_uid;

  delete from private.founder_stepup_sessions
   where user_id = v_uid
     and expires_at <= now();

  v_raw_token := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_tok_hash := encode(extensions.digest(convert_to(v_raw_token, 'UTF8'), 'sha256'), 'hex')::char(64);
  v_expires_at := case
    when v_acl.expires_at is not null then least(now() + interval '15 minutes', v_acl.expires_at)
    else now() + interval '15 minutes'
  end;

  insert into private.founder_stepup_sessions (
    user_id,
    session_token_hash,
    permission_scope,
    expires_at
  ) values (
    v_uid,
    v_tok_hash,
    v_acl.permission_scope,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'STEPUP_SESSION_UNLOCKED',
    'INFO',
    false,
    jsonb_build_object(
      'seat_role', v_acl.seat_role,
      'permission_scope', v_acl.permission_scope,
      'expires_at', v_expires_at
    )
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', v_uid,
    'stepup_token', v_raw_token,
    'seat_role', v_acl.seat_role,
    'permission_scope', v_acl.permission_scope,
    'expires_at', v_expires_at
  );
end $$;

revoke all on function public.founder_unlock_stepup_session(text) from public, anon;
grant execute on function public.founder_unlock_stepup_session(text) to authenticated;

comment on function public.founder_unlock_stepup_session(text) is
  'Desbloqueia sessão efêmera de step-up (15 min, SHA-256 em repouso) para assentos ativos em private.founder_sovereign_acl. Rejeita estranhos com 42501 e aplica backoff exponencial em falhas de Master PIN.';

-- 3.4 Autorização nominal de Delegado (exclusivo `SOVEREIGN_CEO`, teto físico de 3 vagas)
create or replace function public.founder_authorize_delegate(
  p_stepup_token text,
  p_target_email text,
  p_permission_scope text,
  p_initial_pin text,
  p_expires_in_days integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller          jsonb;
  v_caller_uid      uuid;
  v_clean_email     text := lower(btrim(coalesce(p_target_email, '')));
  v_clean_scope     text := upper(btrim(coalesce(p_permission_scope, '')));
  v_clean_pin       text := btrim(coalesce(p_initial_pin, ''));
  v_target_uid      uuid;
  v_resolved_email  text;
  v_pin_hash        text;
  v_expires_at      timestamptz := null;
  v_active_count    integer := 0;
begin
  v_caller := private.validate_founder_stepup_session(p_stepup_token);
  v_caller_uid := (v_caller ->> 'user_id')::uuid;

  if (v_caller ->> 'seat_role') <> 'SOVEREIGN_CEO' then
    raise exception 'ERR_SOVEREIGN_CEO_REQUIRED: Apenas o SOVEREIGN_CEO pode autorizar delegados.'
      using errcode = '42501';
  end if;

  if v_clean_scope = 'FULL_SOVEREIGN' then
    raise exception 'ERR_DELEGATE_FORBIDDEN_FULL_SOVEREIGN: Delegados não podem receber escopo FULL_SOVEREIGN.'
      using errcode = '42501';
  end if;

  if v_clean_scope not in ('READ_ONLY_ANALYTICS', 'FINANCE_TAX_AUDITOR', 'OPERATIONS_SECURITY') then
    raise exception 'ERR_INVALID_PERMISSION_SCOPE: Escopo inválido (%).', coalesce(p_permission_scope, 'null')
      using errcode = '22023';
  end if;

  if v_clean_email = '' or position('@' in v_clean_email) <= 1 then
    raise exception 'ERR_INVALID_TARGET_EMAIL: Informe um endereço de e-mail válido.'
      using errcode = '22023';
  end if;

  if char_length(v_clean_pin) < 6 or char_length(v_clean_pin) > 128 then
    raise exception 'ERR_WEAK_INITIAL_PIN: O PIN inicial do delegado deve ter entre 6 e 128 caracteres.'
      using errcode = '22023';
  end if;

  if p_expires_in_days is not null and (p_expires_in_days < 1 or p_expires_in_days > 3650) then
    raise exception 'ERR_INVALID_EXPIRATION_DAYS: p_expires_in_days deve estar entre 1 e 3650 dias.'
      using errcode = '22023';
  end if;

  select au.id, lower(btrim(au.email))
    into v_target_uid, v_resolved_email
    from auth.users au
   where lower(btrim(au.email)) = v_clean_email
     and au.deleted_at is null
   limit 1;

  if v_target_uid is null then
    raise exception 'ERR_TARGET_USER_NOT_FOUND: Nenhuma conta auth.users ativa encontrada para o e-mail informado.'
      using errcode = 'P0002';
  end if;

  if v_target_uid = v_caller_uid then
    raise exception 'ERR_CANNOT_DELEGATE_TO_SELF: O SOVEREIGN_CEO já possui soberania vitalícia total.'
      using errcode = 'P0001';
  end if;

  -- Desativa automaticamente delegações já expiradas antes de alocar vaga
  update private.founder_sovereign_acl
     set is_active  = false,
         updated_at = now()
   where seat_role = 'AUTHORIZED_DELEGATE'
     and is_active = true
     and expires_at is not null
     and expires_at <= now();

  if p_expires_in_days is not null then
    v_expires_at := now() + (p_expires_in_days || ' days')::interval;
  end if;

  v_pin_hash := extensions.crypt(v_clean_pin, extensions.gen_salt('bf', 10));

  -- A trigger `private.trg_enforce_max_3_founder_delegates()` executa `LOCK TABLE ... IN EXCLUSIVE MODE`
  -- e barra uma 4ª vaga ativa com `ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED` (SQLSTATE P0001).
  insert into private.founder_sovereign_acl (
    user_id,
    email_snapshot,
    seat_role,
    permission_scope,
    authorized_by,
    master_pin_hash,
    require_aal2,
    is_active,
    failed_attempts,
    locked_until,
    expires_at
  ) values (
    v_target_uid,
    v_resolved_email,
    'AUTHORIZED_DELEGATE',
    v_clean_scope,
    v_caller_uid,
    v_pin_hash,
    false,
    true,
    0,
    null,
    v_expires_at
  )
  on conflict (user_id) do update
    set email_snapshot   = excluded.email_snapshot,
        seat_role        = 'AUTHORIZED_DELEGATE',
        permission_scope = excluded.permission_scope,
        authorized_by    = v_caller_uid,
        master_pin_hash  = excluded.master_pin_hash,
        is_active        = true,
        failed_attempts  = 0,
        locked_until     = null,
        expires_at       = excluded.expires_at,
        updated_at       = now();

  -- Invalida quaisquer sessões anteriores do delegado caso seu escopo/PIN tenha sido redefinido
  delete from private.founder_stepup_sessions
   where user_id = v_target_uid;

  select count(*)::integer
    into v_active_count
    from private.founder_sovereign_acl acl
   where acl.seat_role = 'AUTHORIZED_DELEGATE'
     and acl.is_active = true
     and (acl.expires_at is null or acl.expires_at > now());

  perform private.record_founder_audit_event(
    v_caller_uid,
    v_target_uid,
    'DELEGATE_AUTHORIZED',
    'INFO',
    false,
    jsonb_build_object(
      'permission_scope', v_clean_scope,
      'expires_at', v_expires_at,
      'active_delegates_count', v_active_count
    )
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', v_target_uid,
    'email_snapshot', v_resolved_email,
    'seat_role', 'AUTHORIZED_DELEGATE',
    'permission_scope', v_clean_scope,
    'expires_at', v_expires_at,
    'active_delegates_count', v_active_count
  );
end $$;

revoke all on function public.founder_authorize_delegate(text, text, text, text, integer) from public, anon;
grant execute on function public.founder_authorize_delegate(text, text, text, text, integer) to authenticated;

comment on function public.founder_authorize_delegate(text, text, text, text, integer) is
  'Autoriza nominalmente um delegado (exclusivo SOVEREIGN_CEO via sessão step-up ativa), respeitando a trava física de kernel de no máximo 3 delegados ativos (ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED).';

-- 3.5 Kill-Switch Imediato de Delegado (`is_active = FALSE` + expurgo de `founder_stepup_sessions`)
create or replace function public.founder_revoke_delegate(
  p_stepup_token text,
  p_target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller            jsonb;
  v_caller_uid        uuid;
  v_target_seat       private.founder_sovereign_acl%rowtype;
  v_killed_sessions   integer := 0;
  v_active_delegates  integer := 0;
begin
  v_caller := private.validate_founder_stepup_session(p_stepup_token);
  v_caller_uid := (v_caller ->> 'user_id')::uuid;

  if (v_caller ->> 'seat_role') <> 'SOVEREIGN_CEO' then
    raise exception 'ERR_SOVEREIGN_CEO_REQUIRED: Apenas o SOVEREIGN_CEO pode acionar o Kill-Switch de revogação.'
      using errcode = '42501';
  end if;

  if p_target_user_id is null then
    raise exception 'ERR_TARGET_USER_REQUIRED: Identificador do delegado obrigatório.'
      using errcode = '22023';
  end if;

  select *
    into v_target_seat
    from private.founder_sovereign_acl acl
   where acl.user_id = p_target_user_id
     for update;

  if not found then
    raise exception 'ERR_DELEGATE_NOT_FOUND: Assento delegado inexistente.'
      using errcode = 'P0002';
  end if;

  if v_target_seat.seat_role = 'SOVEREIGN_CEO' or p_target_user_id = v_caller_uid then
    raise exception 'ERR_CANNOT_REVOKE_SOVEREIGN_CEO: O assento vitalício SOVEREIGN_CEO é irrevogável.'
      using errcode = '42501';
  end if;

  update private.founder_sovereign_acl
     set is_active  = false,
         updated_at = now()
   where user_id = p_target_user_id
     and seat_role = 'AUTHORIZED_DELEGATE';

  with purged as (
    delete from private.founder_stepup_sessions
     where user_id = p_target_user_id
    returning 1
  )
  select count(*)::integer into v_killed_sessions from purged;

  select count(*)::integer
    into v_active_delegates
    from private.founder_sovereign_acl acl
   where acl.seat_role = 'AUTHORIZED_DELEGATE'
     and acl.is_active = true
     and (acl.expires_at is null or acl.expires_at > now());

  perform private.record_founder_audit_event(
    v_caller_uid,
    p_target_user_id,
    'DELEGATE_REVOKED_KILL_SWITCH',
    'WARN',
    false,
    jsonb_build_object(
      'sessions_terminated', v_killed_sessions,
      'active_delegates_count', v_active_delegates
    )
  );

  return jsonb_build_object(
    'ok', true,
    'revoked_user_id', p_target_user_id,
    'sessions_terminated', v_killed_sessions,
    'active_delegates_count', v_active_delegates
  );
end $$;

revoke all on function public.founder_revoke_delegate(text, uuid) from public, anon;
grant execute on function public.founder_revoke_delegate(text, uuid) to authenticated;

comment on function public.founder_revoke_delegate(text, uuid) is
  'Kill-Switch soberano (exclusivo SOVEREIGN_CEO): desativa imediatamente o assento delegado e destrói todas as suas sessões ativas em private.founder_stepup_sessions.';

-- 3.6 Execução Auditada de Ações Estratégicas (`FULL_SOVEREIGN` ou `OPERATIONS_SECURITY`)
create or replace function public.founder_execute_strategic_action(
  p_stepup_token text,
  p_action_code text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller      jsonb;
  v_caller_uid  uuid;
  v_scope       text;
  v_clean_code  text := upper(regexp_replace(btrim(coalesce(p_action_code, '')), '[^A-Za-z0-9_:-]', '_', 'g'));
  v_audit       jsonb;
begin
  v_caller := private.validate_founder_stepup_session(p_stepup_token);
  v_caller_uid := (v_caller ->> 'user_id')::uuid;
  v_scope := v_caller ->> 'permission_scope';

  if v_scope not in ('FULL_SOVEREIGN', 'OPERATIONS_SECURITY') then
    raise exception 'ERR_INSUFFICIENT_FOUNDER_SCOPE: O escopo % não possui permissão para executar ações estratégicas operacionais.',
      v_scope using errcode = '42501';
  end if;

  if v_clean_code = '' or char_length(v_clean_code) > 80 then
    raise exception 'ERR_INVALID_ACTION_CODE: Código de ação estratégica obrigatório (1..80 chars).'
      using errcode = '22023';
  end if;

  v_audit := private.record_founder_audit_event(
    v_caller_uid,
    null,
    'STRATEGIC_ACTION:' || v_clean_code,
    'INFO',
    false,
    coalesce(p_payload, '{}'::jsonb)
  );

  return jsonb_build_object(
    'ok', true,
    'action_code', v_clean_code,
    'row_hash', v_audit ->> 'row_hash',
    'prev_hash', v_audit ->> 'prev_hash',
    'executed_at', v_audit ->> 'created_at'
  );
end $$;

revoke all on function public.founder_execute_strategic_action(text, text, jsonb) from public, anon;
grant execute on function public.founder_execute_strategic_action(text, text, jsonb) to authenticated;

comment on function public.founder_execute_strategic_action(text, text, jsonb) is
  'Registra ação estratégica executiva na cadeia imutável SHA-256 de private.founder_audit_log (exige FULL_SOVEREIGN ou OPERATIONS_SECURITY).';

-- 3.7 Snapshot Executivo Unificado Somente-Leitura (`SET LOCAL transaction_read_only = on;`)
create or replace function public.founder_get_cockpit_snapshot(
  p_stepup_token text,
  p_days_window integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller                       jsonb;
  v_viewer_role                  text;
  v_viewer_scope                 text;
  v_can_view_fiscal_keys         boolean;
  v_can_view_security_dossiers   boolean;
  v_can_view_acl_emails          boolean;
  v_days                         integer := greatest(1, least(coalesce(p_days_window, 30), 3650));
  v_window_start                 timestamptz;
  -- Demografia & LGPD
  v_only_clients                 integer := 0;
  v_only_providers               integer := 0;
  v_dual_mode_both               integer := 0;
  v_total_users                  integer := 0;
  v_kyc_verified                 integer := 0;
  v_kyc_pending                  integer := 0;
  v_kyc_rejected                 integer := 0;
  v_lgpd_client                  integer := 0;
  v_lgpd_provider                integer := 0;
  v_lgpd_all                     integer := 0;
  v_tier0_kyc_count              integer := 0;
  -- DRE CPC 47 / IFRS 15 (BIGINT centavos)
  v_completed_orders             integer := 0;
  v_gmv_total_cents              bigint := 0;
  v_labor_gross_cents            bigint := 0;
  v_materials_exempt_cents       bigint := 0;
  v_provider_net_labor_cents     bigint := 0;
  v_platform_op_fee_cents        bigint := 0;
  v_sos_fee_revenue_cents        bigint := 0;
  v_platform_gross_revenue_cents bigint := 0;
  v_warranty_carveout_cents      bigint := 0;
  v_simples_tax_cents            bigint := 0;
  v_gross_hyp_tax_cents          bigint := 0;
  v_tax_savings_bps              integer := 0;
  v_variable_psp_cloud_cents     bigint := 0;
  v_tier0_kyc_savings_cents      bigint := 0;
  v_contribution_margin_cents    bigint := 0;
  v_fixed_opex_cents             bigint := 0;
  v_daily_fixed_opex_cents       bigint := 0;
  v_net_profit_ebitda_cents      bigint := 0;
  -- Reconciliação Contábil 3 Vias (BIGINT centavos)
  v_pix_topups_confirmed_cents   bigint := 0;
  v_ledger_topups_cents          bigint := 0;
  v_ledger_client_custody_cents  bigint := 0;
  v_ledger_global_imbalance      bigint := 0;
  v_wallets_and_escrow_cents     bigint := 0;
  v_discrepancy_cents            bigint := 0;
  -- Tesouraria, Float & Maturação
  v_available_wallets_cents      bigint := 0;
  v_active_exec_escrow_cents     bigint := 0;
  v_maturation_d0_d2_cents       bigint := 0;
  v_maturation_d5_cents          bigint := 0;
  v_maturation_d7_cents          bigint := 0;
  v_frozen_mediation_cents       bigint := 0;
  v_frozen_duress_cents          bigint := 0;
  v_total_float_cents            bigint := 0;
  v_monthly_cdi_float_cents      bigint := 0;
  -- Fundo Garantidor Atuarial
  v_pool_credits_cents           bigint := 0;
  v_pool_debits_cents            bigint := 0;
  v_pool_running_balance_cents   bigint := 0;
  v_clawback_recovered_cents     bigint := 0;
  v_claims_paid_cents            bigint := 0;
  v_active_warranty_labor_cents  bigint := 0;
  v_open_mediation_labor_cents   bigint := 0;
  v_active_exposure_cents        bigint := 0;
  v_ica_ratio_bps                integer := 15000;
  v_fcr_layer1_bps               integer := 10000;
  -- Segurança, Geo-Privacy, SEFAZ & Auditoria
  v_pending_sefaz_26h_count      integer := 0;
  v_canceled_clawback_count      integer := 0;
  v_frozen_duress_count          integer := 0;
  v_geo_leak_bps                 integer := 0;
  v_intrusion_canaries_count     integer := 0;
  v_audit_chain_intact           boolean := true;
  -- Coleções JSONB
  v_category_matrix              jsonb := '[]'::jsonb;
  v_duress_incidents             jsonb := '[]'::jsonb;
  v_ceo_seat_json                jsonb := null;
  v_delegate_slots_json          jsonb := '[]'::jsonb;
  v_active_delegates_count       integer := 0;
  v_daily_series                 jsonb := '[]'::jsonb;
  v_recent_orders_pnl            jsonb := '[]'::jsonb;
begin
  -- Barreira física do PostgreSQL: impede qualquer mutação de estado durante o snapshot
  set local transaction_read_only = on;

  v_caller := private.validate_founder_stepup_session(p_stepup_token);
  v_viewer_role := v_caller ->> 'seat_role';
  v_viewer_scope := v_caller ->> 'permission_scope';

  v_can_view_fiscal_keys := v_viewer_scope in ('FULL_SOVEREIGN', 'FINANCE_TAX_AUDITOR');
  v_can_view_security_dossiers := v_viewer_scope in ('FULL_SOVEREIGN', 'OPERATIONS_SECURITY');
  v_can_view_acl_emails := (v_viewer_role = 'SOVEREIGN_CEO' and v_viewer_scope = 'FULL_SOVEREIGN');

  v_window_start := now() - (v_days || ' days')::interval;

  -- ---------------------------------------------------------------------------
  -- 1. Demografia de 4 Grupos + KYC + Expurgos LGPD por Escopo
  -- ---------------------------------------------------------------------------
  select count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_provider, false) = true and coalesce(prof.is_client, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = true)::integer,
         count(*)::integer,
         count(*) filter (
           where prof.verification_status = 'ACTIVE'
              or prof.client_kyc_status = 'APPROVED'
              or coalesce(prof.kyc_biometric_verified, false) = true
         )::integer,
         count(*) filter (
           where not (
             prof.verification_status = 'ACTIVE'
             or prof.client_kyc_status = 'APPROVED'
             or coalesce(prof.kyc_biometric_verified, false) = true
           )
           and (
             prof.verification_status in ('PENDING', 'APPROVED_PENDING_EMAIL')
             or prof.client_kyc_status = 'PENDING_REVIEW'
           )
         )::integer,
         count(*) filter (
           where not (
             prof.verification_status = 'ACTIVE'
             or prof.client_kyc_status = 'APPROVED'
             or coalesce(prof.kyc_biometric_verified, false) = true
           )
           and (
             prof.verification_status = 'REJECTED'
             or prof.client_kyc_status = 'REJECTED'
           )
         )::integer,
         count(*) filter (
           where coalesce(prof.ocr_verified, false) = true
             and prof.kyc_serpro_similarity is null
         )::integer
    into v_only_clients,
         v_only_providers,
         v_dual_mode_both,
         v_total_users,
         v_kyc_verified,
         v_kyc_pending,
         v_kyc_rejected,
         v_tier0_kyc_count
    from public.profiles prof;

  select count(*) filter (where adl.scope = 'client')::integer,
         count(*) filter (where adl.scope = 'provider')::integer,
         count(*) filter (where adl.scope = 'all')::integer
    into v_lgpd_client,
         v_lgpd_provider,
         v_lgpd_all
    from public.account_deletion_log adl;

  -- ---------------------------------------------------------------------------
  -- 2. DRE Gerencial & Contábil CPC 47 / IFRS 15 (100% BIGINT Centavos)
  --    Conservação exata por OS:
  --      gmv = materials_exempt + provider_net_labor + platform_op_fee + warranty_carveout
  -- ---------------------------------------------------------------------------
  with settled_jobs as (
    select jb.id,
           coalesce(jb.approved_at, jb.finished_at, jb.updated_at, jb.created_at) as settled_ts,
           gmv_calc.gmv_cents,
           ex_calc.exempt_cents,
           greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) as fee_base_labor_cents,
           fee_calc.op_fee_cents,
           fee_calc.carveout_cents,
           greatest(
             0::bigint,
             greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents)
             - fee_calc.op_fee_cents
             - fee_calc.carveout_cents
           ) as provider_net_labor_cents
      from public.jobs jb
      left join public.escrow_maturation_entries eme
        on eme.job_id = jb.id
      left join lateral (
        select pay.amount, pay.fee_amount
          from public.payments pay
         where pay.job_id = jb.id
         order by pay.created_at desc
         limit 1
      ) lp on true
      cross join lateral (
        select case
          when coalesce(jb.labor_amount, 0) + coalesce(jb.materials_amount, 0) > 0
            then round((coalesce(jb.labor_amount, 0) + coalesce(jb.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lp.amount, jb.agreed_price, 0) * 100)::bigint
        end as gmv_cents
      ) gmv_calc
      cross join lateral (
        select least(
          gmv_calc.gmv_cents,
          case
            when eme.id is not null then round(eme.materials_reimbursement_amount * 100)::bigint
            else 0::bigint
          end
        ) as exempt_cents
      ) ex_calc
      cross join lateral (
        select case
                 when eme.id is not null then round(eme.platform_operational_fee * 100)::bigint
                 when lp.fee_amount is not null and lp.fee_amount > 0 then
                   greatest(
                     0::bigint,
                     round(lp.fee_amount * 100)::bigint
                     - round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 15.0 / 1000.0)::bigint
                   )
                 else round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 135.0 / 1000.0)::bigint
               end as op_fee_cents,
               case
                 when eme.id is not null then round(eme.warranty_carveout_fee * 100)::bigint
                 else round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 15.0 / 1000.0)::bigint
               end as carveout_cents
      ) fee_calc
     where jb.status = 'completed'
       and coalesce(jb.is_warranty_rework, false) = false
       and coalesce(jb.approved_at, jb.finished_at, jb.updated_at, jb.created_at) >= v_window_start
  )
  select count(*)::integer,
         coalesce(sum(sj.gmv_cents), 0)::bigint,
         coalesce(sum(sj.fee_base_labor_cents), 0)::bigint,
         coalesce(sum(sj.exempt_cents), 0)::bigint,
         coalesce(sum(sj.provider_net_labor_cents), 0)::bigint,
         coalesce(sum(sj.op_fee_cents), 0)::bigint,
         coalesce(sum(sj.carveout_cents), 0)::bigint
    into v_completed_orders,
         v_gmv_total_cents,
         v_labor_gross_cents,
         v_materials_exempt_cents,
         v_provider_net_labor_cents,
         v_platform_op_fee_cents,
         v_warranty_carveout_cents
    from settled_jobs sj;

  select coalesce(sum(ll.cents), 0)::bigint
    into v_sos_fee_revenue_cents
    from public.ledger_lines ll
    join public.ledger_txns lt on lt.id = ll.txn_id
   where ll.account = 'platform:sos_fee'
     and lt.created_at >= v_window_start;

  v_platform_gross_revenue_cents := v_platform_op_fee_cents + greatest(0::bigint, v_sos_fee_revenue_cents);

  -- Simples Nacional Anexo III (6% exclusivamente sobre a receita líquida de intermediação CPC 47)
  v_simples_tax_cents := (v_platform_gross_revenue_cents * 6 + 50) / 100;

  -- Tributação hipotética sem Smart Split / CPC 47 (11,33% PIS/COFINS/ISS/IRPJ/CSLL sobre GMV Bruto)
  v_gross_hyp_tax_cents := (v_gmv_total_cents * 1133 + 5000) / 10000;
  if v_gross_hyp_tax_cents > 0 then
    v_tax_savings_bps := greatest(
      0,
      (((v_gross_hyp_tax_cents - v_simples_tax_cents) * 10000) / v_gross_hyp_tax_cents)::integer
    );
  else
    v_tax_savings_bps := 0;
  end if;

  -- Custo variável PSP Pix + Cloud (R$ 0,034 / OS concluída = 3,4 centavos/OS)
  v_variable_psp_cloud_cents := (v_completed_orders::bigint * 34 + 5) / 10;
  v_tier0_kyc_savings_cents := v_tier0_kyc_count::bigint * 280;

  v_contribution_margin_cents :=
    v_platform_gross_revenue_cents - v_simples_tax_cents - v_variable_psp_cloud_cents;

  -- OPEX fixo enxuto por Stage Gate (Break-Even em ~40 OS/mês; expansão em 100 OS/mês)
  v_fixed_opex_cents := case
    when v_completed_orders >= 100 then (198000::bigint * v_days) / 30
    else (98000::bigint * v_days) / 30
  end;
  v_daily_fixed_opex_cents := greatest(1::bigint, v_fixed_opex_cents / v_days);

  v_net_profit_ebitda_cents := v_contribution_margin_cents - v_fixed_opex_cents;

  -- ---------------------------------------------------------------------------
  -- 3. Reconciliação Contábil de 3 Vias (Sensibilidade Exata de 1 Centavo)
  --    Leg 1: `pix_topups` pagos vs lançamentos `topup` ativos no ledger
  --    Leg 2: Soma global de partida dobrada em `ledger_lines` == 0
  --    Leg 3: Custódia `client:*` no ledger == `available_cents + escrow_cents` em `client_wallets`
  -- ---------------------------------------------------------------------------
  select coalesce(sum(pt.amount_cents), 0)::bigint
    into v_pix_topups_confirmed_cents
    from public.pix_topups pt
   where pt.status = 'paid';

  select coalesce(
           sum(ll.cents) filter (
             where ll.account like 'client:%:available'
                or ll.account like 'client:%:escrow'
           ),
           0
         )::bigint,
         abs(coalesce(sum(ll.cents), 0)::bigint)
    into v_ledger_client_custody_cents,
         v_ledger_global_imbalance
    from public.ledger_lines ll;

  select coalesce(sum(ll_top.cents), 0)::bigint
    into v_ledger_topups_cents
    from public.ledger_txns lt_top
    join public.ledger_lines ll_top on ll_top.txn_id = lt_top.id
   where lt_top.kind = 'topup'
     and ll_top.account like 'client:%:available'
     and ll_top.account not like 'client:removed-%';

  select coalesce(sum(cw.available_cents + cw.escrow_cents), 0)::bigint,
         coalesce(sum(cw.available_cents), 0)::bigint
    into v_wallets_and_escrow_cents,
         v_available_wallets_cents
    from public.client_wallets cw;

  v_discrepancy_cents := greatest(
    abs(v_wallets_and_escrow_cents - v_ledger_client_custody_cents),
    abs(v_pix_topups_confirmed_cents - v_ledger_topups_cents),
    v_ledger_global_imbalance
  );

  -- ---------------------------------------------------------------------------
  -- 4. Tesouraria, Custódia Escrow, Histograma de Maturação D+N & Float CDI
  -- ---------------------------------------------------------------------------
  v_available_wallets_cents := v_available_wallets_cents + coalesce((
    select sum(round(prof_w.available_wallet_balance * 100)::bigint)::bigint
      from public.profiles prof_w
     where prof_w.available_wallet_balance > 0
  ), 0);

  select coalesce(sum(round(coalesce(nullif(jb_ex.labor_amount + jb_ex.materials_amount, 0), jb_ex.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_active_exec_escrow_cents
    from public.jobs jb_ex
   where (
           jb_ex.escrow_status = 'LOCKED_100'
           or (jb_ex.payment_status = 'escrow' and jb_ex.status in ('scheduled', 'in_progress', 'awaiting_approval'))
         )
     and coalesce(jb_ex.escrow_status, 'NONE') not in ('FROZEN_IN_MEDIATION', 'FROZEN_UNDER_DURESS');

  select coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) <= interval '2 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) > interval '2 days 12 hours'
               and (eme_m.available_at - eme_m.created_at) <= interval '5 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) > interval '5 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'FROZEN_BY_DISPUTE'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'FROZEN_UNDER_DURESS'
           ),
           0
         )::bigint
    into v_maturation_d0_d2_cents,
         v_maturation_d5_cents,
         v_maturation_d7_cents,
         v_frozen_mediation_cents,
         v_frozen_duress_cents
    from public.escrow_maturation_entries eme_m;

  v_frozen_mediation_cents := v_frozen_mediation_cents + coalesce((
    select sum(round(coalesce(nullif(jb_fm.labor_amount + jb_fm.materials_amount, 0), jb_fm.agreed_price, 0) * 100)::bigint)::bigint
      from public.jobs jb_fm
     where jb_fm.escrow_status = 'FROZEN_IN_MEDIATION'
       and not exists (select 1 from public.escrow_maturation_entries eme_chk1 where eme_chk1.job_id = jb_fm.id)
  ), 0);

  v_frozen_duress_cents := v_frozen_duress_cents + coalesce((
    select sum(round(coalesce(nullif(jb_fd.labor_amount + jb_fd.materials_amount, 0), jb_fd.agreed_price, 0) * 100)::bigint)::bigint
      from public.jobs jb_fd
     where jb_fd.escrow_status = 'FROZEN_UNDER_DURESS'
       and not exists (
         select 1
           from public.escrow_maturation_entries eme_chk2
          where eme_chk2.job_id = jb_fd.id
            and eme_chk2.maturation_status = 'FROZEN_UNDER_DURESS'
       )
  ), 0);

  v_total_float_cents :=
    v_available_wallets_cents
    + v_active_exec_escrow_cents
    + v_maturation_d0_d2_cents
    + v_maturation_d5_cents
    + v_maturation_d7_cents
    + v_frozen_mediation_cents
    + v_frozen_duress_cents;

  -- Rendimento líquido estimado de float CDI (~0,85% a.m. = 85 bps)
  v_monthly_cdi_float_cents := (v_total_float_cents * 85 + 5000) / 10000;

  -- ---------------------------------------------------------------------------
  -- 5. Solvência Atuarial do Fundo Garantidor (`warranty_pool_ledger`)
  -- ---------------------------------------------------------------------------
  select coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type in (
               'CARVEOUT_CONTRIBUTION_1_5_PCT',
               'CLAWBACK_RECOVERY_CREDIT',
               'COLD_START_SEED_RESERVE'
             )
           ),
           0
         )::bigint,
         coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type = 'REWORK_PAYOUT_DEBIT'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type = 'CLAWBACK_RECOVERY_CREDIT'
           ),
           0
         )::bigint
    into v_pool_credits_cents,
         v_pool_debits_cents,
         v_clawback_recovered_cents
    from public.warranty_pool_ledger wpl;

  v_claims_paid_cents := v_pool_debits_cents;
  v_pool_running_balance_cents := greatest(0::bigint, v_pool_credits_cents - v_pool_debits_cents);

  select coalesce(sum(round(coalesce(nullif(jb_w.labor_amount, 0), jb_w.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_active_warranty_labor_cents
    from public.jobs jb_w
   where jb_w.status = 'completed'
     and jb_w.warranty_expires_at > now();

  select coalesce(sum(round(coalesce(nullif(jb_om.labor_amount, 0), jb_om.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_open_mediation_labor_cents
    from public.job_mediations jm_open
    join public.jobs jb_om on jb_om.id = jm_open.job_id
   where jm_open.current_phase in (
     'PHASE_1_OPENED_AND_FROZEN',
     'PHASE_2_FORENSIC_TRIAGE',
     'PHASE_3_ORIGINAL_PROVIDER_SLA_6H'
   );

  -- Exposição atuarial esperada (1,0% VaR sobre garantias de 90d vigentes + mediações abertas)
  v_active_exposure_cents := greatest(
    v_open_mediation_labor_cents,
    (v_active_warranty_labor_cents * 100 + 5000) / 10000
  );

  if v_active_exposure_cents > 0 then
    v_ica_ratio_bps := least(99999, ((v_pool_running_balance_cents * 10000) / v_active_exposure_cents)::integer);
  elsif v_pool_running_balance_cents > 0 then
    v_ica_ratio_bps := 30000;
  else
    v_ica_ratio_bps := 15000;
  end if;

  select case
           when count(*) > 0 then
             ((count(*) filter (where jm_fcr.resolution_outcome is distinct from 'REPAIRED_BY_LAYER3_RESCUER') * 10000) / count(*))::integer
           else 10000
         end
    into v_fcr_layer1_bps
    from public.job_mediations jm_fcr;

  -- ---------------------------------------------------------------------------
  -- 6. Matriz de Liquidez das 33 Categorias Canônicas (`kCategories`)
  -- ---------------------------------------------------------------------------
  with canonical_cats(ord, slug, display_name) as (
    values
      (1,  'eletrica',              'Elétrica'),
      (2,  'encanador',             'Encanador'),
      (3,  'limpeza',               'Limpeza'),
      (4,  'montagem',              'Montagem'),
      (5,  'pintura',               'Pintura'),
      (6,  'chaveiro',              'Chaveiro'),
      (7,  'pedreiro',              'Pedreiro'),
      (8,  'gesso',                 'Gesso'),
      (9,  'marcenaria',            'Marcenaria'),
      (10, 'ar-condicionado',       'Ar-condicionado'),
      (11, 'pequenos reparos',      'Pequenos Reparos'),
      (12, 'jardinagem',            'Jardinagem'),
      (13, 'dedetizacao',           'Dedetização'),
      (14, 'vidraceiro',            'Vidraceiro'),
      (15, 'serralheria',           'Serralheria'),
      (16, 'telhados e calhas',     'Telhados e Calhas'),
      (17, 'impermeabilizacao',     'Impermeabilização'),
      (18, 'desentupidora',         'Desentupidora'),
      (19, 'piscina',               'Piscina'),
      (20, 'eletrodomesticos',      'Eletrodomésticos'),
      (21, 'tv e antenas',          'TV e Antenas'),
      (22, 'cameras e alarmes',     'Câmeras e Alarmes'),
      (23, 'portoes e interfones',  'Portões e Interfones'),
      (24, 'energia solar',         'Energia Solar'),
      (25, 'gas e aquecedores',     'Gás e Aquecedores'),
      (26, 'pisos e revestimentos', 'Pisos e Revestimentos'),
      (27, 'cortinas e persianas',  'Cortinas e Persianas'),
      (28, 'estofados e tapetes',   'Estofados e Tapetes'),
      (29, 'mudancas e fretes',     'Mudanças e Fretes'),
      (30, 'informatica e redes',   'Informática e Redes'),
      (31, 'cuidador de idosos',    'Cuidador de Idosos'),
      (32, 'baba',                  'Babá'),
      (33, 'pet care',              'Pet Care')
  ),
  demand_by_slug as (
    select public.norm_tag(jb_cat.category) as slug,
           count(*)::integer as demand_n,
           count(*) filter (where jb_cat.status in ('scheduled', 'in_progress', 'awaiting_approval', 'completed'))::integer as conv_n,
           coalesce(
             round(avg(coalesce(nullif(jb_cat.labor_amount + jb_cat.materials_amount, 0), jb_cat.agreed_price, jb_cat.budget_estimate, 0) * 100))::bigint,
             0::bigint
           ) as avg_ticket_cents
      from public.jobs jb_cat
     where jb_cat.created_at >= v_window_start
       and coalesce(jb_cat.is_warranty_rework, false) = false
     group by 1
  ),
  supply_by_slug as (
    select spec_slug as slug,
           count(distinct pp_cat.user_id)::integer as providers_n
      from public.provider_profiles pp_cat
      join public.profiles prof_cat
        on prof_cat.id = pp_cat.user_id
       and prof_cat.is_provider = true
       and prof_cat.verification_status = 'ACTIVE'
       and coalesce(pp_cat.accepting_jobs, true) = true,
      unnest(public.norm_tags(pp_cat.specialties)) as spec_slug
     group by 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'category_id', replace(cc.slug, ' ', '_'),
               'category_name', cc.display_name,
               'demand_count', coalesce(dbs.demand_n, 0),
               'active_providers_count', coalesce(sbs.providers_n, 0),
               'avg_ticket_cents', coalesce(dbs.avg_ticket_cents, 0),
               'conversion_bps', case
                 when coalesce(dbs.demand_n, 0) > 0
                   then ((coalesce(dbs.conv_n, 0) * 10000) / dbs.demand_n)::integer
                 else 0
               end
             )
             order by cc.ord asc
           ),
           '[]'::jsonb
         )
    into v_category_matrix
    from canonical_cats cc
    left join demand_by_slug dbs on dbs.slug = cc.slug
    left join supply_by_slug sbs on sbs.slug = cc.slug;

  -- ---------------------------------------------------------------------------
  -- 7. Monitoramento SEFAZ Fase 2 (> 26h), Geo-Privacy, Canários & Coação
  -- ---------------------------------------------------------------------------
  select count(*) filter (
           where jfd_w.verification_status = 'PENDING_SEFAZ'
             and jfd_w.created_at <= now() - interval '26 hours'
         )::integer,
         count(*) filter (
           where jfd_w.verification_status = 'CANCELED_CLAWBACK'
              or jfd_w.clawback_triggered = true
         )::integer
    into v_pending_sefaz_26h_count,
         v_canceled_clawback_count
    from public.job_fiscal_documents jfd_w;

  select count(*) filter (where jb_sec.escrow_status = 'FROZEN_UNDER_DURESS')::integer,
         case
           when count(*) > 0 then
             ((count(*) filter (
               where jb_sec.latitude is not null
                  or jb_sec.longitude is not null
                  or jb_sec.address_cep is not null
             ) * 10000) / count(*))::integer
           else 0
         end
    into v_frozen_duress_count,
         v_geo_leak_bps
    from public.jobs jb_sec;

  select count(*)::integer
    into v_intrusion_canaries_count
    from private.founder_audit_log fal_c
   where fal_c.is_intrusion_canary = true;

  v_audit_chain_intact := private.verify_founder_audit_chain();

  if v_can_view_security_dossiers then
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'incident_id', 'DUR-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
                 'job_id', jb_dur.id,
                 'order_code', '#DESP-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 5)),
                 'category_name', coalesce(jb_dur.category, 'Serviço'),
                 'neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Restrito'),
                 'coarse_neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Poços de Caldas - MG'),
                 'frozen_amount_cents', round(coalesce(nullif(jb_dur.labor_amount + jb_dur.materials_amount, 0), jb_dur.agreed_price, 0) * 100)::bigint,
                 'custody_status', 'FROZEN_UNDER_DURESS',
                 'masked_victim_role', 'PRESTADOR_CREDENCIADO',
                 'masked_account_ref', 'USR-' || upper(substr(replace(coalesce(jb_dur.provider_id, jb_dur.client_id)::text, '-', ''), 1, 4)) || '-****',
                 'created_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
                 'triggered_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
                 'ledger_freeze_tx_id', 'LEDGER-FRZ-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
                 'device_integrity_hash', encode(
                   extensions.digest(
                     convert_to('DEV|' || jb_dur.id::text || '|' || coalesce(jb_dur.provider_id, jb_dur.client_id)::text, 'UTF8'),
                     'sha256'
                   ),
                   'hex'
                 ),
                 'sha256_evidence_seal', encode(
                   extensions.digest(
                     convert_to(jb_dur.id::text || '|' || coalesce(jb_dur.updated_at, jb_dur.created_at)::text, 'UTF8'),
                     'sha256'
                   ),
                   'hex'
                 ),
                 'evidence_chain_hashes', jsonb_build_array(
                   encode(
                     extensions.digest(
                       convert_to(jb_dur.id::text || '|' || coalesce(jb_dur.updated_at, jb_dur.created_at)::text, 'UTF8'),
                       'sha256'
                     ),
                     'hex'
                   ),
                   encode(
                     extensions.digest(
                       convert_to('ESCROW_FREEZE|' || jb_dur.id::text, 'UTF8'),
                       'sha256'
                     ),
                     'hex'
                   )
                 ),
                 'decoy_ui_displayed', true
               )
               order by coalesce(jb_dur.updated_at, jb_dur.created_at) desc
             ),
             '[]'::jsonb
           )
      into v_duress_incidents
      from public.jobs jb_dur
     where jb_dur.escrow_status = 'FROZEN_UNDER_DURESS';
  else
    v_duress_incidents := '[]'::jsonb;
  end if;

  -- ---------------------------------------------------------------------------
  -- 8. Assentos Soberanos (`sovereign_acl_seats`: CEO + até 3 vagas delegadas)
  -- ---------------------------------------------------------------------------
  select jsonb_build_object(
           'user_id', acl_ceo.user_id,
           'email_snapshot', case
             when v_can_view_acl_emails then acl_ceo.email_snapshot
             else left(split_part(acl_ceo.email_snapshot, '@', 1), 2) || '***@' || split_part(acl_ceo.email_snapshot, '@', 2)
           end,
           'is_active', acl_ceo.is_active,
           'created_at', acl_ceo.created_at
         )
    into v_ceo_seat_json
    from private.founder_sovereign_acl acl_ceo
   where acl_ceo.seat_role = 'SOVEREIGN_CEO'
     and acl_ceo.is_active = true
   limit 1;

  with active_delegates as (
    select row_number() over (order by acl_del.created_at asc, acl_del.user_id asc)::integer as slot_idx,
           acl_del.user_id,
           acl_del.email_snapshot,
           acl_del.permission_scope,
           acl_del.is_active,
           acl_del.expires_at,
           acl_del.created_at
      from private.founder_sovereign_acl acl_del
     where acl_del.seat_role = 'AUTHORIZED_DELEGATE'
       and acl_del.is_active = true
       and (acl_del.expires_at is null or acl_del.expires_at > now())
     order by acl_del.created_at asc, acl_del.user_id asc
     limit 3
  )
  select count(*)::integer,
         coalesce(
           jsonb_agg(
             jsonb_build_object(
               'slot_index', ad.slot_idx,
               'user_id', ad.user_id,
               'email_snapshot', case
                 when v_can_view_acl_emails then ad.email_snapshot
                 else left(split_part(ad.email_snapshot, '@', 1), 2) || '***@' || split_part(ad.email_snapshot, '@', 2)
               end,
               'permission_scope', ad.permission_scope,
               'is_active', ad.is_active,
               'expires_at', ad.expires_at,
               'created_at', ad.created_at
             )
             order by ad.slot_idx asc
           ),
           '[]'::jsonb
         )
    into v_active_delegates_count,
         v_delegate_slots_json
    from active_delegates ad;

  -- ---------------------------------------------------------------------------
  -- 9. Série Temporal Diária Densa (`daily_time_series` para Prefix-Sum O(1))
  -- ---------------------------------------------------------------------------
  with calendar_days as (
    select gs::date as day_dt
      from generate_series(
        (current_date - (v_days - 1)),
        current_date,
        interval '1 day'
      ) gs
  ),
  daily_jobs as (
    select (coalesce(jb_d.approved_at, jb_d.finished_at, jb_d.updated_at, jb_d.created_at) at time zone 'UTC')::date as day_dt,
           count(*)::integer as orders_n,
           coalesce(sum(dg.gmv_c), 0)::bigint as gmv_c,
           coalesce(sum(greatest(0::bigint, dg.gmv_c - de.ex_c)), 0)::bigint as labor_c,
           coalesce(sum(de.ex_c), 0)::bigint as exempt_c,
           coalesce(sum(df.op_c), 0)::bigint as rev_c,
           coalesce(sum(df.pool_c), 0)::bigint as pool_c
      from public.jobs jb_d
      left join public.escrow_maturation_entries eme_d on eme_d.job_id = jb_d.id
      left join lateral (
        select pay_d.amount, pay_d.fee_amount
          from public.payments pay_d
         where pay_d.job_id = jb_d.id
         order by pay_d.created_at desc
         limit 1
      ) lpd on true
      cross join lateral (
        select case
          when coalesce(jb_d.labor_amount, 0) + coalesce(jb_d.materials_amount, 0) > 0
            then round((coalesce(jb_d.labor_amount, 0) + coalesce(jb_d.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lpd.amount, jb_d.agreed_price, 0) * 100)::bigint
        end as gmv_c
      ) dg
      cross join lateral (
        select least(
          dg.gmv_c,
          case when eme_d.id is not null then round(eme_d.materials_reimbursement_amount * 100)::bigint else 0::bigint end
        ) as ex_c
      ) de
      cross join lateral (
        select case
                 when eme_d.id is not null then round(eme_d.platform_operational_fee * 100)::bigint
                 when lpd.fee_amount is not null and lpd.fee_amount > 0 then
                   greatest(0::bigint, round(lpd.fee_amount * 100)::bigint - round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 15.0 / 1000.0)::bigint)
                 else round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 135.0 / 1000.0)::bigint
               end as op_c,
               case
                 when eme_d.id is not null then round(eme_d.warranty_carveout_fee * 100)::bigint
                 else round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 15.0 / 1000.0)::bigint
               end as pool_c
      ) df
     where jb_d.status = 'completed'
       and coalesce(jb_d.is_warranty_rework, false) = false
       and coalesce(jb_d.approved_at, jb_d.finished_at, jb_d.updated_at, jb_d.created_at) >= (current_date - (v_days - 1))::timestamptz
     group by 1
  ),
  daily_claims as (
    select (wpl_d.created_at at time zone 'UTC')::date as day_dt,
           coalesce(sum(round(wpl_d.amount * 100)::bigint), 0)::bigint as claims_c
      from public.warranty_pool_ledger wpl_d
     where wpl_d.entry_type = 'REWORK_PAYOUT_DEBIT'
       and wpl_d.created_at >= (current_date - (v_days - 1))::timestamptz
     group by 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'day_iso', to_char(cd.day_dt, 'YYYY-MM-DD'),
               'orders_count', coalesce(dj.orders_n, 0),
               'gmv_cents', coalesce(dj.gmv_c, 0),
               'labor_cents', coalesce(dj.labor_c, 0),
               'materials_exempt_cents', coalesce(dj.exempt_c, 0),
               'platform_revenue_cents', coalesce(dj.rev_c, 0),
               'pool_carveout_cents', coalesce(dj.pool_c, 0),
               'tax_das_cents', ((coalesce(dj.rev_c, 0) * 6 + 50) / 100),
               'variable_cost_cents', ((coalesce(dj.orders_n, 0)::bigint * 34 + 5) / 10),
               'net_profit_cents', (
                 coalesce(dj.rev_c, 0)
                 - ((coalesce(dj.rev_c, 0) * 6 + 50) / 100)
                 - ((coalesce(dj.orders_n, 0)::bigint * 34 + 5) / 10)
                 - v_daily_fixed_opex_cents
               ),
               'warranty_claims_cents', coalesce(dc.claims_c, 0)
             )
             order by cd.day_dt asc
           ),
           '[]'::jsonb
         )
    into v_daily_series
    from calendar_days cd
    left join daily_jobs dj on dj.day_dt = cd.day_dt
    left join daily_claims dc on dc.day_dt = cd.day_dt;

  -- ---------------------------------------------------------------------------
  -- 10. Inspetor Forense Micro-P&L por Ordem (`recent_orders_micro_pnl`)
  -- ---------------------------------------------------------------------------
  with recent_jobs as (
    select jb_r.id,
           jb_r.category,
           jb_r.address_summary,
           jb_r.created_at,
           jb_r.escrow_status,
           jb_r.status,
           jb_r.checkin_photo_path,
           jb_r.checkout_photo_path,
           prof_r.avatar_url as provider_avatar_url,
           rg.gmv_c,
           greatest(0::bigint, rg.gmv_c - re.ex_c) as labor_c,
           re.ex_c as exempt_c,
           rf.op_c as fee_c,
           rf.pool_c as pool_c,
           greatest(0::bigint, greatest(0::bigint, rg.gmv_c - re.ex_c) - rf.op_c - rf.pool_c) as provider_net_c,
           jfd_r.access_key_44,
           coalesce(jfd_r.verification_status = 'VERIFIED_SEFAZ', false) as nfe_verified
      from public.jobs jb_r
      left join public.profiles prof_r on prof_r.id = jb_r.provider_id
      left join public.escrow_maturation_entries eme_r on eme_r.job_id = jb_r.id
      left join lateral (
        select pay_r.amount, pay_r.fee_amount
          from public.payments pay_r
         where pay_r.job_id = jb_r.id
         order by pay_r.created_at desc
         limit 1
      ) lpr on true
      left join lateral (
        select jfd_lat.access_key_44,
               jfd_lat.verification_status,
               jfd_lat.declared_material_amount,
               jfd_lat.clawback_triggered
          from public.job_fiscal_documents jfd_lat
         where jfd_lat.job_id = jb_r.id
         order by jfd_lat.created_at desc
         limit 1
      ) jfd_r on true
      cross join lateral (
        select case
          when coalesce(jb_r.labor_amount, 0) + coalesce(jb_r.materials_amount, 0) > 0
            then round((coalesce(jb_r.labor_amount, 0) + coalesce(jb_r.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lpr.amount, jb_r.agreed_price, jb_r.budget_estimate, 0) * 100)::bigint
        end as gmv_c
      ) rg
      cross join lateral (
        select least(
          rg.gmv_c,
          case
            when eme_r.id is not null then round(eme_r.materials_reimbursement_amount * 100)::bigint
            when jfd_r.verification_status in ('PENDING_SEFAZ', 'VERIFIED_SEFAZ') and coalesce(jfd_r.clawback_triggered, false) = false
              then least(round(coalesce(jb_r.materials_amount, 0) * 100)::bigint, round(coalesce(jfd_r.declared_material_amount, 0) * 100)::bigint)
            else 0::bigint
          end
        ) as ex_c
      ) re
      cross join lateral (
        select least(
                 greatest(0::bigint, rg.gmv_c - re.ex_c) - rf_pool.pool_c,
                 case
                   when eme_r.id is not null then round(eme_r.platform_operational_fee * 100)::bigint
                   when lpr.fee_amount is not null and lpr.fee_amount > 0 then
                     greatest(0::bigint, round(lpr.fee_amount * 100)::bigint - rf_pool.pool_c)
                   else round(greatest(0::bigint, rg.gmv_c - re.ex_c) * 135.0 / 1000.0)::bigint
                 end
               ) as op_c,
               rf_pool.pool_c
          from (
            select least(
                     greatest(0::bigint, rg.gmv_c - re.ex_c),
                     case
                       when eme_r.id is not null then round(eme_r.warranty_carveout_fee * 100)::bigint
                       else round(greatest(0::bigint, rg.gmv_c - re.ex_c) * 15.0 / 1000.0)::bigint
                     end
                   ) as pool_c
          ) rf_pool
      ) rf
     where jb_r.created_at >= v_window_start
       and coalesce(jb_r.is_warranty_rework, false) = false
     order by jb_r.created_at desc
     limit 50
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'order_code', '#DESP-' || upper(substr(replace(rj.id::text, '-', ''), 1, 5)),
               'job_id', rj.id,
               'category_name', coalesce(rj.category, 'Outros'),
               'neighborhood', coalesce(nullif(btrim(rj.address_summary), ''), 'Poços de Caldas - MG'),
               'created_at', rj.created_at,
               'gmv_cents', rj.gmv_c,
               'labor_cents', rj.labor_c,
               'materials_exempt_cents', rj.exempt_c,
               'nfe_access_key', case
                 when rj.access_key_44 is null then null
                 when v_can_view_fiscal_keys then rj.access_key_44
                 else repeat('*', 40) || right(rj.access_key_44, 4)
               end,
               'nfe_verified', rj.nfe_verified,
               'provider_net_cents', rj.provider_net_c,
               'platform_fee_cents', rj.fee_c,
               'pool_carveout_cents', rj.pool_c,
               'tax_das_cents', ((rj.fee_c * 6 + 50) / 100),
               'pix_cloud_cost_cents', case when rj.status = 'completed' then 3 else 0 end,
               'net_margin_cents', (
                 rj.fee_c
                 - ((rj.fee_c * 6 + 50) / 100)
                 - (case when rj.status = 'completed' then 3 else 0 end)
               ),
               'escrow_status', coalesce(rj.escrow_status, 'NONE'),
               'provider_avatar_url', case when v_viewer_scope = 'READ_ONLY_ANALYTICS' then null else rj.provider_avatar_url end,
               'evidence_photo_url', case
                 when v_can_view_security_dossiers then coalesce(rj.checkout_photo_path, rj.checkin_photo_path)
                 else null
               end
             )
             order by rj.created_at desc
           ),
           '[]'::jsonb
         )
    into v_recent_orders_pnl
    from recent_jobs rj;

  -- ---------------------------------------------------------------------------
  -- Payload Canônico Final (`#127`)
  -- ---------------------------------------------------------------------------
  return jsonb_build_object(
    'generated_at', now(),
    'days_window', v_days,
    'viewer_seat_role', v_viewer_role,
    'viewer_permission_scope', v_viewer_scope,
    'user_demographics', jsonb_build_object(
      'only_clients_count', v_only_clients,
      'only_providers_count', v_only_providers,
      'dual_mode_both_count', v_dual_mode_both,
      'total_users_count', v_total_users,
      'kyc_verified_count', v_kyc_verified,
      'kyc_pending_count', v_kyc_pending,
      'kyc_rejected_count', v_kyc_rejected,
      'lgpd_deleted_client_count', v_lgpd_client,
      'lgpd_deleted_provider_count', v_lgpd_provider,
      'lgpd_deleted_all_count', v_lgpd_all
    ),
    'financial_dre_cents', jsonb_build_object(
      'gmv_total_cents', v_gmv_total_cents,
      'labor_gross_cents', v_labor_gross_cents,
      'materials_exempt_cents', v_materials_exempt_cents,
      'provider_net_labor_cents', v_provider_net_labor_cents,
      'platform_gross_revenue_cents', v_platform_gross_revenue_cents,
      'sos_fee_revenue_cents', greatest(0::bigint, v_sos_fee_revenue_cents),
      'warranty_pool_carveout_cents', v_warranty_carveout_cents,
      'simples_nacional_tax_cents', v_simples_tax_cents,
      'gross_gmv_hypothetical_tax_cents', v_gross_hyp_tax_cents,
      'tax_savings_bps', v_tax_savings_bps,
      'variable_psp_and_cloud_cents', v_variable_psp_cloud_cents,
      'tier0_kyc_savings_cents', v_tier0_kyc_savings_cents,
      'contribution_margin_cents', v_contribution_margin_cents,
      'fixed_opex_cents', v_fixed_opex_cents,
      'completed_orders_count', v_completed_orders,
      'stage_gate_40_reached', (v_completed_orders >= 40),
      'stage_gate_100_reached', (v_completed_orders >= 100),
      'net_profit_ebitda_cents', v_net_profit_ebitda_cents
    ),
    'three_way_reconciliation', jsonb_build_object(
      'pix_topups_confirmed_cents', v_pix_topups_confirmed_cents,
      'ledger_net_sum_cents', v_ledger_client_custody_cents,
      'wallets_and_escrow_total_cents', v_wallets_and_escrow_cents,
      'discrepancy_cents', v_discrepancy_cents,
      'three_way_reconciliation_ok', (v_discrepancy_cents = 0)
    ),
    'treasury_and_escrow_cents', jsonb_build_object(
      'available_wallets_cents', v_available_wallets_cents,
      'active_execution_escrow_cents', v_active_exec_escrow_cents,
      'maturation_d0_d2_cents', v_maturation_d0_d2_cents,
      'maturation_d5_cents', v_maturation_d5_cents,
      'maturation_d7_cents', v_maturation_d7_cents,
      'frozen_mediation_cents', v_frozen_mediation_cents,
      'frozen_under_duress_cents', v_frozen_duress_cents,
      'estimated_monthly_cdi_float_cents', v_monthly_cdi_float_cents
    ),
    'actuarial_warranty_pool', jsonb_build_object(
      'running_balance_cents', v_pool_running_balance_cents,
      'active_exposure_cents', v_active_exposure_cents,
      'ica_ratio_bps', v_ica_ratio_bps,
      'fcr_layer1_bps', v_fcr_layer1_bps,
      'clawback_recovered_cents', v_clawback_recovered_cents,
      'claims_paid_cents', v_claims_paid_cents
    ),
    'category_liquidity_matrix', v_category_matrix,
    'security_and_sefaz_watch', jsonb_build_object(
      'pending_sefaz_over_26h_count', v_pending_sefaz_26h_count,
      'canceled_clawback_count', v_canceled_clawback_count,
      'frozen_under_duress_count', v_frozen_duress_count,
      'geo_privacy_leak_bps', v_geo_leak_bps,
      'intrusion_canaries_count', v_intrusion_canaries_count,
      'audit_chain_intact', v_audit_chain_intact,
      'duress_incidents', v_duress_incidents
    ),
    'sovereign_acl_seats', jsonb_build_object(
      'ceo_seat', v_ceo_seat_json,
      'max_delegates', 3,
      'active_delegates_count', v_active_delegates_count,
      'delegate_slots', v_delegate_slots_json
    ),
    'daily_time_series', v_daily_series,
    'recent_orders_micro_pnl', v_recent_orders_pnl
  );
end $$;

revoke all on function public.founder_get_cockpit_snapshot(text, integer) from public, anon;
grant execute on function public.founder_get_cockpit_snapshot(text, integer) to authenticated;

comment on function public.founder_get_cockpit_snapshot(text, integer) is
  'Snapshot executivo Zero-Trust somente-leitura (SET LOCAL transaction_read_only = on) do Cockpit Soberano Desperrengue: demografia 4 grupos, DRE CPC 47 em BIGINT centavos, reconciliação 3 vias sensível a 1 centavo, matriz das 33 categorias, tesouraria D+N, solvência atuarial e auditoria SHA-256.';

commit;

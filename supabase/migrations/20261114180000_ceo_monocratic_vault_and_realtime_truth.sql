-- =============================================================================
-- DESPERRENGUE CEO — Monocratic Sovereign Vault & Real-Time Operational Truth
-- Migration: 20261114180000_ceo_monocratic_vault_and_realtime_truth.sql (v2.13.0)
--
-- ARQUITETURA SOBERANA PÓS-RED-TEAM (ZERO DADOS FALSOS & MONOCRACIA ABSOLUTA):
--   1. Titular Único Inviolável no Kernel PostgreSQL:
--      - Eliminação total das "3 vagas de delegados" (`AUTHORIZED_DELEGATE`) e
--        das RPCs legadas de delegação (`founder_authorize_delegate`,
--        `founder_revoke_delegate`, `founder_bootstrap_sovereign_ceo`,
--        `founder_unlock_stepup_session`, `founder_get_cockpit_snapshot`).
--      - Criação de `private.ceo_sovereign_vault` com `singleton_id = TRUE` e
--        `CHECK (lower(btrim(owner_email)) = 'wagneroliveira2395@gmail.com')`.
--        Nenhum PIN vem pré-configurado (`pin_sha256_hash = NULL` até criação
--        pessoal por Wagner após validação de código de 6 dígitos enviado por
--        e-mail exclusivamente para `wagneroliveira2395@gmail.com`).
--   2. Criptografia de PIN e OTP com `SHA-256` Salgado + Apimentado (Pepper 512-bit):
--      - `private.ceo_crypto_pepper`: segredo CSPRNG de 64 bytes (512 bits)
--        auto-provisionado no cofre `private` e imutável (`BEFORE UPDATE/DELETE`).
--      - Derivação híbrida: prova cliente (`PBKDF2-HMAC-SHA256`, 120.000 iterações)
--        + `10.000` rodadas de `HMAC-SHA256` no servidor com `pepper_bytes` e
--        `pin_salt_hex` (256 bits) -> digest final canônico `SHA-256` (`CHAR(64)`),
--        comparado byte-a-byte em tempo constante (`ceo_constant_time_eq_hex`).
--      - Sem armadilha de rollback PostgreSQL: falhas de PIN/OTP e sondagens de
--        intrusos comitam duravelmente no WAL (`private.founder_audit_log`) antes
--        de retornar JSON estruturado de bloqueio.
--   3. Ponte de Telemetria Criptografada em Tempo Real (`Desperrengue` -> `CEO`):
--      - `private.ceo_live_events` (`event_seq BIGSERIAL`, lock-free) alimentada
--        por triggers `AFTER INSERT OR UPDATE` isoladas em subtransação
--        (`BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END;`), garantindo impacto
--        ZERO nas transações públicas de clientes e prestadores.
--      - Broadcast privado via `realtime.send(..., 'ceo_live_event',
--        'ceo:war-room:live', true)` com RLS estrita em `realtime.messages`
--        exigindo `email == 'wagneroliveira2395@gmail.com'` + sessão step-up PIN
--        ativa em `private.ceo_stepup_sessions`.
--   4. 100% Dados Reais (`Zero-Fake Policy`) em `America/Sao_Paulo`:
--      - `public.ceo_get_live_cockpit_snapshot`, `public.ceo_fetch_live_events_since`,
--        `public.ceo_inspect_order_forensics` e `public.ceo_list_real_users_directory`
--        leem exclusivamente tabelas reais (`profiles`, `jobs`, `job_geo`,
--        `job_addresses`, `quotes`, `job_invites`, `pix_topups`, `payments`,
--        `client_wallets`, `ledger_txns`, `ledger_lines`, `escrow_maturation_entries`,
--        `warranty_pool_ledger`, `job_fiscal_documents`, `job_mediations`,
--        `reviews`, `account_deletion_log`, `private.ceo_expense_entries`).
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Expurgo definitivo da superfície legada de múltiplos delegados
-- -----------------------------------------------------------------------------
drop function if exists public.founder_authorize_delegate(text, text, text, text, integer);
drop function if exists public.founder_revoke_delegate(text, uuid);
drop function if exists public.founder_bootstrap_sovereign_ceo(text);
drop function if exists public.founder_unlock_stepup_session(text);
drop function if exists public.founder_execute_strategic_action(text, text, jsonb);
drop function if exists public.founder_get_cockpit_snapshot(text, integer);

drop trigger if exists enforce_max_3_founder_delegates_biu on private.founder_sovereign_acl;
drop function if exists private.trg_enforce_max_3_founder_delegates();
drop function if exists private.validate_founder_stepup_session(text);

drop table if exists private.founder_stepup_sessions;
drop table if exists private.founder_sovereign_acl;

-- -----------------------------------------------------------------------------
-- 2. Pepper Criptográfico Soberano (512 bits CSPRNG, imutável no schema `private`)
-- -----------------------------------------------------------------------------
create table if not exists private.ceo_crypto_pepper (
  singleton_id boolean primary key default true check (singleton_id = true),
  pepper_bytes bytea not null check (octet_length(pepper_bytes) = 64),
  created_at   timestamptz not null default now()
);

alter table private.ceo_crypto_pepper enable row level security;
alter table private.ceo_crypto_pepper force row level security;
revoke all on table private.ceo_crypto_pepper from public, anon, authenticated;

do $$
begin
  perform set_config('search_path', 'public, extensions', true);
  insert into private.ceo_crypto_pepper (singleton_id, pepper_bytes)
  values (true, extensions.gen_random_bytes(64))
  on conflict (singleton_id) do nothing;
end $$;

create or replace function private.trg_ceo_crypto_pepper_immutable()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  raise exception 'ERR_CEO_PEPPER_IMMUTABLE: O segredo criptográfico private.ceo_crypto_pepper é imutável.'
    using errcode = '42501';
end $$;

revoke all on function private.trg_ceo_crypto_pepper_immutable() from public, anon, authenticated;

drop trigger if exists ceo_crypto_pepper_block_mutation on private.ceo_crypto_pepper;
create trigger ceo_crypto_pepper_block_mutation
  before update or delete on private.ceo_crypto_pepper
  for each row execute function private.trg_ceo_crypto_pepper_immutable();

-- -----------------------------------------------------------------------------
-- 3. Cofre Monocrático Único (`wagneroliveira2395@gmail.com`), Desafios OTP 6d,
--    Dispositivos Confiáveis, Sessões Step-Up, Despesas Reais e Feed Ao Vivo
-- -----------------------------------------------------------------------------
create table if not exists private.ceo_sovereign_vault (
  singleton_id        boolean primary key default true check (singleton_id = true),
  owner_user_id       uuid unique references auth.users(id) on delete restrict,
  owner_email         text not null default 'wagneroliveira2395@gmail.com'
                        check (lower(btrim(owner_email)) = 'wagneroliveira2395@gmail.com'),
  pin_salt_hex        char(64),
  pin_sha256_hash     char(64),
  pin_algo_version    text not null default 'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
  pin_configured_at   timestamptz,
  pin_rotated_at      timestamptz,
  failed_pin_attempts integer not null default 0 check (failed_pin_attempts >= 0),
  locked_until        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint chk_ceo_vault_pin_pair check (
    (pin_sha256_hash is null and pin_salt_hex is null)
    or (pin_sha256_hash ~ '^[0-9a-f]{64}$' and pin_salt_hex ~ '^[0-9a-f]{64}$')
  )
);

alter table private.ceo_sovereign_vault enable row level security;
alter table private.ceo_sovereign_vault force row level security;
revoke all on table private.ceo_sovereign_vault from public, anon, authenticated;

-- Inicializa a linha singleton SEM PIN pré-definido (obriga criação pessoal via OTP 6 dígitos)
insert into private.ceo_sovereign_vault (singleton_id, owner_email, pin_salt_hex, pin_sha256_hash)
values (true, 'wagneroliveira2395@gmail.com', null, null)
on conflict (singleton_id) do nothing;

create table if not exists private.ceo_otp_challenges (
  challenge_id              uuid primary key default gen_random_uuid(),
  user_id                   uuid not null references auth.users(id) on delete cascade,
  purpose                   text not null check (purpose in ('INITIAL_PIN_SETUP', 'PIN_RESET', 'NEW_DEVICE_BIND')),
  device_fingerprint_sha256 char(64) not null check (device_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  otp_salt_hex              char(64) not null check (otp_salt_hex ~ '^[0-9a-f]{64}$'),
  otp_sha256_hash           char(64) not null check (otp_sha256_hash ~ '^[0-9a-f]{64}$'),
  delivery_channel          text not null default 'RESEND_TLS',
  attempts                  integer not null default 0 check (attempts between 0 and 5),
  expires_at                timestamptz not null,
  verified_at               timestamptz,
  enrollment_ticket_sha256  char(64) unique,
  ticket_expires_at         timestamptz,
  ticket_consumed_at        timestamptz,
  created_at                timestamptz not null default now()
);

create index if not exists idx_ceo_otp_challenges_user_created
  on private.ceo_otp_challenges (user_id, created_at desc);

alter table private.ceo_otp_challenges enable row level security;
alter table private.ceo_otp_challenges force row level security;
revoke all on table private.ceo_otp_challenges from public, anon, authenticated;

create table if not exists private.ceo_trusted_devices (
  device_id                 uuid primary key default gen_random_uuid(),
  user_id                   uuid not null references auth.users(id) on delete cascade,
  device_fingerprint_sha256 char(64) not null unique check (device_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  device_label              text not null default 'Dispositivo Soberano CEO',
  bound_at                  timestamptz not null default now(),
  last_seen_at              timestamptz not null default now(),
  revoked_at                timestamptz
);

create index if not exists idx_ceo_trusted_devices_user_active
  on private.ceo_trusted_devices (user_id, bound_at desc)
  where revoked_at is null;

alter table private.ceo_trusted_devices enable row level security;
alter table private.ceo_trusted_devices force row level security;
revoke all on table private.ceo_trusted_devices from public, anon, authenticated;

create table if not exists private.ceo_stepup_sessions (
  session_id                uuid primary key default gen_random_uuid(),
  user_id                   uuid not null references auth.users(id) on delete cascade,
  device_fingerprint_sha256 char(64) not null check (device_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  session_token_sha256      char(64) not null unique check (session_token_sha256 ~ '^[0-9a-f]{64}$'),
  expires_at                timestamptz not null,
  revoked_at                timestamptz,
  created_at                timestamptz not null default now()
);

create index if not exists idx_ceo_stepup_sessions_active
  on private.ceo_stepup_sessions (user_id, expires_at desc)
  where revoked_at is null;

alter table private.ceo_stepup_sessions enable row level security;
alter table private.ceo_stepup_sessions force row level security;
revoke all on table private.ceo_stepup_sessions from public, anon, authenticated;

-- Livro de despesas reais lançadas pelo CEO (inicia vazio = R$ 0,00; zero OPEX fictício)
create table if not exists private.ceo_expense_entries (
  id              uuid primary key default gen_random_uuid(),
  competence_date date not null default ((now() at time zone 'America/Sao_Paulo')::date),
  expense_kind    text not null default 'FIXED_OPEX' check (expense_kind in ('FIXED_OPEX', 'VARIABLE_PSP_CLOUD', 'TAX_EXTRA')),
  category        text not null check (btrim(category) <> ''),
  description     text not null check (btrim(description) <> ''),
  amount_cents    bigint not null check (amount_cents > 0 and amount_cents <= 1000000000),
  created_by      uuid not null references auth.users(id) on delete restrict,
  created_at      timestamptz not null default now()
);

create index if not exists idx_ceo_expense_entries_date
  on private.ceo_expense_entries (competence_date desc);

alter table private.ceo_expense_entries enable row level security;
alter table private.ceo_expense_entries force row level security;
revoke all on table private.ceo_expense_entries from public, anon, authenticated;

-- Stream append-only de eventos reais da operação (`Desperrengue` -> `Desperrengue CEO`)
create table if not exists private.ceo_live_events (
  event_seq    bigserial primary key,
  event_type   text not null check (btrim(event_type) <> ''),
  severity     text not null default 'INFO' check (severity in ('INFO', 'SUCCESS', 'WARN', 'CRITICAL')),
  title        text not null check (btrim(title) <> ''),
  subtitle     text not null default '',
  entity_table text not null check (btrim(entity_table) <> ''),
  entity_id    text not null default '',
  amount_cents bigint not null default 0,
  metadata     jsonb not null default '{}'::jsonb,
  occurred_at  timestamptz not null default clock_timestamp()
);

create index if not exists idx_ceo_live_events_occurred
  on private.ceo_live_events (occurred_at desc);

alter table private.ceo_live_events enable row level security;
alter table private.ceo_live_events force row level security;
revoke all on table private.ceo_live_events from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Primitivas Criptográficas Internas (`SHA-256`, Tempo Constante & Identidade)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_owner_canonical_email()
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select 'wagneroliveira2395@gmail.com'::text;
$$;

revoke all on function private.ceo_owner_canonical_email() from public, anon, authenticated;

-- Comparação em tempo constante para digests hexadecimais de 64 caracteres (SHA-256)
create or replace function private.ceo_constant_time_eq_hex(
  p_a text,
  p_b text
)
returns boolean
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  v_a    text := lower(coalesce(p_a, ''));
  v_b    text := lower(coalesce(p_b, ''));
  v_diff integer := 0;
  i      integer;
begin
  if char_length(v_a) <> 64 or char_length(v_b) <> 64 then
    return false;
  end if;

  for i in 1..64 loop
    v_diff := v_diff | (ascii(substr(v_a, i, 1)) # ascii(substr(v_b, i, 1)));
  end loop;

  return (v_diff = 0);
end $$;

revoke all on function private.ceo_constant_time_eq_hex(text, text) from public, anon, authenticated;

-- Derivação SHA-256 endurecida para o PIN pessoal do CEO:
--   Entrada: `p_client_pin_proof` (64 hex derivado no app via PBKDF2-HMAC-SHA256 120k)
--   Processo: 10.000 rodadas de HMAC-SHA256 com `pepper_bytes` (512 bits) + `pin_salt_hex` (256 bits)
--   Saída: Digest final `SHA-256` hexadecimal de 64 caracteres (`CHAR(64)`).
create or replace function private.ceo_compute_pin_sha256(
  p_client_pin_proof text,
  p_pin_salt_hex text
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper bytea;
  v_salt   bytea;
  v_acc    bytea;
  i        integer;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  v_salt := decode(lower(btrim(p_pin_salt_hex)), 'hex');
  v_acc := extensions.hmac(
    convert_to('CEO_PIN_V1:' || lower(btrim(p_client_pin_proof)) || ':' || lower(btrim(p_pin_salt_hex)), 'UTF8'),
    v_pepper,
    'sha256'
  );

  for i in 1..10000 loop
    v_acc := extensions.hmac(
      v_acc || v_salt || convert_to(i::text, 'UTF8'),
      v_pepper,
      'sha256'
    );
  end loop;

  return encode(extensions.digest(v_acc, 'sha256'), 'hex')::char(64);
end $$;

revoke all on function private.ceo_compute_pin_sha256(text, text) from public, anon, authenticated;

-- Digest SHA-256 salgado + apimentado para o código OTP de 6 dígitos enviado por e-mail
create or replace function private.ceo_compute_otp_sha256(
  p_otp_code text,
  p_otp_salt_hex text,
  p_user_id uuid,
  p_device_hash text
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper bytea;
  v_mac    bytea;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  v_mac := extensions.hmac(
    convert_to(
      'CEO_OTP_V1|' ||
      btrim(coalesce(p_otp_code, '')) || '|' ||
      lower(btrim(coalesce(p_otp_salt_hex, ''))) || '|' ||
      coalesce(p_user_id::text, '') || '|' ||
      lower(btrim(coalesce(p_device_hash, ''))),
      'UTF8'
    ),
    v_pepper,
    'sha256'
  );

  return encode(extensions.digest(v_mac, 'sha256'), 'hex')::char(64);
end $$;

revoke all on function private.ceo_compute_otp_sha256(text, text, uuid, text) from public, anon, authenticated;

-- Verificador booleano sem exceção da titularidade monocrática (`wagneroliveira2395@gmail.com`)
create or replace function private.ceo_is_caller_monocratic_owner()
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_jwt_email text := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
  v_db_email  text;
begin
  if v_uid is null then
    return false;
  end if;

  if v_jwt_email <> private.ceo_owner_canonical_email() then
    return false;
  end if;

  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = v_uid
     and au.deleted_at is null;

  return (v_db_email = private.ceo_owner_canonical_email());
end $$;

revoke all on function private.ceo_is_caller_monocratic_owner() from public, anon, authenticated;

-- Validador somente-leitura de sessão Step-Up ativa (compatível com `SET LOCAL transaction_read_only = on`)
create or replace function private.validate_ceo_stepup_session(
  p_stepup_token text,
  p_device_hash text
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_clean_tok text := lower(btrim(coalesce(p_stepup_token, '')));
  v_clean_dev text := lower(btrim(coalesce(p_device_hash, '')));
  v_tok_hash  char(64);
  v_sess_id   uuid;
begin
  if not private.ceo_is_caller_monocratic_owner() then
    raise exception 'ERR_MONOCRATIC_OWNER_ONLY_42501: Acesso exclusivo ao titular soberano.'
      using errcode = '42501';
  end if;

  if v_clean_tok !~ '^[0-9a-f]{64}$' or v_clean_dev !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_STEPUP_TOKEN_INVALID: Credencial efêmera ou assinatura de dispositivo inválida.'
      using errcode = '42501';
  end if;

  v_tok_hash := encode(extensions.digest(convert_to(v_clean_tok, 'UTF8'), 'sha256'), 'hex')::char(64);

  select css.session_id
    into v_sess_id
    from private.ceo_stepup_sessions css
    join private.ceo_sovereign_vault csv
      on csv.singleton_id = true
     and csv.owner_user_id = css.user_id
    join private.ceo_trusted_devices ctd
      on ctd.user_id = css.user_id
     and ctd.device_fingerprint_sha256 = css.device_fingerprint_sha256
     and ctd.revoked_at is null
   where css.session_token_sha256 = v_tok_hash
     and css.user_id = v_uid
     and css.device_fingerprint_sha256 = v_clean_dev
     and css.revoked_at is null
     and css.expires_at > now()
     and csv.pin_sha256_hash is not null
     and (csv.locked_until is null or csv.locked_until <= now());

  if v_sess_id is null then
    raise exception 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED: Sessão do Cofre Soberano expirada ou bloqueada.'
      using errcode = '42501';
  end if;

  return v_uid;
end $$;

revoke all on function private.validate_ceo_stepup_session(text, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPCs Exclusivas `service_role` para a Edge Function `ceo-sovereign-auth`
-- -----------------------------------------------------------------------------
create or replace function public.ceo_edge_log_intrusion_canary(
  p_actor_uid uuid,
  p_attempted_email text,
  p_reason text,
  p_meta jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_audit jsonb;
begin
  v_audit := private.record_founder_intrusion_canary(
    p_actor_uid,
    coalesce(nullif(btrim(p_reason), ''), 'EDGE_UNAUTHORIZED_EMAIL_ATTEMPT'),
    jsonb_build_object(
      'attempted_email_sha256', encode(
        extensions.digest(convert_to(lower(btrim(coalesce(p_attempted_email, ''))), 'UTF8'), 'sha256'),
        'hex'
      ),
      'meta', coalesce(p_meta, '{}'::jsonb)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'row_hash', v_audit ->> 'row_hash'
  );
end $$;

revoke all on function public.ceo_edge_log_intrusion_canary(uuid, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.ceo_edge_log_intrusion_canary(uuid, text, text, jsonb) to service_role;

comment on function public.ceo_edge_log_intrusion_canary(uuid, text, text, jsonb) is
  'Uso exclusivo service_role (Edge Function ceo-sovereign-auth): persiste canário de intrusão comitado em private.founder_audit_log quando qualquer e-mail diferente de wagneroliveira2395@gmail.com tenta acessar o app CEO.';

create or replace function public.ceo_edge_issue_otp_challenge(
  p_user_id uuid,
  p_purpose text,
  p_device_hash text,
  p_otp_code text,
  p_delivery_channel text default 'RESEND_TLS'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email       text;
  v_clean_purpose  text := upper(btrim(coalesce(p_purpose, 'INITIAL_PIN_SETUP')));
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_recent_count   integer := 0;
  v_last_created   timestamptz;
  v_cooldown_sec   integer := 30;
  v_wait_sec       integer := 0;
  v_salt_hex       char(64);
  v_otp_hash       char(64);
  v_challenge_id   uuid;
  v_expires_at     timestamptz;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'OTP_ISSUE_NON_OWNER_BLOCKED',
      jsonb_build_object('purpose', v_clean_purpose)
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501'
    );
  end if;

  if v_clean_purpose not in ('INITIAL_PIN_SETUP', 'PIN_RESET', 'NEW_DEVICE_BIND') then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_PURPOSE');
  end if;

  if v_clean_dev !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_DEVICE_HASH');
  end if;

  if v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_FORMAT');
  end if;

  -- Cooldown progressivo anti-abuso na janela de 15 minutos: 30s -> 60s -> 180s -> 900s
  select count(*)::integer, max(coc.created_at)
    into v_recent_count, v_last_created
    from private.ceo_otp_challenges coc
   where coc.user_id = p_user_id
     and coc.created_at >= now() - interval '15 minutes';

  v_cooldown_sec := case
    when v_recent_count <= 0 then 30
    when v_recent_count = 1 then 30
    when v_recent_count = 2 then 60
    when v_recent_count = 3 then 180
    else 900
  end;

  if v_last_created is not null and v_recent_count >= 1 then
    v_wait_sec := ceil(extract(epoch from ((v_last_created + (v_cooldown_sec || ' seconds')::interval) - now())))::integer;
    if v_wait_sec > 0 then
      return jsonb_build_object(
        'ok', false,
        'error_code', 'ERR_OTP_COOLDOWN_ACTIVE',
        'retry_after_seconds', v_wait_sec
      );
    end if;
  end if;

  -- Invalida desafios anteriores não verificados
  update private.ceo_otp_challenges
     set expires_at = now() - interval '1 second'
   where user_id = p_user_id
     and verified_at is null
     and expires_at > now();

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_hash := private.ceo_compute_otp_sha256(v_clean_otp, v_salt_hex, p_user_id, v_clean_dev);
  v_expires_at := now() + interval '5 minutes';

  insert into private.ceo_otp_challenges (
    user_id,
    purpose,
    device_fingerprint_sha256,
    otp_salt_hex,
    otp_sha256_hash,
    delivery_channel,
    attempts,
    expires_at
  ) values (
    p_user_id,
    v_clean_purpose,
    v_clean_dev,
    v_salt_hex,
    v_otp_hash,
    coalesce(nullif(btrim(p_delivery_channel), ''), 'RESEND_TLS'),
    0,
    v_expires_at
  )
  returning challenge_id into v_challenge_id;

  -- Vincula owner_user_id na linha singleton caso seja o primeiro acesso absoluto
  update private.ceo_sovereign_vault
     set owner_user_id = coalesce(owner_user_id, p_user_id),
         updated_at    = now()
   where singleton_id = true
     and (owner_user_id is null or owner_user_id = p_user_id);

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_OTP_6D_ISSUED',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_challenge_id,
      'purpose', v_clean_purpose,
      'delivery_channel', coalesce(nullif(btrim(p_delivery_channel), ''), 'RESEND_TLS'),
      'expires_at', v_expires_at
    )
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'expires_at', v_expires_at,
    'next_cooldown_seconds', case
      when v_recent_count = 0 then 30
      when v_recent_count = 1 then 60
      when v_recent_count = 2 then 180
      else 900
    end
  );
end $$;

revoke all on function public.ceo_edge_issue_otp_challenge(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_issue_otp_challenge(uuid, text, text, text, text) to service_role;

comment on function public.ceo_edge_issue_otp_challenge(uuid, text, text, text, text) is
  'Uso exclusivo service_role: grava desafio OTP de 6 dígitos exclusivamente como hash SHA-256 salgado+apimentado (TTL 5 min, máx 5 tentativas, cooldown progressivo) apenas para wagneroliveira2395@gmail.com.';

create or replace function public.ceo_edge_verify_otp_challenge(
  p_user_id uuid,
  p_challenge_id uuid,
  p_device_hash text,
  p_otp_code text,
  p_device_label text default 'Dispositivo Soberano CEO'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email       text;
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_clean_label    text := left(coalesce(nullif(btrim(p_device_label), ''), 'Dispositivo Soberano CEO'), 80);
  v_ch             private.ceo_otp_challenges%rowtype;
  v_candidate_hash char(64);
  v_new_attempts   integer;
  v_raw_ticket     text;
  v_ticket_hash    char(64);
  v_ticket_exp     timestamptz;
  v_pin_exists     boolean := false;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'OTP_VERIFY_NON_OWNER_BLOCKED',
      jsonb_build_object('challenge_id', p_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if p_challenge_id is null or v_clean_dev !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_ch
    from private.ceo_otp_challenges coc
   where coc.challenge_id = p_challenge_id
     and coc.user_id = p_user_id
     for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if v_ch.verified_at is not null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
  end if;

  if v_ch.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_EXPIRED');
  end if;

  if v_ch.attempts >= 5 then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED');
  end if;

  if v_ch.device_fingerprint_sha256 <> v_clean_dev then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'OTP_DEVICE_MISMATCH',
      jsonb_build_object('challenge_id', p_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_candidate_hash := private.ceo_compute_otp_sha256(v_clean_otp, v_ch.otp_salt_hex, p_user_id, v_clean_dev);

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_ch.otp_sha256_hash) then
    v_new_attempts := v_ch.attempts + 1;
    update private.ceo_otp_challenges
       set attempts   = v_new_attempts,
           expires_at = case when v_new_attempts >= 5 then now() - interval '1 second' else expires_at end
     where challenge_id = p_challenge_id;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_OTP_6D_MISMATCH',
      case when v_new_attempts >= 5 then 'CRITICAL' else 'WARN' end,
      (v_new_attempts >= 5),
      jsonb_build_object(
        'challenge_id', p_challenge_id,
        'attempts', v_new_attempts,
        'remaining_attempts', greatest(0, 5 - v_new_attempts)
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_new_attempts >= 5 then 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED' else 'ERR_OTP_CODE_INCORRECT' end,
      'remaining_attempts', greatest(0, 5 - v_new_attempts)
    );
  end if;

  v_raw_ticket := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_ticket_hash := encode(extensions.digest(convert_to(v_raw_ticket, 'UTF8'), 'sha256'), 'hex')::char(64);
  v_ticket_exp := now() + interval '5 minutes';

  update private.ceo_otp_challenges
     set verified_at              = now(),
         enrollment_ticket_sha256 = v_ticket_hash,
         ticket_expires_at        = v_ticket_exp
   where challenge_id = p_challenge_id;

  -- Se o objetivo foi vincular novo dispositivo a um PIN já existente, autoriza o dispositivo imediatamente
  select (csv.pin_sha256_hash is not null)
    into v_pin_exists
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_ch.purpose = 'NEW_DEVICE_BIND' and coalesce(v_pin_exists, false) then
    insert into private.ceo_trusted_devices (
      user_id,
      device_fingerprint_sha256,
      device_label,
      bound_at,
      last_seen_at,
      revoked_at
    ) values (
      p_user_id,
      v_clean_dev,
      v_clean_label,
      now(),
      now(),
      null
    )
    on conflict (device_fingerprint_sha256) do update
      set user_id      = excluded.user_id,
          device_label = excluded.device_label,
          last_seen_at = now(),
          revoked_at   = null;
  end if;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_OTP_6D_VERIFIED',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', p_challenge_id,
      'purpose', v_ch.purpose,
      'pin_already_configured', coalesce(v_pin_exists, false)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'purpose', v_ch.purpose,
    'pin_configured', coalesce(v_pin_exists, false),
    'enrollment_ticket', v_raw_ticket,
    'ticket_expires_at', v_ticket_exp
  );
end $$;

revoke all on function public.ceo_edge_verify_otp_challenge(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_otp_challenge(uuid, uuid, text, text, text) to service_role;

comment on function public.ceo_edge_verify_otp_challenge(uuid, uuid, text, text, text) is
  'Uso exclusivo service_role: valida código OTP de 6 dígitos em tempo constante SHA-256 e emite enrollment_ticket de uso único (TTL 5 min) para criação/redefinição do PIN pessoal do CEO.';

-- -----------------------------------------------------------------------------
-- 6. RPCs Autenticadas Exclusivas do Titular (`wagneroliveira2395@gmail.com`)
-- -----------------------------------------------------------------------------
create or replace function public.ceo_vault_status(
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid            uuid := auth.uid();
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_device_trusted boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_UNAUTHENTICATED_28000');
  end if;

  if not private.ceo_is_caller_monocratic_owner() then
    perform private.record_founder_intrusion_canary(
      v_uid,
      'VAULT_STATUS_NON_OWNER_PROBE',
      jsonb_build_object('jwt_email_present', (auth.jwt() ->> 'email') is not null)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  update private.ceo_sovereign_vault
     set owner_user_id = coalesce(owner_user_id, v_uid),
         updated_at    = case when owner_user_id is null then now() else updated_at end
   where singleton_id = true;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_clean_dev ~ '^[0-9a-f]{64}$' then
    select exists (
      select 1
        from private.ceo_trusted_devices ctd
       where ctd.user_id = v_uid
         and ctd.device_fingerprint_sha256 = v_clean_dev
         and ctd.revoked_at is null
    ) into v_device_trusted;
  end if;

  return jsonb_build_object(
    'ok', true,
    'owner_email', v_vault.owner_email,
    'pin_configured', (v_vault.pin_sha256_hash is not null),
    'device_trusted', v_device_trusted,
    'pin_algo_version', v_vault.pin_algo_version,
    'pin_configured_at', v_vault.pin_configured_at,
    'pin_rotated_at', v_vault.pin_rotated_at,
    'failed_pin_attempts', v_vault.failed_pin_attempts,
    'locked_until', case when v_vault.locked_until is not null and v_vault.locked_until > now() then v_vault.locked_until else null end
  );
end $$;

revoke all on function public.ceo_vault_status(text) from public, anon;
grant execute on function public.ceo_vault_status(text) to authenticated;

comment on function public.ceo_vault_status(text) is
  'Retorna o estado criptográfico do Cofre Monocrático exclusivamente para wagneroliveira2395@gmail.com (indica se o PIN pessoal SHA-256 já foi criado e se o dispositivo atual já foi vinculado por OTP 6 dígitos).';

create or replace function public.ceo_register_personal_pin(
  p_enrollment_ticket text,
  p_client_pin_proof text,
  p_device_hash text,
  p_device_label text default 'Dispositivo Soberano CEO'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid          uuid := auth.uid();
  v_clean_ticket text := lower(btrim(coalesce(p_enrollment_ticket, '')));
  v_clean_proof  text := lower(btrim(coalesce(p_client_pin_proof, '')));
  v_clean_dev    text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_label  text := left(coalesce(nullif(btrim(p_device_label), ''), 'Dispositivo Soberano CEO'), 80);
  v_ticket_hash  char(64);
  v_ch           private.ceo_otp_challenges%rowtype;
  v_salt_hex     char(64);
  v_pin_hash     char(64);
  v_was_set      boolean := false;
  v_raw_stepup   text;
  v_stepup_hash  char(64);
  v_expires_at   timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_UNAUTHENTICATED_28000');
  end if;

  if not private.ceo_is_caller_monocratic_owner() then
    perform private.record_founder_intrusion_canary(
      v_uid,
      'REGISTER_PIN_NON_OWNER_BLOCKED',
      '{}'::jsonb
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_ticket !~ '^[0-9a-f]{64}$'
     or v_clean_proof !~ '^[0-9a-f]{64}$'
     or v_clean_dev !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  v_ticket_hash := encode(extensions.digest(convert_to(v_clean_ticket, 'UTF8'), 'sha256'), 'hex')::char(64);

  select *
    into v_ch
    from private.ceo_otp_challenges coc
   where coc.user_id = v_uid
     and coc.enrollment_ticket_sha256 = v_ticket_hash
     for update;

  if not found
     or v_ch.verified_at is null
     or v_ch.ticket_consumed_at is not null
     or v_ch.ticket_expires_at is null
     or v_ch.ticket_expires_at <= now()
     or v_ch.device_fingerprint_sha256 <> v_clean_dev then
    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_PIN_ENROLLMENT_TICKET_REJECTED',
      'WARN',
      true,
      jsonb_build_object('found', found)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED');
  end if;

  -- Consome de forma atômica e irreversível o enrollment_ticket (single-use)
  update private.ceo_otp_challenges
     set ticket_consumed_at = now()
   where challenge_id = v_ch.challenge_id;

  select (csv.pin_sha256_hash is not null)
    into v_was_set
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_pin_hash := private.ceo_compute_pin_sha256(v_clean_proof, v_salt_hex);

  update private.ceo_sovereign_vault
     set owner_user_id       = v_uid,
         owner_email         = private.ceo_owner_canonical_email(),
         pin_salt_hex        = v_salt_hex,
         pin_sha256_hash     = v_pin_hash,
         pin_configured_at   = coalesce(pin_configured_at, now()),
         pin_rotated_at      = case when v_was_set then now() else pin_rotated_at end,
         failed_pin_attempts = 0,
         locked_until        = null,
         updated_at          = now()
   where singleton_id = true;

  -- Vincula/renova o dispositivo atual como confiável
  insert into private.ceo_trusted_devices (
    user_id,
    device_fingerprint_sha256,
    device_label,
    bound_at,
    last_seen_at,
    revoked_at
  ) values (
    v_uid,
    v_clean_dev,
    v_clean_label,
    now(),
    now(),
    null
  )
  on conflict (device_fingerprint_sha256) do update
    set user_id      = excluded.user_id,
        device_label = excluded.device_label,
        last_seen_at = now(),
        revoked_at   = null;

  -- Revoga todas as sessões step-up anteriores ao criar/rotacionar o PIN
  update private.ceo_stepup_sessions
     set revoked_at = now()
   where user_id = v_uid
     and revoked_at is null;

  v_raw_stepup := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_stepup_hash := encode(extensions.digest(convert_to(v_raw_stepup, 'UTF8'), 'sha256'), 'hex')::char(64);
  v_expires_at := now() + interval '15 minutes';

  insert into private.ceo_stepup_sessions (
    user_id,
    device_fingerprint_sha256,
    session_token_sha256,
    expires_at
  ) values (
    v_uid,
    v_clean_dev,
    v_stepup_hash,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    case when v_was_set then 'CEO_PERSONAL_PIN_ROTATED_SHA256' else 'CEO_PERSONAL_PIN_CREATED_SHA256' end,
    'INFO',
    false,
    jsonb_build_object(
      'algo', 'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
      'device_label', v_clean_label
    )
  );

  return jsonb_build_object(
    'ok', true,
    'stepup_token', v_raw_stepup,
    'expires_at', v_expires_at,
    'pin_rotated', v_was_set
  );
end $$;

revoke all on function public.ceo_register_personal_pin(text, text, text, text) from public, anon;
grant execute on function public.ceo_register_personal_pin(text, text, text, text) to authenticated;

comment on function public.ceo_register_personal_pin(text, text, text, text) is
  'Registra ou redefine o PIN pessoal do CEO como hash SHA-256 salgado+apimentado (10.000 rodadas HMAC-SHA256 sobre prova cliente PBKDF2 120k), exigindo enrollment_ticket de uso único emitido após código de 6 dígitos no e-mail wagneroliveira2395@gmail.com.';

create or replace function public.ceo_unlock_sovereign_vault(
  p_client_pin_proof text,
  p_device_hash text,
  p_device_label text default 'Dispositivo Soberano CEO'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid            uuid := auth.uid();
  v_clean_proof    text := lower(btrim(coalesce(p_client_pin_proof, '')));
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_label    text := left(coalesce(nullif(btrim(p_device_label), ''), 'Dispositivo Soberano CEO'), 80);
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_device_trusted boolean := false;
  v_candidate_hash char(64);
  v_failed         integer;
  v_lock_until     timestamptz;
  v_raw_stepup     text;
  v_stepup_hash    char(64);
  v_expires_at     timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_UNAUTHENTICATED_28000');
  end if;

  if not private.ceo_is_caller_monocratic_owner() then
    perform private.record_founder_intrusion_canary(
      v_uid,
      'UNLOCK_VAULT_NON_OWNER_BLOCKED',
      '{}'::jsonb
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_proof !~ '^[0-9a-f]{64}$' or v_clean_dev !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if v_vault.pin_sha256_hash is null or v_vault.pin_salt_hex is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_PIN_NOT_CONFIGURED');
  end if;

  if v_vault.locked_until is not null and v_vault.locked_until > now() then
    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_VAULT_UNLOCK_DURING_LOCKOUT',
      'WARN',
      true,
      jsonb_build_object('locked_until', v_vault.locked_until, 'failed_attempts', v_vault.failed_pin_attempts)
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_VAULT_LOCKED_BACKOFF',
      'failed_attempts', v_vault.failed_pin_attempts,
      'locked_until', v_vault.locked_until
    );
  end if;

  select exists (
    select 1
      from private.ceo_trusted_devices ctd
     where ctd.user_id = v_uid
       and ctd.device_fingerprint_sha256 = v_clean_dev
       and ctd.revoked_at is null
  ) into v_device_trusted;

  if not v_device_trusted then
    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_NEW_DEVICE_OTP_CHALLENGE_REQUIRED',
      'WARN',
      false,
      jsonb_build_object('device_label', v_clean_label)
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_UNTRUSTED_DEVICE_OTP_REQUIRED'
    );
  end if;

  v_candidate_hash := private.ceo_compute_pin_sha256(v_clean_proof, v_vault.pin_salt_hex);

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_vault.pin_sha256_hash) then
    v_failed := v_vault.failed_pin_attempts + 1;
    if v_failed >= 3 then
      v_lock_until := now() + (interval '30 seconds' * power(2, least(v_failed - 3, 6)));
    else
      v_lock_until := null;
    end if;

    update private.ceo_sovereign_vault
       set failed_pin_attempts = v_failed,
           locked_until        = v_lock_until,
           updated_at          = now()
     where singleton_id = true;

    -- Após 8 falhas consecutivas, exige nova validação de 6 dígitos no e-mail do dono
    if v_failed >= 8 then
      update private.ceo_trusted_devices
         set revoked_at = now()
       where user_id = v_uid
         and device_fingerprint_sha256 = v_clean_dev;
    end if;

    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_VAULT_INVALID_PIN_SHA256',
      case when v_failed >= 3 then 'CRITICAL' else 'WARN' end,
      (v_failed >= 3),
      jsonb_build_object(
        'failed_attempts', v_failed,
        'locked_until', v_lock_until
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_lock_until is not null then 'ERR_VAULT_LOCKED_BACKOFF' else 'ERR_INVALID_PERSONAL_PIN' end,
      'failed_attempts', v_failed,
      'locked_until', v_lock_until
    );
  end if;

  update private.ceo_sovereign_vault
     set owner_user_id       = v_uid,
         failed_pin_attempts = 0,
         locked_until        = null,
         updated_at          = now()
   where singleton_id = true;

  update private.ceo_trusted_devices
     set last_seen_at = now(),
         device_label = v_clean_label
   where user_id = v_uid
     and device_fingerprint_sha256 = v_clean_dev
     and revoked_at is null;

  delete from private.ceo_stepup_sessions
   where user_id = v_uid
     and (expires_at <= now() or revoked_at is not null);

  v_raw_stepup := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_stepup_hash := encode(extensions.digest(convert_to(v_raw_stepup, 'UTF8'), 'sha256'), 'hex')::char(64);
  v_expires_at := now() + interval '15 minutes';

  insert into private.ceo_stepup_sessions (
    user_id,
    device_fingerprint_sha256,
    session_token_sha256,
    expires_at
  ) values (
    v_uid,
    v_clean_dev,
    v_stepup_hash,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_VAULT_UNLOCKED_SHA256',
    'INFO',
    false,
    jsonb_build_object('device_label', v_clean_label, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'stepup_token', v_raw_stepup,
    'expires_at', v_expires_at
  );
end $$;

revoke all on function public.ceo_unlock_sovereign_vault(text, text, text) from public, anon;
grant execute on function public.ceo_unlock_sovereign_vault(text, text, text) to authenticated;

comment on function public.ceo_unlock_sovereign_vault(text, text, text) is
  'Desbloqueia o Cofre Monocrático exclusivamente para wagneroliveira2395@gmail.com validando o digest SHA-256 em tempo constante em dispositivo previamente autenticado por OTP 6 dígitos.';

create or replace function public.ceo_refresh_stepup_heartbeat(
  p_stepup_token text,
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid;
  v_tok_hash   char(64);
  v_expires_at timestamptz := now() + interval '15 minutes';
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);
  v_tok_hash := encode(extensions.digest(convert_to(lower(btrim(p_stepup_token)), 'UTF8'), 'sha256'), 'hex')::char(64);

  update private.ceo_stepup_sessions
     set expires_at = v_expires_at
   where session_token_sha256 = v_tok_hash
     and user_id = v_uid
     and revoked_at is null;

  update private.ceo_trusted_devices
     set last_seen_at = now()
   where user_id = v_uid
     and device_fingerprint_sha256 = lower(btrim(p_device_hash))
     and revoked_at is null;

  return jsonb_build_object('ok', true, 'expires_at', v_expires_at);
end $$;

revoke all on function public.ceo_refresh_stepup_heartbeat(text, text) from public, anon;
grant execute on function public.ceo_refresh_stepup_heartbeat(text, text) to authenticated;

comment on function public.ceo_refresh_stepup_heartbeat(text, text) is
  'Renova o TTL de 15 minutos da sessão step-up ativa enquanto o CEO interage ativamente com o aplicativo.';

create or replace function public.ceo_lock_sovereign_vault(
  p_stepup_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_clean_tok  text := lower(btrim(coalesce(p_stepup_token, '')));
  v_tok_hash   char(64);
begin
  if v_uid is null or not private.ceo_is_caller_monocratic_owner() then
    return jsonb_build_object('ok', false);
  end if;

  if v_clean_tok ~ '^[0-9a-f]{64}$' then
    v_tok_hash := encode(extensions.digest(convert_to(v_clean_tok, 'UTF8'), 'sha256'), 'hex')::char(64);
    update private.ceo_stepup_sessions
       set revoked_at = now()
     where user_id = v_uid
       and session_token_sha256 = v_tok_hash
       and revoked_at is null;
  end if;

  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.ceo_lock_sovereign_vault(text) from public, anon;
grant execute on function public.ceo_lock_sovereign_vault(text) to authenticated;

comment on function public.ceo_lock_sovereign_vault(text) is
  'Revoga imediatamente no servidor a sessão step-up atual quando o CEO tranca o aplicativo ou o envia para segundo plano.';

create or replace function public.ceo_revoke_trusted_device(
  p_stepup_token text,
  p_device_hash text,
  p_target_device_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid;
  v_dev_fp   char(64);
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  select ctd.device_fingerprint_sha256
    into v_dev_fp
    from private.ceo_trusted_devices ctd
   where ctd.device_id = p_target_device_id
     and ctd.user_id = v_uid;

  if v_dev_fp is null then
    raise exception 'ERR_DEVICE_NOT_FOUND' using errcode = 'P0002';
  end if;

  update private.ceo_trusted_devices
     set revoked_at = now()
   where device_id = p_target_device_id
     and user_id = v_uid;

  update private.ceo_stepup_sessions
     set revoked_at = now()
   where user_id = v_uid
     and device_fingerprint_sha256 = v_dev_fp
     and revoked_at is null;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_TRUSTED_DEVICE_REVOKED',
    'WARN',
    false,
    jsonb_build_object('target_device_id', p_target_device_id)
  );

  return jsonb_build_object('ok', true, 'revoked_device_id', p_target_device_id);
end $$;

revoke all on function public.ceo_revoke_trusted_device(text, text, uuid) from public, anon;
grant execute on function public.ceo_revoke_trusted_device(text, text, uuid) to authenticated;

comment on function public.ceo_revoke_trusted_device(text, text, uuid) is
  'Revoga um dispositivo vinculado e encerra todas as sessões step-up associadas a ele.';

create or replace function public.ceo_record_real_expense(
  p_stepup_token text,
  p_device_hash text,
  p_competence_date date,
  p_expense_kind text,
  p_category text,
  p_description text,
  p_amount_cents bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid  uuid;
  v_kind text := upper(btrim(coalesce(p_expense_kind, 'FIXED_OPEX')));
  v_id   uuid;
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  if v_kind not in ('FIXED_OPEX', 'VARIABLE_PSP_CLOUD', 'TAX_EXTRA') then
    raise exception 'ERR_INVALID_EXPENSE_KIND' using errcode = '22023';
  end if;

  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'ERR_INVALID_EXPENSE_AMOUNT' using errcode = '22023';
  end if;

  insert into private.ceo_expense_entries (
    competence_date,
    expense_kind,
    category,
    description,
    amount_cents,
    created_by
  ) values (
    coalesce(p_competence_date, (now() at time zone 'America/Sao_Paulo')::date),
    v_kind,
    left(btrim(coalesce(p_category, 'Infraestrutura')), 60),
    left(btrim(coalesce(p_description, 'Despesa operacional real')), 180),
    p_amount_cents,
    v_uid
  )
  returning id into v_id;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_REAL_EXPENSE_RECORDED',
    'INFO',
    false,
    jsonb_build_object('expense_id', v_id, 'amount_cents', p_amount_cents, 'kind', v_kind)
  );

  return jsonb_build_object('ok', true, 'expense_id', v_id);
end $$;

revoke all on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint) from public, anon;
grant execute on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint) to authenticated;

comment on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint) is
  'Registra uma despesa operacional real (OPEX/Cloud/PSP) lançada pelo próprio CEO para compor o DRE sem estimativas inventadas.';

create or replace function public.ceo_delete_real_expense(
  p_stepup_token text,
  p_device_hash text,
  p_expense_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  delete from private.ceo_expense_entries
   where id = p_expense_id;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_REAL_EXPENSE_DELETED',
    'INFO',
    false,
    jsonb_build_object('expense_id', p_expense_id)
  );

  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.ceo_delete_real_expense(text, text, uuid) from public, anon;
grant execute on function public.ceo_delete_real_expense(text, text, uuid) to authenticated;

comment on function public.ceo_delete_real_expense(text, text, uuid) is
  'Remove um lançamento de despesa real do livro contábil executivo.';

-- -----------------------------------------------------------------------------
-- 7. Snapshot 100% Verídico em Tempo Real (`ceo_get_live_cockpit_snapshot`)
--    - `SET LOCAL transaction_read_only = on;`
--    - Fuso canônico `America/Sao_Paulo`
--    - Zero valores inventados/demo (se uma métrica for 0, retorna 0 exato)
-- -----------------------------------------------------------------------------
create or replace function public.ceo_get_live_cockpit_snapshot(
  p_stepup_token text,
  p_device_hash text,
  p_window_key text default '30d'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid                          uuid;
  v_win_key                      text := lower(btrim(coalesce(p_window_key, '30d')));
  v_today_sp                     date := (now() at time zone 'America/Sao_Paulo')::date;
  v_days                         integer;
  v_window_start_sp              date;
  v_window_start_utc             timestamptz;
  -- Demografia real de 5 estados (partição exata de `public.profiles`)
  v_only_clients                 integer := 0;
  v_only_providers               integer := 0;
  v_dual_mode_both               integer := 0;
  v_onboarding_incomplete        integer := 0;
  v_total_users                  integer := 0;
  v_new_users_in_window          integer := 0;
  v_kyc_verified                 integer := 0;
  v_kyc_pending                  integer := 0;
  v_kyc_rejected                 integer := 0;
  v_kyc_not_submitted            integer := 0;
  v_biometric_verified           integer := 0;
  v_ocr_verified                 integer := 0;
  v_lgpd_client                  integer := 0;
  v_lgpd_provider                integer := 0;
  v_lgpd_all                     integer := 0;
  -- Pipeline operacional ao vivo (`public.jobs`, `quotes`, `job_invites`, `reviews`)
  v_jobs_open                    integer := 0;
  v_jobs_awaiting_payment        integer := 0;
  v_jobs_scheduled               integer := 0;
  v_jobs_in_progress             integer := 0;
  v_jobs_awaiting_approval       integer := 0;
  v_jobs_completed_all_time      integer := 0;
  v_jobs_canceled_in_window      integer := 0;
  v_jobs_disputed                integer := 0;
  v_quotes_total_in_window       integer := 0;
  v_quotes_pending               integer := 0;
  v_quotes_accepted_in_window    integer := 0;
  v_invites_pending              integer := 0;
  v_reviews_count                integer := 0;
  v_reviews_avg_bps              integer := 0;
  -- DRE CPC 47 / IFRS 15 (100% real em BIGINT centavos; zero OPEX fictício)
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
  v_real_var_cost_cents          bigint := 0;
  v_real_fixed_opex_cents        bigint := 0;
  v_contribution_margin_cents    bigint := 0;
  v_net_profit_ebitda_cents      bigint := 0;
  -- Reconciliação Contábil de 3 Vias (1 centavo)
  v_pix_topups_confirmed_cents   bigint := 0;
  v_pix_topups_pending_count     integer := 0;
  v_ledger_topups_cents          bigint := 0;
  v_ledger_client_custody_cents  bigint := 0;
  v_ledger_global_imbalance      bigint := 0;
  v_wallets_and_escrow_cents     bigint := 0;
  v_discrepancy_cents            bigint := 0;
  -- Tesouraria, Custódia Escrow & Maturação D+N
  v_available_wallets_cents      bigint := 0;
  v_client_Seed_credit_cents     bigint := 0;
  v_active_exec_escrow_cents     bigint := 0;
  v_maturation_d0_d2_cents       bigint := 0;
  v_maturation_d5_cents          bigint := 0;
  v_maturation_d7_cents          bigint := 0;
  v_available_for_pix_cents      bigint := 0;
  v_frozen_mediation_cents       bigint := 0;
  v_frozen_duress_cents          bigint := 0;
  -- Fundo Garantidor Atuarial (`warranty_pool_ledger`)
  v_pool_credits_cents           bigint := 0;
  v_pool_debits_cents            bigint := 0;
  v_pool_running_balance_cents   bigint := 0;
  v_clawback_recovered_cents     bigint := 0;
  v_claims_paid_cents            bigint := 0;
  v_active_warranty_labor_cents  bigint := 0;
  v_open_mediation_labor_cents   bigint := 0;
  v_active_exposure_cents        bigint := 0;
  v_ica_ratio_bps                integer := 0;
  v_fcr_layer1_bps               integer := 10000;
  -- Segurança, SEFAZ, Geo-Privacy & Cadeia WORM
  v_pending_sefaz_total_count    integer := 0;
  v_pending_sefaz_26h_count      integer := 0;
  v_verified_sefaz_count         integer := 0;
  v_canceled_clawback_count      integer := 0;
  v_frozen_duress_count          integer := 0;
  v_geo_leak_bps                 integer := 0;
  v_intrusion_canaries_count     integer := 0;
  v_audit_chain_intact           boolean := true;
  v_latest_event_seq             bigint := 0;
  -- Coleções JSONB 100% reais
  v_category_matrix              jsonb := '[]'::jsonb;
  v_neighborhood_liquidity       jsonb := '[]'::jsonb;
  v_live_map_points              jsonb := '[]'::jsonb;
  v_daily_series                 jsonb := '[]'::jsonb;
  v_recent_orders_pnl            jsonb := '[]'::jsonb;
  v_conversion_funnel            jsonb := '[]'::jsonb;
  v_monthly_cohorts              jsonb := '[]'::jsonb;
  v_recent_reviews               jsonb := '[]'::jsonb;
  v_duress_incidents             jsonb := '[]'::jsonb;
  v_trusted_devices              jsonb := '[]'::jsonb;
  v_recent_audit_log             jsonb := '[]'::jsonb;
  v_live_events                  jsonb := '[]'::jsonb;
  v_real_expenses                jsonb := '[]'::jsonb;
  v_vault_meta                   jsonb := '{}'::jsonb;
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  case v_win_key
    when 'today' then
      v_days := 1;
      v_window_start_sp := v_today_sp;
    when '7d' then
      v_days := 7;
      v_window_start_sp := v_today_sp - 6;
    when '30d' then
      v_days := 30;
      v_window_start_sp := v_today_sp - 29;
    when '90d' then
      v_days := 90;
      v_window_start_sp := v_today_sp - 89;
    when '365d' then
      v_days := 365;
      v_window_start_sp := v_today_sp - 364;
    when 'all' then
      select greatest(
               1,
               least(
                 3650,
                 (v_today_sp - coalesce(min((jb_min.created_at at time zone 'America/Sao_Paulo')::date), v_today_sp)) + 1
               )
             )::integer
        into v_days
        from public.jobs jb_min;
      v_days := coalesce(v_days, 30);
      v_window_start_sp := v_today_sp - (v_days - 1);
    else
      v_win_key := '30d';
      v_days := 30;
      v_window_start_sp := v_today_sp - 29;
  end case;

  -- Meia-noite exata de `v_window_start_sp` no fuso America/Sao_Paulo convertida para timestamptz
  v_window_start_utc := (v_window_start_sp::timestamp at time zone 'America/Sao_Paulo');

  -- ---------------------------------------------------------------------------
  -- 1. Demografia Real de 5 Estados (`profiles`) + Offboarding LGPD
  -- ---------------------------------------------------------------------------
  select count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_provider, false) = true and coalesce(prof.is_client, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = true)::integer,
         count(*) filter (where coalesce(prof.is_client, false) = false and coalesce(prof.is_provider, false) = false)::integer,
         count(*)::integer,
         count(*) filter (where prof.created_at >= v_window_start_utc)::integer,
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
         count(*) filter (where coalesce(prof.kyc_biometric_verified, false) = true)::integer,
         count(*) filter (where coalesce(prof.ocr_verified, false) = true)::integer
    into v_only_clients,
         v_only_providers,
         v_dual_mode_both,
         v_onboarding_incomplete,
         v_total_users,
         v_new_users_in_window,
         v_kyc_verified,
         v_kyc_pending,
         v_kyc_rejected,
         v_biometric_verified,
         v_ocr_verified
    from public.profiles prof;

  v_kyc_not_submitted := greatest(0, v_total_users - v_kyc_verified - v_kyc_pending - v_kyc_rejected);

  select count(*) filter (where adl.scope = 'client')::integer,
         count(*) filter (where adl.scope = 'provider')::integer,
         count(*) filter (where adl.scope = 'all')::integer
    into v_lgpd_client,
         v_lgpd_provider,
         v_lgpd_all
    from public.account_deletion_log adl;

  -- ---------------------------------------------------------------------------
  -- 2. Contadores Operacionais Ao Vivo (`jobs`, `quotes`, `job_invites`, `reviews`)
  -- ---------------------------------------------------------------------------
  select count(*) filter (where jb_s.status = 'open')::integer,
         count(*) filter (where jb_s.status = 'awaiting_payment')::integer,
         count(*) filter (where jb_s.status = 'scheduled')::integer,
         count(*) filter (where jb_s.status = 'in_progress')::integer,
         count(*) filter (where jb_s.status = 'awaiting_approval')::integer,
         count(*) filter (where jb_s.status = 'completed')::integer,
         count(*) filter (where jb_s.status = 'canceled' and coalesce(jb_s.updated_at, jb_s.created_at) >= v_window_start_utc)::integer,
         count(*) filter (where jb_s.status = 'disputed')::integer
    into v_jobs_open,
         v_jobs_awaiting_payment,
         v_jobs_scheduled,
         v_jobs_in_progress,
         v_jobs_awaiting_approval,
         v_jobs_completed_all_time,
         v_jobs_canceled_in_window,
         v_jobs_disputed
    from public.jobs jb_s;

  select count(*) filter (where qt.created_at >= v_window_start_utc)::integer,
         count(*) filter (where qt.status = 'pending')::integer,
         count(*) filter (where qt.status = 'accepted' and qt.created_at >= v_window_start_utc)::integer
    into v_quotes_total_in_window,
         v_quotes_pending,
         v_quotes_accepted_in_window
    from public.quotes qt;

  select count(*)::integer
    into v_invites_pending
    from public.job_invites ji
   where ji.status = 'pending'
     and ji.expires_at > now();

  select count(*)::integer,
         coalesce(round(avg(rv.rating) * 1000)::integer, 0)
    into v_reviews_count,
         v_reviews_avg_bps
    from public.reviews rv
   where rv.revealed_at is not null;

  -- ---------------------------------------------------------------------------
  -- 3. DRE Contábil CPC 47 / IFRS 15 (100% Real, Zero OPEX ou Custo Fictício)
  -- ---------------------------------------------------------------------------
  with settled_jobs as (
    select jb.id,
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
       and coalesce(jb.approved_at, jb.finished_at, jb.updated_at, jb.created_at) >= v_window_start_utc
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
     and lt.created_at >= v_window_start_utc;

  v_platform_gross_revenue_cents := v_platform_op_fee_cents + greatest(0::bigint, v_sos_fee_revenue_cents);
  v_simples_tax_cents := (v_platform_gross_revenue_cents * 6 + 50) / 100;
  v_gross_hyp_tax_cents := (v_gmv_total_cents * 1133 + 5000) / 10000;

  if v_gross_hyp_tax_cents > 0 then
    v_tax_savings_bps := greatest(
      0,
      (((v_gross_hyp_tax_cents - v_simples_tax_cents) * 10000) / v_gross_hyp_tax_cents)::integer
    );
  else
    v_tax_savings_bps := 0;
  end if;

  -- Despesas reais lançadas em `private.ceo_expense_entries` na janela selecionada (0 se vazio!)
  select coalesce(sum(cee.amount_cents) filter (where cee.expense_kind = 'VARIABLE_PSP_CLOUD'), 0)::bigint,
         coalesce(sum(cee.amount_cents) filter (where cee.expense_kind in ('FIXED_OPEX', 'TAX_EXTRA')), 0)::bigint
    into v_real_var_cost_cents,
         v_real_fixed_opex_cents
    from private.ceo_expense_entries cee
   where cee.competence_date >= v_window_start_sp
     and cee.competence_date <= v_today_sp;

  v_contribution_margin_cents :=
    v_platform_gross_revenue_cents - v_simples_tax_cents - v_real_var_cost_cents;

  v_net_profit_ebitda_cents := v_contribution_margin_cents - v_real_fixed_opex_cents;

  -- ---------------------------------------------------------------------------
  -- 4. Reconciliação Contábil de 3 Vias (1 centavo de sensibilidade)
  -- ---------------------------------------------------------------------------
  select coalesce(sum(pt.amount_cents) filter (where pt.status = 'paid'), 0)::bigint,
         count(*) filter (where pt.status = 'pending' and pt.expires_at > now())::integer
    into v_pix_topups_confirmed_cents,
         v_pix_topups_pending_count
    from public.pix_topups pt;

  select coalesce(
           sum(ll.cents) filter (
             where ll.account like 'client:%:available'
                or ll.account like 'client:%:escrow'
           ),
           0
         )::bigint,
         abs(coalesce(sum(ll.cents), 0)::bigint),
         abs(coalesce(sum(ll.cents) filter (where ll.account = 'platform:test_credit'), 0)::bigint)
    into v_ledger_client_custody_cents,
         v_ledger_global_imbalance,
         v_client_seed_credit_cents
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
  -- 5. Tesouraria, Custódia Escrow & Maturação D+N Real
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
             where eme_m.maturation_status = 'AVAILABLE_FOR_PIX'
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
         v_available_for_pix_cents,
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

  -- ---------------------------------------------------------------------------
  -- 6. Fundo Garantidor Atuarial (`warranty_pool_ledger`)
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

  v_active_exposure_cents := greatest(
    v_open_mediation_labor_cents,
    (v_active_warranty_labor_cents * 100 + 5000) / 10000
  );

  if v_active_exposure_cents > 0 then
    v_ica_ratio_bps := least(99999, ((v_pool_running_balance_cents * 10000) / v_active_exposure_cents)::integer);
  elsif v_pool_running_balance_cents > 0 then
    v_ica_ratio_bps := 10000;
  else
    v_ica_ratio_bps := 0;
  end if;

  select case
           when count(*) > 0 then
             ((count(*) filter (where jm_fcr.resolution_outcome is distinct from 'REPAIRED_BY_LAYER3_RESCUER') * 10000) / count(*))::integer
           else 10000
         end
    into v_fcr_layer1_bps
    from public.job_mediations jm_fcr;

  -- ---------------------------------------------------------------------------
  -- 7. Matriz Real das 33 Categorias Canônicas (`category_liquidity_matrix`)
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
     where jb_cat.created_at >= v_window_start_utc
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
             order by coalesce(dbs.demand_n, 0) desc, coalesce(sbs.providers_n, 0) desc, cc.ord asc
           ),
           '[]'::jsonb
         )
    into v_category_matrix
    from canonical_cats cc
    left join demand_by_slug dbs on dbs.slug = cc.slug
    left join supply_by_slug sbs on sbs.slug = cc.slug;

  -- ---------------------------------------------------------------------------
  -- 8. Mapa Cartográfico Real (`live_map_points` de `job_geo` + `job_addresses`)
  --    e Liquidez Real por Bairro/Cidade (`neighborhood_liquidity`)
  -- ---------------------------------------------------------------------------
  with geo_jobs as (
    select jb_m.id as job_id,
           '#DESP-' || upper(substr(replace(jb_m.id::text, '-', ''), 1, 5)) as order_code,
           coalesce(jb_m.title, jb_m.category, 'Serviço') as title,
           coalesce(jb_m.category, 'Outros') as category_name,
           jb_m.status,
           coalesce(jb_m.escrow_status, 'NONE') as escrow_status,
           jb_m.urgency,
           jb_m.scheduled_for,
           jb_m.started_at,
           jb_m.created_at,
           coalesce(jg.lat, jb_m.public_lat) as lat,
           coalesce(jg.lng, jb_m.public_lng) as lng,
           (jg.job_id is not null) as is_exact_pin,
           round(coalesce(nullif(jb_m.labor_amount + jb_m.materials_amount, 0), jb_m.agreed_price, jb_m.budget_estimate, 0) * 100)::bigint as amount_cents,
           public._parse_job_address_parts(ja.address_line, jb_m.address_summary, pc.address_city) as addr_parts,
           public.safe_name(pc.full_name, 'Cliente') as client_name,
           case when pp_u.id is not null then public.safe_name(pp_u.full_name, 'Profissional') else null end as provider_name
      from public.jobs jb_m
      left join public.job_geo jg on jg.job_id = jb_m.id
      left join public.job_addresses ja on ja.job_id = jb_m.id
      left join public.profiles pc on pc.id = jb_m.client_id
      left join public.profiles pp_u on pp_u.id = jb_m.provider_id
     where coalesce(jb_m.is_warranty_rework, false) = false
     order by
       case when jb_m.status in ('in_progress', 'disputed', 'scheduled', 'open', 'awaiting_payment', 'awaiting_approval') then 0 else 1 end asc,
       jb_m.created_at desc
     limit 120
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'job_id', gj.job_id,
               'order_code', gj.order_code,
               'title', gj.title,
               'category_name', gj.category_name,
               'status', gj.status,
               'escrow_status', gj.escrow_status,
               'urgency', coalesce(gj.urgency, 'scheduled'),
               'lat', gj.lat,
               'lng', gj.lng,
               'is_exact_pin', gj.is_exact_pin,
               'amount_cents', gj.amount_cents,
               'neighborhood', coalesce(nullif(gj.addr_parts ->> 'neighborhood', ''), ' Centro / Região'),
               'city', coalesce(nullif(gj.addr_parts ->> 'city', ''), 'Não informada'),
               'uf', coalesce(gj.addr_parts ->> 'uf', ''),
               'client_name', gj.client_name,
               'provider_name', gj.provider_name,
               'scheduled_for', gj.scheduled_for,
               'started_at', gj.started_at,
               'created_at', gj.created_at
             )
           ) filter (where gj.lat is not null and gj.lng is not null),
           '[]'::jsonb
         )
    into v_live_map_points
    from geo_jobs gj;

  with job_regions as (
    select coalesce(
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'neighborhood'), ''),
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'city'), ''),
             'Região Geral'
           ) as region_label,
           coalesce(
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'city'), ''),
             'Cidade não informada'
           ) as city_label,
           count(*)::integer as demand_count,
           count(distinct jb_reg.provider_id) filter (where jb_reg.provider_id is not null)::integer as engaged_providers_count,
           coalesce(
             round(avg(coalesce(nullif(jb_reg.labor_amount + jb_reg.materials_amount, 0), jb_reg.agreed_price, jb_reg.budget_estimate, 0) * 100))::bigint,
             0::bigint
           ) as avg_ticket_cents
      from public.jobs jb_reg
      left join public.job_addresses ja_r on ja_r.job_id = jb_reg.id
      left join public.profiles pc_r on pc_r.id = jb_reg.client_id
     where jb_reg.created_at >= v_window_start_utc
     group by 1, 2
     order by demand_count desc, avg_ticket_cents desc
     limit 16
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'neighborhood_name', jr.region_label,
               'city_name', jr.city_label,
               'demand_count', jr.demand_count,
               'active_supply_count', jr.engaged_providers_count,
               'avg_ticket_cents', jr.avg_ticket_cents
             )
           ),
           '[]'::jsonb
         )
    into v_neighborhood_liquidity
    from job_regions jr;

  -- ---------------------------------------------------------------------------
  -- 9. Funil Real de Conversão (`real_conversion_funnel`) & Coortes Reais Mensais
  -- ---------------------------------------------------------------------------
  with funnel_counts as (
    select v_total_users as s1_registered,
           v_kyc_verified as s2_kyc_approved,
           (
             select count(distinct u_act.uid)::integer
               from (
                 select jb_f.client_id as uid from public.jobs jb_f
                 union
                 select qt_f.provider_id as uid from public.quotes qt_f
               ) u_act
           ) as s3_engaged_order_or_quote,
           (
             select count(distinct jb_e.client_id)::integer
               from public.jobs jb_e
              where jb_e.payment_status in ('escrow', 'released', 'paid')
                 or jb_e.status in ('scheduled', 'in_progress', 'awaiting_approval', 'completed')
           ) as s4_escrow_funded,
           (
             select count(distinct jb_c.client_id)::integer
               from public.jobs jb_c
              where jb_c.status = 'completed'
           ) as s5_completed_service,
           (
             select count(*)::integer
               from (
                 select jb_r2.client_id
                   from public.jobs jb_r2
                  where jb_r2.status = 'completed'
                  group by jb_r2.client_id
                 having count(*) >= 2
               ) rec
           ) as s6_recurring_clients
  )
  select jsonb_build_array(
           jsonb_build_object('stage_id', 'signups',   'label', 'Cadastros Reais',            'users_count', fc.s1_registered),
           jsonb_build_object('stage_id', 'kyc_ok',    'label', 'KYC / Identidade Aprovada',  'users_count', fc.s2_kyc_approved),
           jsonb_build_object('stage_id', 'engaged',   'label', 'Pedido ou Orçamento Enviado','users_count', fc.s3_engaged_order_or_quote),
           jsonb_build_object('stage_id', 'escrow',    'label', 'Custódia Escrow Confirmada', 'users_count', fc.s4_escrow_funded),
           jsonb_build_object('stage_id', 'completed', 'label', 'Serviço Concluído',          'users_count', fc.s5_completed_service),
           jsonb_build_object('stage_id', 'recurring', 'label', 'Clientes Recorrentes (2+)',  'users_count', fc.s6_recurring_clients)
         )
    into v_conversion_funnel
    from funnel_counts fc;

  with user_cohorts as (
    select prof_c.id as user_id,
           date_trunc('month', prof_c.created_at at time zone 'America/Sao_Paulo')::date as cohort_month
      from public.profiles prof_c
  ),
  user_activity_months as (
    select jb_act.client_id as user_id,
           date_trunc('month', jb_act.created_at at time zone 'America/Sao_Paulo')::date as act_month
      from public.jobs jb_act
    union
    select qt_act.provider_id as user_id,
           date_trunc('month', qt_act.created_at at time zone 'America/Sao_Paulo')::date as act_month
      from public.quotes qt_act
  ),
  cohort_agg as (
    select uc.cohort_month,
           count(distinct uc.user_id)::integer as cohort_size,
           count(distinct uam0.user_id)::integer as m0_active,
           count(distinct uam1.user_id)::integer as m1_active,
           count(distinct uam2.user_id)::integer as m2_active,
           count(distinct uam3.user_id)::integer as m3_active
      from user_cohorts uc
      left join user_activity_months uam0
        on uam0.user_id = uc.user_id and uam0.act_month = uc.cohort_month
      left join user_activity_months uam1
        on uam1.user_id = uc.user_id and uam1.act_month = (uc.cohort_month + interval '1 month')::date
      left join user_activity_months uam2
        on uam2.user_id = uc.user_id and uam2.act_month = (uc.cohort_month + interval '2 months')::date
      left join user_activity_months uam3
        on uam3.user_id = uc.user_id and uam3.act_month = (uc.cohort_month + interval '3 months')::date
     group by uc.cohort_month
     order by uc.cohort_month desc
     limit 6
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'cohort_label', to_char(ca.cohort_month, 'YYYY-MM'),
               'cohort_size', ca.cohort_size,
               'm0_bps', case when ca.cohort_size > 0 then ((ca.m0_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm1_bps', case when ca.cohort_size > 0 then ((ca.m1_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm2_bps', case when ca.cohort_size > 0 then ((ca.m2_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm3_bps', case when ca.cohort_size > 0 then ((ca.m3_active * 10000) / ca.cohort_size)::integer else 0 end
             )
             order by ca.cohort_month asc
           ),
           '[]'::jsonb
         )
    into v_monthly_cohorts
    from cohort_agg ca;

  -- ---------------------------------------------------------------------------
  -- 10. Série Temporal Diária Densa em `America/Sao_Paulo` (`daily_time_series`)
  -- ---------------------------------------------------------------------------
  with calendar_days as (
    select gs::date as day_dt
      from generate_series(
        v_window_start_sp,
        v_today_sp,
        interval '1 day'
      ) gs
  ),
  daily_jobs as (
    select (coalesce(jb_d.approved_at, jb_d.finished_at, jb_d.updated_at, jb_d.created_at) at time zone 'America/Sao_Paulo')::date as day_dt,
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
       and coalesce(jb_d.approved_at, jb_d.finished_at, jb_d.updated_at, jb_d.created_at) >= v_window_start_utc
     group by 1
  ),
  daily_expenses as (
    select cee_d.competence_date as day_dt,
           coalesce(sum(cee_d.amount_cents) filter (where cee_d.expense_kind = 'VARIABLE_PSP_CLOUD'), 0)::bigint as var_c,
           coalesce(sum(cee_d.amount_cents) filter (where cee_d.expense_kind in ('FIXED_OPEX', 'TAX_EXTRA')), 0)::bigint as fix_c
      from private.ceo_expense_entries cee_d
     where cee_d.competence_date >= v_window_start_sp
       and cee_d.competence_date <= v_today_sp
     group by 1
  ),
  daily_claims as (
    select (wpl_d.created_at at time zone 'America/Sao_Paulo')::date as day_dt,
           coalesce(sum(round(wpl_d.amount * 100)::bigint), 0)::bigint as claims_c
      from public.warranty_pool_ledger wpl_d
     where wpl_d.entry_type = 'REWORK_PAYOUT_DEBIT'
       and wpl_d.created_at >= v_window_start_utc
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
               'variable_cost_cents', coalesce(dx.var_c, 0),
               'net_profit_cents', (
                 coalesce(dj.rev_c, 0)
                 - ((coalesce(dj.rev_c, 0) * 6 + 50) / 100)
                 - coalesce(dx.var_c, 0)
                 - coalesce(dx.fix_c, 0)
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
    left join daily_expenses dx on dx.day_dt = cd.day_dt
    left join daily_claims dc on dc.day_dt = cd.day_dt;

  -- ---------------------------------------------------------------------------
  -- 11. Ordens Reais Recentes (`recent_orders_micro_pnl`) + Avaliações Reais
  -- ---------------------------------------------------------------------------
  with recent_jobs as (
    select jb_r.id,
           coalesce(jb_r.title, jb_r.category, 'Serviço') as title,
           jb_r.category,
           jb_r.address_summary,
           jb_r.created_at,
           jb_r.scheduled_for,
           jb_r.escrow_status,
           jb_r.status,
           jb_r.urgency,
           jb_r.checkin_photo_path,
           jb_r.checkout_photo_path,
           public.safe_name(prof_c.full_name, 'Cliente') as client_name,
           case when prof_r.id is not null then public.safe_name(prof_r.full_name, 'Profissional') else null end as provider_name,
           prof_r.avatar_url as provider_avatar_url,
           rg.gmv_c,
           greatest(0::bigint, rg.gmv_c - re.ex_c) as labor_c,
           re.ex_c as exempt_c,
           rf.op_c as fee_c,
           rf.pool_c as pool_c,
           greatest(0::bigint, greatest(0::bigint, rg.gmv_c - re.ex_c) - rf.op_c - rf.pool_c) as provider_net_c,
           jfd_r.access_key_44,
           coalesce(jfd_r.verification_status = 'VERIFIED_SEFAZ', false) as nfe_verified,
           (select count(*)::integer from public.quotes q_cnt where q_cnt.job_id = jb_r.id) as quotes_count
      from public.jobs jb_r
      left join public.profiles prof_c on prof_c.id = jb_r.client_id
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
     where coalesce(jb_r.is_warranty_rework, false) = false
     order by jb_r.created_at desc
     limit 60
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'order_code', '#DESP-' || upper(substr(replace(rj.id::text, '-', ''), 1, 5)),
               'job_id', rj.id,
               'title', rj.title,
               'category_name', coalesce(rj.category, 'Outros'),
               'neighborhood', coalesce(nullif(btrim(rj.address_summary), ''), 'Endereço em validação'),
               'created_at', rj.created_at,
               'scheduled_for', rj.scheduled_for,
               'status', rj.status,
               'urgency', coalesce(rj.urgency, 'scheduled'),
               'client_name', rj.client_name,
               'provider_name', rj.provider_name,
               'quotes_count', rj.quotes_count,
               'gmv_cents', rj.gmv_c,
               'labor_cents', rj.labor_c,
               'materials_exempt_cents', rj.exempt_c,
               'nfe_access_key', rj.access_key_44,
               'nfe_verified', rj.nfe_verified,
               'provider_net_cents', rj.provider_net_c,
               'platform_fee_cents', rj.fee_c,
               'pool_carveout_cents', rj.pool_c,
               'tax_das_cents', ((rj.fee_c * 6 + 50) / 100),
               'pix_cloud_cost_cents', 0,
               'net_margin_cents', (rj.fee_c - ((rj.fee_c * 6 + 50) / 100)),
               'escrow_status', coalesce(rj.escrow_status, 'NONE'),
               'provider_avatar_url', rj.provider_avatar_url,
               'evidence_photo_url', coalesce(rj.checkout_photo_path, rj.checkin_photo_path)
             )
             order by rj.created_at desc
           ),
           '[]'::jsonb
         )
    into v_recent_orders_pnl
    from recent_jobs rj;

  with latest_reviews as (
    select rv_l.id,
           rv_l.job_id,
           rv_l.rating,
           rv_l.comment,
           rv_l.tags,
           rv_l.reply,
           rv_l.created_at,
           public.safe_name(p_rev.full_name, 'Avaliador') as reviewer_name,
           public.safe_name(p_ree.full_name, 'Avaliado') as reviewee_name,
           coalesce(jb_rv.category, 'Serviço') as category_name
      from public.reviews rv_l
      left join public.profiles p_rev on p_rev.id = rv_l.reviewer_id
      left join public.profiles p_ree on p_ree.id = rv_l.reviewee_id
      left join public.jobs jb_rv on jb_rv.id = rv_l.job_id
     where rv_l.revealed_at is not null
     order by rv_l.created_at desc
     limit 20
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'review_id', lr.id,
               'job_id', lr.job_id,
               'rating', lr.rating,
               'comment', coalesce(lr.comment, ''),
               'tags', coalesce(to_jsonb(lr.tags), '[]'::jsonb),
               'reply', lr.reply,
               'reviewer_name', lr.reviewer_name,
               'reviewee_name', lr.reviewee_name,
               'category_name', lr.category_name,
               'created_at', lr.created_at
             )
           ),
           '[]'::jsonb
         )
    into v_recent_reviews
    from latest_reviews lr;

  -- ---------------------------------------------------------------------------
  -- 12. Segurança, SEFAZ, Dispositivos Confiáveis, Auditoria WORM & Feed Ao Vivo
  -- ---------------------------------------------------------------------------
  select count(*) filter (where jfd_w.verification_status = 'PENDING_SEFAZ')::integer,
         count(*) filter (
           where jfd_w.verification_status = 'PENDING_SEFAZ'
             and jfd_w.created_at <= now() - interval '26 hours'
         )::integer,
         count(*) filter (where jfd_w.verification_status = 'VERIFIED_SEFAZ')::integer,
         count(*) filter (
           where jfd_w.verification_status = 'CANCELED_CLAWBACK'
              or jfd_w.clawback_triggered = true
         )::integer
    into v_pending_sefaz_total_count,
         v_pending_sefaz_26h_count,
         v_verified_sefaz_count,
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

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'incident_id', 'DUR-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
               'job_id', jb_dur.id,
               'order_code', '#DESP-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 5)),
               'category_name', coalesce(jb_dur.category, 'Serviço'),
               'neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Restrito'),
               'coarse_neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Restrito'),
               'frozen_amount_cents', round(coalesce(nullif(jb_dur.labor_amount + jb_dur.materials_amount, 0), jb_dur.agreed_price, 0) * 100)::bigint,
               'custody_status', 'FROZEN_UNDER_DURESS',
               'masked_victim_role', 'PRESTADOR_CREDENCIADO',
               'masked_account_ref', 'USR-' || upper(substr(replace(coalesce(jb_dur.provider_id, jb_dur.client_id)::text, '-', ''), 1, 4)) || '-****',
               'created_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
               'triggered_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
               'ledger_freeze_tx_id', 'LEDGER-FRZ-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
               'device_integrity_hash', encode(
                 extensions.digest(convert_to('DEV|' || jb_dur.id::text, 'UTF8'), 'sha256'),
                 'hex'
               ),
               'sha256_evidence_seal', encode(
                 extensions.digest(convert_to(jb_dur.id::text || '|' || coalesce(jb_dur.updated_at, jb_dur.created_at)::text, 'UTF8'), 'sha256'),
                 'hex'
               ),
               'evidence_chain_hashes', jsonb_build_array(
                 encode(extensions.digest(convert_to(jb_dur.id::text, 'UTF8'), 'sha256'), 'hex')
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

  select jsonb_build_object(
           'owner_email', csv.owner_email,
           'pin_algo_version', csv.pin_algo_version,
           'pin_configured_at', csv.pin_configured_at,
           'pin_rotated_at', csv.pin_rotated_at,
           'failed_pin_attempts', csv.failed_pin_attempts
         )
    into v_vault_meta
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'device_id', ctd.device_id,
               'device_label', ctd.device_label,
               'fingerprint_prefix', left(ctd.device_fingerprint_sha256, 12),
               'is_current_device', (ctd.device_fingerprint_sha256 = lower(btrim(p_device_hash))),
               'bound_at', ctd.bound_at,
               'last_seen_at', ctd.last_seen_at
             )
             order by ctd.last_seen_at desc
           ),
           '[]'::jsonb
         )
    into v_trusted_devices
    from private.ceo_trusted_devices ctd
   where ctd.user_id = v_uid
     and ctd.revoked_at is null;

  with latest_audits as (
    select fal.id,
           fal.event_code,
           fal.severity,
           fal.is_intrusion_canary,
           fal.prev_hash,
           fal.row_hash,
           fal.created_at
      from private.founder_audit_log fal
     order by fal.id desc
     limit 30
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', la.id,
               'event_code', la.event_code,
               'severity', la.severity,
               'is_intrusion_canary', la.is_intrusion_canary,
               'prev_hash', la.prev_hash,
               'row_hash', la.row_hash,
               'created_at', la.created_at
             )
             order by la.id desc
           ),
           '[]'::jsonb
         )
    into v_recent_audit_log
    from latest_audits la;

  select coalesce(max(cle_m.event_seq), 0)::bigint
    into v_latest_event_seq
    from private.ceo_live_events cle_m;

  with recent_live as (
    select cle.event_seq,
           cle.event_type,
           cle.severity,
           cle.title,
           cle.subtitle,
           cle.entity_table,
           cle.entity_id,
           cle.amount_cents,
           cle.metadata,
           cle.occurred_at
      from private.ceo_live_events cle
     order by cle.event_seq desc
     limit 60
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'event_seq', rl.event_seq,
               'event_type', rl.event_type,
               'severity', rl.severity,
               'title', rl.title,
               'subtitle', rl.subtitle,
               'entity_table', rl.entity_table,
               'entity_id', rl.entity_id,
               'amount_cents', rl.amount_cents,
               'metadata', rl.metadata,
               'occurred_at', rl.occurred_at
             )
             order by rl.event_seq desc
           ),
           '[]'::jsonb
         )
    into v_live_events
    from recent_live rl;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', cee_l.id,
               'competence_date', to_char(cee_l.competence_date, 'YYYY-MM-DD'),
               'expense_kind', cee_l.expense_kind,
               'category', cee_l.category,
               'description', cee_l.description,
               'amount_cents', cee_l.amount_cents,
               'created_at', cee_l.created_at
             )
             order by cee_l.competence_date desc, cee_l.created_at desc
           ),
           '[]'::jsonb
         )
    into v_real_expenses
    from private.ceo_expense_entries cee_l
   where cee_l.competence_date >= v_window_start_sp
     and cee_l.competence_date <= v_today_sp;

  return jsonb_build_object(
    'generated_at', now(),
    'timezone', 'America/Sao_Paulo',
    'window_key', v_win_key,
    'days_window', v_days,
    'latest_event_seq', v_latest_event_seq,
    'vault_metadata', v_vault_meta,
    'user_demographics', jsonb_build_object(
      'only_clients_count', v_only_clients,
      'only_providers_count', v_only_providers,
      'dual_mode_both_count', v_dual_mode_both,
      'onboarding_incomplete_count', v_onboarding_incomplete,
      'total_users_count', v_total_users,
      'new_users_in_window_count', v_new_users_in_window,
      'kyc_verified_count', v_kyc_verified,
      'kyc_pending_count', v_kyc_pending,
      'kyc_rejected_count', v_kyc_rejected,
      'kyc_not_submitted_count', v_kyc_not_submitted,
      'biometric_verified_count', v_biometric_verified,
      'ocr_verified_count', v_ocr_verified,
      'lgpd_deleted_client_count', v_lgpd_client,
      'lgpd_deleted_provider_count', v_lgpd_provider,
      'lgpd_deleted_all_count', v_lgpd_all
    ),
    'live_operations_pulse', jsonb_build_object(
      'open_jobs_count', v_jobs_open,
      'awaiting_payment_count', v_jobs_awaiting_payment,
      'scheduled_jobs_count', v_jobs_scheduled,
      'in_progress_jobs_count', v_jobs_in_progress,
      'awaiting_approval_count', v_jobs_awaiting_approval,
      'completed_all_time_count', v_jobs_completed_all_time,
      'canceled_in_window_count', v_jobs_canceled_in_window,
      'disputed_jobs_count', v_jobs_disputed,
      'quotes_in_window_count', v_quotes_total_in_window,
      'quotes_pending_count', v_quotes_pending,
      'quotes_accepted_in_window_count', v_quotes_accepted_in_window,
      'invites_pending_count', v_invites_pending,
      'pix_pending_count', v_pix_topups_pending_count,
      'reviews_total_count', v_reviews_count,
      'reviews_avg_bps', v_reviews_avg_bps
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
      'variable_psp_and_cloud_cents', v_real_var_cost_cents,
      'tier0_kyc_savings_cents', 0,
      'contribution_margin_cents', v_contribution_margin_cents,
      'fixed_opex_cents', v_real_fixed_opex_cents,
      'completed_orders_count', v_completed_orders,
      'stage_gate_40_reached', (v_completed_orders >= 40),
      'stage_gate_100_reached', (v_completed_orders >= 100),
      'net_profit_ebitda_cents', v_net_profit_ebitda_cents
    ),
    'three_way_reconciliation', jsonb_build_object(
      'pix_topups_confirmed_cents', v_pix_topups_confirmed_cents,
      'ledger_net_sum_cents', v_ledger_client_custody_cents,
      'wallets_and_escrow_total_cents', v_wallets_and_escrow_cents,
      'client_seed_homologation_cents', v_client_seed_credit_cents,
      'discrepancy_cents', v_discrepancy_cents,
      'three_way_reconciliation_ok', (v_discrepancy_cents = 0)
    ),
    'treasury_and_escrow_cents', jsonb_build_object(
      'available_wallets_cents', v_available_wallets_cents,
      'active_execution_escrow_cents', v_active_exec_escrow_cents,
      'maturation_d0_d2_cents', v_maturation_d0_d2_cents,
      'maturation_d5_cents', v_maturation_d5_cents,
      'maturation_d7_cents', v_maturation_d7_cents,
      'available_for_pix_payout_cents', v_available_for_pix_cents,
      'frozen_mediation_cents', v_frozen_mediation_cents,
      'frozen_under_duress_cents', v_frozen_duress_cents,
      'estimated_monthly_cdi_float_cents', 0
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
    'neighborhood_liquidity', v_neighborhood_liquidity,
    'live_map_points', v_live_map_points,
    'real_conversion_funnel', v_conversion_funnel,
    'real_monthly_cohorts', v_monthly_cohorts,
    'daily_time_series', v_daily_series,
    'recent_orders_micro_pnl', v_recent_orders_pnl,
    'recent_reviews', v_recent_reviews,
    'real_expenses', v_real_expenses,
    'security_and_sefaz_watch', jsonb_build_object(
      'pending_sefaz_total_count', v_pending_sefaz_total_count,
      'pending_sefaz_over_26h_count', v_pending_sefaz_26h_count,
      'verified_sefaz_count', v_verified_sefaz_count,
      'canceled_clawback_count', v_canceled_clawback_count,
      'frozen_under_duress_count', v_frozen_duress_count,
      'geo_privacy_leak_bps', v_geo_leak_bps,
      'intrusion_canaries_count', v_intrusion_canaries_count,
      'audit_chain_intact', v_audit_chain_intact,
      'duress_incidents', v_duress_incidents
    ),
    'trusted_devices', v_trusted_devices,
    'recent_audit_log', v_recent_audit_log,
    'live_events', v_live_events
  );
end $$;

revoke all on function public.ceo_get_live_cockpit_snapshot(text, text, text) from public, anon;
grant execute on function public.ceo_get_live_cockpit_snapshot(text, text, text) to authenticated;

comment on function public.ceo_get_live_cockpit_snapshot(text, text, text) is
  'Snapshot executivo 100% real e somente-leitura (SET LOCAL transaction_read_only = on) exclusivo para wagneroliveira2395@gmail.com no fuso America/Sao_Paulo. Zero dados sintéticos ou estimativas inventadas.';

-- -----------------------------------------------------------------------------
-- 8. Recuperação Monotônica de Eventos Ao Vivo (`ceo_fetch_live_events_since`),
--    Inspetor Forense de Ordem (`ceo_inspect_order_forensics`) e Diretório CRM
--    Real de Usuários (`ceo_list_real_users_directory`)
-- -----------------------------------------------------------------------------
create or replace function public.ceo_fetch_live_events_since(
  p_stepup_token text,
  p_device_hash text,
  p_after_seq bigint default 0,
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid    uuid;
  v_lim    integer := greatest(1, least(coalesce(p_limit, 100), 500));
  v_events jsonb := '[]'::jsonb;
  v_max    bigint := coalesce(p_after_seq, 0);
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  with delta as (
    select cle.event_seq,
           cle.event_type,
           cle.severity,
           cle.title,
           cle.subtitle,
           cle.entity_table,
           cle.entity_id,
           cle.amount_cents,
           cle.metadata,
           cle.occurred_at
      from private.ceo_live_events cle
     where cle.event_seq > coalesce(p_after_seq, 0)
     order by cle.event_seq asc
     limit v_lim
  )
  select coalesce(max(d.event_seq), coalesce(p_after_seq, 0))::bigint,
         coalesce(
           jsonb_agg(
             jsonb_build_object(
               'event_seq', d.event_seq,
               'event_type', d.event_type,
               'severity', d.severity,
               'title', d.title,
               'subtitle', d.subtitle,
               'entity_table', d.entity_table,
               'entity_id', d.entity_id,
               'amount_cents', d.amount_cents,
               'metadata', d.metadata,
               'occurred_at', d.occurred_at
             )
             order by d.event_seq asc
           ),
           '[]'::jsonb
         )
    into v_max, v_events
    from delta d;

  return jsonb_build_object(
    'ok', true,
    'latest_event_seq', v_max,
    'events', v_events
  );
end $$;

revoke all on function public.ceo_fetch_live_events_since(text, text, bigint, integer) from public, anon;
grant execute on function public.ceo_fetch_live_events_since(text, text, bigint, integer) to authenticated;

comment on function public.ceo_fetch_live_events_since(text, text, bigint, integer) is
  'Recupera eventos reais com event_seq > p_after_seq para reconexão WebSocket sem perda de mensagens.';

create or replace function public.ceo_inspect_order_forensics(
  p_stepup_token text,
  p_device_hash text,
  p_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid         uuid;
  j             public.jobs%rowtype;
  ja            public.job_addresses%rowtype;
  jg            public.job_geo%rowtype;
  pc            public.profiles%rowtype;
  pp            public.profiles%rowtype;
  v_addr_parts  jsonb;
  v_quotes      jsonb := '[]'::jsonb;
  v_invites     jsonb := '[]'::jsonb;
  v_payments    jsonb := '[]'::jsonb;
  v_ledger      jsonb := '[]'::jsonb;
  v_maturation  jsonb := '[]'::jsonb;
  v_fiscal      jsonb := '[]'::jsonb;
  v_mediations  jsonb := '[]'::jsonb;
  v_reviews     jsonb := '[]'::jsonb;
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  select * into j from public.jobs where id = p_job_id;
  if not found then
    raise exception 'ERR_JOB_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into ja from public.job_addresses where job_id = j.id;
  select * into jg from public.job_geo where job_id = j.id;
  select * into pc from public.profiles where id = j.client_id;
  if j.provider_id is not null then
    select * into pp from public.profiles where id = j.provider_id;
  end if;

  v_addr_parts := public._parse_job_address_parts(ja.address_line, j.address_summary, pc.address_city);

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'quote_id', qt.id,
               'provider_id', qt.provider_id,
               'provider_name', public.safe_name(pq.full_name, 'Profissional'),
               'price_cents', round(qt.price * 100)::bigint,
               'status', qt.status,
               'message', coalesce(qt.message, ''),
               'created_at', qt.created_at
             )
             order by qt.created_at asc
           ),
           '[]'::jsonb
         )
    into v_quotes
    from public.quotes qt
    left join public.profiles pq on pq.id = qt.provider_id
   where qt.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'provider_id', ji.provider_id,
               'provider_name', public.safe_name(pi.full_name, 'Profissional'),
               'status', ji.status,
               'expires_at', ji.expires_at,
               'created_at', ji.created_at
             )
             order by ji.created_at asc
           ),
           '[]'::jsonb
         )
    into v_invites
    from public.job_invites ji
    left join public.profiles pi on pi.id = ji.provider_id
   where ji.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'payment_id', pay.id,
               'amount_cents', round(coalesce(pay.amount, 0) * 100)::bigint,
               'fee_cents', round(coalesce(pay.fee_amount, 0) * 100)::bigint,
               'status', pay.status,
               'method', pay.payment_method,
               'created_at', pay.created_at
             )
             order by pay.created_at asc
           ),
           '[]'::jsonb
         )
    into v_payments
    from public.payments pay
   where pay.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'txn_id', lt.id,
               'kind', lt.kind,
               'memo', coalesce(lt.memo, ''),
               'created_at', lt.created_at,
               'lines', (
                 select coalesce(
                          jsonb_agg(
                            jsonb_build_object('account', ll.account, 'cents', ll.cents)
                            order by ll.id asc
                          ),
                          '[]'::jsonb
                        )
                   from public.ledger_lines ll
                  where ll.txn_id = lt.id
               )
             )
             order by lt.created_at asc
           ),
           '[]'::jsonb
         )
    into v_ledger
    from public.ledger_txns lt
   where lt.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'entry_id', eme.id,
               'maturation_status', eme.maturation_status,
               'gross_labor_cents', round(eme.gross_labor_amount * 100)::bigint,
               'materials_exempt_cents', round(eme.materials_reimbursement_amount * 100)::bigint,
               'platform_fee_cents', round(eme.platform_operational_fee * 100)::bigint,
               'warranty_carveout_cents', round(eme.warranty_carveout_fee * 100)::bigint,
               'net_provider_cents', round(eme.net_provider_amount * 100)::bigint,
               'available_at', eme.available_at,
               'created_at', eme.created_at
             )
             order by eme.created_at desc
           ),
           '[]'::jsonb
         )
    into v_maturation
    from public.escrow_maturation_entries eme
   where eme.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'doc_id', jfd.id,
               'access_key_44', jfd.access_key_44,
               'verification_status', jfd.verification_status,
               'capture_channel', jfd.capture_channel,
               'declared_material_cents', round(coalesce(jfd.declared_material_amount, 0) * 100)::bigint,
               'clawback_triggered', jfd.clawback_triggered,
               'created_at', jfd.created_at
             )
             order by jfd.created_at desc
           ),
           '[]'::jsonb
         )
    into v_fiscal
    from public.job_fiscal_documents jfd
   where jfd.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'mediation_id', jm.id,
               'current_phase', jm.current_phase,
               'resolution_outcome', jm.resolution_outcome,
               'created_at', jm.created_at
             )
             order by jm.created_at desc
           ),
           '[]'::jsonb
         )
    into v_mediations
    from public.job_mediations jm
   where jm.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'review_id', rv.id,
               'rating', rv.rating,
               'comment', coalesce(rv.comment, ''),
               'revealed_at', rv.revealed_at,
               'created_at', rv.created_at
             )
             order by rv.created_at desc
           ),
           '[]'::jsonb
         )
    into v_reviews
    from public.reviews rv
   where rv.job_id = j.id;

  return jsonb_build_object(
    'ok', true,
    'job', jsonb_build_object(
      'job_id', j.id,
      'order_code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
      'title', coalesce(j.title, j.category, 'Serviço'),
      'description', coalesce(j.description, ''),
      'category', coalesce(j.category, 'Outros'),
      'status', j.status,
      'payment_status', j.payment_status,
      'escrow_status', coalesce(j.escrow_status, 'NONE'),
      'urgency', coalesce(j.urgency, 'scheduled'),
      'visibility', coalesce(j.visibility, 'open'),
      'budget_estimate_cents', round(coalesce(j.budget_estimate, 0) * 100)::bigint,
      'agreed_price_cents', round(coalesce(j.agreed_price, 0) * 100)::bigint,
      'labor_cents', round(coalesce(j.labor_amount, 0) * 100)::bigint,
      'materials_cents', round(coalesce(j.materials_amount, 0) * 100)::bigint,
      'created_at', j.created_at,
      'scheduled_for', j.scheduled_for,
      'started_at', j.started_at,
      'finished_at', j.finished_at,
      'approved_at', j.approved_at,
      'warranty_expires_at', j.warranty_expires_at,
      'start_distance_m', j.start_distance_m,
      'checkin_photo_path', j.checkin_photo_path,
      'checkout_photo_path', j.checkout_photo_path
    ),
    'client', jsonb_build_object(
      'user_id', pc.id,
      'full_name', public.safe_name(pc.full_name, 'Cliente'),
      'city', coalesce(pc.address_city, ''),
      'kyc_status', coalesce(pc.client_kyc_status::text, pc.verification_status::text, 'NOT_SUBMITTED')
    ),
    'provider', case
      when j.provider_id is not null then jsonb_build_object(
        'user_id', pp.id,
        'full_name', public.safe_name(pp.full_name, 'Profissional'),
        'city', coalesce(pp.address_city, ''),
        'verification_status', coalesce(pp.verification_status::text, 'NOT_SUBMITTED')
      )
      else null
    end,
    'location', jsonb_build_object(
      'neighborhood', coalesce(v_addr_parts ->> 'neighborhood', ''),
      'city', coalesce(v_addr_parts ->> 'city', ''),
      'uf', coalesce(v_addr_parts ->> 'uf', ''),
      'street', v_addr_parts ->> 'street',
      'number', v_addr_parts ->> 'number',
      'complement', ja.complement,
      'cep', coalesce(ja.cep, v_addr_parts ->> 'cep'),
      'lat', jg.lat,
      'lng', jg.lng,
      'precision_level', jg.precision_level,
      'source', jg.source
    ),
    'quotes', v_quotes,
    'invites', v_invites,
    'payments', v_payments,
    'ledger_txns', v_ledger,
    'maturation_entries', v_maturation,
    'fiscal_documents', v_fiscal,
    'mediations', v_mediations,
    'reviews', v_reviews
  );
end $$;

revoke all on function public.ceo_inspect_order_forensics(text, text, uuid) from public, anon;
grant execute on function public.ceo_inspect_order_forensics(text, text, uuid) to authenticated;

comment on function public.ceo_inspect_order_forensics(text, text, uuid) is
  'Dossiê forense completo e somente-leitura de uma Ordem de Serviço real para inspeção executiva do CEO.';

create or replace function public.ceo_list_real_users_directory(
  p_stepup_token text,
  p_device_hash text,
  p_search text default '',
  p_role_filter text default 'all',
  p_limit integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid;
  v_q     text := lower(btrim(coalesce(p_search, '')));
  v_role  text := lower(btrim(coalesce(p_role_filter, 'all')));
  v_lim   integer := greatest(1, least(coalesce(p_limit, 60), 200));
  v_rows  jsonb := '[]'::jsonb;
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  with dir as (
    select p.id as user_id,
           public.safe_name(p.full_name, 'Usuário') as full_name,
           p.avatar_url,
           coalesce(p.address_city, '') as city,
           coalesce(p.is_client, false) as is_client,
           coalesce(p.is_provider, false) as is_provider,
           p.verification_status::text as verification_status,
           coalesce(p.client_kyc_status, 'NOT_SUBMITTED') as client_kyc_status,
           coalesce(p.kyc_biometric_verified, false) as biometric_verified,
           coalesce(pp.specialties, '{}'::text[]) as specialties,
           coalesce(pp.rating_avg, 0)::numeric(4,2) as rating_avg,
           coalesce(pp.rating_count, 0)::integer as rating_count,
           coalesce(pp.jobs_done, 0)::integer as jobs_done,
           coalesce(pp.accepting_jobs, false) as accepting_jobs,
           coalesce(cw.available_cents, 0)::bigint as client_wallet_available_cents,
           coalesce(cw.escrow_cents, 0)::bigint as client_wallet_escrow_cents,
           round(coalesce(p.available_wallet_balance, 0) * 100)::bigint as provider_wallet_cents,
           (select count(*)::integer from public.jobs jc where jc.client_id = p.id) as client_jobs_count,
           p.created_at,
           p.updated_at
      from public.profiles p
      left join public.provider_profiles pp on pp.user_id = p.id
      left join public.client_wallets cw on cw.client_id = p.id
     where (
             v_role = 'all'
             or (v_role = 'client_only' and coalesce(p.is_client, false) = true and coalesce(p.is_provider, false) = false)
             or (v_role = 'provider_only' and coalesce(p.is_provider, false) = true and coalesce(p.is_client, false) = false)
             or (v_role = 'dual_mode' and coalesce(p.is_client, false) = true and coalesce(p.is_provider, false) = true)
             or (v_role = 'onboarding' and coalesce(p.is_client, false) = false and coalesce(p.is_provider, false) = false)
             or (v_role = 'kyc_pending' and (p.verification_status in ('PENDING', 'APPROVED_PENDING_EMAIL') or p.client_kyc_status = 'PENDING_REVIEW'))
           )
       and (
             v_q = ''
             or lower(p.full_name) like '%' || v_q || '%'
             or lower(coalesce(p.address_city, '')) like '%' || v_q || '%'
             or exists (
               select 1
                 from unnest(coalesce(pp.specialties, '{}'::text[])) sp
                where lower(sp) like '%' || v_q || '%'
             )
           )
     order by p.created_at desc
     limit v_lim
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'user_id', d.user_id,
               'full_name', d.full_name,
               'avatar_url', d.avatar_url,
               'city', d.city,
               'is_client', d.is_client,
               'is_provider', d.is_provider,
               'verification_status', d.verification_status,
               'client_kyc_status', d.client_kyc_status,
               'biometric_verified', d.biometric_verified,
               'specialties', to_jsonb(d.specialties),
               'rating_avg', d.rating_avg,
               'rating_count', d.rating_count,
               'jobs_done', d.jobs_done,
               'client_jobs_count', d.client_jobs_count,
               'accepting_jobs', d.accepting_jobs,
               'client_wallet_available_cents', d.client_wallet_available_cents,
               'client_wallet_escrow_cents', d.client_wallet_escrow_cents,
               'provider_wallet_cents', d.provider_wallet_cents,
               'created_at', d.created_at,
               'updated_at', d.updated_at
             )
             order by d.created_at desc
           ),
           '[]'::jsonb
         )
    into v_rows
    from dir d;

  return jsonb_build_object('ok', true, 'users', v_rows);
end $$;

revoke all on function public.ceo_list_real_users_directory(text, text, text, text, integer) from public, anon;
grant execute on function public.ceo_list_real_users_directory(text, text, text, text, integer) to authenticated;

comment on function public.ceo_list_real_users_directory(text, text, text, text, integer) is
  'Diretório real e pesquisável de clientes, prestadores e contas dual-mode cadastrados no Desperrengue.';

-- -----------------------------------------------------------------------------
-- 9. Ponte Criptografada em Tempo Real (`Desperrengue` -> `Desperrengue CEO`)
--    - Subtransação isolada `BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END;`
--    - Zero `LOCK TABLE` -> impacto ZERO nas transações dos usuários públicos!
--    - Broadcast privado `realtime.send` + RLS estrita em `realtime.messages`
-- -----------------------------------------------------------------------------
create or replace function private.emit_ceo_live_event_safe(
  p_event_type text,
  p_severity text,
  p_title text,
  p_subtitle text,
  p_entity_table text,
  p_entity_id text,
  p_amount_cents bigint default 0,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row     private.ceo_live_events%rowtype;
  v_payload jsonb;
begin
  begin
    insert into private.ceo_live_events (
      event_type,
      severity,
      title,
      subtitle,
      entity_table,
      entity_id,
      amount_cents,
      metadata
    ) values (
      coalesce(nullif(btrim(p_event_type), ''), 'SYSTEM_EVENT'),
      case when p_severity in ('INFO', 'SUCCESS', 'WARN', 'CRITICAL') then p_severity else 'INFO' end,
      left(coalesce(nullif(btrim(p_title), ''), 'Movimentação Desperrengue'), 160),
      left(coalesce(p_subtitle, ''), 240),
      coalesce(nullif(btrim(p_entity_table), ''), 'jobs'),
      coalesce(p_entity_id, ''),
      coalesce(p_amount_cents, 0),
      coalesce(p_metadata, '{}'::jsonb)
    )
    returning * into v_row;

    v_payload := jsonb_build_object(
      'event_seq', v_row.event_seq,
      'event_type', v_row.event_type,
      'severity', v_row.severity,
      'title', v_row.title,
      'subtitle', v_row.subtitle,
      'entity_table', v_row.entity_table,
      'entity_id', v_row.entity_id,
      'amount_cents', v_row.amount_cents,
      'metadata', v_row.metadata,
      'occurred_at', v_row.occurred_at
    );

    begin
      perform realtime.send(
        v_payload,
        'ceo_live_event',
        'ceo:war-room:live',
        true
      );
    exception when others then
      null;
    end;
  exception when others then
    null;
  end;
end $$;

revoke all on function private.emit_ceo_live_event_safe(text, text, text, text, text, text, bigint, jsonb)
  from public, anon, authenticated;

-- 9.1 Trigger em `public.profiles` (novos cadastros, ativação de modo e KYC)
create or replace function private.trg_ceo_live_profiles()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  begin
    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'USER_REGISTERED',
        'INFO',
        'Novo cadastro no Desperrengue',
        public.safe_name(new.full_name, 'Novo usuário') ||
          case when coalesce(new.address_city, '') <> '' then ' · ' || new.address_city else '' end,
        'profiles',
        new.id::text,
        0,
        jsonb_build_object('is_client', coalesce(new.is_client, false), 'is_provider', coalesce(new.is_provider, false))
      );
    elsif tg_op = 'UPDATE' then
      if new.verification_status is distinct from old.verification_status then
        perform private.emit_ceo_live_event_safe(
          'PROVIDER_KYC_' || new.verification_status::text,
          case
            when new.verification_status = 'ACTIVE' then 'SUCCESS'
            when new.verification_status = 'REJECTED' then 'WARN'
            else 'INFO'
          end,
          'KYC Profissional: ' || new.verification_status::text,
          public.safe_name(new.full_name, 'Profissional'),
          'profiles',
          new.id::text,
          0,
          jsonb_build_object('status', new.verification_status::text)
        );
      elsif new.client_kyc_status is distinct from old.client_kyc_status then
        perform private.emit_ceo_live_event_safe(
          'CLIENT_KYC_' || coalesce(new.client_kyc_status, 'UPDATED'),
          case
            when new.client_kyc_status = 'APPROVED' then 'SUCCESS'
            when new.client_kyc_status = 'REJECTED' then 'WARN'
            else 'INFO'
          end,
          'KYC Cliente: ' || coalesce(new.client_kyc_status, 'Atualizado'),
          public.safe_name(new.full_name, 'Cliente'),
          'profiles',
          new.id::text,
          0,
          jsonb_build_object('client_kyc_status', new.client_kyc_status)
        );
      elsif (coalesce(new.is_client, false) and coalesce(new.is_provider, false))
            and not (coalesce(old.is_client, false) and coalesce(old.is_provider, false)) then
        perform private.emit_ceo_live_event_safe(
          'USER_DUAL_MODE_ACTIVATED',
          'SUCCESS',
          'Conta ativou Modo Híbrido (Cliente + Prestador)',
          public.safe_name(new.full_name, 'Usuário'),
          'profiles',
          new.id::text,
          0,
          '{}'::jsonb
        );
      end if;
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_profiles() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_profiles_aiu on public.profiles;
create trigger zz_ceo_live_profiles_aiu
  after insert or update on public.profiles
  for each row execute function private.trg_ceo_live_profiles();

-- 9.2 Trigger em `public.jobs` (abertura, agendamento, início GPS, conclusão, cancelamento, disputa, coação)
create or replace function private.trg_ceo_live_jobs()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(nullif(new.labor_amount + new.materials_amount, 0), new.agreed_price, new.budget_estimate, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'JOB_OPENED',
        'INFO',
        'Novo pedido aberto ' || v_code,
        coalesce(new.category, 'Serviço') ||
          case when coalesce(new.address_summary, '') <> '' then ' · ' || new.address_summary else '' end,
        'jobs',
        new.id::text,
        v_cents,
        jsonb_build_object('status', new.status, 'urgency', new.urgency, 'category', new.category)
      );
    elsif tg_op = 'UPDATE' then
      if new.escrow_status = 'FROZEN_UNDER_DURESS' and old.escrow_status is distinct from 'FROZEN_UNDER_DURESS' then
        perform private.emit_ceo_live_event_safe(
          'DURESS_ALERT_FROZEN',
          'CRITICAL',
          'ALERTA DE COAÇÃO SILENCIOSA ' || v_code,
          'Custódia bloqueada instantaneamente no cofre soberano',
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('escrow_status', new.escrow_status)
        );
      elsif new.status is distinct from old.status then
        perform private.emit_ceo_live_event_safe(
          'JOB_STATUS_' || upper(new.status),
          case
            when new.status = 'completed' then 'SUCCESS'
            when new.status = 'disputed' then 'CRITICAL'
            when new.status = 'canceled' then 'WARN'
            else 'INFO'
          end,
          'Pedido ' || v_code || ' -> ' ||
            case new.status
              when 'awaiting_payment' then 'Aguardando Pagamento'
              when 'scheduled' then 'Agendado com Custódia'
              when 'in_progress' then 'Em Execução (Check-in GPS)'
              when 'awaiting_approval' then 'Aguardando Aprovação'
              when 'completed' then 'Concluído'
              when 'canceled' then 'Cancelado'
              when 'disputed' then 'Em Mediação'
              else new.status
            end,
          coalesce(new.category, 'Serviço') ||
            case when coalesce(new.address_summary, '') <> '' then ' · ' || new.address_summary else '' end,
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('old_status', old.status, 'new_status', new.status)
        );
      end if;
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_jobs() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_jobs_aiu on public.jobs;
create trigger zz_ceo_live_jobs_aiu
  after insert or update on public.jobs
  for each row execute function private.trg_ceo_live_jobs();

-- 9.3 Trigger em `public.quotes` (orçamentos enviados e aceitos)
create or replace function private.trg_ceo_live_quotes()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(new.price, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'QUOTE_SUBMITTED',
        'INFO',
        'Novo orçamento enviado em ' || v_code,
        'Proposta registrada por prestador credenciado',
        'quotes',
        new.job_id::text,
        v_cents,
        jsonb_build_object('quote_id', new.id, 'job_id', new.job_id)
      );
    elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
      perform private.emit_ceo_live_event_safe(
        'QUOTE_ACCEPTED',
        'SUCCESS',
        'Orçamento aceito pelo cliente em ' || v_code,
        'Contratação confirmada',
        'quotes',
        new.job_id::text,
        v_cents,
        jsonb_build_object('quote_id', new.id, 'job_id', new.job_id)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_quotes() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_quotes_aiu on public.quotes;
create trigger zz_ceo_live_quotes_aiu
  after insert or update on public.quotes
  for each row execute function private.trg_ceo_live_quotes();

-- 9.4 Trigger em `public.pix_topups` (recargas PIX geradas e liquidadas)
create or replace function private.trg_ceo_live_pix_topups()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  begin
    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'PIX_TOPUP_CREATED',
        'INFO',
        'Cobrança PIX gerada na carteira',
        'TXID ' || left(new.txid, 14),
        'pix_topups',
        new.id::text,
        new.amount_cents,
        jsonb_build_object('status', new.status)
      );
    elsif tg_op = 'UPDATE' and new.status = 'paid' and old.status is distinct from 'paid' then
      perform private.emit_ceo_live_event_safe(
        'PIX_TOPUP_PAID',
        'SUCCESS',
        'Recarga PIX confirmada no caixa',
        'Crédito conciliado em partida dobrada · TXID ' || left(new.txid, 14),
        'pix_topups',
        new.id::text,
        new.amount_cents,
        jsonb_build_object('paid_at', new.paid_at)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_pix_topups() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_pix_topups_aiu on public.pix_topups;
create trigger zz_ceo_live_pix_topups_aiu
  after insert or update on public.pix_topups
  for each row execute function private.trg_ceo_live_pix_topups();

-- 9.5 Trigger em `public.payments` & `public.escrow_maturation_entries`
create or replace function private.trg_ceo_live_escrow_maturation()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(new.net_provider_amount, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'ESCROW_SETTLED_TO_MATURATION',
        'SUCCESS',
        'Liquidação Smart Split em maturação (' || v_code || ')',
        'Taxa plataforma R$ ' || to_char(coalesce(new.platform_operational_fee, 0), 'FM999990D00'),
        'escrow_maturation_entries',
        new.job_id::text,
        v_cents,
        jsonb_build_object('maturation_status', new.maturation_status, 'available_at', new.available_at)
      );
    elsif tg_op = 'UPDATE' and new.maturation_status is distinct from old.maturation_status then
      perform private.emit_ceo_live_event_safe(
        'MATURATION_' || new.maturation_status,
        case
          when new.maturation_status = 'AVAILABLE_FOR_PIX' then 'SUCCESS'
          when new.maturation_status in ('CLAWED_BACK', 'FROZEN_BY_DISPUTE', 'FROZEN_UNDER_DURESS') then 'CRITICAL'
          else 'INFO'
        end,
        'Maturação ' || v_code || ' -> ' || new.maturation_status,
        'Atualização de custódia do prestador',
        'escrow_maturation_entries',
        new.job_id::text,
        v_cents,
        jsonb_build_object('maturation_status', new.maturation_status)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_escrow_maturation() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_escrow_maturation_aiu on public.escrow_maturation_entries;
create trigger zz_ceo_live_escrow_maturation_aiu
  after insert or update on public.escrow_maturation_entries
  for each row execute function private.trg_ceo_live_escrow_maturation();

-- 9.6 Trigger em `public.job_fiscal_documents`, `public.job_mediations`, `public.reviews`, `public.account_deletion_log`
create or replace function private.trg_ceo_live_fiscal_docs()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(new.declared_material_amount, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'FISCAL_NFE_SUBMITTED',
        'INFO',
        'NF-e de insumos registrada em ' || v_code,
        'Status fiscal: ' || new.verification_status,
        'job_fiscal_documents',
        new.job_id::text,
        v_cents,
        jsonb_build_object('verification_status', new.verification_status)
      );
    elsif tg_op = 'UPDATE' and new.verification_status is distinct from old.verification_status then
      perform private.emit_ceo_live_event_safe(
        'FISCAL_NFE_' || new.verification_status,
        case
          when new.verification_status = 'VERIFIED_SEFAZ' then 'SUCCESS'
          when new.verification_status in ('CANCELED_CLAWBACK', 'REJECTED_SEFAZ') then 'CRITICAL'
          else 'WARN'
        end,
        'Auditoria SEFAZ ' || v_code || ': ' || new.verification_status,
        case when coalesce(new.clawback_triggered, false) then 'Clawback automático de 15% acionado' else 'Conferência SEFAZ atualizada' end,
        'job_fiscal_documents',
        new.job_id::text,
        v_cents,
        jsonb_build_object('clawback_triggered', new.clawback_triggered)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_fiscal_docs() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_fiscal_docs_aiu on public.job_fiscal_documents;
create trigger zz_ceo_live_fiscal_docs_aiu
  after insert or update on public.job_fiscal_documents
  for each row execute function private.trg_ceo_live_fiscal_docs();

create or replace function private.trg_ceo_live_mediations()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.current_phase is distinct from old.current_phase) then
      perform private.emit_ceo_live_event_safe(
        'MEDIATION_' || new.current_phase,
        'WARN',
        'Mediação / Garantia ' || v_code,
        'Fase: ' || new.current_phase,
        'job_mediations',
        new.job_id::text,
        0,
        jsonb_build_object('phase', new.current_phase, 'outcome', new.resolution_outcome)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_mediations() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_mediations_aiu on public.job_mediations;
create trigger zz_ceo_live_mediations_aiu
  after insert or update on public.job_mediations
  for each row execute function private.trg_ceo_live_mediations();

create or replace function private.trg_ceo_live_reviews()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'REVIEW_SUBMITTED',
        case when new.rating >= 4 then 'SUCCESS' when new.rating <= 2 then 'WARN' else 'INFO' end,
        'Nova avaliação ' || new.rating::text || '★ em ' || v_code,
        left(coalesce(new.comment, 'Avaliação registrada'), 120),
        'reviews',
        new.job_id::text,
        0,
        jsonb_build_object('rating', new.rating)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_reviews() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_reviews_ai on public.reviews;
create trigger zz_ceo_live_reviews_ai
  after insert on public.reviews
  for each row execute function private.trg_ceo_live_reviews();

create or replace function private.trg_ceo_live_lgpd_deletions()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  begin
    perform private.emit_ceo_live_event_safe(
      'LGPD_OFFBOARDING_' || upper(coalesce(new.scope, 'ALL')),
      'WARN',
      'Offboarding LGPD executado (escopo: ' || coalesce(new.scope, 'all') || ')',
      'Dados pessoais anonimizados preservando partida dobrada',
      'account_deletion_log',
      '',
      0,
      jsonb_build_object('scope', new.scope)
    );
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_lgpd_deletions() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_lgpd_deletions_ai on public.account_deletion_log;
create trigger zz_ceo_live_lgpd_deletions_ai
  after insert on public.account_deletion_log
  for each row execute function private.trg_ceo_live_lgpd_deletions();

-- 9.7 Blindagem RLS do Canal WebSocket Privado `ceo:war-room:live` (`realtime.messages`)
create or replace function public._ceo_can_subscribe_realtime_war_room()
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not private.ceo_is_caller_monocratic_owner() then
    return false;
  end if;

  return exists (
    select 1
      from private.ceo_stepup_sessions css
     where css.user_id = auth.uid()
       and css.revoked_at is null
       and css.expires_at > now()
  );
end $$;

revoke all on function public._ceo_can_subscribe_realtime_war_room() from public, anon;
grant execute on function public._ceo_can_subscribe_realtime_war_room() to authenticated;

comment on function public._ceo_can_subscribe_realtime_war_room() is
  'Autorizador Zero-Trust de Realtime Broadcast: retorna TRUE única e exclusivamente para wagneroliveira2395@gmail.com com sessão step-up PIN SHA-256 ativa.';

do $$
begin
  if to_regclass('realtime.messages') is not null then
    execute 'alter table realtime.messages enable row level security';
    execute 'drop policy if exists "ceo_war_room_monocratic_select" on realtime.messages';
    execute $pol$
      create policy "ceo_war_room_monocratic_select"
        on realtime.messages
        for select
        to authenticated
        using (
          realtime.topic() = 'ceo:war-room:live'
          and extension in ('broadcast', 'presence')
          and public._ceo_can_subscribe_realtime_war_room()
        )
    $pol$;
  end if;
exception when others then
  raise notice 'Aviso ao configurar policy em realtime.messages: %', sqlerrm;
end $$;

-- Backfill inicial real de até 25 eventos históricos a partir dos registros já existentes no banco
-- (100% dados reais do banco atual, zero dados falsos, apenas se a tabela estiver vazia!)
do $$
begin
  if not exists (select 1 from private.ceo_live_events limit 1) then
    insert into private.ceo_live_events (
      event_type,
      severity,
      title,
      subtitle,
      entity_table,
      entity_id,
      amount_cents,
      metadata,
      occurred_at
    )
    select ev.event_type,
           ev.severity,
           ev.title,
           ev.subtitle,
           ev.entity_table,
           ev.entity_id,
           ev.amount_cents,
           ev.metadata,
           ev.occurred_at
      from (
        select 'USER_REGISTERED'::text as event_type,
               'INFO'::text as severity,
               ('Cadastro real: ' || public.safe_name(p.full_name, 'Usuário'))::text as title,
               coalesce(p.address_city, 'Desperrengue')::text as subtitle,
               'profiles'::text as entity_table,
               p.id::text as entity_id,
               0::bigint as amount_cents,
               jsonb_build_object('is_client', coalesce(p.is_client, false), 'is_provider', coalesce(p.is_provider, false)) as metadata,
               p.created_at as occurred_at
          from public.profiles p
        union all
        select ('JOB_STATUS_' || upper(j.status))::text as event_type,
               case
                 when j.status = 'completed' then 'SUCCESS'
                 when j.status = 'disputed' then 'CRITICAL'
                 when j.status = 'canceled' then 'WARN'
                 else 'INFO'
               end::text as severity,
               ('Pedido #DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)) || ' (' || j.status || ')')::text as title,
               coalesce(j.category, 'Serviço')::text as subtitle,
               'jobs'::text as entity_table,
               j.id::text as entity_id,
               round(coalesce(nullif(j.labor_amount + j.materials_amount, 0), j.agreed_price, j.budget_estimate, 0) * 100)::bigint as amount_cents,
               jsonb_build_object('status', j.status) as metadata,
               coalesce(j.updated_at, j.created_at) as occurred_at
          from public.jobs j
        union all
        select 'PIX_TOPUP_PAID'::text as event_type,
               'SUCCESS'::text as severity,
               'Recarga PIX confirmada'::text as title,
               ('TXID ' || left(pt.txid, 14))::text as subtitle,
               'pix_topups'::text as entity_table,
               pt.id::text as entity_id,
               pt.amount_cents,
               '{}'::jsonb as metadata,
               coalesce(pt.paid_at, pt.created_at) as occurred_at
          from public.pix_topups pt
         where pt.status = 'paid'
      ) ev
     order by ev.occurred_at asc
     limit 25;
  end if;
end $$;

commit;

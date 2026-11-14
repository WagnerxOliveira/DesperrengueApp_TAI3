-- =============================================================================
-- DESPERRENGUE CEO — Cofre Soberano de Senha Mestra Forte (Split-Pepper + AES-256),
-- Autoridade Isolada de 6 Dígitos e Cerimônia de Rotação em 2 E-mails + Deep-Link
-- Migration: 20261115000000_ceo_master_password_vault_and_reset_ceremony.sql (v2.14.0)
--
-- INVARIANTES INEGOCIÁVEIS DE SEGURANÇA (NIST SP 800-63B AAL3 / OWASP ASVS L3):
--   1. Titularidade Monocrática Exclusiva:
--      - Único titular aceito em nível de Kernel: `wagneroliveira2395@gmail.com`.
--      - Zero compartilhamento de senha com `auth.users.encrypted_password` do
--        aplicativo público `Desperrengue` (Marketplace).
--   2. Custódia Dividida (Split-Pepper) + Duplo Key-Stretching + AES-256 em Repouso:
--      - Cliente/Edge: `CK = PBKDF2-HMAC-SHA256(P, domain_salt, 210000, 32)` ->
--        `EK = HMAC-SHA256(CEO_VAULT_EDGE_PEPPER, CK)` (o PostgreSQL jamais recebe
--        a senha em texto puro nem `CK` sem cegamento).
--      - Kernel PostgreSQL: `25.000` rodadas iteradas de `HMAC-SHA512` combinando
--        `private.ceo_crypto_pepper` (512 bits imutável) + `password_salt_hex`
--        (256 bits CSPRNG por rotação) -> `Verifier = SHA-256(...)`, gravado em
--        disco cifrado via `extensions.pgp_sym_encrypt_bytea` (`cipher-algo=aes256,
--        compress-algo=0`).
--   3. Histórico Anti-Reuso (`private.ceo_password_history`):
--      - Impede reutilização da senha atual e das últimas 5 senhas anteriores,
--        todas verificadas em tempo constante (`private.ceo_constant_time_eq_hex`).
--   4. Infraestrutura 100% Isolada de Códigos de 6 Dígitos e Links de Troca:
--      - `private.ceo_security_challenges`: códigos de 6 dígitos para
--        `INITIAL_PASSWORD_SETUP`, `LOGIN_2FA` e `PROFILE_PASSWORD_CHANGE_AUTH`
--        persistidos apenas como digest `SHA-256` salgado + apimentado (TTL 5 min,
--        máx 5 tentativas, uso único).
--      - `private.ceo_password_reset_links`: concessão efêmera de 256 bits gerada
--        após o 1º código de 6 dígitos no Perfil do CEO, vinculada criptograficamente
--        ao `requesting_device_sha256` do celular do titular, com inspeção `GET`
--        idempotente (imune a robôs antivírus/Gmail prefetch) e consumo atômico
--        `POST` de uso único que incrementa `password_version` e mata instantaneamente
--        100% das sessões anteriores.
--   5. Persistência Forense Fora de Rollback:
--      - RPCs administrativas `public.ceo_edge_*` são exclusivas de `service_role`
--        (`REVOKE ALL FROM PUBLIC, anon, authenticated`) e retornam `JSONB` comitado
--        para garantir que lockouts, contadores de falha e `INTRUSION_CANARY` jamais
--        sejam desfeitos por `RAISE EXCEPTION`.
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Remoção definitiva da superfície anterior baseada em PIN curto / PostgREST direto
-- -----------------------------------------------------------------------------
drop function if exists public.ceo_register_personal_pin(text, text, text, text);
drop function if exists public.ceo_unlock_sovereign_vault(text, text, text);
drop function if exists public.ceo_vault_status(text);
drop function if exists public.ceo_edge_issue_otp_challenge(uuid, text, text, text, text);
drop function if exists public.ceo_edge_verify_otp_challenge(uuid, uuid, text, text, text);

-- -----------------------------------------------------------------------------
-- 2. Evolução de `private.ceo_sovereign_vault` para Senha Mestra Forte AES-256
-- -----------------------------------------------------------------------------
alter table private.ceo_sovereign_vault
  add column if not exists password_configured       boolean not null default false,
  add column if not exists password_verifier_cipher  bytea,
  add column if not exists password_salt_hex         char(64),
  add column if not exists password_kdf_spec         text not null default 'edge:pbkdf2-sha256:210000+hmac-sha256|db:hmac-sha512:25000+pgp-aes256',
  add column if not exists password_version          integer not null default 0,
  add column if not exists password_updated_at       timestamptz,
  add column if not exists failed_password_attempts  integer not null default 0,
  add column if not exists last_login_at             timestamptz,
  add column if not exists last_login_device_sha256  char(64);

alter table private.ceo_sovereign_vault
  drop constraint if exists chk_ceo_vault_master_password_state;

-- Limpa artefatos anteriores de PIN e inicializa a Cerimônia Limpa de Primeiro Acesso
-- caso nenhuma Senha Mestra Forte tenha sido configurada ainda.
update private.ceo_sovereign_vault
   set owner_email              = 'wagneroliveira2395@gmail.com',
       pin_salt_hex             = null,
       pin_sha256_hash          = null,
       pin_algo_version         = 'PBKDF2_210K_SPLIT_PEPPER_HMAC512_25K_AES256_V2',
       password_configured      = case when password_verifier_cipher is not null then true else false end,
       password_version         = case when password_verifier_cipher is not null and password_version >= 1 then password_version else 0 end,
       failed_password_attempts = 0,
       failed_pin_attempts      = 0,
       locked_until             = null,
       updated_at               = now()
 where singleton_id = true;

alter table private.ceo_sovereign_vault
  add constraint chk_ceo_vault_master_password_state check (
    password_version >= 0
    and failed_password_attempts >= 0
    and (
      (
        password_configured = false
        and password_verifier_cipher is null
        and password_salt_hex is null
        and password_version = 0
      )
      or (
        password_configured = true
        and password_verifier_cipher is not null
        and octet_length(password_verifier_cipher) >= 48
        and password_salt_hex ~ '^[0-9a-f]{64}$'
        and password_version >= 1
      )
    )
  );

alter table private.ceo_sovereign_vault enable row level security;
alter table private.ceo_sovereign_vault force row level security;
revoke all on table private.ceo_sovereign_vault from public, anon, authenticated;

-- Evolui `private.ceo_stepup_sessions` com invalidação instantânea por versão de senha
alter table private.ceo_stepup_sessions
  add column if not exists password_version_at_issue integer not null default 1;

-- Revoga sessões antigas emitidas antes da existência da Senha Mestra Forte
update private.ceo_stepup_sessions
   set revoked_at = now()
 where revoked_at is null
   and exists (
     select 1
       from private.ceo_sovereign_vault csv
      where csv.singleton_id = true
        and csv.password_configured = false
   );

-- -----------------------------------------------------------------------------
-- 3. Tabelas Isoladas: Histórico Anti-Reuso, Desafios 6d, Links Efêmeros e Rate-Limit
-- -----------------------------------------------------------------------------
create table if not exists private.ceo_password_history (
  history_id               bigserial primary key,
  password_version         integer not null check (password_version >= 1),
  password_salt_hex        char(64) not null check (password_salt_hex ~ '^[0-9a-f]{64}$'),
  password_verifier_cipher bytea not null check (octet_length(password_verifier_cipher) >= 48),
  created_at               timestamptz not null default now()
);

create index if not exists idx_ceo_password_history_version_desc
  on private.ceo_password_history (password_version desc, history_id desc);

alter table private.ceo_password_history enable row level security;
alter table private.ceo_password_history force row level security;
revoke all on table private.ceo_password_history from public, anon, authenticated;

create table if not exists private.ceo_security_challenges (
  challenge_id                  uuid primary key default gen_random_uuid(),
  user_id                       uuid not null references auth.users(id) on delete cascade,
  purpose                       text not null check (
    purpose in ('INITIAL_PASSWORD_SETUP', 'LOGIN_2FA', 'PROFILE_PASSWORD_CHANGE_AUTH')
  ),
  otp_salt_hex                  char(64) not null check (otp_salt_hex ~ '^[0-9a-f]{64}$'),
  otp_digest_sha256             char(64) not null check (otp_digest_sha256 ~ '^[0-9a-f]{64}$'),
  device_fingerprint_sha256     char(64) not null check (device_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  ip_sha256                     char(64) not null check (ip_sha256 ~ '^[0-9a-f]{64}$'),
  attempts                      integer not null default 0 check (attempts >= 0),
  max_attempts                  integer not null default 5 check (max_attempts between 1 and 5),
  expires_at                    timestamptz not null,
  consumed_at                   timestamptz,
  revoked_at                    timestamptz,
  enrollment_ticket_sha256      char(64) unique,
  enrollment_ticket_expires_at  timestamptz,
  enrollment_ticket_consumed_at timestamptz,
  created_at                    timestamptz not null default now()
);

create index if not exists idx_ceo_security_challenges_lookup
  on private.ceo_security_challenges (user_id, purpose, created_at desc);

alter table private.ceo_security_challenges enable row level security;
alter table private.ceo_security_challenges force row level security;
revoke all on table private.ceo_security_challenges from public, anon, authenticated;

create table if not exists private.ceo_password_reset_links (
  link_id                  uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users(id) on delete cascade,
  source_challenge_id      uuid not null references private.ceo_security_challenges(challenge_id) on delete restrict,
  link_salt_hex            char(64) not null check (link_salt_hex ~ '^[0-9a-f]{64}$'),
  grant_token_sha256       char(64) not null check (grant_token_sha256 ~ '^[0-9a-f]{64}$'),
  requesting_device_sha256 char(64) not null check (requesting_device_sha256 ~ '^[0-9a-f]{64}$'),
  password_version_at_issue integer not null check (password_version_at_issue >= 1),
  bridge_opened_count      integer not null default 0 check (bridge_opened_count >= 0),
  last_bridge_opened_at    timestamptz,
  expires_at               timestamptz not null,
  consumed_at              timestamptz,
  revoked_at               timestamptz,
  created_at               timestamptz not null default now()
);

create index if not exists idx_ceo_password_reset_links_active
  on private.ceo_password_reset_links (user_id, created_at desc)
  where consumed_at is null and revoked_at is null;

alter table private.ceo_password_reset_links enable row level security;
alter table private.ceo_password_reset_links force row level security;
revoke all on table private.ceo_password_reset_links from public, anon, authenticated;

create table if not exists private.ceo_rate_limits (
  bucket_key        text primary key check (btrim(bucket_key) <> ''),
  window_started_at timestamptz not null default now(),
  hits_in_window    integer not null default 0 check (hits_in_window >= 0),
  consecutive_sends integer not null default 0 check (consecutive_sends >= 0),
  cooldown_until    timestamptz,
  updated_at        timestamptz not null default now()
);

alter table private.ceo_rate_limits enable row level security;
alter table private.ceo_rate_limits force row level security;
revoke all on table private.ceo_rate_limits from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Primitivas Criptográficas Internas (`HMAC-SHA512 x 25.000` + `AES-256`)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_aes256_wrap_key()
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper bytea;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  return lower(
    encode(
      extensions.hmac('CEO_VAULT_AES256_WRAP_V1'::bytea, v_pepper, 'sha256'),
      'hex'
    )
  );
end $$;

revoke all on function private.ceo_aes256_wrap_key() from public, anon, authenticated;

-- Deriva o verificador canônico de 256 bits (`CHAR(64)` hex) sobre `EK` (já estirado
-- 210.000x via PBKDF2-SHA256 e cegado por CEO_VAULT_EDGE_PEPPER na Edge Function),
-- aplicando 25.000 rodadas de HMAC-SHA512 com `pepper_bytes || password_salt_hex`.
create or replace function private.ceo_compute_password_verifier_hex(
  p_edge_key_hex text,
  p_password_salt_hex text
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper bytea;
  v_key    bytea;
  v_u      bytea;
  i        integer;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  v_u := decode(lower(btrim(p_edge_key_hex)), 'hex');
  v_key := v_pepper || decode(lower(btrim(p_password_salt_hex)), 'hex');

  for i in 1..25000 loop
    v_u := extensions.hmac(v_u, v_key, 'sha512');
  end loop;

  return lower(encode(extensions.digest(v_u, 'sha256'), 'hex'))::char(64);
end $$;

revoke all on function private.ceo_compute_password_verifier_hex(text, text) from public, anon, authenticated;

create or replace function private.ceo_encrypt_password_verifier(
  p_verifier_hex text
)
returns bytea
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_wrap_key text := private.ceo_aes256_wrap_key();
begin
  return extensions.pgp_sym_encrypt_bytea(
    decode(lower(btrim(p_verifier_hex)), 'hex'),
    v_wrap_key,
    'cipher-algo=aes256, compress-algo=0, s2k-mode=3, s2k-digest-algo=sha512'
  );
end $$;

revoke all on function private.ceo_encrypt_password_verifier(text) from public, anon, authenticated;

create or replace function private.ceo_decrypt_password_verifier_hex(
  p_cipher bytea
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_wrap_key text := private.ceo_aes256_wrap_key();
  v_raw      bytea;
begin
  v_raw := extensions.pgp_sym_decrypt_bytea(p_cipher, v_wrap_key);
  return lower(encode(v_raw, 'hex'))::char(64);
end $$;

revoke all on function private.ceo_decrypt_password_verifier_hex(bytea) from public, anon, authenticated;

create or replace function private.ceo_compute_challenge_otp_sha256(
  p_purpose text,
  p_challenge_id uuid,
  p_otp_code text,
  p_otp_salt_hex text,
  p_device_hash text
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper  bytea;
  v_payload bytea;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  v_payload := v_pepper
    || decode(lower(btrim(p_otp_salt_hex)), 'hex')
    || convert_to(
      'CEO_CHALLENGE_V2:' ||
      upper(btrim(coalesce(p_purpose, ''))) || ':' ||
      coalesce(p_challenge_id::text, '') || ':' ||
      lower(btrim(coalesce(p_device_hash, ''))) || ':' ||
      btrim(coalesce(p_otp_code, '')),
      'UTF8'
    );

  return lower(encode(extensions.digest(v_payload, 'sha256'), 'hex'))::char(64);
end $$;

revoke all on function private.ceo_compute_challenge_otp_sha256(text, uuid, text, text, text) from public, anon, authenticated;

create or replace function private.ceo_compute_reset_grant_sha256(
  p_link_id uuid,
  p_raw_grant_hex text,
  p_link_salt_hex text
)
returns char(64)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_pepper  bytea;
  v_payload bytea;
begin
  select cp.pepper_bytes
    into v_pepper
    from private.ceo_crypto_pepper cp
   where cp.singleton_id = true;

  if v_pepper is null then
    raise exception 'ERR_CEO_PEPPER_MISSING' using errcode = 'P0001';
  end if;

  v_payload := v_pepper
    || decode(lower(btrim(p_link_salt_hex)), 'hex')
    || convert_to(
      'CEO_RESET_LINK_V2:' ||
      coalesce(p_link_id::text, '') || ':' ||
      lower(btrim(coalesce(p_raw_grant_hex, ''))),
      'UTF8'
    );

  return lower(encode(extensions.digest(v_payload, 'sha256'), 'hex'))::char(64);
end $$;

revoke all on function private.ceo_compute_reset_grant_sha256(uuid, text, text) from public, anon, authenticated;

-- Controle atômico de cooldown progressivo (30s -> 60s -> 180s -> 900s) e teto por janela
create or replace function private.ceo_check_and_bump_rate_limit(
  p_bucket_key text,
  p_max_hits_per_hour integer default 8
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_rl            private.ceo_rate_limits%rowtype;
  v_wait_sec      integer := 0;
  v_next_cooldown integer := 30;
  v_new_hits      integer;
  v_new_consec    integer;
begin
  insert into private.ceo_rate_limits (bucket_key, window_started_at, hits_in_window, consecutive_sends, cooldown_until, updated_at)
  values (btrim(p_bucket_key), now(), 0, 0, null, now())
  on conflict (bucket_key) do nothing;

  select *
    into v_rl
    from private.ceo_rate_limits rl
   where rl.bucket_key = btrim(p_bucket_key)
     for update;

  if v_rl.cooldown_until is not null and v_rl.cooldown_until > now() then
    v_wait_sec := greatest(1, ceil(extract(epoch from (v_rl.cooldown_until - now())))::integer);
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_OTP_COOLDOWN_ACTIVE',
      'retry_after_seconds', v_wait_sec
    );
  end if;

  if v_rl.window_started_at <= now() - interval '1 hour' then
    v_new_hits := 1;
    v_new_consec := 1;
  else
    if v_rl.hits_in_window >= p_max_hits_per_hour then
      v_wait_sec := greatest(60, ceil(extract(epoch from ((v_rl.window_started_at + interval '1 hour') - now())))::integer);
      return jsonb_build_object(
        'ok', false,
        'error_code', 'ERR_OTP_COOLDOWN_ACTIVE',
        'retry_after_seconds', v_wait_sec
      );
    end if;
    v_new_hits := v_rl.hits_in_window + 1;
    if v_rl.updated_at <= now() - interval '15 minutes' then
      v_new_consec := 1;
    else
      v_new_consec := v_rl.consecutive_sends + 1;
    end if;
  end if;

  v_next_cooldown := case
    when v_new_consec <= 1 then 30
    when v_new_consec = 2 then 60
    when v_new_consec = 3 then 180
    else 900
  end;

  update private.ceo_rate_limits
     set window_started_at = case when v_rl.window_started_at <= now() - interval '1 hour' then now() else window_started_at end,
         hits_in_window    = v_new_hits,
         consecutive_sends = v_new_consec,
         cooldown_until    = now() + (v_next_cooldown || ' seconds')::interval,
         updated_at        = now()
   where bucket_key = btrim(p_bucket_key);

  return jsonb_build_object(
    'ok', true,
    'next_cooldown_seconds', v_next_cooldown
  );
end $$;

revoke all on function private.ceo_check_and_bump_rate_limit(text, integer) from public, anon, authenticated;

-- Verifica se `p_edge_key_hex` coincide com a senha atual ou qualquer uma das últimas 5 senhas
create or replace function private.ceo_is_password_reused(
  p_edge_key_hex text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_stored_hex     char(64);
  v_candidate_hex  char(64);
  v_hist           record;
  v_matched        boolean := false;
begin
  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_vault.password_configured and v_vault.password_verifier_cipher is not null and v_vault.password_salt_hex is not null then
    v_stored_hex := private.ceo_decrypt_password_verifier_hex(v_vault.password_verifier_cipher);
    v_candidate_hex := private.ceo_compute_password_verifier_hex(p_edge_key_hex, v_vault.password_salt_hex);
    if private.ceo_constant_time_eq_hex(v_stored_hex, v_candidate_hex) then
      v_matched := true;
    end if;
  end if;

  for v_hist in
    select cph.password_salt_hex, cph.password_verifier_cipher
      from private.ceo_password_history cph
     order by cph.history_id desc
     limit 5
  loop
    v_stored_hex := private.ceo_decrypt_password_verifier_hex(v_hist.password_verifier_cipher);
    v_candidate_hex := private.ceo_compute_password_verifier_hex(p_edge_key_hex, v_hist.password_salt_hex);
    if private.ceo_constant_time_eq_hex(v_stored_hex, v_candidate_hex) then
      v_matched := true;
    end if;
  end loop;

  return v_matched;
end $$;

revoke all on function private.ceo_is_password_reused(text) from public, anon, authenticated;

-- Emissor interno unificado de sessão Step-Up vinculada a `(user_id, device_hash, password_version)`
create or replace function private.ceo_issue_stepup_session_internal(
  p_user_id uuid,
  p_device_hash text,
  p_device_label text,
  p_password_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev   char(64) := lower(btrim(p_device_hash))::char(64);
  v_clean_label text := left(coalesce(nullif(btrim(p_device_label), ''), 'Desperrengue CEO · Android Blindado'), 80);
  v_raw_stepup  text;
  v_stepup_hash char(64);
  v_expires_at  timestamptz := now() + interval '15 minutes';
begin
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

  delete from private.ceo_stepup_sessions
   where user_id = p_user_id
     and (expires_at <= now() or revoked_at is not null);

  v_raw_stepup := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_stepup_hash := lower(encode(extensions.digest(convert_to(v_raw_stepup, 'UTF8'), 'sha256'), 'hex'))::char(64);

  insert into private.ceo_stepup_sessions (
    user_id,
    device_fingerprint_sha256,
    session_token_sha256,
    password_version_at_issue,
    expires_at
  ) values (
    p_user_id,
    v_clean_dev,
    v_stepup_hash,
    p_password_version,
    v_expires_at
  );

  return jsonb_build_object(
    'stepup_token', v_raw_stepup,
    'expires_at', v_expires_at
  );
end $$;

revoke all on function private.ceo_issue_stepup_session_internal(uuid, text, text, integer) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Atualização dos Validadores Globais da Sala de Guerra & Realtime RLS
-- -----------------------------------------------------------------------------
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
  v_sess_dev  char(64);
begin
  if not private.ceo_is_caller_monocratic_owner() then
    raise exception 'ERR_MONOCRATIC_OWNER_ONLY_42501: Acesso exclusivo ao titular soberano.'
      using errcode = '42501';
  end if;

  if v_clean_tok !~ '^[0-9a-f]{64}$' or v_clean_dev !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_STEPUP_TOKEN_INVALID: Credencial efêmera ou assinatura de dispositivo inválida.'
      using errcode = '42501';
  end if;

  v_tok_hash := lower(encode(extensions.digest(convert_to(v_clean_tok, 'UTF8'), 'sha256'), 'hex'))::char(64);

  select css.device_fingerprint_sha256
    into v_sess_dev
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
     and css.revoked_at is null
     and css.expires_at > now()
     and csv.password_configured = true
     and csv.password_verifier_cipher is not null
     and css.password_version_at_issue = csv.password_version
     and (csv.locked_until is null or csv.locked_until <= now());

  if v_sess_dev is null or not private.ceo_constant_time_eq_hex(v_sess_dev, v_clean_dev) then
    raise exception 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED: Sessão do Cofre Soberano expirada, revogada ou versão de senha rotacionada.'
      using errcode = '42501';
  end if;

  return v_uid;
end $$;

revoke all on function private.validate_ceo_stepup_session(text, text) from public, anon, authenticated;

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
      join private.ceo_sovereign_vault csv
        on csv.singleton_id = true
       and csv.owner_user_id = css.user_id
     where css.user_id = auth.uid()
       and css.revoked_at is null
       and css.expires_at > now()
       and csv.password_configured = true
       and css.password_version_at_issue = csv.password_version
       and (csv.locked_until is null or csv.locked_until <= now())
  );
end $$;

revoke all on function public._ceo_can_subscribe_realtime_war_room() from public, anon;
grant execute on function public._ceo_can_subscribe_realtime_war_room() to authenticated;

-- -----------------------------------------------------------------------------
-- 6. RPCs Exclusivas `service_role` para a Edge Function `ceo-vault-authority`
-- -----------------------------------------------------------------------------

-- 6.1 Resolução O(log N) do UUID de `wagneroliveira2395@gmail.com` em `auth.users`
create or replace function public.ceo_edge_resolve_owner_uid()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
begin
  select au.id
    into v_uid
    from auth.users au
   where lower(btrim(au.email)) = private.ceo_owner_canonical_email()
     and au.deleted_at is null
   order by au.created_at asc
   limit 1;

  if v_uid is not null then
    update private.ceo_sovereign_vault
       set owner_user_id = coalesce(owner_user_id, v_uid),
           updated_at    = case when owner_user_id is null then now() else updated_at end
     where singleton_id = true
       and (owner_user_id is null or owner_user_id = v_uid);
  end if;

  return jsonb_build_object(
    'ok', true,
    'owner_user_id', v_uid
  );
end $$;

revoke all on function public.ceo_edge_resolve_owner_uid() from public, anon, authenticated;
grant execute on function public.ceo_edge_resolve_owner_uid() to service_role;

create or replace function public.ceo_edge_bind_owner_uid(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email text;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'CEO_BIND_OWNER_NON_CANONICAL_EMAIL',
      '{}'::jsonb
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  update private.ceo_sovereign_vault
     set owner_user_id = p_user_id,
         updated_at    = now()
   where singleton_id = true;

  return jsonb_build_object('ok', true, 'owner_user_id', p_user_id);
end $$;

revoke all on function public.ceo_edge_bind_owner_uid(uuid) from public, anon, authenticated;
grant execute on function public.ceo_edge_bind_owner_uid(uuid) to service_role;

-- 6.2 Inspeção pré-autenticação (`inspect_gate`) — zero envio de e-mail
create or replace function public.ceo_edge_inspect_vault_gate(
  p_attempted_email text,
  p_device_hash text,
  p_ip_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_norm_email text := lower(btrim(coalesce(p_attempted_email, '')));
  v_email_hash char(64);
  v_owner_hash char(64);
  v_vault      private.ceo_sovereign_vault%rowtype;
begin
  v_email_hash := lower(encode(extensions.digest(convert_to(v_norm_email, 'UTF8'), 'sha256'), 'hex'))::char(64);
  v_owner_hash := lower(encode(extensions.digest(convert_to(private.ceo_owner_canonical_email(), 'UTF8'), 'sha256'), 'hex'))::char(64);

  if not private.ceo_constant_time_eq_hex(v_email_hash, v_owner_hash) then
    perform private.record_founder_intrusion_canary(
      null,
      'CEO_GATE_INSPECT_UNAUTHORIZED_EMAIL',
      jsonb_build_object(
        'attempted_email_sha256', v_email_hash,
        'ip_sha256', left(coalesce(p_ip_hash, ''), 64),
        'device_sha256', left(coalesce(p_device_hash, ''), 64)
      )
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501'
    );
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  return jsonb_build_object(
    'ok', true,
    'password_configured', coalesce(v_vault.password_configured, false),
    'password_version', coalesce(v_vault.password_version, 0),
    'password_updated_at', v_vault.password_updated_at,
    'locked_until', case
      when v_vault.locked_until is not null and v_vault.locked_until > now() then v_vault.locked_until
      else null
    end
  );
end $$;

revoke all on function public.ceo_edge_inspect_vault_gate(text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_inspect_vault_gate(text, text, text) to service_role;

-- 6.3 Emissão de Código de 6 Dígitos para Primeiro Acesso (`INITIAL_PASSWORD_SETUP`)
create or replace function public.ceo_edge_issue_bootstrap_otp(
  p_user_id uuid,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email     text;
  v_clean_dev    text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip     text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp    text := btrim(coalesce(p_otp_code, ''));
  v_vault        private.ceo_sovereign_vault%rowtype;
  v_rl_res       jsonb;
  v_challenge_id uuid := gen_random_uuid();
  v_salt_hex     char(64);
  v_otp_digest   char(64);
  v_expires_at   timestamptz := now() + interval '5 minutes';
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'BOOTSTRAP_OTP_NON_OWNER_BLOCKED',
      jsonb_build_object('ip_sha256', left(v_clean_ip, 64))
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_dev !~ '^[0-9a-f]{64}$' or v_clean_ip !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  -- Trava irreversível: uma vez criada a Senha Mestra Forte, o bootstrap fica permanentemente selado!
  if v_vault.password_configured then
    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_BOOTSTRAP_ATTEMPT_AFTER_SEAL_BLOCKED',
      'WARN',
      true,
      jsonb_build_object('ip_sha256', v_clean_ip)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_VAULT_ALREADY_SEALED');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('bootstrap_otp', 5);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  update private.ceo_security_challenges
     set revoked_at = now()
   where user_id = p_user_id
     and purpose = 'INITIAL_PASSWORD_SETUP'
     and consumed_at is null
     and revoked_at is null;

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_digest := private.ceo_compute_challenge_otp_sha256(
    'INITIAL_PASSWORD_SETUP',
    v_challenge_id,
    v_clean_otp,
    v_salt_hex,
    v_clean_dev
  );

  insert into private.ceo_security_challenges (
    challenge_id,
    user_id,
    purpose,
    otp_salt_hex,
    otp_digest_sha256,
    device_fingerprint_sha256,
    ip_sha256,
    attempts,
    max_attempts,
    expires_at
  ) values (
    v_challenge_id,
    p_user_id,
    'INITIAL_PASSWORD_SETUP',
    v_salt_hex,
    v_otp_digest,
    v_clean_dev::char(64),
    v_clean_ip::char(64),
    0,
    5,
    v_expires_at
  );

  update private.ceo_sovereign_vault
     set owner_user_id = coalesce(owner_user_id, p_user_id),
         updated_at    = now()
   where singleton_id = true;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_BOOTSTRAP_OTP_6D_ISSUED',
    'INFO',
    false,
    jsonb_build_object('challenge_id', v_challenge_id, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'expires_at', v_expires_at,
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_issue_bootstrap_otp(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_issue_bootstrap_otp(uuid, text, text, text) to service_role;

-- 6.4 Verificação em Tempo Constante do Código de 6 Dígitos do Primeiro Acesso
create or replace function public.ceo_edge_verify_bootstrap_otp(
  p_user_id uuid,
  p_challenge_id uuid,
  p_otp_code text,
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_ch             private.ceo_security_challenges%rowtype;
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_candidate_hash char(64);
  v_new_attempts   integer;
  v_raw_ticket     text;
  v_ticket_hash    char(64);
  v_ticket_exp     timestamptz := now() + interval '10 minutes';
begin
  if p_challenge_id is null or v_clean_dev !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_vault.password_configured then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_VAULT_ALREADY_SEALED');
  end if;

  select *
    into v_ch
    from private.ceo_security_challenges csc
   where csc.challenge_id = p_challenge_id
     and csc.user_id = p_user_id
     and csc.purpose = 'INITIAL_PASSWORD_SETUP'
     for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if v_ch.consumed_at is not null or v_ch.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
  end if;

  if v_ch.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_EXPIRED');
  end if;

  if v_ch.attempts >= v_ch.max_attempts then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED');
  end if;

  if not private.ceo_constant_time_eq_hex(v_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'BOOTSTRAP_OTP_DEVICE_MISMATCH',
      jsonb_build_object('challenge_id', p_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_candidate_hash := private.ceo_compute_challenge_otp_sha256(
    'INITIAL_PASSWORD_SETUP',
    p_challenge_id,
    v_clean_otp,
    v_ch.otp_salt_hex,
    v_clean_dev
  );

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_ch.otp_digest_sha256) then
    v_new_attempts := v_ch.attempts + 1;
    update private.ceo_security_challenges
       set attempts   = v_new_attempts,
           revoked_at = case when v_new_attempts >= v_ch.max_attempts then now() else revoked_at end
     where challenge_id = p_challenge_id;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_BOOTSTRAP_OTP_6D_MISMATCH',
      case when v_new_attempts >= v_ch.max_attempts then 'CRITICAL' else 'WARN' end,
      (v_new_attempts >= v_ch.max_attempts),
      jsonb_build_object('attempts', v_new_attempts, 'challenge_id', p_challenge_id)
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_new_attempts >= v_ch.max_attempts then 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED' else 'ERR_OTP_CODE_INCORRECT' end,
      'remaining_attempts', greatest(0, v_ch.max_attempts - v_new_attempts)
    );
  end if;

  v_raw_ticket := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_ticket_hash := lower(encode(extensions.digest(convert_to(v_raw_ticket, 'UTF8'), 'sha256'), 'hex'))::char(64);

  update private.ceo_security_challenges
     set consumed_at                  = now(),
         enrollment_ticket_sha256     = v_ticket_hash,
         enrollment_ticket_expires_at = v_ticket_exp
   where challenge_id = p_challenge_id;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_BOOTSTRAP_OTP_6D_VERIFIED',
    'INFO',
    false,
    jsonb_build_object('challenge_id', p_challenge_id, 'ticket_expires_at', v_ticket_exp)
  );

  return jsonb_build_object(
    'ok', true,
    'enrollment_ticket', v_raw_ticket,
    'ticket_expires_at', v_ticket_exp
  );
end $$;

revoke all on function public.ceo_edge_verify_bootstrap_otp(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_bootstrap_otp(uuid, uuid, text, text) to service_role;

-- 6.5 Gravação Cifrada em AES-256 da Senha Mestra Inicial do CEO (`password_version = 1`)
create or replace function public.ceo_edge_set_initial_master_password(
  p_user_id uuid,
  p_enrollment_ticket text,
  p_edge_key_hex text,
  p_device_hash text,
  p_device_label text default 'Desperrengue CEO · Android Blindado'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email     text;
  v_clean_ticket text := lower(btrim(coalesce(p_enrollment_ticket, '')));
  v_clean_ek     text := lower(btrim(coalesce(p_edge_key_hex, '')));
  v_clean_dev    text := lower(btrim(coalesce(p_device_hash, '')));
  v_ticket_hash  char(64);
  v_ch           private.ceo_security_challenges%rowtype;
  v_vault        private.ceo_sovereign_vault%rowtype;
  v_salt_hex     char(64);
  v_verifier_hex char(64);
  v_cipher       bytea;
  v_now          timestamptz := now();
  v_stepup       jsonb;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'SET_INITIAL_PASSWORD_NON_OWNER_BLOCKED',
      '{}'::jsonb
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_ticket !~ '^[0-9a-f]{64}$'
     or v_clean_ek !~ '^[0-9a-f]{64}$'
     or v_clean_dev !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if v_vault.password_configured then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_VAULT_ALREADY_SEALED');
  end if;

  v_ticket_hash := lower(encode(extensions.digest(convert_to(v_clean_ticket, 'UTF8'), 'sha256'), 'hex'))::char(64);

  select *
    into v_ch
    from private.ceo_security_challenges csc
   where csc.user_id = p_user_id
     and csc.purpose = 'INITIAL_PASSWORD_SETUP'
     and csc.enrollment_ticket_sha256 = v_ticket_hash
     for update;

  if not found
     or v_ch.consumed_at is null
     or v_ch.enrollment_ticket_consumed_at is not null
     or v_ch.enrollment_ticket_expires_at is null
     or v_ch.enrollment_ticket_expires_at <= v_now
     or not private.ceo_constant_time_eq_hex(v_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_INITIAL_PASSWORD_TICKET_REJECTED',
      'WARN',
      true,
      jsonb_build_object('found', found)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED');
  end if;

  update private.ceo_security_challenges
     set enrollment_ticket_consumed_at = v_now
   where challenge_id = v_ch.challenge_id;

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_verifier_hex := private.ceo_compute_password_verifier_hex(v_clean_ek, v_salt_hex);
  v_cipher := private.ceo_encrypt_password_verifier(v_verifier_hex);

  update private.ceo_sovereign_vault
     set owner_user_id            = p_user_id,
         owner_email              = private.ceo_owner_canonical_email(),
         password_configured      = true,
         password_verifier_cipher = v_cipher,
         password_salt_hex        = v_salt_hex,
         password_kdf_spec        = 'edge:pbkdf2-sha256:210000+hmac-sha256|db:hmac-sha512:25000+pgp-aes256',
         password_version         = 1,
         password_updated_at      = v_now,
         pin_algo_version         = 'PBKDF2_210K_SPLIT_PEPPER_HMAC512_25K_AES256_V2',
         pin_configured_at        = v_now,
         pin_rotated_at           = null,
         failed_password_attempts = 0,
         failed_pin_attempts      = 0,
         locked_until             = null,
         last_login_at            = v_now,
         last_login_device_sha256 = v_clean_dev::char(64),
         updated_at               = v_now
   where singleton_id = true;

  insert into private.ceo_password_history (
    password_version,
    password_salt_hex,
    password_verifier_cipher
  ) values (
    1,
    v_salt_hex,
    v_cipher
  );

  update private.ceo_stepup_sessions
     set revoked_at = v_now
   where revoked_at is null;

  v_stepup := private.ceo_issue_stepup_session_internal(
    p_user_id,
    v_clean_dev,
    p_device_label,
    1
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_MASTER_PASSWORD_INITIALIZED_AES256',
    'INFO',
    false,
    jsonb_build_object(
      'password_version', 1,
      'kdf_spec', 'edge:pbkdf2-sha256:210000+hmac-sha256|db:hmac-sha512:25000+pgp-aes256'
    )
  );

  return jsonb_build_object(
    'ok', true,
    'password_version', 1,
    'password_updated_at', v_now,
    'stepup_token', v_stepup ->> 'stepup_token',
    'stepup_expires_at', v_stepup ->> 'expires_at'
  );
end $$;

revoke all on function public.ceo_edge_set_initial_master_password(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_set_initial_master_password(uuid, text, text, text, text) to service_role;

-- 6.6 Login Diário Passo 1: Validação em Tempo Constante da Senha Mestra AES-256 + Emissão de OTP 6d
--     Garantia Anti-Inbox-Bombing: NENHUM desafio/e-mail é emitido se a Senha Mestra estiver incorreta!
create or replace function public.ceo_edge_verify_password_and_issue_login_otp(
  p_user_id uuid,
  p_edge_key_hex text,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text,
  p_is_resend boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email       text;
  v_clean_ek       text := lower(btrim(coalesce(p_edge_key_hex, '')));
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip       text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_stored_hex     char(64);
  v_candidate_hex  char(64);
  v_failed         integer;
  v_lock_until     timestamptz;
  v_rl_res         jsonb;
  v_challenge_id   uuid := gen_random_uuid();
  v_otp_salt_hex   char(64);
  v_otp_digest     char(64);
  v_expires_at     timestamptz := now() + interval '5 minutes';
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'LOGIN_PASSWORD_NON_OWNER_BLOCKED',
      jsonb_build_object('ip_sha256', left(v_clean_ip, 64))
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_ek !~ '^[0-9a-f]{64}$'
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_ip !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if not v_vault.password_configured
     or v_vault.password_verifier_cipher is null
     or v_vault.password_salt_hex is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MASTER_PASSWORD_NOT_CONFIGURED');
  end if;

  if v_vault.locked_until is not null and v_vault.locked_until > now() then
    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_LOGIN_ATTEMPT_DURING_LOCKOUT',
      'WARN',
      true,
      jsonb_build_object('locked_until', v_vault.locked_until, 'failed_attempts', v_vault.failed_password_attempts)
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_VAULT_LOCKED_BACKOFF',
      'failed_attempts', v_vault.failed_password_attempts,
      'locked_until', v_vault.locked_until
    );
  end if;

  v_stored_hex := private.ceo_decrypt_password_verifier_hex(v_vault.password_verifier_cipher);
  v_candidate_hex := private.ceo_compute_password_verifier_hex(v_clean_ek, v_vault.password_salt_hex);

  if not private.ceo_constant_time_eq_hex(v_stored_hex, v_candidate_hex) then
    v_failed := v_vault.failed_password_attempts + 1;
    if v_failed = 4 then
      v_lock_until := now() + interval '60 seconds';
    elsif v_failed = 5 then
      v_lock_until := now() + interval '5 minutes';
    elsif v_failed >= 6 then
      v_lock_until := now() + interval '30 minutes';
    else
      v_lock_until := null;
    end if;

    update private.ceo_sovereign_vault
       set failed_password_attempts = v_failed,
           failed_pin_attempts      = v_failed,
           locked_until             = v_lock_until,
           updated_at               = now()
     where singleton_id = true;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_MASTER_PASSWORD_MISMATCH',
      case when v_failed >= 4 then 'CRITICAL' else 'WARN' end,
      (v_failed >= 4),
      jsonb_build_object(
        'failed_attempts', v_failed,
        'locked_until', v_lock_until,
        'ip_sha256', v_clean_ip
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_lock_until is not null then 'ERR_VAULT_LOCKED_BACKOFF' else 'ERR_INVALID_MASTER_PASSWORD' end,
      'failed_attempts', v_failed,
      'locked_until', v_lock_until,
      'send_lockout_security_alert', (v_failed = 5)
    );
  end if;

  -- Senha Mestra Forte provada em tempo constante! Aplica rate-limit antes de emitir o OTP 6d.
  v_rl_res := private.ceo_check_and_bump_rate_limit('login_2fa_otp', 12);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  update private.ceo_security_challenges
     set revoked_at = now()
   where user_id = p_user_id
     and purpose = 'LOGIN_2FA'
     and consumed_at is null
     and revoked_at is null;

  v_otp_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_digest := private.ceo_compute_challenge_otp_sha256(
    'LOGIN_2FA',
    v_challenge_id,
    v_clean_otp,
    v_otp_salt_hex,
    v_clean_dev
  );

  insert into private.ceo_security_challenges (
    challenge_id,
    user_id,
    purpose,
    otp_salt_hex,
    otp_digest_sha256,
    device_fingerprint_sha256,
    ip_sha256,
    attempts,
    max_attempts,
    expires_at
  ) values (
    v_challenge_id,
    p_user_id,
    'LOGIN_2FA',
    v_otp_salt_hex,
    v_otp_digest,
    v_clean_dev::char(64),
    v_clean_ip::char(64),
    0,
    5,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    case when p_is_resend then 'CEO_LOGIN_2FA_OTP_RESENT' else 'CEO_LOGIN_2FA_OTP_ISSUED' end,
    'INFO',
    false,
    jsonb_build_object('challenge_id', v_challenge_id, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'expires_at', v_expires_at,
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_verify_password_and_issue_login_otp(uuid, text, text, text, text, boolean) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_password_and_issue_login_otp(uuid, text, text, text, text, boolean) to service_role;

-- 6.6b Reenvio seguro do OTP de Login 2FA sem reter senha/chave na RAM do aparelho:
--      Exige prova de `p_previous_challenge_id` ativo recém-emitido após validação da Senha Mestra
--      no mesmo dispositivo físico, respeitando cooldown progressivo!
create or replace function public.ceo_edge_resend_login_otp(
  p_user_id uuid,
  p_previous_challenge_id uuid,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev    text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip     text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp    text := btrim(coalesce(p_otp_code, ''));
  v_prev_ch      private.ceo_security_challenges%rowtype;
  v_rl_res       jsonb;
  v_challenge_id uuid := gen_random_uuid();
  v_otp_salt_hex char(64);
  v_otp_digest   char(64);
  v_expires_at   timestamptz := now() + interval '5 minutes';
begin
  if p_previous_challenge_id is null
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_ip !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_prev_ch
    from private.ceo_security_challenges csc
   where csc.challenge_id = p_previous_challenge_id
     and csc.user_id = p_user_id
     and csc.purpose = 'LOGIN_2FA'
     for update;

  if not found
     or v_prev_ch.consumed_at is not null
     or v_prev_ch.revoked_at is not null
     or v_prev_ch.created_at <= now() - interval '15 minutes' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if not private.ceo_constant_time_eq_hex(v_prev_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'RESEND_LOGIN_OTP_DEVICE_MISMATCH',
      jsonb_build_object('previous_challenge_id', p_previous_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('login_2fa_otp', 12);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  update private.ceo_security_challenges
     set revoked_at = now()
   where user_id = p_user_id
     and purpose = 'LOGIN_2FA'
     and consumed_at is null
     and revoked_at is null;

  v_otp_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_digest := private.ceo_compute_challenge_otp_sha256(
    'LOGIN_2FA',
    v_challenge_id,
    v_clean_otp,
    v_otp_salt_hex,
    v_clean_dev
  );

  insert into private.ceo_security_challenges (
    challenge_id,
    user_id,
    purpose,
    otp_salt_hex,
    otp_digest_sha256,
    device_fingerprint_sha256,
    ip_sha256,
    attempts,
    max_attempts,
    expires_at
  ) values (
    v_challenge_id,
    p_user_id,
    'LOGIN_2FA',
    v_otp_salt_hex,
    v_otp_digest,
    v_clean_dev::char(64),
    v_clean_ip::char(64),
    0,
    5,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_LOGIN_2FA_OTP_RESENT',
    'INFO',
    false,
    jsonb_build_object('challenge_id', v_challenge_id, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'expires_at', v_expires_at,
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_resend_login_otp(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_resend_login_otp(uuid, uuid, text, text, text) to service_role;

-- 6.7 Login Diário Passo 2: Validação do Código de 6 Dígitos (`LOGIN_2FA`) + Emissão de Step-Up
create or replace function public.ceo_edge_complete_login_2fa(
  p_user_id uuid,
  p_challenge_id uuid,
  p_otp_code text,
  p_device_hash text,
  p_device_label text default 'Desperrengue CEO · Android Blindado'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_ch             private.ceo_security_challenges%rowtype;
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_candidate_hash char(64);
  v_new_attempts   integer;
  v_now            timestamptz := now();
  v_stepup         jsonb;
begin
  if p_challenge_id is null or v_clean_dev !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if not v_vault.password_configured then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MASTER_PASSWORD_NOT_CONFIGURED');
  end if;

  select *
    into v_ch
    from private.ceo_security_challenges csc
   where csc.challenge_id = p_challenge_id
     and csc.user_id = p_user_id
     and csc.purpose = 'LOGIN_2FA'
     for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if v_ch.consumed_at is not null or v_ch.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
  end if;

  if v_ch.expires_at <= v_now then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_EXPIRED');
  end if;

  if v_ch.attempts >= v_ch.max_attempts then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED');
  end if;

  if not private.ceo_constant_time_eq_hex(v_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'LOGIN_2FA_OTP_DEVICE_MISMATCH',
      jsonb_build_object('challenge_id', p_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_candidate_hash := private.ceo_compute_challenge_otp_sha256(
    'LOGIN_2FA',
    p_challenge_id,
    v_clean_otp,
    v_ch.otp_salt_hex,
    v_clean_dev
  );

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_ch.otp_digest_sha256) then
    v_new_attempts := v_ch.attempts + 1;
    update private.ceo_security_challenges
       set attempts   = v_new_attempts,
           revoked_at = case when v_new_attempts >= v_ch.max_attempts then v_now else revoked_at end
     where challenge_id = p_challenge_id;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_LOGIN_2FA_OTP_MISMATCH',
      case when v_new_attempts >= v_ch.max_attempts then 'CRITICAL' else 'WARN' end,
      (v_new_attempts >= v_ch.max_attempts),
      jsonb_build_object('attempts', v_new_attempts, 'challenge_id', p_challenge_id)
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_new_attempts >= v_ch.max_attempts then 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED' else 'ERR_OTP_CODE_INCORRECT' end,
      'remaining_attempts', greatest(0, v_ch.max_attempts - v_new_attempts)
    );
  end if;

  update private.ceo_security_challenges
     set consumed_at = v_now
   where challenge_id = p_challenge_id;

  update private.ceo_sovereign_vault
     set owner_user_id            = p_user_id,
         failed_password_attempts = 0,
         failed_pin_attempts      = 0,
         locked_until             = null,
         last_login_at            = v_now,
         last_login_device_sha256 = v_clean_dev::char(64),
         updated_at               = v_now
   where singleton_id = true;

  v_stepup := private.ceo_issue_stepup_session_internal(
    p_user_id,
    v_clean_dev,
    p_device_label,
    v_vault.password_version
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_SOVEREIGN_LOGIN_2FA_COMPLETED',
    'INFO',
    false,
    jsonb_build_object(
      'password_version', v_vault.password_version,
      'device_label', left(coalesce(p_device_label, ''), 80)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'password_version', v_vault.password_version,
    'password_updated_at', v_vault.password_updated_at,
    'stepup_token', v_stepup ->> 'stepup_token',
    'stepup_expires_at', v_stepup ->> 'expires_at'
  );
end $$;

revoke all on function public.ceo_edge_complete_login_2fa(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_complete_login_2fa(uuid, uuid, text, text, text) to service_role;

-- 6.8 Validador Auxiliar de Tripla Autenticação (`JWT User` + `stepup_token` + `device_hash` + `password_version`)
create or replace function private.ceo_verify_active_edge_stepup(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_clean_tok text := lower(btrim(coalesce(p_stepup_token, '')));
  v_clean_dev text := lower(btrim(coalesce(p_device_hash, '')));
  v_tok_hash  char(64);
  v_sess_dev  char(64);
begin
  if p_user_id is null or v_clean_tok !~ '^[0-9a-f]{64}$' or v_clean_dev !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  v_tok_hash := lower(encode(extensions.digest(convert_to(v_clean_tok, 'UTF8'), 'sha256'), 'hex'))::char(64);

  select css.device_fingerprint_sha256
    into v_sess_dev
    from private.ceo_stepup_sessions css
    join private.ceo_sovereign_vault csv
      on csv.singleton_id = true
     and csv.owner_user_id = css.user_id
   where css.session_token_sha256 = v_tok_hash
     and css.user_id = p_user_id
     and css.revoked_at is null
     and css.expires_at > now()
     and csv.password_configured = true
     and css.password_version_at_issue = csv.password_version
     and (csv.locked_until is null or csv.locked_until <= now());

  if v_sess_dev is null then
    return false;
  end if;

  return private.ceo_constant_time_eq_hex(v_sess_dev, v_clean_dev);
end $$;

revoke all on function private.ceo_verify_active_edge_stepup(uuid, text, text) from public, anon, authenticated;

-- 6.9 Status Criptográfico do Perfil Soberano do CEO
create or replace function public.ceo_edge_get_profile_security_status(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_vault        private.ceo_sovereign_vault%rowtype;
  v_active_count integer := 0;
  v_history_cnt  integer := 0;
begin
  if not private.ceo_verify_active_edge_stepup(p_user_id, p_stepup_token, p_device_hash) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED'
    );
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  select count(*)::integer
    into v_active_count
    from private.ceo_stepup_sessions css
   where css.user_id = p_user_id
     and css.revoked_at is null
     and css.expires_at > now()
     and css.password_version_at_issue = v_vault.password_version;

  select count(*)::integer
    into v_history_cnt
    from private.ceo_password_history;

  return jsonb_build_object(
    'ok', true,
    'owner_email', v_vault.owner_email,
    'password_configured', v_vault.password_configured,
    'password_version', v_vault.password_version,
    'password_updated_at', v_vault.password_updated_at,
    'last_login_at', v_vault.last_login_at,
    'kdf_spec', v_vault.password_kdf_spec,
    'active_sessions_count', v_active_count,
    'protected_history_depth', least(v_history_cnt, 5),
    'device_hash_prefix', left(lower(btrim(p_device_hash)), 12)
  );
end $$;

revoke all on function public.ceo_edge_get_profile_security_status(uuid, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_get_profile_security_status(uuid, text, text) to service_role;

-- 6.10 Perfil CEO Etapa 1: Solicita Troca de Senha -> Emite Código de 6 Dígitos (E-mail #1)
create or replace function public.ceo_edge_request_profile_password_change_otp(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev    text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip     text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp    text := btrim(coalesce(p_otp_code, ''));
  v_rl_res       jsonb;
  v_challenge_id uuid := gen_random_uuid();
  v_salt_hex     char(64);
  v_otp_digest   char(64);
  v_expires_at   timestamptz := now() + interval '5 minutes';
begin
  if not private.ceo_verify_active_edge_stepup(p_user_id, p_stepup_token, v_clean_dev) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED'
    );
  end if;

  if v_clean_ip !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('profile_pw_change_otp', 8);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  update private.ceo_security_challenges
     set revoked_at = now()
   where user_id = p_user_id
     and purpose = 'PROFILE_PASSWORD_CHANGE_AUTH'
     and consumed_at is null
     and revoked_at is null;

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_digest := private.ceo_compute_challenge_otp_sha256(
    'PROFILE_PASSWORD_CHANGE_AUTH',
    v_challenge_id,
    v_clean_otp,
    v_salt_hex,
    v_clean_dev
  );

  insert into private.ceo_security_challenges (
    challenge_id,
    user_id,
    purpose,
    otp_salt_hex,
    otp_digest_sha256,
    device_fingerprint_sha256,
    ip_sha256,
    attempts,
    max_attempts,
    expires_at
  ) values (
    v_challenge_id,
    p_user_id,
    'PROFILE_PASSWORD_CHANGE_AUTH',
    v_salt_hex,
    v_otp_digest,
    v_clean_dev::char(64),
    v_clean_ip::char(64),
    0,
    5,
    v_expires_at
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_PROFILE_PW_CHANGE_OTP_6D_ISSUED',
    'INFO',
    false,
    jsonb_build_object('challenge_id', v_challenge_id, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'expires_at', v_expires_at,
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_request_profile_password_change_otp(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_request_profile_password_change_otp(uuid, text, text, text, text) to service_role;

-- 6.11 Perfil CEO Etapa 2: Valida Código de 6 Dígitos -> Emite Concessão Efêmera do Link (E-mail #2)
create or replace function public.ceo_edge_verify_profile_otp_and_issue_reset_link(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text,
  p_challenge_id uuid,
  p_otp_code text,
  p_raw_grant_hex text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_clean_grant    text := lower(btrim(coalesce(p_raw_grant_hex, '')));
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_ch             private.ceo_security_challenges%rowtype;
  v_candidate_hash char(64);
  v_new_attempts   integer;
  v_link_id        uuid := gen_random_uuid();
  v_link_salt_hex  char(64);
  v_grant_hash     char(64);
  v_link_expires   timestamptz := now() + interval '10 minutes';
begin
  if not private.ceo_verify_active_edge_stepup(p_user_id, p_stepup_token, v_clean_dev) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED'
    );
  end if;

  if p_challenge_id is null
     or v_clean_otp !~ '^[0-9]{6}$'
     or v_clean_grant !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  select *
    into v_ch
    from private.ceo_security_challenges csc
   where csc.challenge_id = p_challenge_id
     and csc.user_id = p_user_id
     and csc.purpose = 'PROFILE_PASSWORD_CHANGE_AUTH'
     for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if v_ch.consumed_at is not null or v_ch.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
  end if;

  if v_ch.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_EXPIRED');
  end if;

  if v_ch.attempts >= v_ch.max_attempts then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED');
  end if;

  if not private.ceo_constant_time_eq_hex(v_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'PROFILE_PW_OTP_DEVICE_MISMATCH',
      jsonb_build_object('challenge_id', p_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_candidate_hash := private.ceo_compute_challenge_otp_sha256(
    'PROFILE_PASSWORD_CHANGE_AUTH',
    p_challenge_id,
    v_clean_otp,
    v_ch.otp_salt_hex,
    v_clean_dev
  );

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_ch.otp_digest_sha256) then
    v_new_attempts := v_ch.attempts + 1;
    update private.ceo_security_challenges
       set attempts   = v_new_attempts,
           revoked_at = case when v_new_attempts >= v_ch.max_attempts then now() else revoked_at end
     where challenge_id = p_challenge_id;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_PROFILE_PW_CHANGE_OTP_MISMATCH',
      case when v_new_attempts >= v_ch.max_attempts then 'CRITICAL' else 'WARN' end,
      (v_new_attempts >= v_ch.max_attempts),
      jsonb_build_object('attempts', v_new_attempts, 'challenge_id', p_challenge_id)
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_new_attempts >= v_ch.max_attempts then 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED' else 'ERR_OTP_CODE_INCORRECT' end,
      'remaining_attempts', greatest(0, v_ch.max_attempts - v_new_attempts)
    );
  end if;

  update private.ceo_security_challenges
     set consumed_at = now()
   where challenge_id = p_challenge_id;

  -- Revoga links anteriores ainda não utilizados antes de emitir o novo link único
  update private.ceo_password_reset_links
     set revoked_at = now()
   where user_id = p_user_id
     and consumed_at is null
     and revoked_at is null;

  v_link_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_grant_hash := private.ceo_compute_reset_grant_sha256(v_link_id, v_clean_grant, v_link_salt_hex);

  insert into private.ceo_password_reset_links (
    link_id,
    user_id,
    source_challenge_id,
    link_salt_hex,
    grant_token_sha256,
    requesting_device_sha256,
    password_version_at_issue,
    bridge_opened_count,
    expires_at
  ) values (
    v_link_id,
    p_user_id,
    p_challenge_id,
    v_link_salt_hex,
    v_grant_hash,
    v_clean_dev::char(64),
    v_vault.password_version,
    0,
    v_link_expires
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_PASSWORD_RESET_LINK_AUTHORIZED',
    'INFO',
    false,
    jsonb_build_object(
      'link_id', v_link_id,
      'expires_at', v_link_expires,
      'password_version_at_issue', v_vault.password_version
    )
  );

  return jsonb_build_object(
    'ok', true,
    'link_id', v_link_id,
    'expires_at', v_link_expires
  );
end $$;

revoke all on function public.ceo_edge_verify_profile_otp_and_issue_reset_link(uuid, text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_profile_otp_and_issue_reset_link(uuid, text, text, uuid, text, text) to service_role;

-- 6.12 Inspeção Idempotente da Ponte HTTPS (`GET ?bridge=reset-password`)
--      NÃO consome o token para que robôs de prefetch do Gmail/antivírus jamais queimem o link!
create or replace function public.ceo_edge_inspect_reset_link_bridge(
  p_link_id uuid,
  p_raw_grant_hex text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_grant    text := lower(btrim(coalesce(p_raw_grant_hex, '')));
  v_link           private.ceo_password_reset_links%rowtype;
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_candidate_hash char(64);
begin
  if p_link_id is null or v_clean_grant !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_INVALID');
  end if;

  select *
    into v_link
    from private.ceo_password_reset_links rl
   where rl.link_id = p_link_id;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_INVALID');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_link.consumed_at is not null
     or v_link.revoked_at is not null
     or v_link.expires_at <= now()
     or v_link.password_version_at_issue <> v_vault.password_version then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_EXPIRED_OR_USED');
  end if;

  v_candidate_hash := private.ceo_compute_reset_grant_sha256(
    p_link_id,
    v_clean_grant,
    v_link.link_salt_hex
  );

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_link.grant_token_sha256) then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_INVALID');
  end if;

  update private.ceo_password_reset_links
     set bridge_opened_count   = bridge_opened_count + 1,
         last_bridge_opened_at = now()
   where link_id = p_link_id;

  return jsonb_build_object(
    'ok', true,
    'expires_at', v_link.expires_at
  );
end $$;

revoke all on function public.ceo_edge_inspect_reset_link_bridge(uuid, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_inspect_reset_link_bridge(uuid, text) to service_role;

-- 6.13 Efetivação Atômica de Uso Único da Nova Senha Mestra via Deep-Link + Revogação Global
create or replace function public.ceo_edge_commit_password_reset_from_link(
  p_user_id uuid,
  p_link_id uuid,
  p_raw_grant_hex text,
  p_new_edge_key_hex text,
  p_device_hash text,
  p_device_label text default 'Desperrengue CEO · Android Blindado'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email       text;
  v_clean_grant    text := lower(btrim(coalesce(p_raw_grant_hex, '')));
  v_clean_ek       text := lower(btrim(coalesce(p_new_edge_key_hex, '')));
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_link           private.ceo_password_reset_links%rowtype;
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_candidate_hash char(64);
  v_new_version    integer;
  v_new_salt_hex   char(64);
  v_new_verifier   char(64);
  v_new_cipher     bytea;
  v_now            timestamptz := now();
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'COMMIT_PW_RESET_NON_OWNER_BLOCKED',
      '{}'::jsonb
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if p_link_id is null
     or v_clean_grant !~ '^[0-9a-f]{64}$'
     or v_clean_ek !~ '^[0-9a-f]{64}$'
     or v_clean_dev !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  select *
    into v_link
    from private.ceo_password_reset_links rl
   where rl.link_id = p_link_id
     and rl.user_id = p_user_id
     for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_INVALID');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if v_link.consumed_at is not null
     or v_link.revoked_at is not null
     or v_link.expires_at <= v_now
     or v_link.password_version_at_issue <> v_vault.password_version then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_EXPIRED_OR_USED');
  end if;

  v_candidate_hash := private.ceo_compute_reset_grant_sha256(
    p_link_id,
    v_clean_grant,
    v_link.link_salt_hex
  );

  if not private.ceo_constant_time_eq_hex(v_candidate_hash, v_link.grant_token_sha256) then
    update private.ceo_password_reset_links
       set revoked_at = v_now
     where link_id = p_link_id;

    perform private.record_founder_intrusion_canary(
      p_user_id,
      'RESET_LINK_GRANT_MISMATCH_REVOKED',
      jsonb_build_object('link_id', p_link_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_INVALID');
  end if;

  -- Vinculação estrita ao dispositivo físico onde o CEO solicitou a troca e validou o 1º OTP!
  if not private.ceo_constant_time_eq_hex(v_link.requesting_device_sha256, v_clean_dev) then
    update private.ceo_password_reset_links
       set revoked_at = v_now
     where link_id = p_link_id;

    perform private.record_founder_intrusion_canary(
      p_user_id,
      'RESET_LINK_DEVICE_MISMATCH_BLOCKED',
      jsonb_build_object('link_id', p_link_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_RESET_LINK_DEVICE_MISMATCH');
  end if;

  -- Bloqueia reutilização da senha atual e das últimas 5 senhas anteriores (sem queimar o link para permitir escolher outra!)
  if private.ceo_is_password_reused(v_clean_ek) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_PASSWORD_REUSE_FORBIDDEN'
    );
  end if;

  v_new_version := v_vault.password_version + 1;
  v_new_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_new_verifier := private.ceo_compute_password_verifier_hex(v_clean_ek, v_new_salt_hex);
  v_new_cipher := private.ceo_encrypt_password_verifier(v_new_verifier);

  update private.ceo_password_reset_links
     set consumed_at = v_now
   where link_id = p_link_id;

  update private.ceo_sovereign_vault
     set password_configured      = true,
         password_verifier_cipher = v_new_cipher,
         password_salt_hex        = v_new_salt_hex,
         password_version         = v_new_version,
         password_updated_at      = v_now,
         pin_algo_version         = 'PBKDF2_210K_SPLIT_PEPPER_HMAC512_25K_AES256_V2',
         pin_rotated_at           = v_now,
         failed_password_attempts = 0,
         failed_pin_attempts      = 0,
         locked_until             = null,
         updated_at               = v_now
   where singleton_id = true;

  insert into private.ceo_password_history (
    password_version,
    password_salt_hex,
    password_verifier_cipher
  ) values (
    v_new_version,
    v_new_salt_hex,
    v_new_cipher
  );

  -- Poda determinística mantendo os 5 registros mais recentes no anel histórico
  delete from private.ceo_password_history
   where history_id not in (
     select cph_keep.history_id
       from private.ceo_password_history cph_keep
      order by cph_keep.history_id desc
      limit 5
   );

  -- Revoga 100% das sessões step-up e todos os desafios abertos para exigir novo login completo (Senha Nova + Código 6d)!
  update private.ceo_stepup_sessions
     set revoked_at = v_now
   where revoked_at is null;

  update private.ceo_security_challenges
     set revoked_at = v_now
   where user_id = p_user_id
     and consumed_at is null
     and revoked_at is null;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_MASTER_PASSWORD_ROTATED_AES256',
    'INFO',
    false,
    jsonb_build_object(
      'new_password_version', v_new_version,
      'link_id', p_link_id,
      'device_label', left(coalesce(p_device_label, ''), 80),
      'all_previous_sessions_revoked', true
    )
  );

  return jsonb_build_object(
    'ok', true,
    'require_full_relogin', true,
    'password_version', v_new_version,
    'password_updated_at', v_now
  );
end $$;

revoke all on function public.ceo_edge_commit_password_reset_from_link(uuid, uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_commit_password_reset_from_link(uuid, uuid, text, text, text, text) to service_role;

commit;

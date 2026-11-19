-- =============================================================================
-- DESPERRENGUE — Escudo Zero-Trust Anti-Recadastro Duplicado, Rate-Limit
-- Deslizante de Elegibilidade de E-mail (GoTrue Obfuscation Guard) e Detecção
-- Antecipada de Conflito de CPF no Passo 1 (Zero Vazamento de PII / LGPD)
--
-- Migration: 20261118220000_duplicate_signup_guard_rate_limit_and_cpf_shield.sql
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Cofre Privado de Rate-Limit Anti-Enumeração (`private.signup_guard_rate_limits`)
--    - RLS ENABLE + FORCE e zero acesso direto para `public`, `anon` e `authenticated`
-- -----------------------------------------------------------------------------
create table if not exists private.signup_guard_rate_limits (
  bucket_key        text not null,
  window_started_at timestamptz not null default timezone('utc', now()),
  hit_count         integer not null default 1 check (hit_count >= 1),
  primary key (bucket_key)
);

create index if not exists idx_signup_guard_rate_limits_window
  on private.signup_guard_rate_limits (window_started_at);

alter table private.signup_guard_rate_limits enable row level security;
alter table private.signup_guard_rate_limits force row level security;

revoke all on table private.signup_guard_rate_limits from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. RPC Exclusivo `service_role`: `public.service_evaluate_signup_email_guard`
--    - Invocado exclusivamente pela Edge Function `signup-eligibility-guard`
--    - Janela de 10 minutos com teto estrito de 8 requisições por `p_rate_key`
--    - Proteção opaca para o e-mail canônico do Cofre Soberano CEO
--    - Distingue `AVAILABLE`, `ALREADY_REGISTERED_CONFIRMED` e
--      `PENDING_EMAIL_VERIFICATION` sem jamais retornar PII (`id`, `cpf`, `role`, `phone`)
-- -----------------------------------------------------------------------------
create or replace function public.service_evaluate_signup_email_guard(
  p_email text,
  p_rate_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_now                timestamptz := timezone('utc', now());
  v_bucket_key         text;
  v_hits               integer := 0;
  v_email              text;
  v_user_id            uuid;
  v_email_confirmed_at timestamptz;
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    raise exception 'ERR_FORBIDDEN_ROLE: Acesso restrito ao motor interno de elegibilidade.'
      using errcode = '42501';
  end if;

  v_bucket_key := 'email:' || left(coalesce(nullif(btrim(p_rate_key), ''), 'global'), 128);

  -- Expurgo oportunístico leve de janelas expiradas há mais de 24h
  if random() < 0.02 then
    delete from private.signup_guard_rate_limits
     where window_started_at < (v_now - interval '24 hours');
  end if;

  insert into private.signup_guard_rate_limits as rl (
    bucket_key,
    window_started_at,
    hit_count
  ) values (
    v_bucket_key,
    v_now,
    1
  )
  on conflict (bucket_key) do update
    set hit_count = case
          when rl.window_started_at <= (v_now - interval '10 minutes') then 1
          else rl.hit_count + 1
        end,
        window_started_at = case
          when rl.window_started_at <= (v_now - interval '10 minutes') then v_now
          else rl.window_started_at
        end
  returning hit_count into v_hits;

  if v_hits > 8 then
    return jsonb_build_object('status', 'RATE_LIMITED');
  end if;

  v_email := lower(btrim(coalesce(p_email, '')));
  if v_email = '' or position('@' in v_email) <= 1 or char_length(v_email) > 254 then
    return jsonb_build_object('status', 'AVAILABLE');
  end if;

  -- Proteção opaca (zero detalhe interno) para a titularidade monocrática do CEO
  if v_email = lower(btrim(private.ceo_owner_canonical_email())) then
    return jsonb_build_object('status', 'ALREADY_REGISTERED_CONFIRMED');
  end if;

  select au.id, au.email_confirmed_at
    into v_user_id, v_email_confirmed_at
    from auth.users au
   where lower(btrim(coalesce(au.email, ''))) = v_email
     and au.deleted_at is null
   order by (case when au.email_confirmed_at is not null then 0 else 1 end), au.created_at asc
   limit 1;

  if v_user_id is null then
    return jsonb_build_object('status', 'AVAILABLE');
  end if;

  if v_email_confirmed_at is not null or exists (
    select 1
      from auth.identities ai
     where ai.user_id = v_user_id
       and lower(btrim(coalesce(ai.provider, ''))) <> 'email'
  ) then
    return jsonb_build_object('status', 'ALREADY_REGISTERED_CONFIRMED');
  end if;

  return jsonb_build_object('status', 'PENDING_EMAIL_VERIFICATION');
end $$;

revoke all on function public.service_evaluate_signup_email_guard(text, text) from public, anon, authenticated;
grant execute on function public.service_evaluate_signup_email_guard(text, text) to service_role;

comment on function public.service_evaluate_signup_email_guard(text, text) is
  'Uso exclusivo service_role (Edge Function signup-eligibility-guard): avalia elegibilidade de e-mail no cadastro com rate-limit de 8 req/10min e zero exposição de PII.';

-- -----------------------------------------------------------------------------
-- 3. RPC Autenticado: `public.check_cpf_registration_conflict(p_cpf_raw text)`
--    - Detecta já no Passo 1 do KYC se o CPF informado pertence a outra conta ativa
--    - Rate-limit estrito por `auth.uid()` (máx. 6 verificações a cada 10 minutos)
--    - Mesmo pepper criptográfico (`DSP-CPF-PEPPER-2026:`) de `submit_unified_kyc_v2`
--    - Zero retorno de PII; emite telemetria segura ao Cofre CEO quando bloqueado
-- -----------------------------------------------------------------------------
create or replace function public.check_cpf_registration_conflict(
  p_cpf_raw text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_now        timestamptz := timezone('utc', now());
  v_bucket_key text;
  v_hits       integer := 0;
  v_digits     text;
  v_cpf_hash   text;
  v_conflict   boolean := false;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada ou usuário não autenticado.'
      using errcode = '28000';
  end if;

  v_bucket_key := 'cpf:' || v_uid::text;

  insert into private.signup_guard_rate_limits as rl (
    bucket_key,
    window_started_at,
    hit_count
  ) values (
    v_bucket_key,
    v_now,
    1
  )
  on conflict (bucket_key) do update
    set hit_count = case
          when rl.window_started_at <= (v_now - interval '10 minutes') then 1
          else rl.hit_count + 1
        end,
        window_started_at = case
          when rl.window_started_at <= (v_now - interval '10 minutes') then v_now
          else rl.window_started_at
        end
  returning hit_count into v_hits;

  if v_hits > 6 then
    raise exception 'ERR_SIGNUP_GUARD_RATE_LIMITED: Limite temporário de verificações de segurança atingido. Aguarde alguns minutos.'
      using errcode = 'P0001';
  end if;

  v_digits := regexp_replace(coalesce(p_cpf_raw, ''), '\D', '', 'g');
  if not public.is_valid_cpf(v_digits) then
    return jsonb_build_object(
      'valid_cpf', false,
      'conflict', false
    );
  end if;

  v_cpf_hash := encode(digest('DSP-CPF-PEPPER-2026:' || v_digits, 'sha256'), 'hex');

  v_conflict := exists (
    select 1
      from public.profiles p
     where p.cpf_hash = v_cpf_hash
       and p.id <> auth.uid()
  );

  if v_conflict then
    begin
      perform private.emit_ceo_live_event_safe(
        'DUPLICATE_CPF_SIGNUP_BLOCKED',
        'WARNING',
        'Tentativa de recadastro com CPF já vinculado bloqueada',
        'Escudo Anti-Sybil no Passo 1 · CPF ***.' || substring(v_digits, 4, 3) || '.' || substring(v_digits, 7, 3) || '-**',
        'profiles',
        v_uid::text,
        0,
        jsonb_build_object(
          'attempting_user_id', v_uid,
          'cpf_hash_prefix', left(v_cpf_hash, 12)
        )
      );
    exception when others then
      null;
    end;

    return jsonb_build_object(
      'valid_cpf', true,
      'conflict', true
    );
  end if;

  return jsonb_build_object(
    'valid_cpf', true,
    'conflict', false
  );
end $$;

revoke all on function public.check_cpf_registration_conflict(text) from public, anon;
grant execute on function public.check_cpf_registration_conflict(text) to authenticated;

comment on function public.check_cpf_registration_conflict(text) is
  'Verifica no Passo 1 do KYC se o CPF informado já está vinculado a outra conta ativa (rate-limit 6/10min por auth.uid(), zero vazamento de PII).';

commit;

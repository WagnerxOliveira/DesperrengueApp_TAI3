-- =============================================================================
-- DESPERRENGUE v2.37.0 — Portão REAL de ativação por e-mail (Cliente & Profissional)
--
-- Problema corrigido: a RPC `confirm_account_approval_email()` (v2.36.0) podia ser
-- chamada pelo próprio usuário autenticado, liberando a conta SEM que ele tivesse
-- clicado em "Confirmar e Ativar Minha Conta" no e-mail.
--
-- Solução:
--   * Token aleatório de 256 bits, de USO ÚNICO, com validade de 72 h, enviado só
--     por e-mail; no banco fica apenas o hash SHA-256 (nunca o token).
--   * A confirmação só acontece pela Edge Function `confirmar-email-aprovacao`
--     (service_role) via RPC `consume_approval_email_token`.
--   * A RPC antiga é REMOVIDA e nenhuma RPC de confirmação fica exposta ao usuário.
--   * Defesa em profundidade no servidor: profissional sem confirmação não é
--     "ativo/público" e cliente sem confirmação não consegue criar pedidos.
--
-- Migration: 20261126180000_approval_email_token_gate.sql
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Tabela de tokens de ativação (RLS forçada, zero acesso direto de app)
-- -----------------------------------------------------------------------------
create table if not exists public.account_approval_email_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token_hash  char(64) not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  target_mode text not null default 'client' check (target_mode in ('client', 'provider')),
  created_at  timestamptz not null default timezone('utc', now()),
  expires_at  timestamptz not null,
  consumed_at timestamptz
);

create index if not exists idx_account_approval_email_tokens_user
  on public.account_approval_email_tokens (user_id, created_at desc);

alter table public.account_approval_email_tokens enable row level security;
alter table public.account_approval_email_tokens force row level security;

revoke all on table public.account_approval_email_tokens from public, anon, authenticated;
grant select, insert, update, delete on table public.account_approval_email_tokens to service_role;

comment on table public.account_approval_email_tokens is
  'Tokens de uso único (hash SHA-256) do botão "Confirmar e Ativar Minha Conta" do e-mail de aprovação. Sem política RLS: acesso exclusivo via service_role.';

-- -----------------------------------------------------------------------------
-- 2. Remove a brecha: nenhuma RPC de confirmação exposta ao usuário autenticado
-- -----------------------------------------------------------------------------
drop function if exists public.confirm_account_approval_email();

-- -----------------------------------------------------------------------------
-- 3. Reserva atômica do envio (anti-duplicidade e anti-spam de e-mail)
--    Retorna true somente para UMA chamada dentro da janela mínima.
-- -----------------------------------------------------------------------------
create or replace function public.claim_approval_email_send_slot(
  p_user_id uuid,
  p_min_interval_seconds integer default 30
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now     timestamptz := timezone('utc', now());
  v_claimed boolean := false;
begin
  if p_user_id is null then
    return false;
  end if;

  update public.profiles
     set approval_email_sent_at = v_now
   where id = p_user_id
     and (
       approval_email_sent_at is null
       or approval_email_sent_at <= v_now - make_interval(secs => greatest(5, coalesce(p_min_interval_seconds, 30)))
     )
  returning true into v_claimed;

  return coalesce(v_claimed, false);
end $$;

revoke all on function public.claim_approval_email_send_slot(uuid, integer) from public, anon, authenticated;
grant execute on function public.claim_approval_email_send_slot(uuid, integer) to service_role;

-- -----------------------------------------------------------------------------
-- 4. Emissão do token (grava só o hash). Mantém no máximo 10 tokens ativos.
-- -----------------------------------------------------------------------------
create or replace function public.issue_approval_email_token(
  p_user_id uuid,
  p_token_hash text,
  p_target_mode text default 'client',
  p_ttl_hours integer default 72
)
returns timestamptz
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_now  timestamptz := timezone('utc', now());
  v_hash text := lower(btrim(coalesce(p_token_hash, '')));
  v_mode text := lower(btrim(coalesce(p_target_mode, 'client')));
  v_exp  timestamptz;
begin
  if p_user_id is null or v_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_INVALID_APPROVAL_TOKEN: Token de ativação inválido.'
      using errcode = '22023';
  end if;

  if v_mode not in ('client', 'provider') then
    v_mode := 'client';
  end if;

  v_exp := v_now + make_interval(hours => greatest(1, least(coalesce(p_ttl_hours, 72), 168)));

  -- Higiene: remove tokens já usados/expirados há mais de 1 dia
  delete from public.account_approval_email_tokens
   where user_id = p_user_id
     and (consumed_at is not null or expires_at < v_now - interval '1 day');

  -- Limita tokens ativos por usuário (anti-abuso)
  delete from public.account_approval_email_tokens
   where id in (
     select id
       from public.account_approval_email_tokens
      where user_id = p_user_id
        and consumed_at is null
      order by created_at desc
      offset 9
   );

  insert into public.account_approval_email_tokens (user_id, token_hash, target_mode, expires_at)
  values (p_user_id, v_hash, v_mode, v_exp);

  return v_exp;
end $$;

revoke all on function public.issue_approval_email_token(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.issue_approval_email_token(uuid, text, text, integer) to service_role;

-- -----------------------------------------------------------------------------
-- 5. Consumo do token: ÚNICO caminho que confirma a conta (somente service_role)
-- -----------------------------------------------------------------------------
create or replace function public.consume_approval_email_token(p_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_now  timestamptz := timezone('utc', now());
  v_hash text := lower(btrim(coalesce(p_token_hash, '')));
  v_row  public.account_approval_email_tokens%rowtype;
begin
  if v_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  select *
    into v_row
    from public.account_approval_email_tokens
   where token_hash = v_hash
   for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  if v_row.consumed_at is null and v_row.expires_at <= v_now then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  if v_row.consumed_at is null then
    update public.account_approval_email_tokens
       set consumed_at = v_now
     where id = v_row.id;
  end if;

  update public.profiles
     set approval_email_confirmed    = true,
         approval_email_confirmed_at = coalesce(approval_email_confirmed_at, v_now),
         verification_status         = case
           when verification_status = 'APPROVED_PENDING_EMAIL'::public.verification_status
             then 'ACTIVE'::public.verification_status
           else verification_status
         end,
         updated_at                  = v_now
   where id = v_row.user_id;

  begin
    perform private.emit_ceo_live_event_safe(
      'ACCOUNT_APPROVAL_EMAIL_CONFIRMED',
      'SUCCESS',
      'E-mail de aprovação confirmado (' || upper(v_row.target_mode) || ')',
      'Conta ativada pelo botão do e-mail',
      'profiles',
      v_row.user_id::text,
      0,
      jsonb_build_object('user_id', v_row.user_id, 'target_mode', v_row.target_mode)
    );
  exception when others then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'user_id', v_row.user_id,
    'mode', v_row.target_mode,
    'already', v_row.consumed_at is not null
  );
end $$;

revoke all on function public.consume_approval_email_token(text) from public, anon, authenticated;
grant execute on function public.consume_approval_email_token(text) to service_role;

-- -----------------------------------------------------------------------------
-- 6. Defesa em profundidade no servidor
--    (a) Profissional sem e-mail confirmado não é "ativo" nem "público"
--    (b) Cliente sem e-mail confirmado não consegue criar pedidos (RLS restritiva)
-- -----------------------------------------------------------------------------
create or replace function public.is_active_provider()
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
      from public.profiles
     where id = auth.uid()
       and is_provider
       and verification_status = 'ACTIVE'
       and coalesce(approval_email_confirmed, true)
       and (kyc_expires_at is null or kyc_expires_at > timezone('utc', now()))
  );
$$;

revoke all on function public.is_active_provider() from public, anon;
grant execute on function public.is_active_provider() to authenticated, service_role;

create or replace function public.is_public_provider(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
      from public.profiles
     where id = p_user
       and is_provider
       and verification_status = 'ACTIVE'
       and coalesce(approval_email_confirmed, true)
       and (kyc_expires_at is null or kyc_expires_at > timezone('utc', now()))
  );
$$;

revoke all on function public.is_public_provider(uuid) from public, anon;
grant execute on function public.is_public_provider(uuid) to authenticated, service_role;

create or replace function public.is_account_approval_email_ok()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.approval_email_confirmed from public.profiles p where p.id = auth.uid()),
    true
  );
$$;

revoke all on function public.is_account_approval_email_ok() from public, anon;
grant execute on function public.is_account_approval_email_ok() to authenticated, service_role;

drop policy if exists jobs_insert_requires_confirmed_email on public.jobs;
create policy jobs_insert_requires_confirmed_email
  on public.jobs
  as restrictive
  for insert
  to authenticated
  with check (public.is_account_approval_email_ok());

commit;

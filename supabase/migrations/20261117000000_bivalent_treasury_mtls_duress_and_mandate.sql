-- =============================================================================
-- DESPERRENGUE & DESPERRENGUE CEO — Tesouraria Bivalente Pré-CNPJ vs. SLU
-- (`SANDBOX_PRE_CNPJ` vs `PRODUCTION_SLU`), Equação de Teto Seguro em Centavos,
-- Trava Física Zero-Digitação PIX, Webhook Anti-Coação (`FROZEN_UNDER_DURESS`),
-- Cláusula-Mandato Art. 653 CC (`SHA-256`), Semáforo dos 4 Critérios da SLU
-- em Poços de Caldas - MG e Ponte Cross-App em Tempo Real (`85% / 13,5% / 1,5%`)
--
-- Migration: 20261117000000_bivalent_treasury_mtls_duress_and_mandate.sql
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Saneamento de Objetos Legados Órfãos (`v2.13`)
-- -----------------------------------------------------------------------------
drop function if exists private.ceo_compute_pin_sha256(text, text);
drop function if exists private.ceo_compute_otp_sha256(text, text, uuid, text);
drop table if exists private.ceo_otp_challenges cascade;

-- -----------------------------------------------------------------------------
-- 2. Validadores Matemáticos Módulo 11 (`CPF` 11 dígitos e `CNPJ` 14 dígitos)
-- -----------------------------------------------------------------------------
create or replace function private.is_valid_cpf_mod11(p_cpf text)
returns boolean
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  v_clean text := regexp_replace(coalesce(p_cpf, ''), '[^0-9]', '', 'g');
  v_sum   integer := 0;
  v_rem   integer;
  v_d1    integer;
  v_d2    integer;
  i       integer;
begin
  if char_length(v_clean) <> 11 then
    return false;
  end if;
  if v_clean ~ '^(\d)\1{10}$' then
    return false;
  end if;

  for i in 1..9 loop
    v_sum := v_sum + (substr(v_clean, i, 1)::integer * (11 - i));
  end loop;
  v_rem := (v_sum * 10) % 11;
  v_d1 := case when v_rem = 10 then 0 else v_rem end;
  if v_d1 <> substr(v_clean, 10, 1)::integer then
    return false;
  end if;

  v_sum := 0;
  for i in 1..10 loop
    v_sum := v_sum + (substr(v_clean, i, 1)::integer * (12 - i));
  end loop;
  v_rem := (v_sum * 10) % 11;
  v_d2 := case when v_rem = 10 then 0 else v_rem end;
  return (v_d2 = substr(v_clean, 11, 1)::integer);
end $$;

revoke all on function private.is_valid_cpf_mod11(text) from public, anon, authenticated;

create or replace function private.is_valid_cnpj_mod11(p_cnpj text)
returns boolean
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  v_clean text := regexp_replace(coalesce(p_cnpj, ''), '[^0-9]', '', 'g');
  v_w1    integer[] := array[5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_w2    integer[] := array[6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_sum   integer := 0;
  v_rem   integer;
  v_d1    integer;
  v_d2    integer;
  i       integer;
begin
  if char_length(v_clean) <> 14 then
    return false;
  end if;
  if v_clean ~ '^(\d)\1{13}$' then
    return false;
  end if;

  for i in 1..12 loop
    v_sum := v_sum + (substr(v_clean, i, 1)::integer * v_w1[i]);
  end loop;
  v_rem := v_sum % 11;
  v_d1 := case when v_rem < 2 then 0 else 11 - v_rem end;
  if v_d1 <> substr(v_clean, 13, 1)::integer then
    return false;
  end if;

  v_sum := 0;
  for i in 1..13 loop
    v_sum := v_sum + (substr(v_clean, i, 1)::integer * v_w2[i]);
  end loop;
  v_rem := v_sum % 11;
  v_d2 := case when v_rem < 2 then 0 else 11 - v_rem end;
  return (v_d2 = substr(v_clean, 14, 1)::integer);
end $$;

revoke all on function private.is_valid_cnpj_mod11(text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Ponte Jurídica Cross-App: Aceite Criptográfico da Cláusula-Mandato
--    Mercantil (Art. 653 do Código Civil + Segregação CPC 47 `85/13,5/1,5`)
-- -----------------------------------------------------------------------------
create table if not exists public.legal_mandate_acceptances (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  mandate_version text not null check (btrim(mandate_version) <> '' and char_length(mandate_version) <= 40),
  document_sha256 char(64) not null check (document_sha256 ~ '^[0-9a-f]{64}$'),
  role_scope      text not null check (role_scope in ('CLIENT', 'PROVIDER', 'DUAL_MODE')),
  accepted_at     timestamptz not null default now(),
  unique (user_id, mandate_version, role_scope)
);

create index if not exists idx_legal_mandate_acceptances_user
  on public.legal_mandate_acceptances (user_id, accepted_at desc);

alter table public.legal_mandate_acceptances enable row level security;
alter table public.legal_mandate_acceptances force row level security;

revoke all on table public.legal_mandate_acceptances from public, anon, authenticated;
grant select, insert on table public.legal_mandate_acceptances to authenticated;

drop policy if exists legal_mandate_select_own on public.legal_mandate_acceptances;
create policy legal_mandate_select_own
  on public.legal_mandate_acceptances
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists legal_mandate_insert_own on public.legal_mandate_acceptances;
create policy legal_mandate_insert_own
  on public.legal_mandate_acceptances
  for insert
  to authenticated
  with check (user_id = auth.uid());

create or replace function public.record_legal_mandate_acceptance(
  p_mandate_version text,
  p_document_sha256 text,
  p_role_scope text default 'CLIENT'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_ver   text := left(btrim(coalesce(p_mandate_version, '')), 40);
  v_sha   text := lower(btrim(coalesce(p_document_sha256, '')));
  v_scope text := upper(btrim(coalesce(p_role_scope, 'CLIENT')));
  v_id    uuid;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED_MANDATE' using errcode = '28000';
  end if;
  if v_ver = '' then
    raise exception 'ERR_INVALID_MANDATE_VERSION' using errcode = '22023';
  end if;
  if v_sha !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_INVALID_MANDATE_SHA256' using errcode = '22023';
  end if;
  if v_scope not in ('CLIENT', 'PROVIDER', 'DUAL_MODE') then
    raise exception 'ERR_INVALID_MANDATE_SCOPE' using errcode = '22023';
  end if;

  insert into public.legal_mandate_acceptances (
    user_id,
    mandate_version,
    document_sha256,
    role_scope
  ) values (
    v_uid,
    v_ver,
    v_sha::char(64),
    v_scope
  )
  on conflict (user_id, mandate_version, role_scope) do update
    set document_sha256 = excluded.document_sha256
  where public.legal_mandate_acceptances.document_sha256 = excluded.document_sha256
  returning id into v_id;

  if v_id is null then
    select lma.id
      into v_id
      from public.legal_mandate_acceptances lma
     where lma.user_id = v_uid
       and lma.mandate_version = v_ver
       and lma.role_scope = v_scope;
  end if;

  return jsonb_build_object(
    'ok', true,
    'acceptance_id', v_id,
    'mandate_version', v_ver,
    'document_sha256', v_sha,
    'role_scope', v_scope
  );
end $$;

revoke all on function public.record_legal_mandate_acceptance(text, text, text) from public, anon;
grant execute on function public.record_legal_mandate_acceptance(text, text, text) to authenticated;

create or replace function private.trg_ceo_live_legal_mandates()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_name text;
begin
  begin
    select public.safe_name(prof.full_name, 'Usuário')
      into v_name
      from public.profiles prof
     where prof.id = new.user_id;

    perform private.emit_ceo_live_event_safe(
      'LEGAL_MANDATE_ART653_ACCEPTED',
      'SUCCESS',
      'Mandato Mercantil Art. 653 assinado (' || new.role_scope || ')',
      coalesce(v_name, 'Usuário') || ' · Versão ' || new.mandate_version || ' · SHA-256 ' || left(new.document_sha256, 12) || '…',
      'legal_mandate_acceptances',
      new.id::text,
      0,
      jsonb_build_object(
        'user_id', new.user_id,
        'mandate_version', new.mandate_version,
        'role_scope', new.role_scope,
        'document_sha256', new.document_sha256
      )
    );
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_legal_mandates() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_legal_mandates_ai on public.legal_mandate_acceptances;
create trigger zz_ceo_live_legal_mandates_ai
  after insert on public.legal_mandate_acceptances
  for each row execute function private.trg_ceo_live_legal_mandates();

-- Gatilho em tempo real para liquidez de rua em Poços de Caldas - MG (Critério 3 do Sinal Verde SLU)
create or replace function private.trg_ceo_live_pocos_liquidity()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_norm_new text := translate(lower(coalesce(new.address_city, '')), 'çáàâãéêíóôõú', 'caaaaeeiooou');
  v_norm_old text := case when tg_op = 'UPDATE' then translate(lower(coalesce(old.address_city, '')), 'çáàâãéêíóôõú', 'caaaaeeiooou') else '' end;
begin
  begin
    if coalesce(new.is_provider, false) = true
       and v_norm_new like '%pocos de caldas%'
       and (
         tg_op = 'INSERT'
         or coalesce(old.is_provider, false) is distinct from coalesce(new.is_provider, false)
         or v_norm_old is distinct from v_norm_new
         or old.verification_status is distinct from new.verification_status
       ) then
      perform private.emit_ceo_live_event_safe(
        'POCOS_PROVIDER_LIQUIDITY_SYNC',
        'SUCCESS',
        'Liquidez Poços de Caldas atualizada',
        public.safe_name(new.full_name, 'Profissional') || ' · Status ' || coalesce(new.verification_status::text, 'EM CADASTRO'),
        'profiles',
        new.id::text,
        0,
        jsonb_build_object(
          'city', new.address_city,
          'verification_status', new.verification_status,
          'is_provider', new.is_provider
        )
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_pocos_liquidity() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_pocos_liquidity_aiu on public.profiles;
create trigger zz_ceo_live_pocos_liquidity_aiu
  after insert or update of is_provider, address_city, verification_status on public.profiles
  for each row execute function private.trg_ceo_live_pocos_liquidity();

-- -----------------------------------------------------------------------------
-- 4. Cofre de Tesouraria Bivalente no Esquema `private`
--    (`SANDBOX_PRE_CNPJ` vs `PRODUCTION_SLU` + Trava Física Zero-Digitação PIX)
-- -----------------------------------------------------------------------------
create table if not exists private.ceo_treasury_config (
  singleton_id                  boolean primary key default true check (singleton_id = true),
  operating_mode                text not null default 'SANDBOX_PRE_CNPJ'
    check (operating_mode in ('SANDBOX_PRE_CNPJ', 'PRODUCTION_SLU')),
  slu_cnpj_digits               text
    check (slu_cnpj_digits is null or private.is_valid_cnpj_mod11(slu_cnpj_digits)),
  sole_partner_cpf_digits       text
    check (sole_partner_cpf_digits is null or private.is_valid_cpf_mod11(sole_partner_cpf_digits)),
  slu_legal_name                text not null default 'HOMOLOGACAO PRE-CNPJ (SLU POCOS DE CALDAS - MG)',
  municipal_registration_pocos  text,
  cnae_primary                  text not null default '6319-4/00',
  cnae_secondary                text not null default '8211-3/00',
  settlement_psp                text not null default 'ASAAS_SANDBOX'
    check (settlement_psp in (
      'ASAAS_SANDBOX',
      'ASAAS_PRODUCTION',
      'INTER_MTLS_SANDBOX',
      'INTER_MTLS_PRODUCTION',
      'EFI_MTLS_SANDBOX',
      'EFI_MTLS_PRODUCTION'
    )),
  safety_buffer_cents           bigint not null default 30000
    check (safety_buffer_cents >= 0 and safety_buffer_cents <= 1000000000),
  takeoff_reserve_target_cents  bigint not null default 130000
    check (takeoff_reserve_target_cents >= 100000 and takeoff_reserve_target_cents <= 10000000),
  takeoff_reserve_saved_cents   bigint not null default 0
    check (takeoff_reserve_saved_cents >= 0 and takeoff_reserve_saved_cents <= 100000000),
  pocos_providers_target        integer not null default 20
    check (pocos_providers_target between 15 and 100),
  duress_mode_status            text not null default 'NORMAL'
    check (duress_mode_status in ('NORMAL', 'FROZEN_UNDER_DURESS')),
  duress_triggered_at           timestamptz,
  sandbox_zero_drift_since      timestamptz not null default now(),
  production_unlocked_at        timestamptz,
  updated_at                    timestamptz not null default now(),
  constraint chk_production_slu_requires_valid_docs check (
    operating_mode = 'SANDBOX_PRE_CNPJ'
    or (
      slu_cnpj_digits is not null
      and sole_partner_cpf_digits is not null
      and settlement_psp in ('ASAAS_PRODUCTION', 'INTER_MTLS_PRODUCTION', 'EFI_MTLS_PRODUCTION')
    )
  )
);

alter table private.ceo_treasury_config enable row level security;
alter table private.ceo_treasury_config force row level security;
revoke all on table private.ceo_treasury_config from public, anon, authenticated;

insert into private.ceo_treasury_config (singleton_id)
values (true)
on conflict (singleton_id) do nothing;

-- Destino único travado fisicamente: NENHUMA coluna de chave PIX digitável existe!
create table if not exists private.ceo_payout_destinations (
  singleton_id          boolean primary key default true check (singleton_id = true),
  beneficiary_full_name text not null default 'Wagner Oliveira' check (btrim(beneficiary_full_name) <> ''),
  destination_lock_mode text not null default 'LOCKED_SOLE_PARTNER_CPF_ACCOUNT'
    check (destination_lock_mode = 'LOCKED_SOLE_PARTNER_CPF_ACCOUNT'),
  allow_typed_pix_keys  boolean not null default false
    check (allow_typed_pix_keys = false),
  bank_ispb             text not null default '00416968'
    check (bank_ispb ~ '^[0-9]{8}$'),
  bank_display_label    text not null default 'Conta Pessoa Física Titular Único (Travada por CPF)',
  locked_at             timestamptz not null default now()
);

alter table private.ceo_payout_destinations enable row level security;
alter table private.ceo_payout_destinations force row level security;
revoke all on table private.ceo_payout_destinations from public, anon, authenticated;

insert into private.ceo_payout_destinations (singleton_id)
values (true)
on conflict (singleton_id) do nothing;

-- Razão WORM de retiradas de lucro / pró-labore / comprovantes anti-coação
create table if not exists private.ceo_profit_distributions (
  id                uuid primary key default gen_random_uuid(),
  idempotency_key   text not null unique check (char_length(btrim(idempotency_key)) between 12 and 128),
  distribution_kind text not null check (distribution_kind in ('PROFIT_DISTRIBUTION', 'PRO_LABORE', 'TAX_DAS_SETTLEMENT')),
  operating_mode    text not null check (operating_mode in ('SANDBOX_PRE_CNPJ', 'PRODUCTION_SLU')),
  psp_provider      text not null check (btrim(psp_provider) <> ''),
  requested_cents   bigint not null check (requested_cents > 0 and requested_cents <= 1000000000),
  settled_cents     bigint not null default 0 check (settled_cents >= 0 and settled_cents <= requested_cents),
  is_duress_decoy   boolean not null default false,
  status            text not null check (status in (
    'PREPARED',
    'SETTLED_SANDBOX',
    'SETTLED_PRODUCTION',
    'DECOY_FROZEN_ZERO_MOVED',
    'REJECTED'
  )),
  psp_transfer_id   text,
  ceiling_snapshot  jsonb not null default '{}'::jsonb,
  receipt_sha256    char(64) not null check (receipt_sha256 ~ '^[0-9a-f]{64}$'),
  created_by        uuid not null,
  created_at        timestamptz not null default now(),
  finalized_at      timestamptz,
  constraint chk_decoy_never_settles_real_cents check (
    not is_duress_decoy or (settled_cents = 0 and status = 'DECOY_FROZEN_ZERO_MOVED')
  )
);

create index if not exists idx_ceo_profit_distributions_created
  on private.ceo_profit_distributions (created_at desc);

alter table private.ceo_profit_distributions enable row level security;
alter table private.ceo_profit_distributions force row level security;
revoke all on table private.ceo_profit_distributions from public, anon, authenticated;

create or replace function private.trg_worm_ceo_profit_distributions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'ERR_WORM_DISTRIBUTION_IMMUTABLE: Exclusão proibida no razão de distribuições.'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' then
    if old.status in ('SETTLED_SANDBOX', 'SETTLED_PRODUCTION', 'DECOY_FROZEN_ZERO_MOVED', 'REJECTED') then
      raise exception 'ERR_WORM_DISTRIBUTION_IMMUTABLE: Registro finalizado não pode ser adulterado.'
        using errcode = '42501';
    end if;
    if new.id <> old.id
       or new.idempotency_key <> old.idempotency_key
       or new.requested_cents <> old.requested_cents
       or new.operating_mode <> old.operating_mode
       or new.created_by <> old.created_by then
      raise exception 'ERR_WORM_DISTRIBUTION_IMMUTABLE: Campos âncora de distribuição são imutáveis.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end $$;

revoke all on function private.trg_worm_ceo_profit_distributions() from public, anon, authenticated;

drop trigger if exists zz_worm_ceo_profit_distributions_bud on private.ceo_profit_distributions;
create trigger zz_worm_ceo_profit_distributions_bud
  before update or delete on private.ceo_profit_distributions
  for each row execute function private.trg_worm_ceo_profit_distributions();

-- Tabela anti-replay para Webhooks de validação de transferência (Asaas / PSP)
create table if not exists private.ceo_webhook_processed_events (
  event_id       text primary key check (char_length(btrim(event_id)) between 4 and 160),
  provider       text not null check (btrim(provider) <> ''),
  event_type     text not null check (btrim(event_type) <> ''),
  decision       text not null check (decision in ('APPROVED', 'REFUSED')),
  refuse_reason  text,
  amount_cents   bigint not null default 0,
  payload_sha256 char(64) not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  processed_at   timestamptz not null default now()
);

alter table private.ceo_webhook_processed_events enable row level security;
alter table private.ceo_webhook_processed_events force row level security;
revoke all on table private.ceo_webhook_processed_events from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Validador AAL3 Step-Up para Edge Functions (`service_role` + JWT verificado)
-- -----------------------------------------------------------------------------
create or replace function private.validate_ceo_stepup_session_for_edge(
  p_actor_uid uuid,
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
  v_email     text;
  v_clean_tok text := lower(btrim(coalesce(p_stepup_token, '')));
  v_clean_dev text := lower(btrim(coalesce(p_device_hash, '')));
  v_tok_hash  char(64);
  v_sess_dev  char(64);
begin
  if p_actor_uid is null then
    raise exception 'ERR_MONOCRATIC_OWNER_ONLY_42501: Identidade ausente.'
      using errcode = '42501';
  end if;

  select lower(btrim(au.email))
    into v_email
    from auth.users au
   where au.id = p_actor_uid;

  if v_email is distinct from private.ceo_owner_canonical_email() then
    raise exception 'ERR_MONOCRATIC_OWNER_ONLY_42501: Acesso exclusivo ao titular soberano.'
      using errcode = '42501';
  end if;

  if v_clean_tok !~ '^[0-9a-f]{64}$' or v_clean_dev !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_STEPUP_TOKEN_INVALID: Credencial efêmera ou dispositivo inválido.'
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
     and css.user_id = p_actor_uid
     and css.revoked_at is null
     and css.expires_at > now()
     and csv.password_configured = true
     and csv.password_verifier_cipher is not null
     and css.password_version_at_issue = csv.password_version
     and (csv.locked_until is null or csv.locked_until <= now());

  if v_sess_dev is null or not private.ceo_constant_time_eq_hex(v_sess_dev, v_clean_dev) then
    raise exception 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED: Sessão do Cofre Soberano expirada ou revogada.'
      using errcode = '42501';
  end if;

  return p_actor_uid;
end $$;

revoke all on function private.validate_ceo_stepup_session_for_edge(uuid, text, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6. Motor Matemático de Teto Seguro (`WithdrawableProfitCents` em `BIGINT`) +
--    Semáforo em Tempo Real dos 4 Critérios do "Sinal Verde" para Abrir a SLU
-- -----------------------------------------------------------------------------
create or replace function private.ceo_compute_safe_treasury_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  cfg                            private.ceo_treasury_config%rowtype;
  dest                           private.ceo_payout_destinations%rowtype;
  -- Segregação e receitas acumuladas reais da plataforma (13,5% + SOS)
  v_cum_gmv_cents                bigint := 0;
  v_cum_exempt_materials_cents   bigint := 0;
  v_cum_provider_85_net_cents    bigint := 0;
  v_cum_platform_op_13_5_cents   bigint := 0;
  v_cum_warranty_1_5_cents       bigint := 0;
  v_cum_sos_fee_cents            bigint := 0;
  v_cum_platform_gross_rev_cents bigint := 0;
  -- Custódia intocável atual (Terceiros + Fundo Garantidor)
  v_client_wallets_total_cents   bigint := 0;
  v_provider_wallets_avail_cents bigint := 0;
  v_provider_maturing_cents      bigint := 0;
  v_active_escrow_jobs_cents     bigint := 0;
  v_untouchable_custody_cents    bigint := 0;
  v_warranty_pool_balance_cents  bigint := 0;
  -- Conciliação Tripla (tolerância 0 centavos)
  v_pix_topups_confirmed_cents   bigint := 0;
  v_ledger_topups_cents          bigint := 0;
  v_ledger_client_custody_cents  bigint := 0;
  v_ledger_global_imbalance      bigint := 0;
  v_recon_discrepancy_cents      bigint := 0;
  -- Provisões Fiscais, Despesas Reais e Distribuições Anteriores
  v_cum_das_6pct_cents           bigint := 0;
  v_das_paid_cents               bigint := 0;
  v_das_unpaid_provision_cents   bigint := 0;
  v_expenses_paid_non_das_cents  bigint := 0;
  v_expenses_scheduled_cents     bigint := 0;
  v_prior_settled_dist_cents     bigint := 0;
  v_inflight_prepared_dist_cents bigint := 0;
  -- Resultado da Equação de Teto Seguro
  v_duress_jobs_count            integer := 0;
  v_is_duress_frozen             boolean := false;
  v_audit_chain_ok               boolean := true;
  v_geo_leak_bps                 integer := 0;
  v_raw_surplus_cents            bigint := 0;
  v_withdrawable_profit_cents    bigint := 0;
  v_blocked_reason               text := 'NONE';
  v_recent_distributions         jsonb := '[]'::jsonb;
  -- Semáforo dos 4 Critérios Objetivos do Sinal Verde SLU (Poços de Caldas - MG)
  v_zero_drift_days_elapsed      integer := 0;
  v_sandbox_payouts_tested_count integer := 0;
  v_pocos_providers_total_count  integer := 0;
  v_pocos_providers_active_count integer := 0;
  v_mandate_accepted_users_count integer := 0;
  v_mandate_providers_count      integer := 0;
  v_crit1_stability_7d_ok        boolean := false;
  v_crit2_p0_p1_zeroed_ok        boolean := false;
  v_crit3_pocos_liquidity_ok     boolean := false;
  v_crit4_takeoff_reserve_ok     boolean := false;
begin
  select * into cfg from private.ceo_treasury_config where singleton_id = true;
  select * into dest from private.ceo_payout_destinations where singleton_id = true;

  -- 1) Receita acumulada da plataforma (13,5% sobre mão de obra concluída + taxas SOS)
  with all_settled as (
    select jb.id,
           gmv_c.gmv_cents,
           ex_c.exempt_cents,
           fee_c.op_fee_cents,
           fee_c.carveout_cents,
           greatest(
             0::bigint,
             greatest(0::bigint, gmv_c.gmv_cents - ex_c.exempt_cents)
             - fee_c.op_fee_cents
             - fee_c.carveout_cents
           ) as prov_net_cents
      from public.jobs jb
      left join public.escrow_maturation_entries eme on eme.job_id = jb.id
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
      ) gmv_c
      cross join lateral (
        select least(
          gmv_c.gmv_cents,
          case
            when eme.id is not null then round(eme.materials_reimbursement_amount * 100)::bigint
            else 0::bigint
          end
        ) as exempt_cents
      ) ex_c
      cross join lateral (
        select case
                 when eme.id is not null then round(eme.platform_operational_fee * 100)::bigint
                 when lp.fee_amount is not null and lp.fee_amount > 0 then
                   greatest(
                     0::bigint,
                     round(lp.fee_amount * 100)::bigint
                     - round(greatest(0::bigint, gmv_c.gmv_cents - ex_c.exempt_cents) * 15.0 / 1000.0)::bigint
                   )
                 else round(greatest(0::bigint, gmv_c.gmv_cents - ex_c.exempt_cents) * 135.0 / 1000.0)::bigint
               end as op_fee_cents,
               case
                 when eme.id is not null then round(eme.warranty_carveout_fee * 100)::bigint
                 else round(greatest(0::bigint, gmv_c.gmv_cents - ex_c.exempt_cents) * 15.0 / 1000.0)::bigint
               end as carveout_cents
      ) fee_c
     where jb.status = 'completed'
       and coalesce(jb.is_warranty_rework, false) = false
       and coalesce(jb.escrow_status, 'NONE') <> 'FROZEN_UNDER_DURESS'
  )
  select coalesce(sum(s.gmv_cents), 0)::bigint,
         coalesce(sum(s.exempt_cents), 0)::bigint,
         coalesce(sum(s.prov_net_cents), 0)::bigint,
         coalesce(sum(s.op_fee_cents), 0)::bigint,
         coalesce(sum(s.carveout_cents), 0)::bigint
    into v_cum_gmv_cents,
         v_cum_exempt_materials_cents,
         v_cum_provider_85_net_cents,
         v_cum_platform_op_13_5_cents,
         v_cum_warranty_1_5_cents
    from all_settled s;

  select coalesce(sum(greatest(0::bigint, ll.cents)), 0)::bigint
    into v_cum_sos_fee_cents
    from public.ledger_lines ll
   where ll.account = 'platform:sos_fee';

  v_cum_platform_gross_rev_cents := v_cum_platform_op_13_5_cents + v_cum_sos_fee_cents;

  -- 2) Parede Intocável de Custódia de Terceiros (85% Prestadores + Carteiras Clientes + 1,5% Garantia)
  select coalesce(sum(cw.available_cents + cw.escrow_cents), 0)::bigint
    into v_client_wallets_total_cents
    from public.client_wallets cw;

  select coalesce(sum(round(greatest(0::numeric, pr.available_wallet_balance) * 100)::bigint), 0)::bigint
    into v_provider_wallets_avail_cents
    from public.profiles pr;

  select coalesce(
           sum(round(eme.net_provider_amount * 100)::bigint) filter (
             where eme.maturation_status in ('MATURING', 'AVAILABLE_FOR_PIX', 'FROZEN_BY_DISPUTE', 'FROZEN_UNDER_DURESS')
           ),
           0
         )::bigint
    into v_provider_maturing_cents
    from public.escrow_maturation_entries eme;

  select coalesce(
           sum(round(coalesce(nullif(jb.labor_amount + jb.materials_amount, 0), jb.agreed_price, 0) * 100)::bigint),
           0
         )::bigint
    into v_active_escrow_jobs_cents
    from public.jobs jb
   where jb.payment_status = 'escrow'
     and jb.status in ('scheduled', 'in_progress', 'awaiting_approval', 'disputed');

  select greatest(
           0::bigint,
           coalesce(
             sum(round(wpl.amount * 100)::bigint) filter (
               where wpl.entry_type in ('CARVEOUT_CONTRIBUTION_1_5_PCT', 'CLAWBACK_RECOVERY_CREDIT', 'COLD_START_SEED_RESERVE')
             ),
             0
           )::bigint
           - coalesce(
             sum(round(wpl.amount * 100)::bigint) filter (
               where wpl.entry_type = 'REWORK_PAYOUT_DEBIT'
             ),
             0
           )::bigint
         )
    into v_warranty_pool_balance_cents
    from public.warranty_pool_ledger wpl;

  v_untouchable_custody_cents :=
    v_client_wallets_total_cents
    + v_provider_wallets_avail_cents
    + v_provider_maturing_cents
    + v_warranty_pool_balance_cents;

  -- 3) Conciliação Tripla Exata (desvio permitido = 0 centavos)
  select coalesce(sum(pt.amount_cents) filter (where pt.status = 'paid'), 0)::bigint
    into v_pix_topups_confirmed_cents
    from public.pix_topups pt;

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

  v_recon_discrepancy_cents := greatest(
    abs(v_client_wallets_total_cents - v_ledger_client_custody_cents),
    abs(v_pix_topups_confirmed_cents - v_ledger_topups_cents),
    v_ledger_global_imbalance
  );

  -- 4) Provisão Fiscal DAS (6% Anexo III) + Despesas Pagas/Agendadas + Retiradas Anteriores
  v_cum_das_6pct_cents := (v_cum_platform_gross_rev_cents * 6 + 50) / 100;

  select coalesce(
           sum(cee.amount_cents) filter (
             where cee.payment_status = 'PAID'
               and cee.expense_kind = 'TAX_EXTRA'
               and (
                 cee.category ilike '%das%'
                 or cee.category ilike '%simples%'
                 or cee.description ilike '%das%'
                 or cee.description ilike '%simples%'
               )
           ),
           0
         )::bigint,
         coalesce(
           sum(cee.amount_cents) filter (
             where cee.payment_status = 'PAID'
               and not (
                 cee.expense_kind = 'TAX_EXTRA'
                 and (
                   cee.category ilike '%das%'
                   or cee.category ilike '%simples%'
                   or cee.description ilike '%das%'
                   or cee.description ilike '%simples%'
                 )
               )
           ),
           0
         )::bigint,
         coalesce(
           sum(cee.amount_cents) filter (where cee.payment_status = 'SCHEDULED'),
           0
         )::bigint
    into v_das_paid_cents,
         v_expenses_paid_non_das_cents,
         v_expenses_scheduled_cents
    from private.ceo_expense_entries cee;

  v_das_unpaid_provision_cents := greatest(0::bigint, v_cum_das_6pct_cents - v_das_paid_cents);

  select coalesce(
           sum(cpd.settled_cents) filter (
             where cpd.status in ('SETTLED_SANDBOX', 'SETTLED_PRODUCTION')
               and cpd.is_duress_decoy = false
               and cpd.operating_mode = cfg.operating_mode
               and cpd.distribution_kind in ('PROFIT_DISTRIBUTION', 'PRO_LABORE')
           ),
           0
         )::bigint,
         coalesce(
           sum(cpd.requested_cents) filter (
             where cpd.status = 'PREPARED'
               and cpd.is_duress_decoy = false
               and cpd.operating_mode = cfg.operating_mode
           ),
           0
         )::bigint,
         count(*) filter (
           where cpd.status = 'SETTLED_SANDBOX'
             and cpd.is_duress_decoy = false
         )::integer
    into v_prior_settled_dist_cents,
         v_inflight_prepared_dist_cents,
         v_sandbox_payouts_tested_count
    from private.ceo_profit_distributions cpd;

  -- 5) Vigilância Anti-Coação e Segurança
  select count(*) filter (where jb_s.escrow_status = 'FROZEN_UNDER_DURESS')::integer,
         case
           when count(*) > 0 then
             ((count(*) filter (
               where jb_s.latitude is not null
                  or jb_s.longitude is not null
                  or jb_s.address_cep is not null
             ) * 10000) / count(*))::integer
           else 0
         end
    into v_duress_jobs_count,
         v_geo_leak_bps
    from public.jobs jb_s;

  v_is_duress_frozen := (cfg.duress_mode_status = 'FROZEN_UNDER_DURESS' or v_duress_jobs_count > 0);
  v_audit_chain_ok := private.verify_founder_audit_chain();

  -- 6) Equação Canônica de Teto Seguro (`WithdrawableProfitCents`)
  v_raw_surplus_cents :=
    v_cum_platform_gross_rev_cents
    - greatest(v_cum_das_6pct_cents, v_das_paid_cents)
    - v_expenses_paid_non_das_cents
    - v_expenses_scheduled_cents
    - v_prior_settled_dist_cents
    - v_inflight_prepared_dist_cents
    - cfg.safety_buffer_cents;

  if v_is_duress_frozen then
    v_withdrawable_profit_cents := 0;
    v_blocked_reason := 'FROZEN_UNDER_DURESS';
  elsif v_recon_discrepancy_cents > 0 then
    v_withdrawable_profit_cents := 0;
    v_blocked_reason := 'THREE_WAY_RECONCILIATION_DRIFT';
  elsif not v_audit_chain_ok then
    v_withdrawable_profit_cents := 0;
    v_blocked_reason := 'WORM_AUDIT_CHAIN_ALERT';
  elsif v_raw_surplus_cents <= 0 then
    v_withdrawable_profit_cents := 0;
    v_blocked_reason := 'BELOW_SAFETY_BUFFER';
  else
    v_withdrawable_profit_cents := v_raw_surplus_cents;
    v_blocked_reason := 'NONE';
  end if;

  with recent_d as (
    select cpd_r.id,
           cpd_r.distribution_kind,
           cpd_r.operating_mode,
           cpd_r.psp_provider,
           cpd_r.requested_cents,
           cpd_r.settled_cents,
           cpd_r.status,
           cpd_r.psp_transfer_id,
           cpd_r.receipt_sha256,
           cpd_r.created_at
      from private.ceo_profit_distributions cpd_r
     where cpd_r.is_duress_decoy = false
     order by cpd_r.created_at desc
     limit 12
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', rd.id,
               'distribution_kind', rd.distribution_kind,
               'operating_mode', rd.operating_mode,
               'psp_provider', rd.psp_provider,
               'requested_cents', rd.requested_cents,
               'settled_cents', rd.settled_cents,
               'status', rd.status,
               'psp_transfer_id', rd.psp_transfer_id,
               'receipt_sha256', rd.receipt_sha256,
               'created_at', rd.created_at
             )
             order by rd.created_at desc
           ),
           '[]'::jsonb
         )
    into v_recent_distributions
    from recent_d rd;

  -- 7) Semáforo Real-Time dos 4 Critérios Objetivos ("Sinal Verde" SLU Poços de Caldas - MG)
  if v_recon_discrepancy_cents = 0 and v_audit_chain_ok then
    v_zero_drift_days_elapsed := greatest(
      0,
      floor(extract(epoch from (now() - cfg.sandbox_zero_drift_since)) / 86400.0)::integer
    );
  else
    v_zero_drift_days_elapsed := 0;
  end if;

  select count(*) filter (
           where coalesce(prof_p.is_provider, false) = true
             and translate(lower(coalesce(prof_p.address_city, '')), 'çáàâãéêíóôõú', 'caaaaeeiooou') like '%pocos de caldas%'
         )::integer,
         count(*) filter (
           where coalesce(prof_p.is_provider, false) = true
             and prof_p.verification_status = 'ACTIVE'
             and translate(lower(coalesce(prof_p.address_city, '')), 'çáàâãéêíóôõú', 'caaaaeeiooou') like '%pocos de caldas%'
         )::integer
    into v_pocos_providers_total_count,
         v_pocos_providers_active_count
    from public.profiles prof_p;

  select count(distinct lma_c.user_id)::integer,
         count(distinct lma_c.user_id) filter (where lma_c.role_scope in ('PROVIDER', 'DUAL_MODE'))::integer
    into v_mandate_accepted_users_count,
         v_mandate_providers_count
    from public.legal_mandate_acceptances lma_c;

  v_crit1_stability_7d_ok := (v_recon_discrepancy_cents = 0 and v_audit_chain_ok and v_zero_drift_days_elapsed >= 7);
  v_crit2_p0_p1_zeroed_ok := (
    v_recon_discrepancy_cents = 0
    and v_audit_chain_ok
    and v_geo_leak_bps = 0
    and to_regprocedure('private.ceo_compute_pin_sha256(text,text)') is null
    and to_regprocedure('private.ceo_compute_otp_sha256(text,text,uuid,text)') is null
  );
  v_crit3_pocos_liquidity_ok := (v_pocos_providers_total_count >= 15);
  v_crit4_takeoff_reserve_ok := (cfg.takeoff_reserve_saved_cents >= 100000);

  return jsonb_build_object(
    'bivalent_treasury', jsonb_build_object(
      'operating_mode', cfg.operating_mode,
      'settlement_psp', cfg.settlement_psp,
      'slu_legal_name', cfg.slu_legal_name,
      'slu_cnpj_configured', (cfg.slu_cnpj_digits is not null),
      'sole_partner_cpf_configured', (cfg.sole_partner_cpf_digits is not null),
      'cnae_primary', cfg.cnae_primary,
      'cnae_secondary', cfg.cnae_secondary,
      'beneficiary_full_name', dest.beneficiary_full_name,
      'destination_lock_mode', dest.destination_lock_mode,
      'allow_typed_pix_keys', dest.allow_typed_pix_keys,
      'bank_display_label', dest.bank_display_label,
      'duress_mode_status', case when v_is_duress_frozen then 'FROZEN_UNDER_DURESS' else 'NORMAL' end,
      'cumulative_platform_revenue_13_5_cents', v_cum_platform_gross_rev_cents,
      'untouchable_custody_total_cents', v_untouchable_custody_cents,
      'provider_custody_85_cents', (v_provider_wallets_avail_cents + v_provider_maturing_cents),
      'client_escrow_and_wallets_cents', v_client_wallets_total_cents,
      'active_execution_escrow_cents', v_active_escrow_jobs_cents,
      'materials_exempt_0pct_cents', v_cum_exempt_materials_cents,
      'warranty_pool_1_5_cents', v_warranty_pool_balance_cents,
      'das_6pct_unpaid_provision_cents', v_das_unpaid_provision_cents,
      'das_6pct_paid_cents', v_das_paid_cents,
      'corporate_expenses_paid_cents', v_expenses_paid_non_das_cents,
      'corporate_expenses_scheduled_cents', v_expenses_scheduled_cents,
      'prior_distributions_cents', (v_prior_settled_dist_cents + v_inflight_prepared_dist_cents),
      'safety_buffer_cents', cfg.safety_buffer_cents,
      'withdrawable_profit_cents', v_withdrawable_profit_cents,
      'reconciliation_discrepancy_cents', v_recon_discrepancy_cents,
      'blocked_reason', v_blocked_reason,
      'recent_distributions', v_recent_distributions
    ),
    'slu_go_live_semaphore', jsonb_build_object(
      'operating_mode', cfg.operating_mode,
      'all_four_criteria_green', (
        v_crit1_stability_7d_ok
        and v_crit2_p0_p1_zeroed_ok
        and v_crit3_pocos_liquidity_ok
        and v_crit4_takeoff_reserve_ok
      ),
      'criteria_green_count', (
        (case when v_crit1_stability_7d_ok then 1 else 0 end)
        + (case when v_crit2_p0_p1_zeroed_ok then 1 else 0 end)
        + (case when v_crit3_pocos_liquidity_ok then 1 else 0 end)
        + (case when v_crit4_takeoff_reserve_ok then 1 else 0 end)
      ),
      'criterion_1_stability_7d_ok', v_crit1_stability_7d_ok,
      'zero_drift_days_elapsed', v_zero_drift_days_elapsed,
      'zero_drift_target_days', 7,
      'sandbox_payouts_tested_count', v_sandbox_payouts_tested_count,
      'criterion_2_p0_p1_zeroed_ok', v_crit2_p0_p1_zeroed_ok,
      'criterion_3_pocos_liquidity_ok', v_crit3_pocos_liquidity_ok,
      'pocos_providers_total_count', v_pocos_providers_total_count,
      'pocos_providers_active_count', v_pocos_providers_active_count,
      'pocos_providers_min_target', 15,
      'pocos_providers_ideal_target', cfg.pocos_providers_target,
      'criterion_4_takeoff_reserve_ok', v_crit4_takeoff_reserve_ok,
      'takeoff_reserve_saved_cents', cfg.takeoff_reserve_saved_cents,
      'takeoff_reserve_min_cents', 100000,
      'takeoff_reserve_target_cents', cfg.takeoff_reserve_target_cents,
      'legal_mandate_accepted_users_count', v_mandate_accepted_users_count,
      'legal_mandate_providers_count', v_mandate_providers_count
    )
  );
end $$;

revoke all on function private.ceo_compute_safe_treasury_state() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 7. RPC Executiva de Governança de Parâmetros da Tesouraria Bivalente & Semáforo
-- -----------------------------------------------------------------------------
create or replace function public.ceo_configure_treasury_parameters(
  p_stepup_token text,
  p_device_hash text,
  p_safety_buffer_cents bigint default null,
  p_takeoff_reserve_saved_cents bigint default null,
  p_pocos_providers_target integer default null,
  p_duress_mode_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid         uuid;
  v_duress_norm text := upper(btrim(coalesce(p_duress_mode_status, '')));
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);
  perform pg_advisory_xact_lock(90219001);

  if p_safety_buffer_cents is not null and (p_safety_buffer_cents < 0 or p_safety_buffer_cents > 1000000000) then
    raise exception 'ERR_INVALID_SAFETY_BUFFER_CENTS' using errcode = '22023';
  end if;

  if p_takeoff_reserve_saved_cents is not null and (p_takeoff_reserve_saved_cents < 0 or p_takeoff_reserve_saved_cents > 100000000) then
    raise exception 'ERR_INVALID_TAKEOFF_RESERVE_CENTS' using errcode = '22023';
  end if;

  if p_pocos_providers_target is not null and (p_pocos_providers_target < 15 or p_pocos_providers_target > 100) then
    raise exception 'ERR_INVALID_POCOS_TARGET' using errcode = '22023';
  end if;

  if v_duress_norm <> '' and v_duress_norm not in ('NORMAL', 'FROZEN_UNDER_DURESS') then
    raise exception 'ERR_INVALID_DURESS_MODE_STATUS' using errcode = '22023';
  end if;

  update private.ceo_treasury_config
     set safety_buffer_cents = coalesce(p_safety_buffer_cents, safety_buffer_cents),
         takeoff_reserve_saved_cents = coalesce(p_takeoff_reserve_saved_cents, takeoff_reserve_saved_cents),
         pocos_providers_target = coalesce(p_pocos_providers_target, pocos_providers_target),
         duress_mode_status = case when v_duress_norm <> '' then v_duress_norm else duress_mode_status end,
         duress_triggered_at = case
           when v_duress_norm = 'FROZEN_UNDER_DURESS' then now()
           when v_duress_norm = 'NORMAL' then null
           else duress_triggered_at
         end,
         updated_at = now()
   where singleton_id = true;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    case
      when v_duress_norm = 'FROZEN_UNDER_DURESS' then 'CEO_TREASURY_DURESS_LOCK_ENGAGED'
      else 'CEO_TREASURY_PARAMETERS_UPDATED'
    end,
    case when v_duress_norm = 'FROZEN_UNDER_DURESS' then 'CRITICAL' else 'INFO' end,
    (v_duress_norm = 'FROZEN_UNDER_DURESS'),
    jsonb_build_object(
      'safety_buffer_cents', p_safety_buffer_cents,
      'takeoff_reserve_saved_cents', p_takeoff_reserve_saved_cents,
      'pocos_providers_target', p_pocos_providers_target,
      'duress_mode_status', nullif(v_duress_norm, '')
    )
  );

  perform private.emit_ceo_live_event_safe(
    'CEO_TREASURY_CONFIG_SYNC',
    case when v_duress_norm = 'FROZEN_UNDER_DURESS' then 'CRITICAL' else 'INFO' end,
    'Parâmetros da Tesouraria atualizados',
    'Sincronizado em tempo real com o Cofre Bivalente',
    'ceo_treasury_config',
    'singleton',
    coalesce(p_takeoff_reserve_saved_cents, p_safety_buffer_cents, 0),
    '{}'::jsonb
  );

  return jsonb_build_object('ok', true) || private.ceo_compute_safe_treasury_state();
end $$;

revoke all on function public.ceo_configure_treasury_parameters(text, text, bigint, bigint, integer, text) from public, anon;
grant execute on function public.ceo_configure_treasury_parameters(text, text, bigint, bigint, integer, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 8. Destravamento Cirúrgico do Dia `D-5` (`SANDBOX_PRE_CNPJ` -> `PRODUCTION_SLU`)
--    Exclusivo do esquema `private` / `service_role` (NUNCA exposto a `anon`/`authenticated`)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_activate_production_slu_mode(
  p_slu_cnpj text,
  p_sole_partner_cpf text,
  p_slu_legal_name text,
  p_municipal_registration_pocos text,
  p_settlement_psp text,
  p_bank_ispb text default '00416968',
  p_bank_display_label text default 'Conta Pessoa Física Sócio Único (Travada por CPF)'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_cnpj  text := regexp_replace(coalesce(p_slu_cnpj, ''), '[^0-9]', '', 'g');
  v_cpf   text := regexp_replace(coalesce(p_sole_partner_cpf, ''), '[^0-9]', '', 'g');
  v_psp   text := upper(btrim(coalesce(p_settlement_psp, '')));
  v_ispb  text := regexp_replace(coalesce(p_bank_ispb, ''), '[^0-9]', '', 'g');
  v_state jsonb;
  v_owner uuid;
begin
  perform pg_advisory_xact_lock(90219001);

  if not private.is_valid_cnpj_mod11(v_cnpj) then
    raise exception 'ERR_INVALID_SLU_CNPJ_MOD11: CNPJ inválido pelos dígitos verificadores Módulo 11.'
      using errcode = '22023';
  end if;

  if not private.is_valid_cpf_mod11(v_cpf) then
    raise exception 'ERR_INVALID_PARTNER_CPF_MOD11: CPF do sócio único inválido pelos dígitos verificadores Módulo 11.'
      using errcode = '22023';
  end if;

  if v_psp not in ('ASAAS_PRODUCTION', 'INTER_MTLS_PRODUCTION', 'EFI_MTLS_PRODUCTION') then
    raise exception 'ERR_PRODUCTION_PSP_REQUIRED: Selecione um adaptador de produção válido (Asaas, Inter mTLS ou Efí mTLS).'
      using errcode = '22023';
  end if;

  if v_ispb !~ '^[0-9]{8}$' then
    raise exception 'ERR_INVALID_BANK_ISPB: Código ISPB deve conter 8 dígitos.'
      using errcode = '22023';
  end if;

  v_state := private.ceo_compute_safe_treasury_state();
  if ((v_state #>> '{bivalent_treasury,reconciliation_discrepancy_cents}')::bigint) <> 0 then
    raise exception 'ERR_RECONCILIATION_DRIFT_BLOCKS_SLU_UNLOCK: Desvio diferente de zero na conciliação tripla.'
      using errcode = 'P0001';
  end if;

  if (v_state #>> '{bivalent_treasury,duress_mode_status}') = 'FROZEN_UNDER_DURESS' then
    raise exception 'ERR_DURESS_ACTIVE_BLOCKS_SLU_UNLOCK: Cofre sob bloqueio anti-coação.'
      using errcode = '42501';
  end if;

  update private.ceo_payout_destinations
     set bank_ispb = v_ispb,
         bank_display_label = left(btrim(coalesce(nullif(p_bank_display_label, ''), 'Conta Pessoa Física Sócio Único')), 120),
         allow_typed_pix_keys = false,
         locked_at = now()
   where singleton_id = true;

  update private.ceo_treasury_config
     set operating_mode = 'PRODUCTION_SLU',
         slu_cnpj_digits = v_cnpj,
         sole_partner_cpf_digits = v_cpf,
         slu_legal_name = left(btrim(coalesce(nullif(p_slu_legal_name, ''), 'DESPERRENGUE INTERMEDIACAO DIGITAL LTDA')), 140),
         municipal_registration_pocos = nullif(btrim(coalesce(p_municipal_registration_pocos, '')), ''),
         settlement_psp = v_psp,
         production_unlocked_at = now(),
         updated_at = now()
   where singleton_id = true;

  select csv.owner_user_id into v_owner from private.ceo_sovereign_vault csv where csv.singleton_id = true;
  if v_owner is not null then
    perform private.record_founder_audit_event(
      v_owner,
      v_owner,
      'CEO_SLU_PRODUCTION_MODE_UNLOCKED',
      'CRITICAL',
      false,
      jsonb_build_object(
        'operating_mode', 'PRODUCTION_SLU',
        'cnpj_prefix', left(v_cnpj, 8),
        'settlement_psp', v_psp,
        'bank_ispb', v_ispb
      )
    );
  end if;

  return jsonb_build_object('ok', true, 'operating_mode', 'PRODUCTION_SLU');
end $$;

revoke all on function private.ceo_activate_production_slu_mode(text, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.ceo_activate_production_slu_mode(text, text, text, text, text, text, text) to service_role;

-- -----------------------------------------------------------------------------
-- 9. RPCs Internas `service_role` para `ceo-treasury-authority` e `asaas-webhook-guard`
--    - Zero parâmetro de chave PIX (destino 100% lido do cofre `private.ceo_payout_destinations`)
--    - `pg_advisory_xact_lock` contra race condition / double-spend (`TOCTOU`)
--    - Comprovante Falso Convincente Silencioso em `FROZEN_UNDER_DURESS` (`settled_cents = 0`)
-- -----------------------------------------------------------------------------
create or replace function public.ceo_edge_prepare_profit_distribution(
  p_actor_uid uuid,
  p_stepup_token text,
  p_device_hash text,
  p_idempotency_key text,
  p_distribution_kind text,
  p_requested_cents bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid          uuid;
  v_idem         text := btrim(coalesce(p_idempotency_key, ''));
  v_kind         text := upper(btrim(coalesce(p_distribution_kind, 'PROFIT_DISTRIBUTION')));
  cfg            private.ceo_treasury_config%rowtype;
  dest           private.ceo_payout_destinations%rowtype;
  existing_row   private.ceo_profit_distributions%rowtype;
  v_state        jsonb;
  v_bt           jsonb;
  v_ceiling      bigint;
  v_is_duress    boolean;
  v_dist_id      uuid;
  v_receipt_hash char(64);
  v_fake_tx      text;
begin
  v_uid := private.validate_ceo_stepup_session_for_edge(p_actor_uid, p_stepup_token, p_device_hash);

  -- Serialização estrita de todas as retiradas da tesouraria (Zero TOCTOU / Double-Spend)
  perform pg_advisory_xact_lock(90219001);

  if char_length(v_idem) < 12 or char_length(v_idem) > 128 or v_idem !~ '^[A-Za-z0-9_\-:.]+$' then
    raise exception 'ERR_INVALID_IDEMPOTENCY_KEY' using errcode = '22023';
  end if;

  if v_kind not in ('PROFIT_DISTRIBUTION', 'PRO_LABORE', 'TAX_DAS_SETTLEMENT') then
    raise exception 'ERR_INVALID_DISTRIBUTION_KIND' using errcode = '22023';
  end if;

  if p_requested_cents is null or p_requested_cents <= 0 or p_requested_cents > 1000000000 then
    raise exception 'ERR_INVALID_REQUESTED_AMOUNT_CENTS' using errcode = '22023';
  end if;

  -- Idempotência estrita: mesma chave retorna exatamente a decisão original sem duplicar saque
  select * into existing_row from private.ceo_profit_distributions where idempotency_key = v_idem;
  if found then
    return jsonb_build_object(
      'ok', (existing_row.status <> 'REJECTED'),
      'idempotent_replay', true,
      'distribution_id', existing_row.id,
      'operating_mode', existing_row.operating_mode,
      'psp_provider', existing_row.psp_provider,
      'status_internal', existing_row.status,
      'is_duress_decoy', existing_row.is_duress_decoy,
      'requested_cents', existing_row.requested_cents,
      'settled_cents', existing_row.settled_cents,
      'psp_transfer_id', existing_row.psp_transfer_id,
      'receipt_sha256', existing_row.receipt_sha256,
      'beneficiary_full_name', 'Wagner Oliveira',
      'created_at', existing_row.created_at
    );
  end if;

  select * into cfg from private.ceo_treasury_config where singleton_id = true;
  select * into dest from private.ceo_payout_destinations where singleton_id = true;

  v_state := private.ceo_compute_safe_treasury_state();
  v_bt := v_state -> 'bivalent_treasury';
  v_ceiling := (v_bt ->> 'withdrawable_profit_cents')::bigint;
  v_is_duress := ((v_bt ->> 'duress_mode_status') = 'FROZEN_UNDER_DURESS');

  -- MODO ANTI-COAÇÃO SILENCIOSO: gera recibo sintético crível com `settled_cents = 0` (nenhum centavo sai!)
  if v_is_duress then
    v_fake_tx := 'E' || cfg.cnae_primary || to_char(now() at time zone 'UTC', 'YYYYMMDDHH24MISS')
                 || upper(substr(encode(extensions.digest(convert_to(v_idem || ':DECOY', 'UTF8'), 'sha256'), 'hex'), 1, 11));
    v_fake_tx := regexp_replace(v_fake_tx, '[^A-Za-z0-9]', '', 'g');
    v_receipt_hash := lower(encode(
      extensions.digest(convert_to('DECOY_RECEIPT:' || v_idem || ':' || p_requested_cents::text || ':' || now()::text, 'UTF8'), 'sha256'),
      'hex'
    ))::char(64);

    insert into private.ceo_profit_distributions (
      idempotency_key,
      distribution_kind,
      operating_mode,
      psp_provider,
      requested_cents,
      settled_cents,
      is_duress_decoy,
      status,
      psp_transfer_id,
      ceiling_snapshot,
      receipt_sha256,
      created_by,
      finalized_at
    ) values (
      v_idem,
      v_kind,
      cfg.operating_mode,
      cfg.settlement_psp,
      p_requested_cents,
      0,
      true,
      'DECOY_FROZEN_ZERO_MOVED',
      v_fake_tx,
      v_bt,
      v_receipt_hash,
      v_uid,
      now()
    )
    returning id into v_dist_id;

    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_TREASURY_DURESS_DECOY_ISSUED',
      'CRITICAL',
      true,
      jsonb_build_object(
        'distribution_id', v_dist_id,
        'requested_cents', p_requested_cents,
        'real_settled_cents', 0
      )
    );

    return jsonb_build_object(
      'ok', true,
      'idempotent_replay', false,
      'distribution_id', v_dist_id,
      'operating_mode', cfg.operating_mode,
      'psp_provider', cfg.settlement_psp,
      'status_internal', 'DECOY_FROZEN_ZERO_MOVED',
      'is_duress_decoy', true,
      'requested_cents', p_requested_cents,
      'settled_cents', 0,
      'psp_transfer_id', v_fake_tx,
      'receipt_sha256', v_receipt_hash,
      'beneficiary_full_name', dest.beneficiary_full_name,
      'created_at', now()
    );
  end if;

  -- Trava Matemática Intransponível de Teto Seguro (`85%` prestadores + `1,5%` garantia + `6%` DAS + despesas + buffer)
  if p_requested_cents > v_ceiling then
    raise exception 'ERR_SAFE_CEILING_EXCEEDED: Solicitado (%) excede o Teto Seguro retirável (%) ou há bloqueio (%). Custódia de prestadores (85%%) e garantia (1,5%%) são intocáveis.',
      p_requested_cents, v_ceiling, coalesce(v_bt ->> 'blocked_reason', 'CEILING')
      using errcode = 'P0001';
  end if;

  v_receipt_hash := lower(encode(
    extensions.digest(
      convert_to('TREASURY_PREP:' || v_idem || ':' || cfg.operating_mode || ':' || p_requested_cents::text || ':' || v_uid::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  ))::char(64);

  if cfg.operating_mode = 'SANDBOX_PRE_CNPJ' then
    v_fake_tx := 'SANDBOX-PIX-' || to_char(now() at time zone 'UTC', 'YYYYMMDDHH24MISS') || '-' || upper(left(v_receipt_hash, 8));
    insert into private.ceo_profit_distributions (
      idempotency_key,
      distribution_kind,
      operating_mode,
      psp_provider,
      requested_cents,
      settled_cents,
      is_duress_decoy,
      status,
      psp_transfer_id,
      ceiling_snapshot,
      receipt_sha256,
      created_by,
      finalized_at
    ) values (
      v_idem,
      v_kind,
      'SANDBOX_PRE_CNPJ',
      cfg.settlement_psp,
      p_requested_cents,
      p_requested_cents,
      false,
      'SETTLED_SANDBOX',
      v_fake_tx,
      v_bt,
      v_receipt_hash,
      v_uid,
      now()
    )
    returning id into v_dist_id;

    perform private.record_founder_audit_event(
      v_uid,
      v_uid,
      'CEO_SANDBOX_PROFIT_DISTRIBUTION_TESTED',
      'INFO',
      false,
      jsonb_build_object(
        'distribution_id', v_dist_id,
        'kind', v_kind,
        'settled_cents', p_requested_cents,
        'remaining_ceiling_cents', (v_ceiling - p_requested_cents)
      )
    );

    perform private.emit_ceo_live_event_safe(
      'CEO_PROFIT_DISTRIBUTION_SANDBOX',
      'SUCCESS',
      'Retirada homologada em Sandbox Pré-CNPJ',
      dest.beneficiary_full_name || ' · Teto respeitado com 0 desvio',
      'ceo_profit_distributions',
      v_dist_id::text,
      p_requested_cents,
      jsonb_build_object('mode', 'SANDBOX_PRE_CNPJ', 'kind', v_kind)
    );

    return jsonb_build_object(
      'ok', true,
      'idempotent_replay', false,
      'distribution_id', v_dist_id,
      'operating_mode', 'SANDBOX_PRE_CNPJ',
      'psp_provider', cfg.settlement_psp,
      'status_internal', 'SETTLED_SANDBOX',
      'is_duress_decoy', false,
      'requested_cents', p_requested_cents,
      'settled_cents', p_requested_cents,
      'psp_transfer_id', v_fake_tx,
      'receipt_sha256', v_receipt_hash,
      'beneficiary_full_name', dest.beneficiary_full_name,
      'sole_partner_cpf_digits', cfg.sole_partner_cpf_digits,
      'bank_ispb', dest.bank_ispb,
      'created_at', now()
    );
  end if;

  -- `PRODUCTION_SLU`: reserva o valor em `PREPARED` para liquidação externa mTLS 1.3 / Asaas Prod
  insert into private.ceo_profit_distributions (
    idempotency_key,
    distribution_kind,
    operating_mode,
    psp_provider,
    requested_cents,
    settled_cents,
    is_duress_decoy,
    status,
    ceiling_snapshot,
    receipt_sha256,
    created_by
  ) values (
    v_idem,
    v_kind,
    'PRODUCTION_SLU',
    cfg.settlement_psp,
    p_requested_cents,
    0,
    false,
    'PREPARED',
    v_bt,
    v_receipt_hash,
    v_uid
  )
  returning id into v_dist_id;

  return jsonb_build_object(
    'ok', true,
    'idempotent_replay', false,
    'distribution_id', v_dist_id,
    'operating_mode', 'PRODUCTION_SLU',
    'psp_provider', cfg.settlement_psp,
    'status_internal', 'PREPARED',
    'is_duress_decoy', false,
    'requested_cents', p_requested_cents,
    'settled_cents', 0,
    'receipt_sha256', v_receipt_hash,
    'beneficiary_full_name', dest.beneficiary_full_name,
    'sole_partner_cpf_digits', cfg.sole_partner_cpf_digits,
    'slu_cnpj_digits', cfg.slu_cnpj_digits,
    'bank_ispb', dest.bank_ispb,
    'created_at', now()
  );
end $$;

revoke all on function public.ceo_edge_prepare_profit_distribution(uuid, text, text, text, text, bigint) from public, anon, authenticated;
grant execute on function public.ceo_edge_prepare_profit_distribution(uuid, text, text, text, text, bigint) to service_role;

create or replace function public.ceo_edge_finalize_profit_distribution(
  p_distribution_id uuid,
  p_succeeded boolean,
  p_psp_transfer_id text default null,
  p_failure_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  row_d private.ceo_profit_distributions%rowtype;
begin
  perform pg_advisory_xact_lock(90219001);

  select * into row_d from private.ceo_profit_distributions where id = p_distribution_id for update;
  if not found then
    raise exception 'ERR_DISTRIBUTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  if row_d.status <> 'PREPARED' then
    return jsonb_build_object('ok', true, 'already_finalized', true, 'status', row_d.status);
  end if;

  if p_succeeded then
    update private.ceo_profit_distributions
       set status = 'SETTLED_PRODUCTION',
           settled_cents = row_d.requested_cents,
           psp_transfer_id = left(btrim(coalesce(p_psp_transfer_id, 'PSP-OK')), 120),
           finalized_at = now()
     where id = p_distribution_id;

    perform private.record_founder_audit_event(
      row_d.created_by,
      row_d.created_by,
      'CEO_PRODUCTION_PROFIT_DISTRIBUTION_SETTLED',
      'INFO',
      false,
      jsonb_build_object(
        'distribution_id', p_distribution_id,
        'settled_cents', row_d.requested_cents,
        'psp_transfer_id', p_psp_transfer_id
      )
    );
  else
    update private.ceo_profit_distributions
       set status = 'REJECTED',
           settled_cents = 0,
           psp_transfer_id = left(btrim(coalesce(p_failure_reason, 'PSP_REJECTED')), 120),
           finalized_at = now()
     where id = p_distribution_id;

    perform private.record_founder_audit_event(
      row_d.created_by,
      row_d.created_by,
      'CEO_PRODUCTION_PROFIT_DISTRIBUTION_REJECTED',
      'WARN',
      false,
      jsonb_build_object(
        'distribution_id', p_distribution_id,
        'reason', left(coalesce(p_failure_reason, 'PSP_ERROR'), 120)
      )
    );
  end if;

  return jsonb_build_object('ok', true, 'succeeded', p_succeeded);
end $$;

revoke all on function public.ceo_edge_finalize_profit_distribution(uuid, boolean, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_finalize_profit_distribution(uuid, boolean, text, text) to service_role;

-- Guardião Outbound Asaas (`asaas-webhook-guard` -> responde `APPROVED` ou `REFUSED` em <50ms)
create or replace function public.ceo_edge_authorize_asaas_webhook_transfer(
  p_event_id text,
  p_event_type text,
  p_transfer_id text,
  p_amount_cents bigint,
  p_target_cpf_cnpj text,
  p_external_reference text,
  p_payload_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ev_id       text := btrim(coalesce(p_event_id, ''));
  v_ev_type     text := upper(btrim(coalesce(p_event_type, 'TRANSFER_VALIDATION')));
  v_target_doc  text := regexp_replace(coalesce(p_target_cpf_cnpj, ''), '[^0-9]', '', 'g');
  v_sha         text := lower(btrim(coalesce(p_payload_sha256, '')));
  prev_ev       private.ceo_webhook_processed_events%rowtype;
  cfg           private.ceo_treasury_config%rowtype;
  v_state       jsonb;
  v_bt          jsonb;
  v_decision    text := 'REFUSED';
  v_reason      text := 'Bloqueio preventivo de segurança da tesouraria.';
  v_owner       uuid;
  v_matched_row private.ceo_profit_distributions%rowtype;
begin
  perform pg_advisory_xact_lock(90219002);

  if char_length(v_ev_id) < 4 or char_length(v_ev_id) > 160 or v_sha !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'REFUSED', 'refuseReason', 'Payload ou identificador de webhook inválido.');
  end if;

  -- Proteção contra Replay Attack: se o `event_id` já foi processado, recusa reexecução
  select * into prev_ev from private.ceo_webhook_processed_events where event_id = v_ev_id;
  if found then
    return jsonb_build_object(
      'status', 'REFUSED',
      'refuseReason', 'Evento duplicado bloqueado por proteção anti-replay.',
      'replayed', true
    );
  end if;

  select * into cfg from private.ceo_treasury_config where singleton_id = true;
  select csv.owner_user_id into v_owner from private.ceo_sovereign_vault csv where csv.singleton_id = true;
  v_state := private.ceo_compute_safe_treasury_state();
  v_bt := v_state -> 'bivalent_treasury';

  -- Regra 1: Coação ativa (`FROZEN_UNDER_DURESS`) -> RECUSA 100% IMEDIATA NO ASAAS!
  if (v_bt ->> 'duress_mode_status') = 'FROZEN_UNDER_DURESS' then
    v_decision := 'REFUSED';
    v_reason := 'Transação retida pela política de conformidade da conta.';
  -- Regra 2: Desvio de conciliação tripla
  elsif ((v_bt ->> 'reconciliation_discrepancy_cents')::bigint) <> 0 then
    v_decision := 'REFUSED';
    v_reason := 'Conciliação contábil pendente de verificação.';
  -- Regra 3: Valor inválido
  elsif p_amount_cents is null or p_amount_cents <= 0 then
    v_decision := 'REFUSED';
    v_reason := 'Valor de transferência inválido.';
  else
    -- Verifica vínculo estrito a uma distribuição preparada pelo CEO ou titularidade CPF/CNPJ travada
    if p_external_reference is not null and p_external_reference ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select *
        into v_matched_row
        from private.ceo_profit_distributions cpd
       where cpd.id = p_external_reference::uuid
         and cpd.is_duress_decoy = false
         and cpd.status in ('PREPARED', 'SETTLED_SANDBOX', 'SETTLED_PRODUCTION')
         and cpd.requested_cents = p_amount_cents;
    end if;

    if v_matched_row.id is null then
      v_decision := 'REFUSED';
      v_reason := 'Saque sem ordem soberana preparada no Cofre do CEO.';
    elsif cfg.operating_mode = 'PRODUCTION_SLU'
          and (v_target_doc = '' or v_target_doc is distinct from cfg.sole_partner_cpf_digits) then
      v_decision := 'REFUSED';
      v_reason := 'Destino divergente do CPF titular único travado em banco.';
    else
      v_decision := 'APPROVED';
      v_reason := null;
    end if;
  end if;

  insert into private.ceo_webhook_processed_events (
    event_id,
    provider,
    event_type,
    decision,
    refuse_reason,
    amount_cents,
    payload_sha256
  ) values (
    v_ev_id,
    'ASAAS',
    v_ev_type,
    v_decision,
    v_reason,
    coalesce(p_amount_cents, 0),
    v_sha::char(64)
  );

  if v_decision = 'REFUSED' and v_owner is not null then
    perform private.record_founder_audit_event(
      v_owner,
      v_owner,
      'ASAAS_WEBHOOK_OUTBOUND_TRANSFER_REFUSED',
      'CRITICAL',
      true,
      jsonb_build_object(
        'event_id', v_ev_id,
        'transfer_id', p_transfer_id,
        'amount_cents', p_amount_cents,
        'reason', v_reason
      )
    );
  end if;

  if v_decision = 'APPROVED' then
    return jsonb_build_object('status', 'APPROVED');
  end if;

  return jsonb_build_object(
    'status', 'REFUSED',
    'refuseReason', coalesce(v_reason, 'Operação recusada pelo guardião de tesouraria.')
  );
end $$;

revoke all on function public.ceo_edge_authorize_asaas_webhook_transfer(text, text, text, bigint, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_authorize_asaas_webhook_transfer(text, text, text, bigint, text, text, text) to service_role;

-- -----------------------------------------------------------------------------
-- 10. Unificação Financeira e Anti-Coação no App Público `Desperrengue`
--     - `gen_job_pin`: CSPRNG de 4 dígitos garantidamente não-palíndromo (`reverse(pin) <> pin`)
--     - `pay_job_mock` & `request_emergency_mock`: Split Canônico `85% / 13,5% / 1,5%` + `0%` NF-e
--     - `complete_job_with_pin`: Liquidação Real + **PIN Invertido Silencioso (`FROZEN_UNDER_DURESS`)**
-- -----------------------------------------------------------------------------
create or replace function public.gen_job_pin(p_job uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_raw integer;
  v_pin text;
  v_try integer := 0;
begin
  loop
    v_try := v_try + 1;
    v_raw := (get_byte(extensions.gen_random_bytes(2), 0) * 256
              + get_byte(extensions.gen_random_bytes(2), 1)) % 10000;
    v_pin := lpad(v_raw::text, 4, '0');
    -- Garante que `reverse(v_pin) <> v_pin` para que 100% dos PINs tenham código reverso anti-coação distinto!
    exit when reverse(v_pin) <> v_pin or v_try >= 25;
  end loop;

  if reverse(v_pin) = v_pin then
    v_pin := '4829';
  end if;

  insert into public.job_secrets (job_id, pin)
  values (p_job, v_pin)
  on conflict (job_id) do nothing;
end $$;

revoke all on function public.gen_job_pin(uuid) from public, anon, authenticated;

create or replace function public.pay_job_mock(
  p_job_id uuid,
  p_method text,
  p_scheduled_for timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  j                 public.jobs%rowtype;
  v_id              uuid;
  v_covered_mat     numeric(12,2) := 0.00;
  v_exempt_mat      numeric(12,2) := 0.00;
  v_fee_base        numeric(12,2);
  v_fee             numeric(12,2);
  c_pct    constant numeric := 15.00; -- 13,5% intermediação + 1,5% reserva de garantia 90d
begin
  if p_method not in ('wallet', 'pix', 'credit_card', 'debit_card') then
    raise exception 'Método de pagamento inválido.' using errcode = '22023';
  end if;

  select * into j from public.jobs where id = p_job_id and client_id = auth.uid() for update;
  if not found or j.status <> 'awaiting_payment' or j.agreed_price is null then
    raise exception 'Demanda não está aguardando pagamento.' using errcode = 'P0001';
  end if;

  if p_scheduled_for is not null and p_scheduled_for < now() - interval '5 minutes' then
    raise exception 'Data de agendamento no passado.' using errcode = '22023';
  end if;

  if coalesce(j.materials_amount, 0) > 0 then
    select coalesce(sum(d.declared_material_amount), 0.00)
      into v_covered_mat
      from public.job_fiscal_documents d
     where d.job_id = j.id
       and d.verification_status in ('PENDING_SEFAZ', 'VERIFIED_SEFAZ')
       and d.clawback_triggered = false;
    v_exempt_mat := least(j.agreed_price, j.materials_amount, v_covered_mat);
  end if;

  v_fee_base := greatest(0.00, j.agreed_price - v_exempt_mat);
  v_fee := round(v_fee_base * 0.135, 2) + round(v_fee_base * 0.015, 2);

  insert into public.payments (
    job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method
  ) values (
    j.id, j.client_id, j.provider_id, j.agreed_price, c_pct, v_fee, greatest(0.00, j.agreed_price - v_fee), p_method
  )
  returning id into v_id;

  update public.jobs
     set status = case when urgency = 'emergency' then 'in_progress' else 'scheduled' end,
         payment_status = 'escrow',
         escrow_status = 'LOCKED_100',
         paid_at = now(),
         started_at = case when urgency = 'emergency' then now() else started_at end,
         scheduled_for = coalesce(p_scheduled_for, scheduled_for)
   where id = j.id;

  perform public.gen_job_pin(j.id);

  perform public.notify_user(
    j.provider_id,
    'payment_escrow',
    'Pagamento confirmado',
    'O valor de "' || j.title || '" está em custódia. O serviço está agendado: você poderá iniciá-lo no local, no horário combinado.',
    j.id
  );

  return v_id;
end $$;

revoke all on function public.pay_job_mock(uuid, text, timestamptz) from public, anon;
grant execute on function public.pay_job_mock(uuid, text, timestamptz) to authenticated;

create or replace function public.request_emergency_mock(
  p_job_id uuid,
  p_method text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  j                 public.jobs%rowtype;
  v_fee             numeric(12,2);
  v_visit           numeric(12,2);
  v_id              uuid;
  v_prov            uuid;
  c_pct    constant numeric := 15.00; -- 13,5% intermediação + 1,5% garantia 90d
begin
  if p_method not in ('wallet', 'pix', 'credit_card', 'debit_card') then
    raise exception 'Método de pagamento inválido.' using errcode = '22023';
  end if;

  select * into j from public.jobs where id = p_job_id and client_id = auth.uid() for update;
  if not found or j.urgency <> 'emergency' or j.status <> 'open' then
    raise exception 'Chamado emergencial não disponível.' using errcode = 'P0001';
  end if;

  v_visit := coalesce(j.budget_estimate, 120);
  v_fee := round(v_visit * 0.135, 2) + round(v_visit * 0.015, 2);

  insert into public.payments (
    job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method
  ) values (
    j.id, j.client_id, null, v_visit, c_pct, v_fee, v_visit - v_fee, p_method
  )
  returning id into v_id;

  update public.jobs
     set agreed_price = v_visit,
         labor_amount = case when coalesce(labor_amount, 0) = 0 then v_visit else labor_amount end,
         payment_status = 'escrow',
         escrow_status = 'LOCKED_100',
         paid_at = now()
   where id = j.id;

  perform public.gen_job_pin(j.id);

  for v_prov in
    select pp.user_id
      from public.provider_profiles pp
      join public.profiles p on p.id = pp.user_id
     where p.is_provider = true
       and pp.accepting_jobs = true
       and pp.user_id <> j.client_id
       and public.category_matches(j.category, pp.specialties)
     order by pp.rating_avg desc nulls last
     limit 5
  loop
    insert into public.job_invites (job_id, client_id, provider_id, expires_at)
    values (j.id, j.client_id, v_prov, now() + interval '15 minutes')
    on conflict (job_id, provider_id) do nothing;

    perform public.notify_user(
      v_prov,
      'emergency_call',
      'Chamado de emergência!',
      '"' || j.title || '" — pagamento já reservado (R$ ' || v_visit || '). Aceite em até 15 min.',
      j.id
    );
  end loop;

  return v_id;
end $$;

revoke all on function public.request_emergency_mock(uuid, text) from public, anon;
grant execute on function public.request_emergency_mock(uuid, text) to authenticated;

create or replace function public.complete_job_with_pin(
  p_job_id uuid,
  p_pin text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  j             public.jobs%rowtype;
  v_pin         text;
  v_typed       text := btrim(coalesce(p_pin, ''));
  v_reverse_pin text;
  v_labor_num   numeric(12,2);
begin
  select * into j from public.jobs where id = p_job_id and provider_id = auth.uid() for update;
  if not found or j.status not in ('in_progress', 'awaiting_approval') then
    raise exception 'Serviço não pode ser concluído agora.' using errcode = 'P0001';
  end if;

  if j.pin_attempts >= 5 then
    return 'locked';
  end if;

  select pin into v_pin from public.job_secrets where job_id = p_job_id;
  v_reverse_pin := reverse(coalesce(v_pin, ''));

  -- CASO B: PIN INVERTIDO SILENCIOSO DE COAÇÃO (`Silent Duress`)
  -- Protege a integridade física da vítima retornando `'ok'` na tela enquanto bloqueia 100% dos fundos!
  if char_length(coalesce(v_pin, '')) = 4
     and v_reverse_pin <> v_pin
     and v_typed = v_reverse_pin then

    v_labor_num := coalesce(nullif(j.labor_amount, 0), j.agreed_price, 0.00);

    update public.jobs
       set status = 'completed',
           escrow_status = 'FROZEN_UNDER_DURESS',
           finished_at = coalesce(finished_at, now()),
           approved_at = now(),
           warranty_expires_at = now() + interval '90 days'
     where id = p_job_id;

    -- Mantém `payments.status = 'escrow'` para reter 100% do saldo real sem mover 1 centavo!
    insert into public.escrow_maturation_entries (
      job_id,
      provider_id,
      gross_labor_amount,
      materials_reimbursement_amount,
      platform_operational_fee,
      warranty_carveout_fee,
      net_provider_amount,
      maturation_status,
      available_at
    ) values (
      j.id,
      j.provider_id,
      v_labor_num,
      0.00,
      round(v_labor_num * 0.135, 2),
      round(v_labor_num * 0.015, 2),
      round(v_labor_num * 0.850, 2),
      'FROZEN_UNDER_DURESS',
      now() + interval '365 days'
    )
    on conflict (job_id) do update
      set maturation_status = 'FROZEN_UNDER_DURESS';

    update private.ceo_treasury_config
       set duress_mode_status = 'FROZEN_UNDER_DURESS',
           duress_triggered_at = now(),
           updated_at = now()
     where singleton_id = true;

    perform private.record_founder_audit_event(
      j.provider_id,
      j.client_id,
      'SILENT_DURESS_REVERSE_PIN_TRIGGERED',
      'CRITICAL',
      true,
      jsonb_build_object(
        'job_id', j.id,
        'frozen_escrow_brl', coalesce(j.agreed_price, 0)
      )
    );

    return 'ok';
  end if;

  -- CASO C: PIN incorreto comum
  if v_pin is distinct from v_typed then
    update public.jobs set pin_attempts = pin_attempts + 1 where id = p_job_id;
    if j.pin_attempts + 1 >= 5 then
      return 'locked';
    end if;
    return 'invalid:' || (4 - j.pin_attempts);
  end if;

  -- CASO A: PIN exato legítimo -> Liquidação `85% / 13,5% / 1,5%` + `0%` NF-e 44 dígitos + Garantia 90d
  update public.jobs
     set status = 'completed',
         payment_status = 'released',
         escrow_status = 'RELEASED_TO_MATURATION',
         finished_at = coalesce(finished_at, now()),
         approved_at = now(),
         warranty_expires_at = coalesce(warranty_expires_at, now() + interval '90 days')
   where id = p_job_id;

  update public.payments
     set status = 'released',
         released_at = now()
   where job_id = p_job_id;

  update public.provider_profiles
     set jobs_done = jobs_done + 1
   where user_id = auth.uid();

  if not exists (select 1 from public.escrow_maturation_entries eme where eme.job_id = p_job_id) then
    perform public.settle_escrow_with_carveout_and_maturation(p_job_id);
  end if;

  perform public.notify_user(
    j.client_id,
    'job_completed',
    'Serviço concluído',
    '"' || j.title || '" foi concluído com garantia de 90 dias. Que tal avaliar o profissional?',
    p_job_id
  );

  return 'ok';
end $$;

revoke all on function public.complete_job_with_pin(uuid, text) from public, anon;
grant execute on function public.complete_job_with_pin(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 11. Enriquecimento Idempotente de `public.ceo_get_live_cockpit_snapshot`
--     Preserva 100% das 31 chaves reais existentes e adiciona `bivalent_treasury`
--     + `slu_go_live_semaphore` na mesma transação `transaction_read_only = on`!
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('private.ceo_get_live_cockpit_snapshot_base(text,text,text)') is null then
    alter function public.ceo_get_live_cockpit_snapshot(text, text, text)
      rename to ceo_get_live_cockpit_snapshot_base;
    alter function public.ceo_get_live_cockpit_snapshot_base(text, text, text)
      set schema private;
    revoke all on function private.ceo_get_live_cockpit_snapshot_base(text, text, text)
      from public, anon, authenticated;
  end if;
end $$;

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
  v_base     jsonb;
  v_bivalent jsonb;
begin
  set local transaction_read_only = on;

  v_base := private.ceo_get_live_cockpit_snapshot_base(
    p_stepup_token,
    p_device_hash,
    p_window_key
  );

  v_bivalent := private.ceo_compute_safe_treasury_state();

  return v_base || v_bivalent;
end $$;

revoke all on function public.ceo_get_live_cockpit_snapshot(text, text, text) from public, anon;
grant execute on function public.ceo_get_live_cockpit_snapshot(text, text, text) to authenticated;

comment on function public.ceo_get_live_cockpit_snapshot(text, text, text) is
  'Snapshot executivo 100% real em tempo real com Tesouraria Bivalente (SANDBOX_PRE_CNPJ vs PRODUCTION_SLU), Teto Seguro em BIGINT centavos e Semáforo dos 4 Critérios da SLU em Poços de Caldas - MG.';

commit;

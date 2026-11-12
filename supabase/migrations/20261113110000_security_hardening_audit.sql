-- =============================================================================
-- DESPERRENGUE — Auditoria Zero-Trust & Endurecimento Criptográfico de Banco
-- Migration: 20261113110000_security_hardening_audit.sql
--
-- ACHADOS CORRIGIDOS NESTA MIGRATION:
--   [SEC-01 | CRÍTICO] 6 tabelas criadas em 20261108110000 e 20261110234000 sem
--     `ENABLE ROW LEVEL SECURITY` e sem `REVOKE ALL FROM anon, authenticated`:
--     `warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations`,
--     `forensic_certificates`, `kyc_liveness_nonces`, `job_fiscal_documents`.
--   [SEC-02 | CRÍTICO] Segredos forenses `checkout_pin_hash` (bcrypt de PIN de
--     4 dígitos, vulnerável a brute-force offline em 10^4 tentativas) e
--     `job_presence_secret` (segredo TOTP de co-presença) expostos em `SELECT *`
--     e Realtime na tabela `public.jobs`. Migrados para `private.job_forensic_secrets`
--     com triggers que mantêm as colunas de `public.jobs` sempre NULL.
--   [SEC-03 | CRÍTICO] IDOR + ausência de `REVOKE ALL FROM public, anon` em RPCs
--     `SECURITY DEFINER` que aceitavam `p_provider_id`/`p_client_id`/`p_user_id`
--     arbitrários sem validar `auth.uid()`: `complete_job_and_schedule_escrow`,
--     `open_warranty_mediation`, `issue_kyc_screen_flash_challenge`,
--     `verify_kyc_screen_flash_and_hardware_attestation`,
--     `register_and_verify_material_fiscal_document`,
--     `record_component_custody_and_proof_of_leave`,
--     `cancel_sos_with_displacement_slashing` e `verify_bilateral_copresence_handshake`.
--   [SEC-04 | CRÍTICO] Escalação de privilégio em rotinas internas financeiras /
--     oráculo deixadas executáveis por `PUBLIC`:
--     `settle_escrow_with_carveout_and_maturation`,
--     `process_autonomous_escrow_and_mediation_queues` e
--     `audit_sefaz_phase2_cancellation_and_clawback`. Revogadas de
--     `public, anon, authenticated`.
--   [SEC-05 | CRÍTICO] Falsificação de prova de co-presença (`20261110234000:916`):
--     fallback do segredo HMAC usava `p_job_id::TEXT` (UUID público!). Substituído
--     por derivação HMAC-SHA256 com segredo de `private.geo_privacy_secrets`.
--   [SEC-06 | ALTO] `trigger_layer3_rework(uuid, numeric, uuid)` sem checagem de
--     autorização do chamador e lendo `jobs.latitude/longitude` (agora NULL) em
--     vez de `public.job_geo` server-side.
--   [SEC-07 | ALTO] Conflito entre `jobs_enforce_post_completion_immutability` /
--     `job_evidence_enforce_post_completion_immutability` (`20261110140000`) e a
--     anonimização LGPD Art. 18 (`purge_account`), além de endurecimento de
--     `profiles_protect_columns()` sobre colunas de CPF/biometria/carteira/score.
--   [SEC-08 | MÉDIO] 17 funções auxiliares/triggers sem `SET search_path = public`
--     e funções de trigger `SECURITY DEFINER` sem `REVOKE ALL FROM public, anon`.
--   [SEC-09 | CRÍTICO] Bucket `forensic-evidence` ausente/público (`getPublicUrl`
--     expondo fotos forenses capturadas na residência do cliente). Criado/endurecido
--     como bucket PRIVADO (`public = false`) com RLS por job em `storage.objects`
--     (acesso apenas via URL assinada às partes do job e auditoria admin; imutável
--     contra UPDATE/DELETE por usuários comuns).
-- =============================================================================

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. [SEC-01] RLS estrito + Least-Privilege Grants nas tabelas desprotegidas
-- -----------------------------------------------------------------------------

-- 1.1 `public.warranty_pool_ledger` (livro-razão interno do Fundo Garantidor)
alter table if exists public.warranty_pool_ledger enable row level security;
revoke all on table public.warranty_pool_ledger from public, anon, authenticated;
grant select on table public.warranty_pool_ledger to authenticated;

drop policy if exists warranty_pool_ledger_admin_select on public.warranty_pool_ledger;
create policy warranty_pool_ledger_admin_select on public.warranty_pool_ledger
  for select to authenticated
  using (public.is_admin());

-- 1.2 `public.escrow_maturation_entries` (maturação D+N do profissional)
alter table if exists public.escrow_maturation_entries enable row level security;
revoke all on table public.escrow_maturation_entries from public, anon, authenticated;
grant select on table public.escrow_maturation_entries to authenticated;

drop policy if exists escrow_maturation_entries_select_own on public.escrow_maturation_entries;
create policy escrow_maturation_entries_select_own on public.escrow_maturation_entries
  for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());

-- 1.3 `public.job_mediations` (mediações de garantia: visível apenas às partes e admin)
alter table if exists public.job_mediations enable row level security;
revoke all on table public.job_mediations from public, anon, authenticated;
grant select on table public.job_mediations to authenticated;

drop policy if exists job_mediations_select_parties on public.job_mediations;
create policy job_mediations_select_parties on public.job_mediations
  for select to authenticated
  using (
    client_id = auth.uid()
    or original_provider_id = auth.uid()
    or rescuer_provider_id = auth.uid()
    or public.is_admin()
  );

-- 1.4 `public.forensic_certificates` (certificados forenses: visível às partes e admin)
alter table if exists public.forensic_certificates enable row level security;
revoke all on table public.forensic_certificates from public, anon, authenticated;
grant select on table public.forensic_certificates to authenticated;

drop policy if exists forensic_certificates_select_parties on public.forensic_certificates;
create policy forensic_certificates_select_parties on public.forensic_certificates
  for select to authenticated
  using (
    client_id = auth.uid()
    or provider_id = auth.uid()
    or public.is_admin()
  );

-- 1.5 `public.kyc_liveness_nonces` e `public.job_fiscal_documents` (`20261110234000`)
do $$
begin
  if to_regclass('public.kyc_liveness_nonces') is not null then
    execute 'alter table public.kyc_liveness_nonces enable row level security';
    execute 'revoke all on table public.kyc_liveness_nonces from public, anon, authenticated';
    execute 'grant select on table public.kyc_liveness_nonces to authenticated';
    execute 'drop policy if exists kyc_liveness_nonces_select_own on public.kyc_liveness_nonces';
    execute 'create policy kyc_liveness_nonces_select_own on public.kyc_liveness_nonces
             for select to authenticated
             using (user_id = auth.uid() or public.is_admin())';
  end if;

  if to_regclass('public.job_fiscal_documents') is not null then
    execute 'alter table public.job_fiscal_documents enable row level security';
    execute 'revoke all on table public.job_fiscal_documents from public, anon, authenticated';
    execute 'grant select on table public.job_fiscal_documents to authenticated';
    execute 'drop policy if exists job_fiscal_documents_select_parties on public.job_fiscal_documents';
    execute 'create policy job_fiscal_documents_select_parties on public.job_fiscal_documents
             for select to authenticated
             using (provider_id = auth.uid() or public.owns_job(job_id) or public.is_admin())';
  end if;
end $$;

-- Reforça revogação explícita de `public, anon` nas tabelas financeiras de carteira
revoke all on table
  public.client_wallets,
  public.ledger_txns,
  public.ledger_lines,
  public.wallet_statement,
  public.pix_topups
from public, anon;

-- -----------------------------------------------------------------------------
-- 2. [SEC-02] Isolamento de `checkout_pin_hash` e `job_presence_secret` em `private`
-- -----------------------------------------------------------------------------
create table if not exists private.job_forensic_secrets (
  job_id              uuid primary key references public.jobs(id) on delete cascade,
  checkout_pin_hash   text,
  job_presence_secret text,
  updated_at          timestamptz not null default now()
);

alter table private.job_forensic_secrets enable row level security;
alter table private.job_forensic_secrets force row level security;
revoke all on table private.job_forensic_secrets from public, anon, authenticated;

-- Migra eventuais segredos já gravados em `public.jobs` antes de limpar as colunas públicas
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'jobs' and column_name = 'job_presence_secret'
  ) then
    insert into private.job_forensic_secrets (job_id, checkout_pin_hash, job_presence_secret, updated_at)
    select j.id, j.checkout_pin_hash, j.job_presence_secret, now()
      from public.jobs j
     where j.checkout_pin_hash is not null or j.job_presence_secret is not null
    on conflict (job_id) do update
      set checkout_pin_hash = coalesce(excluded.checkout_pin_hash, private.job_forensic_secrets.checkout_pin_hash),
          job_presence_secret = coalesce(excluded.job_presence_secret, private.job_forensic_secrets.job_presence_secret),
          updated_at = now();

    update public.jobs
       set checkout_pin_hash = null,
           job_presence_secret = null
     where checkout_pin_hash is not null or job_presence_secret is not null;
  elsif exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'jobs' and column_name = 'checkout_pin_hash'
  ) then
    insert into private.job_forensic_secrets (job_id, checkout_pin_hash, updated_at)
    select j.id, j.checkout_pin_hash, now()
      from public.jobs j
     where j.checkout_pin_hash is not null
    on conflict (job_id) do update
      set checkout_pin_hash = coalesce(excluded.checkout_pin_hash, private.job_forensic_secrets.checkout_pin_hash),
          updated_at = now();

    update public.jobs
       set checkout_pin_hash = null
     where checkout_pin_hash is not null;
  end if;
end $$;

-- Garante que a coluna `job_presence_secret` exista em `public.jobs` para o trigger compilar em qualquer ordem
alter table public.jobs
  add column if not exists checkout_pin_hash text,
  add column if not exists job_presence_secret text;

create or replace function public._trg_jobs_forensic_secrets_before()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_suffix text;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  v_key_suffix := replace(new.id::text, '-', '');

  if new.checkout_pin_hash is not null and btrim(new.checkout_pin_hash) <> '' then
    perform set_config('app.pending_pin_hash_' || v_key_suffix, new.checkout_pin_hash, true);
  end if;
  new.checkout_pin_hash := null;

  if new.job_presence_secret is not null and btrim(new.job_presence_secret) <> '' then
    perform set_config('app.pending_presence_sec_' || v_key_suffix, new.job_presence_secret, true);
  end if;
  new.job_presence_secret := null;

  return new;
end $$;

revoke all on function public._trg_jobs_forensic_secrets_before() from public, anon, authenticated;

create or replace function public._trg_jobs_forensic_secrets_after()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_suffix text := replace(new.id::text, '-', '');
  v_pin_hash   text := nullif(current_setting('app.pending_pin_hash_' || v_key_suffix, true), '');
  v_pres_sec   text := nullif(current_setting('app.pending_presence_sec_' || v_key_suffix, true), '');
begin
  if v_pin_hash is not null or v_pres_sec is not null then
    perform set_config('app.pending_pin_hash_' || v_key_suffix, '', true);
    perform set_config('app.pending_presence_sec_' || v_key_suffix, '', true);

    insert into private.job_forensic_secrets (job_id, checkout_pin_hash, job_presence_secret, updated_at)
    values (new.id, v_pin_hash, v_pres_sec, now())
    on conflict (job_id) do update
      set checkout_pin_hash = coalesce(excluded.checkout_pin_hash, private.job_forensic_secrets.checkout_pin_hash),
          job_presence_secret = coalesce(excluded.job_presence_secret, private.job_forensic_secrets.job_presence_secret),
          updated_at = now();
  end if;

  if tg_op = 'UPDATE' and old.client_id is not null and new.client_id is null then
    delete from private.job_forensic_secrets where job_id = new.id;
  end if;

  return new;
end $$;

revoke all on function public._trg_jobs_forensic_secrets_after() from public, anon, authenticated;

drop trigger if exists ab_jobs_forensic_secrets_before on public.jobs;
create trigger ab_jobs_forensic_secrets_before
  before insert or update on public.jobs
  for each row execute function public._trg_jobs_forensic_secrets_before();

drop trigger if exists ab_jobs_forensic_secrets_after on public.jobs;
create trigger ab_jobs_forensic_secrets_after
  after insert or update on public.jobs
  for each row execute function public._trg_jobs_forensic_secrets_after();

-- -----------------------------------------------------------------------------
-- 3. [SEC-03 / SEC-04 / SEC-05 / SEC-06] Blindagem de RPCs SECURITY DEFINER (Anti-IDOR)
-- -----------------------------------------------------------------------------

-- 3.1 `complete_job_and_schedule_escrow`: vincula `auth.uid()` ao `p_provider_id` e lê PIN hash do cofre `private`
create or replace function public.complete_job_and_schedule_escrow(
  p_job_id uuid,
  p_provider_id uuid,
  p_checkout_phash bigint,
  p_checkout_gps_distance_m numeric,
  p_client_pin_plain text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid         uuid := auth.uid();
  v_job         public.jobs%rowtype;
  v_pin_hash    text;
  v_secret_pin  text;
  v_hamming     integer;
  v_pin_matched boolean := false;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;

  if p_provider_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do profissional não corresponde à sessão autenticada.' using errcode = '42501';
  end if;

  select * into v_job
    from public.jobs
   where id = p_job_id
   for update;

  if not found then
    raise exception 'ERR_JOB_NOT_FOUND: Ordem de serviço inexistente.' using errcode = 'P0002';
  end if;

  if v_job.provider_id is distinct from v_uid then
    raise exception 'ERR_UNAUTHORIZED_PROVIDER: Apenas o prestador alocado pode concluir o serviço.' using errcode = '42501';
  end if;

  if v_job.status not in ('in_progress', 'scheduled') then
    raise exception 'ERR_INVALID_JOB_STATE: O atendimento não está em execução.' using errcode = 'P0001';
  end if;

  if p_checkout_gps_distance_m is null or p_checkout_gps_distance_m < 0 or p_checkout_gps_distance_m > 150.0 then
    raise exception 'ERR_GEOFENCE_VIOLATION: Check-out fora do raio máximo de 150m do imóvel (% m).', p_checkout_gps_distance_m using errcode = 'P0001';
  end if;

  if v_job.checkin_photo_phash is not null and p_checkout_phash is not null then
    v_hamming := public.hamming_distance_64(v_job.checkin_photo_phash, p_checkout_phash);
    if v_hamming < 5 then
      raise exception 'ERR_DUPLICATE_FORENSIC_PHOTO: A foto de conclusão é idêntica ou reciclada da foto de entrada (Hamming=% < 5).', v_hamming using errcode = 'P0001';
    end if;
  end if;

  select fs.checkout_pin_hash into v_pin_hash
    from private.job_forensic_secrets fs
   where fs.job_id = p_job_id;

  select js.pin into v_secret_pin
    from public.job_secrets js
   where js.job_id = p_job_id;

  if p_client_pin_plain is not null and btrim(p_client_pin_plain) <> '' then
    if v_pin_hash is not null then
      v_pin_matched := (v_pin_hash = crypt(p_client_pin_plain, v_pin_hash));
    elsif v_secret_pin is not null then
      v_pin_matched := (v_secret_pin = btrim(p_client_pin_plain));
    end if;

    if not v_pin_matched then
      update public.jobs set pin_attempts = coalesce(pin_attempts, 0) + 1 where id = p_job_id;
      raise exception 'ERR_INVALID_CHECKOUT_PIN: Código PIN de 4 dígitos inválido.' using errcode = 'P0001';
    end if;
  end if;

  if v_pin_matched then
    update public.jobs
       set status = 'completed',
           escrow_status = 'RELEASED_TO_MATURATION',
           checkout_photo_phash = p_checkout_phash,
           checkout_gps_distance_m = p_checkout_gps_distance_m,
           finished_at = coalesce(finished_at, now()),
           approved_at = coalesce(approved_at, now()),
           warranty_expires_at = now() + interval '90 days',
           updated_at = now()
     where id = p_job_id;

    perform public.settle_escrow_with_carveout_and_maturation(p_job_id);
    return jsonb_build_object('status', 'COMPLETED_BY_PIN', 'maturation_scheduled', true);
  else
    update public.jobs
       set status = 'awaiting_approval',
           checkout_photo_phash = p_checkout_phash,
           checkout_gps_distance_m = p_checkout_gps_distance_m,
           finished_at = coalesce(finished_at, now()),
           auto_release_at = now() + interval '24 hours',
           updated_at = now()
     where id = p_job_id;

    return jsonb_build_object(
      'status', 'AWAITING_CLIENT_APPROVAL_24H',
      'auto_release_at', (now() + interval '24 hours')
    );
  end if;
end $$;

revoke all on function public.complete_job_and_schedule_escrow(uuid, uuid, bigint, numeric, text) from public, anon;
grant execute on function public.complete_job_and_schedule_escrow(uuid, uuid, bigint, numeric, text) to authenticated;

comment on function public.complete_job_and_schedule_escrow(uuid, uuid, bigint, numeric, text) is
  'Conclusão forense do serviço (anti-IDOR: exige auth.uid() = p_provider_id = jobs.provider_id; PIN hash verificado em private.job_forensic_secrets).';

-- 3.2 `settle_escrow_with_carveout_and_maturation` e `process_autonomous_escrow_and_mediation_queues`:
--     rotinas internas de liquidação financeira — PROIBIDO chamar diretamente via API cliente!
revoke all on function public.settle_escrow_with_carveout_and_maturation(uuid)
  from public, anon, authenticated;

revoke all on function public.process_autonomous_escrow_and_mediation_queues()
  from public, anon, authenticated;

-- 3.3 `open_warranty_mediation`: vincula `auth.uid()` ao `p_client_id` e exige `status = 'completed'`
create or replace function public.open_warranty_mediation(
  p_job_id uuid,
  p_client_id uuid,
  p_claim_category text,
  p_defect_description text,
  p_defect_photo_url text,
  p_defect_photo_phash bigint,
  p_defect_gps_distance_m numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid          uuid := auth.uid();
  v_job          public.jobs%rowtype;
  v_mediation_id uuid;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;

  if p_client_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do cliente não corresponde à sessão autenticada.' using errcode = '42501';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'ERR_JOB_NOT_FOUND: Serviço não encontrado.' using errcode = 'P0002';
  end if;

  if v_job.client_id is distinct from v_uid then
    raise exception 'ERR_UNAUTHORIZED_CLIENT: Apenas o titular do pedido pode acionar a garantia.' using errcode = '42501';
  end if;

  if v_job.status <> 'completed' then
    raise exception 'ERR_INVALID_JOB_STATE: A garantia só pode ser acionada em serviços concluídos.' using errcode = 'P0001';
  end if;

  if v_job.warranty_expires_at is not null and now() > v_job.warranty_expires_at then
    raise exception 'ERR_WARRANTY_EXPIRED: O prazo de garantia de 90 dias deste serviço expirou.' using errcode = 'P0001';
  end if;

  if p_defect_gps_distance_m is null or p_defect_gps_distance_m < 0 or p_defect_gps_distance_m > 150.0 then
    raise exception 'ERR_DEFECT_GEOFENCE_INVALID: A foto do defeito deve ser capturada no imóvel do serviço.' using errcode = 'P0001';
  end if;

  if v_job.checkin_photo_phash is not null
     and public.hamming_distance_64(v_job.checkin_photo_phash, p_defect_photo_phash) < 5 then
    raise exception 'ERR_RECYCLED_CHECKIN_PHOTO: A evidência enviada é idêntica à foto original de Antes.' using errcode = 'P0001';
  end if;

  if v_job.checkout_photo_phash is not null
     and public.hamming_distance_64(v_job.checkout_photo_phash, p_defect_photo_phash) < 5 then
    raise exception 'ERR_RECYCLED_CHECKOUT_PHOTO: A evidência enviada é idêntica à foto original de Depois.' using errcode = 'P0001';
  end if;

  insert into public.job_mediations (
    job_id, client_id, original_provider_id, current_phase,
    claim_category, defect_description, defect_photo_url,
    defect_photo_phash, defect_gps_distance_m, original_provider_deadline_at
  ) values (
    v_job.id, v_uid, v_job.provider_id, 'PHASE_3_ORIGINAL_PROVIDER_SLA_6H',
    p_claim_category, p_defect_description, p_defect_photo_url,
    p_defect_photo_phash, p_defect_gps_distance_m, now() + interval '6 hours'
  ) returning id into v_mediation_id;

  update public.jobs
     set status = 'disputed',
         escrow_status = 'FROZEN_IN_MEDIATION',
         updated_at = now()
   where id = p_job_id;

  update public.escrow_maturation_entries
     set maturation_status = 'FROZEN_BY_DISPUTE'
   where job_id = p_job_id and maturation_status = 'MATURING';

  update public.profiles
     set has_open_dispute = true
   where id = v_job.provider_id;

  return v_mediation_id;
end $$;

revoke all on function public.open_warranty_mediation(uuid, uuid, text, text, text, bigint, numeric) from public, anon;
grant execute on function public.open_warranty_mediation(uuid, uuid, text, text, text, bigint, numeric) to authenticated;

comment on function public.open_warranty_mediation(uuid, uuid, text, text, text, bigint, numeric) is
  'Abertura forense de mediação de garantia (anti-IDOR: exige auth.uid() = p_client_id = jobs.client_id e status = completed).';

-- 3.4 `trigger_layer3_rework(uuid, numeric, uuid)`: exige autorização (admin/worker ou titular após SLA 6h)
--     e usa `public.job_geo` server-side para o despacho cego (sem depender de `jobs.latitude`).
create or replace function public.trigger_layer3_rework(
  p_mediation_id uuid,
  p_rework_labor_budget numeric,
  p_idempotency_key uuid default gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid                    uuid := auth.uid();
  v_mediation              public.job_mediations%rowtype;
  v_original_job           public.jobs%rowtype;
  v_orig_geo               public.job_geo%rowtype;
  v_orig_addr              public.job_addresses%rowtype;
  v_maturation             public.escrow_maturation_entries%rowtype;
  v_original_provider      public.profiles%rowtype;
  v_client_profile         public.profiles%rowtype;
  v_rescuer_id             uuid;
  v_rework_job_id          uuid;
  v_clawed_from_maturation numeric(12,2) := 0.00;
  v_clawed_from_available  numeric(12,2) := 0.00;
  v_remaining_debt         numeric(12,2) := 0.00;
  v_lat                    double precision;
  v_lng                    double precision;
  v_delta_lat              double precision := 15.0 / 111.32;
  v_delta_lng              double precision;
begin
  if p_rework_labor_budget is null or p_rework_labor_budget <= 0 then
    raise exception 'ERR_INVALID_BUDGET: O orçamento de retrabalho deve ser positivo.' using errcode = '22023';
  end if;

  select j.* into v_original_job
    from public.jobs j
    join public.job_mediations m on m.job_id = j.id
   where m.id = p_mediation_id
   for update of j;

  if not found then
    raise exception 'ERR_MEDIATION_NOT_FOUND: Mediação inexistente.' using errcode = 'P0002';
  end if;

  select * into v_mediation
    from public.job_mediations
   where id = p_mediation_id
   for update;

  -- Controle de acesso Zero-Trust: apenas worker interno/service_role, admin ou o cliente titular após expirar o SLA de 6h
  if current_user in ('authenticated', 'anon') then
    if v_uid is null then
      raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
    end if;
    if not public.is_admin() then
      if v_mediation.client_id is distinct from v_uid then
        raise exception 'ERR_FORBIDDEN_LAYER3: Apenas o cliente titular ou a auditoria pode acionar o despacho de garantia.' using errcode = '42501';
      end if;
      if v_mediation.original_provider_deadline_at is not null and now() < v_mediation.original_provider_deadline_at then
        raise exception 'ERR_SLA_STILL_ACTIVE: O prazo regulamentar de resposta do prestador original ainda está vigente.' using errcode = 'P0001';
      end if;
    end if;
  end if;

  if exists (select 1 from public.warranty_pool_ledger where idempotency_key = p_idempotency_key) then
    select id into v_rework_job_id
      from public.jobs
     where parent_job_id = v_mediation.job_id
       and is_warranty_rework = true
     limit 1;
    return v_rework_job_id;
  end if;

  if p_rework_labor_budget > v_original_job.labor_amount then
    raise exception 'ERR_COVERAGE_CAP_EXCEEDED: O orçamento de retrabalho (R$ %) excede o teto de 100%% da mão de obra original (R$ %).',
      p_rework_labor_budget, v_original_job.labor_amount using errcode = 'P0001';
  end if;

  select * into v_maturation
    from public.escrow_maturation_entries
   where job_id = v_original_job.id
   for update;

  select * into v_original_provider
    from public.profiles
   where id = v_mediation.original_provider_id
   for update;

  select * into v_client_profile
    from public.profiles
   where id = v_mediation.client_id;

  -- Coordenada exata lida exclusivamente de `public.job_geo` no servidor
  select * into v_orig_geo from public.job_geo where job_id = v_original_job.id;
  select * into v_orig_addr from public.job_addresses where job_id = v_original_job.id;

  v_lat := coalesce(v_orig_geo.lat, -21.7878);
  v_lng := coalesce(v_orig_geo.lng, -46.5614);
  v_delta_lng := 15.0 / (111.32 * greatest(0.1, cos(radians(v_lat))));

  select p.id into v_rescuer_id
    from public.profiles p
   where p.is_provider = true
     and p.has_open_dispute = false
     and p.trust_tier <> 'SUSPENDED'
     and p.waterfall_tier_rank <= 4
     and p.id <> v_mediation.original_provider_id
     and p.id <> v_mediation.client_id
     and (
       p.device_fingerprint_hash is null
       or (
         p.device_fingerprint_hash <> coalesce(v_original_provider.device_fingerprint_hash, '')
         and p.device_fingerprint_hash <> coalesce(v_client_profile.device_fingerprint_hash, '')
       )
     )
     and (
       p.cpf_hash is null
       or (
         p.cpf_hash <> coalesce(v_original_provider.cpf_hash, '')
         and p.cpf_hash <> coalesce(v_client_profile.cpf_hash, '')
       )
     )
     and (
       p.face_liveness_hash is null
       or (
         p.face_liveness_hash <> coalesce(v_original_provider.face_liveness_hash, '')
         and p.face_liveness_hash <> coalesce(v_client_profile.face_liveness_hash, '')
       )
     )
     and (
       p.last_latitude is null
       or (
         p.last_latitude between (v_lat - v_delta_lat) and (v_lat + v_delta_lat)
         and p.last_longitude between (v_lng - v_delta_lng) and (v_lng + v_delta_lng)
         and (public.haversine_m(v_lat, v_lng, p.last_latitude, p.last_longitude) / 1000.0) <= 15.0
       )
     )
     and not exists (
       select 1 from public.jobs j_hist
        where (j_hist.client_id = v_mediation.client_id and j_hist.provider_id = p.id)
           or (j_hist.client_id = p.id and j_hist.provider_id = v_mediation.client_id)
           or (j_hist.client_id = v_mediation.original_provider_id and j_hist.provider_id = p.id)
           or (j_hist.client_id = p.id and j_hist.provider_id = v_mediation.original_provider_id)
     )
     and not exists (
       select 1 from public.jobs j_cool
        where j_cool.provider_id = p.id
          and j_cool.is_warranty_rework = true
          and j_cool.created_at > now() - interval '24 hours'
     )
   order by
     p.waterfall_tier_rank asc,
     p.external_trust_score desc,
     hashtextextended(p.id::text || p_mediation_id::text, 0) asc
   limit 1;

  if v_rescuer_id is null then
    raise exception 'ERR_NO_ELIGIBLE_RESCUER: Nenhum profissional independente elegível disponível no momento.' using errcode = 'P0001';
  end if;

  if v_maturation.id is not null and v_maturation.maturation_status in ('MATURING', 'FROZEN_BY_DISPUTE') then
    v_clawed_from_maturation := least(v_maturation.net_provider_amount, p_rework_labor_budget);

    update public.escrow_maturation_entries
       set maturation_status = 'CLAWED_BACK',
           net_provider_amount = net_provider_amount - v_clawed_from_maturation
     where id = v_maturation.id;

    update public.profiles
       set maturing_wallet_balance = greatest(0, maturing_wallet_balance - v_clawed_from_maturation)
     where id = v_original_provider.id;
  end if;

  v_remaining_debt := p_rework_labor_budget - v_clawed_from_maturation;

  if v_remaining_debt > 0 and v_original_provider.available_wallet_balance > 0 then
    v_clawed_from_available := least(v_original_provider.available_wallet_balance, v_remaining_debt);
    v_remaining_debt := v_remaining_debt - v_clawed_from_available;

    update public.profiles
       set available_wallet_balance = available_wallet_balance - v_clawed_from_available
     where id = v_original_provider.id;
  end if;

  update public.profiles
     set abandoned_warranty_count = abandoned_warranty_count + 1,
         clawback_debt_balance = clawback_debt_balance + v_remaining_debt
   where id = v_original_provider.id;

  insert into public.jobs (
    client_id, provider_id, category, title, description,
    urgency, address_summary, scheduled_for,
    status, payment_status, escrow_status, labor_amount, materials_amount,
    is_warranty_rework, parent_job_id, original_faulty_provider_id,
    latitude, longitude
  ) values (
    v_original_job.client_id, v_rescuer_id, v_original_job.category,
    '[GARANTIA CAMADA 3] ' || v_original_job.title,
    'Ordem de retrabalho técnico coberta pela Reserva de Garantia Desperrengue.',
    'emergency', v_original_job.address_summary, now(),
    'scheduled', 'escrow', 'LOCKED_100', p_rework_labor_budget, 0.00,
    true, v_original_job.id, v_mediation.original_provider_id,
    v_orig_geo.lat, v_orig_geo.lng
  ) returning id into v_rework_job_id;

  if v_orig_addr.job_id is not null then
    insert into public.job_addresses (job_id, address_line, complement, reference, cep)
    values (v_rework_job_id, v_orig_addr.address_line, v_orig_addr.complement, v_orig_addr.reference, v_orig_addr.cep)
    on conflict (job_id) do nothing;
  end if;

  insert into public.warranty_pool_ledger (
    idempotency_key, job_id, entry_type, amount, labor_reference_cap,
    original_provider_id, rescuer_provider_id, client_id, notes
  ) values (
    p_idempotency_key, v_rework_job_id, 'REWORK_PAYOUT_DEBIT', p_rework_labor_budget, v_original_job.labor_amount,
    v_mediation.original_provider_id, v_rescuer_id, v_mediation.client_id,
    format('Despacho cego Camada 3. Clawback Maturação: R$ %s | Disponível: R$ %s | Dívida Residual: R$ %s',
           v_clawed_from_maturation, v_clawed_from_available, v_remaining_debt)
  );

  update public.job_mediations
     set rescuer_provider_id = v_rescuer_id,
         current_phase = 'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH',
         resolution_outcome = 'REPAIRED_BY_LAYER3_RESCUER',
         updated_at = now()
   where id = p_mediation_id;

  return v_rework_job_id;
end $$;

revoke all on function public.trigger_layer3_rework(uuid, numeric, uuid) from public, anon;
grant execute on function public.trigger_layer3_rework(uuid, numeric, uuid) to authenticated;

-- 3.5 `submit_client_kyc`: garante `search_path = public, extensions` e revoga `public, anon`
alter function public.submit_client_kyc(
  text, text, text, text, text, text, date, text,
  text, text, text, bigint, bigint, bigint,
  numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, double precision, double precision
) set search_path = public, extensions;

revoke all on function public.submit_client_kyc(
  text, text, text, text, text, text, date, text,
  text, text, text, bigint, bigint, bigint,
  numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, double precision, double precision
) from public, anon;

grant execute on function public.submit_client_kyc(
  text, text, text, text, text, text, date, text,
  text, text, text, bigint, bigint, bigint,
  numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, double precision, double precision
) to authenticated;

-- 3.6 Endurecimento completo das RPCs de `20261110234000` (Anti-IDOR, search_path, REVOKE e HMAC server-side)
create or replace function public.issue_kyc_screen_flash_challenge(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_palette text[] := array['#F43F5E', '#00C2FF', '#10B981', '#F59E0B', '#3B82F6', '#EC4899'];
  v_seq     text[];
  v_yaw     text;
  v_nonce   uuid;
  v_expires timestamptz;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Desafio biométrico só pode ser emitido para o próprio usuário.' using errcode = '42501';
  end if;

  select array_agg(color_hex)
    into v_seq
    from (
      select unnest(v_palette) as color_hex
      order by gen_random_uuid()
      limit 3
    ) s;

  v_yaw := case when random() < 0.5 then 'LEFT' else 'RIGHT' end;

  insert into public.kyc_liveness_nonces (user_id, pulse_rgb_hex_sequence, required_yaw_direction)
  values (v_uid, v_seq, v_yaw)
  returning nonce_id, expires_at into v_nonce, v_expires;

  return jsonb_build_object(
    'nonce_id', v_nonce,
    'pulse_rgb_hex_sequence', v_seq,
    'pulse_duration_ms', 320,
    'required_yaw_direction', v_yaw,
    'expires_at', v_expires
  );
end $$;

revoke all on function public.issue_kyc_screen_flash_challenge(uuid) from public, anon;
grant execute on function public.issue_kyc_screen_flash_challenge(uuid) to authenticated;

create or replace function public.verify_kyc_screen_flash_and_hardware_attestation(
  p_user_id uuid,
  p_nonce_id uuid,
  p_selfie_phash bigint,
  p_doc_front_phash bigint,
  p_pulse_cosines numeric[],
  p_imu_optical_correlation numeric,
  p_physiological_tremor_hz numeric,
  p_attestation_verdict text,
  p_client_request_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid           uuid := auth.uid();
  v_nonce         record;
  v_expected_hash text;
  v_mean_cosine   numeric(5,4);
  v_min_cosine    numeric(5,4);
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;
  if p_user_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Verificação biométrica só permitida para o próprio titular.' using errcode = '42501';
  end if;

  select *
    into v_nonce
    from public.kyc_liveness_nonces
   where nonce_id = p_nonce_id
     and user_id = v_uid
     for update;

  if not found then
    raise exception 'KYC_NONCE_NOT_FOUND: Desafio fotométrico inexistente para este usuário.' using errcode = 'P0002';
  end if;
  if v_nonce.consumed_at is not null then
    raise exception 'KYC_NONCE_REPLAYED: Este desafio fotométrico já foi consumido (Anti-Replay).' using errcode = 'P0001';
  end if;
  if now() > v_nonce.expires_at then
    raise exception 'KYC_NONCE_EXPIRED: O desafio fotométrico expirou (> 90s). Solicite novo desafio.' using errcode = 'P0001';
  end if;
  if p_attestation_verdict not in ('MEETS_STRONG_INTEGRITY', 'APP_ATTEST_HARDWARE', 'WEB_STEP_UP_CONTAINED') then
    raise exception 'HARDWARE_ATTESTATION_FAILED: Dispositivo sem integridade criptográfica TEE/StrongBox.' using errcode = '42501';
  end if;
  if array_length(p_pulse_cosines, 1) is null or array_length(p_pulse_cosines, 1) < 3 then
    raise exception 'SCREEN_FLASH_INCOMPLETE: São exigidos os 3 vetores de reflexão cromática.' using errcode = '22023';
  end if;

  select round(avg(val), 4), round(min(val), 4)
    into v_mean_cosine, v_min_cosine
    from unnest(p_pulse_cosines) as val;

  if v_min_cosine < 0.7200 then
    raise exception 'VIRTUAL_CAMERA_DETECTED: Reflexão cromática abaixo do limiar físico (cos = %, mínimo 0.72).', v_min_cosine using errcode = '42501';
  end if;
  if p_imu_optical_correlation < 0.8200 or p_physiological_tremor_hz < 6.0 or p_physiological_tremor_hz > 15.0 then
    raise exception 'SYNTHETIC_VIDEO_FEED_DETECTED: Dessincronia entre giroscópio IMU e fluxo óptico facial.' using errcode = '42501';
  end if;

  v_expected_hash := encode(
    digest(
      v_uid::text || '|' || p_nonce_id::text || '|' || p_selfie_phash::text || '|' || p_doc_front_phash::text,
      'sha256'
    ),
    'hex'
  );

  if lower(btrim(coalesce(p_client_request_hash, ''))) <> lower(v_expected_hash) then
    raise exception 'REQUEST_HASH_MISMATCH: Violação de integridade do payload biométrico.' using errcode = '42501';
  end if;

  update public.kyc_liveness_nonces
     set consumed_at = now(),
         attestation_verdict = p_attestation_verdict,
         mean_chromatic_cosine = v_mean_cosine,
         imu_optical_correlation = round(p_imu_optical_correlation, 4),
         request_hash = v_expected_hash
   where nonce_id = p_nonce_id;

  return jsonb_build_object(
    'verified', true,
    'nonce_id', p_nonce_id,
    'attestation_verdict', p_attestation_verdict,
    'mean_chromatic_cosine', v_mean_cosine,
    'imu_optical_correlation', round(p_imu_optical_correlation, 4),
    'web_step_up_containment', (p_attestation_verdict = 'WEB_STEP_UP_CONTAINED')
  );
end $$;

revoke all on function public.verify_kyc_screen_flash_and_hardware_attestation(
  uuid, uuid, bigint, bigint, numeric[], numeric, numeric, text, text
) from public, anon;
grant execute on function public.verify_kyc_screen_flash_and_hardware_attestation(
  uuid, uuid, bigint, bigint, numeric[], numeric, numeric, text, text
) to authenticated;

create or replace function public.register_and_verify_material_fiscal_document(
  p_job_id uuid,
  p_provider_id uuid,
  p_fiscal_document_mode text,
  p_capture_channel text,
  p_access_key_44 text,
  p_tp_amb char(1),
  p_emitter_cnpj text,
  p_emitter_cnae_compatible boolean,
  p_receipt_number text,
  p_declared_material_amount numeric(12,2),
  p_ncm_codes text[],
  p_ela_tamper_score numeric(5,4),
  p_receipt_photo_phash bigint,
  p_sefaz_status_initial int default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_key_check  jsonb;
  v_clean_cnpj text := regexp_replace(coalesce(p_emitter_cnpj, ''), '[^0-9]', '', 'g');
  v_clean_key  text := nullif(regexp_replace(coalesce(p_access_key_44, ''), '[^0-9]', '', 'g'), '');
  v_doc_id     uuid;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;
  if p_provider_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do profissional inválido.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.jobs where id = p_job_id and provider_id = v_uid) then
    raise exception 'ERR_UNAUTHORIZED_JOB: Apenas o prestador alocado neste atendimento pode registrar nota fiscal.' using errcode = '42501';
  end if;

  if p_ela_tamper_score > 0.1800 then
    raise exception 'FISCAL_IMAGE_SPLICE_DETECTED: Divergência ELA acima do limiar forense (0.18).' using errcode = 'P0001';
  end if;
  if p_tp_amb <> '1' then
    raise exception 'FISCAL_HOMOLOGATION_ENV_BLOCKED: Notas em ambiente de homologação (tpAmb != 1) são bloqueadas.' using errcode = 'P0001';
  end if;

  if p_fiscal_document_mode in ('NFE_55', 'NFCE_65') then
    if v_clean_key is null then
      raise exception 'ACCESS_KEY_REQUIRED: Chave de acesso de 44 dígitos obrigatória.' using errcode = '22023';
    end if;
    v_key_check := public.validate_nfe_access_key_mod11(v_clean_key);
    if not coalesce((v_key_check ->> 'valid')::boolean, false) then
      raise exception 'INVALID_NFE_KEY_MOD11: Chave de 44 dígitos inválida (%).', (v_key_check ->> 'reason') using errcode = '22023';
    end if;
    v_clean_cnpj := v_key_check ->> 'emitter_cnpj';
    if p_sefaz_status_initial <> 100 then
      raise exception 'SEFAZ_NOT_AUTHORIZED: Documento fiscal não autorizado na SEFAZ (cStat = %).', p_sefaz_status_initial using errcode = 'P0001';
    end if;
  elsif p_fiscal_document_mode = 'MEI_RECEIPT_CGSN140' then
    if not public.validate_cnpj_mod11(v_clean_cnpj) then
      raise exception 'INVALID_MEI_CNPJ: CNPJ inválido (Módulo 11).' using errcode = '22023';
    end if;
    if not coalesce(p_emitter_cnae_compatible, false) then
      raise exception 'INCOMPATIBLE_EMITTER_CNAE: CNAE incompatível com materiais técnicos.' using errcode = 'P0001';
    end if;
    if p_declared_material_amount > 150.00 then
      raise exception 'SMART_FISCAL_CAP_EXCEEDED: Recibos MEI sem chave de 44 dígitos têm teto de R$ 150,00.' using errcode = 'P0001';
    end if;
  else
    raise exception 'UNSUPPORTED_FISCAL_DOCUMENT_MODE: %', p_fiscal_document_mode using errcode = '22023';
  end if;

  insert into public.job_fiscal_documents (
    job_id, provider_id, fiscal_document_mode, capture_channel,
    access_key_44, tp_amb, emitter_cnpj, emitter_cnae_compatible,
    receipt_number, declared_material_amount, ncm_codes,
    ela_tamper_score, receipt_photo_phash, sefaz_status_initial
  ) values (
    p_job_id, v_uid, p_fiscal_document_mode, p_capture_channel,
    v_clean_key, '1', v_clean_cnpj, p_emitter_cnae_compatible,
    p_receipt_number, p_declared_material_amount, coalesce(p_ncm_codes, '{}'),
    p_ela_tamper_score, p_receipt_photo_phash, p_sefaz_status_initial
  ) returning id into v_doc_id;

  return jsonb_build_object(
    'verified', true,
    'document_id', v_doc_id,
    'fiscal_document_mode', p_fiscal_document_mode,
    'emitter_cnpj', v_clean_cnpj,
    'exempt_material_amount', p_declared_material_amount,
    'smart_fiscal_cap_applied', (p_fiscal_document_mode = 'MEI_RECEIPT_CGSN140')
  );
end $$;

revoke all on function public.register_and_verify_material_fiscal_document(
  uuid, uuid, text, text, text, char(1), text, boolean, text, numeric(12,2), text[], numeric(5,4), bigint, int
) from public, anon;
grant execute on function public.register_and_verify_material_fiscal_document(
  uuid, uuid, text, text, text, char(1), text, boolean, text, numeric(12,2), text[], numeric(5,4), bigint, int
) to authenticated;

create or replace function public.record_component_custody_and_proof_of_leave(
  p_job_id uuid,
  p_provider_id uuid,
  p_material_split_scope text,
  p_appliance_nameplate_ocr text,
  p_insitu_connected_part_phash bigint,
  p_old_vs_new_part_macro_phash bigint,
  p_old_part_leave_photo_url text,
  p_old_part_leave_photo_phash bigint,
  p_old_part_disposal_authorized boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;
  if p_provider_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do profissional inválido.' using errcode = '42501';
  end if;

  select * into v_job
    from public.jobs
   where id = p_job_id
     and provider_id = v_uid
     for update;

  if not found then
    raise exception 'JOB_NOT_FOUND_OR_UNAUTHORIZED' using errcode = '42501';
  end if;

  if p_material_split_scope = 'COMPONENT_REPLACEMENT' then
    if coalesce(length(btrim(p_appliance_nameplate_ocr)), 0) < 4 then
      raise exception 'NAMEPLATE_OCR_REQUIRED: Identificação da etiqueta do equipamento obrigatória.' using errcode = '22023';
    end if;
    if p_insitu_connected_part_phash is null or p_old_vs_new_part_macro_phash is null then
      raise exception 'COMPONENT_MACRO_PHOTOS_REQUIRED: Fotos macro da peça antiga in-situ e comparativo são obrigatórias.' using errcode = '22023';
    end if;
    if p_old_part_leave_photo_phash is null and not coalesce(p_old_part_disposal_authorized, false) then
      raise exception 'PROOF_OF_LEAVE_REQUIRED: Registre a foto da peça antiga deixada no imóvel ou autorização de descarte.' using errcode = '22023';
    end if;
    if p_old_part_leave_photo_phash is not null
       and v_job.checkin_photo_phash is not null
       and public.hamming_distance_64(v_job.checkin_photo_phash, p_old_part_leave_photo_phash) < 5 then
      raise exception 'DUPLICATE_LEAVE_PHOTO: A foto de devolução da peça antiga não pode ser idêntica à foto de Check-in.' using errcode = 'P0001';
    end if;
  end if;

  update public.jobs
     set material_split_scope = p_material_split_scope,
         appliance_nameplate_ocr = p_appliance_nameplate_ocr,
         insitu_connected_part_phash = p_insitu_connected_part_phash,
         old_vs_new_part_macro_phash = p_old_vs_new_part_macro_phash,
         old_part_leave_photo_url = p_old_part_leave_photo_url,
         old_part_leave_photo_phash = p_old_part_leave_photo_phash,
         old_part_disposal_authorized = coalesce(p_old_part_disposal_authorized, false)
   where id = p_job_id;

  return jsonb_build_object(
    'recorded', true,
    'job_id', p_job_id,
    'material_split_scope', p_material_split_scope,
    'atomic_pin_proof_ready', true
  );
end $$;

revoke all on function public.record_component_custody_and_proof_of_leave(
  uuid, uuid, text, text, bigint, bigint, text, bigint, boolean
) from public, anon;
grant execute on function public.record_component_custody_and_proof_of_leave(
  uuid, uuid, text, text, bigint, bigint, text, bigint, boolean
) to authenticated;

create or replace function public.cancel_sos_with_displacement_slashing(
  p_job_id uuid,
  p_client_id uuid,
  p_provider_displaced_meters numeric,
  p_active_route_minutes numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid           uuid := auth.uid();
  v_job           record;
  v_total_amt     numeric(12,2);
  v_slashing_fee  numeric(12,2) := 0.00;
  v_client_refund numeric(12,2);
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;
  if p_client_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do cliente inválido.' using errcode = '42501';
  end if;

  select * into v_job
    from public.jobs
   where id = p_job_id
     and client_id = v_uid
     for update;

  if not found then
    raise exception 'JOB_NOT_FOUND_OR_UNAUTHORIZED' using errcode = '42501';
  end if;

  if coalesce(v_job.escrow_status, '') <> 'LOCKED_100' then
    raise exception 'INVALID_ESCROW_STATE_FOR_SOS_CANCEL: %', v_job.escrow_status using errcode = 'P0001';
  end if;

  v_total_amt := coalesce(v_job.agreed_price, coalesce(v_job.labor_amount, 0) + coalesce(v_job.materials_amount, 0));

  if v_job.provider_id is not null
     and (coalesce(p_provider_displaced_meters, 0) >= 250.0 or coalesce(p_active_route_minutes, 0) >= 4.0) then
    v_slashing_fee := least(
      v_total_amt,
      greatest(25.00, least(45.00, round(v_total_amt * 0.15, 2)))
    );
  end if;

  v_client_refund := greatest(0.00, v_total_amt - v_slashing_fee);

  update public.jobs
     set status = 'canceled',
         canceled_at = coalesce(canceled_at, now()),
         canceled_by = v_uid,
         escrow_status = 'REFUNDED_TO_CLIENT'
   where id = p_job_id;

  return jsonb_build_object(
    'canceled', true,
    'job_id', p_job_id,
    'slashing_fee_credited_to_provider', v_slashing_fee,
    'client_refund_amount', v_client_refund
  );
end $$;

revoke all on function public.cancel_sos_with_displacement_slashing(uuid, uuid, numeric, numeric) from public, anon;
grant execute on function public.cancel_sos_with_displacement_slashing(uuid, uuid, numeric, numeric) to authenticated;

-- [SEC-05] `verify_bilateral_copresence_handshake`: elimina segredo público `p_job_id::TEXT`
--          e exige que `auth.uid()` seja parte ativa (`client_id` ou `provider_id`) do atendimento.
create or replace function public.verify_bilateral_copresence_handshake(
  p_job_id uuid,
  p_stage text,
  p_totp_window_bucket bigint,
  p_provided_hmac_hex text,
  p_gnss_agc_cn0_valid boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid           uuid := auth.uid();
  v_job           public.jobs%rowtype;
  v_job_secret    text;
  v_master_secret bytea;
  v_hmac_key      bytea;
  v_expected_hmac text;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;

  if p_stage not in ('CHECKIN', 'CHECKOUT') then
    raise exception 'INVALID_COPRESENCE_STAGE: %', p_stage using errcode = '22023';
  end if;

  select * into v_job
    from public.jobs
   where id = p_job_id
     for update;

  if not found then
    raise exception 'JOB_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_uid is distinct from v_job.client_id and v_uid is distinct from v_job.provider_id then
    raise exception 'ERR_UNAUTHORIZED_COPRESENCE: Apenas o cliente ou o prestador do atendimento pode validar co-presença.' using errcode = '42501';
  end if;

  if not coalesce(p_gnss_agc_cn0_valid, false) then
    update public.jobs
       set gnss_agc_cn0_valid = false
     where id = p_job_id;
    raise exception 'SDR_GNSS_SPOOFING_DETECTED: Anomalia na razão física AGC x C/N0 das constelações GNSS.' using errcode = '42501';
  end if;

  select fs.job_presence_secret
    into v_job_secret
    from private.job_forensic_secrets fs
   where fs.job_id = p_job_id;

  if v_job_secret is not null and btrim(v_job_secret) <> '' then
    v_hmac_key := convert_to(v_job_secret, 'UTF8');
  else
    -- Chave derivada criptograficamente do segredo privado do servidor (NUNCA do UUID público!)
    select s.secret_key into v_master_secret from private.geo_privacy_secrets s where s.id = 1;
    v_hmac_key := hmac(convert_to('copresence:' || p_job_id::text, 'UTF8'), v_master_secret, 'sha256');
  end if;

  v_expected_hmac := encode(
    hmac(
      convert_to(p_job_id::text || '|' || p_stage || '|' || p_totp_window_bucket::text, 'UTF8'),
      v_hmac_key,
      'sha256'
    ),
    'hex'
  );

  if lower(btrim(coalesce(p_provided_hmac_hex, ''))) <> lower(v_expected_hmac) then
    raise exception 'COPRESENCE_HMAC_MISMATCH: Token de co-presença física inválido ou expirado.' using errcode = '42501';
  end if;

  if p_stage = 'CHECKIN' then
    update public.jobs
       set checkin_copresence_proof_hash = v_expected_hmac,
           gnss_agc_cn0_valid = true
     where id = p_job_id;
  else
    update public.jobs
       set checkout_copresence_proof_hash = v_expected_hmac,
           gnss_agc_cn0_valid = true
     where id = p_job_id;
  end if;

  return jsonb_build_object(
    'copresence_verified', true,
    'job_id', p_job_id,
    'stage', p_stage,
    'proof_hash', v_expected_hmac
  );
end $$;

revoke all on function public.verify_bilateral_copresence_handshake(uuid, text, bigint, text, boolean) from public, anon;
grant execute on function public.verify_bilateral_copresence_handshake(uuid, text, bigint, text, boolean) to authenticated;

comment on function public.verify_bilateral_copresence_handshake(uuid, text, bigint, text, boolean) is
  'Valida handshake bilateral TOTP/Ultrassom de co-presença física usando segredo privado em private.job_forensic_secrets / private.geo_privacy_secrets (anti-IDOR e anti-forja de UUID público).';

-- Restringe sobrecargas de oráculo/worker (`audit_sefaz_phase2_cancellation_and_clawback` e `trigger_layer3_rework(uuid)`)
do $$
begin
  if to_regprocedure('public.audit_sefaz_phase2_cancellation_and_clawback(uuid,integer)') is not null then
    execute 'alter function public.audit_sefaz_phase2_cancellation_and_clawback(uuid, integer) set search_path = public';
    execute 'revoke all on function public.audit_sefaz_phase2_cancellation_and_clawback(uuid, integer) from public, anon, authenticated';
  end if;

  if to_regprocedure('public.trigger_layer3_rework(uuid)') is not null then
    execute 'alter function public.trigger_layer3_rework(uuid) set search_path = public';
    execute 'revoke all on function public.trigger_layer3_rework(uuid) from public, anon, authenticated';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4. [SEC-07] Proteção de colunas sensíveis de `profiles` + Compatibilidade LGPD `purge_account`
-- -----------------------------------------------------------------------------
create or replace function public.profiles_protect_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.role is distinct from old.role then
      raise exception 'O papel do usuário não pode ser alterado.' using errcode = '42501';
    end if;
    if new.verification_status is distinct from old.verification_status then
      raise exception 'O status de verificação é controlado pelo sistema.' using errcode = '42501';
    end if;
    if new.is_client is distinct from old.is_client
       or new.is_provider is distinct from old.is_provider
       or new.client_setup_done is distinct from old.client_setup_done
       or new.provider_setup_done is distinct from old.provider_setup_done
       or new.last_mode is distinct from old.last_mode then
      raise exception 'Modo de uso controlado pelo sistema.' using errcode = '42501';
    end if;
    if new.cpf_hash is distinct from old.cpf_hash
       or new.cpf_masked is distinct from old.cpf_masked
       or new.face_liveness_hash is distinct from old.face_liveness_hash
       or new.kyc_biometric_verified is distinct from old.kyc_biometric_verified
       or new.liveness_verified is distinct from old.liveness_verified
       or new.ocr_verified is distinct from old.ocr_verified
       or new.client_kyc_status is distinct from old.client_kyc_status
       or new.trust_tier is distinct from old.trust_tier
       or new.external_trust_score is distinct from old.external_trust_score
       or new.waterfall_tier_rank is distinct from old.waterfall_tier_rank
       or new.available_wallet_balance is distinct from old.available_wallet_balance
       or new.maturing_wallet_balance is distinct from old.maturing_wallet_balance
       or new.clawback_debt_balance is distinct from old.clawback_debt_balance
       or new.has_open_dispute is distinct from old.has_open_dispute then
      raise exception 'Atributos forenses, biométricos e financeiros são controlados exclusivamente pelo servidor.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

revoke all on function public.profiles_protect_columns() from public, anon, authenticated;

-- Preserva imutabilidade pós-conclusão contra usuários/prestadores sem quebrar o expurgo LGPD (`purge_account`)
create or replace function public.jobs_enforce_post_completion_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_lgpd_client_purge boolean := (
    current_user not in ('authenticated', 'anon')
    and old.client_id is not null
    and new.client_id is null
    and new.description = '[conteúdo removido a pedido do titular]'
  );
  v_is_lgpd_provider_purge boolean := (
    current_user not in ('authenticated', 'anon')
    and new.provider_report is null
    and old.provider_report is not null
  );
begin
  if old.status = 'completed' then
    if new.description is distinct from old.description and not v_is_lgpd_client_purge then
      raise exception 'IMMUTABLE_CLIENT_REQUEST: A descrição original solicitada pelo cliente não pode ser alterada após a conclusão.' using errcode = '42501';
    end if;
    if old.provider_report is not null
       and new.provider_report is distinct from old.provider_report
       and not v_is_lgpd_provider_purge then
      raise exception 'IMMUTABLE_CONCLUSION_REPORT: O laudo técnico original da conclusão é imutável por segurança. Utilize as Notas Técnicas Complementares.' using errcode = '42501';
    end if;
    if new.photo_paths is distinct from old.photo_paths and not v_is_lgpd_client_purge then
      raise exception 'IMMUTABLE_JOB_PHOTOS: As fotos originais do chamado concluído não podem ser alteradas ou excluídas.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

revoke all on function public.jobs_enforce_post_completion_immutability() from public, anon, authenticated;

create or replace function public.job_evidence_enforce_post_completion_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  -- Permite deleção apenas pela rotina interna `purge_account` (service_role/owner) em exercício de direito LGPD
  if tg_op = 'DELETE' and current_user not in ('authenticated', 'anon') then
    return old;
  end if;

  select j.status into v_status from public.jobs j where j.id = coalesce(old.job_id, new.job_id);
  if v_status = 'completed' then
    raise exception 'IMMUTABLE_EVIDENCE_PHOTOS: As fotos registradas na conclusão do serviço são imutáveis e não podem ser removidas ou alteradas.' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end $$;

revoke all on function public.job_evidence_enforce_post_completion_immutability() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. [SEC-08] Fixação de `search_path = public` e `REVOKE FROM public, anon` global
-- -----------------------------------------------------------------------------
do $$
declare
  v_sig text;
  v_fn_sigs text[] := array[
    'public.set_updated_at()',
    'public.ranking_min_reviews()',
    'public._short_name(text)',
    'public._crc16(text)',
    'public._tlv(text,text)',
    'public._brcode(text,bigint)',
    'public.haversine_m(double precision,double precision,double precision,double precision)',
    'public.safe_name(text,text)',
    'public.server_time()',
    'public.norm_tag(text)',
    'public.norm_tags(text[])',
    'public.hamming_distance_64(bigint,bigint)',
    'public.calculate_relative_trust_score(boolean,integer,boolean,integer,integer)',
    'public.trg_sync_profile_trust_and_rank()',
    'public.is_valid_cpf(text)',
    'public.validate_cnpj_mod11(text)',
    'public.validate_nfe_access_key_mod11(text)'
  ];
  v_internal_triggers text[] := array[
    'public.handle_new_user()',
    'public.quotes_before_insert()',
    'public.quotes_after_insert()',
    'public._profiles_wallet()',
    'public._payments_hold_before()',
    'public._payments_hold_after()',
    'public._payments_settle()',
    'public._withdrawals_ledger()',
    'public.trg_sync_profile_trust_and_rank()'
  ];
begin
  foreach v_sig in array v_fn_sigs loop
    if to_regprocedure(v_sig) is not null then
      execute format('alter function %s set search_path = public', v_sig);
    end if;
  end loop;

  foreach v_sig in array v_internal_triggers loop
    if to_regprocedure(v_sig) is not null then
      execute format('revoke all on function %s from public, anon, authenticated', v_sig);
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 6. [SEC-09] Storage Forense Privado (`forensic-evidence`, `public = false` + RLS por job)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forensic-evidence',
  'forensic-evidence',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function public._extract_forensic_job_id(p_object_name text)
returns uuid
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  v_clean text := btrim(coalesce(p_object_name, ''), '/');
  v_parts text[];
  v_uuid_re constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  if v_clean = '' or position('..' in v_clean) > 0 then
    return null;
  end if;

  v_parts := string_to_array(v_clean, '/');

  -- Padrão canônico: `evidence/<job_id>/<arquivo>.<ext>`
  if coalesce(array_length(v_parts, 1), 0) >= 3
     and v_parts[1] = 'evidence'
     and v_parts[2] ~* v_uuid_re then
    return v_parts[2]::uuid;
  end if;

  -- Padrão alternativo prefixado por uid: `<uid>/evidence/<job_id>/<arquivo>.<ext>`
  if coalesce(array_length(v_parts, 1), 0) >= 4
     and v_parts[2] = 'evidence'
     and v_parts[3] ~* v_uuid_re then
    return v_parts[3]::uuid;
  end if;

  -- Padrão curto por pasta de job: `<job_id>/<arquivo>.<ext>`
  if coalesce(array_length(v_parts, 1), 0) >= 2
     and v_parts[1] ~* v_uuid_re then
    return v_parts[1]::uuid;
  end if;

  return null;
end $$;

revoke all on function public._extract_forensic_job_id(text) from public, anon;
grant execute on function public._extract_forensic_job_id(text) to authenticated;

comment on function public._extract_forensic_job_id(text) is
  'Extrai com segurança o job_id de um caminho no bucket privado forensic-evidence (suporta evidence/<jobId>/<file>, <uid>/evidence/<jobId>/<file> ou <jobId>/<file>; bloqueia path traversal).';

create or replace function public._can_access_forensic_evidence(
  p_object_name text,
  p_for_write boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_job_id uuid;
  v_job    public.jobs%rowtype;
begin
  if v_uid is null then
    return false;
  end if;

  if p_for_write and coalesce(p_object_name, '') !~* '\.(jpe?g|png|webp)$' then
    return false;
  end if;

  if not p_for_write and public.is_admin() then
    return true;
  end if;

  v_job_id := public._extract_forensic_job_id(p_object_name);
  if v_job_id is null then
    return false;
  end if;

  select * into v_job from public.jobs where id = v_job_id;
  if not found then
    return false;
  end if;

  if v_job.client_id = v_uid or v_job.provider_id = v_uid or public.is_admin() then
    return true;
  end if;

  if exists (
    select 1
      from public.job_mediations m
     where m.job_id = v_job_id
       and (m.original_provider_id = v_uid or m.rescuer_provider_id = v_uid)
  ) then
    return true;
  end if;

  return false;
end $$;

revoke all on function public._can_access_forensic_evidence(text, boolean) from public, anon;
grant execute on function public._can_access_forensic_evidence(text, boolean) to authenticated;

comment on function public._can_access_forensic_evidence(text, boolean) is
  'Autorização RLS por job para o bucket privado forensic-evidence: somente cliente titular, prestador alocado, partes de mediação de garantia ou admin acessam via URL assinada (createSignedUrl).';

drop policy if exists "forensic_evidence_insert" on storage.objects;
drop policy if exists "forensic_evidence_select" on storage.objects;
drop policy if exists "forensic_evidence_update" on storage.objects;
drop policy if exists "forensic_evidence_delete_admin" on storage.objects;

create policy "forensic_evidence_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'forensic-evidence'
    and public._can_access_forensic_evidence(name, true)
  );

create policy "forensic_evidence_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'forensic-evidence'
    and public._can_access_forensic_evidence(name, false)
  );

create policy "forensic_evidence_delete_admin" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'forensic-evidence'
    and public.is_admin()
  );

commit;

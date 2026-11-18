-- =============================================================================
-- DESPERRENGUE — Cofre KYC Unificado Semestral (6 Meses), Certidão de
-- Antecedentes Criminais (Polícia Federal SINIC/ePol), Termos Bivalentes por
-- Papel, Trava Anti-Recobrança de API e Marco Zero de Usuários do Marketplace
-- (Preservando Estritamente o Cofre Soberano do CEO `wagneroliveira2395@gmail.com`)
--
-- Migration: 20261118150000_unified_6m_kyc_criminal_check_role_terms_and_marketplace_reset.sql
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Bucket Privado `kyc-documents`: suporte seguro a PDF oficial da Polícia
--    Federal além de imagens higienizadas (`public = false` preservado)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'kyc-documents',
  'kyc-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- 2. Extensão de `public.profiles`: Ciclo Semestral (6 Meses), Antecedentes
--    Criminais, Trava Anti-Recobrança de API e Termos Bivalentes por Papel
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists kyc_expires_at timestamptz,
  add column if not exists kyc_validation_cycle integer not null default 0,
  add column if not exists kyc_billing_lock_until timestamptz,
  add column if not exists criminal_record_verified boolean not null default false,
  add column if not exists criminal_record_verified_at timestamptz,
  add column if not exists criminal_record_expires_at timestamptz,
  add column if not exists criminal_certificate_number_masked text,
  add column if not exists criminal_certificate_sha256 char(64),
  add column if not exists client_terms_accepted boolean not null default false,
  add column if not exists client_terms_accepted_at timestamptz,
  add column if not exists client_terms_version text,
  add column if not exists provider_terms_accepted boolean not null default false,
  add column if not exists provider_terms_accepted_at timestamptz,
  add column if not exists provider_terms_version text;

alter table public.profiles
  drop constraint if exists profiles_kyc_validation_cycle_check;

alter table public.profiles
  add constraint profiles_kyc_validation_cycle_check
  check (kyc_validation_cycle >= 0);

alter table public.profiles
  drop constraint if exists profiles_criminal_cert_sha256_check;

alter table public.profiles
  add constraint profiles_criminal_cert_sha256_check
  check (
    criminal_certificate_sha256 is null
    or criminal_certificate_sha256 ~ '^[0-9a-f]{64}$'
  );

create index if not exists idx_profiles_kyc_expires_at
  on public.profiles (kyc_expires_at)
  where kyc_expires_at is not null;

-- Blindagem de colunas sensíveis no trigger `public.profiles_protect_columns()`
-- (SECURITY INVOKER: bloqueia escrita direta por `authenticated`/`anon` e
--  permite escrita exclusivamente via RPCs `SECURITY DEFINER` auditadas).
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
       or new.kyc_verified_at is distinct from old.kyc_verified_at
       or new.kyc_expires_at is distinct from old.kyc_expires_at
       or new.kyc_validation_cycle is distinct from old.kyc_validation_cycle
       or new.kyc_billing_lock_until is distinct from old.kyc_billing_lock_until
       or new.criminal_record_verified is distinct from old.criminal_record_verified
       or new.criminal_record_verified_at is distinct from old.criminal_record_verified_at
       or new.criminal_record_expires_at is distinct from old.criminal_record_expires_at
       or new.criminal_certificate_number_masked is distinct from old.criminal_certificate_number_masked
       or new.criminal_certificate_sha256 is distinct from old.criminal_certificate_sha256
       or new.client_terms_accepted is distinct from old.client_terms_accepted
       or new.client_terms_accepted_at is distinct from old.client_terms_accepted_at
       or new.client_terms_version is distinct from old.client_terms_version
       or new.provider_terms_accepted is distinct from old.provider_terms_accepted
       or new.provider_terms_accepted_at is distinct from old.provider_terms_accepted_at
       or new.provider_terms_version is distinct from old.provider_terms_version
       or new.trust_tier is distinct from old.trust_tier
       or new.external_trust_score is distinct from old.external_trust_score
       or new.waterfall_tier_rank is distinct from old.waterfall_tier_rank
       or new.available_wallet_balance is distinct from old.available_wallet_balance
       or new.maturing_wallet_balance is distinct from old.maturing_wallet_balance
       or new.clawback_debt_balance is distinct from old.clawback_debt_balance
       or new.has_open_dispute is distinct from old.has_open_dispute then
      raise exception 'Atributos forenses, biométricos, criminais, contratuais e financeiros são controlados exclusivamente pelo servidor.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

revoke all on function public.profiles_protect_columns() from public, anon, authenticated;

drop trigger if exists profiles_protect_columns on public.profiles;
create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function public.profiles_protect_columns();

-- -----------------------------------------------------------------------------
-- 3. Nova Tabela Forense `public.criminal_background_checks`
--    (RLS ENABLE + FORCE, Zero escrita direta, Anti-Replay `file_sha256` entre contas)
-- -----------------------------------------------------------------------------
create table if not exists public.criminal_background_checks (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid not null references public.profiles(id) on delete cascade,
  validation_cycle            integer not null default 1 check (validation_cycle >= 1),
  certificate_protocol_masked text not null check (btrim(certificate_protocol_masked) <> ''),
  issuing_organ               text not null default 'POLICIA_FEDERAL_SINIC' check (btrim(issuing_organ) <> ''),
  certificate_issued_date     date not null,
  validation_code_hash        char(64) not null check (validation_code_hash ~ '^[0-9a-f]{64}$'),
  file_storage_path           text not null check (btrim(file_storage_path) <> ''),
  file_sha256                 char(64) not null check (file_sha256 ~ '^[0-9a-f]{64}$'),
  holder_cpf_hash             text not null check (btrim(holder_cpf_hash) <> ''),
  holder_name_normalized      text not null check (btrim(holder_name_normalized) <> ''),
  outcome                     text not null check (outcome in ('NOTHING_ON_RECORD', 'REJECTED')),
  verified_at                 timestamptz not null default timezone('utc', now()),
  expires_at                  timestamptz not null
);

create index if not exists idx_criminal_background_checks_user_cycle
  on public.criminal_background_checks (user_id, verified_at desc);

-- Índice dedicado anti-replay sobre `file_sha256` para verificação O(log N) entre contas distintas
create index if not exists idx_criminal_background_checks_file_sha256
  on public.criminal_background_checks (file_sha256, user_id);

alter table public.criminal_background_checks enable row level security;
alter table public.criminal_background_checks force row level security;

revoke all on table public.criminal_background_checks from public, anon, authenticated;
grant select on table public.criminal_background_checks to authenticated;

drop policy if exists criminal_background_checks_select_own_or_admin on public.criminal_background_checks;
create policy criminal_background_checks_select_own_or_admin
  on public.criminal_background_checks
  for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

create or replace function public.trg_criminal_checks_anti_replay()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('crim_sha256:' || new.file_sha256, 0));

  if exists (
    select 1
      from public.criminal_background_checks c
     where c.file_sha256 = new.file_sha256
       and c.user_id <> new.user_id
  ) then
    raise exception 'ERR_CRIMINAL_CERT_REPLAY_ACROSS_ACCOUNTS: Este arquivo de certidão já foi utilizado por outra conta na plataforma.'
      using errcode = '23505';
  end if;

  return new;
end $$;

revoke all on function public.trg_criminal_checks_anti_replay() from public, anon, authenticated;

drop trigger if exists zz_criminal_checks_anti_replay_biu on public.criminal_background_checks;
create trigger zz_criminal_checks_anti_replay_biu
  before insert or update on public.criminal_background_checks
  for each row execute function public.trg_criminal_checks_anti_replay();

-- -----------------------------------------------------------------------------
-- 4. Predicados e RPCs `SECURITY DEFINER` do Ciclo Semestral (6 Meses)
-- -----------------------------------------------------------------------------
create or replace function public.is_kyc_cycle_currently_valid(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_caller uuid := auth.uid();
  v_role   text := coalesce(auth.role(), '');
begin
  if p_user_id is null then
    return false;
  end if;

  if v_role in ('authenticated', 'anon')
     and v_caller is distinct from p_user_id
     and not public.is_admin() then
    return false;
  end if;

  return exists (
    select 1
      from public.profiles p
     where p.id = p_user_id
       and p.kyc_verified_at is not null
       and p.kyc_expires_at is not null
       and p.kyc_expires_at > timezone('utc', now())
       and p.criminal_record_verified = true
       and p.criminal_record_expires_at is not null
       and p.criminal_record_expires_at > timezone('utc', now())
  );
end $$;

revoke all on function public.is_kyc_cycle_currently_valid(uuid) from public, anon;
grant execute on function public.is_kyc_cycle_currently_valid(uuid) to authenticated, service_role;

comment on function public.is_kyc_cycle_currently_valid(uuid) is
  'Verifica se o ciclo semestral (6 meses) de KYC biométrico + Certidão de Antecedentes Criminais do titular está ativo e não expirado.';

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
       and (kyc_expires_at is null or kyc_expires_at > timezone('utc', now()))
  );
$$;

revoke all on function public.is_public_provider(uuid) from public, anon;
grant execute on function public.is_public_provider(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. RPC Transacional Unificado `public.submit_unified_kyc_v2`
--    - Primeiro cadastro (Cliente ou Profissional) ou Renovação de 6 Meses
--    - Trava Anti-Dupla Cobrança: se o ciclo atual já está válido e `not p_is_renewal`,
--      sincroniza papel/termos sem gravar nova submissão faturável (`api_billed: false`)
-- -----------------------------------------------------------------------------
create or replace function public.submit_unified_kyc_v2(
  p_target_mode text default 'client',
  p_is_renewal boolean default false,
  p_cpf_raw text default null,
  p_typed_full_name text default null,
  p_ocr_full_name text default null,
  p_phone text default null,
  p_document_type text default 'CNH',
  p_document_number_masked text default null,
  p_birth_date date default null,
  p_issuing_authority text default null,
  p_address_line text default null,
  p_address_city text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_doc_front_url text default null,
  p_doc_back_url text default null,
  p_selfie_url text default null,
  p_doc_front_phash bigint default null,
  p_doc_back_phash bigint default null,
  p_selfie_phash bigint default null,
  p_liveness_score numeric default 0,
  p_face_liveness_hash text default null,
  p_ocr_confidence numeric default 0,
  p_laplacian_sharpness numeric default 120,
  p_glare_ratio_pct numeric default 0,
  p_face_match_similarity numeric default 0,
  p_liveness_challenges jsonb default '[]'::jsonb,
  p_criminal_file_path text default null,
  p_criminal_file_sha256 text default null,
  p_criminal_protocol text default null,
  p_criminal_issued_date date default null,
  p_criminal_validation_code text default null,
  p_criminal_outcome text default 'NOTHING_ON_RECORD',
  p_terms_version text default '2026.11-CLIENT-V2',
  p_terms_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid            uuid := auth.uid();
  v_now            timestamptz := timezone('utc', now());
  v_today_br       date := (timezone('utc', now()) at time zone 'America/Sao_Paulo')::date;
  v_mode           text := lower(btrim(coalesce(p_target_mode, 'client')));
  v_terms_ver      text := left(btrim(coalesce(p_terms_version, '')), 40);
  v_terms_sha      text := lower(btrim(coalesce(p_terms_sha256, '')));
  v_role_scope     text;
  v_prof           public.profiles%rowtype;
  v_digits         text;
  v_cpf_hash       text;
  v_cpf_masked     text;
  v_hamming_docs   integer;
  v_crim_sha       text;
  v_crim_path      text;
  v_crim_outcome   text;
  v_proto_clean    text;
  v_proto_masked   text;
  v_val_code_clean text;
  v_val_code_hash  char(64);
  v_holder_norm    text;
  v_new_cycle      integer;
  v_expires        timestamptz;
  v_doc_norm       text;
  v_front_safe     text;
  v_back_safe      text;
  v_selfie_safe    text;
  v_submission_id  uuid;
  v_crim_check_id  uuid;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada ou usuário não autenticado.'
      using errcode = '28000';
  end if;

  if v_mode not in ('client', 'provider') then
    raise exception 'ERR_INVALID_TARGET_MODE: Modo de destino inválido (%).', v_mode
      using errcode = '22023';
  end if;

  if v_terms_ver = '' then
    raise exception 'ERR_INVALID_MANDATE_VERSION: Versão dos termos obrigatória.'
      using errcode = '22023';
  end if;

  if v_terms_sha !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_INVALID_MANDATE_SHA256: Assinatura SHA-256 dos termos inválida.'
      using errcode = '22023';
  end if;

  v_role_scope := case when v_mode = 'provider' then 'PROVIDER' else 'CLIENT' end;

  select * into v_prof
    from public.profiles
   where id = v_uid
     for update;

  if not found then
    raise exception 'ERR_PROFILE_NOT_FOUND: Perfil de usuário não localizado.'
      using errcode = 'P0002';
  end if;

  -- ===========================================================================
  -- TRAVA ANTI-DUPLA COBRANÇA DE API / ZERO REENVIO DESNECESSÁRIO:
  -- Se o ciclo semestral (6 meses) já está válido e não é renovação explícita,
  -- sincroniza apenas modo + termos sem gravar nova submissão faturável!
  -- ===========================================================================
  if public.is_kyc_cycle_currently_valid(v_uid) and not coalesce(p_is_renewal, false) then
    insert into public.legal_mandate_acceptances (
      user_id,
      mandate_version,
      document_sha256,
      role_scope
    ) values (
      v_uid,
      v_terms_ver,
      v_terms_sha::char(64),
      v_role_scope
    )
    on conflict (user_id, mandate_version, role_scope) do update
      set document_sha256 = excluded.document_sha256;

    if v_mode = 'client' then
      update public.profiles
         set is_client = true,
             client_setup_done = true,
             client_terms_accepted = true,
             client_terms_accepted_at = coalesce(client_terms_accepted_at, v_now),
             client_terms_version = v_terms_ver,
             last_mode = 'client',
             updated_at = v_now
       where id = v_uid;
    else
      update public.profiles
         set is_provider = true,
             verification_status = 'ACTIVE'::public.verification_status,
             provider_terms_accepted = true,
             provider_terms_accepted_at = coalesce(provider_terms_accepted_at, v_now),
             provider_terms_version = v_terms_ver,
             last_mode = 'provider',
             updated_at = v_now
       where id = v_uid;

      insert into public.provider_profiles (user_id)
      values (v_uid)
      on conflict (user_id) do nothing;
    end if;

    begin
      perform private.emit_ceo_live_event_safe(
        'KYC_VALID_CYCLE_REUSED_ZERO_COST',
        'SUCCESS',
        'Ciclo KYC 6M reaproveitado sem custo de API (' || v_role_scope || ')',
        public.safe_name(v_prof.full_name, 'Usuário') || ' · Ciclo #' || coalesce(v_prof.kyc_validation_cycle, 1)::text,
        'profiles',
        v_uid::text,
        0,
        jsonb_build_object(
          'user_id', v_uid,
          'target_mode', v_mode,
          'reused_valid_kyc', true,
          'api_billed', false
        )
      );
    exception when others then
      null;
    end;

    return jsonb_build_object(
      'ok', true,
      'status', 'APPROVED',
      'target_mode', v_mode,
      'reused_valid_kyc', true,
      'api_billed', false,
      'kyc_validation_cycle', v_prof.kyc_validation_cycle,
      'kyc_expires_at', v_prof.kyc_expires_at,
      'criminal_record_expires_at', v_prof.criminal_record_expires_at
    );
  end if;

  -- ===========================================================================
  -- VALIDAÇÃO COMPLETA (1ª CONTA OU RENOVAÇÃO SEMESTRAL DE 6 MESES)
  -- ===========================================================================
  v_digits := regexp_replace(coalesce(p_cpf_raw, ''), '\D', '', 'g');
  if not public.is_valid_cpf(v_digits) then
    raise exception 'ERR_INVALID_CPF_MOD11: O CPF informado é matematicamente inválido.'
      using errcode = '22023';
  end if;

  v_cpf_hash := encode(extensions.digest('DSP-CPF-PEPPER-2026:' || v_digits, 'sha256'), 'hex');
  v_cpf_masked := '***.' || substring(v_digits, 4, 3) || '.' || substring(v_digits, 7, 3) || '-**';

  -- Anti-Sybil: bloqueia reutilização de CPF por conta distinta
  if exists (
    select 1
      from public.profiles p_dup
     where p_dup.cpf_hash = v_cpf_hash
       and p_dup.id <> v_uid
  ) then
    raise exception 'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta ativa na plataforma.'
      using errcode = '23505';
  end if;

  -- Na renovação semestral, garante continuidade estrita de titularidade do CPF
  if v_prof.cpf_hash is not null and v_prof.cpf_hash <> v_cpf_hash then
    raise exception 'ERR_RENEWAL_CPF_MISMATCH: Na renovação semestral, o documento deve pertencer ao mesmo CPF titular da conta.'
      using errcode = '42501';
  end if;

  if coalesce(btrim(p_face_liveness_hash), '') <> '' and exists (
    select 1
      from public.profiles p_face
     where p_face.face_liveness_hash = btrim(p_face_liveness_hash)
       and p_face.id <> v_uid
  ) then
    raise exception 'ERR_DUPLICATE_BIOMETRIC_FACE: Esta biometria facial já está vinculada a outra conta ativa na plataforma.'
      using errcode = '23505';
  end if;

  if p_doc_front_phash is null or p_doc_back_phash is null then
    raise exception 'ERR_DOCUMENT_PHASH_MISSING: Fotos da frente e do verso do documento oficial são obrigatórias.'
      using errcode = '22023';
  end if;

  v_hamming_docs := public.hamming_distance_64(p_doc_front_phash, p_doc_back_phash);
  if v_hamming_docs < 5 then
    raise exception 'ERR_DUPLICATE_FRONT_BACK_PHOTO: A foto do verso do documento é idêntica à foto da frente (Hamming=% < 5).', v_hamming_docs
      using errcode = 'P0001';
  end if;

  if coalesce(p_laplacian_sharpness, 0) < 110.0 then
    raise exception 'ERR_BLURRY_DOCUMENT_IMAGE: Imagem do documento sem nitidez suficiente (Score=% < 110).', p_laplacian_sharpness
      using errcode = 'P0001';
  end if;

  if coalesce(p_glare_ratio_pct, 100.0) > 8.5 then
    raise exception 'ERR_EXCESSIVE_GLARE: Reflexo de luz excessivo sobre os dados do documento (% > 8.5%%).', p_glare_ratio_pct
      using errcode = 'P0001';
  end if;

  if coalesce(p_liveness_score, 0) < 85.0 then
    raise exception 'ERR_LIVENESS_FAILED: Prova de vida facial não atingiu o índice mínimo de segurança (% < 85%%).', p_liveness_score
      using errcode = 'P0001';
  end if;

  if coalesce(p_face_match_similarity, 0) < 0.7800 then
    raise exception 'ERR_FACE_MISMATCH: A biometria facial capturada ao vivo não corresponde à foto do documento enviado.'
      using errcode = 'P0001';
  end if;

  -- Validação Forense da Certidão de Antecedentes Criminais (Polícia Federal SINIC/ePol)
  v_crim_sha := lower(btrim(coalesce(p_criminal_file_sha256, '')));
  if v_crim_sha !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_CRIMINAL_FILE_SHA256_INVALID: Hash SHA-256 do arquivo de antecedentes criminais inválido.'
      using errcode = '22023';
  end if;

  v_crim_path := btrim(coalesce(p_criminal_file_path, ''));
  if v_crim_path = ''
     or split_part(v_crim_path, '/', 1) <> v_uid::text
     or position('..' in v_crim_path) > 0 then
    raise exception 'ERR_CRIMINAL_FILE_PATH_INVALID: Caminho do arquivo de antecedentes inválido para o titular autenticado.'
      using errcode = '42501';
  end if;

  v_crim_outcome := upper(btrim(coalesce(p_criminal_outcome, '')));
  if v_crim_outcome <> 'NOTHING_ON_RECORD' then
    raise exception 'ERR_CRIMINAL_RECORD_NOT_CLEAR: A Certidão de Antecedentes Criminais deve atestar NADA CONSTA / NÃO CONSTA vigente.'
      using errcode = 'P0001';
  end if;

  if p_criminal_issued_date is null then
    raise exception 'ERR_CRIMINAL_ISSUED_DATE_REQUIRED: A data de emissão da certidão da Polícia Federal é obrigatória.'
      using errcode = '22023';
  end if;

  if p_criminal_issued_date > (v_today_br + 1) then
    raise exception 'ERR_CRIMINAL_ISSUED_IN_FUTURE: Data de emissão da certidão não pode estar no futuro.'
      using errcode = '22023';
  end if;

  if (v_today_br - p_criminal_issued_date) > 90 then
    raise exception 'ERR_CRIMINAL_CERTIFICATE_EXPIRED_90D: A Certidão de Antecedentes Criminais foi emitida há mais de 90 dias. Emita uma nova certidão gratuita no portal da Polícia Federal.'
      using errcode = 'P0001';
  end if;

  v_proto_clean := regexp_replace(btrim(coalesce(p_criminal_protocol, '')), '[^A-Za-z0-9./\-]', '', 'g');
  if char_length(v_proto_clean) < 6 then
    raise exception 'ERR_CRIMINAL_PROTOCOL_INVALID: Número de certidão/protocolo da Polícia Federal inválido.'
      using errcode = '22023';
  end if;
  v_proto_masked := 'PF-***' || right(v_proto_clean, 4);

  v_val_code_clean := btrim(coalesce(p_criminal_validation_code, ''));
  if char_length(v_val_code_clean) < 4 then
    raise exception 'ERR_CRIMINAL_VALIDATION_CODE_INVALID: Código de validação eletrônica da Polícia Federal inválido.'
      using errcode = '22023';
  end if;
  v_val_code_hash := lower(
    encode(extensions.digest(convert_to('DSP-PF-VAL-2026:' || upper(v_val_code_clean), 'UTF8'), 'sha256'), 'hex')
  )::char(64);

  -- Anti-Replay de arquivo de certidão entre contas distintas
  if exists (
    select 1
      from public.criminal_background_checks c_dup
     where c_dup.file_sha256 = v_crim_sha::char(64)
       and c_dup.user_id <> v_uid
  ) then
    raise exception 'ERR_CRIMINAL_CERT_REPLAY_ACROSS_ACCOUNTS: Este arquivo de certidão já foi utilizado por outra conta na plataforma.'
      using errcode = '23505';
  end if;

  v_new_cycle := coalesce(v_prof.kyc_validation_cycle, 0) + 1;
  v_expires := v_now + interval '6 months';

  v_doc_norm := case
    when upper(btrim(coalesce(p_document_type, ''))) in ('CPF', 'CNH', 'RG', 'CIN')
      then upper(btrim(p_document_type))
    else 'CNH'
  end;

  v_front_safe := coalesce(nullif(btrim(p_doc_front_url), ''), v_uid::text || '/unified_front_' || v_new_cycle::text || '.jpg');
  v_back_safe := coalesce(nullif(btrim(p_doc_back_url), ''), v_uid::text || '/unified_back_' || v_new_cycle::text || '.jpg');
  v_selfie_safe := coalesce(nullif(btrim(p_selfie_url), ''), v_uid::text || '/unified_selfie_' || v_new_cycle::text || '.jpg');

  v_holder_norm := upper(
    btrim(
      coalesce(
        nullif(btrim(p_ocr_full_name), ''),
        nullif(btrim(p_typed_full_name), ''),
        v_prof.full_name
      )
    )
  );

  -- 1. Grava submissão forense em `public.kyc_submissions`
  insert into public.kyc_submissions (
    user_id,
    front_path,
    back_path,
    selfie_path,
    doc_front_url,
    doc_back_url,
    selfie_url,
    registry_type,
    registry_number,
    role_scope,
    document_type,
    doc_front_phash,
    doc_back_phash,
    selfie_liveness_phash,
    liveness_challenges_passed,
    ocr_extracted_payload,
    laplacian_sharpness_score,
    glare_ratio_pct,
    face_match_cosine_similarity,
    status,
    reviewed_at
  ) values (
    v_uid,
    v_front_safe,
    v_back_safe,
    v_selfie_safe,
    v_front_safe,
    v_back_safe,
    v_selfie_safe,
    'Outro',
    v_cpf_masked,
    case
      when coalesce(v_prof.is_client, false) and coalesce(v_prof.is_provider, false) then 'both'
      when v_mode = 'provider' then 'provider'
      else 'client'
    end,
    v_doc_norm,
    p_doc_front_phash,
    p_doc_back_phash,
    p_selfie_phash,
    coalesce(p_liveness_challenges, '[]'::jsonb),
    jsonb_build_object(
      'typed_name', p_typed_full_name,
      'ocr_name', v_holder_norm,
      'cpf_masked', v_cpf_masked,
      'document_number_masked', p_document_number_masked,
      'birth_date', p_birth_date,
      'issuing_authority', p_issuing_authority,
      'ocr_confidence', p_ocr_confidence,
      'validation_cycle', v_new_cycle,
      'is_renewal', coalesce(p_is_renewal, false),
      'criminal_protocol_masked', v_proto_masked,
      'criminal_file_sha256', v_crim_sha
    ),
    p_laplacian_sharpness,
    p_glare_ratio_pct,
    least(1.0000, greatest(0.0000, round(p_face_match_similarity, 4))),
    'APPROVED',
    v_now
  )
  returning id into v_submission_id;

  -- 2. Grava auditoria de Antecedentes Criminais em `public.criminal_background_checks`
  insert into public.criminal_background_checks (
    user_id,
    validation_cycle,
    certificate_protocol_masked,
    issuing_organ,
    certificate_issued_date,
    validation_code_hash,
    file_storage_path,
    file_sha256,
    holder_cpf_hash,
    holder_name_normalized,
    outcome,
    verified_at,
    expires_at
  ) values (
    v_uid,
    v_new_cycle,
    v_proto_masked,
    'POLICIA_FEDERAL_SINIC',
    p_criminal_issued_date,
    v_val_code_hash,
    v_crim_path,
    v_crim_sha::char(64),
    v_cpf_hash,
    v_holder_norm,
    'NOTHING_ON_RECORD',
    v_now,
    v_expires
  )
  returning id into v_crim_check_id;

  -- 3. Grava aceite contratual criptográfico em `public.legal_mandate_acceptances`
  insert into public.legal_mandate_acceptances (
    user_id,
    mandate_version,
    document_sha256,
    role_scope
  ) values (
    v_uid,
    v_terms_ver,
    v_terms_sha::char(64),
    v_role_scope
  )
  on conflict (user_id, mandate_version, role_scope) do update
    set document_sha256 = excluded.document_sha256;

  -- 4. Carimba `public.profiles` para o ciclo de 6 meses
  update public.profiles
     set full_name                          = coalesce(nullif(btrim(p_typed_full_name), ''), full_name),
         verified_full_name                 = v_holder_norm,
         phone                              = coalesce(nullif(btrim(p_phone), ''), phone),
         cpf_masked                         = v_cpf_masked,
         cpf_hash                           = v_cpf_hash,
         document_type                      = v_doc_norm,
         document_number_masked             = coalesce(nullif(btrim(p_document_number_masked), ''), document_number_masked),
         birth_date                         = coalesce(p_birth_date, birth_date),
         issuing_authority                  = coalesce(nullif(btrim(p_issuing_authority), ''), issuing_authority),
         address_line                       = coalesce(nullif(btrim(p_address_line), ''), address_line),
         address_city                       = coalesce(nullif(btrim(p_address_city), ''), address_city),
         latitude                           = coalesce(p_latitude, latitude),
         longitude                          = coalesce(p_longitude, longitude),
         last_latitude                      = coalesce(p_latitude, last_latitude),
         last_longitude                     = coalesce(p_longitude, last_longitude),
         client_kyc_status                  = 'APPROVED',
         liveness_verified                  = true,
         liveness_score                     = least(100.00, greatest(0.00, round(p_liveness_score, 2))),
         face_liveness_hash                 = coalesce(nullif(btrim(p_face_liveness_hash), ''), face_liveness_hash),
         ocr_verified                       = true,
         kyc_ocr_confidence                 = least(100.00, greatest(0.00, round(coalesce(p_ocr_confidence, 95.0), 2))),
         kyc_biometric_verified             = true,
         pix_key_cpf_matched                = true,
         kyc_verified_at                    = v_now,
         kyc_expires_at                     = v_expires,
         kyc_billing_lock_until             = v_expires,
         kyc_validation_cycle               = v_new_cycle,
         criminal_record_verified           = true,
         criminal_record_verified_at        = v_now,
         criminal_record_expires_at         = v_expires,
         criminal_certificate_number_masked = v_proto_masked,
         criminal_certificate_sha256        = v_crim_sha::char(64),
         is_client                          = case when v_mode = 'client' then true else is_client end,
         client_setup_done                  = case when v_mode = 'client' then true else client_setup_done end,
         client_terms_accepted              = case when v_mode = 'client' then true else client_terms_accepted end,
         client_terms_accepted_at           = case when v_mode = 'client' then v_now else client_terms_accepted_at end,
         client_terms_version               = case when v_mode = 'client' then v_terms_ver else client_terms_version end,
         is_provider                        = case when v_mode = 'provider' then true else is_provider end,
         verification_status                = case
           when v_mode = 'provider' then 'ACTIVE'::public.verification_status
           when is_provider and verification_status = 'ACTIVE' then 'ACTIVE'::public.verification_status
           else verification_status
         end,
         provider_terms_accepted            = case when v_mode = 'provider' then true else provider_terms_accepted end,
         provider_terms_accepted_at         = case when v_mode = 'provider' then v_now else provider_terms_accepted_at end,
         provider_terms_version             = case when v_mode = 'provider' then v_terms_ver else provider_terms_version end,
         last_mode                          = v_mode,
         updated_at                         = v_now
   where id = v_uid;

  if v_mode = 'provider' then
    insert into public.provider_profiles (user_id)
    values (v_uid)
    on conflict (user_id) do nothing;
  end if;

  begin
    perform private.emit_ceo_live_event_safe(
      'UNIFIED_KYC_6M_AND_CRIMINAL_APPROVED',
      'SUCCESS',
      'KYC Unificado 6M + Antecedentes PF Aprovados (' || v_role_scope || ')',
      public.safe_name(v_holder_norm, 'Usuário') || ' · Ciclo #' || v_new_cycle::text || ' · ' || v_proto_masked,
      'criminal_background_checks',
      v_crim_check_id::text,
      0,
      jsonb_build_object(
        'user_id', v_uid,
        'target_mode', v_mode,
        'is_renewal', coalesce(p_is_renewal, false),
        'validation_cycle', v_new_cycle,
        'kyc_expires_at', v_expires,
        'submission_id', v_submission_id
      )
    );
  exception when others then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'status', 'APPROVED',
    'target_mode', v_mode,
    'reused_valid_kyc', false,
    'api_billed', true,
    'submission_id', v_submission_id,
    'criminal_check_id', v_crim_check_id,
    'kyc_validation_cycle', v_new_cycle,
    'kyc_verified_at', v_now,
    'kyc_expires_at', v_expires,
    'criminal_record_expires_at', v_expires,
    'cpf_masked', v_cpf_masked,
    'criminal_certificate_number_masked', v_proto_masked
  );
end $$;

revoke all on function public.submit_unified_kyc_v2(
  text, boolean, text, text, text, text, text, text, date, text,
  text, text, double precision, double precision, text, text, text,
  bigint, bigint, bigint, numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, text, date, text, text, text, text
) from public, anon;

grant execute on function public.submit_unified_kyc_v2(
  text, boolean, text, text, text, text, text, text, date, text,
  text, text, double precision, double precision, text, text, text,
  bigint, bigint, bigint, numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, text, date, text, text, text, text
) to authenticated;

comment on function public.submit_unified_kyc_v2(
  text, boolean, text, text, text, text, text, text, date, text,
  text, text, double precision, double precision, text, text, text,
  bigint, bigint, bigint, numeric, text, numeric, numeric, numeric, numeric,
  jsonb, text, text, text, date, text, text, text, text
) is
  'Validação unificada semestral (6 meses) de Identidade Civil + Prova de Vida + Certidão Negativa da Polícia Federal + Aceite de Termos por Papel, com trava anti-recobrança de API.';

-- -----------------------------------------------------------------------------
-- 6. RPC de Transição Instantânea entre Modos `public.activate_role_reusing_valid_kyc`
--    - Cliente validado -> Profissional: zero reenvio de documentos, zero custo API
--    - Profissional validado -> Cliente: zero alteração cadastral, zero reenvio, apenas Termos
-- -----------------------------------------------------------------------------
create or replace function public.activate_role_reusing_valid_kyc(
  p_target_mode text,
  p_terms_version text,
  p_terms_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_now        timestamptz := timezone('utc', now());
  v_mode       text := lower(btrim(coalesce(p_target_mode, '')));
  v_ver        text := left(btrim(coalesce(p_terms_version, '')), 40);
  v_sha        text := lower(btrim(coalesce(p_terms_sha256, '')));
  v_role_scope text;
  v_prof       public.profiles%rowtype;
  v_acc_id     uuid;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada ou usuário não autenticado.'
      using errcode = '28000';
  end if;

  if v_mode not in ('client', 'provider') then
    raise exception 'ERR_INVALID_TARGET_MODE: Modo de destino inválido (%).', v_mode
      using errcode = '22023';
  end if;

  if v_ver = '' then
    raise exception 'ERR_INVALID_MANDATE_VERSION: Versão dos termos obrigatória.'
      using errcode = '22023';
  end if;

  if v_sha !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_INVALID_MANDATE_SHA256: Assinatura SHA-256 dos termos inválida.'
      using errcode = '22023';
  end if;

  select * into v_prof
    from public.profiles
   where id = v_uid
     for update;

  if not found then
    raise exception 'ERR_PROFILE_NOT_FOUND: Perfil de usuário não localizado.'
      using errcode = 'P0002';
  end if;

  if not public.is_kyc_cycle_currently_valid(v_uid) then
    raise exception 'ERR_KYC_EXPIRED_OR_MISSING: Seu ciclo semestral de validação de identidade e antecedentes está ausente ou vencido.'
      using errcode = 'P0001';
  end if;

  v_role_scope := case when v_mode = 'provider' then 'PROVIDER' else 'CLIENT' end;

  insert into public.legal_mandate_acceptances (
    user_id,
    mandate_version,
    document_sha256,
    role_scope
  ) values (
    v_uid,
    v_ver,
    v_sha::char(64),
    v_role_scope
  )
  on conflict (user_id, mandate_version, role_scope) do update
    set document_sha256 = excluded.document_sha256
  returning id into v_acc_id;

  if v_mode = 'provider' then
    update public.profiles
       set is_provider = true,
           verification_status = 'ACTIVE'::public.verification_status,
           provider_terms_accepted = true,
           provider_terms_accepted_at = v_now,
           provider_terms_version = v_ver,
           last_mode = 'provider',
           updated_at = v_now
     where id = v_uid;

    insert into public.provider_profiles (user_id)
    values (v_uid)
    on conflict (user_id) do nothing;
  else
    update public.profiles
       set is_client = true,
           client_setup_done = true,
           client_terms_accepted = true,
           client_terms_accepted_at = v_now,
           client_terms_version = v_ver,
           last_mode = 'client',
           updated_at = v_now
     where id = v_uid;
  end if;

  begin
    perform private.emit_ceo_live_event_safe(
      'DUAL_ROLE_ACTIVATED_REUSING_KYC',
      'SUCCESS',
      'Segundo modo ativado com reaproveitamento KYC 6M (' || v_role_scope || ')',
      public.safe_name(v_prof.full_name, 'Usuário') || ' · Zero reenvio documental · Zero custo API',
      'profiles',
      v_uid::text,
      0,
      jsonb_build_object(
        'user_id', v_uid,
        'target_mode', v_mode,
        'mandate_acceptance_id', v_acc_id,
        'terms_version', v_ver,
        'reused_valid_kyc', true,
        'api_billed', false,
        'kyc_expires_at', v_prof.kyc_expires_at
      )
    );
  exception when others then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'target_mode', v_mode,
    'reused_valid_kyc', true,
    'api_billed', false,
    'mandate_acceptance_id', v_acc_id,
    'kyc_expires_at', v_prof.kyc_expires_at,
    'criminal_record_expires_at', v_prof.criminal_record_expires_at,
    'terms_version', v_ver,
    'terms_sha256', v_sha
  );
end $$;

revoke all on function public.activate_role_reusing_valid_kyc(text, text, text) from public, anon;
grant execute on function public.activate_role_reusing_valid_kyc(text, text, text) to authenticated;

comment on function public.activate_role_reusing_valid_kyc(text, text, text) is
  'Ativa instantaneamente o segundo modo (Cliente <-> Profissional) reutilizando o ciclo semestral válido de KYC + Antecedentes sem pedir documentos novamente e sem cobrar API.';

-- -----------------------------------------------------------------------------
-- 7. Limpeza Atômica Integral de 100% dos Usuários e Dados do Marketplace
--    Preservando Estritamente o Titular Soberano CEO (`wagneroliveira2395@gmail.com`)
--    e Todo o Esquema `private.ceo_*` + `private.founder_audit_log` + `public.app_settings`
-- -----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  if to_regclass('private.founder_audit_log') is not null then
    for r in
      select con.conname
        from pg_constraint con
       where con.conrelid = 'private.founder_audit_log'::regclass
         and con.contype = 'f'
         and con.confrelid = 'auth.users'::regclass
    loop
      execute format(
        'alter table private.founder_audit_log drop constraint if exists %I',
        r.conname
      );
    end loop;
  end if;
end $$;

do $$
declare
  v_ceo_email            text := lower(btrim(private.ceo_owner_canonical_email()));
  v_vault_owner_uid      uuid;
  v_auth_ceo_uid         uuid;
  v_ceo_uid              uuid;
  v_had_ceo_user         boolean := false;
  v_pre_audit_cnt        bigint := 0;
  v_pre_expenses_cnt     bigint := 0;
  v_pre_devices_cnt      bigint := 0;
  v_pre_pw_hist_cnt      bigint := 0;
  v_pre_app_settings_cnt bigint := 0;
  v_pre_cal_notes_cnt    bigint := 0;
  v_post_cal_notes_cnt   bigint := 0;
  v_extra_duress_cnt     bigint := 0;
  v_remaining_mkt        bigint := 0;
  v_remaining_non_ceo    bigint := 0;
begin
  select sv.owner_user_id
    into v_vault_owner_uid
    from private.ceo_sovereign_vault sv
   where sv.singleton_id = true;

  select au.id
    into v_auth_ceo_uid
    from auth.users au
   where lower(btrim(coalesce(au.email, ''))) = v_ceo_email
     and au.deleted_at is null
   order by (case when au.id = v_vault_owner_uid then 0 else 1 end), au.created_at asc
   limit 1;

  v_ceo_uid := coalesce(v_vault_owner_uid, v_auth_ceo_uid);
  v_had_ceo_user := (v_ceo_uid is not null);

  -- Snapshot pré-limpeza dos cofres soberanos intocáveis para asserção exata pós-limpeza
  select count(*) into v_pre_audit_cnt from private.founder_audit_log;
  select count(*) into v_pre_expenses_cnt from private.ceo_expense_entries;
  select count(*) into v_pre_devices_cnt from private.ceo_trusted_devices;
  select count(*) into v_pre_pw_hist_cnt from private.ceo_password_history;
  select count(*) into v_pre_app_settings_cnt from public.app_settings;

  if to_regclass('private.ceo_calendar_notes') is not null then
    execute 'select count(*) from private.ceo_calendar_notes' into v_pre_cal_notes_cnt;
  end if;

  -- 7.1 Limpeza dos objetos de Storage do marketplace (mídia, KYC e forense)
  begin
    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects
     where bucket_id in (
       'public-media',
       'job-media',
       'kyc-documents',
       'kyc_documentos',
       'forensic-evidence'
     );
  exception when others then
    null;
  end;

  -- 7.2 Camada Forense, Garantia, Mediações, Documentos Fiscais e Evidências de Pedidos
  delete from private.job_forensic_secrets;
  delete from public.forensic_certificates;
  delete from public.warranty_pool_ledger;
  delete from public.escrow_maturation_entries;
  delete from public.job_mediations;
  delete from public.job_fiscal_documents;
  delete from public.provider_case_pins;
  delete from public.job_evidence;
  delete from public.job_invites;
  delete from public.job_secrets;
  delete from public.job_addresses;
  delete from public.job_geo;

  if to_regclass('public.duress_security_alerts') is not null then
    execute 'delete from public.duress_security_alerts';
  end if;

  -- 7.3 Mensagens, Avaliações, Suporte e Notificações
  delete from public.messages;
  delete from public.reviews;
  delete from public.support_tickets;
  delete from public.notifications;

  -- 7.4 Ledger de Partida Dobrada, Carteiras, Pix, Pagamentos e Saques
  delete from public.ledger_lines;
  delete from public.ledger_txns;
  delete from public.wallet_statement;
  delete from public.pix_topups;
  delete from public.payments;
  delete from public.withdrawals;
  delete from public.client_wallets;

  -- 7.5 Pedidos e Orçamentos
  update public.jobs
     set accepted_quote_id = null,
         parent_job_id = null
   where accepted_quote_id is not null
      or parent_job_id is not null;

  delete from public.quotes;
  delete from public.jobs;

  -- 7.6 Portfólio, Certificados, Conquistas, Antecedentes, Mandatos, KYC e Perfis
  delete from public.provider_achievements;
  delete from public.provider_certificates;
  delete from public.provider_portfolio;
  delete from public.criminal_background_checks;
  delete from public.legal_mandate_acceptances;
  delete from public.kyc_webhook_events;
  delete from public.kyc_liveness_nonces;
  delete from public.kyc_submissions;
  delete from public.provider_profiles;
  delete from public.account_deletion_log;
  delete from public.profiles;

  -- 7.7 Contas de Autenticação (`auth.*`) de 100% dos usuários do Marketplace,
  --     preservando estritamente a conta única do CEO (`wagneroliveira2395@gmail.com`)
  delete from auth.refresh_tokens rt
   where rt.user_id is not null
     and (v_ceo_uid is null or rt.user_id <> v_ceo_uid::text)
     and not exists (
       select 1
         from auth.users au_keep
        where au_keep.id::text = rt.user_id
          and lower(btrim(coalesce(au_keep.email, ''))) = v_ceo_email
     );

  delete from auth.users au
   where (v_ceo_uid is null or au.id <> v_ceo_uid)
     and lower(btrim(coalesce(au.email, ''))) <> v_ceo_email;

  -- 7.8 Feed operacional efêmero do marketplace em `private.ceo_live_events`
  delete from private.ceo_live_events;

  alter sequence if exists public.ledger_lines_id_seq restart with 1;
  alter sequence if exists private.ceo_live_events_event_seq_seq restart with 1;

  -- ---------------------------------------------------------------------------
  -- 8. Pós-condições Matemáticas Fail-Closed antes do COMMIT
  -- ---------------------------------------------------------------------------
  if to_regclass('public.duress_security_alerts') is not null then
    execute 'select count(*) from public.duress_security_alerts' into v_extra_duress_cnt;
  end if;

  select (
    (select count(*) from public.profiles) +
    (select count(*) from public.provider_profiles) +
    (select count(*) from public.jobs) +
    (select count(*) from public.quotes) +
    (select count(*) from public.job_invites) +
    (select count(*) from public.job_evidence) +
    (select count(*) from public.job_secrets) +
    (select count(*) from public.job_addresses) +
    (select count(*) from public.job_geo) +
    (select count(*) from public.payments) +
    (select count(*) from public.ledger_txns) +
    (select count(*) from public.ledger_lines) +
    (select count(*) from public.client_wallets) +
    (select count(*) from public.wallet_statement) +
    (select count(*) from public.pix_topups) +
    (select count(*) from public.withdrawals) +
    (select count(*) from public.reviews) +
    (select count(*) from public.messages) +
    (select count(*) from public.notifications) +
    (select count(*) from public.support_tickets) +
    (select count(*) from public.kyc_submissions) +
    (select count(*) from public.kyc_liveness_nonces) +
    (select count(*) from public.kyc_webhook_events) +
    (select count(*) from public.criminal_background_checks) +
    (select count(*) from public.legal_mandate_acceptances) +
    (select count(*) from public.provider_portfolio) +
    (select count(*) from public.provider_certificates) +
    (select count(*) from public.provider_achievements) +
    (select count(*) from public.provider_case_pins) +
    (select count(*) from public.job_mediations) +
    (select count(*) from public.escrow_maturation_entries) +
    (select count(*) from public.warranty_pool_ledger) +
    (select count(*) from public.forensic_certificates) +
    (select count(*) from public.job_fiscal_documents) +
    (select count(*) from public.account_deletion_log) +
    (select count(*) from private.job_forensic_secrets) +
    (select count(*) from private.ceo_live_events) +
    v_extra_duress_cnt
  )
  into v_remaining_mkt;

  if v_remaining_mkt <> 0 then
    raise exception 'ERR_MARKETPLACE_RESET_INCOMPLETE: Restaram % registros operacionais no marketplace.',
      v_remaining_mkt using errcode = 'P0001';
  end if;

  select count(*)
    into v_remaining_non_ceo
    from auth.users au
   where (v_ceo_uid is null or au.id <> v_ceo_uid)
     and lower(btrim(coalesce(au.email, ''))) <> v_ceo_email;

  if v_remaining_non_ceo <> 0 then
    raise exception 'ERR_AUTH_USERS_RESET_INCOMPLETE: Restaram % contas fora da titularidade CEO em auth.users.',
      v_remaining_non_ceo using errcode = 'P0001';
  end if;

  if v_had_ceo_user and not exists (
    select 1
      from auth.users au
     where au.id = v_ceo_uid
       and lower(btrim(coalesce(au.email, ''))) = v_ceo_email
       and au.deleted_at is null
  ) then
    raise exception 'ERR_CEO_ACCOUNT_PROTECTION_VIOLATION: A conta exclusiva do CEO deve permanecer intacta.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_sovereign_vault where singleton_id = true) then
    raise exception 'ERR_CEO_VAULT_MISSING: Cofre soberano ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_crypto_pepper where singleton_id = true) then
    raise exception 'ERR_CEO_PEPPER_MISSING: Pepper criptográfico ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.geo_privacy_secrets where id = 1) then
    raise exception 'ERR_GEO_PRIVACY_SECRET_MISSING: Segredo geográfico HMAC ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_treasury_config where singleton_id = true) then
    raise exception 'ERR_CEO_TREASURY_CONFIG_MISSING: Configuração de tesouraria bivalente ausente.'
      using errcode = '42501';
  end if;

  if (select count(*) from private.founder_audit_log) <> v_pre_audit_cnt
     or not private.verify_founder_audit_chain() then
    raise exception 'ERR_FOUNDER_AUDIT_WORM_VIOLATION: Cadeia WORM de auditoria do CEO deve permanecer intacta.'
      using errcode = '42501';
  end if;

  if (select count(*) from private.ceo_expense_entries) <> v_pre_expenses_cnt
     or (select count(*) from private.ceo_trusted_devices) <> v_pre_devices_cnt
     or (select count(*) from private.ceo_password_history) <> v_pre_pw_hist_cnt
     or (select count(*) from public.app_settings) <> v_pre_app_settings_cnt then
    raise exception 'ERR_CEO_STATE_PRESERVATION_VIOLATION: Tabelas soberanas do CEO ou app_settings sofreram mutação.'
      using errcode = '42501';
  end if;

  if to_regclass('private.ceo_calendar_notes') is not null then
    execute 'select count(*) from private.ceo_calendar_notes' into v_post_cal_notes_cnt;
    if v_post_cal_notes_cnt <> v_pre_cal_notes_cnt then
      raise exception 'ERR_CEO_CALENDAR_NOTES_VIOLATION: Notas executivas do calendário CEO sofreram mutação.'
        using errcode = '42501';
    end if;
  end if;
end $$;

analyze
  public.profiles,
  public.provider_profiles,
  public.jobs,
  public.quotes,
  public.job_invites,
  public.job_evidence,
  public.job_secrets,
  public.job_addresses,
  public.job_geo,
  public.payments,
  public.ledger_txns,
  public.ledger_lines,
  public.client_wallets,
  public.wallet_statement,
  public.pix_topups,
  public.withdrawals,
  public.reviews,
  public.messages,
  public.notifications,
  public.support_tickets,
  public.kyc_submissions,
  public.kyc_liveness_nonces,
  public.kyc_webhook_events,
  public.criminal_background_checks,
  public.legal_mandate_acceptances,
  public.provider_portfolio,
  public.provider_certificates,
  public.provider_achievements,
  public.provider_case_pins,
  public.job_mediations,
  public.escrow_maturation_entries,
  public.warranty_pool_ledger,
  public.forensic_certificates,
  public.job_fiscal_documents,
  public.account_deletion_log,
  private.job_forensic_secrets,
  private.ceo_live_events;

commit;

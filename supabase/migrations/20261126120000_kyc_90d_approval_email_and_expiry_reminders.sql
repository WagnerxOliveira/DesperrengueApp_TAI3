-- =============================================================================
-- DESPERRENGUE v2.36.0 — Ciclo Oficial de 90 Dias (Polícia Federal),
-- Confirmação de E-mail de Aprovação (Cliente & Profissional) e Lembretes
-- Automáticos Prévios de Vencimento por E-mail (15d / 5d / Expirado)
--
-- Migration: 20261126120000_kyc_90d_approval_email_and_expiry_reminders.sql
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Novas colunas protegidas em `public.profiles`
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists approval_email_confirmed boolean not null default true,
  add column if not exists approval_email_sent_at timestamptz,
  add column if not exists approval_email_confirmed_at timestamptz,
  add column if not exists kyc_expiry_reminder_15d_sent_at timestamptz,
  add column if not exists kyc_expiry_reminder_5d_sent_at timestamptz,
  add column if not exists kyc_expiry_reminder_expired_sent_at timestamptz;

create index if not exists idx_profiles_kyc_expiry_reminders
  on public.profiles (kyc_expires_at)
  where kyc_expires_at is not null and criminal_record_verified = true;

-- -----------------------------------------------------------------------------
-- 2. Blindagem de colunas sensíveis no trigger `public.profiles_protect_columns()`
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
       or new.approval_email_confirmed is distinct from old.approval_email_confirmed
       or new.approval_email_sent_at is distinct from old.approval_email_sent_at
       or new.approval_email_confirmed_at is distinct from old.approval_email_confirmed_at
       or new.kyc_expiry_reminder_15d_sent_at is distinct from old.kyc_expiry_reminder_15d_sent_at
       or new.kyc_expiry_reminder_5d_sent_at is distinct from old.kyc_expiry_reminder_5d_sent_at
       or new.kyc_expiry_reminder_expired_sent_at is distinct from old.kyc_expiry_reminder_expired_sent_at
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

-- -----------------------------------------------------------------------------
-- 3. Atualização do RPC `public.submit_unified_kyc_v2` para Ciclo de 90 Dias PF
--    + disparo do estado `approval_email_confirmed = false` na 1ª aprovação
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
  p_terms_version text default '2026.11-CLIENT-V3',
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
  v_cert_expires   timestamptz;
  v_expires        timestamptz;
  v_doc_norm       text;
  v_front_safe     text;
  v_back_safe      text;
  v_selfie_safe    text;
  v_submission_id  uuid;
  v_crim_check_id  uuid;
  v_require_email  boolean;
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

  select *
    into v_prof
    from public.profiles
   where id = v_uid
   for update;

  if not found then
    raise exception 'ERR_PROFILE_NOT_FOUND: Perfil do usuário não encontrado.'
      using errcode = 'P0002';
  end if;

  -- Trava Anti-Dupla Cobrança: se o ciclo de 90 dias já está válido e NÃO é renovação,
  -- apenas ativa o modo e registra os termos sem criar nova submissão faturável.
  if not coalesce(p_is_renewal, false)
     and public.is_kyc_cycle_currently_valid(v_uid) then
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
  -- VALIDAÇÃO COMPLETA (1ª CONTA OU RENOVAÇÃO OFICIAL DE 90 DIAS)
  -- ===========================================================================
  v_digits := regexp_replace(coalesce(p_cpf_raw, ''), '\D', '', 'g');
  if not public.is_valid_cpf(v_digits) then
    raise exception 'ERR_INVALID_CPF_MOD11: O CPF informado é matematicamente inválido.'
      using errcode = '22023';
  end if;

  v_cpf_hash := encode(extensions.digest('DSP-CPF-PEPPER-2026:' || v_digits, 'sha256'), 'hex');
  v_cpf_masked := '***.' || substring(v_digits, 4, 3) || '.' || substring(v_digits, 7, 3) || '-**';

  if exists (
    select 1
      from public.profiles p_dup
     where p_dup.cpf_hash = v_cpf_hash
       and p_dup.id <> v_uid
  ) then
    raise exception 'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta ativa na plataforma.'
      using errcode = '23505';
  end if;

  if v_prof.cpf_hash is not null and v_prof.cpf_hash <> v_cpf_hash then
    raise exception 'ERR_RENEWAL_CPF_MISMATCH: Na renovação de segurança, o documento deve pertencer ao mesmo CPF titular da conta.'
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
    v_proto_clean := 'PF-' || upper(left(v_crim_sha, 10));
  end if;
  v_proto_masked := 'PF-***' || right(v_proto_clean, 4);

  v_val_code_clean := btrim(coalesce(p_criminal_validation_code, ''));
  if char_length(v_val_code_clean) < 4 then
    v_val_code_clean := 'SINIC-' || upper(substring(v_crim_sha from 11 for 8));
  end if;
  v_val_code_hash := lower(
    encode(extensions.digest(convert_to('DSP-PF-VAL-2026:' || upper(v_val_code_clean), 'UTF8'), 'sha256'), 'hex')
  )::char(64);

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

  -- Vigência estritamente alinhada ao prazo oficial de 90 dias da Polícia Federal:
  v_cert_expires := ((p_criminal_issued_date + 90)::timestamp + interval '23 hours 59 minutes') at time zone 'America/Sao_Paulo';
  v_expires := least(v_now + interval '90 days', v_cert_expires);
  if v_expires <= v_now then
    v_expires := v_now + interval '1 day';
  end if;

  v_require_email := (not coalesce(p_is_renewal, false)) and (coalesce(v_prof.kyc_validation_cycle, 0) = 0);

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

  insert into public.kyc_submissions (
    user_id, front_path, back_path, selfie_path,
    doc_front_url, doc_back_url, selfie_url,
    registry_type, registry_number, role_scope, document_type,
    doc_front_phash, doc_back_phash, selfie_liveness_phash,
    liveness_challenges_passed, ocr_extracted_payload,
    laplacian_sharpness_score, glare_ratio_pct, face_match_cosine_similarity,
    status, reviewed_at
  ) values (
    v_uid, v_front_safe, v_back_safe, v_selfie_safe,
    v_front_safe, v_back_safe, v_selfie_safe,
    'Outro', v_cpf_masked,
    case
      when coalesce(v_prof.is_client, false) and coalesce(v_prof.is_provider, false) then 'both'
      when v_mode = 'provider' then 'provider'
      else 'client'
    end,
    v_doc_norm,
    p_doc_front_phash, p_doc_back_phash, p_selfie_phash,
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
      'validity_days', 90,
      'is_renewal', coalesce(p_is_renewal, false),
      'criminal_protocol_masked', v_proto_masked,
      'criminal_file_sha256', v_crim_sha
    ),
    p_laplacian_sharpness, p_glare_ratio_pct,
    least(1.0000, greatest(0.0000, round(p_face_match_similarity, 4))),
    'APPROVED', v_now
  )
  returning id into v_submission_id;

  insert into public.criminal_background_checks (
    user_id, validation_cycle, certificate_protocol_masked, issuing_organ,
    certificate_issued_date, validation_code_hash, file_storage_path,
    file_sha256, holder_cpf_hash, holder_name_normalized, outcome,
    verified_at, expires_at
  ) values (
    v_uid, v_new_cycle, v_proto_masked, 'POLICIA_FEDERAL_SINIC',
    p_criminal_issued_date, v_val_code_hash, v_crim_path,
    v_crim_sha::char(64), v_cpf_hash, v_holder_norm, 'NOTHING_ON_RECORD',
    v_now, v_expires
  )
  returning id into v_crim_check_id;

  insert into public.legal_mandate_acceptances (
    user_id, mandate_version, document_sha256, role_scope
  ) values (
    v_uid, v_terms_ver, v_terms_sha::char(64), v_role_scope
  )
  on conflict (user_id, mandate_version, role_scope) do update
    set document_sha256 = excluded.document_sha256;

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
         approval_email_confirmed           = case when v_require_email then false else approval_email_confirmed end,
         approval_email_sent_at             = case when v_require_email then null else approval_email_sent_at end,
         approval_email_confirmed_at        = case when v_require_email then null else approval_email_confirmed_at end,
         kyc_expiry_reminder_15d_sent_at    = null,
         kyc_expiry_reminder_5d_sent_at     = null,
         kyc_expiry_reminder_expired_sent_at = null,
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
      'UNIFIED_KYC_90D_AND_CRIMINAL_APPROVED',
      'SUCCESS',
      'KYC Unificado 90d + Antecedentes PF Aprovados (' || v_role_scope || ')',
      public.safe_name(v_holder_norm, 'Usuário') || ' · Ciclo #' || v_new_cycle::text || ' · ' || v_proto_masked,
      'criminal_background_checks',
      v_crim_check_id::text,
      0,
      jsonb_build_object(
        'user_id', v_uid,
        'target_mode', v_mode,
        'is_renewal', coalesce(p_is_renewal, false),
        'validation_cycle', v_new_cycle,
        'validity_days', 90,
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
    'validity_days', 90,
    'kyc_expires_at', v_expires,
    'criminal_record_expires_at', v_expires,
    'approval_email_confirmed', not v_require_email
  );
end $$;

revoke all on function public.submit_unified_kyc_v2(
  text, boolean, text, text, text, text, text, text, date, text, text, text,
  double precision, double precision, text, text, text, bigint, bigint, bigint,
  numeric, text, numeric, numeric, numeric, numeric, jsonb, text, text, text,
  date, text, text, text, text
) from public, anon;

grant execute on function public.submit_unified_kyc_v2(
  text, boolean, text, text, text, text, text, text, date, text, text, text,
  double precision, double precision, text, text, text, bigint, bigint, bigint,
  numeric, text, numeric, numeric, numeric, numeric, jsonb, text, text, text,
  date, text, text, text, text
) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. RPC `public.confirm_account_approval_email()` (Cliente e Profissional)
-- -----------------------------------------------------------------------------
create or replace function public.confirm_account_approval_email()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
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
   where id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'approval_email_confirmed', true,
    'confirmed_at', v_now
  );
end $$;

revoke all on function public.confirm_account_approval_email() from public, anon;
grant execute on function public.confirm_account_approval_email() to authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPC `public.get_profiles_needing_kyc_expiry_reminder()` (service_role)
--    Retorna clientes e profissionais que precisam de e-mail prévio (15d, 5d, vencido)
-- -----------------------------------------------------------------------------
create or replace function public.get_profiles_needing_kyc_expiry_reminder()
returns table (
  user_id uuid,
  email text,
  full_name text,
  is_client boolean,
  is_provider boolean,
  expires_at timestamptz,
  days_remaining integer,
  reminder_stage text
)
language sql
security definer
set search_path = public, auth, extensions
as $$
  with effective as (
    select
      p.id as user_id,
      u.email::text as email,
      coalesce(nullif(btrim(p.verified_full_name), ''), nullif(btrim(p.full_name), ''), 'Usuário') as full_name,
      p.is_client,
      p.is_provider,
      least(
        coalesce(p.kyc_expires_at, p.criminal_record_expires_at),
        coalesce(p.criminal_record_expires_at, p.kyc_expires_at)
      ) as expires_at,
      p.kyc_expiry_reminder_15d_sent_at,
      p.kyc_expiry_reminder_5d_sent_at,
      p.kyc_expiry_reminder_expired_sent_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where u.email is not null
      and coalesce(p.role, 'user') <> 'admin'
      and p.criminal_record_verified = true
      and (p.kyc_expires_at is not null or p.criminal_record_expires_at is not null)
  )
  select
    e.user_id,
    e.email,
    e.full_name,
    e.is_client,
    e.is_provider,
    e.expires_at,
    greatest(0, ceil(extract(epoch from (e.expires_at - timezone('utc', now()))) / 86400.0)::integer) as days_remaining,
    case
      when e.expires_at <= timezone('utc', now())
           and e.kyc_expiry_reminder_expired_sent_at is null
        then 'expired'
      when e.expires_at > timezone('utc', now())
           and e.expires_at <= timezone('utc', now()) + interval '5 days'
           and e.kyc_expiry_reminder_5d_sent_at is null
        then '5d'
      when e.expires_at > timezone('utc', now()) + interval '5 days'
           and e.expires_at <= timezone('utc', now()) + interval '15 days'
           and e.kyc_expiry_reminder_15d_sent_at is null
        then '15d'
      else null
    end as reminder_stage
  from effective e
  where (
    (e.expires_at <= timezone('utc', now()) and e.kyc_expiry_reminder_expired_sent_at is null)
    or (e.expires_at > timezone('utc', now()) and e.expires_at <= timezone('utc', now()) + interval '5 days' and e.kyc_expiry_reminder_5d_sent_at is null)
    or (e.expires_at > timezone('utc', now()) + interval '5 days' and e.expires_at <= timezone('utc', now()) + interval '15 days' and e.kyc_expiry_reminder_15d_sent_at is null)
  );
$$;

revoke all on function public.get_profiles_needing_kyc_expiry_reminder() from public, anon, authenticated;
grant execute on function public.get_profiles_needing_kyc_expiry_reminder() to service_role;

-- -----------------------------------------------------------------------------
-- 6. Agendamento diário via `pg_cron` + `pg_net` (08:00 Brasília = 11:00 UTC)
--    (Protegido por bloco EXCEPTION caso pg_cron/vault não estejam ativos)
-- -----------------------------------------------------------------------------
do $$
declare
  v_project_url text;
  v_secret      text;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    select decrypted_secret into v_project_url
      from vault.decrypted_secrets
     where name = 'project_url'
     limit 1;
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'kyc_webhook_secret'
     limit 1;

    if coalesce(v_project_url, '') <> '' and coalesce(v_secret, '') <> '' then
      perform cron.unschedule('desperrengue_kyc_90d_expiry_reminders')
        where exists (
          select 1 from cron.job where jobname = 'desperrengue_kyc_90d_expiry_reminders'
        );

      perform cron.schedule(
        'desperrengue_kyc_90d_expiry_reminders',
        '0 11 * * *',
        format(
          $cmd$
          select net.http_post(
            url := %L,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'x-webhook-secret', %L
            ),
            body := '{}'::jsonb
          );
          $cmd$,
          rtrim(v_project_url, '/') || '/functions/v1/kyc-expiry-reminder',
          v_secret
        )
      );
    end if;
  end if;
exception when others then
  null;
end $$;

commit;

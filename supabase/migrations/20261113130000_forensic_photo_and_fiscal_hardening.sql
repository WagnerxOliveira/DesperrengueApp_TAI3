-- =============================================================================
-- DESPERRENGUE — Registro Forense de Fotos (Check-in/Check-out) & Endurecimento
--                Zero-Trust de Documentos Fiscais / Smart Split (v2.11.1)
-- Migration: 20261113130000_forensic_photo_and_fiscal_hardening.sql
--
-- OBJETIVOS:
--   1. Criar a RPC `public.register_forensic_photo(p_job_id, p_stage, p_phash, p_storage_path)`
--      para registrar no servidor os hashes perceptuais dHash 64-bit e caminhos privados
--      (`forensic-evidence` -> `evidence/<job_id>/...`) das fotos reais de check-in e
--      check-out, com check-in imutável e bloqueio de reciclagem (`hamming_distance_64 < 5`).
--   2. Endurecer `public.job_fiscal_documents` e `public.register_and_verify_material_fiscal_document`:
--      - Aceitar `capture_channel = 'MANUAL_KEY'` (chave de 44 dígitos digitada/colada).
--      - Jamais confiar em `p_sefaz_status_initial` ou `p_ela_tamper_score` enviados pelo
--        cliente (parâmetros mantidos na assinatura apenas por compatibilidade retroativa,
--        mas ignorados no servidor: todo documento nasce em `verification_status = 'PENDING_SEFAZ'`,
--        `sefaz_status_initial = NULL`, `ela_tamper_score = 0.0000`, `verified = false`).
--   3. Impacto Financeiro Corrigido no Smart Split (`settle_escrow_with_carveout_and_maturation`):
--      - Antes desta migration, `settle_escrow_with_carveout_and_maturation` concedia isenção
--        de 0% sobre todo `jobs.materials_amount` sem verificar `public.job_fiscal_documents`.
--      - Agora, a isenção de 0% de taxa sobre materiais SOMENTE é aplicada à parcela coberta por
--        documento fiscal com `verification_status = 'VERIFIED_SEFAZ'`, `sefaz_status_recheck = 100`
--        e `clawback_triggered = false`. Enquanto o documento estiver `PENDING_SEFAZ` (ou ausente /
--        rejeitado / cancelado), a parcela não verificada sofre incidência integral da taxa padrão
--        (13,5% operacional + 1,5% Fundo Garantidor = 15%).
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Colunas de rastreabilidade dos objetos forenses privados em `public.jobs`
--    + Correção de overflow signed INT64 em `public.hamming_distance_64`
-- -----------------------------------------------------------------------------
alter table public.jobs
  add column if not exists checkin_photo_path text,
  add column if not exists checkout_photo_path text;

revoke insert, update (
  checkin_photo_phash,
  checkout_photo_phash,
  checkin_photo_path,
  checkout_photo_path
) on public.jobs from public, anon, authenticated;

comment on column public.jobs.checkin_photo_path is
  'Caminho do objeto no bucket privado forensic-evidence (evidence/<job_id>/...) correspondente ao checkin_photo_phash.';
comment on column public.jobs.checkout_photo_path is
  'Caminho do objeto no bucket privado forensic-evidence (evidence/<job_id>/...) correspondente ao checkout_photo_phash.';

-- Corrige `bigint out of range` (SQLSTATE 22003) quando `hash_a` e `hash_b`
-- possuem sinais opostos (bit 63 = 1 em `hash_a # hash_b`, 50% dos hashes dHash 64-bit reais).
create or replace function public.hamming_distance_64(
  hash_a bigint,
  hash_b bigint
)
returns integer
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  x bigint;
  c integer := 0;
begin
  if hash_a is null or hash_b is null then
    return null;
  end if;

  x := hash_a # hash_b;
  if x < 0 then
    c := 1;
    x := x & 9223372036854775807::bigint;
  end if;

  while x > 0 loop
    x := x & (x - 1);
    c := c + 1;
  end loop;

  return c;
end $$;

revoke all on function public.hamming_distance_64(bigint, bigint) from public, anon;
grant execute on function public.hamming_distance_64(bigint, bigint) to authenticated, service_role;

comment on function public.hamming_distance_64(bigint, bigint) is
  'Distância de Hamming exata de 64 bits (dHash perceptual) segura contra overflow signed bigint no bit 63 (INT64_MIN).';

-- -----------------------------------------------------------------------------
-- 2. RPC `public.register_forensic_photo` (Check-in imutável + Anti-Reciclagem)
-- -----------------------------------------------------------------------------
create or replace function public.register_forensic_photo(
  p_job_id uuid,
  p_stage text,
  p_phash bigint,
  p_storage_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_stage   text := lower(btrim(coalesce(p_stage, '')));
  v_path    text := ltrim(btrim(coalesce(p_storage_path, '')), '/');
  v_prefix  text;
  v_job     public.jobs%rowtype;
  v_hamming integer;
begin
  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;

  if p_job_id is null then
    raise exception 'FORENSIC_JOB_NOT_FOUND: Identificador do atendimento obrigatório.' using errcode = '22023';
  end if;

  if v_stage not in ('check_in', 'check_out') then
    raise exception 'FORENSIC_STAGE_INVALID: Estágio inválido (%). Use check_in ou check_out.', coalesce(p_stage, 'null')
      using errcode = '22023';
  end if;

  if p_phash is null then
    raise exception 'FORENSIC_PHASH_REQUIRED: Hash perceptual de 64 bits obrigatório.' using errcode = '22023';
  end if;

  v_prefix := 'evidence/' || lower(p_job_id::text) || '/';
  if position('..' in v_path) > 0
     or position('//' in v_path) > 0
     or left(lower(v_path), length(v_prefix)) <> v_prefix
     or length(v_path) <= length(v_prefix)
     or v_path !~* '\.(jpe?g|png|webp)$' then
    raise exception 'FORENSIC_PATH_INVALID: O caminho deve iniciar por evidence/<job_id>/ com extensão de imagem válida e sem ..'
      using errcode = '22023';
  end if;

  select *
    into v_job
    from public.jobs
   where id = p_job_id
     for update;

  if not found then
    raise exception 'FORENSIC_JOB_NOT_FOUND: Ordem de serviço inexistente.' using errcode = 'P0002';
  end if;

  if v_job.provider_id is distinct from v_uid then
    raise exception 'FORENSIC_UNAUTHORIZED_PROVIDER: Apenas o profissional alocado pode registrar evidência forense.'
      using errcode = '42501';
  end if;

  if v_job.status <> 'in_progress' then
    raise exception 'FORENSIC_INVALID_JOB_STATE: O atendimento precisa estar em andamento (in_progress) para registrar evidência forense (estado atual: %).',
      v_job.status using errcode = 'P0001';
  end if;

  if v_stage = 'check_in' then
    if v_job.checkin_photo_phash is not null then
      raise exception 'FORENSIC_CHECKIN_IMMUTABLE: A foto forense de check-in já foi gravada e não pode ser substituída.'
        using errcode = '42501';
    end if;

    if v_job.checkout_photo_phash is not null then
      v_hamming := public.hamming_distance_64(p_phash, v_job.checkout_photo_phash);
      if v_hamming < 5 then
        raise exception 'FORENSIC_PHOTO_DUPLICATE: A foto de check-in é idêntica ou reciclada da foto de check-out (Hamming=% < 5).',
          v_hamming using errcode = 'P0001';
      end if;
    end if;

    update public.jobs
       set checkin_photo_phash = p_phash,
           checkin_photo_path = v_path,
           updated_at = now()
     where id = p_job_id;
  else
    if v_job.checkin_photo_phash is not null then
      v_hamming := public.hamming_distance_64(v_job.checkin_photo_phash, p_phash);
      if v_hamming < 5 then
        raise exception 'FORENSIC_PHOTO_DUPLICATE: A foto de check-out é idêntica ou reciclada da foto de check-in (Hamming=% < 5).',
          v_hamming using errcode = 'P0001';
      end if;
    end if;

    update public.jobs
       set checkout_photo_phash = p_phash,
           checkout_photo_path = v_path,
           updated_at = now()
     where id = p_job_id;
  end if;

  return jsonb_build_object(
    'recorded', true,
    'stage', v_stage,
    'phash', p_phash
  );
end $$;

revoke all on function public.register_forensic_photo(uuid, text, bigint, text) from public, anon;
grant execute on function public.register_forensic_photo(uuid, text, bigint, text) to authenticated;

comment on function public.register_forensic_photo(uuid, text, bigint, text) is
  'Registra hash perceptual dHash 64-bit e caminho privado (evidence/<job_id>/...) de foto forense de check_in (imutável após gravação) ou check_out do profissional em atendimento in_progress, bloqueando duplicidade/reciclagem (hamming_distance_64 < 5).';

-- -----------------------------------------------------------------------------
-- 3. Endurecimento de `public.job_fiscal_documents` (`MANUAL_KEY` + `PENDING_SEFAZ`)
-- -----------------------------------------------------------------------------
alter table public.job_fiscal_documents
  add column if not exists verification_status text not null default 'PENDING_SEFAZ';

alter table public.job_fiscal_documents
  alter column sefaz_status_initial drop not null,
  alter column sefaz_status_initial set default null;

do $$
declare
  r record;
begin
  -- Remove constraints antigas de capture_channel ou verification_status para recriação idempotente
  for r in
    select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'job_fiscal_documents'
       and c.contype = 'c'
       and (
         pg_get_constraintdef(c.oid) ilike '%capture_channel%'
         or pg_get_constraintdef(c.oid) ilike '%verification_status%'
       )
  loop
    execute format('alter table public.job_fiscal_documents drop constraint if exists %I', r.conname);
  end loop;
end $$;

alter table public.job_fiscal_documents
  add constraint chk_job_fiscal_documents_capture_channel check (
    capture_channel in ('QR_CODE', 'BARCODE_1D_CODE128C', 'OCR_CHAVE_44', 'OCR_MEI_RECEIPT', 'MANUAL_KEY')
  ),
  add constraint chk_job_fiscal_documents_verification_status check (
    verification_status in ('PENDING_SEFAZ', 'VERIFIED_SEFAZ', 'REJECTED_SEFAZ', 'CANCELED_CLAWBACK')
  );

-- Normaliza registros pré-existentes conforme estado real de rechecagem SEFAZ
update public.job_fiscal_documents
   set verification_status = case
         when clawback_triggered = true then 'CANCELED_CLAWBACK'
         when sefaz_status_recheck = 100 then 'VERIFIED_SEFAZ'
         when sefaz_status_recheck is not null and sefaz_status_recheck <> 100 then 'REJECTED_SEFAZ'
         else 'PENDING_SEFAZ'
       end,
       sefaz_status_initial = case
         when sefaz_status_recheck = 100 then sefaz_status_initial
         else null
       end
 where verification_status is distinct from case
         when clawback_triggered = true then 'CANCELED_CLAWBACK'
         when sefaz_status_recheck = 100 then 'VERIFIED_SEFAZ'
         when sefaz_status_recheck is not null and sefaz_status_recheck <> 100 then 'REJECTED_SEFAZ'
         else 'PENDING_SEFAZ'
       end
    or (sefaz_status_recheck is distinct from 100 and sefaz_status_initial is not null);

comment on column public.job_fiscal_documents.verification_status is
  'Estado server-side da verificação fiscal: nasce sempre em PENDING_SEFAZ (nunca confiando no cliente); só passa a VERIFIED_SEFAZ por worker/oráculo SEFAZ no servidor.';

-- -----------------------------------------------------------------------------
-- 4. RPC `public.register_and_verify_material_fiscal_document` (Zero-Trust Client Inputs)
-- -----------------------------------------------------------------------------
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
  v_uid            uuid := auth.uid();
  v_job            public.jobs%rowtype;
  v_key_check      jsonb;
  v_clean_cnpj     text := regexp_replace(coalesce(p_emitter_cnpj, ''), '[^0-9]', '', 'g');
  v_clean_key      text := nullif(regexp_replace(coalesce(p_access_key_44, ''), '[^0-9]', '', 'g'), '');
  v_channel        text := upper(btrim(coalesce(p_capture_channel, '')));
  v_effective_mode text := upper(btrim(coalesce(p_fiscal_document_mode, '')));
  v_receipt_num    text := btrim(coalesce(p_receipt_number, ''));
  v_doc_id         uuid;
begin
  -- Nota Zero-Trust: `p_ela_tamper_score` e `p_sefaz_status_initial` são mantidos na
  -- assinatura exclusivamente por compatibilidade retroativa com clientes instalados,
  -- mas IGNORADOS no servidor. Todo cupom nasce em `PENDING_SEFAZ` com score neutro `0.0000`
  -- e `sefaz_status_initial = NULL` até conferência assíncrona real na SEFAZ.

  if v_uid is null then
    raise exception 'ERR_UNAUTHENTICATED: Sessão expirada.' using errcode = '28000';
  end if;

  if p_provider_id is distinct from v_uid then
    raise exception 'ERR_IDOR_BLOCKED: Identificador do profissional inválido.' using errcode = '42501';
  end if;

  select * into v_job
    from public.jobs
   where id = p_job_id
     for update;

  if not found or v_job.provider_id is distinct from v_uid then
    raise exception 'ERR_UNAUTHORIZED_JOB: Apenas o prestador alocado neste atendimento pode registrar documento fiscal.'
      using errcode = '42501';
  end if;

  if v_job.status not in ('scheduled', 'in_progress', 'awaiting_approval') then
    raise exception 'ERR_INVALID_JOB_STATE: Não é possível registrar documento fiscal para atendimento em estado %.',
      v_job.status using errcode = 'P0001';
  end if;

  if p_declared_material_amount is null or p_declared_material_amount <= 0 then
    raise exception 'ERR_INVALID_MATERIAL_AMOUNT: O valor declarado dos materiais deve ser maior que zero.'
      using errcode = '22023';
  end if;

  if p_receipt_photo_phash is null then
    raise exception 'RECEIPT_PHOTO_REQUIRED: A foto forense do cupom/nota fiscal é obrigatória.'
      using errcode = '22023';
  end if;

  if v_channel not in ('QR_CODE', 'BARCODE_1D_CODE128C', 'OCR_CHAVE_44', 'OCR_MEI_RECEIPT', 'MANUAL_KEY') then
    raise exception 'INVALID_CAPTURE_CHANNEL: Canal de captura inválido (%).', coalesce(p_capture_channel, 'null')
      using errcode = '22023';
  end if;

  if coalesce(p_tp_amb, '1') <> '1' then
    raise exception 'FISCAL_HOMOLOGATION_ENV_BLOCKED: Notas em ambiente de homologação (tpAmb != 1) são bloqueadas.'
      using errcode = 'P0001';
  end if;

  -- Anti-reciclagem cruzada: impede reutilizar foto de check-in ou check-out como foto de cupom fiscal
  if v_job.checkin_photo_phash is not null
     and public.hamming_distance_64(v_job.checkin_photo_phash, p_receipt_photo_phash) < 5 then
    raise exception 'FORENSIC_RECEIPT_PHOTO_RECYCLED: A foto do documento fiscal é idêntica à foto de check-in.'
      using errcode = 'P0001';
  end if;

  if v_job.checkout_photo_phash is not null
     and public.hamming_distance_64(v_job.checkout_photo_phash, p_receipt_photo_phash) < 5 then
    raise exception 'FORENSIC_RECEIPT_PHOTO_RECYCLED: A foto do documento fiscal é idêntica à foto de check-out.'
      using errcode = 'P0001';
  end if;

  if v_effective_mode in ('NFE_55', 'NFCE_65') then
    if v_clean_key is null then
      raise exception 'ACCESS_KEY_REQUIRED: Chave de acesso de 44 dígitos obrigatória.' using errcode = '22023';
    end if;

    v_key_check := public.validate_nfe_access_key_mod11(v_clean_key);
    if not coalesce((v_key_check ->> 'valid')::boolean, false) then
      raise exception 'INVALID_NFE_KEY_MOD11: Chave de 44 dígitos inválida (%).', (v_key_check ->> 'reason')
        using errcode = '22023';
    end if;

    v_clean_cnpj := v_key_check ->> 'emitter_cnpj';
    v_effective_mode := case when (v_key_check ->> 'fiscal_model') = '55' then 'NFE_55' else 'NFCE_65' end;

    if v_receipt_num = '' then
      -- Posições 26..34 da chave de 44 dígitos correspondem ao nNF (9 dígitos)
      v_receipt_num := substring(v_clean_key, 26, 9);
    end if;
  elsif v_effective_mode = 'MEI_RECEIPT_CGSN140' then
    if not public.validate_cnpj_mod11(v_clean_cnpj) then
      raise exception 'INVALID_MEI_CNPJ: CNPJ inválido (Módulo 11).' using errcode = '22023';
    end if;
    if not coalesce(p_emitter_cnae_compatible, false) then
      raise exception 'INCOMPATIBLE_EMITTER_CNAE: CNAE incompatível com materiais técnicos.' using errcode = 'P0001';
    end if;
    if p_declared_material_amount > 150.00 then
      raise exception 'SMART_FISCAL_CAP_EXCEEDED: Recibos MEI sem chave de 44 dígitos têm teto de R$ 150,00.'
        using errcode = 'P0001';
    end if;
    if v_receipt_num = '' then
      raise exception 'RECEIPT_NUMBER_REQUIRED: Número do recibo obrigatório.' using errcode = '22023';
    end if;
  else
    raise exception 'UNSUPPORTED_FISCAL_DOCUMENT_MODE: %', coalesce(p_fiscal_document_mode, 'null')
      using errcode = '22023';
  end if;

  insert into public.job_fiscal_documents (
    job_id,
    provider_id,
    fiscal_document_mode,
    capture_channel,
    access_key_44,
    tp_amb,
    emitter_cnpj,
    emitter_cnae_compatible,
    receipt_number,
    declared_material_amount,
    ncm_codes,
    ela_tamper_score,
    receipt_photo_phash,
    sefaz_status_initial,
    verification_status
  ) values (
    p_job_id,
    v_uid,
    v_effective_mode,
    v_channel,
    v_clean_key,
    '1',
    v_clean_cnpj,
    coalesce(p_emitter_cnae_compatible, true),
    v_receipt_num,
    p_declared_material_amount,
    coalesce(p_ncm_codes, '{}'),
    0.0000,          -- neutro server-side (ignora p_ela_tamper_score do cliente)
    p_receipt_photo_phash,
    null,            -- sem confirmação SEFAZ ainda (ignora p_sefaz_status_initial do cliente)
    'PENDING_SEFAZ'
  ) returning id into v_doc_id;

  return jsonb_build_object(
    'recorded', true,
    'verified', false,
    'sefaz_confirmed', false,
    'sefaz_verified', false,
    'verification_status', 'PENDING_SEFAZ',
    'status_label_pt', 'Registrada — conferência na SEFAZ em andamento',
    'document_id', v_doc_id,
    'fiscal_document_mode', v_effective_mode,
    'capture_channel', v_channel,
    'emitter_cnpj', v_clean_cnpj,
    'receipt_number', v_receipt_num,
    'declared_material_amount', p_declared_material_amount,
    'exempt_material_amount', 0.00,
    'smart_fiscal_cap_applied', (v_effective_mode = 'MEI_RECEIPT_CGSN140')
  );
end $$;

revoke all on function public.register_and_verify_material_fiscal_document(
  uuid, uuid, text, text, text, char(1), text, boolean, text, numeric(12,2), text[], numeric(5,4), bigint, int
) from public, anon;

grant execute on function public.register_and_verify_material_fiscal_document(
  uuid, uuid, text, text, text, char(1), text, boolean, text, numeric(12,2), text[], numeric(5,4), bigint, int
) to authenticated;

comment on function public.register_and_verify_material_fiscal_document(
  uuid, uuid, text, text, text, char(1), text, boolean, text, numeric(12,2), text[], numeric(5,4), bigint, int
) is
  'Registra documento fiscal de materiais (QR_CODE, BARCODE_1D_CODE128C, OCR_CHAVE_44, OCR_MEI_RECEIPT ou MANUAL_KEY) com validação Mod-11 server-side. Ignora p_sefaz_status_initial e p_ela_tamper_score do cliente: nasce sempre em PENDING_SEFAZ (verified=false, exempt_material_amount=0.00) até conferência SEFAZ no servidor.';

-- -----------------------------------------------------------------------------
-- 5. Blindagem Financeira do Smart Split (`settle_escrow_with_carveout_and_maturation`
--    e `audit_sefaz_phase2_cancellation_and_clawback`)
-- -----------------------------------------------------------------------------
-- IMPACTO FINANCEIRO DOCUMENTADO:
--   A isenção de 0% de taxa sobre materiais (`materials_amount`) SÓ é aplicada
--   sobre o montante coberto por documentos fiscais do job com
--   `verification_status = 'VERIFIED_SEFAZ'`, `sefaz_status_recheck = 100` e
--   `clawback_triggered = false`. Enquanto o documento estiver em `PENDING_SEFAZ`
--   (ou ausente/rejeitado/cancelado), a parcela de materiais não verificada compõe
--   a base tributável da plataforma (13,5% operacional + 1,5% Fundo de Garantia).
create or replace function public.settle_escrow_with_carveout_and_maturation(
  p_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job                  public.jobs%rowtype;
  v_provider             public.profiles%rowtype;
  v_labor                numeric(12,2);
  v_materials            numeric(12,2);
  v_verified_materials   numeric(12,2) := 0.00;
  v_exempt_materials     numeric(12,2) := 0.00;
  v_unverified_materials numeric(12,2) := 0.00;
  v_fee_bearing_base     numeric(12,2);
  v_operational_fee      numeric(12,2);
  v_warranty_carveout    numeric(12,2);
  v_net_provider         numeric(12,2);
  v_clawback_deducted    numeric(12,2) := 0.00;
  v_maturation_days      integer := 5;
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'ERR_JOB_NOT_FOUND: Ordem de serviço % inexistente.', p_job_id using errcode = 'P0002';
  end if;

  select * into v_provider from public.profiles where id = v_job.provider_id for update;

  v_labor := coalesce(v_job.labor_amount, 0.00);
  v_materials := coalesce(v_job.materials_amount, 0.00);
  if v_labor = 0.00 and v_materials = 0.00 and coalesce(v_job.agreed_price, 0.00) > 0.00 then
    v_labor := v_job.agreed_price;
  end if;

  if v_materials > 0 then
    select coalesce(sum(d.declared_material_amount), 0.00)
      into v_verified_materials
      from public.job_fiscal_documents d
     where d.job_id = v_job.id
       and d.verification_status = 'VERIFIED_SEFAZ'
       and d.sefaz_status_recheck = 100
       and d.clawback_triggered = false;

    v_exempt_materials := least(v_materials, v_verified_materials);
  end if;

  v_unverified_materials := greatest(0.00, v_materials - v_exempt_materials);
  v_fee_bearing_base := v_labor + v_unverified_materials;

  -- 13,5% operacional + 1,5% Fundo Garantidor sobre mão de obra + materiais NÃO verificados na SEFAZ
  v_operational_fee := round(v_fee_bearing_base * 0.135, 2);
  v_warranty_carveout := round(v_fee_bearing_base * 0.015, 2);
  v_net_provider := (v_labor + v_materials) - v_operational_fee - v_warranty_carveout;

  if v_provider.clawback_debt_balance > 0 and v_net_provider > 0 then
    v_clawback_deducted := least(v_provider.clawback_debt_balance, v_net_provider);
    v_net_provider := v_net_provider - v_clawback_deducted;

    update public.profiles
       set clawback_debt_balance = clawback_debt_balance - v_clawback_deducted
     where id = v_provider.id;

    insert into public.warranty_pool_ledger (
      job_id, entry_type, amount, labor_reference_cap,
      original_provider_id, client_id, notes
    ) values (
      v_job.id, 'CLAWBACK_RECOVERY_CREDIT', v_clawback_deducted, v_fee_bearing_base,
      v_provider.id, v_job.client_id, 'Compensação automática de saldo devedor de retrabalho/clawback anterior.'
    );
  end if;

  if v_warranty_carveout > 0 then
    insert into public.warranty_pool_ledger (
      job_id, entry_type, amount, labor_reference_cap,
      original_provider_id, client_id, notes
    ) values (
      v_job.id, 'CARVEOUT_CONTRIBUTION_1_5_PCT', v_warranty_carveout, v_fee_bearing_base,
      v_provider.id, v_job.client_id,
      case
        when v_unverified_materials > 0
          then 'Carve-out de 1,5% sobre mão de obra + materiais sem verificação SEFAZ concluída.'
        else 'Carve-out de 1,5% da taxa de intermediação sobre mão de obra.'
      end
    );
  end if;

  if v_provider.trust_tier = 'VERIFIED_ANCHOR' then
    v_maturation_days := 2;
  elsif v_provider.trust_tier = 'TRAINEE' or v_provider.completed_jobs_count < 3 then
    v_maturation_days := 7;
  else
    v_maturation_days := 5;
  end if;

  insert into public.escrow_maturation_entries (
    job_id, provider_id, gross_labor_amount, materials_reimbursement_amount,
    platform_operational_fee, warranty_carveout_fee, net_provider_amount,
    maturation_status, available_at
  ) values (
    v_job.id, v_provider.id, v_labor, v_exempt_materials,
    v_operational_fee, v_warranty_carveout, v_net_provider,
    'MATURING', now() + (v_maturation_days || ' days')::interval
  )
  on conflict (job_id) do nothing;

  update public.profiles
     set maturing_wallet_balance = maturing_wallet_balance + v_net_provider,
         completed_jobs_count = completed_jobs_count + 1
   where id = v_provider.id;
end $$;

revoke all on function public.settle_escrow_with_carveout_and_maturation(uuid)
  from public, anon, authenticated;

comment on function public.settle_escrow_with_carveout_and_maturation(uuid) is
  'Liquidação interna do escrow com carve-out de 1,5% e maturação D+N. A isenção de 0% sobre materiais só se aplica a documentos fiscais com verification_status = VERIFIED_SEFAZ (cStat=100, sem clawback); materiais PENDING_SEFAZ ou sem nota pagam taxa padrão de 15%.';

create or replace function public.audit_sefaz_phase2_cancellation_and_clawback(
  p_document_id uuid,
  p_sefaz_status_recheck int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc          public.job_fiscal_documents%rowtype;
  v_job          public.jobs%rowtype;
  v_was_verified boolean;
  v_op_fee       numeric(12,2);
  v_reserve_fee  numeric(12,2);
  v_evaded_fee   numeric(12,2);
begin
  select *
    into v_doc
    from public.job_fiscal_documents
   where id = p_document_id
     for update;

  if not found then
    raise exception 'FISCAL_DOCUMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_was_verified := (v_doc.verification_status = 'VERIFIED_SEFAZ');

  if p_sefaz_status_recheck = 100 then
    update public.job_fiscal_documents
       set sefaz_status_initial = coalesce(sefaz_status_initial, 100),
           sefaz_status_recheck = 100,
           verification_status = case when clawback_triggered then 'CANCELED_CLAWBACK' else 'VERIFIED_SEFAZ' end,
           rechecked_at = now()
     where id = p_document_id;

    return jsonb_build_object(
      'canceled_on_sefaz', false,
      'sefaz_confirmed', (not v_doc.clawback_triggered),
      'sefaz_verified', (not v_doc.clawback_triggered),
      'verification_status', case when v_doc.clawback_triggered then 'CANCELED_CLAWBACK' else 'VERIFIED_SEFAZ' end,
      'sefaz_status_recheck', 100
    );
  end if;

  -- cStat 101 / 151 / 155 = Cancelamento homologado na SEFAZ
  if p_sefaz_status_recheck in (101, 151, 155) then
    update public.job_fiscal_documents
       set sefaz_status_recheck = p_sefaz_status_recheck,
           verification_status = 'CANCELED_CLAWBACK',
           clawback_triggered = true,
           rechecked_at = now()
     where id = p_document_id;

    -- Só aplica clawback retroativo de 15% se a nota já havia concedido isenção em liquidação anterior
    if v_was_verified and not v_doc.clawback_triggered and exists (
      select 1 from public.escrow_maturation_entries e
       where e.job_id = v_doc.job_id and e.materials_reimbursement_amount > 0
    ) then
      select * into v_job from public.jobs where id = v_doc.job_id;
      v_op_fee := round(v_doc.declared_material_amount * 0.1350, 2);
      v_reserve_fee := round(v_doc.declared_material_amount * 0.0150, 2);
      v_evaded_fee := v_op_fee + v_reserve_fee;

      update public.profiles
         set clawback_debt_balance = clawback_debt_balance + v_evaded_fee,
             external_trust_score = greatest(0, external_trust_score - 120)
       where id = v_doc.provider_id;

      if v_reserve_fee > 0 then
        insert into public.warranty_pool_ledger (
          job_id, entry_type, amount, labor_reference_cap,
          original_provider_id, client_id, notes
        ) values (
          v_doc.job_id, 'CARVEOUT_CONTRIBUTION_1_5_PCT', v_reserve_fee, v_doc.declared_material_amount,
          v_doc.provider_id, v_job.client_id,
          'Recuperação de Carve-Out (1,5%) por cancelamento de nota fiscal na SEFAZ (cStat ' || p_sefaz_status_recheck || ').'
        );
      end if;

      return jsonb_build_object(
        'canceled_on_sefaz', true,
        'verification_status', 'CANCELED_CLAWBACK',
        'clawback_debited', v_evaded_fee,
        'reclassified_amount', v_doc.declared_material_amount
      );
    end if;

    return jsonb_build_object(
      'canceled_on_sefaz', true,
      'verification_status', 'CANCELED_CLAWBACK',
      'clawback_debited', 0.00,
      'reclassified_amount', v_doc.declared_material_amount
    );
  end if;

  -- Qualquer outro cStat != 100 (denegada / inexistente)
  update public.job_fiscal_documents
     set sefaz_status_recheck = p_sefaz_status_recheck,
         verification_status = 'REJECTED_SEFAZ',
         rechecked_at = now()
   where id = p_document_id;

  return jsonb_build_object(
    'canceled_on_sefaz', false,
    'sefaz_verified', false,
    'verification_status', 'REJECTED_SEFAZ',
    'sefaz_status_recheck', p_sefaz_status_recheck
  );
end $$;

revoke all on function public.audit_sefaz_phase2_cancellation_and_clawback(uuid, int)
  from public, anon, authenticated;
grant execute on function public.audit_sefaz_phase2_cancellation_and_clawback(uuid, int)
  to service_role;

comment on function public.audit_sefaz_phase2_cancellation_and_clawback(uuid, int) is
  'Oráculo server-side (service_role) de confirmação/rechecagem SEFAZ: promove PENDING_SEFAZ -> VERIFIED_SEFAZ (cStat=100) ou REJECTED_SEFAZ / CANCELED_CLAWBACK (cStat 101/151/155).';

commit;

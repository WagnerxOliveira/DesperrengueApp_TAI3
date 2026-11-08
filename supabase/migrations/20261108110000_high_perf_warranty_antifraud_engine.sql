-- ============================================================================
-- MIGRATION: 20261108110000_high_perf_warranty_antifraud_engine.sql
-- DESCRIÇÃO: Arquitetura de Alta Performance, Garantia em 3 Camadas,
--            Motor Antifraude, Score RTS Relativo Materializado O(1),
--            Ordem Canônica de Locks (Zero Deadlock) e Workers SKIP LOCKED.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. EXTENSÃO DA TABELA public.profiles (CONFIANÇA, MARCO ZERO E CARTEIRA)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS trust_tier TEXT NOT NULL DEFAULT 'STANDARD'
    CHECK (trust_tier IN ('TRAINEE', 'STANDARD', 'VERIFIED_ANCHOR', 'SUSPENDED')),
  ADD COLUMN IF NOT EXISTS is_trusted_anchor BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS external_trust_score NUMERIC(5,2) NOT NULL DEFAULT 0.00
    CHECK (external_trust_score >= 0 AND external_trust_score <= 100),
  ADD COLUMN IF NOT EXISTS kyc_biometric_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS mei_cnpj_active_months INTEGER NOT NULL DEFAULT 0
    CHECK (mei_cnpj_active_months >= 0),
  ADD COLUMN IF NOT EXISTS technical_cert_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS completed_jobs_count INTEGER NOT NULL DEFAULT 0
    CHECK (completed_jobs_count >= 0),
  ADD COLUMN IF NOT EXISTS abandoned_warranty_count INTEGER NOT NULL DEFAULT 0
    CHECK (abandoned_warranty_count >= 0),
  ADD COLUMN IF NOT EXISTS waterfall_tier_rank SMALLINT NOT NULL DEFAULT 5
    CHECK (waterfall_tier_rank BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS has_open_dispute BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS clawback_debt_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (clawback_debt_balance >= 0),
  ADD COLUMN IF NOT EXISTS available_wallet_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (available_wallet_balance >= 0),
  ADD COLUMN IF NOT EXISTS maturing_wallet_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (maturing_wallet_balance >= 0),
  ADD COLUMN IF NOT EXISTS device_fingerprint_hash TEXT,
  ADD COLUMN IF NOT EXISTS pix_key_cpf_matched BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS last_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS last_longitude DOUBLE PRECISION;

-- ----------------------------------------------------------------------------
-- 2. EXTENSÃO DA TABELA public.jobs (SPLIT INTELIGENTE, CUSTÓDIA E FORENSE)
-- ----------------------------------------------------------------------------
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS labor_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (labor_amount >= 0),
  ADD COLUMN IF NOT EXISTS materials_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (materials_amount >= 0),
  ADD COLUMN IF NOT EXISTS escrow_status TEXT NOT NULL DEFAULT 'NONE'
    CHECK (escrow_status IN (
      'NONE', 'LOCKED_100', 'RELEASED_TO_MATURATION',
      'FROZEN_IN_MEDIATION', 'REFUNDED_TO_CLIENT', 'CONVERTED_TO_REWORK'
    )),
  ADD COLUMN IF NOT EXISTS checkout_pin_hash TEXT,
  ADD COLUMN IF NOT EXISTS auto_release_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS warranty_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS checkin_photo_phash BIGINT,
  ADD COLUMN IF NOT EXISTS checkout_photo_phash BIGINT,
  ADD COLUMN IF NOT EXISTS checkin_gps_distance_m NUMERIC(8,2),
  ADD COLUMN IF NOT EXISTS checkout_gps_distance_m NUMERIC(8,2),
  ADD COLUMN IF NOT EXISTS is_warranty_rework BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS parent_job_id UUID REFERENCES public.jobs(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS original_faulty_provider_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- 3. LIVRO-RAZÃO IMUTÁVEL DO FUNDO DE GARANTIA (CAMADA 2 E CAMADA 3)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warranty_pool_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE RESTRICT,
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'CARVEOUT_CONTRIBUTION_1_5_PCT',
    'REWORK_PAYOUT_DEBIT',
    'CLAWBACK_RECOVERY_CREDIT',
    'COLD_START_SEED_RESERVE'
  )),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  labor_reference_cap NUMERIC(12,2) NOT NULL CHECK (labor_reference_cap >= 0),
  original_provider_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
  rescuer_provider_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
  client_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- INVARIANTE 1: Teto máximo de cobertura de retrabalho <= 100% da Mão de Obra original
  CONSTRAINT chk_invariant_1_coverage_cap CHECK (
    entry_type <> 'REWORK_PAYOUT_DEBIT' OR amount <= labor_reference_cap
  ),
  -- INVARIANTE 2: Disjunção estrita de identidade na Camada 3
  CONSTRAINT chk_invariant_2_identity_disjunction CHECK (
    entry_type <> 'REWORK_PAYOUT_DEBIT' OR (
      rescuer_provider_id IS NOT NULL AND
      original_provider_id IS NOT NULL AND
      client_id IS NOT NULL AND
      rescuer_provider_id <> original_provider_id AND
      rescuer_provider_id <> client_id
    )
  )
);

-- ----------------------------------------------------------------------------
-- 4. FILA DE MATURAÇÃO PROGRESSIVA DE REPASSES (D+5 / D+7 / D+2)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escrow_maturation_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL UNIQUE REFERENCES public.jobs(id) ON DELETE RESTRICT,
  provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  gross_labor_amount NUMERIC(12,2) NOT NULL CHECK (gross_labor_amount >= 0),
  materials_reimbursement_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (materials_reimbursement_amount >= 0),
  platform_operational_fee NUMERIC(12,2) NOT NULL CHECK (platform_operational_fee >= 0),
  warranty_carveout_fee NUMERIC(12,2) NOT NULL CHECK (warranty_carveout_fee >= 0),
  net_provider_amount NUMERIC(12,2) NOT NULL CHECK (net_provider_amount >= 0),
  maturation_status TEXT NOT NULL DEFAULT 'MATURING'
    CHECK (maturation_status IN ('MATURING', 'FROZEN_BY_DISPUTE', 'AVAILABLE_FOR_PIX', 'CLAWED_BACK')),
  available_at TIMESTAMPTZ NOT NULL,
  released_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 5. MÁQUINA DE ESTADOS DE MEDIAÇÃO E ACIONAMENTO DE GARANTIA (5 FASES)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.job_mediations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE RESTRICT,
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  original_provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  rescuer_provider_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
  current_phase TEXT NOT NULL DEFAULT 'PHASE_1_OPENED_AND_FROZEN'
    CHECK (current_phase IN (
      'PHASE_1_OPENED_AND_FROZEN',
      'PHASE_2_FORENSIC_TRIAGE',
      'PHASE_3_ORIGINAL_PROVIDER_SLA_6H',
      'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH',
      'PHASE_5_SETTLED_AND_CERTIFIED'
    )),
  claim_Category TEXT NOT NULL DEFAULT 'EXECUTION_DEFECT'
    CHECK (claim_category IN ('EXECUTION_DEFECT', 'INCOMPLETE_SERVICE', 'NEW_ADDITIONAL_SCOPE', 'FRAUD_SUSPICION')),
  defect_description TEXT NOT NULL,
  defect_photo_url TEXT NOT NULL,
  defect_photo_phash BIGINT NOT NULL,
  defect_gps_distance_m NUMERIC(8,2) NOT NULL,
  original_provider_deadline_at TIMESTAMPTZ NOT NULL,
  resolution_outcome TEXT CHECK (resolution_outcome IN (
    'REPAIRED_BY_ORIGINAL_PROVIDER',
    'REPAIRED_BY_LAYER3_RESCUER',
    'REFUNDED_TO_CLIENT',
    'REJECTED_AS_OUT_OF_SCOPE'
  )),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. CERTIFICADOS DIGITAIS DE GARANTIA E PRONTUÁRIO DO IMÓVEL
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.forensic_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  certificate_code TEXT NOT NULL UNIQUE,
  job_id UUID NOT NULL UNIQUE REFERENCES public.jobs(id) ON DELETE RESTRICT,
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  sha256_integrity_seal TEXT NOT NULL,
  checkin_phash BIGINT NOT NULL,
  checkout_phash BIGINT NOT NULL,
  warranty_until TIMESTAMPTZ NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. ÍNDICES DE ALTA SELETIVIDADE E PODAGEM ESPACIAL O(log N)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_rescue_waterfall_bbox
  ON public.profiles (waterfall_tier_rank ASC, last_latitude, last_longitude)
  WHERE is_provider = TRUE
    AND has_open_dispute = FALSE
    AND trust_tier <> 'SUSPENDED'
    AND last_latitude IS NOT NULL
    AND last_longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_client_provider_link
  ON public.jobs (client_id, provider_id);

CREATE INDEX IF NOT EXISTS idx_jobs_provider_client_link
  ON public.jobs (provider_id, client_id);

CREATE INDEX IF NOT EXISTS idx_jobs_rescuer_cooldown_24h
  ON public.jobs (provider_id, created_at DESC)
  WHERE is_warranty_rework = TRUE;

CREATE INDEX IF NOT EXISTS idx_jobs_auto_release_queue
  ON public.jobs (auto_release_at ASC)
  WHERE status = 'awaiting_approval' AND escrow_status = 'LOCKED_100';

CREATE INDEX IF NOT EXISTS idx_escrow_maturation_queue
  ON public.escrow_maturation_entries (available_at ASC)
  WHERE maturation_status = 'MATURING';

CREATE INDEX IF NOT EXISTS idx_mediations_sla_6h_queue
  ON public.job_mediations (original_provider_deadline_at ASC)
  WHERE current_phase IN ('PHASE_1_OPENED_AND_FROZEN', 'PHASE_3_ORIGINAL_PROVIDER_SLA_6H');

-- ----------------------------------------------------------------------------
-- 8. FUNÇÕES MATEMÁTICAS O(1): DISTÂNCIA DE HAMMING 64-BIT & SCORE RTS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hamming_distance_64(hash_a BIGINT, hash_b BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  x BIGINT := hash_a # hash_b;
  c INTEGER := 0;
BEGIN
  WHILE x <> 0 LOOP
    x := x & (x - 1);
    c := c + 1;
  END LOOP;
  RETURN c;
END;
$$;

CREATE OR REPLACE FUNCTION public.calculate_relative_trust_score(
  p_kyc_verified BOOLEAN,
  p_mei_months INTEGER,
  p_tech_cert BOOLEAN,
  p_completed_jobs INTEGER,
  p_abandoned_warranties INTEGER
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  v_score NUMERIC(5,2) := 0.00;
BEGIN
  IF p_kyc_verified THEN v_score := v_score + 30.00; END IF;
  IF COALESCE(p_mei_months, 0) >= 6 THEN v_score := v_score + 20.00; END IF;
  IF p_tech_cert THEN v_score := v_score + 20.00; END IF;
  v_score := v_score + LEAST(COALESCE(p_completed_jobs, 0) * 6.00, 30.00);
  v_score := v_score - (COALESCE(p_abandoned_warranties, 0) * 50.00);
  RETURN GREATEST(0.00, LEAST(100.00, v_score));
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. TRIGGER DE MANUTENÇÃO INCREMENTAL O(1) DE RTS E WATERFALL TIER RANK
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_sync_profile_trust_and_rank()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.external_trust_score := public.calculate_relative_trust_score(
    COALESCE(NEW.kyc_biometric_verified, FALSE) OR (COALESCE(NEW.liveness_verified, FALSE) AND COALESCE(NEW.ocr_verified, FALSE)),
    NEW.mei_cnpj_active_months,
    NEW.technical_cert_verified,
    NEW.completed_jobs_count,
    NEW.abandoned_warranty_count
  );

  IF NEW.is_trusted_anchor = TRUE THEN
    NEW.waterfall_tier_rank := 1;
  ELSIF NEW.completed_jobs_count >= 5 AND NEW.abandoned_warranty_count = 0 THEN
    NEW.waterfall_tier_rank := 2;
  ELSIF NEW.completed_jobs_count BETWEEN 1 AND 4 AND NEW.abandoned_warranty_count = 0 THEN
    NEW.waterfall_tier_rank := 3;
  ELSIF NEW.completed_jobs_count = 0 AND NEW.external_trust_score >= 70.00 THEN
    NEW.waterfall_tier_rank := 4;
  ELSE
    NEW.waterfall_tier_rank := 5;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_trust_and_rank_biu ON public.profiles;
CREATE TRIGGER sync_profile_trust_and_rank_biu
  BEFORE INSERT OR UPDATE OF
    is_trusted_anchor, kyc_biometric_verified, mei_cnpj_active_months,
    technical_cert_verified, completed_jobs_count, abandoned_warranty_count
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_trust_and_rank();

-- ----------------------------------------------------------------------------
-- 10. RPC 1: CHECK-OUT COM GUARDA FORENSE pHASH E GATILHO DE 24H
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_job_and_schedule_escrow(
  p_job_id UUID,
  p_provider_id UUID,
  p_checkout_phash BIGINT,
  p_checkout_gps_distance_m NUMERIC,
  p_client_pin_plain TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.jobs%ROWTYPE;
  v_hamming INTEGER;
  v_pin_matched BOOLEAN := FALSE;
BEGIN
  -- Lock Ordem Canônica: 1. jobs
  SELECT * INTO v_job
  FROM public.jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR_JOB_NOT_FOUND: Ordem de serviço inexistente.';
  END IF;

  IF v_job.provider_id <> p_provider_id THEN
    RAISE EXCEPTION 'ERR_UNAUTHORIZED_PROVIDER: Apenas o prestador alocado pode concluir o serviço.';
  END IF;

  IF p_checkout_gps_distance_m > 150.0 THEN
    RAISE EXCEPTION 'ERR_GEOFENCE_VIOLATION: Check-out fora do raio máximo de 150m do imóvel (% m).', p_checkout_gps_distance_m;
  END IF;

  IF v_job.checkin_photo_phash IS NOT NULL THEN
    v_hamming := public.hamming_distance_64(v_job.checkin_photo_phash, p_checkout_phash);
    IF v_hamming < 5 THEN
      RAISE EXCEPTION 'ERR_DUPLICATE_FORENSIC_PHOTO: A foto de conclusão é idêntica ou reciclada da foto de entrada (Hamming=% < 5).', v_hamming;
    END IF;
  END IF;

  IF p_client_pin_plain IS NOT NULL AND v_job.checkout_pin_hash IS NOT NULL THEN
    v_pin_matched := (v_job.checkout_pin_hash = crypt(p_client_pin_plain, v_job.checkout_pin_hash));
    IF NOT v_pin_matched THEN
      RAISE EXCEPTION 'ERR_INVALID_CHECKOUT_PIN: Código PIN de 4 dígitos inválido.';
    END IF;
  END IF;

  IF v_pin_matched THEN
    UPDATE public.jobs
    SET status = 'completed',
        escrow_status = 'RELEASED_TO_MATURATION',
        checkout_photo_phash = p_checkout_phash,
        checkout_gps_distance_m = p_checkout_gps_distance_m,
        warranty_expires_at = NOW() + INTERVAL '90 days',
        updated_at = NOW()
    WHERE id = p_job_id;

    PERFORM public.settle_escrow_with_carveout_and_maturation(p_job_id);
    RETURN jsonb_build_object('status', 'COMPLETED_BY_PIN', 'maturation_scheduled', TRUE);
  ELSE
    UPDATE public.jobs
    SET status = 'awaiting_approval',
        checkout_photo_phash = p_checkout_phash,
        checkout_gps_distance_m = p_checkout_gps_distance_m,
        auto_release_at = NOW() + INTERVAL '24 hours',
        updated_at = NOW()
    WHERE id = p_job_id;

    RETURN jsonb_build_object(
      'status', 'AWAITING_CLIENT_APPROVAL_24H',
      'auto_release_at', (NOW() + INTERVAL '24 hours')
    );
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. RPC 2: LIQUIDAÇÃO DO ESCROW COM CARVE-OUT 1,5% E MATURAÇÃO D+N
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.settle_escrow_with_carveout_and_maturation(
  p_job_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.jobs%ROWTYPE;
  v_provider public.profiles%ROWTYPE;
  v_operational_fee NUMERIC(12,2);
  v_warranty_carveout NUMERIC(12,2);
  v_net_provider NUMERIC(12,2);
  v_clawback_deducted NUMERIC(12,2) := 0.00;
  v_maturation_days INTEGER := 5;
BEGIN
  -- Lock Ordem Canônica: 1. jobs -> 4. profiles
  SELECT * INTO v_job FROM public.jobs WHERE id = p_job_id FOR UPDATE;
  SELECT * INTO v_provider FROM public.profiles WHERE id = v_job.provider_id FOR UPDATE;

  -- Cálculo aritmético exato: 13,5% operacional + 1,5% Fundo de Garantia (exclusivamente sobre Mão de Obra)
  v_operational_fee := ROUND(v_job.labor_amount * 0.135, 2);
  v_warranty_carveout := ROUND(v_job.labor_amount * 0.015, 2);
  v_net_provider := (v_job.labor_amount - v_operational_fee - v_warranty_carveout) + v_job.materials_amount;

  -- Recuperação automática de dívida de Clawback anterior
  IF v_provider.clawback_debt_balance > 0 AND v_net_provider > 0 THEN
    v_clawback_deducted := LEAST(v_provider.clawback_debt_balance, v_net_provider);
    v_net_provider := v_net_provider - v_clawback_deducted;

    UPDATE public.profiles
    SET clawback_debt_balance = clawback_debt_balance - v_clawback_deducted
    WHERE id = v_provider.id;

    INSERT INTO public.warranty_pool_ledger (
      job_id, entry_type, amount, labor_reference_cap,
      original_provider_id, client_id, notes
    ) VALUES (
      v_job.id, 'CLAWBACK_RECOVERY_CREDIT', v_clawback_deducted, v_job.labor_amount,
      v_provider.id, v_job.client_id, 'Compensação automática de saldo devedor de retrabalho anterior.'
    );
  END IF;

  -- Aporte de 1,5% no Fundo de Garantia (Camada 2)
  IF v_warranty_carveout > 0 THEN
    INSERT INTO public.warranty_pool_ledger (
      job_id, entry_type, amount, labor_reference_cap,
      original_provider_id, client_id, notes
    ) VALUES (
      v_job.id, 'CARVEOUT_CONTRIBUTION_1_5_PCT', v_warranty_carveout, v_job.labor_amount,
      v_provider.id, v_job.client_id, 'Carve-out de 1,5% da taxa de intermediação sobre mão de obra.'
    );
  END IF;

  -- Janela de Maturação segundo Nível de Confiança
  IF v_provider.trust_tier = 'VERIFIED_ANCHOR' THEN
    v_maturation_days := 2;
  ELSIF v_provider.trust_tier = 'TRAINEE' OR v_provider.completed_jobs_count < 3 THEN
    v_maturation_days := 7;
  ELSE
    v_maturation_days := 5;
  END IF;

  INSERT INTO public.escrow_maturation_entries (
    job_id, provider_id, gross_labor_amount, materials_reimbursement_amount,
    platform_operational_fee, warranty_carveout_fee, net_provider_amount,
    maturation_status, available_at
  ) VALUES (
    v_job.id, v_provider.id, v_job.labor_amount, v_job.materials_amount,
    v_operational_fee, v_warranty_carveout, v_net_provider,
    'MATURING', NOW() + (v_maturation_days || ' days')::INTERVAL
  )
  ON CONFLICT (job_id) DO NOTHING;

  UPDATE public.profiles
  SET maturing_wallet_balance = maturing_wallet_balance + v_net_provider,
      completed_jobs_count = completed_jobs_count + 1
  WHERE id = v_provider.id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. RPC 3: ABERTURA DE MEDIAÇÃO COM CONGELAMENTO PREVENTIVO (CIRCUIT BREAKER)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_warranty_mediation(
  p_job_id UUID,
  p_client_id UUID,
  p_claim_category TEXT,
  p_defect_description TEXT,
  p_defect_photo_url TEXT,
  p_defect_photo_phash BIGINT,
  p_defect_gps_distance_m NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.jobs%ROWTYPE;
  v_mediation_id UUID;
BEGIN
  -- Lock Ordem Canônica: 1. jobs
  SELECT * INTO v_job FROM public.jobs WHERE id = p_job_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR_JOB_NOT_FOUND: Serviço não encontrado.';
  END IF;

  IF v_job.client_id <> p_client_id THEN
    RAISE EXCEPTION 'ERR_UNAUTHORIZED_CLIENT: Apenas o titular do pedido pode acionar a garantia.';
  END IF;

  IF v_job.warranty_expires_at IS NOT NULL AND NOW() > v_job.warranty_expires_at THEN
    RAISE EXCEPTION 'ERR_WARRANTY_EXPIRED: O prazo de garantia de 90 dias deste serviço expirou.';
  END IF;

  IF p_defect_gps_distance_m > 150.0 THEN
    RAISE EXCEPTION 'ERR_DEFECT_GEOFENCE_INVALID: A foto do defeito deve ser capturada no imóvel do serviço.';
  END IF;

  IF v_job.checkin_photo_phash IS NOT NULL AND public.hamming_distance_64(v_job.checkin_photo_phash, p_defect_photo_phash) < 5 THEN
    RAISE EXCEPTION 'ERR_RECYCLED_CHECKIN_PHOTO: A evidência enviada é idêntica à foto original de Antes.';
  END IF;

  IF v_job.checkout_photo_phash IS NOT NULL AND public.hamming_distance_64(v_job.checkout_photo_phash, p_defect_photo_phash) < 5 THEN
    RAISE EXCEPTION 'ERR_RECYCLED_CHECKOUT_PHOTO: A evidência enviada é idêntica à foto original de Depois.';
  END IF;

  -- Lock 2: job_mediations (INSERT)
  INSERT INTO public.job_mediations (
    job_id, client_id, original_provider_id, current_phase,
    claim_category, defect_description, defect_photo_url,
    defect_photo_phash, defect_gps_distance_m, original_provider_deadline_at
  ) VALUES (
    v_job.id, p_client_id, v_job.provider_id, 'PHASE_3_ORIGINAL_PROVIDER_SLA_6H',
    p_claim_category, p_defect_description, p_defect_photo_url,
    p_defect_photo_phash, p_defect_gps_distance_m, NOW() + INTERVAL '6 hours'
  ) RETURNING id INTO v_mediation_id;

  UPDATE public.jobs
  SET status = 'disputed',
      escrow_status = 'FROZEN_IN_MEDIATION',
      updated_at = NOW()
  WHERE id = p_job_id;

  -- Lock 3: escrow_maturation_entries
  UPDATE public.escrow_maturation_entries
  SET maturation_status = 'FROZEN_BY_DISPUTE'
  WHERE job_id = p_job_id AND maturation_status = 'MATURING';

  -- Lock 4: profiles (Circuit Breaker Preventivo)
  UPDATE public.profiles
  SET has_open_dispute = TRUE
  WHERE id = v_job.provider_id;

  RETURN v_mediation_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 13. RPC 4: ACIONAMENTO DA CAMADA 3 (WATERFALL 5 NÍVEIS, BOUNDING BOX E CLAWBACK)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_layer3_rework(
  p_mediation_id UUID,
  p_rework_labor_budget NUMERIC,
  p_idempotency_key UUID DEFAULT gen_random_uuid()
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mediation public.job_mediations%ROWTYPE;
  v_original_job public.jobs%ROWTYPE;
  v_maturation public.escrow_maturation_entries%ROWTYPE;
  v_original_provider public.profiles%ROWTYPE;
  v_client_profile public.profiles%ROWTYPE;
  v_rescuer_id UUID;
  v_rework_job_id UUID;
  v_clawed_from_maturation NUMERIC(12,2) := 0.00;
  v_clawed_from_available NUMERIC(12,2) := 0.00;
  v_remaining_debt NUMERIC(12,2) := 0.00;
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_delta_lat DOUBLE PRECISION := 15.0 / 111.32;
  v_delta_lng DOUBLE PRECISION;
BEGIN
  -- Idempotência estrita via chave única no ledger
  IF EXISTS (SELECT 1 FROM public.warranty_pool_ledger WHERE idempotency_key = p_idempotency_key) THEN
    SELECT id INTO v_rework_job_id
    FROM public.jobs
    WHERE parent_job_id = (SELECT job_id FROM public.job_mediations WHERE id = p_mediation_id)
      AND is_warranty_rework = TRUE
    LIMIT 1;
    RETURN v_rework_job_id;
  END IF;

  -- ORDEM CANÔNICA ESTRITA DE LOCKS:
  -- 1. public.jobs -> 2. public.job_mediations -> 3. public.escrow_maturation_entries -> 4. public.profiles
  SELECT j.* INTO v_original_job
  FROM public.jobs j
  JOIN public.job_mediations m ON m.job_id = j.id
  WHERE m.id = p_mediation_id
  FOR UPDATE OF j;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR_MEDIATION_NOT_FOUND: Mediação inexistente.';
  END IF;

  SELECT * INTO v_mediation
  FROM public.job_mediations
  WHERE id = p_mediation_id
  FOR UPDATE;

  IF p_rework_labor_budget > v_original_job.labor_amount THEN
    RAISE EXCEPTION 'ERR_COVERAGE_CAP_EXCEEDED: O orçamento de retrabalho (R$ %) excede o teto de 100%% da mão de obra original (R$ %).',
      p_rework_labor_budget, v_original_job.labor_amount;
  END IF;

  SELECT * INTO v_maturation
  FROM public.escrow_maturation_entries
  WHERE job_id = v_original_job.id
  FOR UPDATE;

  SELECT * INTO v_original_provider
  FROM public.profiles
  WHERE id = v_mediation.original_provider_id
  FOR UPDATE;

  SELECT * INTO v_client_profile
  FROM public.profiles
  WHERE id = v_mediation.client_id;

  -- Coordenadas de referência com Bounding Box Axial O(log N)
  v_lat := COALESCE(v_original_job.latitude, -22.25);
  v_lng := COALESCE(v_original_job.longitude, -45.70);
  v_delta_lng := 15.0 / (111.32 * GREATEST(0.1, COS(RADIANS(v_lat))));

  -- DESPACHO CEGO EM CASCATA DE 5 NÍVEIS (WATERFALL) COM FILTRO DE GRAFO ZERO-LINK
  SELECT p.id INTO v_rescuer_id
  FROM public.profiles p
  WHERE p.is_provider = TRUE
    AND p.has_open_dispute = FALSE
    AND p.trust_tier <> 'SUSPENDED'
    AND p.waterfall_tier_rank <= 4
    AND p.id <> v_mediation.original_provider_id
    AND p.id <> v_mediation.client_id
    -- Disjunção de Hardware / Device Fingerprint
    AND (
      p.device_fingerprint_hash IS NULL
      OR (
        p.device_fingerprint_hash <> COALESCE(v_original_provider.device_fingerprint_hash, '')
        AND p.device_fingerprint_hash <> COALESCE(v_client_profile.device_fingerprint_hash, '')
      )
    )
    -- Podagem Axial por Bounding Box antes de Haversine
    AND (
      p.last_latitude IS NULL
      OR (
        p.last_latitude BETWEEN (v_lat - v_delta_lat) AND (v_lat + v_delta_lat)
        AND p.last_longitude BETWEEN (v_lng - v_delta_lng) AND (v_lng + v_delta_lng)
        AND (
          6371.0 * 2.0 * ASIN(SQRT(
            POWER(SIN(RADIANS(p.last_latitude - v_lat) / 2.0), 2) +
            COS(RADIANS(v_lat)) * COS(RADIANS(p.last_latitude)) *
            POWER(SIN(RADIANS(p.last_longitude - v_lng) / 2.0), 2)
          ))
        ) <= 15.0
      )
    )
    -- Grafo Zero-Link: sem histórico prévio cruzado com cliente ou prestador original
    AND NOT EXISTS (
      SELECT 1 FROM public.jobs j_hist
      WHERE (j_hist.client_id = v_mediation.client_id AND j_hist.provider_id = p.id)
         OR (j_hist.client_id = p.id AND j_hist.provider_id = v_mediation.client_id)
         OR (j_hist.client_id = v_mediation.original_provider_id AND j_hist.provider_id = p.id)
         OR (j_hist.client_id = p.id AND j_hist.provider_id = v_mediation.original_provider_id)
    )
    -- Cooldown de 24h entre resgates de garantia
    AND NOT EXISTS (
      SELECT 1 FROM public.jobs j_cool
      WHERE j_cool.provider_id = p.id
        AND j_cool.is_warranty_rework = TRUE
        AND j_cool.created_at > NOW() - INTERVAL '24 hours'
    )
  ORDER BY
    p.waterfall_tier_rank ASC,
    p.external_trust_score DESC,
    hashtextextended(p.id::TEXT || p_mediation_id::TEXT, 0) ASC
  LIMIT 1;

  IF v_rescuer_id IS NULL THEN
    RAISE EXCEPTION 'ERR_NO_ELIGIBLE_RESCUER: Nenhum profissional independente elegível disponível no momento.';
  END IF;

  -- CLAWBACK FIRST: Retenção prioritária do repasse em maturação ou saldo disponível
  IF v_maturation.id IS NOT NULL AND v_maturation.maturation_status IN ('MATURING', 'FROZEN_BY_DISPUTE') THEN
    v_clawed_from_maturation := LEAST(v_maturation.net_provider_amount, p_rework_labor_budget);

    UPDATE public.escrow_maturation_entries
    SET maturation_status = 'CLAWED_BACK',
        net_provider_amount = net_provider_amount - v_clawed_from_maturation
    WHERE id = v_maturation.id;

    UPDATE public.profiles
    SET maturing_wallet_balance = GREATEST(0, maturing_wallet_balance - v_clawed_from_maturation)
    WHERE id = v_original_provider.id;
  END IF;

  v_remaining_debt := p_rework_labor_budget - v_clawed_from_maturation;

  IF v_remaining_debt > 0 AND v_original_provider.available_wallet_balance > 0 THEN
    v_clawed_from_available := LEAST(v_original_provider.available_wallet_balance, v_remaining_debt);
    v_remaining_debt := v_remaining_debt - v_clawed_from_available;

    UPDATE public.profiles
    SET available_wallet_balance = available_wallet_balance - v_clawed_from_available
    WHERE id = v_original_provider.id;
  END IF;

  -- Incrementa contador materializado O(1) de abandono de garantia (Trigger recalcula RTS e Rank)
  UPDATE public.profiles
  SET abandoned_warranty_count = abandoned_warranty_count + 1,
      clawback_debt_balance = clawback_debt_balance + v_remaining_debt
  WHERE id = v_original_provider.id;

  -- Criação da Nova Ordem de Serviço de Retrabalho (Camada 3)
  INSERT INTO public.jobs (
    client_id, provider_id, category, title, description,
    status, escrow_status, labor_amount, materials_amount,
    is_warranty_rework, parent_job_id, original_faulty_provider_id,
    latitude, longitude
  ) VALUES (
    v_original_job.client_id, v_rescuer_id, v_original_job.category,
    '[GARANTIA CAMADA 3] ' || v_original_job.title,
    'Ordem de retrabalho técnico coberta pela Reserva de Garantia Desperrengue.',
    'scheduled', 'LOCKED_100', p_rework_labor_budget, 0.00,
    TRUE, v_original_job.id, v_mediation.original_provider_id,
    v_original_job.latitude, v_original_job.longitude
  ) RETURNING id INTO v_rework_job_id;

  -- Registro no Livro-Razão do Fundo de Garantia (com verificação das Invariantes 1 e 2)
  INSERT INTO public.warranty_pool_ledger (
    idempotency_key, job_id, entry_type, amount, labor_reference_cap,
    original_provider_id, rescuer_provider_id, client_id, notes
  ) VALUES (
    p_idempotency_key, v_rework_job_id, 'REWORK_PAYOUT_DEBIT', p_rework_labor_budget, v_original_job.labor_amount,
    v_mediation.original_provider_id, v_rescuer_id, v_mediation.client_id,
    format('Despacho cego Camada 3. Clawback Maturação: R$ %s | Disponível: R$ %s | Dívida Residual: R$ %s',
           v_clawed_from_maturation, v_clawed_from_available, v_remaining_debt)
  );

  UPDATE public.job_mediations
  SET rescuer_provider_id = v_rescuer_id,
      current_phase = 'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH',
      resolution_outcome = 'REPAIRED_BY_LAYER3_RESCUER',
      updated_at = NOW()
  WHERE id = p_mediation_id;

  RETURN v_rework_job_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 14. RPC 5: WORKER ASSÍNCRONO NÃO-BLOQUEANTE (FOR UPDATE SKIP LOCKED LIMIT 100)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_autonomous_escrow_and_mediation_queues()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job_id UUID;
  v_maturation RECORD;
  v_auto_released_count INTEGER := 0;
  v_matured_count INTEGER := 0;
BEGIN
  -- 1. Liberação Automática em 24h (Auto-Release) para serviços sem contestação
  FOR v_job_id IN
    SELECT id FROM public.jobs
    WHERE status = 'awaiting_approval'
      AND escrow_status = 'LOCKED_100'
      AND auto_release_at <= NOW()
    ORDER BY auto_release_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 100
  LOOP
    UPDATE public.jobs
    SET status = 'completed',
        escrow_status = 'RELEASED_TO_MATURATION',
        warranty_expires_at = NOW() + INTERVAL '90 days',
        updated_at = NOW()
    WHERE id = v_job_id;

    PERFORM public.settle_escrow_with_carveout_and_maturation(v_job_id);
    v_auto_released_count := v_auto_released_count + 1;
  END LOOP;

  -- 2. Conversão de Saldo em Maturação (D+N) para Saldo Disponível PIX
  FOR v_maturation IN
    SELECT id, provider_id, net_provider_amount
    FROM public.escrow_maturation_entries
    WHERE maturation_status = 'MATURING'
      AND available_at <= NOW()
    ORDER BY available_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 100
  LOOP
    UPDATE public.escrow_maturation_entries
    SET maturation_status = 'AVAILABLE_FOR_PIX',
        released_at = NOW()
    WHERE id = v_maturation.id;

    UPDATE public.profiles
    SET maturing_wallet_balance = GREATEST(0, maturing_wallet_balance - v_maturation.net_provider_amount),
        available_wallet_balance = available_wallet_balance + v_maturation.net_provider_amount
    WHERE id = v_maturation.provider_id;

    v_matured_count := v_matured_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'auto_released_jobs', v_auto_released_count,
    'matured_escrow_entries', v_matured_count,
    'processed_at', NOW()
  );
END;
$$;

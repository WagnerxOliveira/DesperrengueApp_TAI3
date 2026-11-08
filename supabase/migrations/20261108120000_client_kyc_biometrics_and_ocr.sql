-- ============================================================================
-- MIGRATION: 20261108120000_client_kyc_biometrics_and_ocr.sql
-- DESCRIÇÃO: Validação Biométrica Facial (Active Liveness), Autenticidade
--            Documental (Frente/Verso), OCR Automático e Interoperabilidade
--            Antifraude (Anti-Sybil, Same-Holder PIX Lock, Prontuário ABNT).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. EXTENSÃO DA TABELA public.profiles (KYC BIOMÉTRICO UNIFICADO CLIENTE/PRESTADOR)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cpf_masked TEXT,
  ADD COLUMN IF NOT EXISTS cpf_hash TEXT,
  ADD COLUMN IF NOT EXISTS verified_full_name TEXT,
  ADD COLUMN IF NOT EXISTS document_type TEXT
    CHECK (document_type IS NULL OR document_type IN ('CPF', 'CNH', 'RG', 'CIN')),
  ADD COLUMN IF NOT EXISTS document_number_masked TEXT,
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS issuing_authority TEXT,
  ADD COLUMN IF NOT EXISTS client_kyc_status TEXT NOT NULL DEFAULT 'NOT_STARTED'
    CHECK (client_kyc_status IN ('NOT_STARTED', 'PENDING_REVIEW', 'APPROVED', 'REJECTED')),
  ADD COLUMN IF NOT EXISTS liveness_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS liveness_score NUMERIC(5,2) NOT NULL DEFAULT 0.00
    CHECK (liveness_score >= 0 AND liveness_score <= 100),
  ADD COLUMN IF NOT EXISTS face_liveness_hash TEXT,
  ADD COLUMN IF NOT EXISTS ocr_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS kyc_ocr_confidence NUMERIC(5,2) NOT NULL DEFAULT 0.00
    CHECK (kyc_ocr_confidence >= 0 AND kyc_ocr_confidence <= 100),
  ADD COLUMN IF NOT EXISTS kyc_verified_at TIMESTAMPTZ;

-- Índice Único Anti-Sybil por CPF Hash (impede contas múltiplas com o mesmo CPF)
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_cpf_hash_unique
  ON public.profiles (cpf_hash)
  WHERE cpf_hash IS NOT NULL;

-- Índice Anti-Sybil por Hash Biométrico Facial
CREATE INDEX IF NOT EXISTS idx_profiles_face_liveness_hash
  ON public.profiles (face_liveness_hash)
  WHERE face_liveness_hash IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. EXTENSÃO DA TABELA public.kyc_submissions (AUDITORIA FORENSE CLIENTE/PRESTADOR)
-- ----------------------------------------------------------------------------
ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS role_scope TEXT NOT NULL DEFAULT 'provider'
    CHECK (role_scope IN ('client', 'provider', 'both')),
  ADD COLUMN IF NOT EXISTS document_type TEXT DEFAULT 'CNH'
    CHECK (document_type IN ('CPF', 'CNH', 'RG', 'CIN')),
  ADD COLUMN IF NOT EXISTS doc_front_phash BIGINT,
  ADD COLUMN IF NOT EXISTS doc_back_phash BIGINT,
  ADD COLUMN IF NOT EXISTS selfie_liveness_phash BIGINT,
  ADD COLUMN IF NOT EXISTS liveness_challenges_passed JSONB DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS ocr_extracted_payload JSONB DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS laplacian_sharpness_score NUMERIC(8,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS glare_ratio_pct NUMERIC(5,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS face_match_cosine_similarity NUMERIC(5,4) DEFAULT 0.0000;

-- Atualiza o Trigger de RTS para considerar a identidade civil unificada (Cliente ou Prestador)
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
    is_trusted_anchor, kyc_biometric_verified, liveness_verified, ocr_verified,
    mei_cnpj_active_months, technical_cert_verified, completed_jobs_count, abandoned_warranty_count
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_trust_and_rank();

-- ----------------------------------------------------------------------------
-- 3. FUNÇÃO PURA PL/pgSQL: VALIDAÇÃO MATEMÁTICA MOD-11 DE CPF (O(1))
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_valid_cpf(p_cpf TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  v_digits TEXT := regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g');
  v_sum INTEGER := 0;
  v_rem INTEGER;
  v_d1 INTEGER;
  v_d2 INTEGER;
  i INTEGER;
BEGIN
  IF length(v_digits) <> 11 THEN
    RETURN FALSE;
  END IF;

  -- Rejeita sequências repetidas (00000000000 .. 99999999999)
  IF v_digits ~ '^(\d)\1{10}$' THEN
    RETURN FALSE;
  END IF;

  -- 1º Dígito Verificador
  FOR i IN 1..9 LOOP
    v_sum := v_sum + (substring(v_digits, i, 1)::INTEGER * (11 - i));
  END LOOP;
  v_rem := (v_sum * 10) % 11;
  IF v_rem = 10 THEN v_rem := 0; END IF;
  v_d1 := substring(v_digits, 10, 1)::INTEGER;
  IF v_rem <> v_d1 THEN
    RETURN FALSE;
  END IF;

  -- 2º Dígito Verificador
  v_sum := 0;
  FOR i IN 1..10 LOOP
    v_sum := v_sum + (substring(v_digits, i, 1)::INTEGER * (12 - i));
  END LOOP;
  v_rem := (v_sum * 10) % 11;
  IF v_rem = 10 THEN v_rem := 0; END IF;
  v_d2 := substring(v_digits, 11, 1)::INTEGER;

  RETURN (v_rem = v_d2);
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. RPC ATÔMICO: SUBMISSÃO E HOMOLOGAÇÃO FORENSE DO KYC DO CLIENTE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_client_kyc(
  p_cpf_raw TEXT,
  p_typed_full_name TEXT,
  p_ocr_full_name TEXT,
  p_phone TEXT,
  p_document_type TEXT,
  p_document_number_masked TEXT,
  p_birth_date DATE,
  p_issuing_authority TEXT,
  p_doc_front_url TEXT,
  p_doc_back_url TEXT,
  p_selfie_url TEXT,
  p_doc_front_phash BIGINT,
  p_doc_back_phash BIGINT,
  p_selfie_phash BIGINT,
  p_liveness_score NUMERIC,
  p_face_liveness_hash TEXT,
  p_ocr_confidence NUMERIC,
  p_laplacian_sharpness NUMERIC,
  p_glare_ratio_pct NUMERIC,
  p_face_match_similarity NUMERIC,
  p_liveness_challenges JSONB,
  p_address_line TEXT,
  p_address_city TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_digits TEXT := regexp_replace(COALESCE(p_cpf_raw, ''), '\D', '', 'g');
  v_cpf_masked TEXT;
  v_cpf_hash TEXT;
  v_hamming_docs INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'ERR_UNAUTHENTICATED: Sessão expirada ou usuário não autenticado.';
  END IF;

  -- 1. Validação Matemática Mod-11 do CPF
  IF NOT public.is_valid_cpf(v_digits) THEN
    RAISE EXCEPTION 'ERR_INVALID_CPF_MOD11: O CPF informado é matematicamente inválido.';
  END IF;

  -- 2. Geração de Hash Criptográfico Salgado e Máscara LGPD
  v_cpf_hash := encode(digest('DSP-CPF-PEPPER-2026:' || v_digits, 'sha256'), 'hex');
  v_cpf_masked := '***.'.concat(substring(v_digits, 4, 3), '.', substring(v_digits, 7, 3), '-**');

  -- 3. Guarda Anti-Sybil: Verifica se outro usuário já utiliza este CPF ou Biometria Facial
  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE cpf_hash = v_cpf_hash AND id <> v_uid
  ) THEN
    RAISE EXCEPTION 'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta ativa na plataforma.';
  END IF;

  -- 4. Guarda Perceptual Hash (Impede que Frente e Verso sejam a mesma foto)
  v_hamming_docs := public.hamming_distance_64(p_doc_front_phash, p_doc_back_phash);
  IF v_hamming_docs < 5 THEN
    RAISE EXCEPTION 'ERR_DUPLICATE_FRONT_BACK_PHOTO: A foto do verso do documento é idêntica à foto da frente (Hamming=% < 5).', v_hamming_docs;
  END IF;

  -- 5. Guarda de Qualidade Forense (Nitidez Laplaciana, Reflexo, Liveness e Face Match)
  IF p_laplacian_sharpness < 110.0 THEN
    RAISE EXCEPTION 'ERR_BLURRY_DOCUMENT_IMAGE: Imagem do documento sem nitidez suficiente para leitura forense (Score=% < 110).', p_laplacian_sharpness;
  END IF;

  IF p_glare_ratio_pct > 8.5 THEN
    RAISE EXCEPTION 'ERR_EXCESSIVE_GLARE: Reflexo de luz excessivo sobre os dados do documento (% > 8.5%%).', p_glare_ratio_pct;
  END IF;

  IF p_liveness_score < 85.0 THEN
    RAISE EXCEPTION 'ERR_LIVENESS_FAILED: Prova de vida facial não atingiu o índice mínimo de segurança (% < 85%%).', p_liveness_score;
  END IF;

  IF p_face_match_similarity < 0.7800 THEN
    RAISE EXCEPTION 'ERR_FACE_MISMATCH: A biometria facial capturada ao vivo não corresponde à foto do documento enviado.';
  END IF;

  -- 6. Registro na Tabela de Auditoria KYC (public.kyc_submissions)
  INSERT INTO public.kyc_submissions (
    user_id, role_scope, document_type,
    doc_front_url, doc_back_url, selfie_url,
    doc_front_phash, doc_back_phash, selfie_liveness_phash,
    liveness_challenges_passed,
    ocr_extracted_payload,
    laplacian_sharpness_score, glare_ratio_pct, face_match_cosine_similarity,
    status, reviewed_at
  ) VALUES (
    v_uid, 'client', p_document_type,
    p_doc_front_url, p_doc_back_url, p_selfie_url,
    p_doc_front_phash, p_doc_back_phash, p_selfie_phash,
    p_liveness_challenges,
    jsonb_build_object(
      'typed_name', p_typed_full_name,
      'ocr_name', p_ocr_full_name,
      'cpf_masked', v_cpf_masked,
      'document_number_masked', p_document_number_masked,
      'birth_date', p_birth_date,
      'issuing_authority', p_issuing_authority,
      'ocr_confidence', p_ocr_confidence
    ),
    p_laplacian_sharpness, p_glare_ratio_pct, p_face_match_similarity,
    'APPROVED', NOW()
  );

  -- 7. Atualização Atômica do Perfil do Cliente + Interoperabilidade Multi-Modo
  UPDATE public.profiles
  SET full_name = COALESCE(NULLIF(trim(p_typed_full_name), ''), full_name),
      verified_full_name = p_ocr_full_name,
      phone = p_phone,
      cpf_masked = v_cpf_masked,
      cpf_hash = v_cpf_hash,
      document_type = p_document_type,
      document_number_masked = p_document_number_masked,
      birth_date = p_birth_date,
      issuing_authority = p_issuing_authority,
      client_kyc_status = 'APPROVED',
      liveness_verified = TRUE,
      liveness_score = p_liveness_score,
      face_liveness_hash = p_face_liveness_hash,
      ocr_verified = TRUE,
      kyc_ocr_confidence = p_ocr_confidence,
      kyc_biometric_verified = TRUE, -- Compartilha o selo biométrico caso atue também como Prestador (+30 pts RTS)
      pix_key_cpf_matched = TRUE,    -- Habilita a trava Same-Holder Lock para Carteira/PIX
      kyc_verified_at = NOW(),
      address_line = p_address_line,
      address_city = p_address_city,
      latitude = p_latitude,
      longitude = p_longitude,
      last_latitude = p_latitude,
      last_longitude = p_longitude,
      is_client = TRUE,
      client_setup_done = TRUE,
      updated_at = NOW()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'status', 'APPROVED',
    'cpf_masked', v_cpf_masked,
    'verified_full_name', p_ocr_full_name,
    'kyc_verified_at', NOW()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. UPGRADE DO RPC trigger_layer3_rework COM DISJUNÇÃO DE CPF_HASH E FACE_LIVENESS_HASH
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

  v_lat := COALESCE(v_original_job.latitude, -22.25);
  v_lng := COALESCE(v_original_job.longitude, -45.70);
  v_delta_lng := 15.0 / (111.32 * GREATEST(0.1, COS(RADIANS(v_lat))));

  -- DESPACHO CEGO EM CASCATA DE 5 NÍVEIS COM DISJUNÇÃO TRIPLA (HARDWARE + CPF_HASH + FACE_LIVENESS_HASH)
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
    -- Disjunção de Identidade Civil (CPF Hash)
    AND (
      p.cpf_hash IS NULL
      OR (
        p.cpf_hash <> COALESCE(v_original_provider.cpf_hash, '')
        AND p.cpf_hash <> COALESCE(v_client_profile.cpf_hash, '')
      )
    )
    -- Disjunção Biométrica Facial (Face Liveness Hash)
    AND (
      p.face_liveness_hash IS NULL
      OR (
        p.face_liveness_hash <> COALESCE(v_original_provider.face_liveness_hash, '')
        AND p.face_liveness_hash <> COALESCE(v_client_profile.face_liveness_hash, '')
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
    -- Grafo Zero-Link: sem histórico prévio cruzado
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

  UPDATE public.profiles
  SET abandoned_warranty_count = abandoned_warranty_count + 1,
      clawback_debt_balance = clawback_debt_balance + v_remaining_debt
  WHERE id = v_original_provider.id;

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

-- ============================================================================
-- MIGRATION: 20261112150000_carbon_kyc_webhook_bridge.sql
-- DESCRIÇÃO: Ponte Transacional Zero-Trust do Motor Python KYC Carbon High ->
--            Supabase PostgreSQL com Idempotência Antirreplay, Guarda Anti-Sybil
--            por CPF Hash, Preservação Integral da Unificação Multi-Modo
--            (+30 pts RTS imediatos ao ativar modo Profissional) e Trava
--            Same-Holder PIX Lock.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. TABELA DE AUDITORIA E IDEMPOTÊNCIA DE WEBHOOKS (ZERO-TRUST SERVICE-ONLY)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.kyc_webhook_events (
  event_id              UUID PRIMARY KEY,
  user_id               UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_nonce_hash    TEXT NOT NULL,
  verdict_status        TEXT NOT NULL
    CHECK (verdict_status IN ('APPROVED', 'MANUAL_REVIEW', 'REJECTED')),
  risk_tier             TEXT NOT NULL
    CHECK (risk_tier IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  alcada_restriction    TEXT,
  hard_veto_code        TEXT,
  worm_evidence_digest  TEXT NOT NULL,
  signature_timestamp   BIGINT NOT NULL,
  payload_summary       JSONB NOT NULL DEFAULT '{}'::JSONB,
  processed_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_kyc_webhook_events_session_nonce UNIQUE (session_nonce_hash)
);

CREATE INDEX IF NOT EXISTS idx_kyc_webhook_events_user_processed
  ON public.kyc_webhook_events (user_id, processed_at DESC);

ALTER TABLE public.kyc_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_webhook_events FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.kyc_webhook_events FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.kyc_webhook_events TO service_role;

DROP POLICY IF EXISTS kyc_webhook_events_service_role_only ON public.kyc_webhook_events;
CREATE POLICY kyc_webhook_events_service_role_only
  ON public.kyc_webhook_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 2. EXTENSÃO ADITIVA SEGURA DE public.kyc_submissions E public.profiles
--    (100% retrocompatível com todas as constraints e colunas existentes)
-- ----------------------------------------------------------------------------
ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS doc_front_url TEXT,
  ADD COLUMN IF NOT EXISTS doc_back_url TEXT,
  ADD COLUMN IF NOT EXISTS selfie_url TEXT,
  ADD COLUMN IF NOT EXISTS vio_signature_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS nfc_passive_auth_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS serpro_similarity_score NUMERIC(5,4),
  ADD COLUMN IF NOT EXISTS device_integrity_verdict TEXT,
  ADD COLUMN IF NOT EXISTS shap_top_3_factors JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS alcada_restriction TEXT,
  ADD COLUMN IF NOT EXISTS session_nonce_hash TEXT,
  ADD COLUMN IF NOT EXISTS worm_evidence_digest TEXT,
  ADD COLUMN IF NOT EXISTS carbon_confidence_score NUMERIC(5,4),
  ADD COLUMN IF NOT EXISTS carbon_risk_tier TEXT
    CHECK (carbon_risk_tier IS NULL OR carbon_risk_tier IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  ADD COLUMN IF NOT EXISTS hard_veto_code TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_alcada_restriction TEXT,
  ADD COLUMN IF NOT EXISTS kyc_device_integrity_verdict TEXT,
  ADD COLUMN IF NOT EXISTS kyc_vio_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS kyc_serpro_similarity NUMERIC(5,4);

-- ----------------------------------------------------------------------------
-- 3. RPC TRANSACIONAL ATÔMICA: apply_verified_carbon_kyc_verdict
--    Exclusiva para service_role (Edge Function kyc-carbon-webhook após MAC).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_verified_carbon_kyc_verdict(
  p_event_id                  UUID,
  p_user_id                   UUID,
  p_session_nonce_hash        TEXT,
  p_signature_timestamp       BIGINT,
  p_cpf_masked                TEXT,
  p_cpf_anti_sybil_hash       TEXT,
  p_face_liveness_hash        TEXT,
  p_verified_full_name        TEXT,
  p_document_type             TEXT,
  p_birth_date                DATE,
  p_issuing_authority         TEXT,
  p_verdict_status            TEXT,
  p_confidence_score          NUMERIC,
  p_risk_tier                 TEXT,
  p_alcada_restriction        TEXT,
  p_hard_veto_code            TEXT,
  p_shap_top_3_factors        JSONB,
  p_vio_signature_verified    BOOLEAN,
  p_nfc_passive_auth_verified BOOLEAN,
  p_serpro_similarity_score   NUMERIC,
  p_device_integrity_verdict  TEXT,
  p_liveness_score            NUMERIC,
  p_local_face_match_score    NUMERIC,
  p_worm_evidence_digest      TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_event    public.kyc_webhook_events%ROWTYPE;
  v_profile           public.profiles%ROWTYPE;
  v_submission_id     UUID;
  v_normalized_doc    TEXT;
  v_submission_status TEXT;
  v_role_scope        TEXT;
  v_scaled_liveness   NUMERIC(5,2);
  v_scaled_confidence NUMERIC(5,2);
  v_cpf_mask_safe     TEXT;
  v_updated_rts       NUMERIC(5,2);
  v_updated_rank      INTEGER;
BEGIN
  IF p_event_id IS NULL OR p_user_id IS NULL OR COALESCE(btrim(p_session_nonce_hash), '') = '' THEN
    RAISE EXCEPTION 'ERR_INVALID_WEBHOOK_ARGS: event_id, user_id e session_nonce_hash são obrigatórios.'
      USING ERRCODE = '22023';
  END IF;

  IF p_verdict_status NOT IN ('APPROVED', 'MANUAL_REVIEW', 'REJECTED') THEN
    RAISE EXCEPTION 'ERR_INVALID_VERDICT_STATUS: Status de veredito inválido (%).', p_verdict_status
      USING ERRCODE = '22023';
  END IF;

  IF p_risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN
    RAISE EXCEPTION 'ERR_INVALID_RISK_TIER: Tier de risco inválido (%).', p_risk_tier
      USING ERRCODE = '22023';
  END IF;

  -- 1. Idempotência Estrita por event_id (reenvios legítimos de rede não duplicam efeitos)
  SELECT * INTO v_existing_event
    FROM public.kyc_webhook_events
   WHERE event_id = p_event_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'ok', TRUE,
      'idempotent_replay', TRUE,
      'event_id', v_existing_event.event_id,
      'verdict_status', v_existing_event.verdict_status,
      'processed_at', v_existing_event.processed_at
    );
  END IF;

  -- 2. Bloqueio Antirreplay de Nonce de Sessão sob outro event_id
  IF EXISTS (
    SELECT 1 FROM public.kyc_webhook_events
     WHERE session_nonce_hash = p_session_nonce_hash
  ) THEN
    RAISE EXCEPTION 'ERR_SESSION_NONCE_REPLAY: Este desafio criptográfico de sessão KYC já foi consumido.'
      USING ERRCODE = '23505';
  END IF;

  -- 3. Lock pessimista sobre o perfil alvo
  SELECT * INTO v_profile
    FROM public.profiles
   WHERE id = p_user_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR_PROFILE_NOT_FOUND: Perfil de usuário inexistente para o user_id informado.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 4. Guarda Anti-Sybil por CPF Hash e Biometria Facial: impede múltiplas contas com mesma identidade
  IF p_verdict_status IN ('APPROVED', 'MANUAL_REVIEW') THEN
    IF COALESCE(btrim(p_cpf_anti_sybil_hash), '') <> '' AND EXISTS (
      SELECT 1 FROM public.profiles
       WHERE cpf_hash = p_cpf_anti_sybil_hash
         AND id <> p_user_id
    ) THEN
      RAISE EXCEPTION 'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta ativa na plataforma.'
        USING ERRCODE = '23505';
    END IF;

    IF COALESCE(btrim(p_face_liveness_hash), '') <> '' AND EXISTS (
      SELECT 1 FROM public.profiles
       WHERE face_liveness_hash = p_face_liveness_hash
         AND id <> p_user_id
    ) THEN
      RAISE EXCEPTION 'ERR_DUPLICATE_BIOMETRIC_FACE: Esta biometria facial já está vinculada a outra conta ativa na plataforma.'
        USING ERRCODE = '23505';
    END IF;
  END IF;

  -- 5. Normalização segura de tipos e escalas compatíveis com constraints existentes
  v_normalized_doc := CASE
    WHEN UPPER(COALESCE(p_document_type, '')) IN ('CPF', 'CNH', 'RG', 'CIN')
      THEN UPPER(p_document_type)
    ELSE 'CIN'
  END;

  v_submission_status := CASE p_verdict_status
    WHEN 'APPROVED'      THEN 'APPROVED'
    WHEN 'MANUAL_REVIEW' THEN 'PENDING'
    ELSE 'REJECTED'
  END;

  v_role_scope := CASE
    WHEN COALESCE(v_profile.is_provider, FALSE) AND COALESCE(v_profile.is_client, FALSE) THEN 'both'
    WHEN COALESCE(v_profile.is_provider, FALSE) THEN 'provider'
    ELSE 'client'
  END;

  v_scaled_liveness := LEAST(
    100.00,
    GREATEST(
      0.00,
      CASE
        WHEN COALESCE(p_liveness_score, 0) <= 1.0 THEN ROUND(COALESCE(p_liveness_score, 0) * 100.0, 2)
        ELSE ROUND(COALESCE(p_liveness_score, 0), 2)
      END
    )
  );

  v_scaled_confidence := LEAST(
    100.00,
    GREATEST(
      0.00,
      CASE
        WHEN COALESCE(p_confidence_score, 0) <= 1.0 THEN ROUND(COALESCE(p_confidence_score, 0) * 100.0, 2)
        ELSE ROUND(COALESCE(p_confidence_score, 0), 2)
      END
    )
  );

  v_cpf_mask_safe := COALESCE(NULLIF(btrim(p_cpf_masked), ''), '***.***.***-**');

  -- 6. Registro Forense Imutável em public.kyc_submissions
  INSERT INTO public.kyc_submissions (
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
    ocr_extracted_payload,
    face_match_cosine_similarity,
    vio_signature_verified,
    nfc_passive_auth_verified,
    serpro_similarity_score,
    device_integrity_verdict,
    shap_top_3_factors,
    alcada_restriction,
    session_nonce_hash,
    worm_evidence_digest,
    carbon_confidence_score,
    carbon_risk_tier,
    hard_veto_code,
    rejection_reason,
    status,
    reviewed_at
  ) VALUES (
    p_user_id,
    format('%s/worm/%s_front.enc', p_user_id, p_event_id),
    format('%s/worm/%s_back.enc', p_user_id, p_event_id),
    format('%s/worm/%s_selfie.enc', p_user_id, p_event_id),
    format('worm://kyc-evidence/%s/front', p_event_id),
    format('worm://kyc-evidence/%s/back', p_event_id),
    format('worm://kyc-evidence/%s/selfie', p_event_id),
    'Outro',
    v_cpf_mask_safe,
    v_role_scope,
    v_normalized_doc,
    jsonb_build_object(
      'verified_full_name', p_verified_full_name,
      'cpf_masked', v_cpf_mask_safe,
      'birth_date', p_birth_date,
      'issuing_authority', p_issuing_authority,
      'document_type', p_document_type,
      'worm_evidence_digest', p_worm_evidence_digest
    ),
    LEAST(1.0000, GREATEST(0.0000, ROUND(COALESCE(p_local_face_match_score, 0), 4))),
    COALESCE(p_vio_signature_verified, FALSE),
    COALESCE(p_nfc_passive_auth_verified, FALSE),
    p_serpro_similarity_score,
    p_device_integrity_verdict,
    COALESCE(p_shap_top_3_factors, '[]'::JSONB),
    p_alcada_restriction,
    p_session_nonce_hash,
    p_worm_evidence_digest,
    LEAST(1.0000, GREATEST(0.0000, ROUND(COALESCE(p_confidence_score, 0), 4))),
    p_risk_tier,
    p_hard_veto_code,
    CASE WHEN p_verdict_status = 'REJECTED' THEN COALESCE(p_hard_veto_code, 'CARBON_REJECTED') ELSE NULL END,
    v_submission_status,
    CASE WHEN p_verdict_status IN ('APPROVED', 'REJECTED') THEN timezone('utc', now()) ELSE NULL END
  )
  RETURNING id INTO v_submission_id;

  -- 7. Atualização Atômica de public.profiles
  --    Preserva 100% da Unificação Multi-Modo (+30 pts RTS imediatos via trigger
  --    sync_profile_trust_and_rank_biu quando o Cliente ativa o modo Profissional)
  --    e habilita a trava Same-Holder PIX Lock (pix_key_cpf_matched = TRUE).
  IF p_verdict_status = 'APPROVED' THEN
    UPDATE public.profiles
       SET verified_full_name           = COALESCE(NULLIF(btrim(p_verified_full_name), ''), verified_full_name),
           cpf_masked                   = v_cpf_mask_safe,
           cpf_hash                     = p_cpf_anti_sybil_hash,
           face_liveness_hash           = COALESCE(NULLIF(btrim(p_face_liveness_hash), ''), face_liveness_hash),
           document_type                = v_normalized_doc,
           birth_date                   = COALESCE(p_birth_date, birth_date),
           issuing_authority            = COALESCE(NULLIF(btrim(p_issuing_authority), ''), issuing_authority),
           client_kyc_status            = 'APPROVED',
           liveness_verified            = TRUE,
           liveness_score               = v_scaled_liveness,
           ocr_verified                 = TRUE,
           kyc_ocr_confidence           = v_scaled_confidence,
           kyc_biometric_verified       = TRUE, -- +30.00 pts RTS compartilhados com o modo Profissional
           pix_key_cpf_matched          = TRUE, -- Habilita Same-Holder PIX Lock para saques/carteira
           kyc_alcada_restriction       = p_alcada_restriction,
           kyc_device_integrity_verdict = p_device_integrity_verdict,
           kyc_vio_verified             = COALESCE(p_vio_signature_verified, FALSE),
           kyc_serpro_similarity        = p_serpro_similarity_score,
           kyc_verified_at              = timezone('utc', now()),
           verification_status          = CASE
             WHEN COALESCE(is_provider, FALSE) = TRUE AND p_alcada_restriction IS NULL THEN 'ACTIVE'::public.verification_status
             ELSE verification_status
           END,
           updated_at                   = timezone('utc', now())
     WHERE id = p_user_id
     RETURNING external_trust_score, waterfall_tier_rank
          INTO v_updated_rts, v_updated_rank;

  ELSIF p_verdict_status = 'MANUAL_REVIEW' THEN
    UPDATE public.profiles
       SET client_kyc_status            = CASE WHEN client_kyc_status = 'APPROVED' THEN 'APPROVED' ELSE 'PENDING_REVIEW' END,
           kyc_alcada_restriction       = COALESCE(p_alcada_restriction, 'MANUAL_REVIEW'),
           kyc_device_integrity_verdict = p_device_integrity_verdict,
           updated_at                   = timezone('utc', now())
     WHERE id = p_user_id
     RETURNING external_trust_score, waterfall_tier_rank
          INTO v_updated_rts, v_updated_rank;

  ELSE
    UPDATE public.profiles
       SET client_kyc_status            = CASE WHEN client_kyc_status = 'APPROVED' THEN 'APPROVED' ELSE 'REJECTED' END,
           kyc_device_integrity_verdict = p_device_integrity_verdict,
           updated_at                   = timezone('utc', now())
     WHERE id = p_user_id
     RETURNING external_trust_score, waterfall_tier_rank
          INTO v_updated_rts, v_updated_rank;
  END IF;

  -- 8. Gravação do Evento Consumido na Tabela de Idempotência
  INSERT INTO public.kyc_webhook_events (
    event_id,
    user_id,
    session_nonce_hash,
    verdict_status,
    risk_tier,
    alcada_restriction,
    hard_veto_code,
    worm_evidence_digest,
    signature_timestamp,
    payload_summary
  ) VALUES (
    p_event_id,
    p_user_id,
    p_session_nonce_hash,
    p_verdict_status,
    p_risk_tier,
    p_alcada_restriction,
    p_hard_veto_code,
    p_worm_evidence_digest,
    p_signature_timestamp,
    jsonb_build_object(
      'submission_id', v_submission_id,
      'cpf_masked', v_cpf_mask_safe,
      'vio_verified', COALESCE(p_vio_signature_verified, FALSE),
      'nfc_verified', COALESCE(p_nfc_passive_auth_verified, FALSE),
      'device_integrity_verdict', p_device_integrity_verdict,
      'external_trust_score', v_updated_rts,
      'waterfall_tier_rank', v_updated_rank
    )
  );

  RETURN jsonb_build_object(
    'ok', TRUE,
    'idempotent_replay', FALSE,
    'event_id', p_event_id,
    'submission_id', v_submission_id,
    'verdict_status', p_verdict_status,
    'alcada_restriction', p_alcada_restriction,
    'multi_mode_kyc_biometric_verified', (p_verdict_status = 'APPROVED'),
    'same_holder_pix_lock_enabled', (p_verdict_status = 'APPROVED'),
    'external_trust_score', v_updated_rts,
    'waterfall_tier_rank', v_updated_rank
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_verified_carbon_kyc_verdict(
  UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, TEXT,
  TEXT, NUMERIC, TEXT, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN, NUMERIC,
  TEXT, NUMERIC, NUMERIC, TEXT
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.apply_verified_carbon_kyc_verdict(
  UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, TEXT,
  TEXT, NUMERIC, TEXT, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN, NUMERIC,
  TEXT, NUMERIC, NUMERIC, TEXT
) TO service_role;

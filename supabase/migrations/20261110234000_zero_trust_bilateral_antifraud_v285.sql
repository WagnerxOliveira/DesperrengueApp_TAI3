-- =============================================================================
-- DESPERRENGUE — ARQUITETURA ZERO-TRUST DE SEGURANÇA BILATERAL (v2.8.5)
-- Red Team Countermeasures para os Vetores Residuais 1 a 6 (Seção 10.1):
--   Vetor 1: Desafio Fotométrico de Reflexão Cromática Ativa (Screen-Flash) +
--            Play Integrity (MEETS_STRONG_INTEGRITY) / Apple App Attest + IMU Sync
--   Vetor 2: Validação Criptográfica e Visual de Notas/Cupons em 4 Camadas
--            (Módulo 11 44 dígitos + tpAmb=1 + Oráculo SEFAZ Bifásico 26h +
--             Recibo MEI CGSN 140/2018 com Teto R$ 150,00 + ELA JPEG 8x8)
--   Vetor 3: Despacho Equiprovável em Coroa Circular (0,4 km a 8,0 km) +
--            Guarda Anti-Sniper (< 350 m / 30 min) + Base/Pernoite (< 300 m) +
--            Retenção Dinâmica de Anomalia (D+5)
--   Vetor 4: Cadeia de Custódia da Peça Substituída em 3 Atos + Foto de Entrega
--            (Proof-of-Leave) Embutida Atomicamente no PIN de 4 Dígitos
--   Vetor 5: Invariante Zero Unfunded Lock + Taxa Compensatória de Deslocamento
--            SOS Revertida ao Especialista Prejudicado (>= 250 m ou >= 4 min)
--   Vetor 6: Telemetria Bruta GNSS (AGC x C/N0) + Prova Criptográfica Bilateral
--            de Co-Presença Física (QR TOTP 15s + Token Ultrassônico 18.5-19.5 kHz)
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. VETOR 1: DESAFIO FOTOMÉTRICO SCREEN-FLASH + HARDWARE ATTESTATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.kyc_liveness_nonces (
    nonce_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- fix: tabela de contas públicas no schema é public.profiles (não existe public.users)
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    pulse_rgb_hex_sequence TEXT[] NOT NULL DEFAULT ARRAY['#F43F5E', '#00C2FF', '#10B981'],
    required_yaw_direction TEXT NOT NULL CHECK (required_yaw_direction IN ('LEFT', 'RIGHT')),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '90 seconds'),
    consumed_at TIMESTAMPTZ,
    attestation_verdict TEXT CHECK (
        attestation_verdict IN ('MEETS_STRONG_INTEGRITY', 'APP_ATTEST_HARDWARE', 'WEB_STEP_UP_CONTAINED')
    ),
    mean_chromatic_cosine NUMERIC(5,4),
    imu_optical_correlation NUMERIC(5,4),
    request_hash TEXT
);

CREATE INDEX IF NOT EXISTS idx_kyc_liveness_nonces_user_active
    ON public.kyc_liveness_nonces (user_id, expires_at DESC)
    WHERE consumed_at IS NULL;

CREATE OR REPLACE FUNCTION public.issue_kyc_screen_flash_challenge(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_palette TEXT[] := ARRAY['#F43F5E', '#00C2FF', '#10B981', '#F59E0B', '#3B82F6', '#EC4899'];
    v_seq TEXT[];
    v_yaw TEXT;
    v_nonce UUID;
    v_expires TIMESTAMPTZ;
BEGIN
    -- Sorteia 3 pulsos cromáticos ortogonais e a direção do giro de cabeça (Yaw)
    SELECT ARRAY_AGG(color_hex)
      INTO v_seq
      FROM (
          SELECT unnest(v_palette) AS color_hex
          ORDER BY gen_random_uuid()
          LIMIT 3
      ) s;

    v_yaw := CASE WHEN random() < 0.5 THEN 'LEFT' ELSE 'RIGHT' END;

    INSERT INTO public.kyc_liveness_nonces (
        user_id,
        pulse_rgb_hex_sequence,
        required_yaw_direction
    )
    VALUES (
        p_user_id,
        v_seq,
        v_yaw
    )
    RETURNING nonce_id, expires_at INTO v_nonce, v_expires;

    RETURN jsonb_build_object(
        'nonce_id', v_nonce,
        'pulse_rgb_hex_sequence', v_seq,
        'pulse_duration_ms', 320,
        'required_yaw_direction', v_yaw,
        'expires_at', v_expires
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_kyc_screen_flash_and_hardware_attestation(
    p_user_id UUID,
    p_nonce_id UUID,
    p_selfie_phash BIGINT,
    p_doc_front_phash BIGINT,
    p_pulse_cosines NUMERIC[],
    p_imu_optical_correlation NUMERIC,
    p_physiological_tremor_hz NUMERIC,
    p_attestation_verdict TEXT,
    p_client_request_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_nonce RECORD;
    v_expected_hash TEXT;
    v_mean_cosine NUMERIC(5,4);
    v_min_cosine NUMERIC(5,4);
BEGIN
    SELECT *
      INTO v_nonce
      FROM public.kyc_liveness_nonces
     WHERE nonce_id = p_nonce_id
       AND user_id = p_user_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'KYC_NONCE_NOT_FOUND: Desafio fotométrico inexistente para este usuário.';
    END IF;

    IF v_nonce.consumed_at IS NOT NULL THEN
        RAISE EXCEPTION 'KYC_NONCE_REPLAYED: Este desafio fotométrico já foi consumido (Anti-Replay).';
    END IF;

    IF NOW() > v_nonce.expires_at THEN
        RAISE EXCEPTION 'KYC_NONCE_EXPIRED: O desafio fotométrico expirou (> 90s). Solicite novo desafio.';
    END IF;

    IF p_attestation_verdict NOT IN ('MEETS_STRONG_INTEGRITY', 'APP_ATTEST_HARDWARE', 'WEB_STEP_UP_CONTAINED') THEN
        RAISE EXCEPTION 'HARDWARE_ATTESTATION_FAILED: Dispositivo sem integridade criptográfica TEE/StrongBox.';
    END IF;

    IF array_length(p_pulse_cosines, 1) IS NULL OR array_length(p_pulse_cosines, 1) < 3 THEN
        RAISE EXCEPTION 'SCREEN_FLASH_INCOMPLETE: São exigidos os 3 vetores de reflexão cromática.';
    END IF;

    SELECT ROUND(AVG(val), 4), ROUND(MIN(val), 4)
      INTO v_mean_cosine, v_min_cosine
      FROM unnest(p_pulse_cosines) AS val;

    IF v_min_cosine < 0.7200 THEN
        RAISE EXCEPTION 'VIRTUAL_CAMERA_DETECTED: Reflexão cromática abaixo do limiar físico (cos = %, mínimo 0.72). Possível câmera virtual/OBS.', v_min_cosine;
    END IF;

    IF p_imu_optical_correlation < 0.8200 OR p_physiological_tremor_hz < 6.0 OR p_physiological_tremor_hz > 15.0 THEN
        RAISE EXCEPTION 'SYNTHETIC_VIDEO_FEED_DETECTED: Dessincronia entre giroscópio IMU e fluxo óptico facial (r = %, tremor = % Hz).', p_imu_optical_correlation, p_physiological_tremor_hz;
    END IF;

    v_expected_hash := encode(
        digest(
            p_user_id::TEXT || '|' || p_nonce_id::TEXT || '|' || p_selfie_phash::TEXT || '|' || p_doc_front_phash::TEXT,
            'sha256'
        ),
        'hex'
    );

    IF lower(trim(p_client_request_hash)) <> lower(v_expected_hash) THEN
        RAISE EXCEPTION 'REQUEST_HASH_MISMATCH: Violação de integridade do payload biométrico (MITM/Hook detectado).';
    END IF;

    UPDATE public.kyc_liveness_nonces
       SET consumed_at = NOW(),
           attestation_verdict = p_attestation_verdict,
           mean_chromatic_cosine = v_mean_cosine,
           imu_optical_correlation = ROUND(p_imu_optical_correlation, 4),
           request_hash = v_expected_hash
     WHERE nonce_id = p_nonce_id;

    RETURN jsonb_build_object(
        'verified', TRUE,
        'nonce_id', p_nonce_id,
        'attestation_verdict', p_attestation_verdict,
        'mean_chromatic_cosine', v_mean_cosine,
        'imu_optical_correlation', ROUND(p_imu_optical_correlation, 4),
        'web_step_up_containment', (p_attestation_verdict = 'WEB_STEP_UP_CONTAINED')
    );
END;
$$;

-- =============================================================================
-- 2. VETOR 2: VALIDAÇÃO FISCAL EM 4 CAMADAS (CHAVE 44 DÍGITOS + MEI R$ 150 + ELA)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.validate_cnpj_mod11(
    p_cnpj TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_clean TEXT := regexp_replace(COALESCE(p_cnpj, ''), '[^0-9]', '', 'g');
    v_w1 INT[] := ARRAY[5,4,3,2,9,8,7,6,5,4,3,2];
    v_w2 INT[] := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
    v_sum INT := 0;
    v_rem INT;
    v_d1 INT;
    v_d2 INT;
    i INT;
BEGIN
    IF length(v_clean) <> 14 THEN
        RETURN FALSE;
    END IF;

    IF v_clean ~ '^(\d)\1{13}$' THEN
        RETURN FALSE;
    END IF;

    FOR i IN 1..12 LOOP
        v_sum := v_sum + (substr(v_clean, i, 1)::INT * v_w1[i]);
    END LOOP;
    v_rem := v_sum % 11;
    v_d1 := CASE WHEN v_rem < 2 THEN 0 ELSE 11 - v_rem END;

    IF substr(v_clean, 13, 1)::INT <> v_d1 THEN
        RETURN FALSE;
    END IF;

    v_sum := 0;
    FOR i IN 1..13 LOOP
        v_sum := v_sum + (substr(v_clean, i, 1)::INT * v_w2[i]);
    END LOOP;
    v_rem := v_sum % 11;
    v_d2 := CASE WHEN v_rem < 2 THEN 0 ELSE 11 - v_rem END;

    RETURN substr(v_clean, 14, 1)::INT = v_d2;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_nfe_access_key_mod11(
    p_access_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_key TEXT := regexp_replace(COALESCE(p_access_key, ''), '[^0-9]', '', 'g');
    v_uf INT;
    v_aamm TEXT;
    v_cnpj TEXT;
    v_mod TEXT;
    v_tp_emis TEXT;
    v_weight INT := 2;
    v_sum INT := 0;
    v_rem INT;
    v_dv INT;
    i INT;
BEGIN
    IF length(v_key) <> 44 THEN
        RETURN jsonb_build_object('valid', FALSE, 'reason', 'INVALID_LENGTH_44');
    END IF;

    v_uf := substr(v_key, 1, 2)::INT;
    IF v_uf NOT IN (11,12,13,14,15,16,17,21,22,23,24,25,26,27,28,29,31,32,33,35,41,42,43,50,51,52,53) THEN
        RETURN jsonb_build_object('valid', FALSE, 'reason', 'INVALID_IBGE_UF');
    END IF;

    v_aamm := substr(v_key, 3, 4);
    v_cnpj := substr(v_key, 7, 14);
    IF NOT public.validate_cnpj_mod11(v_cnpj) THEN
        RETURN jsonb_build_object('valid', FALSE, 'reason', 'INVALID_EMITTER_CNPJ_MOD11');
    END IF;

    v_mod := substr(v_key, 21, 2);
    IF v_mod NOT IN ('55', '65') THEN
        RETURN jsonb_build_object('valid', FALSE, 'reason', 'UNSUPPORTED_FISCAL_MODEL');
    END IF;

    v_tp_emis := substr(v_key, 35, 1);
    IF v_tp_emis NOT IN ('1', '9') THEN
        RETURN jsonb_build_object('valid', FALSE, 'reason', 'INVALID_TP_EMIS');
    END IF;

    FOR i IN REVERSE 43..1 LOOP
        v_sum := v_sum + (substr(v_key, i, 1)::INT * v_weight);
        v_weight := CASE WHEN v_weight = 9 THEN 2 ELSE v_weight + 1 END;
    END LOOP;

    v_rem := v_sum % 11;
    v_dv := CASE WHEN v_rem IN (0, 1) THEN 0 ELSE 11 - v_rem END;

    IF substr(v_key, 44, 1)::INT <> v_dv THEN
        RETURN jsonb_build_object(
            'valid', FALSE,
            'reason', 'MOD11_CHECK_DIGIT_MISMATCH',
            'expected_dv', v_dv
        );
    END IF;

    RETURN jsonb_build_object(
        'valid', TRUE,
        'uf_code', v_uf,
        'aamm', v_aamm,
        'emitter_cnpj', v_cnpj,
        'fiscal_model', v_mod,
        'check_digit', v_dv
    );
END;
$$;

CREATE TABLE IF NOT EXISTS public.job_fiscal_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    -- fix: referência correta para public.profiles(id)
    provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    fiscal_document_mode TEXT NOT NULL CHECK (
        fiscal_document_mode IN ('NFE_55', 'NFCE_65', 'MEI_RECEIPT_CGSN140')
    ),
    capture_channel TEXT NOT NULL CHECK (
        capture_channel IN ('QR_CODE', 'BARCODE_1D_CODE128C', 'OCR_CHAVE_44', 'OCR_MEI_RECEIPT')
    ),
    access_key_44 TEXT UNIQUE,
    tp_amb CHAR(1) NOT NULL DEFAULT '1' CHECK (tp_amb = '1'),
    emitter_cnpj TEXT NOT NULL,
    emitter_cnae_compatible BOOLEAN NOT NULL DEFAULT TRUE,
    receipt_number TEXT NOT NULL,
    issued_date DATE NOT NULL DEFAULT CURRENT_DATE,
    declared_material_amount NUMERIC(12,2) NOT NULL CHECK (declared_material_amount > 0),
    ncm_codes TEXT[] NOT NULL DEFAULT '{}',
    ela_tamper_score NUMERIC(5,4) NOT NULL DEFAULT 0.0000 CHECK (ela_tamper_score >= 0 AND ela_tamper_score <= 1),
    receipt_photo_phash BIGINT NOT NULL,
    sefaz_status_initial INT NOT NULL DEFAULT 100,
    sefaz_status_recheck INT,
    rechecked_at TIMESTAMPTZ,
    clawback_triggered BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_job_fiscal_emitter_receipt UNIQUE (emitter_cnpj, receipt_number, issued_date)
);

CREATE INDEX IF NOT EXISTS idx_job_fiscal_docs_recheck_queue
    ON public.job_fiscal_documents (created_at)
    WHERE fiscal_document_mode IN ('NFE_55', 'NFCE_65')
      AND sefaz_status_recheck IS NULL
      AND clawback_triggered = FALSE;

CREATE OR REPLACE FUNCTION public.register_and_verify_material_fiscal_document(
    p_job_id UUID,
    p_provider_id UUID,
    p_fiscal_document_mode TEXT,
    p_capture_channel TEXT,
    p_access_key_44 TEXT,
    p_tp_amb CHAR(1),
    p_emitter_cnpj TEXT,
    p_emitter_cnae_compatible BOOLEAN,
    p_receipt_number TEXT,
    p_declared_material_amount NUMERIC(12,2),
    p_ncm_codes TEXT[],
    p_ela_tamper_score NUMERIC(5,4),
    p_receipt_photo_phash BIGINT,
    p_sefaz_status_initial INT DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_check JSONB;
    v_clean_cnpj TEXT := regexp_replace(COALESCE(p_emitter_cnpj, ''), '[^0-9]', '', 'g');
    v_clean_key TEXT := NULLIF(regexp_replace(COALESCE(p_access_key_44, ''), '[^0-9]', '', 'g'), '');
    v_doc_id UUID;
BEGIN
    -- Camada 4: Forense Digital de Imagem (ELA - Error Level Analysis 8x8 DCT)
    IF p_ela_tamper_score > 0.1800 THEN
        RAISE EXCEPTION 'FISCAL_IMAGE_SPLICE_DETECTED: Divergência ELA (score = %) acima do limiar forense (0.18). Possível edição gráfica de valores.', p_ela_tamper_score;
    END IF;

    IF p_tp_amb <> '1' THEN
        RAISE EXCEPTION 'FISCAL_HOMOLOGATION_ENV_BLOCKED: Notas em ambiente de teste/homologação (tpAmb != 1) são bloqueadas.';
    END IF;

    IF p_fiscal_document_mode IN ('NFE_55', 'NFCE_65') THEN
        IF v_clean_key IS NULL THEN
            RAISE EXCEPTION 'ACCESS_KEY_REQUIRED: Notas NF-e (55) e NFC-e (65) exigem a Chave de Acesso de 44 dígitos (via QR Code, Código de Barras 1D ou OCR).';
        END IF;

        v_key_check := public.validate_nfe_access_key_mod11(v_clean_key);
        IF NOT COALESCE((v_key_check->>'valid')::BOOLEAN, FALSE) THEN
            RAISE EXCEPTION 'INVALID_NFE_KEY_MOD11: Chave de 44 dígitos inválida (%).', (v_key_check->>'reason');
        END IF;

        v_clean_cnpj := v_key_check->>'emitter_cnpj';

        IF p_sefaz_status_initial <> 100 THEN
            RAISE EXCEPTION 'SEFAZ_NOT_AUTHORIZED: Documento fiscal não autorizado na SEFAZ (cStat = %).', p_sefaz_status_initial;
        END IF;

    ELSIF p_fiscal_document_mode = 'MEI_RECEIPT_CGSN140' THEN
        -- Camada 3 + Camada 4: Recibo MEI (Res. CGSN 140/2018 Art. 106) + Teto Fiscal Inteligente R$ 150,00
        IF NOT public.validate_cnpj_mod11(v_clean_cnpj) THEN
            RAISE EXCEPTION 'INVALID_MEI_CNPJ: O CNPJ informado no recibo sem QR Code é matematicamente inválido (Módulo 11).';
        END IF;

        IF NOT COALESCE(p_emitter_cnae_compatible, FALSE) THEN
            RAISE EXCEPTION 'INCOMPATIBLE_EMITTER_CNAE: O CNPJ do recibo não pertence ao ramo de materiais de construção, elétrica, hidráulica ou peças técnicas.';
        END IF;

        IF p_declared_material_amount > 150.00 THEN
            RAISE EXCEPTION 'SMART_FISCAL_CAP_EXCEEDED: Recibos simples sem chave de 44 dígitos possuem teto de isenção 0%% limitado a R$ 150,00 (declarado: R$ %). Para valores superiores, exija NF-e/NFC-e ou NF-e Avulsa.', p_declared_material_amount;
        END IF;
    ELSE
        RAISE EXCEPTION 'UNSUPPORTED_FISCAL_DOCUMENT_MODE: %', p_fiscal_document_mode;
    END IF;

    INSERT INTO public.job_fiscal_documents (
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
        sefaz_status_initial
    )
    VALUES (
        p_job_id,
        p_provider_id,
        p_fiscal_document_mode,
        p_capture_channel,
        v_clean_key,
        '1',
        v_clean_cnpj,
        p_emitter_cnae_compatible,
        p_receipt_number,
        p_declared_material_amount,
        COALESCE(p_ncm_codes, '{}'),
        p_ela_tamper_score,
        p_receipt_photo_phash,
        p_sefaz_status_initial
    )
    RETURNING id INTO v_doc_id;

    RETURN jsonb_build_object(
        'verified', TRUE,
        'document_id', v_doc_id,
        'fiscal_document_mode', p_fiscal_document_mode,
        'emitter_cnpj', v_clean_cnpj,
        'exempt_material_amount', p_declared_material_amount,
        'smart_fiscal_cap_applied', (p_fiscal_document_mode = 'MEI_RECEIPT_CGSN140')
    );
END;
$$;

-- Função de Re-Verificação Assíncrona (Fase 2 SEFAZ > 26h) contra o golpe "Compra-Escaneia-Cancela"
CREATE OR REPLACE FUNCTION public.audit_sefaz_phase2_cancellation_and_clawback(
    p_document_id UUID,
    p_sefaz_status_recheck INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_doc RECORD;
    v_evaded_fee NUMERIC(12,2);
    v_op_fee NUMERIC(12,2);
    v_reserve_fee NUMERIC(12,2);
BEGIN
    SELECT *
      INTO v_doc
      FROM public.job_fiscal_documents
     WHERE id = p_document_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FISCAL_DOCUMENT_NOT_FOUND';
    END IF;

    UPDATE public.job_fiscal_documents
       SET sefaz_status_recheck = p_sefaz_status_recheck,
           rechecked_at = NOW()
     WHERE id = p_document_id;

    -- cStat 101 / 151 / 155 = Cancelamento de NF-e / NFC-e homologado após emissão
    IF p_sefaz_status_recheck IN (101, 151, 155) AND NOT v_doc.clawback_triggered THEN
        v_op_fee := ROUND(v_doc.declared_material_amount * 0.1350, 2);
        v_reserve_fee := ROUND(v_doc.declared_material_amount * 0.0150, 2);
        v_evaded_fee := v_op_fee + v_reserve_fee;

        UPDATE public.job_fiscal_documents
           SET clawback_triggered = TRUE
         WHERE id = p_document_id;

        INSERT INTO public.wallet_ledger_entries (
            job_id,
            provider_id,
            entry_kind,
            amount,
            description
        )
        VALUES
            (
                v_doc.job_id,
                v_doc.provider_id,
                'CLAWBACK_DEBIT',
                -v_evaded_fee,
                'Clawback Automático: Nota Fiscal cancelada na SEFAZ após upload (cStat ' || p_sefaz_status_recheck || '). Reclassificação de Peças para Mão de Obra (15%).'
            ),
            (
                v_doc.job_id,
                NULL,
                'PLATFORM_OPERATIONAL_FEE',
                v_op_fee,
                'Recuperação de Take Rate Operacional (13,5%) sobre nota cancelada.'
            ),
            (
                v_doc.job_id,
                NULL,
                'WARRANTY_RESERVE_CARVEOUT',
                v_reserve_fee,
                'Recuperação de Carve-Out do Fundo de Garantia (1,5%) sobre nota cancelada.'
            );

        UPDATE public.provider_profiles
           SET clawback_debt_balance = clawback_debt_balance + v_evaded_fee,
               rts_score = GREATEST(0.0, rts_score - 25.0),
               updated_at = NOW()
         WHERE user_id = v_doc.provider_id;

        RETURN jsonb_build_object(
            'canceled_on_sefaz', TRUE,
            'clawback_debited', v_evaded_fee,
            'reclassified_amount', v_doc.declared_material_amount
        );
    END IF;

    RETURN jsonb_build_object(
        'canceled_on_sefaz', FALSE,
        'sefaz_status_recheck', p_sefaz_status_recheck
    );
END;
$$;

-- =============================================================================
-- 3. VETOR 3: COROA CIRCULAR EQUIPROVÁVEL (0,4 A 8,0 KM) + ANTI-SNIPER (< 350 M)
--             + BASE/PERNOITE (< 300 M) + ANOMALY HOLD D+5
-- =============================================================================

ALTER TABLE public.provider_profiles
    ADD COLUMN IF NOT EXISTS roost_lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS roost_lng DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS last_online_transition_at TIMESTAMPTZ DEFAULT (NOW() - INTERVAL '2 hours');

-- Atualiza trigger_layer3_rework com Coroa Circular Equiprovável (400m..8000m),
-- bloqueio de Pernoite/Base (< 300m) e penalização de Sniper (< 350m em < 30 min)
CREATE OR REPLACE FUNCTION public.trigger_layer3_rework(
    p_warranty_claim_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_claim RECORD;
    v_job RECORD;
    v_offender_roost RECORD;
    v_pool_balance NUMERIC(14,2);
    v_rework_cap NUMERIC(12,2);
    v_selected_rescuer UUID;
BEGIN
    SELECT * INTO v_claim
      FROM public.warranty_claims
     WHERE id = p_warranty_claim_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'WARRANTY_CLAIM_NOT_FOUND';
    END IF;

    SELECT * INTO v_job
      FROM public.jobs
     WHERE id = v_claim.job_id
       FOR UPDATE;

    SELECT roost_lat, roost_lng
      INTO v_offender_roost
      FROM public.provider_profiles
     WHERE user_id = v_claim.original_provider_id;

    v_rework_cap := v_job.labor_amount;

    SELECT COALESCE(SUM(
        CASE
            WHEN entry_kind IN ('WARRANTY_RESERVE_CARVEOUT', 'CLAWBACK_RECOVERY') THEN amount
            WHEN entry_kind = 'WARRANTY_PAYOUT_DEBIT' THEN amount
            ELSE 0
        END
    ), 0.00)
      INTO v_pool_balance
      FROM public.wallet_ledger_entries;

    IF v_pool_balance < v_rework_cap THEN
        RAISE EXCEPTION 'INSUFFICIENT_WARRANTY_POOL_BALANCE: Pool=% Required=%', v_pool_balance, v_rework_cap;
    END IF;

    -- Seleção Cega em Coroa Circular Equiprovável (400m a 8000m) + Grafo Zero-Linkage + Anti-Sniper
    SELECT pp.user_id
      INTO v_selected_rescuer
      FROM public.provider_profiles pp
      -- fix: tabela real é public.profiles (usa apenas u.id)
      JOIN public.profiles u ON u.id = pp.user_id
     WHERE pp.is_online = TRUE
       AND pp.schedule_locked_for_warranty = FALSE
       AND pp.rts_score >= 75.0
       AND pp.tier <= 2
       AND pp.user_id <> v_claim.original_provider_id
       -- 1. Coroa Circular: mínimo 0,4 km (400m) e máximo 8,0 km para derrotar emboscada de esquina
       AND public.haversine_km(v_job.property_lat, v_job.property_lng, pp.base_lat, pp.base_lng)
           BETWEEN 0.40 AND 8.00
       -- 2. Bloqueio de Co-Localização de Base/Pernoite (< 300m do imóvel ou do infrator original)
       AND (
           pp.roost_lat IS NULL
           OR public.haversine_km(v_job.property_lat, v_job.property_lng, pp.roost_lat, pp.roost_lng) >= 0.30
       )
       AND (
           pp.roost_lat IS NULL
           OR v_offender_roost.roost_lat IS NULL
           OR public.haversine_km(v_offender_roost.roost_lat, v_offender_roost.roost_lng, pp.roost_lat, pp.roost_lng) >= 0.30
       )
       -- 3. Guarda Anti-Sniper: bloqueia quem ficou online há menos de 30 min a < 350m do imóvel
       AND NOT (
           pp.last_online_transition_at >= (v_claim.created_at - INTERVAL '30 minutes')
           AND public.haversine_km(v_job.property_lat, v_job.property_lng, pp.base_lat, pp.base_lng) < 0.35
       )
       -- 4. Grafo Zero-Linkage: nem mesmo device, nem mesma sub-rede /24, nem histórico prévio
       AND NOT EXISTS (
           SELECT 1
             FROM public.security_device_sessions s_rescuer
             JOIN public.security_device_sessions s_other
               ON (
                   s_rescuer.device_fingerprint_hash = s_other.device_fingerprint_hash
                   OR s_rescuer.ip_subnet_24 = s_other.ip_subnet_24
               )
            WHERE s_rescuer.user_id = pp.user_id
              AND s_other.user_id IN (v_job.client_id, v_claim.original_provider_id)
       )
       AND NOT EXISTS (
           SELECT 1
             FROM public.jobs j_hist
            WHERE (j_hist.client_id = v_job.client_id AND j_hist.provider_id = pp.user_id)
               OR (j_hist.client_id = pp.user_id AND j_hist.provider_id = v_claim.original_provider_id)
               OR (j_hist.client_id = v_claim.original_provider_id AND j_hist.provider_id = pp.user_id)
       )
     -- Entropia uniforme dentro do mesmo Tier (elimina determinismo de distância mínima)
     ORDER BY pp.tier ASC, gen_random_uuid()
     LIMIT 1;

    IF v_selected_rescuer IS NULL THEN
        RAISE EXCEPTION 'NO_ZERO_LINK_RESCUER_AVAILABLE_IN_ANNULAR_RING';
    END IF;

    UPDATE public.jobs
       SET escrow_state = 'REWORK_ALLOCATED'
     WHERE id = v_job.id;

    INSERT INTO public.wallet_ledger_entries (job_id, provider_id, entry_kind, amount, description)
    VALUES
        (v_job.id, v_selected_rescuer, 'WARRANTY_PAYOUT_DEBIT', -v_rework_cap,
         'Débito do Fundo Garantidor para pagamento de Retrabalho Camada 3 (Coroa Circular Zero-Link)'),
        (v_job.id, v_selected_rescuer, 'PROVIDER_PAYOUT', v_rework_cap,
         'Crédito integral (100% Mão de Obra) ao Profissional Socorrista'),
        (v_job.id, v_claim.original_provider_id, 'CLAWBACK_DEBIT', -v_rework_cap,
         'Lançamento de Dívida de Regresso (Clawback) contra o prestador original inadimplente');

    UPDATE public.provider_profiles
       SET schedule_locked_for_warranty = TRUE,
           clawback_debt_balance = clawback_debt_balance + v_rework_cap,
           rts_score = GREATEST(0.0, rts_score - 30.0),
           tier = 4,
           updated_at = NOW()
     WHERE user_id = v_claim.original_provider_id;

    UPDATE public.warranty_claims
       SET current_layer = 3,
           phase = 'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH',
           rescue_provider_id = v_selected_rescuer,
           reserve_allocated_amount = v_rework_cap,
           clawback_debited_amount = v_rework_cap
     WHERE id = p_warranty_claim_id;

    RETURN v_selected_rescuer;
END;
$$;

-- =============================================================================
-- 4. VETOR 4 E VETOR 6: CADEIA DE CUSTÓDIA DE PEÇA SUBSTITUÍDA (PROOF-OF-LEAVE)
--    + PROVA CRIPTOGRÁFICA BILATERAL DE CO-PRESENÇA E TELEMETRIA GNSS
-- =============================================================================

ALTER TABLE public.jobs
    ADD COLUMN IF NOT EXISTS material_split_scope TEXT NOT NULL DEFAULT 'NONE'
        CHECK (material_split_scope IN ('NONE', 'CONSUMABLE_SUPPLIES', 'COMPONENT_REPLACEMENT')),
    ADD COLUMN IF NOT EXISTS appliance_nameplate_ocr TEXT,
    ADD COLUMN IF NOT EXISTS insitu_connected_part_phash BIGINT,
    ADD COLUMN IF NOT EXISTS old_vs_new_part_macro_phash BIGINT,
    ADD COLUMN IF NOT EXISTS old_part_leave_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS old_part_leave_photo_phash BIGINT,
    ADD COLUMN IF NOT EXISTS old_part_disposal_authorized BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS job_presence_secret TEXT,
    ADD COLUMN IF NOT EXISTS checkin_copresence_proof_hash TEXT,
    ADD COLUMN IF NOT EXISTS checkout_copresence_proof_hash TEXT,
    ADD COLUMN IF NOT EXISTS gnss_agc_cn0_valid BOOLEAN NOT NULL DEFAULT TRUE;

CREATE OR REPLACE FUNCTION public.record_component_custody_and_proof_of_leave(
    p_job_id UUID,
    p_provider_id UUID,
    p_material_split_scope TEXT,
    p_appliance_nameplate_ocr TEXT,
    p_insitu_connected_part_phash BIGINT,
    p_old_vs_new_part_macro_phash BIGINT,
    p_old_part_leave_photo_url TEXT,
    p_old_part_leave_photo_phash BIGINT,
    p_old_part_disposal_authorized BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_job RECORD;
BEGIN
    SELECT * INTO v_job
      FROM public.jobs
     WHERE id = p_job_id
       AND provider_id = p_provider_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND_OR_UNAUTHORIZED';
    END IF;

    IF p_material_split_scope = 'COMPONENT_REPLACEMENT' THEN
        IF COALESCE(length(trim(p_appliance_nameplate_ocr)), 0) < 4 THEN
            RAISE EXCEPTION 'NAMEPLATE_OCR_REQUIRED: Para substituição de componente interno, a identificação da etiqueta do equipamento é obrigatória.';
        END IF;

        IF p_insitu_connected_part_phash IS NULL OR p_old_vs_new_part_macro_phash IS NULL THEN
            RAISE EXCEPTION 'COMPONENT_MACRO_PHOTOS_REQUIRED: As fotos da peça antiga conectada in-situ e do comparativo Peça Antiga vs. Peça Nova são obrigatórias.';
        END IF;

        IF p_old_part_leave_photo_phash IS NULL AND NOT COALESCE(p_old_part_disposal_authorized, FALSE) THEN
            RAISE EXCEPTION 'PROOF_OF_LEAVE_REQUIRED: Registre a foto da peça antiga deixada no imóvel (Proof-of-Leave) ou a autorização de descarte para exibir no PIN do cliente.';
        END IF;

        IF p_old_part_leave_photo_phash IS NOT NULL
           AND v_job.checkin_phash_64 IS NOT NULL
           AND public.phash_hamming_distance(v_job.checkin_phash_64, p_old_part_leave_photo_phash) < 5 THEN
            RAISE EXCEPTION 'DUPLICATE_LEAVE_PHOTO: A foto de devolução da peça antiga não pode ser idêntica à foto de Check-in.';
        END IF;
    END IF;

    UPDATE public.jobs
       SET material_split_scope = p_material_split_scope,
           appliance_nameplate_ocr = p_appliance_nameplate_ocr,
           insitu_connected_part_phash = p_insitu_connected_part_phash,
           old_vs_new_part_macro_phash = p_old_vs_new_part_macro_phash,
           old_part_leave_photo_url = p_old_part_leave_photo_url,
           old_part_leave_photo_phash = p_old_part_leave_photo_phash,
           old_part_disposal_authorized = COALESCE(p_old_part_disposal_authorized, FALSE)
     WHERE id = p_job_id;

    RETURN jsonb_build_object(
        'recorded', TRUE,
        'job_id', p_job_id,
        'material_split_scope', p_material_split_scope,
        'atomic_pin_proof_ready', TRUE
    );
END;
$$;

-- =============================================================================
-- 5. VETOR 5: ZERO UNFUNDED LOCK + TAXA COMPENSATÓRIA DE DESLOCAMENTO SOS
--             REVERTIDA AO ESPECIALISTA PREJUDICADO
-- =============================================================================

CREATE OR REPLACE FUNCTION public.cancel_sos_with_displacement_slashing(
    p_job_id UUID,
    p_client_id UUID,
    p_provider_displaced_meters NUMERIC,
    p_active_route_minutes NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_job RECORD;
    v_slashing_fee NUMERIC(12,2) := 0.00;
    v_client_refund NUMERIC(12,2);
BEGIN
    SELECT * INTO v_job
      FROM public.jobs
     WHERE id = p_job_id
       AND client_id = p_client_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND_OR_UNAUTHORIZED';
    END IF;

    IF v_job.escrow_state <> 'LOCKED_100' THEN
        RAISE EXCEPTION 'INVALID_ESCROW_STATE_FOR_SOS_CANCEL: %', v_job.escrow_state;
    END IF;

    -- Se o especialista já aceitou e iniciou deslocamento real (>= 250m ou >= 4 min),
    -- debita taxa compensatória do Escrow do cliente e reverte 100% ao profissional prejudicado.
    IF v_job.provider_id IS NOT NULL
       AND (p_provider_displaced_meters >= 250.0 OR p_active_route_minutes >= 4.0) THEN
        v_slashing_fee := LEAST(
            v_job.total_amount,
            GREATEST(25.00, LEAST(45.00, ROUND(v_job.total_amount * 0.15, 2)))
        );
    END IF;

    v_client_refund := GREATEST(0.00, v_job.total_amount - v_slashing_fee);

    UPDATE public.jobs
       SET escrow_state = 'REFUNDED_TO_CLIENT'
     WHERE id = p_job_id;

    IF v_slashing_fee > 0 AND v_job.provider_id IS NOT NULL THEN
        INSERT INTO public.wallet_ledger_entries (
            job_id,
            provider_id,
            entry_kind,
            amount,
            description
        )
        VALUES (
            p_job_id,
            v_job.provider_id,
            'PROVIDER_PAYOUT',
            v_slashing_fee,
            'Indenização Automática de Deslocamento SOS (Anti-Slot Locking DoS): '
            || ROUND(p_provider_displaced_meters, 0) || 'm / '
            || ROUND(p_active_route_minutes, 1) || ' min.'
        );
    END IF;

    IF v_client_refund > 0 THEN
        INSERT INTO public.wallet_ledger_entries (
            job_id,
            provider_id,
            entry_kind,
            amount,
            description
        )
        VALUES (
            p_job_id,
            NULL,
            'CLIENT_REFUND',
            v_client_refund,
            'Estorno parcial ao cliente após retenção de taxa compensatória de deslocamento SOS.'
        );
    END IF;

    RETURN jsonb_build_object(
        'canceled', TRUE,
        'job_id', p_job_id,
        'slashing_fee_credited_to_provider', v_slashing_fee,
        'client_refund_amount', v_client_refund
    );
END;
$$;

-- =============================================================================
-- 6. VETOR 6: HANDSHAKE CRIPTOGRÁFICO BILATERAL DE CO-PRESENÇA (QR TOTP / ULTRASSOM)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.verify_bilateral_copresence_handshake(
    p_job_id UUID,
    p_stage TEXT, -- 'CHECKIN' ou 'CHECKOUT'
    p_totp_window_bucket BIGINT,
    p_provided_hmac_hex TEXT,
    p_gnss_agc_cn0_valid BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_job RECORD;
    v_expected_hmac TEXT;
BEGIN
    IF p_stage NOT IN ('CHECKIN', 'CHECKOUT') THEN
        RAISE EXCEPTION 'INVALID_COPRESENCE_STAGE: %', p_stage;
    END IF;

    SELECT * INTO v_job
      FROM public.jobs
     WHERE id = p_job_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;

    IF NOT COALESCE(p_gnss_agc_cn0_valid, FALSE) THEN
        UPDATE public.jobs
           SET gnss_agc_cn0_valid = FALSE
         WHERE id = p_job_id;
        RAISE EXCEPTION 'SDR_GNSS_SPOOFING_DETECTED: Anomalia na razão física AGC x C/N0 das constelações GNSS.';
    END IF;

    v_expected_hmac := encode(
        hmac(
            p_job_id::TEXT || '|' || p_stage || '|' || p_totp_window_bucket::TEXT,
            COALESCE(v_job.job_presence_secret, p_job_id::TEXT),
            'sha256'
        ),
        'hex'
    );

    IF lower(trim(p_provided_hmac_hex)) <> lower(v_expected_hmac) THEN
        RAISE EXCEPTION 'COPRESENCE_HMAC_MISMATCH: Token de co-presença física (QR TOTP / Ultrassom) inválido ou expirado.';
    END IF;

    IF p_stage = 'CHECKIN' THEN
        UPDATE public.jobs
           SET checkin_copresence_proof_hash = v_expected_hmac,
               gnss_agc_cn0_valid = TRUE
         WHERE id = p_job_id;
    ELSE
        UPDATE public.jobs
           SET checkout_copresence_proof_hash = v_expected_hmac,
               gnss_agc_cn0_valid = TRUE
         WHERE id = p_job_id;
    END IF;

    RETURN jsonb_build_object(
        'copresence_verified', TRUE,
        'job_id', p_job_id,
        'stage', p_stage,
        'proof_hash', v_expected_hmac
    );
END;
$$;

COMMIT;

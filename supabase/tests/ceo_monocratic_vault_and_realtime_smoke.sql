-- ============================================================================
-- DESPERRENGUE CEO — Suíte Forense SQL: Cofre Monocrático SHA-256 & Tempo Real
-- Alvo: supabase/migrations/20261114180000_ceo_monocratic_vault_and_realtime_truth.sql
-- Executa em transação isolada com ROLLBACK ao final (zero poluição de estado).
-- ============================================================================

begin;

create or replace function pg_temp.t(cond boolean, msg text)
returns void
language plpgsql
as $$
begin
  if not coalesce(cond, false) then
    raise exception 'ASSERTION_FAILED: %', msg;
  end if;
end;
$$;

do $smoke$
declare
  v_vault_count integer;
  v_owner_email text;
  v_hash_a text;
  v_hash_b text;
  v_salt_hex text := repeat('ab', 32);
  v_intruder_res jsonb;
  v_canaries_before bigint;
  v_canaries_after bigint;
  v_otp_issue jsonb;
  v_otp_verify jsonb;
  v_reg_res jsonb;
  v_unlock_res jsonb;
  v_snap jsonb;
  v_ceo_uid uuid := '00000000-0000-4000-8000-00000000ce01'::uuid;
  v_dev_hash text := repeat('f1', 32);
  v_proof_ok text := repeat('a7', 32);
  v_proof_bad text := repeat('b8', 32);
  v_stepup_token text;
begin
  -- 1. Invariante Singleton Monocrático e erradicação de delegados legados
  select count(*), max(owner_email)
    into v_vault_count, v_owner_email
    from private.ceo_sovereign_vault;

  perform pg_temp.t(v_vault_count = 1, 'ceo_sovereign_vault deve ter exatamente 1 linha singleton');
  perform pg_temp.t(v_owner_email = 'wagneroliveira2395@gmail.com', 'owner_email deve ser estritamente wagneroliveira2395@gmail.com');

  perform pg_temp.t(
    to_regprocedure('public.founder_authorize_delegate(text,text,text,text)') is null,
    'função legada founder_authorize_delegate deve ter sido erradicada'
  );
  perform pg_temp.t(
    to_regprocedure('public.founder_revoke_delegate(text,uuid)') is null,
    'função legada founder_revoke_delegate deve ter sido erradicada'
  );

  -- 2. Derivação SHA-256 determinística de 64 hex chars e comparação em tempo constante
  v_hash_a := private.ceo_compute_pin_sha256(v_proof_ok, v_salt_hex);
  v_hash_b := private.ceo_compute_pin_sha256(v_proof_ok, v_salt_hex);

  perform pg_temp.t(length(v_hash_a) = 64, 'digest PIN SHA-256 deve ter 64 caracteres hexadecimais');
  perform pg_temp.t(private.ceo_constant_time_eq_hex(v_hash_a, v_hash_b), 'comparação constante deve aprovar hashes idênticos');
  perform pg_temp.t(
    not private.ceo_constant_time_eq_hex(v_hash_a, private.ceo_compute_pin_sha256(v_proof_bad, v_salt_hex)),
    'comparação constante deve rejeitar prova divergente'
  );

  -- 3. Tentativa de intruso (qualquer outro e-mail) é bloqueada e grava INTRUSION_CANARY
  select count(*) into v_canaries_before
    from private.founder_audit_log
   where is_intrusion_canary is true;

  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', '00000000-0000-4000-8000-000000009999',
      'role', 'authenticated',
      'email', 'impostor@attacker.org'
    )::text,
    true
  );

  v_intruder_res := public.ceo_vault_status(v_dev_hash);
  perform pg_temp.t(coalesce((v_intruder_res ->> 'ok')::boolean, true) = false, 'intruso jamais pode receber ok=true em ceo_vault_status');
  perform pg_temp.t(
    (v_intruder_res ->> 'error_code') = 'ERR_MONOCRATIC_OWNER_ONLY_42501',
    'intruso deve receber ERR_MONOCRATIC_OWNER_ONLY_42501'
  );

  select count(*) into v_canaries_after
    from private.founder_audit_log
   where is_intrusion_canary is true;

  perform pg_temp.t(v_canaries_after = v_canaries_before + 1, 'intruso deve gravar INTRUSION_CANARY na cadeia WORM');
  perform pg_temp.t(private.verify_founder_audit_chain(), 'cadeia WORM SHA-256 deve permanecer 100% íntegra');

  -- 4. Fluxo completo do único dono (wagneroliveira2395@gmail.com): OTP 6 dígitos -> PIN SHA-256 -> Snapshot Real
  insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
  values (v_ceo_uid, 'wagneroliveira2395@gmail.com', '{}'::jsonb, now(), now())
  on conflict (id) do update set email = excluded.email;

  v_otp_issue := public.ceo_edge_issue_otp_challenge(
    v_ceo_uid,
    'INITIAL_PIN_SETUP',
    v_dev_hash,
    '904817',
    'RESEND_TLS'
  );
  perform pg_temp.t((v_otp_issue ->> 'ok')::boolean = true, 'emissão interna OTP para o dono deve retornar ok=true');

  v_otp_verify := public.ceo_edge_verify_otp_challenge(
    v_ceo_uid,
    (v_otp_issue ->> 'challenge_id')::uuid,
    v_dev_hash,
    '904817',
    'Test Suite Sovereign Device'
  );
  perform pg_temp.t((v_otp_verify ->> 'ok')::boolean = true, 'verificação constante de OTP 6 dígitos correto deve aprovar');
  perform pg_temp.t(length(v_otp_verify ->> 'enrollment_ticket') = 64, 'enrollment_ticket deve ter 64 chars hex');

  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', v_ceo_uid::text,
      'role', 'authenticated',
      'email', 'wagneroliveira2395@gmail.com'
    )::text,
    true
  );

  v_reg_res := public.ceo_register_personal_pin(
    v_otp_verify ->> 'enrollment_ticket',
    v_proof_ok,
    v_dev_hash,
    'Test Suite Sovereign Device'
  );
  perform pg_temp.t((v_reg_res ->> 'ok')::boolean = true, 'ceo_register_personal_pin deve gravar hash SHA-256 e retornar ok=true');

  -- PIN errado deve falhar sem abrir sessão
  v_unlock_res := public.ceo_unlock_sovereign_vault(v_proof_bad, v_dev_hash, 'Test Suite Sovereign Device');
  perform pg_temp.t(coalesce((v_unlock_res ->> 'ok')::boolean, true) = false, 'PIN incorreto deve ser bloqueado');

  -- PIN correto deve destrancar o cofre
  v_unlock_res := public.ceo_unlock_sovereign_vault(v_proof_ok, v_dev_hash, 'Test Suite Sovereign Device');
  perform pg_temp.t((v_unlock_res ->> 'ok')::boolean = true, 'PIN pessoal correto deve destrancar cofre');
  v_stepup_token := v_unlock_res ->> 'stepup_token';

  -- Snapshot ao vivo 100% real (zero-fake)
  v_snap := public.ceo_get_live_cockpit_snapshot(v_stepup_token, v_dev_hash, '30d');
  perform pg_temp.t((v_snap #>> '{vault_metadata,owner_email}') = 'wagneroliveira2395@gmail.com', 'snapshot deve confirmar owner_email monocrático');
  perform pg_temp.t((v_snap ? 'live_operations_pulse') and (v_snap ? 'financial_dre_cents'), 'snapshot deve conter blocos reais completos');
end;
$smoke$;

rollback;

-- =============================================================================
-- DESPERRENGUE CEO — Enterprise OTP Hardening, 10-Min TTL, Anti-Race Same-Device
-- Window & Superseded-Code Diagnostics (NIST SP 800-63B Rev 4)
-- Migration: 20261115010000_ceo_otp_hardening_and_verification_fix.sql (v2.14.1)
--
-- CORREÇÕES CRÍTICAS DE PRODUÇÃO (FORENSE REAL + PADRÃO FINTECH AAL3):
--   1. Protocolo Visual Determinístico (`challenge_ref` #XXXX):
--      - `private.ceo_challenge_ref_code(uuid)` gera o identificador curto de 4
--        caracteres hexadecimais maiúsculos exibido simultaneamente no App e no
--        E-mail para eliminação total de ambiguidade entre envios.
--   2. TTL Estendido para 10 Minutos + Janela Controlada de 2 Desafios Ativos no
--      Mesmo Dispositivo Físico (`device_fingerprint_sha256`):
--      - Absorve atrasos de entrega/sincronização de push no Gmail mobile: caso o
--        CEO solicite reenvio segundos antes do 1º e-mail abrir na tela, tanto o
--        código recém-emitido quanto o imediatamente anterior (não consumido,
--        dentro de 10 min, `< 5` tentativas e vinculado ao EXATO mesmo
--        `device_fingerprint_sha256`) permanecem verificáveis.
--      - Imunidade Total a Replay & Força Bruta: assim que QUALQUER um dos dois
--        códigos é validado, o desafio correspondente recebe `consumed_at = now()`
--        e TODOS os demais desafios daquela finalidade recebem `revoked_at = now()`
--        na mesma transação atômica. Em caso de erro de digitação, `attempts` é
--        incrementado simultaneamente em todos os desafios ativos da finalidade,
--        preservando o teto rígido de 5 tentativas totais!
--   3. Diagnóstico Explícito de Código Substituído (`ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL`):
--      - Se o CEO digitar um código pertencente a um e-mail antigo já revogado
--        (> 2 envios atrás), o motor identifica em tempo constante que se trata de
--        um código anterior substituído e retorna `ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL`
--        junto com `latest_challenge_ref`, jamais confundindo com "código incorreto".
--   4. Reset Limpo de Cooldowns Transitórios Pré-Ativação:
--      - Enquanto `password_configured = false`, limpa `private.ceo_rate_limits`
--        e revoga desafios de teste já expirados para garantir primeiro acesso
--        imediato sem bloqueio residual.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Utilitário Determinístico de Protocolo Curto (`#XXXX`)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_challenge_ref_code(
  p_challenge_id uuid
)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select upper(left(replace(coalesce(p_challenge_id::text, ''), '-', ''), 4));
$$;

revoke all on function private.ceo_challenge_ref_code(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Emissor Interno Unificado de Desafio OTP 6 Dígitos (TTL 10 min + Janela 2x)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_issue_otp_challenge_internal(
  p_user_id uuid,
  p_purpose text,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_clean_purpose text := upper(btrim(coalesce(p_purpose, '')));
  v_clean_dev     text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip      text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp     text := btrim(coalesce(p_otp_code, ''));
  v_now           timestamptz := now();
  v_expires_at    timestamptz := v_now + interval '10 minutes';
  v_challenge_id  uuid := gen_random_uuid();
  v_salt_hex      char(64);
  v_otp_digest    char(64);
begin
  if p_user_id is null
     or v_clean_purpose not in ('INITIAL_PASSWORD_SETUP', 'LOGIN_2FA', 'PROFILE_PASSWORD_CHANGE_AUTH')
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_ip !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  -- Preserva NO MÁXIMO 1 desafio anterior não-consumido emitido há menos de 10 min
  -- no EXATO mesmo dispositivo físico (`device_fingerprint_sha256`), revogando todos
  -- os demais (outros dispositivos, expirados ou mais antigos que o imediatamente anterior).
  update private.ceo_security_challenges csc
     set revoked_at = v_now
   where csc.user_id = p_user_id
     and csc.purpose = v_clean_purpose
     and csc.consumed_at is null
     and csc.revoked_at is null
     and (
       csc.expires_at <= v_now
       or csc.attempts >= csc.max_attempts
       or not private.ceo_constant_time_eq_hex(csc.device_fingerprint_sha256, v_clean_dev)
       or csc.challenge_id not in (
         select keep_prev.challenge_id
           from private.ceo_security_challenges keep_prev
          where keep_prev.user_id = p_user_id
            and keep_prev.purpose = v_clean_purpose
            and keep_prev.consumed_at is null
            and keep_prev.revoked_at is null
            and keep_prev.expires_at > v_now
            and keep_prev.attempts < keep_prev.max_attempts
            and private.ceo_constant_time_eq_hex(keep_prev.device_fingerprint_sha256, v_clean_dev)
          order by keep_prev.created_at desc
          limit 1
       )
     );

  v_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_otp_digest := private.ceo_compute_challenge_otp_sha256(
    v_clean_purpose,
    v_challenge_id,
    v_clean_otp,
    v_salt_hex,
    v_clean_dev
  );

  insert into private.ceo_security_challenges (
    challenge_id,
    user_id,
    purpose,
    otp_salt_hex,
    otp_digest_sha256,
    device_fingerprint_sha256,
    ip_sha256,
    attempts,
    max_attempts,
    expires_at,
    created_at
  ) values (
    v_challenge_id,
    p_user_id,
    v_clean_purpose,
    v_salt_hex,
    v_otp_digest,
    v_clean_dev::char(64),
    v_clean_ip::char(64),
    0,
    5,
    v_expires_at,
    v_now
  );

  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge_id,
    'challenge_ref', private.ceo_challenge_ref_code(v_challenge_id),
    'issued_at', v_now,
    'expires_at', v_expires_at
  );
end $$;

revoke all on function private.ceo_issue_otp_challenge_internal(uuid, text, text, text, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Verificador Interno Unificado em Tempo Constante (Anti-Race + Anti-Replay)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_verify_and_consume_otp_challenge(
  p_user_id uuid,
  p_purpose text,
  p_requested_challenge_id uuid,
  p_otp_code text,
  p_device_hash text,
  p_rate_bucket_key text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_clean_purpose    text := upper(btrim(coalesce(p_purpose, '')));
  v_clean_dev        text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_otp        text := btrim(coalesce(p_otp_code, ''));
  v_now              timestamptz := now();
  v_req_row          private.ceo_security_challenges%rowtype;
  v_latest_row       private.ceo_security_challenges%rowtype;
  v_cand_row         record;
  v_cand_hash        char(64);
  v_matched_id       uuid := null;
  v_active_count     integer := 0;
  v_latest_active_id uuid := null;
  v_matched_old_id   uuid := null;
  v_max_attempts_now integer := 0;
  v_rem_attempts     integer := 0;
begin
  if p_user_id is null
     or v_clean_purpose not in ('INITIAL_PASSWORD_SETUP', 'LOGIN_2FA', 'PROFILE_PASSWORD_CHANGE_AUTH')
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  -- Serializa todas as linhas recentes desta finalidade para o titular único
  perform 1
    from private.ceo_security_challenges csc
   where csc.user_id = p_user_id
     and csc.purpose = v_clean_purpose
     and csc.created_at >= v_now - interval '2 hours'
     for update;

  -- Se um challenge_id específico foi informado, valida que não pertence a outro dispositivo
  if p_requested_challenge_id is not null then
    select *
      into v_req_row
      from private.ceo_security_challenges csc
     where csc.challenge_id = p_requested_challenge_id
       and csc.user_id = p_user_id
       and csc.purpose = v_clean_purpose;

    if found and not private.ceo_constant_time_eq_hex(v_req_row.device_fingerprint_sha256, v_clean_dev) then
      perform private.record_founder_intrusion_canary(
        p_user_id,
        v_clean_purpose || '_OTP_DEVICE_MISMATCH',
        jsonb_build_object('challenge_id', p_requested_challenge_id)
      );
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
    end if;
  end if;

  -- Percorre os desafios ativos (máx. 2) vinculados ao mesmo dispositivo físico sem early-exit
  for v_cand_row in
    select csc.*
      from private.ceo_security_challenges csc
     where csc.user_id = p_user_id
       and csc.purpose = v_clean_purpose
       and csc.consumed_at is null
       and csc.revoked_at is null
       and csc.expires_at > v_now
       and csc.attempts < csc.max_attempts
       and private.ceo_constant_time_eq_hex(csc.device_fingerprint_sha256, v_clean_dev)
     order by
       case when csc.challenge_id = p_requested_challenge_id then 0 else 1 end,
       csc.created_at desc
     limit 2
  loop
    v_active_count := v_active_count + 1;

    v_cand_hash := private.ceo_compute_challenge_otp_sha256(
      v_clean_purpose,
      v_cand_row.challenge_id,
      v_clean_otp,
      v_cand_row.otp_salt_hex,
      v_clean_dev
    );

    if private.ceo_constant_time_eq_hex(v_cand_hash, v_cand_row.otp_digest_sha256) then
      if v_matched_id is null then
        v_matched_id := v_cand_row.challenge_id;
      end if;
    end if;
  end loop;

  -- Reidentifica sempre o desafio ativo cronologicamente mais recente para referência visual
  select csc.challenge_id
    into v_latest_active_id
    from private.ceo_security_challenges csc
   where csc.user_id = p_user_id
     and csc.purpose = v_clean_purpose
     and csc.consumed_at is null
     and csc.revoked_at is null
     and csc.expires_at > v_now
     and csc.attempts < csc.max_attempts
     and private.ceo_constant_time_eq_hex(csc.device_fingerprint_sha256, v_clean_dev)
   order by csc.created_at desc
   limit 1;

  -- Caso nenhum desafio esteja ativo no momento, diagnostica o motivo exato
  if v_active_count = 0 then
    select *
      into v_latest_row
      from private.ceo_security_challenges csc
     where csc.user_id = p_user_id
       and csc.purpose = v_clean_purpose
     order by
       case when csc.challenge_id = p_requested_challenge_id then 0 else 1 end,
       csc.created_at desc
     limit 1;

    if not found then
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
    end if;

    if not private.ceo_constant_time_eq_hex(v_latest_row.device_fingerprint_sha256, v_clean_dev) then
      perform private.record_founder_intrusion_canary(
        p_user_id,
        v_clean_purpose || '_OTP_DEVICE_MISMATCH',
        jsonb_build_object('challenge_id', v_latest_row.challenge_id)
      );
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
    end if;

    if v_latest_row.consumed_at is not null then
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
    end if;

    if v_latest_row.attempts >= v_latest_row.max_attempts then
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED', 'remaining_attempts', 0);
    end if;

    if v_latest_row.expires_at <= v_now then
      return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_EXPIRED');
    end if;

    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_ALREADY_USED');
  end if;

  -- SUCESSO CRIPTOGRÁFICO: consome o desafio validado e revoga TODOS os demais ativos!
  if v_matched_id is not null then
    update private.ceo_security_challenges
       set consumed_at = v_now
     where challenge_id = v_matched_id;

    update private.ceo_security_challenges
       set revoked_at = v_now
     where user_id = p_user_id
       and purpose = v_clean_purpose
       and challenge_id <> v_matched_id
       and consumed_at is null
       and revoked_at is null;

    if p_rate_bucket_key is not null and btrim(p_rate_bucket_key) <> '' then
      update private.ceo_rate_limits
         set consecutive_sends = 0,
             cooldown_until    = null,
             updated_at        = v_now
       where bucket_key = btrim(p_rate_bucket_key);
    end if;

    return jsonb_build_object(
      'ok', true,
      'matched_challenge_id', v_matched_id,
      'challenge_ref', private.ceo_challenge_ref_code(v_matched_id)
    );
  end if;

  -- FALHA: verifica se o CEO digitou um código pertencente a um e-mail anterior já substituído/expirado
  for v_cand_row in
    select csc.challenge_id, csc.otp_salt_hex, csc.otp_digest_sha256
      from private.ceo_security_challenges csc
     where csc.user_id = p_user_id
       and csc.purpose = v_clean_purpose
       and csc.consumed_at is null
       and (csc.revoked_at is not null or csc.expires_at <= v_now)
       and csc.created_at >= v_now - interval '2 hours'
       and private.ceo_constant_time_eq_hex(csc.device_fingerprint_sha256, v_clean_dev)
     order by csc.created_at desc
     limit 5
  loop
    v_cand_hash := private.ceo_compute_challenge_otp_sha256(
      v_clean_purpose,
      v_cand_row.challenge_id,
      v_clean_otp,
      v_cand_row.otp_salt_hex,
      v_clean_dev
    );
    if private.ceo_constant_time_eq_hex(v_cand_hash, v_cand_row.otp_digest_sha256) then
      if v_matched_old_id is null then
        v_matched_old_id := v_cand_row.challenge_id;
      end if;
    end if;
  end loop;

  -- Incrementa `attempts` simultaneamente em TODOS os desafios ativos desta finalidade
  -- (garante orçamento máximo global estrito de 5 tentativas!)
  update private.ceo_security_challenges csc
     set attempts   = csc.attempts + 1,
         revoked_at = case when csc.attempts + 1 >= csc.max_attempts then v_now else csc.revoked_at end
   where csc.user_id = p_user_id
     and csc.purpose = v_clean_purpose
     and csc.consumed_at is null
     and csc.revoked_at is null
     and csc.expires_at > v_now
     and private.ceo_constant_time_eq_hex(csc.device_fingerprint_sha256, v_clean_dev);

  select coalesce(max(csc.attempts), 5),
         coalesce(min(greatest(0, csc.max_attempts - csc.attempts)), 0)
    into v_max_attempts_now, v_rem_attempts
    from private.ceo_security_challenges csc
   where csc.user_id = p_user_id
     and csc.purpose = v_clean_purpose
     and csc.challenge_id = v_latest_active_id;

  return jsonb_build_object(
    'ok', false,
    'error_code', case
      when v_rem_attempts <= 0 then 'ERR_OTP_MAX_ATTEMPTS_EXCEEDED'
      when v_matched_old_id is not null then 'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL'
      else 'ERR_OTP_CODE_INCORRECT'
    end,
    'attempts', v_max_attempts_now,
    'remaining_attempts', greatest(0, v_rem_attempts),
    'latest_challenge_id', v_latest_active_id,
    'latest_challenge_ref', private.ceo_challenge_ref_code(v_latest_active_id)
  );
end $$;

revoke all on function private.ceo_verify_and_consume_otp_challenge(uuid, text, uuid, text, text, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. RPCs Atualizadas para `ceo-vault-authority` (`service_role`)
-- -----------------------------------------------------------------------------

-- 4.1 Primeiro Acesso: Emissão do Código de 6 Dígitos (`INITIAL_PASSWORD_SETUP`)
create or replace function public.ceo_edge_issue_bootstrap_otp(
  p_user_id uuid,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email   text;
  v_clean_dev  text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip   text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp  text := btrim(coalesce(p_otp_code, ''));
  v_vault      private.ceo_sovereign_vault%rowtype;
  v_rl_res     jsonb;
  v_issue_res  jsonb;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'BOOTSTRAP_OTP_NON_OWNER_BLOCKED',
      jsonb_build_object('ip_sha256', left(v_clean_ip, 64))
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_dev !~ '^[0-9a-f]{64}$' or v_clean_ip !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if v_vault.password_configured then
    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_BOOTSTRAP_ATTEMPT_AFTER_SEAL_BLOCKED',
      'WARN',
      true,
      jsonb_build_object('ip_sha256', v_clean_ip)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_VAULT_ALREADY_SEALED');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('bootstrap_otp', 10);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  v_issue_res := private.ceo_issue_otp_challenge_internal(
    p_user_id,
    'INITIAL_PASSWORD_SETUP',
    v_clean_dev,
    v_clean_ip,
    v_clean_otp
  );
  if (v_issue_res ->> 'ok')::boolean is not true then
    return v_issue_res;
  end if;

  update private.ceo_sovereign_vault
     set owner_user_id = coalesce(owner_user_id, p_user_id),
         updated_at    = now()
   where singleton_id = true;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_BOOTSTRAP_OTP_6D_ISSUED',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_issue_res -> 'challenge_id',
      'challenge_ref', v_issue_res -> 'challenge_ref',
      'expires_at', v_issue_res -> 'expires_at'
    )
  );

  return v_issue_res || jsonb_build_object(
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_issue_bootstrap_otp(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_issue_bootstrap_otp(uuid, text, text, text) to service_role;

-- 4.2 Primeiro Acesso: Verificação do Código de 6 Dígitos (`INITIAL_PASSWORD_SETUP`)
create or replace function public.ceo_edge_verify_bootstrap_otp(
  p_user_id uuid,
  p_challenge_id uuid,
  p_otp_code text,
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_vault        private.ceo_sovereign_vault%rowtype;
  v_verify_res   jsonb;
  v_matched_id   uuid;
  v_raw_ticket   text;
  v_ticket_hash  char(64);
  v_ticket_exp   timestamptz := now() + interval '15 minutes';
  v_rem          integer;
begin
  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  if v_vault.password_configured then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_VAULT_ALREADY_SEALED');
  end if;

  v_verify_res := private.ceo_verify_and_consume_otp_challenge(
    p_user_id,
    'INITIAL_PASSWORD_SETUP',
    p_challenge_id,
    p_otp_code,
    p_device_hash,
    'bootstrap_otp'
  );

  if (v_verify_res ->> 'ok')::boolean is not true then
    if (v_verify_res ->> 'error_code') in (
      'ERR_OTP_CODE_INCORRECT',
      'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL',
      'ERR_OTP_MAX_ATTEMPTS_EXCEEDED'
    ) then
      v_rem := coalesce((v_verify_res ->> 'remaining_attempts')::integer, 0);
      perform private.record_founder_audit_event(
        p_user_id,
        p_user_id,
        'CEO_BOOTSTRAP_OTP_6D_MISMATCH',
        case when v_rem <= 0 then 'CRITICAL' else 'WARN' end,
        (v_rem <= 0),
        jsonb_build_object(
          'error_code', v_verify_res ->> 'error_code',
          'attempts', coalesce((v_verify_res ->> 'attempts')::integer, 1),
          'challenge_id', p_challenge_id,
          'latest_challenge_ref', v_verify_res ->> 'latest_challenge_ref'
        )
      );
    end if;
    return v_verify_res;
  end if;

  v_matched_id := (v_verify_res ->> 'matched_challenge_id')::uuid;
  v_raw_ticket := lower(encode(extensions.gen_random_bytes(32), 'hex'));
  v_ticket_hash := lower(encode(extensions.digest(convert_to(v_raw_ticket, 'UTF8'), 'sha256'), 'hex'))::char(64);

  update private.ceo_security_challenges
     set enrollment_ticket_sha256     = v_ticket_hash,
         enrollment_ticket_expires_at = v_ticket_exp
   where challenge_id = v_matched_id;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_BOOTSTRAP_OTP_6D_VERIFIED',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_matched_id,
      'challenge_ref', v_verify_res ->> 'challenge_ref',
      'ticket_expires_at', v_ticket_exp
    )
  );

  return jsonb_build_object(
    'ok', true,
    'enrollment_ticket', v_raw_ticket,
    'ticket_expires_at', v_ticket_exp,
    'challenge_ref', v_verify_res ->> 'challenge_ref'
  );
end $$;

revoke all on function public.ceo_edge_verify_bootstrap_otp(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_bootstrap_otp(uuid, uuid, text, text) to service_role;

-- 4.3 Login Diário Passo 1: Senha Mestra AES-256 + Emissão de OTP 6 Dígitos (`LOGIN_2FA`)
create or replace function public.ceo_edge_verify_password_and_issue_login_otp(
  p_user_id uuid,
  p_edge_key_hex text,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text,
  p_is_resend boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_db_email       text;
  v_clean_ek       text := lower(btrim(coalesce(p_edge_key_hex, '')));
  v_clean_dev      text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip       text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp      text := btrim(coalesce(p_otp_code, ''));
  v_vault          private.ceo_sovereign_vault%rowtype;
  v_stored_hex     char(64);
  v_candidate_hex  char(64);
  v_failed         integer;
  v_lock_until     timestamptz;
  v_rl_res         jsonb;
  v_issue_res      jsonb;
begin
  select lower(btrim(au.email))
    into v_db_email
    from auth.users au
   where au.id = p_user_id
     and au.deleted_at is null;

  if v_db_email is distinct from private.ceo_owner_canonical_email() then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'LOGIN_PASSWORD_NON_OWNER_BLOCKED',
      jsonb_build_object('ip_sha256', left(v_clean_ip, 64))
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MONOCRATIC_OWNER_ONLY_42501');
  end if;

  if v_clean_ek !~ '^[0-9a-f]{64}$'
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_ip !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_CRYPTOGRAPHIC_PROOF');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if not v_vault.password_configured
     or v_vault.password_verifier_cipher is null
     or v_vault.password_salt_hex is null then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MASTER_PASSWORD_NOT_CONFIGURED');
  end if;

  if v_vault.locked_until is not null and v_vault.locked_until > now() then
    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_LOGIN_ATTEMPT_DURING_LOCKOUT',
      'WARN',
      true,
      jsonb_build_object('locked_until', v_vault.locked_until, 'failed_attempts', v_vault.failed_password_attempts)
    );
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_VAULT_LOCKED_BACKOFF',
      'failed_attempts', v_vault.failed_password_attempts,
      'locked_until', v_vault.locked_until
    );
  end if;

  v_stored_hex := private.ceo_decrypt_password_verifier_hex(v_vault.password_verifier_cipher);
  v_candidate_hex := private.ceo_compute_password_verifier_hex(v_clean_ek, v_vault.password_salt_hex);

  if not private.ceo_constant_time_eq_hex(v_stored_hex, v_candidate_hex) then
    v_failed := v_vault.failed_password_attempts + 1;
    if v_failed = 4 then
      v_lock_until := now() + interval '60 seconds';
    elsif v_failed = 5 then
      v_lock_until := now() + interval '5 minutes';
    elsif v_failed >= 6 then
      v_lock_until := now() + interval '30 minutes';
    else
      v_lock_until := null;
    end if;

    update private.ceo_sovereign_vault
       set failed_password_attempts = v_failed,
           failed_pin_attempts      = v_failed,
           locked_until             = v_lock_until,
           updated_at               = now()
     where singleton_id = true;

    perform private.record_founder_audit_event(
      p_user_id,
      p_user_id,
      'CEO_MASTER_PASSWORD_MISMATCH',
      case when v_failed >= 4 then 'CRITICAL' else 'WARN' end,
      (v_failed >= 4),
      jsonb_build_object(
        'failed_attempts', v_failed,
        'locked_until', v_lock_until,
        'ip_sha256', v_clean_ip
      )
    );

    return jsonb_build_object(
      'ok', false,
      'error_code', case when v_lock_until is not null then 'ERR_VAULT_LOCKED_BACKOFF' else 'ERR_INVALID_MASTER_PASSWORD' end,
      'failed_attempts', v_failed,
      'locked_until', v_lock_until,
      'send_lockout_security_alert', (v_failed = 5)
    );
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('login_2fa_otp', 14);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  v_issue_res := private.ceo_issue_otp_challenge_internal(
    p_user_id,
    'LOGIN_2FA',
    v_clean_dev,
    v_clean_ip,
    v_clean_otp
  );
  if (v_issue_res ->> 'ok')::boolean is not true then
    return v_issue_res;
  end if;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    case when p_is_resend then 'CEO_LOGIN_2FA_OTP_RESENT' else 'CEO_LOGIN_2FA_OTP_ISSUED' end,
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_issue_res -> 'challenge_id',
      'challenge_ref', v_issue_res -> 'challenge_ref',
      'expires_at', v_issue_res -> 'expires_at'
    )
  );

  return v_issue_res || jsonb_build_object(
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_verify_password_and_issue_login_otp(uuid, text, text, text, text, boolean) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_password_and_issue_login_otp(uuid, text, text, text, text, boolean) to service_role;

-- 4.4 Login Diário: Reenvio Seguro sem Reter Senha na RAM (`LOGIN_2FA`)
create or replace function public.ceo_edge_resend_login_otp(
  p_user_id uuid,
  p_previous_challenge_id uuid,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev  text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip   text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp  text := btrim(coalesce(p_otp_code, ''));
  v_prev_ch    private.ceo_security_challenges%rowtype;
  v_rl_res     jsonb;
  v_issue_res  jsonb;
begin
  if p_previous_challenge_id is null
     or v_clean_dev !~ '^[0-9a-f]{64}$'
     or v_clean_ip !~ '^[0-9a-f]{64}$'
     or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_prev_ch
    from private.ceo_security_challenges csc
   where csc.challenge_id = p_previous_challenge_id
     and csc.user_id = p_user_id
     and csc.purpose = 'LOGIN_2FA'
     for update;

  if not found
     or v_prev_ch.consumed_at is not null
     or v_prev_ch.attempts >= v_prev_ch.max_attempts
     or v_prev_ch.created_at <= now() - interval '20 minutes' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_CHALLENGE_NOT_FOUND');
  end if;

  if not private.ceo_constant_time_eq_hex(v_prev_ch.device_fingerprint_sha256, v_clean_dev) then
    perform private.record_founder_intrusion_canary(
      p_user_id,
      'RESEND_LOGIN_OTP_DEVICE_MISMATCH',
      jsonb_build_object('previous_challenge_id', p_previous_challenge_id)
    );
    return jsonb_build_object('ok', false, 'error_code', 'ERR_OTP_DEVICE_MISMATCH');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('login_2fa_otp', 14);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  v_issue_res := private.ceo_issue_otp_challenge_internal(
    p_user_id,
    'LOGIN_2FA',
    v_clean_dev,
    v_clean_ip,
    v_clean_otp
  );
  if (v_issue_res ->> 'ok')::boolean is not true then
    return v_issue_res;
  end if;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_LOGIN_2FA_OTP_RESENT',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_issue_res -> 'challenge_id',
      'challenge_ref', v_issue_res -> 'challenge_ref',
      'expires_at', v_issue_res -> 'expires_at'
    )
  );

  return v_issue_res || jsonb_build_object(
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_resend_login_otp(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_resend_login_otp(uuid, uuid, text, text, text) to service_role;

-- 4.5 Login Diário Passo 2: Validação do Código de 6 Dígitos (`LOGIN_2FA`)
create or replace function public.ceo_edge_complete_login_2fa(
  p_user_id uuid,
  p_challenge_id uuid,
  p_otp_code text,
  p_device_hash text,
  p_device_label text default 'Desperrengue CEO · Android Blindado'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev  text := lower(btrim(coalesce(p_device_hash, '')));
  v_vault      private.ceo_sovereign_vault%rowtype;
  v_verify_res jsonb;
  v_now        timestamptz := now();
  v_stepup     jsonb;
  v_rem        integer;
begin
  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true
     for update;

  if not v_vault.password_configured then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_MASTER_PASSWORD_NOT_CONFIGURED');
  end if;

  v_verify_res := private.ceo_verify_and_consume_otp_challenge(
    p_user_id,
    'LOGIN_2FA',
    p_challenge_id,
    p_otp_code,
    v_clean_dev,
    'login_2fa_otp'
  );

  if (v_verify_res ->> 'ok')::boolean is not true then
    if (v_verify_res ->> 'error_code') in (
      'ERR_OTP_CODE_INCORRECT',
      'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL',
      'ERR_OTP_MAX_ATTEMPTS_EXCEEDED'
    ) then
      v_rem := coalesce((v_verify_res ->> 'remaining_attempts')::integer, 0);
      perform private.record_founder_audit_event(
        p_user_id,
        p_user_id,
        'CEO_LOGIN_2FA_OTP_MISMATCH',
        case when v_rem <= 0 then 'CRITICAL' else 'WARN' end,
        (v_rem <= 0),
        jsonb_build_object(
          'error_code', v_verify_res ->> 'error_code',
          'attempts', coalesce((v_verify_res ->> 'attempts')::integer, 1),
          'challenge_id', p_challenge_id,
          'latest_challenge_ref', v_verify_res ->> 'latest_challenge_ref'
        )
      );
    end if;
    return v_verify_res;
  end if;

  update private.ceo_sovereign_vault
     set owner_user_id            = p_user_id,
         failed_password_attempts = 0,
         failed_pin_attempts      = 0,
         locked_until             = null,
         last_login_at            = v_now,
         last_login_device_sha256 = v_clean_dev::char(64),
         updated_at               = v_now
   where singleton_id = true;

  v_stepup := private.ceo_issue_stepup_session_internal(
    p_user_id,
    v_clean_dev,
    p_device_label,
    v_vault.password_version
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_SOVEREIGN_LOGIN_2FA_COMPLETED',
    'INFO',
    false,
    jsonb_build_object(
      'password_version', v_vault.password_version,
      'challenge_ref', v_verify_res ->> 'challenge_ref',
      'device_label', left(coalesce(p_device_label, ''), 80)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'password_version', v_vault.password_version,
    'password_updated_at', v_vault.password_updated_at,
    'stepup_token', v_stepup ->> 'stepup_token',
    'stepup_expires_at', v_stepup ->> 'expires_at',
    'challenge_ref', v_verify_res ->> 'challenge_ref'
  );
end $$;

revoke all on function public.ceo_edge_complete_login_2fa(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_complete_login_2fa(uuid, uuid, text, text, text) to service_role;

-- 4.6 Perfil CEO Etapa 1: Emissão do Código de 6 Dígitos (`PROFILE_PASSWORD_CHANGE_AUTH`)
create or replace function public.ceo_edge_request_profile_password_change_otp(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text,
  p_ip_hash text,
  p_otp_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev  text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_ip   text := lower(btrim(coalesce(p_ip_hash, '')));
  v_clean_otp  text := btrim(coalesce(p_otp_code, ''));
  v_rl_res     jsonb;
  v_issue_res  jsonb;
begin
  if not private.ceo_verify_active_edge_stepup(p_user_id, p_stepup_token, v_clean_dev) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED'
    );
  end if;

  if v_clean_ip !~ '^[0-9a-f]{64}$' or v_clean_otp !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  v_rl_res := private.ceo_check_and_bump_rate_limit('profile_pw_change_otp', 10);
  if (v_rl_res ->> 'ok')::boolean is not true then
    return v_rl_res;
  end if;

  v_issue_res := private.ceo_issue_otp_challenge_internal(
    p_user_id,
    'PROFILE_PASSWORD_CHANGE_AUTH',
    v_clean_dev,
    v_clean_ip,
    v_clean_otp
  );
  if (v_issue_res ->> 'ok')::boolean is not true then
    return v_issue_res;
  end if;

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_PROFILE_PW_CHANGE_OTP_6D_ISSUED',
    'INFO',
    false,
    jsonb_build_object(
      'challenge_id', v_issue_res -> 'challenge_id',
      'challenge_ref', v_issue_res -> 'challenge_ref',
      'expires_at', v_issue_res -> 'expires_at'
    )
  );

  return v_issue_res || jsonb_build_object(
    'next_cooldown_seconds', (v_rl_res ->> 'next_cooldown_seconds')::integer
  );
end $$;

revoke all on function public.ceo_edge_request_profile_password_change_otp(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_request_profile_password_change_otp(uuid, text, text, text, text) to service_role;

-- 4.7 Perfil CEO Etapa 2: Valida Código de 6 Dígitos e Emite Link Efêmero (E-mail #2)
create or replace function public.ceo_edge_verify_profile_otp_and_issue_reset_link(
  p_user_id uuid,
  p_stepup_token text,
  p_device_hash text,
  p_challenge_id uuid,
  p_otp_code text,
  p_raw_grant_hex text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean_dev     text := lower(btrim(coalesce(p_device_hash, '')));
  v_clean_grant   text := lower(btrim(coalesce(p_raw_grant_hex, '')));
  v_vault         private.ceo_sovereign_vault%rowtype;
  v_verify_res    jsonb;
  v_matched_id    uuid;
  v_link_id       uuid := gen_random_uuid();
  v_link_salt_hex char(64);
  v_grant_hash    char(64);
  v_link_expires  timestamptz := now() + interval '10 minutes';
  v_rem           integer;
begin
  if not private.ceo_verify_active_edge_stepup(p_user_id, p_stepup_token, v_clean_dev) then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED'
    );
  end if;

  if v_clean_grant !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error_code', 'ERR_INVALID_OTP_INPUT');
  end if;

  select *
    into v_vault
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  v_verify_res := private.ceo_verify_and_consume_otp_challenge(
    p_user_id,
    'PROFILE_PASSWORD_CHANGE_AUTH',
    p_challenge_id,
    p_otp_code,
    v_clean_dev,
    'profile_pw_change_otp'
  );

  if (v_verify_res ->> 'ok')::boolean is not true then
    if (v_verify_res ->> 'error_code') in (
      'ERR_OTP_CODE_INCORRECT',
      'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL',
      'ERR_OTP_MAX_ATTEMPTS_EXCEEDED'
    ) then
      v_rem := coalesce((v_verify_res ->> 'remaining_attempts')::integer, 0);
      perform private.record_founder_audit_event(
        p_user_id,
        p_user_id,
        'CEO_PROFILE_PW_CHANGE_OTP_MISMATCH',
        case when v_rem <= 0 then 'CRITICAL' else 'WARN' end,
        (v_rem <= 0),
        jsonb_build_object(
          'error_code', v_verify_res ->> 'error_code',
          'attempts', coalesce((v_verify_res ->> 'attempts')::integer, 1),
          'challenge_id', p_challenge_id,
          'latest_challenge_ref', v_verify_res ->> 'latest_challenge_ref'
        )
      );
    end if;
    return v_verify_res;
  end if;

  v_matched_id := (v_verify_res ->> 'matched_challenge_id')::uuid;

  update private.ceo_password_reset_links
     set revoked_at = now()
   where user_id = p_user_id
     and consumed_at is null
     and revoked_at is null;

  v_link_salt_hex := lower(encode(extensions.gen_random_bytes(32), 'hex'))::char(64);
  v_grant_hash := private.ceo_compute_reset_grant_sha256(v_link_id, v_clean_grant, v_link_salt_hex);

  insert into private.ceo_password_reset_links (
    link_id,
    user_id,
    source_challenge_id,
    link_salt_hex,
    grant_token_sha256,
    requesting_device_sha256,
    password_version_at_issue,
    bridge_opened_count,
    expires_at
  ) values (
    v_link_id,
    p_user_id,
    v_matched_id,
    v_link_salt_hex,
    v_grant_hash,
    v_clean_dev::char(64),
    v_vault.password_version,
    0,
    v_link_expires
  );

  perform private.record_founder_audit_event(
    p_user_id,
    p_user_id,
    'CEO_PASSWORD_RESET_LINK_AUTHORIZED',
    'INFO',
    false,
    jsonb_build_object(
      'link_id', v_link_id,
      'expires_at', v_link_expires,
      'password_version_at_issue', v_vault.password_version
    )
  );

  return jsonb_build_object(
    'ok', true,
    'link_id', v_link_id,
    'expires_at', v_link_expires
  );
end $$;

revoke all on function public.ceo_edge_verify_profile_otp_and_issue_reset_link(uuid, text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ceo_edge_verify_profile_otp_and_issue_reset_link(uuid, text, text, uuid, text, text) to service_role;

-- -----------------------------------------------------------------------------
-- 5. Higienização Pré-Ativação dos Buckets de Cooldown (quando `password_configured = false`)
-- -----------------------------------------------------------------------------
delete from private.ceo_rate_limits
 where exists (
   select 1
     from private.ceo_sovereign_vault csv
    where csv.singleton_id = true
      and csv.password_configured = false
 );

update private.ceo_security_challenges
   set revoked_at = now()
 where consumed_at is null
   and revoked_at is null
   and expires_at <= now();

commit;

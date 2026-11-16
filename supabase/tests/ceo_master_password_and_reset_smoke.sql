-- ============================================================================
-- DESPERRENGUE CEO — Suíte Forense Red-Team SQL: Cofre de Senha Mestra Forte
-- (Split-Pepper + HMAC-SHA512 x 25.000 + AES-256), 2FA 6d & Deep-Link Efêmero
-- Alvo: supabase/migrations/20261115000000_ceo_master_password_vault_and_reset_ceremony.sql
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
  v_ceo_uid         uuid := '00000000-0000-4000-8000-00000000ce01'::uuid;
  v_dev_ok          text := repeat('d1', 32);
  v_dev_attacker    text := repeat('e9', 32);
  v_ip_hash         text := repeat('1a', 32);
  v_salt_hex        text := repeat('ab', 32);
  v_ek_v1           text := repeat('a1', 32);
  v_ek_v2           text := repeat('b2', 32);
  v_ek_wrong        text := repeat('ff', 32);
  v_ver_a           text;
  v_ver_b           text;
  v_cipher_a        bytea;
  v_cipher_b        bytea;
  v_canaries_before bigint;
  v_canaries_after  bigint;
  v_res             jsonb;
  v_ch_id           uuid;
  v_ticket          text;
  v_stepup_v1       text;
  v_stepup_login    text;
  v_grant_a         text := repeat('7c', 32);
  v_grant_b         text := repeat('8d', 32);
  v_link_id_a       uuid;
  v_link_id_b       uuid;
  v_login_ch_cnt    integer;
  v_snap            jsonb;
  v_revoked_err     boolean := false;
begin
  -- Garante estado limpo de primeiro acesso dentro da transação de teste
  delete from private.ceo_password_reset_links;
  delete from private.ceo_security_challenges;
  delete from private.ceo_password_history;
  delete from private.ceo_rate_limits;
  delete from private.ceo_stepup_sessions;

  update private.ceo_sovereign_vault
     set password_configured      = false,
         password_verifier_cipher = null,
         password_salt_hex        = null,
         password_version         = 0,
         failed_password_attempts = 0,
         failed_pin_attempts      = 0,
         locked_until             = null
   where singleton_id = true;

  insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
  values (v_ceo_uid, 'wagneroliveira2395@gmail.com', '{}'::jsonb, now(), now())
  on conflict (id) do update set email = excluded.email;

  -- 1. Erradicação física das RPCs legadas de PIN curto
  perform pg_temp.t(
    to_regprocedure('public.ceo_register_personal_pin(text,text,text,text)') is null,
    'ceo_register_personal_pin deve ter sido removida'
  );
  perform pg_temp.t(
    to_regprocedure('public.ceo_unlock_sovereign_vault(text,text,text)') is null,
    'ceo_unlock_sovereign_vault deve ter sido removida'
  );
  perform pg_temp.t(
    to_regprocedure('public.ceo_vault_status(text)') is null,
    'ceo_vault_status deve ter sido removida'
  );

  -- 2. Primitivas criptográficas: 25.000 rodadas HMAC-SHA512 + cifragem AES-256 probabilística
  v_ver_a := private.ceo_compute_password_verifier_hex(v_ek_v1, v_salt_hex);
  v_ver_b := private.ceo_compute_password_verifier_hex(v_ek_v1, v_salt_hex);
  perform pg_temp.t(length(v_ver_a) = 64, 'verificador derivado deve ter 64 hex chars');
  perform pg_temp.t(private.ceo_constant_time_eq_hex(v_ver_a, v_ver_b), 'HMAC-SHA512 x 25k deve ser determinístico');
  perform pg_temp.t(
    not private.ceo_constant_time_eq_hex(v_ver_a, private.ceo_compute_password_verifier_hex(v_ek_wrong, v_salt_hex)),
    'EK diferente deve produzir verificador completamente distinto'
  );

  v_cipher_a := private.ceo_encrypt_password_verifier(v_ver_a);
  v_cipher_b := private.ceo_encrypt_password_verifier(v_ver_a);
  perform pg_temp.t(octet_length(v_cipher_a) >= 48, 'ciphertext PGP AES-256 deve ter >= 48 bytes');
  perform pg_temp.t(v_cipher_a <> v_cipher_b, 'cifragem AES-256 PGP deve ser probabilística (salts S2K distintos)');
  perform pg_temp.t(
    private.ceo_constant_time_eq_hex(private.ceo_decrypt_password_verifier_hex(v_cipher_a), v_ver_a),
    'decifragem AES-256 deve recuperar exatamente o verificador original'
  );

  -- 3. Inspeção de Gate: bloqueia intruso + canário WORM; aprova wagneroliveira2395@gmail.com
  select count(*) into v_canaries_before
    from private.founder_audit_log
   where is_intrusion_canary is true;

  v_res := public.ceo_edge_inspect_vault_gate('intruso@atacante.com', v_dev_ok, v_ip_hash);
  perform pg_temp.t((v_res ->> 'ok')::boolean = false, 'intruso deve receber ok=false no inspect_gate');
  perform pg_temp.t((v_res ->> 'error_code') = 'ERR_MONOCRATIC_OWNER_ONLY_42501', 'intruso deve receber ERR_MONOCRATIC_OWNER_ONLY_42501');

  select count(*) into v_canaries_after
    from private.founder_audit_log
   where is_intrusion_canary is true;
  perform pg_temp.t(v_canaries_after = v_canaries_before + 1, 'inspect_gate de intruso deve gravar INTRUSION_CANARY');

  v_res := public.ceo_edge_inspect_vault_gate('  WagnerOliveira2395@gmail.com ', v_dev_ok, v_ip_hash);
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'titular canônico deve receber ok=true');
  perform pg_temp.t((v_res ->> 'password_configured')::boolean = false, 'estado inicial deve reportar password_configured=false');

  -- 4. Cerimônia de Primeiro Acesso: OTP 6d -> Ticket -> Criação da Senha Mestra Forte v1
  v_res := public.ceo_edge_issue_bootstrap_otp(v_ceo_uid, v_dev_ok, v_ip_hash, '482915');
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'emissão do OTP de primeiro acesso deve aprovar');
  v_ch_id := (v_res ->> 'challenge_id')::uuid;

  v_res := public.ceo_edge_verify_bootstrap_otp(v_ceo_uid, v_ch_id, '482915', v_dev_ok);
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'validação do OTP de primeiro acesso deve aprovar');
  v_ticket := v_res ->> 'enrollment_ticket';
  perform pg_temp.t(length(v_ticket) = 64, 'enrollment_ticket deve ter 64 chars hex');

  v_res := public.ceo_edge_set_initial_master_password(
    v_ceo_uid,
    v_ticket,
    v_ek_v1,
    v_dev_ok,
    'Moto G · Wagner CEO'
  );
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'gravação da Senha Mestra v1 deve aprovar');
  perform pg_temp.t((v_res ->> 'password_version')::integer = 1, 'password_version inicial deve ser 1');
  v_stepup_v1 := v_res ->> 'stepup_token';

  -- Selagem irreversível do bootstrap após password_configured = true
  delete from private.ceo_rate_limits;
  v_res := public.ceo_edge_issue_bootstrap_otp(v_ceo_uid, v_dev_ok, v_ip_hash, '111222');
  perform pg_temp.t((v_res ->> 'error_code') = 'ERR_VAULT_ALREADY_SEALED', 'bootstrap deve ficar permanentemente selado após criação da senha');

  -- 5. Anti-Inbox-Bombing + Lockout Progressivo em tentativas de senha incorreta
  for i in 1..3 loop
    v_res := public.ceo_edge_verify_password_and_issue_login_otp(v_ceo_uid, v_ek_wrong, v_dev_ok, v_ip_hash, '333444', false);
    perform pg_temp.t((v_res ->> 'error_code') = 'ERR_INVALID_MASTER_PASSWORD', 'tentativas 1..3 incorretas retornam ERR_INVALID_MASTER_PASSWORD');
  end loop;

  select count(*)::integer into v_login_ch_cnt
    from private.ceo_security_challenges
   where purpose = 'LOGIN_2FA';
  perform pg_temp.t(v_login_ch_cnt = 0, 'nenhum desafio/e-mail LOGIN_2FA pode ser emitido quando a senha está incorreta');

  -- 4ª falha -> lockout 60s
  v_res := public.ceo_edge_verify_password_and_issue_login_otp(v_ceo_uid, v_ek_wrong, v_dev_ok, v_ip_hash, '333444', false);
  perform pg_temp.t((v_res ->> 'error_code') = 'ERR_VAULT_LOCKED_BACKOFF', '4ª falha consecutiva deve ativar lockout de 60s');

  -- Simula avanço do relógio após lockout de 60s -> 5ª falha dispara alerta de segurança + 5 min
  update private.ceo_sovereign_vault set locked_until = now() - interval '1 second' where singleton_id = true;
  v_res := public.ceo_edge_verify_password_and_issue_login_otp(v_ceo_uid, v_ek_wrong, v_dev_ok, v_ip_hash, '333444', false);
  perform pg_temp.t((v_res ->> 'send_lockout_security_alert')::boolean = true, '5ª falha deve sinalizar alerta de segurança ao e-mail do CEO');

  -- Simula avanço após 5 min -> Login Diário 2FA completo com a senha correta zera contador
  update private.ceo_sovereign_vault set locked_until = now() - interval '1 second' where singleton_id = true;
  delete from private.ceo_rate_limits;

  v_res := public.ceo_edge_verify_password_and_issue_login_otp(v_ceo_uid, v_ek_v1, v_dev_ok, v_ip_hash, '759204', false);
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'senha mestra correta deve emitir desafio LOGIN_2FA');
  v_ch_id := (v_res ->> 'challenge_id')::uuid;

  v_res := public.ceo_edge_complete_login_2fa(v_ceo_uid, v_ch_id, '759204', v_dev_ok, 'Moto G · Wagner CEO');
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, '2º fator 6d correto deve concluir login soberano');
  v_stepup_login := v_res ->> 'stepup_token';

  -- Verifica Snapshot Real funcionando com a sessão recém-emitida
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', v_ceo_uid::text,
      'role', 'authenticated',
      'email', 'wagneroliveira2395@gmail.com'
    )::text,
    true
  );
  v_snap := public.ceo_get_live_cockpit_snapshot(v_stepup_login, v_dev_ok, '30d');
  perform set_config('transaction_read_only', 'off', true);
  perform pg_temp.t((v_snap -> 'vault_metadata' ->> 'owner_email') = 'wagneroliveira2395@gmail.com', 'snapshot deve carregar telemetria real para sessão v1 válida');

  -- 6. Cerimônia de Perfil: 1º E-mail (OTP 6d) -> 2º E-mail (Deep-Link idempotente no GET + Device-Bound no POST)
  delete from private.ceo_rate_limits;
  v_res := public.ceo_edge_request_profile_password_change_otp(v_ceo_uid, v_stepup_login, v_dev_ok, v_ip_hash, '618390');
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'solicitação de troca de senha no perfil deve emitir 1º OTP 6d');
  v_ch_id := (v_res ->> 'challenge_id')::uuid;

  v_res := public.ceo_edge_verify_profile_otp_and_issue_reset_link(
    v_ceo_uid,
    v_stepup_login,
    v_dev_ok,
    v_ch_id,
    '618390',
    v_grant_a
  );
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'validação do OTP do perfil deve autorizar link efêmero do 2º e-mail');
  v_link_id_a := (v_res ->> 'link_id')::uuid;

  -- Ponte GET chamada 3x seguidas (robô Gmail + antivírus + clique real) NÃO consome o link!
  for i in 1..3 loop
    v_res := public.ceo_edge_inspect_reset_link_bridge(v_link_id_a, v_grant_a);
    perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'GET bridge deve ser 100% idempotente sem queimar o link');
  end loop;

  -- Tentativa de reutilizar a mesma senha atual -> ERR_PASSWORD_REUSE_FORBIDDEN (sem queimar o link)
  v_res := public.ceo_edge_commit_password_reset_from_link(v_ceo_uid, v_link_id_a, v_grant_a, v_ek_v1, v_dev_ok, 'Moto G · Wagner CEO');
  perform pg_temp.t((v_res ->> 'error_code') = 'ERR_PASSWORD_REUSE_FORBIDDEN', 'histórico deve bloquear reutilização da senha atual');

  -- Tentativa de usar o link interceptado em OUTRO aparelho -> bloqueado + revoga o link + canário!
  v_res := public.ceo_edge_commit_password_reset_from_link(v_ceo_uid, v_link_id_a, v_grant_a, v_ek_v2, v_dev_attacker, 'Aparelho Invasor');
  perform pg_temp.t((v_res ->> 'error_code') = 'ERR_RESET_LINK_DEVICE_MISMATCH', 'link aberto em outro aparelho deve ser sumariamente bloqueado');

  -- Emite novo link legítimo no aparelho do CEO e efetiva a Nova Senha Mestra Forte (password_version = 2)
  delete from private.ceo_rate_limits;
  v_res := public.ceo_edge_request_profile_password_change_otp(v_ceo_uid, v_stepup_login, v_dev_ok, v_ip_hash, '940271');
  v_ch_id := (v_res ->> 'challenge_id')::uuid;
  v_res := public.ceo_edge_verify_profile_otp_and_issue_reset_link(v_ceo_uid, v_stepup_login, v_dev_ok, v_ch_id, '940271', v_grant_b);
  v_link_id_b := (v_res ->> 'link_id')::uuid;

  v_res := public.ceo_edge_commit_password_reset_from_link(
    v_ceo_uid,
    v_link_id_b,
    v_grant_b,
    v_ek_v2,
    v_dev_ok,
    'Moto G · Wagner CEO'
  );
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'efetivação da nova Senha Mestra Forte deve aprovar');
  perform pg_temp.t((v_res ->> 'password_version')::integer = 2, 'password_version deve incrementar para 2');
  perform pg_temp.t((v_res ->> 'require_full_relogin')::boolean = true, 'deve exigir novo login completo após troca de senha');

  -- Confirma que a sessão anterior (`v_stepup_login`) foi instantaneamente invalidada!
  begin
    perform public.ceo_get_live_cockpit_snapshot(v_stepup_login, v_dev_ok, 30);
    v_revoked_err := false;
  exception when insufficient_privilege then
    v_revoked_err := true;
  end;
  perform pg_temp.t(v_revoked_err = true, 'sessão anterior deve ser rejeitada com 42501 imediatamente após rotação de senha');

  perform pg_temp.t(private.verify_founder_audit_chain(), 'cadeia forense WORM SHA-256 deve permanecer 100% íntegra');
end;
$smoke$;

rollback;

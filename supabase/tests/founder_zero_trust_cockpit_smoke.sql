-- =============================================================================
-- DESPERRENGUE — Suíte SQL Zero-Trust: Founder Sovereign Cockpit & War Room
-- Migration alvo: 20261114100000_founder_sovereign_cockpit_zero_trust.sql (v2.12.0)
--
-- Executa integralmente dentro de UMA transação abortada no final (ROLLBACK):
-- nada é persistido no banco. O relatório completo sai na mensagem da exceção:
--
--   supabase db query --linked -f supabase/tests/founder_zero_trust_cockpit_smoke.sql
--
-- Cobertura de Invariantes Zero-Trust & Contábeis:
--   01..04 Barreira `anon` e isolamento total de `private.*` + Intrusion Canary
--   05..06 Bootstrap único `SOVEREIGN_CEO` + `uq_single_sovereign_ceo`
--   07..09 Backoff exponencial de Master PIN, SHA-256 em repouso e anti-IDOR
--   10..13 Autorização de 3 delegados + Trava Física de Kernel (4º bloqueado `P0001`)
--   14..17 RBAC de ações estratégicas, Kill-Switch imediato de sessão, expiração e AAL2
--   18     Demografia exata de 4 grupos + expurgos LGPD por escopo (`client`/`provider`/`all`)
--   19     DRE CPC 47 / IFRS 15 100% BIGINT em centavos + Lei de Conservação Monetária
--   20     Reconciliação de 3 Vias (`discrepancy_cents = 0` e detecção exata de `1` centavo)
--   21..24 Custódia `FROZEN_UNDER_DURESS`, SEFAZ > 26h, 33 categorias, redaction por escopo,
--          índices `INCLUDE`, `transaction_read_only = on` e cadeia SHA-256 imutável
-- =============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$
  insert into pg_temp.res (ok, name) values (coalesce(p_ok, false), p_name);
$$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', u, 'role', 'authenticated', 'aal', 'aal1')::text,
    true
  );
  execute 'set local role authenticated';
end $$;

create function pg_temp.login_aal2(u uuid) returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', u, 'role', 'authenticated', 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';
end $$;

create function pg_temp.try(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;

-- Executa `founder_get_cockpit_snapshot` preservando `SET LOCAL transaction_read_only = on`
-- dentro de uma subtransação isolada (emulando uma chamada HTTP RPC PostgREST independente)
-- para que o bloco `DO $$` externo possa continuar gravando resultados em `pg_temp.res`.
create function pg_temp.call_snapshot(
  p_uid uuid,
  p_token text,
  p_days int default 30,
  p_aal text default 'aal1'
) returns jsonb language plpgsql as $$
declare
  v_out jsonb;
begin
  begin
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', p_uid, 'role', 'authenticated', 'aal', p_aal)::text,
      true
    );
    execute 'set local role authenticated';
    v_out := public.founder_get_cockpit_snapshot(p_token, p_days);
    raise exception 'SNAPSHOT_SUBTX_RELEASE_RO' using errcode = 'P9998';
  exception when sqlstate 'P9998' then
    reset role;
  end;
  return v_out;
end $$;

-- Gera chave NF-e/NFC-e de 44 dígitos com DV Módulo 11 matematicamente válido
create function pg_temp.make_nfe_key(p_nnf9 text, p_mod text default '65') returns text
language plpgsql immutable as $$
declare
  v_base   text := '35' || '2611' || '11222333000181' || p_mod || '001' || lpad(p_nnf9, 9, '0') || '1' || '12345678';
  v_weight int := 2;
  v_sum    int := 0;
  v_rem    int;
  v_dv     int;
  i        int;
begin
  for i in reverse 43..1 loop
    v_sum := v_sum + (substr(v_base, i, 1)::int * v_weight);
    v_weight := case when v_weight = 9 then 2 else v_weight + 1 end;
  end loop;
  v_rem := v_sum % 11;
  v_dv := case when v_rem in (0, 1) then 0 else 11 - v_rem end;
  return v_base || v_dv::text;
end $$;

do $$
declare
  ids                  uuid[];
  v_existing_profiles  int;
  v_total_profiles     int;
  u_ceo                uuid;
  u_del1               uuid;
  u_del2               uuid;
  u_del3               uuid;
  u_del4               uuid;
  u_prov2              uuid;
  u_rej                uuid;
  u_intruder           uuid;
  v_email_ceo          text;
  v_email_del1         text;
  v_email_del2         text;
  v_email_del3         text;
  v_email_del4         text;
  v_err                text;
  v_err2               text;
  v_res                jsonb;
  v_res2               jsonb;
  v_res3               jsonb;
  v_ceo_token          text;
  v_del1_token         text;
  v_del2_token         text;
  v_del3_token         text;
  v_del4_token         text;
  v_topup              jsonb;
  v_job_split          uuid;
  v_quote_split        uuid;
  v_pin_split          text;
  v_nfe_key1           text;
  v_nfe_key2           text;
  v_doc_split          uuid;
  v_job_duress         uuid;
  v_snap_ceo           jsonb;
  v_snap_ro            jsonb;
  v_snap_tax           jsonb;
  v_snap_bad           jsonb;
  v_ok_p1              boolean := false;
  v_ok_p2              boolean := false;
  v_ok_p3              boolean := false;
  v_audit_before       int;
  v_audit_after        int;
  v_idx_count          int;
  v_report             text;
  c_lat0      constant double precision := -21.787800;
  c_lng0      constant double precision := -46.561200;
  c_phash_in  constant bigint := -9223372036854775808; -- 0x8000000000000000
  c_phash_out constant bigint :=  9223372036854775807; -- 0x7FFFFFFFFFFFFFFF
  c_phash_nfe constant bigint :=  1229782938247303441; -- 0x1111111111111111
begin
  -- Garante >= 8 atores na transação de fumaça (reaproveita contas ou semeia faltantes)
  select count(*)::int into v_existing_profiles from public.profiles;
  if v_existing_profiles < 8 then
    insert into auth.users (id, email, raw_user_meta_data)
    select gen_random_uuid(),
           'founder_actor_' || g || '@smoke.desperrengue.local',
           jsonb_build_object('full_name', 'Founder Smoke Actor ' || g)
      from generate_series(v_existing_profiles + 1, 8) g;
  end if;

  select array_agg(p.id order by p.created_at asc, p.id asc),
         count(*)::int
    into ids, v_total_profiles
    from public.profiles p;

  u_ceo      := ids[1];
  u_del1     := ids[2];
  u_del2     := ids[3];
  u_del3     := ids[4];
  u_del4     := ids[5];
  u_prov2    := ids[6];
  u_rej      := ids[7];
  u_intruder := ids[8];

  -- Normaliza e-mails em auth.users para resolução determinística case-insensitive
  update auth.users set email = 'ceo.sovereign@smoke.desperrengue.local', deleted_at = null where id = u_ceo;
  update auth.users set email = 'delegate.analytics@smoke.desperrengue.local', deleted_at = null where id = u_del1;
  update auth.users set email = 'delegate.tax@smoke.desperrengue.local', deleted_at = null where id = u_del2;
  update auth.users set email = 'delegate.ops@smoke.desperrengue.local', deleted_at = null where id = u_del3;
  update auth.users set email = 'delegate.fourth@smoke.desperrengue.local', deleted_at = null where id = u_del4;
  update auth.users set email = 'provider.two@smoke.desperrengue.local', deleted_at = null where id = u_prov2;
  update auth.users set email = 'client.rejected@smoke.desperrengue.local', deleted_at = null where id = u_rej;
  update auth.users set email = 'intruder.outsider@smoke.desperrengue.local', deleted_at = null where id = u_intruder;

  v_email_ceo  := 'ceo.sovereign@smoke.desperrengue.local';
  v_email_del1 := 'delegate.analytics@smoke.desperrengue.local';
  v_email_del2 := 'delegate.tax@smoke.desperrengue.local';
  v_email_del3 := 'delegate.ops@smoke.desperrengue.local';
  v_email_del4 := 'delegate.fourth@smoke.desperrengue.local';

  -- Limpa estado transacional para asserções aritméticas 100% determinísticas
  delete from private.founder_stepup_sessions;
  delete from private.founder_sovereign_acl;
  delete from public.job_mediations;
  delete from public.job_fiscal_documents;
  delete from public.escrow_maturation_entries;
  delete from public.warranty_pool_ledger;
  delete from public.payments;
  delete from public.quotes;
  delete from public.jobs;
  delete from public.pix_topups;
  delete from public.wallet_statement;
  delete from public.ledger_lines;
  delete from public.ledger_txns;
  delete from public.client_wallets;
  delete from public.account_deletion_log;
  delete from public.provider_profiles;

  insert into public.app_settings (key, value) values ('pix_sandbox', 'true')
    on conflict (key) do update set value = 'true';

  -- Demografia determinística de 4 grupos:
  --   Dual-Mode (Cliente + Profissional) = 2 (u_ceo, u_del3)
  --   Exclusivamente Clientes            = 3 (u_del1, u_del4, u_rej)
  --   Exclusivamente Profissionais       = 2 (u_del2, u_prov2)
  --   Sem modo (u_intruder + eventuais extras) -> total_users_count = v_total_profiles
  update public.profiles
     set role = null,
         is_client = false,
         is_provider = false,
         client_setup_done = false,
         provider_setup_done = false,
         verification_status = 'NOT_SUBMITTED',
         client_kyc_status = 'NOT_STARTED',
         kyc_biometric_verified = false,
         ocr_verified = false,
         kyc_serpro_similarity = null,
         available_wallet_balance = 0,
         maturing_wallet_balance = 0,
         clawback_debt_balance = 0;

  -- Dual-mode (2): u_ceo (admin + ACTIVE) e u_del3 (ACTIVE + Tier-0 OCR)
  update public.profiles
     set role = 'admin',
         is_client = true,
         is_provider = true,
         client_setup_done = true,
         provider_setup_done = true,
         verification_status = 'ACTIVE',
         client_kyc_status = 'APPROVED',
         kyc_biometric_verified = true
   where id = u_ceo;

  update public.profiles
     set is_client = true,
         is_provider = true,
         client_setup_done = true,
         provider_setup_done = true,
         verification_status = 'ACTIVE',
         client_kyc_status = 'APPROVED',
         ocr_verified = true,
         kyc_serpro_similarity = null
   where id = u_del3;

  -- Exclusivamente Clientes (3): u_del1 (APPROVED + Tier-0 OCR), u_del4 (PENDING_REVIEW), u_rej (REJECTED)
  update public.profiles
     set is_client = true,
         client_setup_done = true,
         client_kyc_status = 'APPROVED',
         ocr_verified = true,
         kyc_serpro_similarity = null
   where id = u_del1;

  update public.profiles
     set is_client = true,
         client_setup_done = true,
         client_kyc_status = 'PENDING_REVIEW'
   where id = u_del4;

  update public.profiles
     set is_client = true,
         client_setup_done = true,
         client_kyc_status = 'REJECTED'
   where id = u_rej;

  -- Exclusivamente Profissionais (2): u_del2 (ACTIVE, STANDARD D+5) e u_prov2 (PENDING)
  update public.profiles
     set is_provider = true,
         provider_setup_done = true,
         verification_status = 'ACTIVE',
         trust_tier = 'STANDARD'
   where id = u_del2;

  update public.profiles
     set is_provider = true,
         provider_setup_done = true,
         verification_status = 'PENDING'
   where id = u_prov2;

  insert into public.provider_profiles (user_id, specialties, visit_fee, accepting_jobs)
  values
    (u_ceo,  array['Elétrica', 'Ar-condicionado'], 40, true),
    (u_del2, array['Elétrica', 'Encanador'], 35, true),
    (u_del3, array['Pintura', 'Marcenaria'], 45, true);

  -- Semeia histórico auditável de expurgos LGPD por escopo (2 client, 1 provider, 3 all)
  insert into public.account_deletion_log (user_hash, was_client, was_provider, jobs_deleted, jobs_retained, scope)
  values
    (repeat('1', 64), true,  true,  1, 0, 'client'),
    (repeat('2', 64), true,  true,  2, 0, 'client'),
    (repeat('3', 64), true,  true,  0, 1, 'provider'),
    (repeat('4', 64), true,  false, 1, 1, 'all'),
    (repeat('5', 64), false, true,  0, 0, 'all'),
    (repeat('6', 64), true,  true,  2, 1, 'all');

  -- ---------------------------------------------------------------------------
  -- 01. Barreira Zero-Trust `anon` (`42501` em tabelas `private.*` e TODAS as RPCs)
  -- ---------------------------------------------------------------------------
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
  perform pg_temp.t(
    starts_with(pg_temp.try('select 1 from private.founder_sovereign_acl limit 1'), '42501')
    and starts_with(pg_temp.try('select 1 from private.founder_stepup_sessions limit 1'), '42501')
    and starts_with(pg_temp.try('select 1 from private.founder_audit_log limit 1'), '42501')
    and starts_with(pg_temp.try('select public.founder_bootstrap_sovereign_ceo(''Sovereign#2026'')'), '42501')
    and starts_with(pg_temp.try('select public.founder_unlock_stepup_session(''Sovereign#2026'')'), '42501')
    and starts_with(pg_temp.try('select public.founder_report_security_canary(''PROBE'', ''{}''::jsonb)'), '42501')
    and starts_with(pg_temp.try('select public.founder_authorize_delegate(repeat(''a'', 64), ''a@b.c'', ''READ_ONLY_ANALYTICS'', ''123456'', null)'), '42501')
    and starts_with(pg_temp.try(format('select public.founder_revoke_delegate(repeat(''a'', 64), %L)', u_del1)), '42501')
    and starts_with(pg_temp.try('select public.founder_execute_strategic_action(repeat(''a'', 64), ''TEST'', ''{}''::jsonb)'), '42501')
    and starts_with(pg_temp.try('select public.founder_get_cockpit_snapshot(repeat(''a'', 64), 30)'), '42501'),
    'anon recebe 42501 em private.founder_* e em todas as 7 RPCs public.founder_*'
  );
  reset role;

  -- ---------------------------------------------------------------------------
  -- 02. Isolamento do schema `private` e funções internas contra `authenticated` (`42501`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  perform pg_temp.t(
    starts_with(pg_temp.try('select * from private.founder_sovereign_acl'), '42501')
    and starts_with(pg_temp.try('select * from private.founder_stepup_sessions'), '42501')
    and starts_with(pg_temp.try('select * from private.founder_audit_log'), '42501')
    and starts_with(pg_temp.try('select private.validate_founder_stepup_session(repeat(''a'', 64))'), '42501')
    and starts_with(pg_temp.try('select private.verify_founder_audit_chain()'), '42501'),
    'authenticated (mesmo admin) recebe 42501 ao consultar tabelas ou funções internas do schema private'
  );
  reset role;

  -- ---------------------------------------------------------------------------
  -- 03. Não-admin proibido de executar `founder_bootstrap_sovereign_ceo` (`42501`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_intruder);
  v_err := pg_temp.try('select public.founder_bootstrap_sovereign_ceo(''Intruder#2026'')');
  reset role;

  perform pg_temp.login(u_del1);
  v_err2 := pg_temp.try('select public.founder_bootstrap_sovereign_ceo(''Client#2026'')');
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_FORBIDDEN_BOOTSTRAP' in v_err) > 0
    and starts_with(v_err2, '42501:'),
    'usuários não-admin são bloqueados em founder_bootstrap_sovereign_ceo com 42501 (ERR_FORBIDDEN_BOOTSTRAP)'
  );

  -- ---------------------------------------------------------------------------
  -- 04. Chamador fora da ACL rejeitado com `42501` + Intrusion Canary persistente
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_intruder);
  v_err := pg_temp.try('select public.founder_unlock_stepup_session(''123456'')');
  v_res := public.founder_report_security_canary(
    'VAULT_UNAUTHORIZED_UNLOCK',
    jsonb_build_object('surface', 'vault_screen')
  );
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_FOUNDER_UNAUTHORIZED' in v_err) > 0
    and (v_res ->> 'ok')::boolean = true
    and (v_res ->> 'canary_logged')::boolean = true
    and char_length(v_res ->> 'row_hash') = 64
    and exists (
      select 1 from private.founder_audit_log fal
       where fal.actor_user_id = u_intruder
         and fal.is_intrusion_canary = true
         and fal.row_hash = (v_res ->> 'row_hash')
    ),
    'estranho recebe 42501 em founder_unlock_stepup_session e canário silencioso persiste com selo SHA-256'
  );

  -- ---------------------------------------------------------------------------
  -- 05. Bootstrap CEO valida PIN >= 6 chars (`22023`) e grava Blowfish (`bf/10`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  v_err := pg_temp.try('select public.founder_bootstrap_sovereign_ceo(''12345'')');
  v_res := public.founder_bootstrap_sovereign_ceo('CeoSovereign#2026');
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '22023:')
    and (v_res ->> 'ok')::boolean = true
    and (v_res ->> 'seat_role') = 'SOVEREIGN_CEO'
    and (v_res ->> 'permission_scope') = 'FULL_SOVEREIGN'
    and exists (
      select 1 from private.founder_sovereign_acl acl
       where acl.user_id = u_ceo
         and acl.seat_role = 'SOVEREIGN_CEO'
         and acl.permission_scope = 'FULL_SOVEREIGN'
         and acl.is_active = true
         and acl.expires_at is null
         and acl.master_pin_hash like '$2%'
         and acl.master_pin_hash <> 'CeoSovereign#2026'
    ),
    'admin inicializa SOVEREIGN_CEO vitalício (PIN curto < 6 chars falha 22023; Blowfish bf/10 sem texto puro)'
  );

  -- ---------------------------------------------------------------------------
  -- 06. Invariante Física 1: Assento Único `SOVEREIGN_CEO` (`P0001` + `uq_single_sovereign_ceo`)
  -- ---------------------------------------------------------------------------
  update public.profiles set role = 'admin' where id = u_prov2;
  perform pg_temp.login(u_prov2);
  v_err := pg_temp.try('select public.founder_bootstrap_sovereign_ceo(''SecondCeo#2026'')');
  reset role;
  update public.profiles set role = null where id = u_prov2;

  v_err2 := pg_temp.try(format(
    'insert into private.founder_sovereign_acl (user_id, email_snapshot, seat_role, permission_scope, master_pin_hash, is_active) '
    || 'values (%L, %L, ''SOVEREIGN_CEO'', ''FULL_SOVEREIGN'', ''$2a$10$dummyhashvalue00000000000000000000000000000000'', true)',
    u_prov2, 'second@smoke.local'
  ));

  perform pg_temp.t(
    starts_with(v_err, 'P0001:')
    and position('ERR_SOVEREIGN_CEO_ALREADY_BOOTSTRAPPED' in v_err) > 0
    and starts_with(v_err2, '23505:'),
    '2º bootstrap SOVEREIGN_CEO falha com P0001 e INSERT direto falha com 23505 (uq_single_sovereign_ceo)'
  );

  -- ---------------------------------------------------------------------------
  -- 07. Backoff Exponencial em falhas de Master PIN (persistido em PostgreSQL)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  v_res  := public.founder_unlock_stepup_session('WrongPin#1');
  v_res2 := public.founder_unlock_stepup_session('WrongPin#2');
  v_res3 := public.founder_unlock_stepup_session('WrongPin#3');
  -- Mesmo digitando o PIN CORRETO durante a janela de lockout, o cofre permanece travado!
  v_snap_bad := public.founder_unlock_stepup_session('CeoSovereign#2026');
  reset role;

  perform pg_temp.t(
    (v_res ->> 'ok')::boolean = false
    and (v_res ->> 'error_code') = 'ERR_INVALID_MASTER_PIN'
    and (v_res2 ->> 'failed_attempts')::int = 2
    and (v_res3 ->> 'ok')::boolean = false
    and (v_res3 ->> 'error_code') = 'ERR_STEPUP_LOCKED_BACKOFF'
    and (v_res3 ->> 'failed_attempts')::int = 3
    and (v_res3 ->> 'locked_until') is not null
    and (v_snap_bad ->> 'ok')::boolean = false
    and (v_snap_bad ->> 'error_code') = 'ERR_STEPUP_LOCKED_BACKOFF',
    '3 tentativas incorretas de PIN comitam backoff exponencial (locked_until) e bloqueiam até mesmo o PIN válido'
  );

  -- ---------------------------------------------------------------------------
  -- 08. Desbloqueio de Step-Up após expiração do lockout (apenas hash SHA-256 em repouso)
  -- ---------------------------------------------------------------------------
  update private.founder_sovereign_acl
     set locked_until = now() - interval '1 second'
   where user_id = u_ceo;

  perform pg_temp.login(u_ceo);
  v_res := public.founder_unlock_stepup_session('CeoSovereign#2026');
  reset role;

  v_ceo_token := v_res ->> 'stepup_token';

  perform pg_temp.t(
    (v_res ->> 'ok')::boolean = true
    and char_length(v_ceo_token) = 64
    and v_ceo_token ~ '^[0-9a-f]{64}$'
    and exists (
      select 1 from private.founder_sovereign_acl acl
       where acl.user_id = u_ceo and acl.failed_attempts = 0 and acl.locked_until is null
    )
    and not exists (
      select 1 from private.founder_stepup_sessions fss
       where fss.session_token_hash = v_ceo_token
    )
    and exists (
      select 1 from private.founder_stepup_sessions fss
       where fss.user_id = u_ceo
         and fss.session_token_hash = encode(extensions.digest(convert_to(v_ceo_token, 'UTF8'), 'sha256'), 'hex')
    ),
    'PIN válido emite token 64-hex, zera failed_attempts e persiste apenas o hash SHA-256 em founder_stepup_sessions'
  );

  -- ---------------------------------------------------------------------------
  -- 09. Anti-IDOR de Sessão Step-Up (`42501` se outro usuário apresentar o token do CEO)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_intruder);
  v_err := pg_temp.try(format('select public.founder_get_cockpit_snapshot(%L, 30)', v_ceo_token));
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_STEPUP_SESSION_INVALID_OR_REVOKED' in v_err) > 0,
    'anti-IDOR: token step-up válido do CEO é rejeitado com 42501 quando apresentado por outro auth.uid()'
  );

  -- ---------------------------------------------------------------------------
  -- 10. Proibição de `FULL_SOVEREIGN` para delegados e auto-delegação do CEO
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  v_err := pg_temp.try(format(
    'select public.founder_authorize_delegate(%L, %L, ''FULL_SOVEREIGN'', ''DelPin#2026'', 30)',
    v_ceo_token, v_email_del1
  ));
  v_err2 := pg_temp.try(format(
    'select public.founder_authorize_delegate(%L, %L, ''READ_ONLY_ANALYTICS'', ''DelPin#2026'', 30)',
    v_ceo_token, v_email_ceo
  ));
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_DELEGATE_FORBIDDEN_FULL_SOVEREIGN' in v_err) > 0
    and starts_with(v_err2, 'P0001:')
    and position('ERR_CANNOT_DELEGATE_TO_SELF' in v_err2) > 0,
    'delegado jamais pode receber FULL_SOVEREIGN (42501) e CEO não ocupa vaga delegada consigo mesmo (P0001)'
  );

  -- ---------------------------------------------------------------------------
  -- 11. CEO autoriza Vagas 1/3, 2/3 e 3/3 (resolução de e-mail case-insensitive)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  v_res  := public.founder_authorize_delegate(v_ceo_token, upper(v_email_del1), 'READ_ONLY_ANALYTICS', 'DelOne#2026', 30);
  v_res2 := public.founder_authorize_delegate(v_ceo_token, v_email_del2, 'FINANCE_TAX_AUDITOR', 'DelTwo#2026', null);
  v_res3 := public.founder_authorize_delegate(v_ceo_token, '  ' || upper(v_email_del3) || '  ', 'OPERATIONS_SECURITY', 'DelThree#2026', 15);
  reset role;

  perform pg_temp.t(
    (v_res ->> 'ok')::boolean = true
    and (v_res ->> 'active_delegates_count')::int = 1
    and (v_res2 ->> 'active_delegates_count')::int = 2
    and (v_res3 ->> 'active_delegates_count')::int = 3,
    'CEO preenche Vaga 1 (READ_ONLY_ANALYTICS), Vaga 2 (FINANCE_TAX_AUDITOR) e Vaga 3 (OPERATIONS_SECURITY)'
  );

  -- ---------------------------------------------------------------------------
  -- 12. Invariante Física 2: Trava de Kernel de Máximo 3 Delegados (`ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_ceo);
  v_err := pg_temp.try(format(
    'select public.founder_authorize_delegate(%L, %L, ''READ_ONLY_ANALYTICS'', ''DelFour#2026'', 7)',
    v_ceo_token, v_email_del4
  ));
  reset role;

  v_err2 := pg_temp.try(format(
    'insert into private.founder_sovereign_acl (user_id, email_snapshot, seat_role, permission_scope, master_pin_hash, is_active) '
    || 'values (%L, %L, ''AUTHORIZED_DELEGATE'', ''READ_ONLY_ANALYTICS'', ''$2a$10$dummyhashvalue00000000000000000000000000000000'', true)',
    u_del4, v_email_del4
  ));

  perform pg_temp.t(
    starts_with(v_err, 'P0001:')
    and position('ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED' in v_err) > 0
    and starts_with(v_err2, 'P0001:')
    and position('ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED' in v_err2) > 0,
    '4º delegado bloqueado com P0001 (ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED) tanto via RPC quanto via trigger de kernel'
  );

  -- ---------------------------------------------------------------------------
  -- 13. Fronteiras de Privilégio dos Delegados (`42501` ao tentar delegar/revogar; CEO irrevogável)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_del1);
  v_del1_token := public.founder_unlock_stepup_session('DelOne#2026') ->> 'stepup_token';
  reset role;

  perform pg_temp.login(u_del2);
  v_del2_token := public.founder_unlock_stepup_session('DelTwo#2026') ->> 'stepup_token';
  reset role;

  perform pg_temp.login(u_del3);
  v_del3_token := public.founder_unlock_stepup_session('DelThree#2026') ->> 'stepup_token';
  v_err := pg_temp.try(format(
    'select public.founder_authorize_delegate(%L, %L, ''READ_ONLY_ANALYTICS'', ''SubDel#2026'', 7)',
    v_del3_token, v_email_del4
  ));
  v_err2 := pg_temp.try(format(
    'select public.founder_revoke_delegate(%L, %L)',
    v_del3_token, u_del1
  ));
  reset role;

  perform pg_temp.t(
    char_length(v_del1_token) = 64
    and char_length(v_del2_token) = 64
    and char_length(v_del3_token) = 64
    and starts_with(v_err, '42501:')
    and starts_with(v_err2, '42501:')
    and starts_with(pg_temp.try(format('select public.founder_revoke_delegate(%L, %L)', v_ceo_token, u_ceo)), '42501:'),
    'delegados não podem autorizar nem revogar assentos (42501) e SOVEREIGN_CEO é fisicamente irrevogável'
  );

  -- ---------------------------------------------------------------------------
  -- 14. RBAC em `founder_execute_strategic_action` (`FULL_SOVEREIGN` & `OPERATIONS_SECURITY` apenas)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_del1);
  v_err := pg_temp.try(format(
    'select public.founder_execute_strategic_action(%L, ''DISPATCH_SUPPLY_BOOSTER'', ''{"city":"Pocos"}''::jsonb)',
    v_del1_token
  ));
  reset role;

  perform pg_temp.login(u_del2);
  v_err2 := pg_temp.try(format(
    'select public.founder_execute_strategic_action(%L, ''DISPATCH_SUPPLY_BOOSTER'', ''{"city":"Pocos"}''::jsonb)',
    v_del2_token
  ));
  reset role;

  perform pg_temp.login(u_del3);
  v_res := public.founder_execute_strategic_action(
    v_del3_token,
    'DISPATCH_SUPPLY_BOOSTER',
    jsonb_build_object('neighborhood', 'Centro', 'budget_cents', 15000)
  );
  reset role;

  perform pg_temp.login(u_ceo);
  v_res2 := public.founder_execute_strategic_action(
    v_ceo_token,
    'EXPORT_CPC47_ACCOUNTANT_PACK',
    jsonb_build_object('competence', '2026-11')
  );
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and starts_with(v_err2, '42501:')
    and (v_res ->> 'ok')::boolean = true
    and (v_res2 ->> 'ok')::boolean = true
    and (v_res2 ->> 'prev_hash') = (v_res ->> 'row_hash'),
    'READ_ONLY e FINANCE_TAX recebem 42501 em ações estratégicas; OPERATIONS_SECURITY e CEO encadeiam prev_hash -> row_hash'
  );

  -- ---------------------------------------------------------------------------
  -- 15. Kill-Switch Imediato (`founder_revoke_delegate`) destrói sessão ativa e libera vaga
  -- ---------------------------------------------------------------------------
  v_snap_tax := pg_temp.call_snapshot(u_del2, v_del2_token, 30, 'aal1');

  perform pg_temp.login(u_ceo);
  v_res := public.founder_revoke_delegate(v_ceo_token, u_del2);
  reset role;

  perform pg_temp.login(u_del2);
  v_err := pg_temp.try(format('select public.founder_get_cockpit_snapshot(%L, 30)', v_del2_token));
  v_err2 := pg_temp.try('select public.founder_unlock_stepup_session(''DelTwo#2026'')');
  reset role;

  -- A Vaga 2 foi liberada: agora u_del4 é autorizado com sucesso como substituto!
  perform pg_temp.login(u_ceo);
  v_res2 := public.founder_authorize_delegate(v_ceo_token, v_email_del4, 'FINANCE_TAX_AUDITOR', 'DelFour#2026', 30);
  reset role;

  perform pg_temp.login(u_del4);
  v_del4_token := public.founder_unlock_stepup_session('DelFour#2026') ->> 'stepup_token';
  reset role;

  perform pg_temp.t(
    (v_snap_tax ->> 'viewer_permission_scope') = 'FINANCE_TAX_AUDITOR'
    and (v_res ->> 'ok')::boolean = true
    and (v_res ->> 'sessions_terminated')::int >= 1
    and (v_res ->> 'active_delegates_count')::int = 2
    and starts_with(v_err, '42501:')
    and starts_with(v_err2, '42501:')
    and (v_res2 ->> 'ok')::boolean = true
    and (v_res2 ->> 'active_delegates_count')::int = 3
    and char_length(v_del4_token) = 64,
    'Kill-Switch invalida sessão ativa da Vaga 2 no mesmo milissegundo (42501) e libera a vaga para novo delegado'
  );

  -- ---------------------------------------------------------------------------
  -- 16. Expiração temporal automática bloqueia acesso (`42501`) e recicla vaga expirada
  -- ---------------------------------------------------------------------------
  update private.founder_sovereign_acl
     set expires_at = now() - interval '1 minute'
   where user_id = u_del3;

  perform pg_temp.login(u_del3);
  v_err := pg_temp.try(format('select public.founder_get_cockpit_snapshot(%L, 30)', v_del3_token));
  reset role;

  -- Re-autoriza u_del3 renovando o prazo para +15 dias sem estourar o teto de 3 delegados
  perform pg_temp.login(u_ceo);
  v_res := public.founder_authorize_delegate(v_ceo_token, v_email_del3, 'OPERATIONS_SECURITY', 'DelThree#2026', 15);
  reset role;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and (v_res ->> 'ok')::boolean = true
    and (v_res ->> 'active_delegates_count')::int = 3,
    'delegação com expires_at vencido é bloqueada imediatamente (42501) e reciclada sem violar o teto de 3 vagas'
  );

  -- ---------------------------------------------------------------------------
  -- 17. Exigência criptográfica AAL2 opcional (`require_aal2 = TRUE`)
  -- ---------------------------------------------------------------------------
  update private.founder_sovereign_acl set require_aal2 = true where user_id = u_del4;

  perform pg_temp.login(u_del4);
  v_err := pg_temp.try(format('select public.founder_get_cockpit_snapshot(%L, 30)', v_del4_token));
  reset role;

  v_snap_tax := pg_temp.call_snapshot(u_del4, v_del4_token, 30, 'aal2');

  update private.founder_sovereign_acl set require_aal2 = false where user_id = u_del4;

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_AAL2_MFA_REQUIRED' in v_err) > 0
    and (v_snap_tax ->> 'viewer_permission_scope') = 'FINANCE_TAX_AUDITOR',
    'assento com require_aal2=true bloqueia JWT aal1 (42501:ERR_AAL2_MFA_REQUIRED) e autoriza JWT aal2'
  );

  -- ---------------------------------------------------------------------------
  -- 18 & 19. Pipeline Real Pix + Smart Split CPC 47 (100% BIGINT Centavos)
  --          Mão de obra R$ 200,00 (20000c) + Materiais R$ 100,00 (10000c) c/ NF-e SEFAZ
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(u_del1);
  v_topup := public.create_topup(50000, 'founder-smoke-topup-1');
  reset role;

  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  execute 'set local role service_role';
  perform public.confirm_topup(v_topup ->> 'txid', 50000, 'psp-founder-smoke-001');
  reset role;

  perform pg_temp.login(u_del1);
  insert into public.jobs (
    client_id, title, description, category, urgency, visibility,
    scheduled_for, address_summary, latitude, longitude
  ) values (
    u_del1,
    'Quadro bifásico residencial',
    'Substituição de disjuntores DIN com nota fiscal',
    'Elétrica',
    'scheduled',
    'direct',
    now(),
    'Centro, Poços de Caldas - MG',
    c_lat0,
    c_lng0
  ) returning id into v_job_split;

  insert into public.job_addresses (job_id, address_line, cep)
  values (v_job_split, 'Rua Assis Figueiredo, 1245', '37701-000');

  perform public.invite_providers(v_job_split, array[u_del2]);
  reset role;

  perform pg_temp.login(u_del2);
  insert into public.quotes (job_id, provider_id, price, estimated_hours, message)
  values (v_job_split, u_del2, 300.00, 2, 'Mão de obra R$ 200 + disjuntores R$ 100')
  returning id into v_quote_split;
  reset role;

  perform pg_temp.login(u_del1);
  perform public.accept_quote(v_quote_split);
  perform public.pay_job_mock(v_job_split, 'wallet');
  select pin into v_pin_split from public.job_secrets where job_id = v_job_split;
  reset role;

  update public.jobs
     set labor_amount = 200.00,
         materials_amount = 100.00,
         agreed_price = 300.00,
         escrow_status = 'LOCKED_100'
   where id = v_job_split;

  v_nfe_key1 := pg_temp.make_nfe_key('000777001', '65');

  perform pg_temp.login(u_del2);
  perform public.start_job(v_job_split, c_lat0 + 0.0002, c_lng0, 6.0, false);
  perform public.register_forensic_photo(v_job_split, 'check_in', c_phash_in, 'evidence/' || v_job_split || '/in.jpg');
  perform public.register_forensic_photo(v_job_split, 'check_out', c_phash_out, 'evidence/' || v_job_split || '/out.jpg');
  v_res := public.register_and_verify_material_fiscal_document(
    v_job_split,
    u_del2,
    'NFCE_65',
    'MANUAL_KEY',
    v_nfe_key1,
    '1',
    '',
    true,
    '',
    100.00,
    array['85362000'],
    0.0100,
    c_phash_nfe,
    100
  );
  v_doc_split := (v_res ->> 'document_id')::uuid;
  reset role;

  -- Oráculo SEFAZ confirma autorização cStat=100 antes da liquidação
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  execute 'set local role service_role';
  perform public.audit_sefaz_phase2_cancellation_and_clawback(v_doc_split, 100);
  reset role;

  perform pg_temp.login(u_del2);
  perform public.complete_job_and_schedule_escrow(v_job_split, u_del2, c_phash_out, 6.0, v_pin_split);
  reset role;

  -- Semeia também 1 OS em custódia congelada sob coação silenciosa (`FROZEN_UNDER_DURESS`)
  -- + 1 documento fiscal pendente na SEFAZ há > 26h para testar o painel War Room
  insert into public.jobs (
    client_id, provider_id, title, description, category, urgency, visibility,
    status, payment_status, escrow_status, address_summary,
    labor_amount, materials_amount, agreed_price
  ) values (
    u_ceo, u_del3,
    'Reparo emergencial portão eletrônico',
    'Motor travado na garagem',
    'Portões e Interfones',
    'emergency',
    'direct',
    'in_progress',
    'escrow',
    'LOCKED_100',
    'Country Club, Poços de Caldas - MG',
    350.00,
    100.00,
    450.00
  ) returning id into v_job_duress;

  v_nfe_key2 := pg_temp.make_nfe_key('000777002', '55');
  perform pg_temp.login(u_del3);
  v_res := public.register_and_verify_material_fiscal_document(
    v_job_duress,
    u_del3,
    'NFE_55',
    'MANUAL_KEY',
    v_nfe_key2,
    '1',
    '',
    true,
    '',
    100.00,
    array['85362000'],
    0.0100,
    987654321,
    100
  );
  reset role;

  update public.job_fiscal_documents
     set created_at = now() - interval '28 hours'
   where id = (v_res ->> 'document_id')::uuid;

  update public.jobs
     set status = 'awaiting_approval',
         escrow_status = 'FROZEN_UNDER_DURESS',
         created_at = now() - interval '5 minutes'
   where id = v_job_duress;

  -- Snapshot completo pelo SOVEREIGN_CEO
  select count(*)::int into v_audit_before from private.founder_audit_log;
  v_snap_ceo := pg_temp.call_snapshot(u_ceo, v_ceo_token, 30, 'aal1');
  select count(*)::int into v_audit_after from private.founder_audit_log;

  -- Asserção 18: Demografia exata de 4 grupos + LGPD por escopo
  perform pg_temp.t(
    (v_snap_ceo -> 'user_demographics' ->> 'only_clients_count')::int = 3
    and (v_snap_ceo -> 'user_demographics' ->> 'only_providers_count')::int = 2
    and (v_snap_ceo -> 'user_demographics' ->> 'dual_mode_both_count')::int = 2
    and (v_snap_ceo -> 'user_demographics' ->> 'total_users_count')::int = v_total_profiles
    and (v_snap_ceo -> 'user_demographics' ->> 'kyc_verified_count')::int = 4
    and (v_snap_ceo -> 'user_demographics' ->> 'kyc_pending_count')::int = 2
    and (v_snap_ceo -> 'user_demographics' ->> 'kyc_rejected_count')::int = 1
    and (v_snap_ceo -> 'user_demographics' ->> 'lgpd_deleted_client_count')::int = 2
    and (v_snap_ceo -> 'user_demographics' ->> 'lgpd_deleted_provider_count')::int = 1
    and (v_snap_ceo -> 'user_demographics' ->> 'lgpd_deleted_all_count')::int = 3,
    'user_demographics calcula exatamente 4 grupos (only_clients=3, only_providers=2, dual_mode=2, total) + LGPD (2/1/3)'
  );

  -- Asserção 19: DRE CPC 47 / IFRS 15 100% BIGINT em centavos + Conservação Monetária
  perform pg_temp.t(
    (v_snap_ceo -> 'financial_dre_cents' ->> 'completed_orders_count')::int = 1
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'gmv_total_cents')::bigint = 30000
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'labor_gross_cents')::bigint = 20000
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'materials_exempt_cents')::bigint = 10000
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'provider_net_labor_cents')::bigint = 17000
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'platform_gross_revenue_cents')::bigint = 2700
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'warranty_pool_carveout_cents')::bigint = 300
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'simples_nacional_tax_cents')::bigint = 162
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'gross_gmv_hypothetical_tax_cents')::bigint = 3399
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'tax_savings_bps')::int = 9523
    and (v_snap_ceo -> 'financial_dre_cents' ->> 'tier0_kyc_savings_cents')::bigint = 560
    and (
      (v_snap_ceo -> 'financial_dre_cents' ->> 'materials_exempt_cents')::bigint
      + (v_snap_ceo -> 'financial_dre_cents' ->> 'provider_net_labor_cents')::bigint
      + (v_snap_ceo -> 'financial_dre_cents' ->> 'platform_gross_revenue_cents')::bigint
      + (v_snap_ceo -> 'financial_dre_cents' ->> 'warranty_pool_carveout_cents')::bigint
    ) = (v_snap_ceo -> 'financial_dre_cents' ->> 'gmv_total_cents')::bigint,
    'financial_dre_cents (BIGINT): GMV=30000c, Isento=10000c, LíqMO=17000c, Fee=2700c, Pool=300c, DAS=162c vs 3399c (-95,23%)'
  );

  -- ---------------------------------------------------------------------------
  -- 20. Reconciliação de 3 Vias: `discrepancy_cents = 0` em equilíbrio e detecção
  --     imediata de `1` centavo em `client_wallets`, `pix_topups` e `ledger_lines`
  -- ---------------------------------------------------------------------------
  -- Subtransação A: perturbação de +1 centavo em `public.client_wallets`
  begin
    update public.client_wallets
       set available_cents = available_cents + 1
     where client_id = u_del1;

    perform pg_temp.login(u_ceo);
    v_snap_bad := public.founder_get_cockpit_snapshot(v_ceo_token, 30);
    reset role;

    v_ok_p1 := (
      (v_snap_bad -> 'three_way_reconciliation' ->> 'three_way_reconciliation_ok')::boolean = false
      and (v_snap_bad -> 'three_way_reconciliation' ->> 'discrepancy_cents')::bigint = 1
    );
    raise exception 'REVERT_WALLET_PERTURBATION' using errcode = 'P9999';
  exception when sqlstate 'P9999' then
    reset role;
  end;

  -- Subtransação B: perturbação de +1 centavo em `public.pix_topups`
  begin
    update public.pix_topups
       set amount_cents = amount_cents + 1
     where client_id = u_del1;

    perform pg_temp.login(u_ceo);
    v_snap_bad := public.founder_get_cockpit_snapshot(v_ceo_token, 30);
    reset role;

    v_ok_p2 := (
      (v_snap_bad -> 'three_way_reconciliation' ->> 'three_way_reconciliation_ok')::boolean = false
      and (v_snap_bad -> 'three_way_reconciliation' ->> 'discrepancy_cents')::bigint = 1
    );
    raise exception 'REVERT_TOPUP_PERTURBATION' using errcode = 'P9999';
  exception when sqlstate 'P9999' then
    reset role;
  end;

  -- Subtransação C: perturbação de +1 centavo em `public.ledger_lines`
  begin
    update public.ledger_lines
       set cents = cents + 1
     where id = (select min(ll.id) from public.ledger_lines ll where ll.cents > 0);

    perform pg_temp.login(u_ceo);
    v_snap_bad := public.founder_get_cockpit_snapshot(v_ceo_token, 30);
    reset role;

    v_ok_p3 := (
      (v_snap_bad -> 'three_way_reconciliation' ->> 'three_way_reconciliation_ok')::boolean = false
      and (v_snap_bad -> 'three_way_reconciliation' ->> 'discrepancy_cents')::bigint = 1
    );
    raise exception 'REVERT_LEDGER_PERTURBATION' using errcode = 'P9999';
  exception when sqlstate 'P9999' then
    reset role;
  end;

  perform pg_temp.t(
    (v_snap_ceo -> 'three_way_reconciliation' ->> 'three_way_reconciliation_ok')::boolean = true
    and (v_snap_ceo -> 'three_way_reconciliation' ->> 'discrepancy_cents')::bigint = 0
    and (v_snap_ceo -> 'three_way_reconciliation' ->> 'pix_topups_confirmed_cents')::bigint = 50000
    and v_ok_p1
    and v_ok_p2
    and v_ok_p3,
    'three_way_reconciliation fecha discrepancy_cents=0 e acusa discrepancy_cents=1 em desvios de 1 centavo nas 3 pernas'
  );

  -- ---------------------------------------------------------------------------
  -- 21. Tesouraria, `FROZEN_UNDER_DURESS`, SEFAZ > 26h, Fundo Garantidor e 33 Categorias
  -- ---------------------------------------------------------------------------
  perform pg_temp.t(
    jsonb_array_length(v_snap_ceo -> 'category_liquidity_matrix') = 33
    and jsonb_array_length(v_snap_ceo -> 'daily_time_series') = 30
    and jsonb_array_length(v_snap_ceo -> 'recent_orders_micro_pnl') = 2
    and (v_snap_ceo -> 'treasury_and_escrow_cents' ->> 'frozen_under_duress_cents')::bigint = 45000
    and (v_snap_ceo -> 'treasury_and_escrow_cents' ->> 'maturation_d7_cents')::bigint = 27000
    and (v_snap_ceo -> 'actuarial_warranty_pool' ->> 'running_balance_cents')::bigint >= 300
    and (v_snap_ceo -> 'security_and_sefaz_watch' ->> 'pending_sefaz_over_26h_count')::int = 1
    and (v_snap_ceo -> 'security_and_sefaz_watch' ->> 'frozen_under_duress_count')::int = 1
    and (v_snap_ceo -> 'security_and_sefaz_watch' ->> 'geo_privacy_leak_bps')::int = 0
    and (v_snap_ceo -> 'security_and_sefaz_watch' ->> 'intrusion_canaries_count')::int >= 2,
    'snapshot consolida 33 categorias, 30 dias, maturação D+7 (27000c), coação (45000c), SEFAZ > 26h e 0 bps geo-leak'
  );

  -- ---------------------------------------------------------------------------
  -- 22. Filtragem de Escopo Zero-Trust (`READ_ONLY_ANALYTICS` vs `FINANCE_TAX` vs `FULL_SOVEREIGN`)
  -- ---------------------------------------------------------------------------
  v_snap_ro  := pg_temp.call_snapshot(u_del1, v_del1_token, 30, 'aal1');
  v_snap_tax := pg_temp.call_snapshot(u_del4, v_del4_token, 30, 'aal1');

  perform pg_temp.t(
    -- READ_ONLY_ANALYTICS mascara e-mails, chaves NF-e e dossiê policial de coação
    position('***@' in (v_snap_ro -> 'sovereign_acl_seats' -> 'ceo_seat' ->> 'email_snapshot')) > 0
    and jsonb_array_length(v_snap_ro -> 'security_and_sefaz_watch' -> 'duress_incidents') = 0
    and left(v_snap_ro -> 'recent_orders_micro_pnl' -> 0 ->> 'nfe_access_key', 10) = '**********'
    -- FINANCE_TAX_AUDITOR vê chave NF-e completa de 44 dígitos, mas não vê dossiê de coação nem e-mails ACL
    and char_length(v_snap_tax -> 'recent_orders_micro_pnl' -> 0 ->> 'nfe_access_key') = 44
    and left(v_snap_tax -> 'recent_orders_micro_pnl' -> 0 ->> 'nfe_access_key', 2) = '35'
    and jsonb_array_length(v_snap_tax -> 'security_and_sefaz_watch' -> 'duress_incidents') = 0
    -- SOVEREIGN_CEO vê e-mails completos, chaves NF-e de 44 dígitos e dossiê de coação com selo SHA-256
    and (v_snap_ceo -> 'sovereign_acl_seats' -> 'ceo_seat' ->> 'email_snapshot') = v_email_ceo
    and jsonb_array_length(v_snap_ceo -> 'security_and_sefaz_watch' -> 'duress_incidents') = 1
    and char_length(v_snap_ceo -> 'security_and_sefaz_watch' -> 'duress_incidents' -> 0 ->> 'sha256_evidence_seal') = 64
    and char_length(v_snap_ceo -> 'security_and_sefaz_watch' -> 'duress_incidents' -> 0 ->> 'device_integrity_hash') = 64
    and jsonb_array_length(v_snap_ceo -> 'security_and_sefaz_watch' -> 'duress_incidents' -> 0 -> 'evidence_chain_hashes') = 2
    -- Conservação algébrica centavo-a-centavo no Micro-P&L (`OrderMicroPnlRecord.splitConservationOk`)
    and (
      (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'gmv_cents')::bigint
      = (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'labor_cents')::bigint
        + (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'materials_exempt_cents')::bigint
    )
    and (
      (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'labor_cents')::bigint
      = (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'provider_net_cents')::bigint
        + (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'platform_fee_cents')::bigint
        + (v_snap_ceo -> 'recent_orders_micro_pnl' -> 0 ->> 'pool_carveout_cents')::bigint
    )
    and (
      (v_snap_ceo -> 'recent_orders_micro_pnl' -> 1 ->> 'labor_cents')::bigint
      = (v_snap_ceo -> 'recent_orders_micro_pnl' -> 1 ->> 'provider_net_cents')::bigint
        + (v_snap_ceo -> 'recent_orders_micro_pnl' -> 1 ->> 'platform_fee_cents')::bigint
        + (v_snap_ceo -> 'recent_orders_micro_pnl' -> 1 ->> 'pool_carveout_cents')::bigint
    ),
    'filtragem de escopo e conservação Micro-P&L: READ_ONLY mascara PII; FINANCE_TAX vê NF-e 44d; CEO vê dossiê completo'
  );

  -- ---------------------------------------------------------------------------
  -- 23. Índices de Cobertura `INCLUDE` + Garantia Física `SET LOCAL transaction_read_only = on` (`25006`)
  -- ---------------------------------------------------------------------------
  select count(*)::int
    into v_idx_count
    from pg_indexes pi
   where pi.schemaname = 'public'
     and pi.indexname in (
       'idx_founder_jobs_cockpit_covering',
       'idx_founder_jobs_escrow_watch_covering',
       'idx_founder_escrow_maturation_covering',
       'idx_founder_warranty_pool_covering',
       'idx_founder_fiscal_docs_covering'
     )
     and pi.indexdef ilike '%INCLUDE%';

  -- Prova empírica: após invocar `founder_get_cockpit_snapshot` diretamente na subtransação,
  -- qualquer tentativa subsequente de mutação falha com `25006` (read_only_sql_transaction)
  v_err := 'NOT_TESTED';
  begin
    perform pg_temp.login(u_ceo);
    perform public.founder_get_cockpit_snapshot(v_ceo_token, 30);
    reset role;
    insert into public.app_settings (key, value) values ('ro_probe', '1');
  exception when others then
    v_err := sqlstate || ':' || sqlerrm;
    reset role;
  end;

  perform pg_temp.t(
    v_idx_count = 5
    and v_audit_after = v_audit_before
    and starts_with(v_err, '25006:'),
    'os 5 índices B-Tree INCLUDE existem e founder_get_cockpit_snapshot impõe SET LOCAL transaction_read_only=on (25006)'
  );

  -- ---------------------------------------------------------------------------
  -- 24. Imutabilidade Append-Only (`42501`) e Integridade Criptográfica SHA-256
  --     de `private.founder_audit_log`
  -- ---------------------------------------------------------------------------
  v_err  := pg_temp.try('update private.founder_audit_log set severity = ''INFO''');
  v_err2 := pg_temp.try('delete from private.founder_audit_log');

  perform pg_temp.t(
    starts_with(v_err, '42501:')
    and position('ERR_FOUNDER_AUDIT_IMMUTABLE' in v_err) > 0
    and starts_with(v_err2, '42501:')
    and position('ERR_FOUNDER_AUDIT_IMMUTABLE' in v_err2) > 0
    and private.verify_founder_audit_chain() = true
    and (v_snap_ceo -> 'security_and_sefaz_watch' ->> 'audit_chain_intact')::boolean = true,
    'private.founder_audit_log bloqueia UPDATE e DELETE com 42501 (até para superuser) e mantém cadeia SHA-256 íntegra'
  );

  -- ---------------------------------------------------------------------------
  -- Relatório consolidado
  -- ---------------------------------------------------------------------------
  select string_agg(
    (case when r2.ok then 'ok    ' else 'FAIL  ' end) || lpad(r2.n::text, 2, '0') || ' ' || r2.name,
    E'\n' order by r2.n
  ) into v_report
  from res r2;

  raise exception E'\n=== RELATÓRIO FOUNDER ZERO-TRUST COCKPIT ===\n%\n\nOK=%  FALHAS=%\n',
    v_report,
    (select count(*) from res r3 where r3.ok),
    (select count(*) from res r4 where not r4.ok);
end $$;

rollback;

-- =============================================================================
-- DESPERRENGUE — Limpeza Transacional Atômica do Marketplace (v2.34.0 — Refresh)
--
-- Objetivo:
--   Excluir 100% dos usuários cadastrados no aplicativo Desperrengue
--   (Clientes, Profissionais e contas incompletas/de teste), bem como todo o
--   histórico operacional do marketplace, preservando EXCLUSIVAMENTE o titular
--   soberano do Desperrengue CEO (`wagneroliveira2395@gmail.com`) e toda a
--   infraestrutura `private.ceo_*`, cadeia WORM `private.founder_audit_log`,
--   `private.geo_privacy_secrets` e `public.app_settings`.
-- =============================================================================

begin;

do $$
declare
  v_ceo_email            text := lower(btrim(private.ceo_owner_canonical_email()));
  v_vault_owner_uid      uuid;
  v_auth_ceo_uid         uuid;
  v_ceo_uid              uuid;
  v_had_ceo_user         boolean := false;
  v_pre_audit_cnt        bigint := 0;
  v_pre_expenses_cnt     bigint := 0;
  v_pre_devices_cnt      bigint := 0;
  v_pre_pw_hist_cnt      bigint := 0;
  v_pre_app_settings_cnt bigint := 0;
  v_remaining_mkt        bigint := 0;
  v_remaining_non_ceo    bigint := 0;
begin
  select sv.owner_user_id
    into v_vault_owner_uid
    from private.ceo_sovereign_vault sv
   where sv.singleton_id = true;

  select au.id
    into v_auth_ceo_uid
    from auth.users au
   where lower(btrim(coalesce(au.email, ''))) = v_ceo_email
     and au.deleted_at is null
   order by (case when au.id = v_vault_owner_uid then 0 else 1 end), au.created_at asc
   limit 1;

  v_ceo_uid := coalesce(v_vault_owner_uid, v_auth_ceo_uid);
  v_had_ceo_user := (v_ceo_uid is not null);

  select count(*) into v_pre_audit_cnt from private.founder_audit_log;
  select count(*) into v_pre_expenses_cnt from private.ceo_expense_entries;
  select count(*) into v_pre_devices_cnt from private.ceo_trusted_devices;
  select count(*) into v_pre_pw_hist_cnt from private.ceo_password_history;
  select count(*) into v_pre_app_settings_cnt from public.app_settings;

  -- 1. Storage do marketplace (mídia, KYC e forense)
  begin
    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects
     where bucket_id in (
       'public-media',
       'job-media',
       'kyc-documents',
       'kyc_documentos',
       'forensic-evidence'
     );
  exception when others then
    null;
  end;

  -- 2. Camada Forense, Garantia, Mediações, Documentos Fiscais e Evidências
  delete from private.job_forensic_secrets;
  delete from public.forensic_certificates;
  delete from public.warranty_pool_ledger;
  delete from public.escrow_maturation_entries;
  delete from public.job_mediations;
  delete from public.job_fiscal_documents;
  delete from public.provider_case_pins;
  delete from public.job_evidence;
  delete from public.job_invites;
  delete from public.job_secrets;
  delete from public.job_addresses;
  delete from public.job_geo;

  if to_regclass('public.duress_security_alerts') is not null then
    execute 'delete from public.duress_security_alerts';
  end if;

  -- 3. Mensagens, Avaliações, Suporte e Notificações
  delete from public.messages;
  delete from public.reviews;
  delete from public.support_tickets;
  delete from public.notifications;

  -- 4. Ledger, Carteiras, Pix, Pagamentos e Saques
  delete from public.ledger_lines;
  delete from public.ledger_txns;
  delete from public.wallet_statement;
  delete from public.pix_topups;
  delete from public.payments;
  delete from public.withdrawals;
  delete from public.client_wallets;

  -- 5. Pedidos e Orçamentos
  update public.jobs
     set accepted_quote_id = null,
         parent_job_id = null
   where accepted_quote_id is not null
      or parent_job_id is not null;

  delete from public.quotes;
  delete from public.jobs;

  -- 6. Portfólio, Certificados, Conquistas, Antecedentes, Mandatos, KYC e Perfis
  delete from public.provider_achievements;
  delete from public.provider_certificates;
  delete from public.provider_portfolio;
  delete from public.criminal_background_checks;
  delete from public.legal_mandate_acceptances;
  delete from public.kyc_webhook_events;
  delete from public.kyc_liveness_nonces;
  delete from public.kyc_submissions;
  delete from public.provider_profiles;
  delete from public.account_deletion_log;
  delete from public.profiles;

  if to_regclass('private.signup_guard_rate_limits') is not null then
    execute 'delete from private.signup_guard_rate_limits';
  end if;

  -- 7. Contas auth.users fora do titular exclusivo CEO (wagneroliveira2395@gmail.com)
  delete from auth.refresh_tokens rt
   where rt.user_id is not null
     and (v_ceo_uid is null or rt.user_id <> v_ceo_uid::text)
     and not exists (
       select 1
         from auth.users au_keep
        where au_keep.id::text = rt.user_id
          and lower(btrim(coalesce(au_keep.email, ''))) = v_ceo_email
     );

  delete from auth.users au
   where (v_ceo_uid is null or au.id <> v_ceo_uid)
     and lower(btrim(coalesce(au.email, ''))) <> v_ceo_email;

  -- 8. Feed operacional efêmero do marketplace
  delete from private.ceo_live_events;

  alter sequence if exists public.ledger_lines_id_seq restart with 1;
  alter sequence if exists private.ceo_live_events_event_seq_seq restart with 1;

  -- 9. Asserções fail-closed de integridade
  select (
    (select count(*) from public.profiles) +
    (select count(*) from public.provider_profiles) +
    (select count(*) from public.jobs) +
    (select count(*) from public.quotes) +
    (select count(*) from public.client_wallets) +
    (select count(*) from public.wallet_statement) +
    (select count(*) from public.ledger_txns) +
    (select count(*) from public.ledger_lines) +
    (select count(*) from public.kyc_submissions) +
    (select count(*) from public.legal_mandate_acceptances) +
    (select count(*) from private.ceo_live_events)
  )
  into v_remaining_mkt;

  if v_remaining_mkt <> 0 then
    raise exception 'ERR_MARKETPLACE_RESET_INCOMPLETE: Restaram % registros.', v_remaining_mkt
      using errcode = 'P0001';
  end if;

  select count(*)
    into v_remaining_non_ceo
    from auth.users au
   where (v_ceo_uid is null or au.id <> v_ceo_uid)
     and lower(btrim(coalesce(au.email, ''))) <> v_ceo_email;

  if v_remaining_non_ceo <> 0 then
    raise exception 'ERR_AUTH_USERS_RESET_INCOMPLETE: Restaram % contas fora do CEO.', v_remaining_non_ceo
      using errcode = 'P0001';
  end if;

  if v_had_ceo_user and not exists (
    select 1
      from auth.users au
     where au.id = v_ceo_uid
       and lower(btrim(coalesce(au.email, ''))) = v_ceo_email
       and au.deleted_at is null
  ) then
    raise exception 'ERR_CEO_ACCOUNT_PROTECTION_VIOLATION' using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_sovereign_vault where singleton_id = true)
     or (select count(*) from private.founder_audit_log) <> v_pre_audit_cnt
     or not private.verify_founder_audit_chain()
     or (select count(*) from private.ceo_expense_entries) <> v_pre_expenses_cnt
     or (select count(*) from private.ceo_trusted_devices) <> v_pre_devices_cnt
     or (select count(*) from private.ceo_password_history) <> v_pre_pw_hist_cnt
     or (select count(*) from public.app_settings) <> v_pre_app_settings_cnt then
    raise exception 'ERR_CEO_STATE_PRESERVATION_VIOLATION' using errcode = '42501';
  end if;
end $$;

analyze
  public.profiles,
  public.provider_profiles,
  public.client_wallets,
  public.wallet_statement,
  public.ledger_txns,
  public.ledger_lines,
  public.legal_mandate_acceptances,
  private.ceo_live_events;

commit;

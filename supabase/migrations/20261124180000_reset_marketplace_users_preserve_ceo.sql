-- =============================================================================
-- DESPERRENGUE — Limpeza Transacional Atômica do Marketplace (v2.34.0)
--
-- Objetivo:
--   Excluir 100% dos usuários cadastrados no aplicativo Desperrengue
--   (Clientes, Profissionais e contas híbridas), bem como todo o histórico
--   operacional (pedidos, orçamentos, mensagens, carteiras, transações,
--   avaliações, antecedentes, KYC e objetos de Storage do marketplace),
--   preservando exclusivamente o titular soberano do Desperrengue CEO
--   (`wagneroliveira2395@gmail.com`) e toda a infraestrutura `private.ceo_*`,
--   a cadeia WORM (`private.founder_audit_log`), o segredo HMAC geográfico e
--   `public.app_settings`.
-- =============================================================================

begin;

-- Desacopla FKs de `private.founder_audit_log` para `auth.users` caso tenham sido
-- recriadas, preservando a integridade imutável da cadeia WORM de auditoria.
do $$
declare
  r record;
begin
  if to_regclass('private.founder_audit_log') is not null then
    for r in
      select con.conname
        from pg_constraint con
       where con.conrelid = 'private.founder_audit_log'::regclass
         and con.contype = 'f'
         and con.confrelid = 'auth.users'::regclass
    loop
      execute format(
        'alter table private.founder_audit_log drop constraint if exists %I',
        r.conname
      );
    end loop;
  end if;
end $$;

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
  v_pre_cal_notes_cnt    bigint := 0;
  v_post_cal_notes_cnt   bigint := 0;
  v_extra_duress_cnt     bigint := 0;
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

  if to_regclass('private.ceo_calendar_notes') is not null then
    execute 'select count(*) from private.ceo_calendar_notes' into v_pre_cal_notes_cnt;
  end if;

  -- 1. Limpeza dos objetos de Storage do marketplace (mídia, KYC e forense)
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

  -- 2. Camada Forense, Garantia, Mediações, Documentos Fiscais e Evidências de Pedidos
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

  -- 4. Ledger de Partida Dobrada, Carteiras, Pix, Pagamentos e Saques
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

  -- Libera novos cadastros imediatos sem rate-limit residual de testes
  if to_regclass('private.signup_guard_rate_limits') is not null then
    execute 'delete from private.signup_guard_rate_limits';
  end if;

  -- 7. Contas de Autenticação (`auth.*`) de 100% dos usuários do Marketplace,
  --    preservando estritamente a conta única do CEO (`wagneroliveira2395@gmail.com`)
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

  -- 8. Feed operacional efêmero do marketplace em `private.ceo_live_events`
  delete from private.ceo_live_events;

  alter sequence if exists public.ledger_lines_id_seq restart with 1;
  alter sequence if exists private.ceo_live_events_event_seq_seq restart with 1;

  -- 9. Asserções matemáticas fail-closed antes do COMMIT
  if to_regclass('public.duress_security_alerts') is not null then
    execute 'select count(*) from public.duress_security_alerts' into v_extra_duress_cnt;
  end if;

  select (
    (select count(*) from public.profiles) +
    (select count(*) from public.provider_profiles) +
    (select count(*) from public.jobs) +
    (select count(*) from public.quotes) +
    (select count(*) from public.job_invites) +
    (select count(*) from public.job_evidence) +
    (select count(*) from public.job_secrets) +
    (select count(*) from public.job_addresses) +
    (select count(*) from public.job_geo) +
    (select count(*) from public.payments) +
    (select count(*) from public.ledger_txns) +
    (select count(*) from public.ledger_lines) +
    (select count(*) from public.client_wallets) +
    (select count(*) from public.wallet_statement) +
    (select count(*) from public.pix_topups) +
    (select count(*) from public.withdrawals) +
    (select count(*) from public.reviews) +
    (select count(*) from public.messages) +
    (select count(*) from public.notifications) +
    (select count(*) from public.support_tickets) +
    (select count(*) from public.kyc_submissions) +
    (select count(*) from public.kyc_liveness_nonces) +
    (select count(*) from public.kyc_webhook_events) +
    (select count(*) from public.criminal_background_checks) +
    (select count(*) from public.legal_mandate_acceptances) +
    (select count(*) from public.provider_portfolio) +
    (select count(*) from public.provider_certificates) +
    (select count(*) from public.provider_achievements) +
    (select count(*) from public.provider_case_pins) +
    (select count(*) from public.job_mediations) +
    (select count(*) from public.escrow_maturation_entries) +
    (select count(*) from public.warranty_pool_ledger) +
    (select count(*) from public.forensic_certificates) +
    (select count(*) from public.job_fiscal_documents) +
    (select count(*) from public.account_deletion_log) +
    (select count(*) from private.job_forensic_secrets) +
    (select count(*) from private.ceo_live_events) +
    v_extra_duress_cnt
  )
  into v_remaining_mkt;

  if v_remaining_mkt <> 0 then
    raise exception 'ERR_MARKETPLACE_RESET_INCOMPLETE: Restaram % registros operacionais no marketplace.',
      v_remaining_mkt using errcode = 'P0001';
  end if;

  select count(*)
    into v_remaining_non_ceo
    from auth.users au
   where (v_ceo_uid is null or au.id <> v_ceo_uid)
     and lower(btrim(coalesce(au.email, ''))) <> v_ceo_email;

  if v_remaining_non_ceo <> 0 then
    raise exception 'ERR_AUTH_USERS_RESET_INCOMPLETE: Restaram % contas fora da titularidade CEO em auth.users.',
      v_remaining_non_ceo using errcode = 'P0001';
  end if;

  if v_had_ceo_user and not exists (
    select 1
      from auth.users au
     where au.id = v_ceo_uid
       and lower(btrim(coalesce(au.email, ''))) = v_ceo_email
       and au.deleted_at is null
  ) then
    raise exception 'ERR_CEO_ACCOUNT_PROTECTION_VIOLATION: A conta exclusiva do CEO deve permanecer intacta.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_sovereign_vault where singleton_id = true) then
    raise exception 'ERR_CEO_VAULT_MISSING: Cofre soberano ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_crypto_pepper where singleton_id = true) then
    raise exception 'ERR_CEO_PEPPER_MISSING: Pepper criptográfico ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.geo_privacy_secrets where id = 1) then
    raise exception 'ERR_GEO_PRIVACY_SECRET_MISSING: Segredo geográfico HMAC ausente após limpeza.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from private.ceo_treasury_config where singleton_id = true) then
    raise exception 'ERR_CEO_TREASURY_CONFIG_MISSING: Configuração de tesouraria bivalente ausente.'
      using errcode = '42501';
  end if;

  if (select count(*) from private.founder_audit_log) <> v_pre_audit_cnt
     or not private.verify_founder_audit_chain() then
    raise exception 'ERR_FOUNDER_AUDIT_WORM_VIOLATION: Cadeia WORM de auditoria do CEO deve permanecer intacta.'
      using errcode = '42501';
  end if;

  if (select count(*) from private.ceo_expense_entries) <> v_pre_expenses_cnt
     or (select count(*) from private.ceo_trusted_devices) <> v_pre_devices_cnt
     or (select count(*) from private.ceo_password_history) <> v_pre_pw_hist_cnt
     or (select count(*) from public.app_settings) <> v_pre_app_settings_cnt then
    raise exception 'ERR_CEO_STATE_PRESERVATION_VIOLATION: Tabelas soberanas do CEO ou app_settings sofreram mutação.'
      using errcode = '42501';
  end if;

  if to_regclass('private.ceo_calendar_notes') is not null then
    execute 'select count(*) from private.ceo_calendar_notes' into v_post_cal_notes_cnt;
    if v_post_cal_notes_cnt <> v_pre_cal_notes_cnt then
      raise exception 'ERR_CEO_CALENDAR_NOTES_VIOLATION: Notas executivas do calendário CEO sofreram mutação.'
        using errcode = '42501';
    end if;
  end if;
end $$;

analyze
  public.profiles,
  public.provider_profiles,
  public.jobs,
  public.quotes,
  public.job_invites,
  public.job_evidence,
  public.job_secrets,
  public.job_addresses,
  public.job_geo,
  public.payments,
  public.ledger_txns,
  public.ledger_lines,
  public.client_wallets,
  public.wallet_statement,
  public.pix_topups,
  public.withdrawals,
  public.reviews,
  public.messages,
  public.notifications,
  public.support_tickets,
  public.kyc_submissions,
  public.kyc_liveness_nonces,
  public.kyc_webhook_events,
  public.criminal_background_checks,
  public.legal_mandate_acceptances,
  public.provider_portfolio,
  public.provider_certificates,
  public.provider_achievements,
  public.provider_case_pins,
  public.job_mediations,
  public.escrow_maturation_entries,
  public.warranty_pool_ledger,
  public.forensic_certificates,
  public.job_fiscal_documents,
  public.account_deletion_log,
  private.job_forensic_secrets,
  private.ceo_live_events;

commit;

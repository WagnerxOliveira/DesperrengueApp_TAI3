-- =============================================================================
-- DESPERRENGUE — Marco Zero Operacional do Marketplace (v2.17.0)
--
-- Objetivo:
--   Limpar integralmente todos os cadastros de usuários do marketplace público
--   `Desperrengue` (Clientes, Profissionais e contas híbridas Cliente+Profissional),
--   bem como 100% dos pedidos, orçamentos, convites, conversas, avaliações,
--   carteiras, transações Pix/escrow/saques, lançamentos de partida dobrada,
--   mediações, dossiês forenses, submissões KYC e eventos operacionais históricos,
--   iniciando a plataforma `Desperrengue` completamente zerada (0 usuários).
--
-- Invariante Soberana Inviolável:
--   A conta única e exclusiva do `Desperrengue CEO` (`wagneroliveira2395@gmail.com`),
--   seu Cofre Criptográfico Monocrático (`private.ceo_sovereign_vault`,
--   `private.ceo_crypto_pepper`, `private.ceo_password_history`,
--   `private.ceo_trusted_devices`, `private.ceo_stepup_sessions`,
--   `private.ceo_security_challenges`, `private.ceo_otp_challenges`,
--   `private.ceo_password_reset_links`, `private.ceo_rate_limits`,
--   `private.ceo_expense_entries`), a cadeia WORM (`private.founder_audit_log`),
--   o segredo HMAC geográfico (`private.geo_privacy_secrets`) e as flags globais
--   (`public.app_settings`) permanecem 100% preservados e intactos.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Desacoplamento WORM de `private.founder_audit_log` contra deleção em `auth.users`:
--    Em logs criptográficos imutáveis (SHA-256 hash-chain), `actor_user_id` e
--    `target_user_id` jamais podem sofrer `ON DELETE SET NULL` quando contas do
--    marketplace são removidas de `auth.users`, preservando a integridade da cadeia.
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 2. Purga Transacional Atômica de Todos os Dados e Usuários do Marketplace
--    com Preservação Estrita da Conta Exclusiva do CEO (`wagneroliveira2395@gmail.com`)
-- -----------------------------------------------------------------------------
do $$
declare
  v_ceo_email         text := lower(btrim(private.ceo_owner_canonical_email()));
  v_vault_owner_uid   uuid;
  v_auth_ceo_uid      uuid;
  v_ceo_uid           uuid;
  v_had_ceo_user      boolean := false;
  v_remaining_mkt     bigint := 0;
  v_remaining_non_ceo bigint := 0;
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

  -- 2.1 Limpeza de metadados residuais de objetos nos buckets do marketplace
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

  -- 2.2 Camada Forense, Garantia em 3 Camadas, Mediações, Documentos Fiscais e Evidências
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

  -- 2.3 Comunicação, Avaliações, Chamados de Suporte e Notificações
  delete from public.messages;
  delete from public.reviews;
  delete from public.support_tickets;
  delete from public.notifications;

  -- 2.4 Transações Financeiras, Ledger de Partida Dobrada, Carteiras, Pix e Saques
  delete from public.ledger_lines;
  delete from public.ledger_txns;
  delete from public.wallet_statement;
  delete from public.pix_topups;
  delete from public.payments;
  delete from public.withdrawals;
  delete from public.client_wallets;

  -- 2.5 Desvinculação de autorreferências em `jobs` seguida da limpeza de `quotes` e `jobs`
  update public.jobs
     set accepted_quote_id = null,
         parent_job_id = null
   where accepted_quote_id is not null
      or parent_job_id is not null;

  delete from public.quotes;
  delete from public.jobs;

  -- 2.6 Portfólio, Certificados, Conquistas, KYC, Perfis Profissionais e Logs LGPD
  delete from public.provider_achievements;
  delete from public.provider_certificates;
  delete from public.provider_portfolio;
  delete from public.kyc_webhook_events;
  delete from public.kyc_liveness_nonces;
  delete from public.kyc_submissions;
  delete from public.provider_profiles;
  delete from public.account_deletion_log;

  -- 2.7 Perfis Unificados do Marketplace (`public.profiles`: Clientes, Profissionais e Ambos)
  delete from public.profiles;

  -- 2.8 Contas de Autenticação (`auth.*`) de TODOS os usuários do Marketplace,
  --     preservando estritamente a conta única e exclusiva do CEO (`wagneroliveira2395@gmail.com`)
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

  -- 2.9 Limpeza do feed operacional histórico do marketplace em `private.ceo_live_events`
  delete from private.ceo_live_events;

  -- Reinício limpo de sequências numéricas operacionais
  alter sequence if exists public.ledger_lines_id_seq restart with 1;
  alter sequence if exists private.ceo_live_events_event_seq_seq restart with 1;

  -- ---------------------------------------------------------------------------
  -- 3. Pós-condições Matemáticas Obrigatórias antes do COMMIT (Fail-Closed)
  -- ---------------------------------------------------------------------------
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
    (select count(*) from private.ceo_live_events)
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
end $$;

-- Atualiza estatísticas físicas do planejador PostgreSQL para leitura exata imediata (0 linhas)
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

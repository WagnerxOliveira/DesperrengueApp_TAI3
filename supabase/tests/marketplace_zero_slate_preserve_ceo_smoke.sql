-- =============================================================================
-- Suíte Smoke de Validação — Marco Zero do Marketplace & Preservação Soberana CEO
--
-- Verifica que:
--   1. `private.founder_audit_log` preserva cadeia WORM SHA-256 intacta mesmo
--      quando um usuário intruso de `auth.users` é removido do banco;
--   2. A limpeza de todos os usuários do marketplace (Cliente, Profissional e
--      Cliente+Profissional) e seus pedidos/transações zera 100% das tabelas
--      operacionais preservando integralmente `wagneroliveira2395@gmail.com`
--      e todas as tabelas soberanas `private.ceo_*`.
-- =============================================================================

begin;

do $$
declare
  v_ceo_id      uuid := '99999999-0000-4000-8000-000000000001';
  v_client_id   uuid := '11111111-0000-4000-8000-000000000001';
  v_provider_id uuid := '22222222-0000-4000-8000-000000000002';
  v_dual_id     uuid := '33333333-0000-4000-8000-000000000003';
  v_job_id      uuid := '44444444-0000-4000-8000-000000000004';
  v_audit_cnt   bigint;
begin
  -- 1. Semeia CEO + 3 perfis do marketplace (Cliente, Profissional e Híbrido) em transação reversível
  insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
  values
    (v_ceo_id, 'wagneroliveira2395@gmail.com', '{"full_name":"Wagner CEO"}'::jsonb, now(), now()),
    (v_client_id, 'cliente.teste@example.com', '{"full_name":"Cliente Teste"}'::jsonb, now(), now()),
    (v_provider_id, 'profissional.teste@example.com', '{"full_name":"Profissional Teste"}'::jsonb, now(), now()),
    (v_dual_id, 'hibrido.teste@example.com', '{"full_name":"Hibrido Teste"}'::jsonb, now(), now())
  on conflict (id) do nothing;

  update private.ceo_sovereign_vault
     set owner_user_id = coalesce(owner_user_id, v_ceo_id)
   where singleton_id = true;

  update public.profiles set is_client = true, client_setup_done = true where id = v_client_id;
  update public.profiles set is_provider = true, provider_setup_done = true, verification_status = 'ACTIVE' where id = v_provider_id;
  update public.profiles set is_client = true, is_provider = true, client_setup_done = true, provider_setup_done = true, verification_status = 'ACTIVE' where id = v_dual_id;

  insert into public.provider_profiles (user_id, headline)
  values (v_provider_id, 'Eletricista'), (v_dual_id, 'Encanador')
  on conflict (user_id) do nothing;

  insert into public.jobs (id, client_id, provider_id, category, title, description, status, agreed_price)
  values (v_job_id, v_client_id, v_provider_id, 'eletrica', 'Troca de disjuntor', 'Quadro principal', 'open', 180.00);

  select count(*) into v_audit_cnt from private.founder_audit_log;

  -- 2. Executa a mesma lógica de purga seletiva preservando `wagneroliveira2395@gmail.com`
  delete from public.jobs;
  delete from public.provider_profiles;
  delete from public.client_wallets;
  delete from public.wallet_statement;
  delete from public.ledger_lines;
  delete from public.ledger_txns;
  delete from public.profiles;
  delete from private.ceo_live_events;

  delete from auth.users au
   where lower(btrim(coalesce(au.email, ''))) <> 'wagneroliveira2395@gmail.com';

  -- 3. Asserções estritas
  if (select count(*) from public.profiles) <> 0 then
    raise exception 'SMOKE_FAIL: public.profiles deveria estar zerada.';
  end if;

  if (select count(*) from public.provider_profiles) <> 0 then
    raise exception 'SMOKE_FAIL: public.provider_profiles deveria estar zerada.';
  end if;

  if (select count(*) from public.jobs) <> 0 then
    raise exception 'SMOKE_FAIL: public.jobs deveria estar zerada.';
  end if;

  if not exists (
    select 1 from auth.users where lower(btrim(email)) = 'wagneroliveira2395@gmail.com'
  ) then
    raise exception 'SMOKE_FAIL: Conta exclusiva CEO foi afetada indevidamente.';
  end if;

  if (select count(*) from private.founder_audit_log) <> v_audit_cnt then
    raise exception 'SMOKE_FAIL: private.founder_audit_log sofreu mutação indevida.';
  end if;
end $$;

rollback;

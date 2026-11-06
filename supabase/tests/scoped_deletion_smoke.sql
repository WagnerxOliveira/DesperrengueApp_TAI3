-- ============================================================================
-- DESPERRENGUE — Teste de fumaça da EXCLUSÃO DE CONTA POR ESCOPO
-- (migration 20261107100000): normalização, travas por escopo, dossiê por escopo,
-- purga 'client' / 'provider' / 'all', ledger consistente e permissões.
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/scoped_deletion_smoke.sql
-- Requer >= 4 linhas em public.profiles.
--   b = cliente E profissional   o = só cliente   x = só profissional   y = profissional (contraparte)
-- Cada purga roda numa subtransação revertida (RAISE P0999), então os três casos
-- partem do MESMO cenário; os resultados são acumulados em variáveis (que
-- sobrevivem ao rollback da subtransação) e registrados depois.
-- ============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$ insert into pg_temp.res (ok, name) values (p_ok, p_name) $$;

-- Resultado "para depois" (sobrevive a rollback de subtransação).
create function pg_temp.chk(p_ok boolean, p_name text) returns jsonb
language sql immutable as $$ select jsonb_build_array(jsonb_build_object('ok', coalesce(p_ok, false), 'n', p_name)) $$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Serviço concluído com pagamento liberado (c -> p).
create function pg_temp.done_job(c uuid, p uuid, title text, amt numeric, photo text default null) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category, urgency, address_summary, address_cep)
  values (c, title, 'descrição privada', 'Elétrica', 'scheduled', 'Rua Secreta, 10', '01001000') returning id into j;
  update public.jobs set provider_id = p, status = 'completed', payment_status = 'released', agreed_price = amt,
         photo_paths = case when photo is null then '{}' else array[photo] end
   where id = j;
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status, released_at)
  values (j, c, p, amt, 12, round(amt * 0.12, 2), round(amt * 0.88, 2), 'pix', 'released', now());
  return j;
end $$;

do $$
declare
  ids uuid[]; act uuid[]; b uuid; o uuid; x uuid; y uuid;
  jc1 uuid; jc2 uuid; jc3 uuid; jp1 uuid; jp2 uuid; jz uuid;
  v jsonb; s text; n int; n2 int; r record; v_acc jsonb := '[]'::jsonb;
  v_month text := to_char(timezone('UTC', now()), 'YYYY-MM');
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 4 then raise exception 'TESTE ABORTADO: são necessários >= 4 perfis.'; end if;
  b := ids[1]; o := ids[2]; x := ids[3]; y := ids[4];
  act := array[b, o, x, y];

  -- ===== limpeza do cenário (só dentro desta transação abortada) =====
  delete from public.jobs where client_id = any (act) or provider_id = any (act);
  delete from public.reviews where reviewer_id = any (act) or reviewee_id = any (act);
  delete from public.withdrawals where provider_id = any (act);
  delete from public.support_tickets where user_id = any (act);
  delete from public.pix_topups where client_id = any (act);
  delete from public.notifications where user_id = any (act);
  delete from public.provider_portfolio where provider_id = any (act);
  delete from public.provider_certificates where provider_id = any (act);
  delete from public.provider_achievements where provider_id = any (act);
  delete from public.provider_case_pins where provider_id = any (act);
  delete from public.kyc_submissions where user_id = any (act);
  delete from public.provider_profiles where user_id = any (act);

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED', last_mode = null
   where id = any (act);

  -- ===== 1. NORMALIZAÇÃO DO ESCOPO =====
  perform pg_temp.t(public._normalize_deletion_scope(b, 'client') = 'all', '01 conta sem nenhum papel: qualquer escopo vira all');

  update public.profiles set is_client = true, client_setup_done = true, last_mode = 'client' where id = b;
  update public.profiles set is_provider = true, provider_setup_done = true, verification_status = 'ACTIVE' where id = b;
  update public.profiles set is_client = true, client_setup_done = true where id = o;
  update public.profiles set is_provider = true, provider_setup_done = true, verification_status = 'ACTIVE' where id in (x, y);
  insert into public.provider_profiles (user_id, specialties, visit_fee)
    select id, array['Elétrica'], 30 from public.profiles where id in (b, x, y);
  update public.client_wallets set available_cents = 120000, escrow_cents = 0 where client_id = any (act);

  perform pg_temp.t(public._normalize_deletion_scope(b, 'client') = 'client', '02 dois papéis: client permanece client');
  perform pg_temp.t(public._normalize_deletion_scope(b, 'provider') = 'provider', '03 dois papéis: provider permanece provider');
  perform pg_temp.t(public._normalize_deletion_scope(b, 'all') = 'all', '04 dois papéis: all permanece all');
  perform pg_temp.t(public._normalize_deletion_scope(b, null) = 'all' and public._normalize_deletion_scope(b, '  ') = 'all', '05 escopo nulo/vazio vira all');
  perform pg_temp.t(public._normalize_deletion_scope(b, ' CLIENT ') = 'client', '06 caixa/espaços são normalizados');
  perform pg_temp.t(public._normalize_deletion_scope(o, 'client') = 'all', '07 só cliente pedindo client: vira all (cobre todos os papéis)');
  perform pg_temp.t(public._normalize_deletion_scope(x, 'provider') = 'all', '08 só profissional pedindo provider: vira all');
  begin
    perform public._normalize_deletion_scope(o, 'provider');
    perform pg_temp.t(false, '09 provider para quem não é profissional PERMITIDO');
  exception when others then perform pg_temp.t(sqlerrm like '%profissional%', '09 provider exige is_provider (erro explícito, NÃO vira all)'); end;
  begin
    perform public._normalize_deletion_scope(x, 'client');
    perform pg_temp.t(false, '10 client para quem não é cliente PERMITIDO');
  exception when others then perform pg_temp.t(sqlerrm like '%cliente%', '10 client exige is_client (erro explícito, NÃO vira all)'); end;
  begin
    perform public._normalize_deletion_scope(b, 'tudo');
    perform pg_temp.t(false, '11 escopo inválido PERMITIDO');
  exception when others then perform pg_temp.t(true, '11 escopo inválido é recusado'); end;

  -- ===== CENÁRIO =====
  -- b como CLIENTE
  update public.profiles set address_line = 'Rua Secreta, 10', address_city = 'Poços de Caldas',
         latitude = -21.78, longitude = -46.56 where id = b;
  insert into public.jobs (client_id, title, description, category, urgency) values (b, 'Trocar disjuntor', 'desc', 'Elétrica', 'scheduled') returning id into jc1;
  insert into public.quotes (job_id, provider_id, price) values (jc1, y, 100);
  insert into public.quotes (job_id, provider_id, price) values (jc1, x, 150);
  insert into public.messages (job_id, provider_id, sender_id, body) values (jc1, y, b, 'oi, do cliente');
  insert into public.messages (job_id, provider_id, sender_id, body) values (jc1, y, y, 'oi, do profissional');
  update public.quotes set status = 'accepted' where job_id = jc1 and provider_id = y;
  update public.quotes set status = 'rejected' where job_id = jc1 and provider_id = x;
  update public.jobs set provider_id = y, status = 'completed', payment_status = 'released', agreed_price = 100,
         photo_paths = array[b::text || '/job_1.jpg'], created_at = now() where id = jc1;
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status, released_at)
    values (jc1, b, y, 100, 12, 12, 88, 'pix', 'released', now());
  insert into public.job_addresses (job_id, address_line) values (jc1, 'Rua Secreta, 10');
  insert into public.job_secrets (job_id, pin) values (jc1, '1234');
  jc2 := pg_temp.done_job(b, x, 'Montar prateleira', 50);
  update public.jobs set created_at = now() - interval '40 days' where id = jc2;
  update public.payments set released_at = now() - interval '40 days' where job_id = jc2;
  insert into public.jobs (client_id, title, description, category, urgency) values (b, 'Pedido aberto', 'segredo', 'Elétrica', 'scheduled') returning id into jc3;
  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, photo_paths, revealed_at)
    values (jc1, b, y, 5, 'Excelente', '{}', array[b::text || '/review_1.jpg'], now());
  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, revealed_at)
    values (jc1, y, b, 4, 'Cliente educado', '{}', now());
  insert into public.support_tickets (user_id, job_id, reason, description, evidence_paths)
    values (b, null, 'Dúvida', 'texto', array[b::text || '/ticket_1.jpg']);
  insert into public.pix_topups (client_id, amount_cents, txid, brcode, status, idempotency_key, paid_at)
    values (b, 1000, 'TESTTX' || replace(gen_random_uuid()::text, '-', ''), 'brcode', 'paid', 'k1', now());

  -- b como PROFISSIONAL
  jp1 := pg_temp.done_job(o, b, 'Instalar chuveiro', 200);   -- net 176
  update public.jobs set provider_report = 'Relatório técnico do trabalho' where id = jp1;
  insert into public.job_evidence (job_id, provider_id, slot, path) values (jp1, b, 'overview', b::text || '/ev_overview_1.jpg');
  insert into public.provider_case_pins (provider_id, job_id) values (b, jp1);
  insert into public.provider_portfolio (provider_id, image_path, caption) values (b, b::text || '/portfolio_1.jpg', 'obra');
  insert into public.provider_certificates (provider_id, title) values (b, 'NR-10');
  insert into public.provider_achievements (provider_id, code) values (b, 'jobs_1') on conflict do nothing;   -- o gatilho de conclusão pode já ter liberado conquistas
  insert into public.kyc_submissions (user_id, front_path, back_path, selfie_path, registry_type, registry_number)
    values (b, b::text || '/front_1.jpg', b::text || '/back_1.jpg', b::text || '/selfie_1.jpg', 'CREA', '12345');
  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, revealed_at, reply, reply_at)
    values (jp1, o, b, 4, 'Bom profissional', '{}', now(), 'Obrigado!', now());
  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, photo_paths, revealed_at)
    values (jp1, b, o, 5, 'Cliente ótimo', '{}', array[b::text || '/review_9.jpg'], now());
  insert into public.jobs (client_id, title, description, category, urgency) values (o, 'Pedido de outro cliente', 'x', 'Elétrica', 'scheduled') returning id into jp2;
  insert into public.quotes (job_id, provider_id, price) values (jp2, b, 90);
  insert into public.messages (job_id, provider_id, sender_id, body) values (jp2, b, b, 'oi, do prof b');
  insert into public.messages (job_id, provider_id, sender_id, body) values (jp2, b, o, 'oi, do cliente o');
  insert into public.withdrawals (provider_id, amount, pix_key_type, pix_key_hint) values (b, 176, 'cpf', '***8901');

  -- ===== 2. TRAVAS POR ESCOPO =====
  v := public._deletion_blockers(b, 'client');
  perform pg_temp.t((v ->> 'can_delete')::boolean and v ->> 'scope' = 'client', '12 cenário limpo: b pode excluir o papel de cliente');
  v := public._deletion_blockers(b, 'provider');
  perform pg_temp.t((v ->> 'can_delete')::boolean and (v ->> 'available')::numeric = 0, '13 cenário limpo: saldo zerado libera o papel profissional');
  v := public._deletion_blockers(b);
  perform pg_temp.t((v ->> 'can_delete')::boolean and v ->> 'scope' = 'all', '14 default (1 argumento) = all e libera');

  -- serviço em andamento onde b é CLIENTE: trava só o escopo cliente (e all)
  begin
    insert into public.jobs (client_id, title, description, category, urgency) values (b, 'Andando', 'x', 'Elétrica', 'scheduled') returning id into jz;
    update public.jobs set provider_id = y, status = 'in_progress' where id = jz;
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(b, 'client') -> 'blockers' ? 'active_jobs', '15 serviço ativo como cliente trava o escopo client');
    v_acc := v_acc || pg_temp.chk((public._deletion_blockers(b, 'provider') ->> 'can_delete')::boolean, '16 ...mas NÃO trava o escopo provider');
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(b, 'all') -> 'blockers' ? 'active_jobs', '17 ...e trava all');
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(y, 'provider') -> 'blockers' ? 'active_jobs', '18 o profissional y fica travado pelo mesmo serviço');
    update public.jobs set status = 'scheduled' where id = jz;
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(b, 'client') -> 'blockers' ? 'active_jobs', '19 status scheduled continua sendo serviço ativo');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco de travas (ativo) falhou: ' || sqlerrm); end if;
  end;
  -- serviço onde b é PROFISSIONAL: trava só o escopo profissional
  begin
    insert into public.jobs (client_id, title, description, category, urgency) values (o, 'Andando 2', 'x', 'Elétrica', 'scheduled') returning id into jz;
    update public.jobs set provider_id = b, status = 'awaiting_approval' where id = jz;
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(b, 'provider') -> 'blockers' ? 'active_jobs', '20 serviço ativo como profissional trava o escopo provider');
    v_acc := v_acc || pg_temp.chk((public._deletion_blockers(b, 'client') ->> 'can_delete')::boolean, '21 ...mas NÃO trava o escopo client');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco de travas (ativo prof) falhou: ' || sqlerrm); end if;
  end;
  -- custódia (escrow): do cliente trava client; do profissional trava provider
  begin
    insert into public.jobs (client_id, title, description, category, urgency) values (b, 'Custódia cliente', 'x', 'Elétrica', 'scheduled') returning id into jz;
    update public.jobs set provider_id = y, status = 'canceled' where id = jz;
    insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status)
      values (jz, b, y, 50, 12, 6, 44, 'pix', 'escrow');
    v := public._deletion_blockers(b, 'client');
    v_acc := v_acc || pg_temp.chk(v -> 'blockers' ? 'escrow' and (v ->> 'held')::numeric = 50, '22 escrow do cliente trava o escopo client (held = 50)');
    v_acc := v_acc || pg_temp.chk((public._deletion_blockers(b, 'provider') ->> 'can_delete')::boolean, '23 ...mas não o escopo provider');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco de travas (escrow cliente) falhou: ' || sqlerrm); end if;
  end;
  begin
    insert into public.jobs (client_id, title, description, category, urgency) values (o, 'Custódia prof', 'x', 'Elétrica', 'scheduled') returning id into jz;
    update public.jobs set provider_id = b, status = 'canceled' where id = jz;
    insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status)
      values (jz, o, b, 50, 12, 6, 44, 'pix', 'escrow');
    v_acc := v_acc || pg_temp.chk(public._deletion_blockers(b, 'provider') -> 'blockers' ? 'escrow', '24 custódia do profissional trava o escopo provider');
    v_acc := v_acc || pg_temp.chk((public._deletion_blockers(b, 'client') ->> 'can_delete')::boolean, '25 ...mas não o escopo client');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco de travas (escrow prof) falhou: ' || sqlerrm); end if;
  end;
  -- saldo livre do profissional trava só provider
  begin
    delete from public.withdrawals where provider_id = b;
    v := public._deletion_blockers(b, 'provider');
    v_acc := v_acc || pg_temp.chk(v -> 'blockers' ? 'balance' and (v ->> 'available')::numeric = 176, '26 saldo livre trava o escopo provider (available = 176)');
    v_acc := v_acc || pg_temp.chk((public._deletion_blockers(b, 'client') ->> 'can_delete')::boolean, '27 ...mas não o escopo client');
    begin
      perform public.purge_account(b, 'provider');
      v_acc := v_acc || pg_temp.chk(false, '28 purge provider com saldo PERMITIDO');
    exception when others then
      v_acc := v_acc || pg_temp.chk(sqlerrm like 'Exclusão bloqueada%', '28 purge_account revalida a trava e recusa com saldo');
    end;
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco de travas (saldo) falhou: ' || sqlerrm); end if;
  end;

  -- ===== 3. DOSSIÊ POR ESCOPO =====
  v := public.account_dossier(b, 'client');
  perform pg_temp.t(v ->> 'scope' = 'client' and v -> 'scope_roles' = '["client"]'::jsonb, '29 dossiê client: scope e scope_roles');
  perform pg_temp.t(v ? 'client' and not (v ? 'provider'), '30 dossiê client traz só a seção do cliente');
  perform pg_temp.t(v ? 'generated_at' and v ? 'name' and v ? 'member_since' and (v ->> 'is_client')::boolean and (v ->> 'is_provider')::boolean, '31 dossiê traz as chaves comuns');
  perform pg_temp.t((v #>> '{client,total_spent}')::numeric = 150 and (v #>> '{client,total_saved}')::numeric = 25, '32 cliente: gasto 150 e economia 25 (média 125 - 100)');
  perform pg_temp.t((v #>> '{totals,spent}')::numeric = 150 and (v #>> '{totals,saved}')::numeric = 25 and (v #>> '{totals,profit}')::numeric = 0, '33 totals.* (chaves antigas) e lucro 0 fora do escopo');
  perform pg_temp.t(jsonb_array_length(v #> '{client,orders}') = 3 and (v #>> '{client,orders_count}')::int = 3, '34 cliente: 3 pedidos listados');
  perform pg_temp.t((v #>> '{client,completed_count}')::int = 2 and (v #>> '{client,ticket_medio}')::numeric = 75, '35 cliente: 2 concluídos e ticket médio 75');
  perform pg_temp.t(jsonb_array_length(v #> '{client,monthly}') = 12 and v #>> '{client,monthly,11,month}' = v_month, '36 cliente: série mensal de 12 meses terminando no mês atual');
  perform pg_temp.t((v #>> '{client,monthly,11,spent}')::numeric = 100 and (v #>> '{client,monthly,11,saved}')::numeric = 25
                    and (select sum((m ->> 'spent')::numeric) from jsonb_array_elements(v #> '{client,monthly}') m) = 150, '37 cliente: gasto/economia por mês (100 no mês atual; 150 em 12 meses)');
  select e into r from jsonb_array_elements(v #> '{client,orders}') e where e ->> 'title' = 'Trocar disjuntor';
  perform pg_temp.t((r.e ->> 'quotes_received')::int = 2 and (r.e ->> 'avg_other_quotes')::numeric = 125 and (r.e ->> 'saved')::numeric = 25
                    and r.e ? 'scheduled_for' and r.e ? 'started_at' and r.e ? 'finished_at' and r.e ? 'category' and r.e ? 'payment_status', '38 pedido traz orçamentos, média, economia, datas e categoria');
  perform pg_temp.t(v #> '{client,by_category}' @> '[{"category":"Elétrica","orders":3}]'::jsonb, '39 cliente: por categoria');
  perform pg_temp.t((v #>> '{client,by_status,completed}')::int = 2 and (v #>> '{client,by_status,open}')::int = 1, '40 cliente: contagem por status');
  perform pg_temp.t((v #>> '{client,reviews_given,count}')::int = 1 and (v #>> '{client,reviews_given,avg}')::numeric = 5, '41 cliente: avaliações dadas (1, média 5)');
  perform pg_temp.t((v #>> '{client,wallet,total}')::numeric = 10 and (v #>> '{client,wallet,count}')::int = 1, '42 cliente: recargas de carteira (R$ 10,00)');

  v := public.account_dossier(b, 'provider');
  perform pg_temp.t(v ->> 'scope' = 'provider' and v -> 'scope_roles' = '["provider"]'::jsonb and v ? 'provider' and not (v ? 'client'), '43 dossiê provider: só a seção do profissional');
  perform pg_temp.t((v #>> '{provider,total_gross}')::numeric = 200 and (v #>> '{provider,total_fee}')::numeric = 24
                    and (v #>> '{provider,total_profit}')::numeric = 176 and (v #>> '{provider,total_withdrawn}')::numeric = 176, '44 profissional: bruto 200, comissão 24, líquido 176, sacado 176');
  perform pg_temp.t((v #>> '{totals,profit}')::numeric = 176 and (v #>> '{totals,spent}')::numeric = 0, '45 totals.profit = 176 e gasto 0 fora do escopo');
  perform pg_temp.t(jsonb_array_length(v #> '{provider,jobs}') = 1 and (v #>> '{provider,jobs,0,net}')::numeric = 176
                    and (v #>> '{provider,jobs,0,fee}')::numeric = 24 and v #> '{provider,jobs,0}' ? 'finished_at', '46 profissional: serviços com valor, comissão, líquido e datas');
  perform pg_temp.t(jsonb_array_length(v #> '{provider,monthly}') = 12 and (v #>> '{provider,monthly,11,net}')::numeric = 176 and (v #>> '{provider,monthly,11,jobs}')::int = 1, '47 profissional: série mensal de 12 meses (líquido no mês atual)');
  perform pg_temp.t(v #> '{provider,by_category}' @> '[{"category":"Elétrica","jobs":1}]'::jsonb, '48 profissional: por categoria');
  perform pg_temp.t((v #>> '{provider,quotes_total}')::int = 1 and (v #>> '{provider,quotes_accepted}')::int = 0
                    and (v #>> '{provider,acceptance_rate}')::numeric = 0 and jsonb_array_length(v #> '{provider,quotes}') = 1, '49 profissional: orçamentos e taxa de aceitação');
  perform pg_temp.t((v #>> '{provider,reviews_count}')::int = 1 and (v #>> '{provider,rating_avg}')::numeric = 4
                    and (v #>> '{provider,rating_dist,4}')::int = 1 and (v #>> '{provider,rating_dist,5}')::int = 0, '50 profissional: avaliações, nota média e distribuição 1..5');
  perform pg_temp.t((v #>> '{provider,achievements_count}')::int = (select count(*) from public.provider_achievements where provider_id = b) and (v #>> '{provider,achievements_count}')::int >= 1 and jsonb_array_length(v #> '{provider,withdrawals}') = 1, '51 profissional: conquistas e saques');

  v := public.account_dossier(b, 'all');
  perform pg_temp.t(v ->> 'scope' = 'all' and v -> 'scope_roles' = '["client","provider"]'::jsonb and v ? 'client' and v ? 'provider', '52 dossiê all: as duas seções');
  perform pg_temp.t(v #> '{client,orders}' is not null and v #> '{client,total_spent}' is not null and v #> '{client,total_saved}' is not null
                    and v #> '{provider,jobs}' is not null and v #> '{provider,total_gross}' is not null and v #> '{provider,total_fee}' is not null
                    and v #> '{provider,total_profit}' is not null and v #> '{provider,total_withdrawn}' is not null
                    and v #> '{provider,quotes}' is not null and v #> '{provider,reviews}' is not null
                    and v #> '{totals,spent}' is not null and v #> '{totals,saved}' is not null and v #> '{totals,profit}' is not null, '53 chaves antigas preservadas');
  perform pg_temp.t(public.account_dossier(b) ->> 'scope' = 'all', '54 default (1 argumento) = all');
  perform pg_temp.t(public.account_dossier(o, 'client') ->> 'scope' = 'all' and public.account_dossier(o, 'client') -> 'scope_roles' = '["client"]'::jsonb, '55 só cliente: client vira all, com só o papel de cliente');
  begin
    perform public.account_dossier(o, 'provider');
    perform pg_temp.t(false, '56 dossiê provider para quem não é profissional PERMITIDO');
  exception when others then perform pg_temp.t(true, '56 dossiê recusa escopo de papel inexistente'); end;
  -- sem dados: arrays vazios e zeros (PDF sem dados)
  begin
    delete from public.jobs where client_id = any (act) or provider_id = any (act);
    delete from public.reviews where reviewer_id = any (act) or reviewee_id = any (act);
    delete from public.withdrawals where provider_id = any (act);
    delete from public.provider_achievements where provider_id = any (act);
    delete from public.pix_topups where client_id = any (act);
    v := public.account_dossier(b, 'all');
    v_acc := v_acc || pg_temp.chk(v #> '{client,orders}' = '[]'::jsonb and v #> '{provider,jobs}' = '[]'::jsonb
      and v #> '{provider,quotes}' = '[]'::jsonb and v #> '{provider,reviews}' = '[]'::jsonb
      and v #> '{client,by_category}' = '[]'::jsonb and v #> '{provider,by_category}' = '[]'::jsonb
      and v #> '{provider,withdrawals}' = '[]'::jsonb, '57 conta sem histórico: listas vazias (nunca nulas)');
    v_acc := v_acc || pg_temp.chk((v #>> '{client,total_spent}')::numeric = 0 and (v #>> '{client,ticket_medio}')::numeric = 0
      and (v #>> '{provider,total_profit}')::numeric = 0 and (v #>> '{provider,acceptance_rate}')::numeric = 0
      and (v #>> '{provider,rating_avg}')::numeric = 0 and (v #>> '{client,wallet,total}')::numeric = 0, '58 conta sem histórico: totais zerados (sem divisão por zero)');
    v_acc := v_acc || pg_temp.chk(jsonb_array_length(v #> '{client,monthly}') = 12 and jsonb_array_length(v #> '{provider,monthly}') = 12
      and (select count(*) from jsonb_array_elements(v #> '{provider,monthly}') m where (m ->> 'net')::numeric <> 0) = 0
      and (v #>> '{provider,rating_dist,1}')::int = 0 and (v #>> '{provider,rating_dist,5}')::int = 0, '58b conta sem histórico: 12 meses zerados e distribuição de notas zerada');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco dossiê vazio falhou: ' || sqlerrm); end if;
  end;
  -- ===== 4. PURGA 'client' =====
  begin
    v := public.purge_account(b, 'client');
    v_acc := v_acc || pg_temp.chk(v ->> 'scope' = 'client' and (v ->> 'account_removed')::boolean = false
                                  and (v ->> 'jobs_deleted')::int = 1 and (v ->> 'jobs_retained')::int = 2, '59 purge client: retorno {scope, account_removed=false, deleted=1, retained=2}');
    select is_client, is_provider, client_setup_done, last_mode, address_line, address_city, latitude into r from public.profiles where id = b;
    v_acc := v_acc || pg_temp.chk(not r.is_client and r.is_provider and not r.client_setup_done and r.last_mode = 'provider', '60 purge client: is_client=false, is_provider mantido, last_mode client -> provider');
    v_acc := v_acc || pg_temp.chk(r.address_line is null and r.address_city = 'Poços de Caldas' and r.latitude is not null, '61 purge client: endereço (address_line) limpo; cidade/coordenadas mantidas (servem ao profissional)');
    select count(*) into n from public.provider_profiles where user_id = b;
    select count(*) into n2 from public.provider_portfolio where provider_id = b;
    v_acc := v_acc || pg_temp.chk(n = 1 and n2 = 1
      and (select count(*) from public.job_evidence where provider_id = b) = 1
      and (select count(*) from public.kyc_submissions where user_id = b) = 1
      and (select count(*) from public.provider_achievements where provider_id = b) >= 1
      and (select count(*) from public.quotes where provider_id = b and status = 'pending') = 1
      and (select verification_status::text from public.profiles where id = b) = 'ACTIVE', '62 purge client: provider_profiles, portfólio, evidências, KYC, conquistas, orçamento e verificação INTACTOS');
    select count(*) into n from public.jobs where id = jc3;
    v_acc := v_acc || pg_temp.chk(n = 0, '63 purge client: pedido sem pagamento removido');
    select count(*) into n from public.jobs where id in (jc1, jc2) and client_id is null and description = '[conteúdo removido a pedido do titular]'
       and address_summary is null and address_cep is null and photo_paths = '{}' and title = 'Serviço';
    v_acc := v_acc || pg_temp.chk(n = 2, '64 purge client: pedidos pagos ficam anonimizados e sem vínculo (client_id NULL)');
    select count(*) into n from public.payments where job_id in (jc1, jc2) and client_id is null and status = 'released';
    v_acc := v_acc || pg_temp.chk(n = 2, '65 purge client: pagamentos ficam como registro financeiro sem vínculo');
    select count(*) into n from public.job_addresses where job_id in (jc1, jc2);
    select count(*) into n2 from public.job_secrets where job_id in (jc1, jc2);
    v_acc := v_acc || pg_temp.chk(n = 0 and n2 = 0, '66 purge client: job_addresses e job_secrets apagados');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.client_wallets where client_id = b) = 0
      and (select count(*) from public.wallet_statement where client_id = b) = 0
      and (select count(*) from public.pix_topups where client_id = b) = 0, '67 purge client: carteira, extrato e Pix apagados');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.ledger_lines where account like 'client:' || b::text || ':%') = 0
      and (select count(*) from public.ledger_txns where idempotency_key = 'seed:' || b::text) = 0, '68 purge client: ledger sem vínculo com o usuário (contas e chave de seed renomeadas)');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.ledger_txns t where (select coalesce(sum(cents), 0) from public.ledger_lines l where l.txn_id = t.id) <> 0) = 0
      and (select coalesce(sum(cents), 0) from public.ledger_lines) = 0, '69 purge client: ledger segue em partida dobrada (toda transação soma 0)');
    v_acc := v_acc || pg_temp.chk((select count(*) from (select account from public.ledger_lines where account like 'client:removed-%' group by account having sum(cents) <> 0) z) = 0
      and (select count(*) from public.ledger_txns where kind = 'closure') >= 1, '70 purge client: contas removidas fecham em 0 por lançamento de encerramento');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.support_tickets where user_id = b) = 0, '71 purge client: chamados do cliente apagados');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.messages where job_id = jc1 and sender_id = b) = 0
      and (select count(*) from public.messages where job_id = jc1 and sender_id = y) = 1
      and (select count(*) from public.messages where job_id = jp2 and provider_id = b) = 2, '72 purge client: mensagens do cliente saem; as do profissional e as dele como profissional ficam');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.reviews where job_id = jc1 and reviewee_id = b) = 0, '73 purge client: avaliação recebida como cliente removida');
    select reviewer_id, photo_paths into r from public.reviews where job_id = jc1 and reviewee_id = y;
    v_acc := v_acc || pg_temp.chk(r.reviewer_id is null and r.photo_paths = '{}', '74 purge client: avaliação dada fica sem autoria e sem fotos');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.reviews where job_id = jp1 and reviewee_id = b and reply is not null) = 1
      and (select photo_paths from public.reviews where job_id = jp1 and reviewer_id = b) = array[b::text || '/review_9.jpg'], '75 purge client: avaliações do papel profissional intactas (resposta e fotos)');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.jobs where id = jp1 and provider_id = b and provider_report is not null) = 1
      and (select count(*) from public.withdrawals where provider_id = b) = 1
      and (select count(*) from public.payments where job_id = jp1 and provider_id = b) = 1, '76 purge client: serviços, relatório, pagamentos e saques do profissional intactos');
    v_acc := v_acc || pg_temp.chk((v #> '{storage,job_media}') @> to_jsonb(array[b::text || '/ticket_1.jpg', b::text || '/job_1.jpg'])
      and (v #> '{storage,public_media}') @> to_jsonb(array[b::text || '/review_1.jpg'])
      and not ((v #> '{storage,public_media}') @> to_jsonb(array[b::text || '/review_9.jpg']))
      and not ((v #> '{storage,job_media}') @> to_jsonb(array[b::text || '/ev_overview_1.jpg'])), '77 purge client: devolve só os arquivos do papel cliente (ticket, job, review dado) p/ o Storage');
    select count(*) into n from public.account_deletion_log where user_hash = encode(extensions.digest(b::text, 'sha256'), 'hex') and scope = 'client' and was_client and not was_provider;
    v_acc := v_acc || pg_temp.chk(n = 1, '78 purge client: auditoria com scope=client (was_client, não was_provider)');
    v_acc := v_acc || pg_temp.chk(public.is_public_provider(b), '79 purge client: b continua profissional público ativo');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco purge client falhou: ' || sqlerrm); end if;
  end;

  -- ===== 5. PURGA 'provider' =====
  begin
    update public.profiles set last_mode = 'provider' where id = b;
    v := public.purge_account(b, 'provider');
    v_acc := v_acc || pg_temp.chk(v ->> 'scope' = 'provider' and (v ->> 'account_removed')::boolean = false
                                  and (v ->> 'jobs_deleted')::int = 0 and (v ->> 'jobs_retained')::int = 0, '80 purge provider: retorno {scope, account_removed=false, deleted=0, retained=0}');
    select is_client, is_provider, provider_setup_done, client_setup_done, last_mode, verification_status::text as vs, bio into r from public.profiles where id = b;
    v_acc := v_acc || pg_temp.chk(r.is_client and not r.is_provider and not r.provider_setup_done and r.client_setup_done
                                  and r.vs = 'NOT_SUBMITTED' and r.last_mode = 'client', '81 purge provider: is_provider=false, NOT_SUBMITTED, is_client mantido, last_mode provider -> client');
    v_acc := v_acc || pg_temp.chk(not public.is_public_provider(b), '82 purge provider: deixa de ser profissional público');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.provider_profiles where user_id = b) = 0
      and (select count(*) from public.provider_portfolio where provider_id = b) = 0
      and (select count(*) from public.provider_certificates where provider_id = b) = 0
      and (select count(*) from public.provider_achievements where provider_id = b) = 0
      and (select count(*) from public.provider_case_pins where provider_id = b) = 0
      and (select count(*) from public.job_evidence where provider_id = b) = 0
      and (select count(*) from public.kyc_submissions where user_id = b) = 0, '83 purge provider: perfil, portfólio, certificados, conquistas, pins, evidências e KYC apagados');
    select quote_count into n from public.jobs where id = jp2;
    v_acc := v_acc || pg_temp.chk((select count(*) from public.quotes where provider_id = b and status = 'pending') = 0 and n = 0, '84 purge provider: orçamento pendente sai e quote_count do pedido acompanha (' || n || ')');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.messages where provider_id = b) = 0, '85 purge provider: conversas como profissional apagadas');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.messages where job_id = jc1 and sender_id = b) = 1, '86 purge provider: conversa do papel cliente intacta');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.jobs where client_id = b) = 3
      and (select count(*) from public.jobs where id = jc3 and description = 'segredo') = 1
      and (select count(*) from public.payments where client_id = b and status = 'released') = 2, '87 purge provider: pedidos e pagamentos do cliente (3 pedidos, 2 pagamentos) intactos, sem anonimização');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.client_wallets where client_id = b) = 1
      and (select count(*) from public.wallet_statement where client_id = b) >= 1
      and (select count(*) from public.pix_topups where client_id = b) = 1
      and (select count(*) from public.ledger_lines where account like 'client:' || b::text || ':%') >= 1
      and (select count(*) from public.support_tickets where user_id = b) = 1, '88 purge provider: carteira, extrato, Pix, ledger e chamados do cliente intactos');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.jobs where id = jp1 and provider_id = b and provider_report is null) = 1
      and (select count(*) from public.payments where job_id = jp1 and provider_id = b and status = 'released') = 1
      and (select count(*) from public.withdrawals where provider_id = b) = 1, '89 purge provider: serviço fica sem relatório; pagamentos e saques ficam como registro');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.reviews where job_id = jp1 and reviewee_id = b and reply is null and rating = 4) = 1
      and (select count(*) from public.reviews where job_id = jp1 and reviewee_id = o and reviewer_id is null and photo_paths = '{}') = 1, '90 purge provider: avaliação recebida fica (sem a resposta); a escrita por ele perde autoria/fotos');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.reviews where job_id = jc1 and reviewer_id = b and photo_paths = array[b::text || '/review_1.jpg']) = 1
      and (select count(*) from public.reviews where job_id = jc1 and reviewee_id = b) = 1, '91 purge provider: avaliações do papel cliente intactas');
    v_acc := v_acc || pg_temp.chk((v #> '{storage,public_media}') @> to_jsonb(array[b::text || '/portfolio_1.jpg', b::text || '/review_9.jpg'])
      and (v #> '{storage,job_media}') @> to_jsonb(array[b::text || '/ev_overview_1.jpg'])
      and not ((v #> '{storage,job_media}') @> to_jsonb(array[b::text || '/job_1.jpg', b::text || '/ticket_1.jpg']))
      and not ((v #> '{storage,public_media}') @> to_jsonb(array[b::text || '/review_1.jpg'])), '92 purge provider: devolve só os arquivos do papel profissional p/ o Storage');
    select count(*) into n from public.account_deletion_log where user_hash = encode(extensions.digest(b::text, 'sha256'), 'hex') and scope = 'provider' and was_provider and not was_client;
    v_acc := v_acc || pg_temp.chk(n = 1, '93 purge provider: auditoria com scope=provider');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.ledger_txns t where (select coalesce(sum(cents), 0) from public.ledger_lines l where l.txn_id = t.id) <> 0) = 0, '94 purge provider: ledger intacto e balanceado');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco purge provider falhou: ' || sqlerrm); end if;
  end;

  -- ===== 6. PURGA 'all' (não apaga auth.users; só dados) =====
  begin
    v := public.purge_account(b, 'all');
    v_acc := v_acc || pg_temp.chk(v ->> 'scope' = 'all' and (v ->> 'account_removed')::boolean and (v ->> 'jobs_deleted')::int = 1 and (v ->> 'jobs_retained')::int = 2, '95 purge all: retorno {scope=all, account_removed=true, deleted=1, retained=2}');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.jobs where id = jc3) = 0
      and (select count(*) from public.jobs where id in (jc1, jc2) and description = '[conteúdo removido a pedido do titular]' and address_summary is null) = 2, '96 purge all: pedido sem pagamento removido; pagos anonimizados');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.client_wallets where client_id = b) = 0
      and (select count(*) from public.ledger_lines where account like '%' || b::text || '%') = 0, '97 purge all: carteira apagada e nenhuma conta contábil com o id do usuário (cliente e profissional)');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.ledger_txns t where (select coalesce(sum(cents), 0) from public.ledger_lines l where l.txn_id = t.id) <> 0) = 0
      and (select count(*) from (select account from public.ledger_lines where account like 'client:removed-%' group by account having sum(cents) <> 0) z) = 0, '98 purge all: ledger balanceado e contas removidas em 0');
    v_acc := v_acc || pg_temp.chk((select count(*) from public.jobs where id = jp1 and provider_report is null) = 1, '99 purge all: relatório do profissional removido');
    select count(*) into n from public.account_deletion_log where user_hash = encode(extensions.digest(b::text, 'sha256'), 'hex') and scope = 'all' and was_client and was_provider;
    v_acc := v_acc || pg_temp.chk(n = 1, '100 purge all: auditoria com scope=all (was_client e was_provider)');
    -- simula o deleteUser da Edge Function: o perfil some e o histórico da outra parte permanece
    delete from public.profiles where id = b;
    v_acc := v_acc || pg_temp.chk((select count(*) from public.payments where job_id in (jc1, jc2) and client_id is null) = 2
      and (select count(*) from public.payments where job_id = jp1 and provider_id is null) = 1
      and (select count(*) from public.jobs where id = jp1) = 1, '101 purge all + deleteUser: pagamentos e serviço da contraparte sobrevivem sem vínculo');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco purge all falhou: ' || sqlerrm); end if;
  end;
  begin
    v := public.purge_account(o, 'client');   -- só cliente: client vira all
    v_acc := v_acc || pg_temp.chk(v ->> 'scope' = 'all' and (v ->> 'account_removed')::boolean, '102 purge de conta só-cliente com scope client vira all');
    raise exception 'ROLLBACK_SUB' using errcode = 'P0999';
  exception when others then
    if sqlstate <> 'P0999' then v_acc := v_acc || pg_temp.chk(false, 'bloco purge o falhou: ' || sqlerrm); end if;
  end;

  -- replay dos resultados acumulados nas subtransações revertidas
  for r in select e ->> 'n' as nm, (e ->> 'ok')::boolean as ok from jsonb_array_elements(v_acc) e loop
    perform pg_temp.t(r.ok, r.nm);
  end loop;

  -- ===== 7. PERMISSÕES / RLS =====
  perform pg_temp.login(b);
  begin
    perform public.purge_account(b, 'client');
    perform pg_temp.t(false, '103 authenticated executou purge_account PERMITIDO');
  exception when others then perform pg_temp.t(sqlstate = '42501', '103 purge_account é só service_role (' || sqlstate || ')'); end;
  begin
    perform public.account_dossier(b, 'client');
    perform pg_temp.t(false, '104 authenticated executou account_dossier PERMITIDO');
  exception when others then perform pg_temp.t(sqlstate = '42501', '104 account_dossier é só service_role (' || sqlstate || ')'); end;
  begin
    perform public._deletion_blockers(b, 'client');
    perform pg_temp.t(false, '105 authenticated executou _deletion_blockers PERMITIDO');
  exception when others then perform pg_temp.t(sqlstate = '42501', '105 _deletion_blockers é interno (' || sqlstate || ')'); end;
  begin
    perform public._normalize_deletion_scope(b, 'client');
    perform pg_temp.t(false, '106 authenticated executou _normalize_deletion_scope PERMITIDO');
  exception when others then perform pg_temp.t(sqlstate = '42501', '106 _normalize_deletion_scope é interno (' || sqlstate || ')'); end;
  v := public.account_deletion_status('client');
  perform pg_temp.t(v ->> 'scope' = 'client' and v ? 'available' and v ? 'held' and v ? 'active_jobs' and v ? 'blockers' and v ? 'can_delete', '107 account_deletion_status(client): mesmo formato de hoje + scope');
  perform pg_temp.t(public.account_deletion_status('provider') ->> 'scope' = 'provider' and public.account_deletion_status() ->> 'scope' = 'all', '108 account_deletion_status(provider) e default (sem argumento) = all');
  begin
    perform public.account_deletion_status('invalido');
    perform pg_temp.t(false, '109 status com escopo inválido PERMITIDO');
  exception when others then perform pg_temp.t(true, '109 account_deletion_status recusa escopo inválido'); end;
  reset role;
  perform pg_temp.login(o);
  begin
    perform public.account_deletion_status('provider');
    perform pg_temp.t(false, '110 cliente puro pediu status de provider PERMITIDO');
  exception when others then perform pg_temp.t(true, '110 status recusa escopo de papel que a conta não tem'); end;
  perform pg_temp.t(public.account_deletion_status('client') ->> 'scope' = 'all', '111 só cliente: status(client) é normalizado para all');
  reset role;
  execute 'set local role anon';
  begin
    perform public.account_deletion_status('client');
    perform pg_temp.t(false, '112 anon executou account_deletion_status PERMITIDO');
  exception when others then perform pg_temp.t(true, '112 anon sem acesso ao status'); end;
  begin
    perform public.account_dossier(b, 'client');
    perform pg_temp.t(false, '113 anon executou account_dossier PERMITIDO');
  exception when others then perform pg_temp.t(true, '113 anon sem acesso ao dossiê'); end;
  reset role;

  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (EXCLUSÃO POR ESCOPO) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;

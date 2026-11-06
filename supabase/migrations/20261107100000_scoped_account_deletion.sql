-- =============================================================================
-- Exclusao de conta POR ESCOPO (cliente | profissional | tudo) + Dossie rico.
--
-- Uma mesma conta pode ser cliente E profissional. Antes, excluir apagava SEMPRE
-- a conta inteira. Agora o escopo decide o que sai:
--   'client'   -> so dados e papel de CLIENTE (a conta e o papel profissional ficam)
--   'provider' -> so dados e papel de PROFISSIONAL (a conta e o papel cliente ficam)
--   'all'      -> conta inteira (purga + a Edge Function apaga auth.users)
--
-- Funcoes (mesmos nomes; parametro novo com DEFAULT 'all' para compatibilidade):
--   _normalize_deletion_scope(uuid, text)   normalizacao pura do escopo
--   _deletion_blockers(uuid, text)          trava financeira POR ESCOPO
--   account_deletion_status(text)           tela (authenticated)
--   account_dossier(uuid, text)             dados do PDF (service_role)
--   purge_account(uuid, text)               limpeza LGPD (service_role)
--
-- LEDGER (partida dobrada) ao remover o papel de cliente:
--   * `ledger_txns`/`ledger_lines` NAO sao apagados (registro financeiro, soma zero
--     por transacao). Em vez disso:
--       1. as contas contabeis 'client:<uuid>:*' sao RENOMEADAS para um token
--          aleatorio ('client:removed-<token>:*'): o registro financeiro permanece,
--          sem vinculo com a pessoa (nem por hash);
--       2. o saldo remanescente dessas contas e ZERADO por uma transacao de
--          encerramento (kind 'closure', contra 'platform:account_closure'), entao
--          cada conta contabil fecha em 0 e nenhuma transacao fica desbalanceada;
--       3. a chave de idempotencia 'seed:<uuid>' vira 'seed:<token>' (assim um
--          eventual novo cadastro como cliente recebe um seed novo com lancamento).
--   * client_wallets, wallet_statement e pix_topups do cliente sao apagados (o
--     saldo de homologacao e perdido; nao ha dinheiro real nesta fase).
--   * Em 'all' o mesmo vale para o cliente, e as contas 'provider:<uuid>:*' tambem
--     sao renomeadas (o saldo do profissional ja e zero pela trava).
-- ADR-0013, ADR-0018.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. Auditoria com escopo + ledger aceita o lancamento de encerramento
-- ---------------------------------------------------------------------------
alter table public.account_deletion_log add column if not exists scope text not null default 'all';
alter table public.account_deletion_log drop constraint if exists account_deletion_log_scope_check;
alter table public.account_deletion_log add constraint account_deletion_log_scope_check
  check (scope in ('client', 'provider', 'all'));

do $$
declare c record;
begin
  for c in
    select con.conname from pg_constraint con
     where con.conrelid = 'public.ledger_txns'::regclass and con.contype = 'c'
       and pg_get_constraintdef(con.oid) like '%kind%'
  loop
    execute format('alter table public.ledger_txns drop constraint %I', c.conname);
  end loop;
  alter table public.ledger_txns add constraint ledger_txns_kind_check
    check (kind in ('seed', 'topup', 'hold', 'release', 'refund', 'withdrawal', 'closure'));
end $$;

-- ---------------------------------------------------------------------------
-- 1. Normalizacao do escopo
--    * nulo/vazio -> 'all'; valor desconhecido -> erro
--    * 'client' exige is_client; 'provider' exige is_provider (senao erro: nunca
--      "promove" um pedido de escopo parcial para exclusao total por engano)
--    * conta com UM so papel, ou escopo que cobre todos os papeis da conta -> 'all'
--    * conta sem nenhum papel (cadastro nao concluido) -> 'all'
-- ---------------------------------------------------------------------------
create or replace function public._normalize_deletion_scope(p_user uuid, p_scope text)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  v_scope text := lower(btrim(coalesce(p_scope, '')));
  v_c boolean; v_p boolean;
begin
  if v_scope = '' then v_scope := 'all'; end if;
  if v_scope not in ('client', 'provider', 'all') then
    raise exception 'Escopo de exclusão inválido.' using errcode = '22023';
  end if;
  if v_scope = 'all' then return 'all'; end if;

  select is_client, is_provider into v_c, v_p from public.profiles where id = p_user;
  if not found then return 'all'; end if;
  v_c := coalesce(v_c, false);
  v_p := coalesce(v_p, false);

  if not v_c and not v_p then return 'all'; end if;
  if v_scope = 'client' and not v_c then
    raise exception 'A conta não possui o papel de cliente.' using errcode = 'P0001';
  end if;
  if v_scope = 'provider' and not v_p then
    raise exception 'A conta não possui o papel de profissional.' using errcode = 'P0001';
  end if;
  if v_c and v_p then return v_scope; end if;   -- dois papeis: escopo parcial vale
  return 'all';                                  -- um papel so: cobre tudo
end $$;
revoke all on function public._normalize_deletion_scope(uuid, text) from public, anon, authenticated;
grant execute on function public._normalize_deletion_scope(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Trava financeira por escopo (mesmo formato de hoje + 'scope')
-- ---------------------------------------------------------------------------
drop function if exists public.account_deletion_status();
drop function if exists public._deletion_blockers(uuid);

create or replace function public._deletion_blockers(p_user uuid, p_scope text default 'all')
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_scope text := public._normalize_deletion_scope(p_user, p_scope);
  v_av numeric := 0; v_held numeric := 0;
  v_cl_escrow_n int := 0; v_cl_escrow numeric := 0;
  v_active int := 0; v_codes text[] := '{}';
  c_active constant text[] := array['scheduled', 'in_progress', 'awaiting_approval', 'disputed'];
begin
  -- Profissional: saldo livre e valor em custodia da carteira de saques.
  if v_scope in ('provider', 'all') then
    select available, held into v_av, v_held from public._wallet_of(p_user);
  end if;
  -- Cliente: valor em custodia (escrow) dos pagamentos do cliente.
  if v_scope in ('client', 'all') then
    select count(*), coalesce(sum(amount), 0) into v_cl_escrow_n, v_cl_escrow
      from public.payments where client_id = p_user and status = 'escrow';
  end if;

  select count(*) into v_active from public.jobs
   where status = any (c_active)
     and ((v_scope in ('client', 'all') and client_id = p_user)
       or (v_scope in ('provider', 'all') and provider_id = p_user));

  if round(v_av, 2) > 0 then v_codes := array_append(v_codes, 'balance'); end if;
  if round(v_held, 2) > 0 or v_cl_escrow_n > 0 then v_codes := array_append(v_codes, 'escrow'); end if;
  if v_active > 0 then v_codes := array_append(v_codes, 'active_jobs'); end if;

  return jsonb_build_object(
    'scope', v_scope,
    'available', round(v_av, 2), 'held', round(v_held + v_cl_escrow, 2),
    'active_jobs', v_active, 'blockers', to_jsonb(v_codes),
    'can_delete', cardinality(v_codes) = 0);
end $$;
revoke all on function public._deletion_blockers(uuid, text) from public, anon, authenticated;
grant execute on function public._deletion_blockers(uuid, text) to service_role;

-- Tela "Excluir conta": decide entre BottomSheet do Pix e a chamada de offboarding.
create or replace function public.account_deletion_status(p_scope text default 'all')
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  return public._deletion_blockers(auth.uid(), p_scope);
end $$;
revoke all on function public.account_deletion_status(text) from public, anon;
grant execute on function public.account_deletion_status(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Dossie de despedida (PDF): so as secoes do escopo, bem mais dados.
--    Chaves antigas preservadas (client.orders/total_spent/total_saved,
--    provider.jobs/total_gross/total_fee/total_profit/total_withdrawn/quotes/
--    reviews e totals.{spent,saved,profit}).
--    Economia = media dos orcamentos recebidos (nao retirados) - valor contratado,
--    so em pedidos concluidos com >= 2 orcamentos (regra anterior, inalterada).
-- ---------------------------------------------------------------------------
drop function if exists public.account_dossier(uuid);

create or replace function public.account_dossier(p_user uuid, p_scope text default 'all')
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_prof record; v_scope text;
  v_roles text[] := '{}';
  v_m0 timestamp := date_trunc('month', timezone('UTC', now())) - interval '11 months';
  v_client jsonb := null; v_prov jsonb := null; v_out jsonb;
  -- cliente
  c_orders jsonb; c_monthly jsonb; c_bycat jsonb; c_bystatus jsonb; c_rev jsonb; c_top jsonb;
  c_spent numeric := 0; c_saved numeric := 0; c_paid_n int := 0; c_done_n int := 0; c_orders_n int := 0;
  -- profissional
  p_jobs jsonb; p_monthly jsonb; p_bycat jsonb; p_quotes jsonb; p_revs jsonb; p_wd jsonb; p_dist jsonb;
  p_gross numeric := 0; p_fee numeric := 0; p_net numeric := 0; p_withdrawn numeric := 0;
  p_jobs_n int := 0; p_done_n int := 0; p_q_total int := 0; p_q_acc int := 0;
  p_rating numeric := 0; p_rev_n int := 0; p_ach int := 0;
begin
  select id, full_name, is_client, is_provider, created_at into v_prof from public.profiles where id = p_user;
  if not found then
    raise exception 'Conta inexistente.' using errcode = 'P0002';
  end if;
  v_scope := public._normalize_deletion_scope(p_user, p_scope);

  if v_scope = 'client' then v_roles := array['client'];
  elsif v_scope = 'provider' then v_roles := array['provider'];
  else
    if coalesce(v_prof.is_client, false) then v_roles := array_append(v_roles, 'client'); end if;
    if coalesce(v_prof.is_provider, false) then v_roles := array_append(v_roles, 'provider'); end if;
  end if;

  -- ======================= CLIENTE =======================
  if v_scope in ('client', 'all') then
    select count(*) into c_orders_n from public.jobs where client_id = p_user;
    select count(*) into c_done_n from public.jobs where client_id = p_user and status = 'completed';

    select coalesce(jsonb_agg(x.o order by x.ca desc), '[]'::jsonb) into c_orders
      from (
        select j.created_at as ca,
               jsonb_build_object(
                 'id', upper(left(j.id::text, 8)), 'title', j.title, 'category', j.category, 'status', j.status,
                 'created_at', j.created_at, 'scheduled_for', j.scheduled_for, 'started_at', j.started_at,
                 'finished_at', coalesce(j.approved_at, j.finished_at),
                 'partner', public._short_name(pr.full_name),
                 'price', j.agreed_price, 'paid', p.amount, 'payment_status', p.status,
                 'quotes_received', coalesce(qs.n, 0),
                 'avg_other_quotes', case when coalesce(qs.n, 0) >= 2 then round(qs.a, 2) else null end,
                 'saved', case when j.status = 'completed' and j.agreed_price is not null and coalesce(qs.n, 0) >= 2
                               then round(greatest(0, qs.a - j.agreed_price), 2) else 0 end) as o
          from public.jobs j
          left join public.profiles pr on pr.id = j.provider_id
          left join lateral (select pp.amount, pp.status from public.payments pp
                              where pp.job_id = j.id order by pp.created_at desc limit 1) p on true
          left join lateral (select count(*) as n, avg(q.price) as a from public.quotes q
                              where q.job_id = j.id and q.status <> 'withdrawn') qs on true
         where j.client_id = p_user
         order by j.created_at desc
         limit 1000) x;

    select coalesce(sum(amount), 0), count(*) into c_spent, c_paid_n
      from public.payments where client_id = p_user and status = 'released';

    select coalesce(sum(greatest(0, s.avg_price - j.agreed_price)), 0) into c_saved
      from public.jobs j
      join lateral (select avg(q.price) as avg_price, count(*) as n
                      from public.quotes q where q.job_id = j.id and q.status <> 'withdrawn') s on s.n >= 2
     where j.client_id = p_user and j.status = 'completed' and j.agreed_price is not null;

    select coalesce(jsonb_agg(jsonb_build_object(
             'month', to_char(m.d, 'YYYY-MM'),
             'spent', round(coalesce(sp.v, 0), 2), 'saved', round(coalesce(sv.v, 0), 2),
             'orders', coalesce(oc.v, 0)) order by m.d), '[]'::jsonb)
      into c_monthly
      from generate_series(v_m0, v_m0 + interval '11 months', interval '1 month') m(d)
      left join (select date_trunc('month', timezone('UTC', coalesce(released_at, created_at))) as mth, sum(amount) as v
                   from public.payments where client_id = p_user and status = 'released' group by 1) sp on sp.mth = m.d
      left join (select date_trunc('month', timezone('UTC', coalesce(j.approved_at, j.finished_at, j.created_at))) as mth,
                        sum(greatest(0, s.a - j.agreed_price)) as v
                   from public.jobs j
                   join lateral (select avg(q.price) as a, count(*) as n from public.quotes q
                                  where q.job_id = j.id and q.status <> 'withdrawn') s on s.n >= 2
                  where j.client_id = p_user and j.status = 'completed' and j.agreed_price is not null
                  group by 1) sv on sv.mth = m.d
      left join (select date_trunc('month', timezone('UTC', created_at)) as mth, count(*) as v
                   from public.jobs where client_id = p_user group by 1) oc on oc.mth = m.d;

    select coalesce(jsonb_agg(jsonb_build_object('category', c.cat, 'orders', c.n, 'spent', round(c.s, 2))
                              order by c.s desc, c.n desc, c.cat), '[]'::jsonb)
      into c_bycat
      from (select coalesce(nullif(btrim(j.category), ''), 'Outros') as cat,
                   count(distinct j.id) as n,
                   coalesce(sum(p.amount) filter (where p.status = 'released'), 0) as s
              from public.jobs j
              left join public.payments p on p.job_id = j.id and p.client_id = p_user
             where j.client_id = p_user group by 1) c;

    select coalesce(jsonb_object_agg(s.status, s.n), '{}'::jsonb) into c_bystatus
      from (select status, count(*) as n from public.jobs where client_id = p_user group by 1) s;

    select jsonb_build_object('count', count(*), 'avg', coalesce(round(avg(r.rating), 2), 0)) into c_rev
      from public.reviews r join public.jobs j on j.id = r.job_id
     where r.reviewer_id = p_user and j.client_id = p_user;

    select jsonb_build_object('total', coalesce(sum(amount_cents), 0) / 100.0, 'count', count(*)) into c_top
      from public.pix_topups where client_id = p_user and status = 'paid';

    v_client := jsonb_build_object(
      'orders', c_orders, 'orders_count', c_orders_n,
      'total_spent', c_spent, 'total_saved', round(c_saved, 2),
      'completed_count', c_done_n, 'paid_count', c_paid_n,
      'ticket_medio', case when c_paid_n > 0 then round(c_spent / c_paid_n, 2) else 0 end,
      'monthly', c_monthly, 'by_category', c_bycat, 'by_status', c_bystatus,
      'reviews_given', c_rev, 'wallet', c_top);
  end if;

  -- ======================= PROFISSIONAL =======================
  if v_scope in ('provider', 'all') then
    select count(*) into p_jobs_n from public.jobs where provider_id = p_user;
    select count(*) into p_done_n from public.jobs where provider_id = p_user and status = 'completed';

    select coalesce(jsonb_agg(x.o order by x.ca desc), '[]'::jsonb) into p_jobs
      from (
        select j.created_at as ca,
               jsonb_build_object(
                 'id', upper(left(j.id::text, 8)), 'title', j.title, 'category', j.category, 'status', j.status,
                 'created_at', j.created_at, 'scheduled_for', j.scheduled_for, 'started_at', j.started_at,
                 'finished_at', coalesce(j.approved_at, j.finished_at),
                 'partner', public._short_name(cl.full_name),
                 'price', j.agreed_price, 'gross', p.amount, 'fee', p.fee_amount, 'net', p.net_amount,
                 'payment_status', p.status) as o
          from public.jobs j
          left join public.profiles cl on cl.id = j.client_id
          left join lateral (select pp.amount, pp.fee_amount, pp.net_amount, pp.status from public.payments pp
                              where pp.job_id = j.id order by pp.created_at desc limit 1) p on true
         where j.provider_id = p_user
         order by j.created_at desc
         limit 1000) x;

    select coalesce(sum(amount), 0), coalesce(sum(fee_amount), 0), coalesce(sum(net_amount), 0)
      into p_gross, p_fee, p_net
      from public.payments where provider_id = p_user and status = 'released';
    select coalesce(sum(amount), 0) into p_withdrawn
      from public.withdrawals where provider_id = p_user and status <> 'failed';

    select coalesce(jsonb_agg(jsonb_build_object(
             'month', to_char(m.d, 'YYYY-MM'),
             'gross', round(coalesce(g.gross, 0), 2), 'net', round(coalesce(g.net, 0), 2),
             'fee', round(coalesce(g.fee, 0), 2), 'jobs', coalesce(g.n, 0)) order by m.d), '[]'::jsonb)
      into p_monthly
      from generate_series(v_m0, v_m0 + interval '11 months', interval '1 month') m(d)
      left join (select date_trunc('month', timezone('UTC', coalesce(released_at, created_at))) as mth,
                        sum(amount) as gross, sum(net_amount) as net, sum(fee_amount) as fee, count(*) as n
                   from public.payments where provider_id = p_user and status = 'released' group by 1) g on g.mth = m.d;

    select coalesce(jsonb_agg(jsonb_build_object('category', c.cat, 'jobs', c.n, 'gross', round(c.g, 2), 'net', round(c.nt, 2))
                              order by c.nt desc, c.n desc, c.cat), '[]'::jsonb)
      into p_bycat
      from (select coalesce(nullif(btrim(j.category), ''), 'Outros') as cat,
                   count(distinct j.id) as n,
                   coalesce(sum(p.amount) filter (where p.status = 'released'), 0) as g,
                   coalesce(sum(p.net_amount) filter (where p.status = 'released'), 0) as nt
              from public.jobs j
              left join public.payments p on p.job_id = j.id and p.provider_id = p_user
             where j.provider_id = p_user group by 1) c;

    select coalesce(jsonb_agg(jsonb_build_object(
             'job', upper(left(q.job_id::text, 8)), 'title', j.title, 'price', q.price,
             'status', q.status, 'created_at', q.created_at) order by q.created_at desc), '[]'::jsonb)
      into p_quotes
      from (select * from public.quotes where provider_id = p_user order by created_at desc limit 1000) q
      join public.jobs j on j.id = q.job_id;
    select count(*), count(*) filter (where status = 'accepted') into p_q_total, p_q_acc
      from public.quotes where provider_id = p_user;

    select coalesce(jsonb_agg(jsonb_build_object(
             'job', upper(left(r.job_id::text, 8)), 'rating', r.rating, 'comment', r.comment,
             'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb),
           count(*), coalesce(round(avg(r.rating), 2), 0),
           jsonb_build_object(
             '1', count(*) filter (where r.rating = 1), '2', count(*) filter (where r.rating = 2),
             '3', count(*) filter (where r.rating = 3), '4', count(*) filter (where r.rating = 4),
             '5', count(*) filter (where r.rating = 5))
      into p_revs, p_rev_n, p_rating, p_dist
      from public.reviews r join public.jobs j on j.id = r.job_id
     where r.reviewee_id = p_user and j.provider_id = p_user and r.revealed_at is not null;

    select count(*) into p_ach from public.provider_achievements where provider_id = p_user;

    select coalesce(jsonb_agg(jsonb_build_object(
             'created_at', w.created_at, 'amount', w.amount, 'status', w.status,
             'pix_key_type', w.pix_key_type, 'pix_key_hint', w.pix_key_hint) order by w.created_at desc), '[]'::jsonb)
      into p_wd
      from (select * from public.withdrawals where provider_id = p_user order by created_at desc limit 500) w;

    v_prov := jsonb_build_object(
      'jobs', p_jobs, 'jobs_count', p_jobs_n, 'completed_count', p_done_n,
      'total_gross', p_gross, 'total_fee', p_fee, 'total_profit', p_net, 'total_withdrawn', p_withdrawn,
      'monthly', p_monthly, 'by_category', p_bycat,
      'quotes', p_quotes, 'quotes_total', p_q_total, 'quotes_accepted', p_q_acc,
      'acceptance_rate', case when p_q_total > 0 then round(100.0 * p_q_acc / p_q_total, 1) else 0 end,
      'reviews', p_revs, 'reviews_count', p_rev_n, 'rating_avg', p_rating, 'rating_dist', p_dist,
      'achievements_count', p_ach, 'withdrawals', p_wd);
  end if;

  v_out := jsonb_build_object(
    'generated_at', now(), 'scope', v_scope,
    'name', v_prof.full_name, 'member_since', v_prof.created_at,
    'is_client', v_prof.is_client, 'is_provider', v_prof.is_provider,
    'scope_roles', to_jsonb(v_roles),
    'totals', jsonb_build_object('spent', c_spent, 'saved', round(c_saved, 2), 'profit', p_net));
  if v_client is not null then v_out := v_out || jsonb_build_object('client', v_client); end if;
  if v_prov is not null then v_out := v_out || jsonb_build_object('provider', v_prov); end if;
  return v_out;
end $$;
revoke all on function public.account_dossier(uuid, text) from public, anon, authenticated;
grant execute on function public.account_dossier(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Purga por escopo. A conta de autenticacao so e removida pela Edge Function
--    (Admin API) DEPOIS desta funcao, e SO quando o escopo final e 'all'.
--    Retorna tambem `storage`: caminhos EXATOS de arquivos (por bucket) cujas
--    linhas foram limpas aqui - a Edge Function os apaga (e so os do proprio uid).
-- ---------------------------------------------------------------------------
drop function if exists public.purge_account(uuid);

create or replace function public.purge_account(p_user uuid, p_scope text default 'all')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b jsonb; v_prof record; v_scope text;
  v_do_c boolean; v_do_p boolean; v_part boolean;
  v_deleted int := 0; v_retained int := 0;
  v_cjobs uuid[] := '{}';
  v_token text; v_acc record;
  v_pub text[] := '{}'; v_job text[] := '{}'; v_tmp text[];
begin
  select is_client, is_provider, last_mode into v_prof from public.profiles where id = p_user;
  if not found then
    raise exception 'Conta inexistente.' using errcode = 'P0002';
  end if;
  v_scope := public._normalize_deletion_scope(p_user, p_scope);
  v_do_c := v_scope in ('client', 'all');
  v_do_p := v_scope in ('provider', 'all');
  v_part := v_scope <> 'all';   -- a conta continua existindo: desvincula explicitamente

  -- Serializa com saques do mesmo usuario (mesma chave de request_withdrawal).
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 0));

  v_b := public._deletion_blockers(p_user, v_scope);
  if not (v_b ->> 'can_delete')::boolean then
    raise exception 'Exclusão bloqueada: %', v_b ->> 'blockers' using errcode = 'P0001';
  end if;

  -- ============================ CLIENTE ============================
  if v_do_c then
    select coalesce(array_agg(id), '{}') into v_cjobs from public.jobs where client_id = p_user;

    -- Arquivos exatos que serao orfaos: fotos dos pedidos, provas de chamados e fotos de avaliacao.
    select coalesce(array_agg(distinct ph), '{}') into v_tmp
      from public.jobs j, unnest(j.photo_paths) ph where j.client_id = p_user;
    v_job := v_job || v_tmp;
    select coalesce(array_agg(distinct ph), '{}') into v_tmp
      from public.reviews r join public.jobs j on j.id = r.job_id, unnest(r.photo_paths) ph
     where r.reviewer_id = p_user and (not v_part or j.client_id = p_user);
    v_pub := v_pub || v_tmp;

    if v_part then
      -- Chamados de suporte do cliente (sem pedido, ou de pedido dele): apagados com as provas.
      select coalesce(array_agg(distinct ph), '{}') into v_tmp
        from public.support_tickets t, unnest(t.evidence_paths) ph
       where t.user_id = p_user and (t.job_id is null or t.job_id = any (v_cjobs));
      v_job := v_job || v_tmp;
      delete from public.support_tickets where user_id = p_user and (job_id is null or job_id = any (v_cjobs));
      -- Conversa e notificacoes do cliente nos pedidos dele.
      delete from public.messages where sender_id = p_user and job_id = any (v_cjobs);
      delete from public.notifications where user_id = p_user and job_id = any (v_cjobs);
      -- Avaliacoes que o cliente RECEBEU do profissional sao dado sobre a pessoa: removidas.
      delete from public.reviews where reviewee_id = p_user and job_id = any (v_cjobs);
    end if;

    -- Pedidos do cliente sem pagamento: removidos por completo (cascata).
    with d as (
      delete from public.jobs j where j.client_id = p_user
         and not exists (select 1 from public.payments p where p.job_id = j.id)
      returning 1)
    select count(*) into v_deleted from d;

    -- Pedidos com pagamento: ficam (historico fiscal e do profissional), sem dado pessoal.
    select count(*) into v_retained from public.jobs where client_id = p_user;
    delete from public.job_addresses where job_id in (select id from public.jobs where client_id = p_user);
    delete from public.job_secrets   where job_id in (select id from public.jobs where client_id = p_user);
    update public.jobs
       set title = 'Serviço', description = '[conteúdo removido a pedido do titular]',
           photo_paths = '{}', address_summary = null, address_cep = null,
           latitude = null, longitude = null
     where client_id = p_user;

    -- Avaliacoes escritas pelo cliente: o texto fica para o profissional (historico dele), sem autoria.
    update public.reviews r set photo_paths = '{}'
     where r.reviewer_id = p_user
       and (not v_part or r.job_id in (select id from public.jobs where client_id = p_user));

    -- Carteira do cliente + ledger (ver cabecalho): renomeia, encerra o saldo e apaga a carteira.
    v_token := substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
    update public.ledger_lines
       set account = replace(account, 'client:' || p_user::text || ':', 'client:removed-' || v_token || ':')
     where account like 'client:' || p_user::text || ':%';
    update public.ledger_txns set idempotency_key = 'seed:removed-' || v_token
     where idempotency_key = 'seed:' || p_user::text;
    for v_acc in
      select l.account, sum(l.cents)::bigint as bal
        from public.ledger_lines l
       where l.account like 'client:removed-' || v_token || ':%'
       group by l.account having sum(l.cents) <> 0
    loop
      perform public._ledger_post('closure', 'closure:' || v_token || ':' || v_acc.account,
        'Encerramento da conta contábil (cliente removido)', null,
        jsonb_build_array(
          jsonb_build_object('account', v_acc.account, 'cents', -v_acc.bal),
          jsonb_build_object('account', 'platform:account_closure', 'cents', v_acc.bal)));
    end loop;
    delete from public.wallet_statement where client_id = p_user;
    delete from public.pix_topups       where client_id = p_user;
    delete from public.client_wallets   where client_id = p_user;

    if v_part then
      -- A conta fica: desvincula o historico financeiro e limpa o endereco de cliente.
      -- (latitude/longitude/cidade do perfil ficam: tambem servem a area de atuacao do profissional.)
      update public.payments set client_id = null where client_id = p_user;
      update public.reviews  set reviewer_id = null
       where reviewer_id = p_user and job_id in (select id from public.jobs where client_id = p_user);
      update public.jobs set canceled_by = null where client_id = p_user and canceled_by = p_user;
      update public.jobs set client_id = null where client_id = p_user;
      update public.profiles
         set is_client = false, client_setup_done = false, address_line = null,
             last_mode = case when last_mode = 'client' then 'provider' else last_mode end
       where id = p_user;
    end if;
  end if;

  -- ============================ PROFISSIONAL ============================
  if v_do_p then
    -- Trabalhos como profissional: o relatorio e do autor; o cliente mantem o historico.
    update public.jobs set provider_report = null where provider_id = p_user;

    if v_part then
      -- Arquivos exatos: portfolio (public-media) e evidencias de servico (job-media).
      select coalesce(array_agg(image_path), '{}') into v_tmp from public.provider_portfolio where provider_id = p_user;
      v_pub := v_pub || v_tmp;
      select coalesce(array_agg(path), '{}') into v_tmp from public.job_evidence where provider_id = p_user;
      v_job := v_job || v_tmp;
      select coalesce(array_agg(distinct ph), '{}') into v_tmp
        from public.reviews r join public.jobs j on j.id = r.job_id, unnest(r.photo_paths) ph
       where r.reviewer_id = p_user and j.provider_id = p_user;
      v_pub := v_pub || v_tmp;

      delete from public.job_evidence         where provider_id = p_user;
      delete from public.provider_case_pins   where provider_id = p_user;
      delete from public.provider_achievements where provider_id = p_user;
      delete from public.provider_certificates where provider_id = p_user;
      delete from public.provider_portfolio    where provider_id = p_user;
      delete from public.job_invites           where provider_id = p_user;
      delete from public.messages              where provider_id = p_user;
      delete from public.notifications
       where user_id = p_user and job_id in (select id from public.jobs where provider_id = p_user);

      -- Orcamentos pendentes saem (e o contador do pedido acompanha); os demais ficam como historico.
      update public.jobs j set quote_count = greatest(j.quote_count - q.n, 0)
        from (select job_id, count(*)::int as n from public.quotes
               where provider_id = p_user and status = 'pending' group by job_id) q
       where j.id = q.job_id;
      delete from public.quotes where provider_id = p_user and status = 'pending';

      -- Avaliacoes: as que o profissional escreveu perdem autoria/fotos; resposta dele a avaliacoes recebidas sai.
      update public.reviews r set photo_paths = '{}', reviewer_id = null
       where r.reviewer_id = p_user and r.job_id in (select id from public.jobs where provider_id = p_user);
      update public.reviews r set reply = null, reply_at = null
       where r.reviewee_id = p_user and r.job_id in (select id from public.jobs where provider_id = p_user);

      delete from public.kyc_submissions where user_id = p_user;
      delete from public.provider_profiles where user_id = p_user;
      update public.profiles
         set is_provider = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED',
             bio = null,
             last_mode = case when last_mode = 'provider' then 'client' else last_mode end
       where id = p_user;
    else
      -- 'all': a conta inteira sai; so as contas contabeis do profissional perdem o vinculo.
      v_token := substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
      update public.ledger_lines
         set account = replace(account, 'provider:' || p_user::text || ':', 'provider:removed-' || v_token || ':')
       where account like 'provider:' || p_user::text || ':%';
    end if;
  end if;

  insert into public.account_deletion_log (user_hash, was_client, was_provider, jobs_deleted, jobs_retained, scope)
  values (encode(extensions.digest(p_user::text, 'sha256'), 'hex'),
          v_do_c and coalesce(v_prof.is_client, false), v_do_p and coalesce(v_prof.is_provider, false),
          v_deleted, v_retained, v_scope);

  return jsonb_build_object(
    'scope', v_scope, 'account_removed', v_scope = 'all',
    'jobs_deleted', v_deleted, 'jobs_retained', v_retained,
    'storage', jsonb_build_object('public_media', to_jsonb(v_pub), 'job_media', to_jsonb(v_job)));
end $$;
revoke all on function public.purge_account(uuid, text) from public, anon, authenticated;
grant execute on function public.purge_account(uuid, text) to service_role;

commit;

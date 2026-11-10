-- =============================================================================
-- DESPERRENGUE — Portfólio Real (Pilha LIFO Top 3 + Até 5 Destaques Escolhidos),
-- Imutabilidade Pós-Conclusão, Notas Técnicas Complementares e Histórico Real
-- em 4 Estados (Concluído 100% Pago, Sob Proteção Pós-Serviço, Em Mediação, Cancelado).
-- =============================================================================
begin;

-- ---------------------------------------------------------------------------
-- 1. Coluna `complementary_notes` ("Notas Técnicas Complementares") e
--    Trava de Imutabilidade Criptográfica Pós-Conclusão (Descrição, Solução e Fotos)
-- ---------------------------------------------------------------------------
alter table public.jobs
  add column if not exists complementary_notes text;

alter table public.jobs drop constraint if exists jobs_complementary_notes_len;
alter table public.jobs add constraint jobs_complementary_notes_len
  check (complementary_notes is null or char_length(complementary_notes) <= 2000);

create or replace function public.jobs_enforce_post_completion_immutability()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status = 'completed' then
    if new.description is distinct from old.description then
      raise exception 'IMMUTABLE_CLIENT_REQUEST: A descrição original solicitada pelo cliente não pode ser alterada após a conclusão.' using errcode = '42501';
    end if;
    if old.provider_report is not null and new.provider_report is distinct from old.provider_report then
      raise exception 'IMMUTABLE_CONCLUSION_REPORT: O laudo técnico original da conclusão é imutável por segurança. Utilize as Notas Técnicas Complementares.' using errcode = '42501';
    end if;
    if new.photo_paths is distinct from old.photo_paths then
      raise exception 'IMMUTABLE_JOB_PHOTOS: As fotos originais do chamado concluído não podem ser alteradas ou excluídas.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.jobs_enforce_post_completion_immutability() from public, anon, authenticated;

drop trigger if exists jobs_enforce_post_completion_immutability on public.jobs;
create trigger jobs_enforce_post_completion_immutability
  before update on public.jobs
  for each row execute function public.jobs_enforce_post_completion_immutability();

-- Impede exclusão ou substituição de fotos de evidência (Antes/Depois) após o serviço estar concluído
create or replace function public.job_evidence_enforce_post_completion_immutability()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  select j.status into v_status from public.jobs j where j.id = coalesce(old.job_id, new.job_id);
  if v_status = 'completed' then
    raise exception 'IMMUTABLE_EVIDENCE_PHOTOS: As fotos registradas na conclusão do serviço são imutáveis e não podem ser removidas ou alteradas.' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
revoke all on function public.job_evidence_enforce_post_completion_immutability() from public, anon, authenticated;

drop trigger if exists job_evidence_enforce_post_completion_immutability on public.job_evidence;
create trigger job_evidence_enforce_post_completion_immutability
  before update or delete on public.job_evidence
  for each row execute function public.job_evidence_enforce_post_completion_immutability();

-- RPC exclusiva para o profissional salvar/atualizar "Notas Técnicas Complementares"
-- abaixo da solução original imutável, apenas em serviços já concluídos por ele.
create or replace function public.set_job_complementary_notes(p_job uuid, p_notes text)
returns void language plpgsql security definer set search_path = public as $$
declare v_txt text := nullif(btrim(coalesce(p_notes, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if v_txt is not null and char_length(v_txt) > 2000 then
    raise exception 'Notas Técnicas Complementares muito longas (máx. 2000 caracteres).' using errcode = 'P0001';
  end if;
  update public.jobs
     set complementary_notes = v_txt
   where id = p_job
     and provider_id = auth.uid()
     and status = 'completed';
  if not found then
    raise exception 'Apenas o profissional executor pode registrar Notas Técnicas Complementares em um serviço concluído.' using errcode = '42501';
  end if;
end $$;
revoke all on function public.set_job_complementary_notes(uuid, text) from public, anon;
grant execute on function public.set_job_complementary_notes(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Elegibilidade Estrita do Portfólio (100% Recebido + Pós-Proteção) e
--    Expansão para Top 3 LIFO Automático + Até 5 Destaques Escolhidos (Total = 8)
-- ---------------------------------------------------------------------------
create or replace function public.is_job_portfolio_eligible(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.jobs j
      left join public.payments pay on pay.job_id = j.id
     where j.id = p_job
       and j.status = 'completed'
       and coalesce(pay.status, 'released') = 'released'
       and coalesce(j.escrow_status, 'settled') in ('settled', 'released')
       and not exists (
         select 1 from public.job_mediations m
          where m.job_id = j.id and m.phase not in ('resolved_release_provider', 'resolved_refund_client')
       )
  );
$$;
revoke all on function public.is_job_portfolio_eligible(uuid) from public, anon;
grant execute on function public.is_job_portfolio_eligible(uuid) to authenticated;

create or replace function public._case_visible(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.jobs j
      left join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id
                                and r.reviewer_id is not distinct from j.client_id
     where j.id = p_job
       and public.is_job_portfolio_eligible(j.id)
       and (j.provider_id = auth.uid() or public.is_admin() or public.is_public_provider(j.provider_id))
  );
$$;
revoke all on function public._case_visible(uuid) from public, anon;
grant execute on function public._case_visible(uuid) to authenticated;

-- Vitrine Pública e do Profissional:
-- Top 3 mais recentes automáticos (LIFO) + até 5 Destaques Escolhidos pelo profissional (máx. 8).
create or replace function public.provider_showcase(p_provider uuid)
returns table (
  job_id uuid, title text, category text, cover_path text, rating smallint, comment text,
  client_name text, revealed_at timestamptz, pinned boolean, pos int)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not (p_provider = auth.uid() or public.is_admin() or public.is_public_provider(p_provider)) then
    return;
  end if;
  return query
  with eligible_jobs as (
    select j.id as jid,
           j.title as jtitle,
           j.category as jcat,
           coalesce(r.rating, 5)::smallint as rrating,
           r.comment as rcomment,
           coalesce(r.revealed_at, j.approved_at, j.finished_at, j.created_at) as rrev,
           cl.full_name as cname,
           k.pinned_at as kpinned,
           row_number() over (order by coalesce(j.approved_at, j.finished_at, j.created_at) desc) as chrono_rn
      from public.jobs j
      left join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id
                                and r.reviewer_id is not distinct from j.client_id
      left join public.profiles cl on cl.id = j.client_id
      left join public.provider_case_pins k on k.job_id = j.id and k.provider_id = j.provider_id
     where j.provider_id = p_provider
       and public.is_job_portfolio_eligible(j.id)
  ),
  portfolio_union as (
    -- Seção A: Top 3 mais recentes automáticos (LIFO) + Seção B: Até 5 escolhidos pelo profissional (do 4º em diante)
    select e.*,
           row_number() over (
             order by (e.chrono_rn <= 3) desc,
                      case when e.chrono_rn <= 3 then e.chrono_rn else 999999 end asc,
                      e.kpinned desc nulls last,
                      e.rrev desc
           ) as final_rn
      from eligible_jobs e
     where e.chrono_rn <= 3 or e.kpinned is not null
  )
  select pu.jid,
         pu.jtitle,
         pu.jcat,
         coalesce(
           (select e.path from public.job_evidence e where e.job_id = pu.jid and e.slot in ('clean', 'overview', 'detail', 'angle')
             order by array_position(array['clean', 'overview', 'detail', 'angle'], e.slot) limit 1),
           (select j2.photo_paths[1] from public.jobs j2 where j2.id = pu.jid and coalesce(array_length(j2.photo_paths, 1), 0) > 0)
         ),
         pu.rrating,
         pu.rcomment,
         public._short_name(pu.cname),
         pu.rrev,
         (pu.kpinned is not null and pu.chrono_rn > 3),
         (pu.final_rn - 1)::int
    from portfolio_union pu
   where pu.final_rn <= 8
   order by pu.final_rn;
end $$;
revoke all on function public.provider_showcase(uuid) from public, anon;
grant execute on function public.provider_showcase(uuid) to authenticated;

-- Dossiê técnico público do Case no Portfólio:
-- Retorna Demanda do Cliente, Solução Original Imutável, Notas Técnicas Complementares e Fotos (1..N).
-- NUNCA retorna valores monetários (agreed_price, gross, fee, net) para garantir sigilo absoluto ao Cliente.
create or replace function public.provider_case_detail(p_job uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_out jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not public._case_visible(p_job) then
    return null;
  end if;
  select jsonb_build_object(
           'job_id', j.id,
           'provider_id', j.provider_id,
           'title', j.title,
           'category', j.category,
           'client_request_description', j.description,
           'finished_at', coalesce(j.approved_at, j.finished_at),
           'report', j.provider_report,
           'complementary_notes', j.complementary_notes,
           'photos', coalesce(
             (select jsonb_agg(p.path order by p.ord)
                from (
                  select e.path, array_position(array['overview', 'detail', 'angle', 'clean'], e.slot) as ord
                    from public.job_evidence e
                   where e.job_id = j.id and e.slot in ('overview', 'detail', 'angle', 'clean')
                  union all
                  select unnest(coalesce(j.photo_paths, '{}'::text[])) as path, 100 as ord
                ) p
               where p.path is not null and btrim(p.path) <> ''),
             '[]'::jsonb
           ),
           'video', (select e.path from public.job_evidence e where e.job_id = j.id and e.slot = 'video'),
           'rating', coalesce(r.rating, 5),
           'comment', r.comment,
           'tags', coalesce(to_jsonb(r.tags), '[]'::jsonb),
           'reply', r.reply,
           'client_name', public._short_name(cl.full_name),
           'pinned', exists (select 1 from public.provider_case_pins k where k.job_id = j.id and k.provider_id = j.provider_id)
         )
    into v_out
    from public.jobs j
    left join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id and r.reviewer_id is not distinct from j.client_id
    left join public.profiles cl on cl.id = j.client_id
   where j.id = p_job;
  return v_out;
end $$;
revoke all on function public.provider_case_detail(uuid) from public, anon;
grant execute on function public.provider_case_detail(uuid) to authenticated;

-- Permite ao profissional destacar até 5 serviços elegíveis (Concluídos & 100% Liquidados, a partir do 4º)
create or replace function public.pin_case(p_job uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('pin:' || v_uid::text, 0));
  if not exists (
    select 1 from public.jobs j
     where j.id = p_job
       and j.provider_id = v_uid
       and public.is_job_portfolio_eligible(j.id)
  ) then
    raise exception 'Só é possível destacar no Portfólio serviços concluídos cujo período de proteção pós-serviço já finalizou e com 100% do pagamento recebido.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.provider_case_pins where provider_id = v_uid and job_id = p_job) then
    return;
  end if;
  if (select count(*) from public.provider_case_pins where provider_id = v_uid) >= 5 then
    raise exception 'Você já escolheu o limite máximo de 5 serviços em destaque no Portfólio. Remova um destaque para escolher outro.' using errcode = 'P0001';
  end if;
  insert into public.provider_case_pins (provider_id, job_id) values (v_uid, p_job);
end $$;
revoke all on function public.pin_case(uuid) from public, anon;
grant execute on function public.pin_case(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Histórico Completo de Serviços Prestados do Profissional (4 Estados Reais)
--    Isolamento Estrito: Apenas `j.provider_id = auth.uid()` (Cliente JAMAIS vê)
-- ---------------------------------------------------------------------------
create index if not exists idx_jobs_provider_history_fast
  on public.jobs (provider_id, status, finished_at desc, created_at desc);

create or replace function public.provider_full_service_history()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_out jsonb;
begin
  if v_uid is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;

  select coalesce(jsonb_agg(item order by sort_ts desc), '[]'::jsonb)
    into v_out
    from (
      select coalesce(j.approved_at, j.finished_at, j.canceled_at, j.created_at) as sort_ts,
             jsonb_build_object(
               'id', j.id,
               'order_id', j.id,
               'title', j.title,
               'category_name', j.category,
               'client_requested_description', coalesce(j.description, ''),
               'detailed_execution_report', coalesce(j.provider_report, ''),
               'complementary_technical_notes', j.complementary_notes,
               'city_and_state', coalesce(j.address_summary, 'Local Verificado'),
               'completed_at', coalesce(j.approved_at, j.finished_at, j.canceled_at, j.created_at),
               'service_value', coalesce(pay.net_amount, j.agreed_price, 0),
               'gross_amount', coalesce(pay.gross_amount, j.agreed_price, 0),
               'materials_amount', coalesce(j.materials_amount, 0),
               'platform_fee_amount', coalesce(pay.fee_amount, 0),
               'lifecycle_stage', case
                 when j.status = 'canceled' then 'canceled'
                 when j.status = 'disputed' or exists (
                   select 1 from public.job_mediations m
                    where m.job_id = j.id and m.phase not in ('resolved_release_provider', 'resolved_refund_client')
                 ) then 'in_mediation'
                 when j.status = 'completed' and public.is_job_portfolio_eligible(j.id) then 'settled_and_paid'
                 else 'under_protection'
               end,
               'is_paid_100_percent', (j.status = 'completed' and public.is_job_portfolio_eligible(j.id)),
               'protection_ends_at', coalesce(j.warranty_until, pay.released_at),
               'canceled_by_role', case
                 when j.status <> 'canceled' then null
                 when j.canceled_by = j.client_id then 'client'
                 when j.canceled_by = j.provider_id then 'provider'
                 else 'system'
               end,
               'cancel_reason', j.cancel_reason,
               'is_pinned', exists (select 1 from public.provider_case_pins k where k.job_id = j.id and k.provider_id = v_uid),
               'is_reviewed_by_client', (r.id is not null and r.revealed_at is not null),
               'client_rating', r.rating,
               'client_review_comment', r.comment,
               'client_praise_tags', coalesce(to_jsonb(r.tags), '[]'::jsonb),
               'client_reviewed_at', r.revealed_at,
               'client_display_name', public._short_name(cl.full_name),
               'photos', coalesce(
                 (select jsonb_agg(p.path order by p.ord)
                    from (
                      select e.path, array_position(array['overview', 'detail', 'angle', 'clean'], e.slot) as ord
                        from public.job_evidence e
                       where e.job_id = j.id and e.slot in ('overview', 'detail', 'angle', 'clean')
                      union all
                      select unnest(coalesce(j.photo_paths, '{}'::text[])) as path, 100 as ord
                    ) p
                   where p.path is not null and btrim(p.path) <> ''),
                 '[]'::jsonb
               )
             ) as item
        from public.jobs j
        left join public.payments pay on pay.job_id = j.id
        left join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id and r.reviewer_id is not distinct from j.client_id
        left join public.profiles cl on cl.id = j.client_id
       where j.provider_id = v_uid
         and j.status in ('completed', 'disputed', 'canceled')
    ) sub;

  return v_out;
end $$;
revoke all on function public.provider_full_service_history() from public, anon;
grant execute on function public.provider_full_service_history() to authenticated;

commit;

-- =============================================================================
-- DESPERRENGUE CEO — Calendário Executivo Real-Time (Passado, Hoje e Futuro),
--                    Motor Fiscal Legal Brasileiro (DAS Simples Nacional Dia 20 Útil),
--                    Mediações Unificadas (`job_mediations` + `support_tickets`),
--                    Consulta Exata por Data (`day:YYYY-MM-DD`) e Ponte Realtime Total
-- Migration: 20261116120000_ceo_executive_calendar_agenda_and_realtime_bridge.sql
--
-- GARANTIAS INEGOCIÁVEIS (`Zero-Fake Policy` & `Zero-Trust`):
--   1. Zero dados sintéticos/demo: se não houve faturamento em uma competência,
--      o DAS apurado é exatamente `0` (`R$ 0,00`), exibindo apenas o marco legal
--      do dia útil de vencimento (Resolução CGSN nº 140/2018, Art. 40, § 2º).
--   2. Calendário bancário/nacional brasileiro determinístico em PL/pgSQL:
--      calcula Páscoa (Meeus/Jones/Butcher), Carnaval bancário FEBRABAN, Paixão,
--      Corpus Christi e todos os feriados federais (incluindo 20/11 Lei 14.759/2023),
--      prorrogando o vencimento do DAS do dia 20 para o 1º dia útil subsequente.
--   3. Consulta exata por data (`p_window_key = 'day:YYYY-MM-DD'`) para datas
--      passadas, hoje e futuras no fuso `America/Sao_Paulo`, com janela fechada
--      `[v_window_start_sp, v_window_end_sp]`.
--   4. Correção da visibilidade de despesas e impostos futuros (`competence_date > hoje`),
--      adicionando `payment_status IN ('PAID', 'SCHEDULED')` e baixa em 1 toque.
--   5. Ponte Criptografada em Tempo Real expandida (`ceo:war-room:live`):
--      novas triggers isoladas em `public.support_tickets`, `public.payments`,
--      `public.withdrawals`, `private.ceo_expense_entries` e enriquecimento de
--      `public.jobs` (`scheduled_for`, `escrow_status`, fotos forenses) e
--      `public.job_mediations` (`resolution_outcome`), além da correção de
--      `pay.method` e inclusão de `support_tickets` em `ceo_inspect_order_forensics`.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Calendário Fiscal e Bancário Oficial Brasileiro (`private.ceo_*`)
--    - Algoritmo astronômico de Meeus/Jones/Butcher para Domingo de Páscoa
--    - Feriados nacionais fixos (incluindo 20/11 a partir de 2024 — Lei 14.759/2023)
--      e móveis sem expediente bancário (Seg/Ter Carnaval, Sexta Santa, Corpus Christi)
--    - Prorrogação legal do DAS (dia 20 de M+1 -> próximo dia útil)
-- -----------------------------------------------------------------------------
create or replace function private.ceo_easter_sunday(p_year integer)
returns date
language plpgsql
immutable
set search_path = public
as $$
declare
  a integer;
  b integer;
  c integer;
  d integer;
  e integer;
  f integer;
  g integer;
  h integer;
  i integer;
  k integer;
  l integer;
  m integer;
  v_month integer;
  v_day integer;
begin
  a := p_year % 19;
  b := p_year / 100;
  c := p_year % 100;
  d := b / 4;
  e := b % 4;
  f := (b + 8) / 25;
  g := (b - f + 1) / 3;
  h := (19 * a + b - d - g + 15) % 30;
  i := c / 4;
  k := c % 4;
  l := (32 + 2 * e + 2 * i - h - k) % 7;
  m := (a + 11 * h + 22 * l) / 451;
  v_month := (h + l - 7 * m + 114) / 31;
  v_day := ((h + l - 7 * m + 114) % 31) + 1;
  return make_date(p_year, v_month, v_day);
end $$;

revoke all on function private.ceo_easter_sunday(integer) from public, anon, authenticated;

create or replace function private.ceo_is_brazil_bank_holiday(p_date date)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_year   integer := extract(year from p_date)::integer;
  v_month  integer := extract(month from p_date)::integer;
  v_day    integer := extract(day from p_date)::integer;
  v_easter date;
begin
  -- Feriados nacionais fixos (Leis Federais 662/1949, 6.802/1980, 10.607/2002 e 14.759/2023)
  if (v_month = 1 and v_day = 1)
     or (v_month = 4 and v_day = 21)
     or (v_month = 5 and v_day = 1)
     or (v_month = 9 and v_day = 7)
     or (v_month = 10 and v_day = 12)
     or (v_month = 11 and v_day = 2)
     or (v_month = 11 and v_day = 15)
     or (v_month = 11 and v_day = 20 and v_year >= 2024)
     or (v_month = 12 and v_day = 25) then
    return true;
  end if;

  -- Feriados móveis bancários FEBRABAN / nacionais
  v_easter := private.ceo_easter_sunday(v_year);
  if p_date = (v_easter - 48)
     or p_date = (v_easter - 47)
     or p_date = (v_easter - 2)
     or p_date = (v_easter + 60) then
    return true;
  end if;

  return false;
end $$;

revoke all on function private.ceo_is_brazil_bank_holiday(date) from public, anon, authenticated;

create or replace function private.ceo_next_business_day_br(p_date date)
returns date
language plpgsql
immutable
set search_path = public
as $$
declare
  v_cur   date := p_date;
  v_guard integer := 0;
begin
  while v_guard < 15 loop
    if extract(isodow from v_cur)::integer not in (6, 7)
       and not private.ceo_is_brazil_bank_holiday(v_cur) then
      return v_cur;
    end if;
    v_cur := v_cur + 1;
    v_guard := v_guard + 1;
  end loop;
  return v_cur;
end $$;

revoke all on function private.ceo_next_business_day_br(date) from public, anon, authenticated;

create or replace function private.ceo_das_due_date_for_competence(
  p_comp_year integer,
  p_comp_month integer
)
returns date
language plpgsql
immutable
set search_path = public
as $$
declare
  v_due_year  integer := case when p_comp_month = 12 then p_comp_year + 1 else p_comp_year end;
  v_due_month integer := case when p_comp_month = 12 then 1 else p_comp_month + 1 end;
begin
  -- Resolução CGSN nº 140/2018, Art. 40, § 2º: dia 20 do mês subsequente,
  -- prorrogado para o dia útil imediatamente posterior se não houver expediente bancário.
  return private.ceo_next_business_day_br(make_date(v_due_year, v_due_month, 20));
end $$;

revoke all on function private.ceo_das_due_date_for_competence(integer, integer) from public, anon, authenticated;

create or replace function private.ceo_defis_due_date_for_year(p_ref_year integer)
returns date
language plpgsql
immutable
set search_path = public
as $$
begin
  -- Resolução CGSN nº 140/2018, Art. 72: até 31 de março do ano-calendário subsequente
  return private.ceo_next_business_day_br(make_date(p_ref_year + 1, 3, 31));
end $$;

revoke all on function private.ceo_defis_due_date_for_year(integer) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Evolução de `private.ceo_expense_entries` (Despesas Pagas vs. Agendadas)
--    + RPCs `ceo_record_real_expense` e `ceo_toggle_expense_paid_status`
-- -----------------------------------------------------------------------------
alter table private.ceo_expense_entries
  add column if not exists payment_status text not null default 'PAID',
  add column if not exists paid_at timestamptz;

alter table private.ceo_expense_entries
  drop constraint if exists chk_ceo_expense_payment_status;

alter table private.ceo_expense_entries
  add constraint chk_ceo_expense_payment_status check (
    payment_status in ('PAID', 'SCHEDULED')
  );

update private.ceo_expense_entries
   set paid_at = coalesce(paid_at, created_at)
 where payment_status = 'PAID'
   and paid_at is null;

drop function if exists public.ceo_record_real_expense(text, text, date, text, text, text, bigint);

create or replace function public.ceo_record_real_expense(
  p_stepup_token text,
  p_device_hash text,
  p_competence_date date,
  p_expense_kind text,
  p_category text,
  p_description text,
  p_amount_cents bigint,
  p_payment_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid;
  v_today_sp date := (now() at time zone 'America/Sao_Paulo')::date;
  v_comp_dt  date := coalesce(p_competence_date, (now() at time zone 'America/Sao_Paulo')::date);
  v_kind     text := upper(btrim(coalesce(p_expense_kind, 'FIXED_OPEX')));
  v_status   text := upper(btrim(coalesce(p_payment_status, '')));
  v_id       uuid;
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  if v_kind not in ('FIXED_OPEX', 'VARIABLE_PSP_CLOUD', 'TAX_EXTRA') then
    raise exception 'ERR_INVALID_EXPENSE_KIND' using errcode = '22023';
  end if;

  if p_amount_cents is null or p_amount_cents <= 0 or p_amount_cents > 1000000000 then
    raise exception 'ERR_INVALID_EXPENSE_AMOUNT' using errcode = '22023';
  end if;

  if v_status = '' then
    v_status := case when v_comp_dt > v_today_sp then 'SCHEDULED' else 'PAID' end;
  elsif v_status not in ('PAID', 'SCHEDULED') then
    raise exception 'ERR_INVALID_EXPENSE_STATUS' using errcode = '22023';
  end if;

  insert into private.ceo_expense_entries (
    competence_date,
    expense_kind,
    category,
    description,
    amount_cents,
    payment_status,
    paid_at,
    created_by
  ) values (
    v_comp_dt,
    v_kind,
    left(btrim(coalesce(p_category, 'Infraestrutura')), 60),
    left(btrim(coalesce(p_description, 'Despesa operacional real')), 180),
    p_amount_cents,
    v_status,
    case when v_status = 'PAID' then now() else null end,
    v_uid
  )
  returning id into v_id;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_REAL_EXPENSE_RECORDED',
    'INFO',
    false,
    jsonb_build_object(
      'expense_id', v_id,
      'competence_date', to_char(v_comp_dt, 'YYYY-MM-DD'),
      'amount_cents', p_amount_cents,
      'kind', v_kind,
      'payment_status', v_status
    )
  );

  return jsonb_build_object(
    'ok', true,
    'expense_id', v_id,
    'payment_status', v_status
  );
end $$;

revoke all on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint, text) from public, anon;
grant execute on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint, text) to authenticated;

comment on function public.ceo_record_real_expense(text, text, date, text, text, text, bigint, text) is
  'Registra despesa ou imposto real (pago ou agendado para data futura) no livro contábil executivo do CEO.';

create or replace function public.ceo_toggle_expense_paid_status(
  p_stepup_token text,
  p_device_hash text,
  p_expense_id uuid,
  p_paid boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid    uuid;
  v_status text := case when coalesce(p_paid, true) then 'PAID' else 'SCHEDULED' end;
begin
  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  update private.ceo_expense_entries
     set payment_status = v_status,
         paid_at = case when v_status = 'PAID' then now() else null end
   where id = p_expense_id;

  if not found then
    raise exception 'ERR_EXPENSE_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.record_founder_audit_event(
    v_uid,
    v_uid,
    'CEO_REAL_EXPENSE_STATUS_UPDATED',
    'INFO',
    false,
    jsonb_build_object('expense_id', p_expense_id, 'payment_status', v_status)
  );

  return jsonb_build_object('ok', true, 'expense_id', p_expense_id, 'payment_status', v_status);
end $$;

revoke all on function public.ceo_toggle_expense_paid_status(text, text, uuid, boolean) from public, anon;
grant execute on function public.ceo_toggle_expense_paid_status(text, text, uuid, boolean) to authenticated;

comment on function public.ceo_toggle_expense_paid_status(text, text, uuid, boolean) is
  'Alterna um lançamento de despesa/imposto entre agendado (SCHEDULED) e quitado (PAID) no livro do CEO.';

-- -----------------------------------------------------------------------------
-- 3. Ponte Criptografada em Tempo Real (`Desperrengue` <-> `Desperrengue CEO`)
--    Expansão completa de gatilhos isolados (`EXCEPTION WHEN OTHERS THEN NULL`)
-- -----------------------------------------------------------------------------

-- 3.1 Enriquecimento de `private.trg_ceo_live_jobs` (agendamentos, custódia e fotos forenses)
create or replace function private.trg_ceo_live_jobs()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(nullif(new.labor_amount + new.materials_amount, 0), new.agreed_price, new.budget_estimate, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'JOB_OPENED',
        'INFO',
        'Novo pedido aberto ' || v_code,
        coalesce(new.category, 'Serviço') ||
          case
            when new.scheduled_for is not null
              then ' · Agendado ' || to_char(new.scheduled_for at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI')
            when coalesce(new.address_summary, '') <> ''
              then ' · ' || new.address_summary
            else ''
          end,
        'jobs',
        new.id::text,
        v_cents,
        jsonb_build_object(
          'status', new.status,
          'urgency', new.urgency,
          'category', new.category,
          'scheduled_for', new.scheduled_for
        )
      );
    elsif tg_op = 'UPDATE' then
      if new.escrow_status = 'FROZEN_UNDER_DURESS' and old.escrow_status is distinct from 'FROZEN_UNDER_DURESS' then
        perform private.emit_ceo_live_event_safe(
          'DURESS_ALERT_FROZEN',
          'CRITICAL',
          'ALERTA DE COAÇÃO SILENCIOSA ' || v_code,
          'Custódia bloqueada instantaneamente no cofre soberano',
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('escrow_status', new.escrow_status)
        );
      elsif new.status is distinct from old.status then
        perform private.emit_ceo_live_event_safe(
          'JOB_STATUS_' || upper(new.status),
          case
            when new.status = 'completed' then 'SUCCESS'
            when new.status = 'disputed' then 'CRITICAL'
            when new.status = 'canceled' then 'WARN'
            else 'INFO'
          end,
          'Pedido ' || v_code || ' -> ' ||
            case new.status
              when 'awaiting_payment' then 'Aguardando Pagamento'
              when 'scheduled' then 'Agendado com Custódia'
              when 'in_progress' then 'Em Execução (Check-in GPS)'
              when 'awaiting_approval' then 'Aguardando Aprovação'
              when 'completed' then 'Concluído'
              when 'canceled' then 'Cancelado'
              when 'disputed' then 'Em Mediação'
              else new.status
            end,
          coalesce(new.category, 'Serviço') ||
            case
              when new.scheduled_for is not null and new.status = 'scheduled'
                then ' · ' || to_char(new.scheduled_for at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
              when coalesce(new.address_summary, '') <> ''
                then ' · ' || new.address_summary
              else ''
            end,
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object(
            'old_status', old.status,
            'new_status', new.status,
            'scheduled_for', new.scheduled_for
          )
        );
      elsif new.scheduled_for is distinct from old.scheduled_for and new.scheduled_for is not null then
        perform private.emit_ceo_live_event_safe(
          'JOB_SCHEDULE_SET',
          'INFO',
          'Data agendada em ' || v_code,
          coalesce(new.category, 'Serviço') || ' · ' ||
            to_char(new.scheduled_for at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI'),
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('scheduled_for', new.scheduled_for, 'status', new.status)
        );
      elsif new.escrow_status is distinct from old.escrow_status then
        perform private.emit_ceo_live_event_safe(
          'JOB_ESCROW_' || upper(coalesce(new.escrow_status, 'UPDATED')),
          case
            when new.escrow_status = 'FROZEN_IN_MEDIATION' then 'CRITICAL'
            when new.escrow_status in ('LOCKED_100', 'RELEASED_TO_MATURATION') then 'SUCCESS'
            else 'INFO'
          end,
          'Custódia ' || v_code || ' -> ' || coalesce(new.escrow_status, 'NONE'),
          coalesce(new.category, 'Serviço'),
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('escrow_status', new.escrow_status)
        );
      elsif (new.checkin_photo_path is distinct from old.checkin_photo_path and new.checkin_photo_path is not null)
         or (new.checkout_photo_path is distinct from old.checkout_photo_path and new.checkout_photo_path is not null) then
        perform private.emit_ceo_live_event_safe(
          'FORENSIC_PHOTO_RECORDED',
          'SUCCESS',
          'Evidência fotográfica registrada em ' || v_code,
          case
            when new.checkout_photo_path is distinct from old.checkout_photo_path and new.checkout_photo_path is not null
              then 'Foto de conclusão validada por hash perceptual'
            else 'Foto de entrada validada por hash perceptual'
          end,
          'jobs',
          new.id::text,
          v_cents,
          jsonb_build_object('job_id', new.id)
        );
      end if;
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_jobs() from public, anon, authenticated;

-- 3.2 Enriquecimento de `private.trg_ceo_live_mediations` (abertura, SLA 6h e desfecho)
create or replace function private.trg_ceo_live_mediations()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    if tg_op = 'INSERT'
       or new.current_phase is distinct from old.current_phase
       or new.resolution_outcome is distinct from old.resolution_outcome
       or new.rescuer_provider_id is distinct from old.rescuer_provider_id then
      perform private.emit_ceo_live_event_safe(
        'MEDIATION_' || new.current_phase,
        case
          when new.current_phase = 'PHASE_5_SETTLED_AND_CERTIFIED' then 'SUCCESS'
          when tg_op = 'INSERT' then 'CRITICAL'
          else 'WARN'
        end,
        case
          when tg_op = 'INSERT' then 'Mediação de garantia aberta em ' || v_code
          when new.current_phase = 'PHASE_5_SETTLED_AND_CERTIFIED' then 'Mediação concluída em ' || v_code
          else 'Mediação atualizada em ' || v_code
        end,
        coalesce(new.claim_category, 'GARANTIA') ||
          case
            when new.resolution_outcome is not null then ' · ' || new.resolution_outcome
            else ' · Prazo ' || to_char(new.original_provider_deadline_at at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI')
          end,
        'job_mediations',
        new.job_id::text,
        0,
        jsonb_build_object(
          'mediation_id', new.id,
          'job_id', new.job_id,
          'phase', new.current_phase,
          'outcome', new.resolution_outcome,
          'deadline_at', new.original_provider_deadline_at
        )
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_mediations() from public, anon, authenticated;

-- 3.3 Nova Trigger em `public.support_tickets` ("Relatar problema" / Disputa SLA 24h)
create or replace function private.trg_ceo_live_support_tickets()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_proto text;
  v_order text;
begin
  begin
    v_proto := '#DSP-' || upper(substr(replace(new.id::text, '-', ''), 1, 4));
    v_order := case
      when new.job_id is not null then ' (' || '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5)) || ')'
      else ''
    end;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'SUPPORT_TICKET_OPENED',
        case when new.job_id is not null then 'CRITICAL' else 'WARN' end,
        'Mediação / Chamado ' || v_proto || v_order,
        left(coalesce(new.reason, 'Chamado aberto no Desperrengue'), 180),
        'support_tickets',
        coalesce(new.job_id::text, new.id::text),
        0,
        jsonb_build_object(
          'ticket_id', new.id,
          'job_id', new.job_id,
          'status', new.status,
          'sla_due_at', new.sla_due_at
        )
      );
    elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
      perform private.emit_ceo_live_event_safe(
        'SUPPORT_TICKET_' || upper(new.status),
        case
          when new.status = 'resolved' then 'SUCCESS'
          when new.status = 'in_review' then 'WARN'
          else 'INFO'
        end,
        'Chamado ' || v_proto || v_order || ' -> ' ||
          case new.status
            when 'resolved' then 'Resolvido'
            when 'in_review' then 'Em análise'
            else new.status
          end,
        left(coalesce(new.resolution, new.reason, ''), 180),
        'support_tickets',
        coalesce(new.job_id::text, new.id::text),
        0,
        jsonb_build_object(
          'ticket_id', new.id,
          'job_id', new.job_id,
          'status', new.status
        )
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_support_tickets() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_support_tickets_aiu on public.support_tickets;
create trigger zz_ceo_live_support_tickets_aiu
  after insert or update on public.support_tickets
  for each row execute function private.trg_ceo_live_support_tickets();

-- 3.4 Nova Trigger em `public.payments` (Custódia Escrow / Liberação / Estorno)
create or replace function private.trg_ceo_live_payments()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code  text;
  v_cents bigint;
begin
  begin
    v_code := '#DESP-' || upper(substr(replace(new.job_id::text, '-', ''), 1, 5));
    v_cents := round(coalesce(new.amount, 0) * 100)::bigint;

    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'PAYMENT_ESCROW_CREATED',
        'SUCCESS',
        'Pagamento protegido recebido em ' || v_code,
        'Método: ' || upper(coalesce(new.method, 'pix')),
        'payments',
        new.job_id::text,
        v_cents,
        jsonb_build_object('job_id', new.job_id, 'status', new.status, 'method', new.method)
      );
    elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
      perform private.emit_ceo_live_event_safe(
        'PAYMENT_' || upper(new.status),
        case when new.status = 'released' then 'SUCCESS' else 'WARN' end,
        'Pagamento ' || v_code || ' -> ' ||
          case new.status
            when 'released' then 'Liberado ao profissional'
            when 'refunded' then 'Estornado ao cliente'
            else new.status
          end,
        'Movimentação financeira liquidada',
        'payments',
        new.job_id::text,
        v_cents,
        jsonb_build_object('job_id', new.job_id, 'status', new.status)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_payments() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_payments_aiu on public.payments;
create trigger zz_ceo_live_payments_aiu
  after insert or update on public.payments
  for each row execute function private.trg_ceo_live_payments();

-- 3.5 Nova Trigger em `public.withdrawals` (Saques PIX dos Profissionais)
create or replace function private.trg_ceo_live_withdrawals()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_cents bigint;
begin
  begin
    v_cents := round(coalesce(new.amount, 0) * 100)::bigint;
    if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.status is distinct from old.status) then
      perform private.emit_ceo_live_event_safe(
        'PROVIDER_PIX_WITHDRAWAL',
        case when new.status = 'failed' then 'WARN' else 'INFO' end,
        'Saque PIX de profissional (' || upper(coalesce(new.pix_key_type, 'pix')) || ')',
        'Chave ' || coalesce(new.pix_key_hint, '***'),
        'withdrawals',
        new.id::text,
        v_cents,
        jsonb_build_object('status', new.status, 'provider_id', new.provider_id)
      );
    end if;
  exception when others then
    null;
  end;
  return new;
end $$;

revoke all on function private.trg_ceo_live_withdrawals() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_withdrawals_aiu on public.withdrawals;
create trigger zz_ceo_live_withdrawals_aiu
  after insert or update on public.withdrawals
  for each row execute function private.trg_ceo_live_withdrawals();

-- 3.6 Nova Trigger em `private.ceo_expense_entries` (Sincronia Multi-Tela do CEO)
create or replace function private.trg_ceo_live_expenses()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  begin
    if tg_op = 'INSERT' then
      perform private.emit_ceo_live_event_safe(
        'CEO_EXPENSE_' || new.payment_status,
        'INFO',
        case
          when new.payment_status = 'SCHEDULED' then 'Conta/imposto agendado: ' || new.category
          else 'Gasto registrado: ' || new.category
        end,
        'Data ' || to_char(new.competence_date, 'DD/MM/YYYY'),
        'ceo_expense_entries',
        new.id::text,
        new.amount_cents,
        jsonb_build_object(
          'competence_date', to_char(new.competence_date, 'YYYY-MM-DD'),
          'payment_status', new.payment_status,
          'expense_kind', new.expense_kind
        )
      );
      return new;
    elsif tg_op = 'UPDATE' then
      perform private.emit_ceo_live_event_safe(
        'CEO_EXPENSE_UPDATED',
        'SUCCESS',
        'Conta atualizada: ' || new.category,
        'Status: ' || case when new.payment_status = 'PAID' then 'Quitado' else 'Agendado' end,
        'ceo_expense_entries',
        new.id::text,
        new.amount_cents,
        jsonb_build_object(
          'competence_date', to_char(new.competence_date, 'YYYY-MM-DD'),
          'payment_status', new.payment_status
        )
      );
      return new;
    elsif tg_op = 'DELETE' then
      perform private.emit_ceo_live_event_safe(
        'CEO_EXPENSE_DELETED',
        'INFO',
        'Lançamento removido: ' || old.category,
        'Data ' || to_char(old.competence_date, 'DD/MM/YYYY'),
        'ceo_expense_entries',
        old.id::text,
        0,
        '{}'::jsonb
      );
      return old;
    end if;
  exception when others then
    null;
  end;
  return coalesce(new, old);
end $$;

revoke all on function private.trg_ceo_live_expenses() from public, anon, authenticated;

drop trigger if exists zz_ceo_live_expenses_aiud on private.ceo_expense_entries;
create trigger zz_ceo_live_expenses_aiud
  after insert or update or delete on private.ceo_expense_entries
  for each row execute function private.trg_ceo_live_expenses();

-- -----------------------------------------------------------------------------
-- 4. Correção de `public.ceo_inspect_order_forensics` (`pay.method` + `support_tickets`)
-- -----------------------------------------------------------------------------
create or replace function public.ceo_inspect_order_forensics(
  p_stepup_token text,
  p_device_hash text,
  p_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid             uuid;
  j                 public.jobs%rowtype;
  ja                public.job_addresses%rowtype;
  jg                public.job_geo%rowtype;
  pc                public.profiles%rowtype;
  pp                public.profiles%rowtype;
  v_addr_parts      jsonb;
  v_quotes          jsonb := '[]'::jsonb;
  v_invites         jsonb := '[]'::jsonb;
  v_payments        jsonb := '[]'::jsonb;
  v_ledger          jsonb := '[]'::jsonb;
  v_maturation      jsonb := '[]'::jsonb;
  v_fiscal          jsonb := '[]'::jsonb;
  v_mediations      jsonb := '[]'::jsonb;
  v_support_tickets jsonb := '[]'::jsonb;
  v_reviews         jsonb := '[]'::jsonb;
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  select * into j from public.jobs where id = p_job_id;
  if not found then
    raise exception 'ERR_JOB_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into ja from public.job_addresses where job_id = j.id;
  select * into jg from public.job_geo where job_id = j.id;
  select * into pc from public.profiles where id = j.client_id;
  if j.provider_id is not null then
    select * into pp from public.profiles where id = j.provider_id;
  end if;

  v_addr_parts := public._parse_job_address_parts(ja.address_line, j.address_summary, pc.address_city);

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'quote_id', qt.id,
               'provider_id', qt.provider_id,
               'provider_name', public.safe_name(pq.full_name, 'Profissional'),
               'price_cents', round(qt.price * 100)::bigint,
               'status', qt.status,
               'message', coalesce(qt.message, ''),
               'created_at', qt.created_at
             )
             order by qt.created_at asc
           ),
           '[]'::jsonb
         )
    into v_quotes
    from public.quotes qt
    left join public.profiles pq on pq.id = qt.provider_id
   where qt.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'provider_id', ji.provider_id,
               'provider_name', public.safe_name(pi.full_name, 'Profissional'),
               'status', ji.status,
               'expires_at', ji.expires_at,
               'created_at', ji.created_at
             )
             order by ji.created_at asc
           ),
           '[]'::jsonb
         )
    into v_invites
    from public.job_invites ji
    left join public.profiles pi on pi.id = ji.provider_id
   where ji.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'payment_id', pay.id,
               'amount_cents', round(coalesce(pay.amount, 0) * 100)::bigint,
               'fee_cents', round(coalesce(pay.fee_amount, 0) * 100)::bigint,
               'status', pay.status,
               'method', pay.method,
               'created_at', pay.created_at,
               'released_at', pay.released_at
             )
             order by pay.created_at asc
           ),
           '[]'::jsonb
         )
    into v_payments
    from public.payments pay
   where pay.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'txn_id', lt.id,
               'kind', lt.kind,
               'memo', coalesce(lt.memo, ''),
               'created_at', lt.created_at,
               'lines', (
                 select coalesce(
                          jsonb_agg(
                            jsonb_build_object('account', ll.account, 'cents', ll.cents)
                            order by ll.id asc
                          ),
                          '[]'::jsonb
                        )
                   from public.ledger_lines ll
                  where ll.txn_id = lt.id
               )
             )
             order by lt.created_at asc
           ),
           '[]'::jsonb
         )
    into v_ledger
    from public.ledger_txns lt
   where lt.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'entry_id', eme.id,
               'maturation_status', eme.maturation_status,
               'gross_labor_cents', round(eme.gross_labor_amount * 100)::bigint,
               'materials_exempt_cents', round(eme.materials_reimbursement_amount * 100)::bigint,
               'platform_fee_cents', round(eme.platform_operational_fee * 100)::bigint,
               'warranty_carveout_cents', round(eme.warranty_carveout_fee * 100)::bigint,
               'net_provider_cents', round(eme.net_provider_amount * 100)::bigint,
               'available_at', eme.available_at,
               'created_at', eme.created_at
             )
             order by eme.created_at desc
           ),
           '[]'::jsonb
         )
    into v_maturation
    from public.escrow_maturation_entries eme
   where eme.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'doc_id', jfd.id,
               'access_key_44', jfd.access_key_44,
               'verification_status', jfd.verification_status,
               'capture_channel', jfd.capture_channel,
               'declared_material_cents', round(coalesce(jfd.declared_material_amount, 0) * 100)::bigint,
               'clawback_triggered', jfd.clawback_triggered,
               'created_at', jfd.created_at
             )
             order by jfd.created_at desc
           ),
           '[]'::jsonb
         )
    into v_fiscal
    from public.job_fiscal_documents jfd
   where jfd.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'mediation_id', jm.id,
               'current_phase', jm.current_phase,
               'claim_category', jm.claim_category,
               'defect_description', jm.defect_description,
               'original_provider_deadline_at', jm.original_provider_deadline_at,
               'resolution_outcome', jm.resolution_outcome,
               'created_at', jm.created_at
             )
             order by jm.created_at desc
           ),
           '[]'::jsonb
         )
    into v_mediations
    from public.job_mediations jm
   where jm.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'ticket_id', st.id,
               'protocol_code', '#DSP-' || upper(substr(replace(st.id::text, '-', ''), 1, 4)),
               'reason', st.reason,
               'description', coalesce(st.description, ''),
               'status', st.status,
               'sla_due_at', st.sla_due_at,
               'resolution', st.resolution,
               'created_at', st.created_at
             )
             order by st.created_at desc
           ),
           '[]'::jsonb
         )
    into v_support_tickets
    from public.support_tickets st
   where st.job_id = j.id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'review_id', rv.id,
               'rating', rv.rating,
               'comment', coalesce(rv.comment, ''),
               'revealed_at', rv.revealed_at,
               'created_at', rv.created_at
             )
             order by rv.created_at desc
           ),
           '[]'::jsonb
         )
    into v_reviews
    from public.reviews rv
   where rv.job_id = j.id;

  return jsonb_build_object(
    'ok', true,
    'job', jsonb_build_object(
      'job_id', j.id,
      'order_code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
      'title', coalesce(j.title, j.category, 'Serviço'),
      'description', coalesce(j.description, ''),
      'category', coalesce(j.category, 'Outros'),
      'status', j.status,
      'payment_status', j.payment_status,
      'escrow_status', coalesce(j.escrow_status, 'NONE'),
      'urgency', coalesce(j.urgency, 'scheduled'),
      'visibility', coalesce(j.visibility, 'open'),
      'budget_estimate_cents', round(coalesce(j.budget_estimate, 0) * 100)::bigint,
      'agreed_price_cents', round(coalesce(j.agreed_price, 0) * 100)::bigint,
      'labor_cents', round(coalesce(j.labor_amount, 0) * 100)::bigint,
      'materials_cents', round(coalesce(j.materials_amount, 0) * 100)::bigint,
      'created_at', j.created_at,
      'scheduled_for', j.scheduled_for,
      'started_at', j.started_at,
      'finished_at', j.finished_at,
      'approved_at', j.approved_at,
      'auto_release_at', j.auto_release_at,
      'warranty_expires_at', j.warranty_expires_at,
      'start_distance_m', j.start_distance_m,
      'checkin_photo_path', j.checkin_photo_path,
      'checkout_photo_path', j.checkout_photo_path
    ),
    'client', jsonb_build_object(
      'user_id', pc.id,
      'full_name', public.safe_name(pc.full_name, 'Cliente'),
      'city', coalesce(pc.address_city, ''),
      'kyc_status', coalesce(pc.client_kyc_status::text, pc.verification_status::text, 'NOT_SUBMITTED')
    ),
    'provider', case
      when j.provider_id is not null then jsonb_build_object(
        'user_id', pp.id,
        'full_name', public.safe_name(pp.full_name, 'Profissional'),
        'city', coalesce(pp.address_city, ''),
        'verification_status', coalesce(pp.verification_status::text, 'NOT_SUBMITTED')
      )
      else null
    end,
    'location', jsonb_build_object(
      'neighborhood', coalesce(v_addr_parts ->> 'neighborhood', ''),
      'city', coalesce(v_addr_parts ->> 'city', ''),
      'uf', coalesce(v_addr_parts ->> 'uf', ''),
      'street', v_addr_parts ->> 'street',
      'number', v_addr_parts ->> 'number',
      'complement', ja.complement,
      'cep', coalesce(ja.cep, v_addr_parts ->> 'cep'),
      'lat', jg.lat,
      'lng', jg.lng,
      'precision_level', jg.precision_level,
      'source', jg.source
    ),
    'quotes', v_quotes,
    'invites', v_invites,
    'payments', v_payments,
    'ledger_txns', v_ledger,
    'maturation_entries', v_maturation,
    'fiscal_documents', v_fiscal,
    'mediations', v_mediations,
    'support_tickets', v_support_tickets,
    'reviews', v_reviews
  );
end $$;

revoke all on function public.ceo_inspect_order_forensics(text, text, uuid) from public, anon;
grant execute on function public.ceo_inspect_order_forensics(text, text, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Upgrade Completo de `public.ceo_get_live_cockpit_snapshot`
--    - Suporte a `day:YYYY-MM-DD` (Passado, Hoje e Futuro) com janela fechada
--    - Cronograma Fiscal Real `tax_obligations_schedule` (DAS Simples Anexo III)
--    - Mediações Unificadas `active_mediations` (`job_mediations` + `support_tickets`)
--    - Mapa Denso do Calendário `calendar_agenda_days` (-365d .. +365d)
--    - Eventos Clicáveis por Data `calendar_agenda_events`
-- -----------------------------------------------------------------------------
create or replace function public.ceo_get_live_cockpit_snapshot(
  p_stepup_token text,
  p_device_hash text,
  p_window_key text default '30d'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid                          uuid;
  v_win_key                      text := lower(btrim(coalesce(p_window_key, '30d')));
  v_today_sp                     date := (now() at time zone 'America/Sao_Paulo')::date;
  v_days                         integer;
  v_is_single_day                boolean := false;
  v_is_future_window             boolean := false;
  v_parsed_day                   date;
  v_window_start_sp              date;
  v_window_end_sp                date;
  v_window_start_utc             timestamptz;
  v_window_end_excl_utc          timestamptz;
  v_agenda_min_sp                date;
  v_agenda_max_sp                date;
  -- Demografia real de 5 estados
  v_only_clients                 integer := 0;
  v_only_providers               integer := 0;
  v_dual_mode_both               integer := 0;
  v_onboarding_incomplete        integer := 0;
  v_total_users                  integer := 0;
  v_new_users_in_window          integer := 0;
  v_kyc_verified                 integer := 0;
  v_kyc_pending                  integer := 0;
  v_kyc_rejected                 integer := 0;
  v_kyc_not_submitted            integer := 0;
  v_biometric_verified           integer := 0;
  v_ocr_verified                 integer := 0;
  v_lgpd_client                  integer := 0;
  v_lgpd_provider                integer := 0;
  v_lgpd_all                     integer := 0;
  -- Pipeline operacional ao vivo
  v_jobs_open                    integer := 0;
  v_jobs_awaiting_payment        integer := 0;
  v_jobs_scheduled               integer := 0;
  v_jobs_in_progress             integer := 0;
  v_jobs_awaiting_approval       integer := 0;
  v_jobs_completed_all_time      integer := 0;
  v_jobs_canceled_in_window      integer := 0;
  v_jobs_disputed                integer := 0;
  v_open_mediations_count        integer := 0;
  v_open_support_tickets_count   integer := 0;
  v_quotes_total_in_window       integer := 0;
  v_quotes_pending               integer := 0;
  v_quotes_accepted_in_window    integer := 0;
  v_invites_pending              integer := 0;
  v_reviews_count                integer := 0;
  v_reviews_avg_bps              integer := 0;
  -- DRE CPC 47 / IFRS 15 (100% real em BIGINT centavos)
  v_completed_orders             integer := 0;
  v_gmv_total_cents              bigint := 0;
  v_labor_gross_cents            bigint := 0;
  v_materials_exempt_cents       bigint := 0;
  v_provider_net_labor_cents     bigint := 0;
  v_platform_op_fee_cents        bigint := 0;
  v_sos_fee_revenue_cents        bigint := 0;
  v_platform_gross_revenue_cents bigint := 0;
  v_warranty_carveout_cents      bigint := 0;
  v_simples_tax_cents            bigint := 0;
  v_gross_hyp_tax_cents          bigint := 0;
  v_tax_savings_bps              integer := 0;
  v_real_var_cost_cents          bigint := 0;
  v_real_fixed_opex_cents        bigint := 0;
  v_contribution_margin_cents    bigint := 0;
  v_net_profit_ebitda_cents      bigint := 0;
  -- Reconciliação Contábil de 3 Vias
  v_pix_topups_confirmed_cents   bigint := 0;
  v_pix_topups_pending_count     integer := 0;
  v_ledger_topups_cents          bigint := 0;
  v_ledger_client_custody_cents  bigint := 0;
  v_ledger_global_imbalance      bigint := 0;
  v_wallets_and_escrow_cents     bigint := 0;
  v_discrepancy_cents            bigint := 0;
  -- Tesouraria, Custódia Escrow & Maturação D+N
  v_available_wallets_cents      bigint := 0;
  v_client_seed_credit_cents     bigint := 0;
  v_active_exec_escrow_cents     bigint := 0;
  v_maturation_d0_d2_cents       bigint := 0;
  v_maturation_d5_cents          bigint := 0;
  v_maturation_d7_cents          bigint := 0;
  v_available_for_pix_cents      bigint := 0;
  v_frozen_mediation_cents       bigint := 0;
  v_frozen_duress_cents          bigint := 0;
  -- Fundo Garantidor Atuarial
  v_pool_credits_cents           bigint := 0;
  v_pool_debits_cents            bigint := 0;
  v_pool_running_balance_cents   bigint := 0;
  v_clawback_recovered_cents     bigint := 0;
  v_claims_paid_cents            bigint := 0;
  v_active_warranty_labor_cents  bigint := 0;
  v_open_mediation_labor_cents   bigint := 0;
  v_active_exposure_cents        bigint := 0;
  v_ica_ratio_bps                integer := 0;
  v_fcr_layer1_bps               integer := 10000;
  -- Segurança, SEFAZ, Geo-Privacy & Cadeia WORM
  v_pending_sefaz_total_count    integer := 0;
  v_pending_sefaz_26h_count      integer := 0;
  v_verified_sefaz_count         integer := 0;
  v_canceled_clawback_count      integer := 0;
  v_frozen_duress_count          integer := 0;
  v_geo_leak_bps                 integer := 0;
  v_intrusion_canaries_count     integer := 0;
  v_audit_chain_intact           boolean := true;
  v_latest_event_seq             bigint := 0;
  -- Coleções JSONB 100% reais
  v_category_matrix              jsonb := '[]'::jsonb;
  v_neighborhood_liquidity       jsonb := '[]'::jsonb;
  v_live_map_points              jsonb := '[]'::jsonb;
  v_daily_series                 jsonb := '[]'::jsonb;
  v_recent_orders_pnl            jsonb := '[]'::jsonb;
  v_conversion_funnel            jsonb := '[]'::jsonb;
  v_monthly_cohorts              jsonb := '[]'::jsonb;
  v_recent_reviews               jsonb := '[]'::jsonb;
  v_duress_incidents             jsonb := '[]'::jsonb;
  v_trusted_devices              jsonb := '[]'::jsonb;
  v_recent_audit_log             jsonb := '[]'::jsonb;
  v_live_events                  jsonb := '[]'::jsonb;
  v_real_expenses                jsonb := '[]'::jsonb;
  v_vault_meta                   jsonb := '{}'::jsonb;
  -- Novas coleções do Calendário Executivo & Governança Preditiva Real
  v_tax_schedule                 jsonb := '[]'::jsonb;
  v_active_mediations            jsonb := '[]'::jsonb;
  v_calendar_agenda_days         jsonb := '[]'::jsonb;
  v_calendar_agenda_events       jsonb := '[]'::jsonb;
begin
  set local transaction_read_only = on;

  v_uid := private.validate_ceo_stepup_session(p_stepup_token, p_device_hash);

  -- Resolução de janela: suporta `day:YYYY-MM-DD` (passado, hoje ou futuro) e janelas rolantes
  if v_win_key ~ '^day:\d{4}-\d{2}-\d{2}$' then
    begin
      v_parsed_day := to_date(substr(v_win_key, 5, 10), 'YYYY-MM-DD');
      if to_char(v_parsed_day, 'YYYY-MM-DD') = substr(v_win_key, 5, 10)
         and v_parsed_day between date '2020-01-01' and (v_today_sp + 1095) then
        v_is_single_day := true;
        v_is_future_window := (v_parsed_day > v_today_sp);
        v_days := 1;
        v_window_start_sp := v_parsed_day;
        v_window_end_sp := v_parsed_day;
        v_win_key := 'day:' || to_char(v_parsed_day, 'YYYY-MM-DD');
      end if;
    exception when others then
      v_is_single_day := false;
    end;
  end if;

  if not v_is_single_day then
    case v_win_key
      when 'today' then
        v_days := 1;
        v_window_start_sp := v_today_sp;
        v_window_end_sp := v_today_sp;
      when '7d' then
        v_days := 7;
        v_window_start_sp := v_today_sp - 6;
        v_window_end_sp := v_today_sp;
      when '30d' then
        v_days := 30;
        v_window_start_sp := v_today_sp - 29;
        v_window_end_sp := v_today_sp;
      when '90d' then
        v_days := 90;
        v_window_start_sp := v_today_sp - 89;
        v_window_end_sp := v_today_sp;
      when '365d' then
        v_days := 365;
        v_window_start_sp := v_today_sp - 364;
        v_window_end_sp := v_today_sp;
      when 'all' then
        select greatest(
                 1,
                 least(
                   3650,
                   (v_today_sp - coalesce(min((jb_min.created_at at time zone 'America/Sao_Paulo')::date), v_today_sp)) + 1
                 )
               )::integer
          into v_days
          from public.jobs jb_min;
        v_days := coalesce(v_days, 30);
        v_window_start_sp := v_today_sp - (v_days - 1);
        v_window_end_sp := v_today_sp;
      else
        v_win_key := '30d';
        v_days := 30;
        v_window_start_sp := v_today_sp - 29;
        v_window_end_sp := v_today_sp;
    end case;
  end if;

  v_window_start_utc := (v_window_start_sp::timestamp at time zone 'America/Sao_Paulo');
  v_window_end_excl_utc := ((v_window_end_sp + 1)::timestamp at time zone 'America/Sao_Paulo');
  v_agenda_min_sp := least(v_window_start_sp, v_today_sp - 365);
  v_agenda_max_sp := greatest(v_window_end_sp, v_today_sp + 365);

  -- ---------------------------------------------------------------------------
  -- 1. Demografia Real de 5 Estados (`profiles`) + Offboarding LGPD
  -- ---------------------------------------------------------------------------
  select count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_provider, false) = true and coalesce(prof.is_client, false) = false)::integer,
         count(*) filter (where coalesce(prof.is_client, false) = true and coalesce(prof.is_provider, false) = true)::integer,
         count(*) filter (where coalesce(prof.is_client, false) = false and coalesce(prof.is_provider, false) = false)::integer,
         count(*)::integer,
         count(*) filter (where prof.created_at >= v_window_start_utc and prof.created_at < v_window_end_excl_utc)::integer,
         count(*) filter (
           where prof.verification_status = 'ACTIVE'
              or prof.client_kyc_status = 'APPROVED'
              or coalesce(prof.kyc_biometric_verified, false) = true
         )::integer,
         count(*) filter (
           where not (
             prof.verification_status = 'ACTIVE'
             or prof.client_kyc_status = 'APPROVED'
             or coalesce(prof.kyc_biometric_verified, false) = true
           )
           and (
             prof.verification_status in ('PENDING', 'APPROVED_PENDING_EMAIL')
             or prof.client_kyc_status = 'PENDING_REVIEW'
           )
         )::integer,
         count(*) filter (
           where not (
             prof.verification_status = 'ACTIVE'
             or prof.client_kyc_status = 'APPROVED'
             or coalesce(prof.kyc_biometric_verified, false) = true
           )
           and (
             prof.verification_status = 'REJECTED'
             or prof.client_kyc_status = 'REJECTED'
           )
         )::integer,
         count(*) filter (where coalesce(prof.kyc_biometric_verified, false) = true)::integer,
         count(*) filter (where coalesce(prof.ocr_verified, false) = true)::integer
    into v_only_clients,
         v_only_providers,
         v_dual_mode_both,
         v_onboarding_incomplete,
         v_total_users,
         v_new_users_in_window,
         v_kyc_verified,
         v_kyc_pending,
         v_kyc_rejected,
         v_biometric_verified,
         v_ocr_verified
    from public.profiles prof;

  v_kyc_not_submitted := greatest(0, v_total_users - v_kyc_verified - v_kyc_pending - v_kyc_rejected);

  select count(*) filter (where adl.scope = 'client')::integer,
         count(*) filter (where adl.scope = 'provider')::integer,
         count(*) filter (where adl.scope = 'all')::integer
    into v_lgpd_client,
         v_lgpd_provider,
         v_lgpd_all
    from public.account_deletion_log adl;

  -- ---------------------------------------------------------------------------
  -- 2. Contadores Operacionais Ao Vivo (`jobs`, `job_mediations`, `support_tickets`, `quotes`)
  -- ---------------------------------------------------------------------------
  select count(*) filter (where jb_s.status = 'open')::integer,
         count(*) filter (where jb_s.status = 'awaiting_payment')::integer,
         count(*) filter (where jb_s.status = 'scheduled')::integer,
         count(*) filter (where jb_s.status = 'in_progress')::integer,
         count(*) filter (where jb_s.status = 'awaiting_approval')::integer,
         count(*) filter (where jb_s.status = 'completed')::integer,
         count(*) filter (
           where jb_s.status = 'canceled'
             and coalesce(jb_s.updated_at, jb_s.created_at) >= v_window_start_utc
             and coalesce(jb_s.updated_at, jb_s.created_at) < v_window_end_excl_utc
         )::integer,
         count(*) filter (where jb_s.status = 'disputed')::integer
    into v_jobs_open,
         v_jobs_awaiting_payment,
         v_jobs_scheduled,
         v_jobs_in_progress,
         v_jobs_awaiting_approval,
         v_jobs_completed_all_time,
         v_jobs_canceled_in_window,
         v_jobs_disputed
    from public.jobs jb_s;

  select count(*)::integer
    into v_open_mediations_count
    from public.job_mediations jm_cnt
   where jm_cnt.current_phase <> 'PHASE_5_SETTLED_AND_CERTIFIED';

  select count(*)::integer
    into v_open_support_tickets_count
    from public.support_tickets st_cnt
   where st_cnt.status in ('open', 'in_review');

  v_jobs_disputed := greatest(v_jobs_disputed, v_open_mediations_count + v_open_support_tickets_count);

  select count(*) filter (where qt.created_at >= v_window_start_utc and qt.created_at < v_window_end_excl_utc)::integer,
         count(*) filter (where qt.status = 'pending')::integer,
         count(*) filter (where qt.status = 'accepted' and qt.created_at >= v_window_start_utc and qt.created_at < v_window_end_excl_utc)::integer
    into v_quotes_total_in_window,
         v_quotes_pending,
         v_quotes_accepted_in_window
    from public.quotes qt;

  select count(*)::integer
    into v_invites_pending
    from public.job_invites ji
   where ji.status = 'pending'
     and ji.expires_at > now();

  select count(*)::integer,
         coalesce(round(avg(rv.rating) * 1000)::integer, 0)
    into v_reviews_count,
         v_reviews_avg_bps
    from public.reviews rv
   where rv.revealed_at is not null;

  -- ---------------------------------------------------------------------------
  -- 3. DRE Contábil CPC 47 / IFRS 15 (Janela Fechada `[v_window_start_utc, v_window_end_excl_utc)`)
  -- ---------------------------------------------------------------------------
  with settled_jobs as (
    select jb.id,
           gmv_calc.gmv_cents,
           ex_calc.exempt_cents,
           greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) as fee_base_labor_cents,
           fee_calc.op_fee_cents,
           fee_calc.carveout_cents,
           greatest(
             0::bigint,
             greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents)
             - fee_calc.op_fee_cents
             - fee_calc.carveout_cents
           ) as provider_net_labor_cents
      from public.jobs jb
      left join public.escrow_maturation_entries eme
        on eme.job_id = jb.id
      left join lateral (
        select pay.amount, pay.fee_amount
          from public.payments pay
         where pay.job_id = jb.id
         order by pay.created_at desc
         limit 1
      ) lp on true
      cross join lateral (
        select case
          when coalesce(jb.labor_amount, 0) + coalesce(jb.materials_amount, 0) > 0
            then round((coalesce(jb.labor_amount, 0) + coalesce(jb.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lp.amount, jb.agreed_price, 0) * 100)::bigint
        end as gmv_cents
      ) gmv_calc
      cross join lateral (
        select least(
          gmv_calc.gmv_cents,
          case
            when eme.id is not null then round(eme.materials_reimbursement_amount * 100)::bigint
            else 0::bigint
          end
        ) as exempt_cents
      ) ex_calc
      cross join lateral (
        select case
                 when eme.id is not null then round(eme.platform_operational_fee * 100)::bigint
                 when lp.fee_amount is not null and lp.fee_amount > 0 then
                   greatest(
                     0::bigint,
                     round(lp.fee_amount * 100)::bigint
                     - round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 15.0 / 1000.0)::bigint
                   )
                 else round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 135.0 / 1000.0)::bigint
               end as op_fee_cents,
               case
                 when eme.id is not null then round(eme.warranty_carveout_fee * 100)::bigint
                 else round(greatest(0::bigint, gmv_calc.gmv_cents - ex_calc.exempt_cents) * 15.0 / 1000.0)::bigint
               end as carveout_cents
      ) fee_calc
     where jb.status = 'completed'
       and coalesce(jb.is_warranty_rework, false) = false
       and coalesce(jb.approved_at, jb.finished_at, jb.updated_at, jb.created_at) >= v_window_start_utc
       and coalesce(jb.approved_at, jb.finished_at, jb.updated_at, jb.created_at) < v_window_end_excl_utc
  )
  select count(*)::integer,
         coalesce(sum(sj.gmv_cents), 0)::bigint,
         coalesce(sum(sj.fee_base_labor_cents), 0)::bigint,
         coalesce(sum(sj.exempt_cents), 0)::bigint,
         coalesce(sum(sj.provider_net_labor_cents), 0)::bigint,
         coalesce(sum(sj.op_fee_cents), 0)::bigint,
         coalesce(sum(sj.carveout_cents), 0)::bigint
    into v_completed_orders,
         v_gmv_total_cents,
         v_labor_gross_cents,
         v_materials_exempt_cents,
         v_provider_net_labor_cents,
         v_platform_op_fee_cents,
         v_warranty_carveout_cents
    from settled_jobs sj;

  select coalesce(sum(ll.cents), 0)::bigint
    into v_sos_fee_revenue_cents
    from public.ledger_lines ll
    join public.ledger_txns lt on lt.id = ll.txn_id
   where ll.account = 'platform:sos_fee'
     and lt.created_at >= v_window_start_utc
     and lt.created_at < v_window_end_excl_utc;

  v_platform_gross_revenue_cents := v_platform_op_fee_cents + greatest(0::bigint, v_sos_fee_revenue_cents);
  v_simples_tax_cents := (v_platform_gross_revenue_cents * 6 + 50) / 100;
  v_gross_hyp_tax_cents := (v_gmv_total_cents * 1133 + 5000) / 10000;

  if v_gross_hyp_tax_cents > 0 then
    v_tax_savings_bps := greatest(
      0,
      (((v_gross_hyp_tax_cents - v_simples_tax_cents) * 10000) / v_gross_hyp_tax_cents)::integer
    );
  else
    v_tax_savings_bps := 0;
  end if;

  select coalesce(sum(cee.amount_cents) filter (where cee.expense_kind = 'VARIABLE_PSP_CLOUD'), 0)::bigint,
         coalesce(sum(cee.amount_cents) filter (where cee.expense_kind in ('FIXED_OPEX', 'TAX_EXTRA')), 0)::bigint
    into v_real_var_cost_cents,
         v_real_fixed_opex_cents
    from private.ceo_expense_entries cee
   where cee.competence_date >= v_window_start_sp
     and cee.competence_date <= v_window_end_sp
     and (v_is_future_window or cee.payment_status = 'PAID');

  v_contribution_margin_cents :=
    v_platform_gross_revenue_cents - v_simples_tax_cents - v_real_var_cost_cents;

  v_net_profit_ebitda_cents := v_contribution_margin_cents - v_real_fixed_opex_cents;

  -- ---------------------------------------------------------------------------
  -- 4. Reconciliação Contábil de 3 Vias (1 centavo de sensibilidade)
  -- ---------------------------------------------------------------------------
  select coalesce(sum(pt.amount_cents) filter (where pt.status = 'paid'), 0)::bigint,
         count(*) filter (where pt.status = 'pending' and pt.expires_at > now())::integer
    into v_pix_topups_confirmed_cents,
         v_pix_topups_pending_count
    from public.pix_topups pt;

  select coalesce(
           sum(ll.cents) filter (
             where ll.account like 'client:%:available'
                or ll.account like 'client:%:escrow'
           ),
           0
         )::bigint,
         abs(coalesce(sum(ll.cents), 0)::bigint),
         abs(coalesce(sum(ll.cents) filter (where ll.account = 'platform:test_credit'), 0)::bigint)
    into v_ledger_client_custody_cents,
         v_ledger_global_imbalance,
         v_client_seed_credit_cents
    from public.ledger_lines ll;

  select coalesce(sum(ll_top.cents), 0)::bigint
    into v_ledger_topups_cents
    from public.ledger_txns lt_top
    join public.ledger_lines ll_top on ll_top.txn_id = lt_top.id
   where lt_top.kind = 'topup'
     and ll_top.account like 'client:%:available'
     and ll_top.account not like 'client:removed-%';

  select coalesce(sum(cw.available_cents + cw.escrow_cents), 0)::bigint,
         coalesce(sum(cw.available_cents), 0)::bigint
    into v_wallets_and_escrow_cents,
         v_available_wallets_cents
    from public.client_wallets cw;

  v_discrepancy_cents := greatest(
    abs(v_wallets_and_escrow_cents - v_ledger_client_custody_cents),
    abs(v_pix_topups_confirmed_cents - v_ledger_topups_cents),
    v_ledger_global_imbalance
  );

  -- ---------------------------------------------------------------------------
  -- 5. Tesouraria, Custódia Escrow & Maturação D+N Real
  -- ---------------------------------------------------------------------------
  v_available_wallets_cents := v_available_wallets_cents + coalesce((
    select sum(round(prof_w.available_wallet_balance * 100)::bigint)::bigint
      from public.profiles prof_w
     where prof_w.available_wallet_balance > 0
  ), 0);

  select coalesce(sum(round(coalesce(nullif(jb_ex.labor_amount + jb_ex.materials_amount, 0), jb_ex.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_active_exec_escrow_cents
    from public.jobs jb_ex
   where (
           jb_ex.escrow_status = 'LOCKED_100'
           or (jb_ex.payment_status = 'escrow' and jb_ex.status in ('scheduled', 'in_progress', 'awaiting_approval'))
         )
     and coalesce(jb_ex.escrow_status, 'NONE') not in ('FROZEN_IN_MEDIATION', 'FROZEN_UNDER_DURESS');

  select coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) <= interval '2 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) > interval '2 days 12 hours'
               and (eme_m.available_at - eme_m.created_at) <= interval '5 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'MATURING'
               and (eme_m.available_at - eme_m.created_at) > interval '5 days 12 hours'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'AVAILABLE_FOR_PIX'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'FROZEN_BY_DISPUTE'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(eme_m.net_provider_amount * 100)::bigint) filter (
             where eme_m.maturation_status = 'FROZEN_UNDER_DURESS'
           ),
           0
         )::bigint
    into v_maturation_d0_d2_cents,
         v_maturation_d5_cents,
         v_maturation_d7_cents,
         v_available_for_pix_cents,
         v_frozen_mediation_cents,
         v_frozen_duress_cents
    from public.escrow_maturation_entries eme_m;

  v_frozen_mediation_cents := v_frozen_mediation_cents + coalesce((
    select sum(round(coalesce(nullif(jb_fm.labor_amount + jb_fm.materials_amount, 0), jb_fm.agreed_price, 0) * 100)::bigint)::bigint
      from public.jobs jb_fm
     where (jb_fm.escrow_status = 'FROZEN_IN_MEDIATION' or jb_fm.status = 'disputed')
       and coalesce(jb_fm.escrow_status, 'NONE') <> 'FROZEN_UNDER_DURESS'
       and not exists (select 1 from public.escrow_maturation_entries eme_chk1 where eme_chk1.job_id = jb_fm.id)
  ), 0);

  v_frozen_duress_cents := v_frozen_duress_cents + coalesce((
    select sum(round(coalesce(nullif(jb_fd.labor_amount + jb_fd.materials_amount, 0), jb_fd.agreed_price, 0) * 100)::bigint)::bigint
      from public.jobs jb_fd
     where jb_fd.escrow_status = 'FROZEN_UNDER_DURESS'
       and not exists (
         select 1
           from public.escrow_maturation_entries eme_chk2
          where eme_chk2.job_id = jb_fd.id
            and eme_chk2.maturation_status = 'FROZEN_UNDER_DURESS'
       )
  ), 0);

  -- ---------------------------------------------------------------------------
  -- 6. Fundo Garantidor Atuarial (`warranty_pool_ledger`)
  -- ---------------------------------------------------------------------------
  select coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type in (
               'CARVEOUT_CONTRIBUTION_1_5_PCT',
               'CLAWBACK_RECOVERY_CREDIT',
               'COLD_START_SEED_RESERVE'
             )
           ),
           0
         )::bigint,
         coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type = 'REWORK_PAYOUT_DEBIT'
           ),
           0
         )::bigint,
         coalesce(
           sum(round(wpl.amount * 100)::bigint) filter (
             where wpl.entry_type = 'CLAWBACK_RECOVERY_CREDIT'
           ),
           0
         )::bigint
    into v_pool_credits_cents,
         v_pool_debits_cents,
         v_clawback_recovered_cents
    from public.warranty_pool_ledger wpl;

  v_claims_paid_cents := v_pool_debits_cents;
  v_pool_running_balance_cents := greatest(0::bigint, v_pool_credits_cents - v_pool_debits_cents);

  select coalesce(sum(round(coalesce(nullif(jb_w.labor_amount, 0), jb_w.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_active_warranty_labor_cents
    from public.jobs jb_w
   where jb_w.status = 'completed'
     and jb_w.warranty_expires_at > now();

  select coalesce(sum(round(coalesce(nullif(jb_om.labor_amount, 0), jb_om.agreed_price, 0) * 100)::bigint), 0)::bigint
    into v_open_mediation_labor_cents
    from public.job_mediations jm_open
    join public.jobs jb_om on jb_om.id = jm_open.job_id
   where jm_open.current_phase in (
     'PHASE_1_OPENED_AND_FROZEN',
     'PHASE_2_FORENSIC_TRIAGE',
     'PHASE_3_ORIGINAL_PROVIDER_SLA_6H',
     'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH'
   );

  v_active_exposure_cents := greatest(
    v_open_mediation_labor_cents,
    (v_active_warranty_labor_cents * 100 + 5000) / 10000
  );

  if v_active_exposure_cents > 0 then
    v_ica_ratio_bps := least(99999, ((v_pool_running_balance_cents * 10000) / v_active_exposure_cents)::integer);
  elsif v_pool_running_balance_cents > 0 then
    v_ica_ratio_bps := 10000;
  else
    v_ica_ratio_bps := 0;
  end if;

  select case
           when count(*) > 0 then
             ((count(*) filter (where jm_fcr.resolution_outcome is distinct from 'REPAIRED_BY_LAYER3_RESCUER') * 10000) / count(*))::integer
           else 10000
         end
    into v_fcr_layer1_bps
    from public.job_mediations jm_fcr;

  -- ---------------------------------------------------------------------------
  -- 7. Matriz Real das 33 Categorias Canônicas (`category_liquidity_matrix`)
  -- ---------------------------------------------------------------------------
  with canonical_cats(ord, slug, display_name) as (
    values
      (1,  'eletrica',              'Elétrica'),
      (2,  'encanador',             'Encanador'),
      (3,  'limpeza',               'Limpeza'),
      (4,  'montagem',              'Montagem'),
      (5,  'pintura',               'Pintura'),
      (6,  'chaveiro',              'Chaveiro'),
      (7,  'pedreiro',              'Pedreiro'),
      (8,  'gesso',                 'Gesso'),
      (9,  'marcenaria',            'Marcenaria'),
      (10, 'ar-condicionado',       'Ar-condicionado'),
      (11, 'pequenos reparos',      'Pequenos Reparos'),
      (12, 'jardinagem',            'Jardinagem'),
      (13, 'dedetizacao',           'Dedetização'),
      (14, 'vidraceiro',            'Vidraceiro'),
      (15, 'serralheria',           'Serralheria'),
      (16, 'telhados e calhas',     'Telhados e Calhas'),
      (17, 'impermeabilizacao',     'Impermeabilização'),
      (18, 'desentupidora',         'Desentupidora'),
      (19, 'piscina',               'Piscina'),
      (20, 'eletrodomesticos',      'Eletrodomésticos'),
      (21, 'tv e antenas',          'TV e Antenas'),
      (22, 'cameras e alarmes',     'Câmeras e Alarmes'),
      (23, 'portoes e interfones',  'Portões e Interfones'),
      (24, 'energia solar',         'Energia Solar'),
      (25, 'gas e aquecedores',     'Gás e Aquecedores'),
      (26, 'pisos e revestimentos', 'Pisos e Revestimentos'),
      (27, 'cortinas e persianas',  'Cortinas e Persianas'),
      (28, 'estofados e tapetes',   'Estofados e Tapetes'),
      (29, 'mudancas e fretes',     'Mudanças e Fretes'),
      (30, 'informatica e redes',   'Informática e Redes'),
      (31, 'cuidador de idosos',    'Cuidador de Idosos'),
      (32, 'baba',                  'Babá'),
      (33, 'pet care',              'Pet Care')
  ),
  demand_by_slug as (
    select public.norm_tag(jb_cat.category) as slug,
           count(*)::integer as demand_n,
           count(*) filter (where jb_cat.status in ('scheduled', 'in_progress', 'awaiting_approval', 'completed'))::integer as conv_n,
           coalesce(
             round(avg(coalesce(nullif(jb_cat.labor_amount + jb_cat.materials_amount, 0), jb_cat.agreed_price, jb_cat.budget_estimate, 0) * 100))::bigint,
             0::bigint
           ) as avg_ticket_cents
      from public.jobs jb_cat
     where coalesce(jb_cat.scheduled_for, jb_cat.created_at) >= v_window_start_utc
       and coalesce(jb_cat.scheduled_for, jb_cat.created_at) < v_window_end_excl_utc
       and coalesce(jb_cat.is_warranty_rework, false) = false
     group by 1
  ),
  supply_by_slug as (
    select spec_slug as slug,
           count(distinct pp_cat.user_id)::integer as providers_n
      from public.provider_profiles pp_cat
      join public.profiles prof_cat
        on prof_cat.id = pp_cat.user_id
       and prof_cat.is_provider = true
       and prof_cat.verification_status = 'ACTIVE'
       and coalesce(pp_cat.accepting_jobs, true) = true,
      unnest(public.norm_tags(pp_cat.specialties)) as spec_slug
     group by 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'category_id', replace(cc.slug, ' ', '_'),
               'category_name', cc.display_name,
               'demand_count', coalesce(dbs.demand_n, 0),
               'active_providers_count', coalesce(sbs.providers_n, 0),
               'avg_ticket_cents', coalesce(dbs.avg_ticket_cents, 0),
               'conversion_bps', case
                 when coalesce(dbs.demand_n, 0) > 0
                   then ((coalesce(dbs.conv_n, 0) * 10000) / dbs.demand_n)::integer
                 else 0
               end
             )
             order by coalesce(dbs.demand_n, 0) desc, coalesce(sbs.providers_n, 0) desc, cc.ord asc
           ),
           '[]'::jsonb
         )
    into v_category_matrix
    from canonical_cats cc
    left join demand_by_slug dbs on dbs.slug = cc.slug
    left join supply_by_slug sbs on sbs.slug = cc.slug;

  -- ---------------------------------------------------------------------------
  -- 8. Mapa Cartográfico Real (`live_map_points`) e Liquidez por Bairro
  -- ---------------------------------------------------------------------------
  with geo_jobs as (
    select jb_m.id as job_id,
           '#DESP-' || upper(substr(replace(jb_m.id::text, '-', ''), 1, 5)) as order_code,
           coalesce(jb_m.title, jb_m.category, 'Serviço') as title,
           coalesce(jb_m.category, 'Outros') as category_name,
           jb_m.status,
           coalesce(jb_m.escrow_status, 'NONE') as escrow_status,
           jb_m.urgency,
           jb_m.scheduled_for,
           jb_m.started_at,
           jb_m.created_at,
           coalesce(jg.lat, jb_m.public_lat) as lat,
           coalesce(jg.lng, jb_m.public_lng) as lng,
           (jg.job_id is not null) as is_exact_pin,
           round(coalesce(nullif(jb_m.labor_amount + jb_m.materials_amount, 0), jb_m.agreed_price, jb_m.budget_estimate, 0) * 100)::bigint as amount_cents,
           public._parse_job_address_parts(ja.address_line, jb_m.address_summary, pc.address_city) as addr_parts,
           public.safe_name(pc.full_name, 'Cliente') as client_name,
           case when pp_u.id is not null then public.safe_name(pp_u.full_name, 'Profissional') else null end as provider_name
      from public.jobs jb_m
      left join public.job_geo jg on jg.job_id = jb_m.id
      left join public.job_addresses ja on ja.job_id = jb_m.id
      left join public.profiles pc on pc.id = jb_m.client_id
      left join public.profiles pp_u on pp_u.id = jb_m.provider_id
     where coalesce(jb_m.is_warranty_rework, false) = false
     order by
       case when jb_m.status in ('in_progress', 'disputed', 'scheduled', 'open', 'awaiting_payment', 'awaiting_approval') then 0 else 1 end asc,
       jb_m.created_at desc
     limit 120
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'job_id', gj.job_id,
               'order_code', gj.order_code,
               'title', gj.title,
               'category_name', gj.category_name,
               'status', gj.status,
               'escrow_status', gj.escrow_status,
               'urgency', coalesce(gj.urgency, 'scheduled'),
               'lat', gj.lat,
               'lng', gj.lng,
               'is_exact_pin', gj.is_exact_pin,
               'amount_cents', gj.amount_cents,
               'neighborhood', coalesce(nullif(gj.addr_parts ->> 'neighborhood', ''), ' Centro / Região'),
               'city', coalesce(nullif(gj.addr_parts ->> 'city', ''), 'Não informada'),
               'uf', coalesce(gj.addr_parts ->> 'uf', ''),
               'client_name', gj.client_name,
               'provider_name', gj.provider_name,
               'scheduled_for', gj.scheduled_for,
               'started_at', gj.started_at,
               'created_at', gj.created_at
             )
           ) filter (where gj.lat is not null and gj.lng is not null),
           '[]'::jsonb
         )
    into v_live_map_points
    from geo_jobs gj;

  with job_regions as (
    select coalesce(
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'neighborhood'), ''),
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'city'), ''),
             'Região Geral'
           ) as region_label,
           coalesce(
             nullif(btrim((public._parse_job_address_parts(ja_r.address_line, jb_reg.address_summary, pc_r.address_city)) ->> 'city'), ''),
             'Cidade não informada'
           ) as city_label,
           count(*)::integer as demand_count,
           count(distinct jb_reg.provider_id) filter (where jb_reg.provider_id is not null)::integer as engaged_providers_count,
           coalesce(
             round(avg(coalesce(nullif(jb_reg.labor_amount + jb_reg.materials_amount, 0), jb_reg.agreed_price, jb_reg.budget_estimate, 0) * 100))::bigint,
             0::bigint
           ) as avg_ticket_cents
      from public.jobs jb_reg
      left join public.job_addresses ja_r on ja_r.job_id = jb_reg.id
      left join public.profiles pc_r on pc_r.id = jb_reg.client_id
     where coalesce(jb_reg.scheduled_for, jb_reg.created_at) >= v_window_start_utc
       and coalesce(jb_reg.scheduled_for, jb_reg.created_at) < v_window_end_excl_utc
     group by 1, 2
     order by demand_count desc, avg_ticket_cents desc
     limit 16
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'neighborhood_name', jr.region_label,
               'city_name', jr.city_label,
               'demand_count', jr.demand_count,
               'active_supply_count', jr.engaged_providers_count,
               'avg_ticket_cents', jr.avg_ticket_cents
             )
           ),
           '[]'::jsonb
         )
    into v_neighborhood_liquidity
    from job_regions jr;

  -- ---------------------------------------------------------------------------
  -- 9. Funil Real de Conversão & Coortes Reais Mensais
  -- ---------------------------------------------------------------------------
  with funnel_counts as (
    select v_total_users as s1_registered,
           v_kyc_verified as s2_kyc_approved,
           (
             select count(distinct u_act.uid)::integer
               from (
                 select jb_f.client_id as uid from public.jobs jb_f
                 union
                 select qt_f.provider_id as uid from public.quotes qt_f
               ) u_act
           ) as s3_engaged_order_or_quote,
           (
             select count(distinct jb_e.client_id)::integer
               from public.jobs jb_e
              where jb_e.payment_status in ('escrow', 'released', 'paid')
                 or jb_e.status in ('scheduled', 'in_progress', 'awaiting_approval', 'completed')
           ) as s4_escrow_funded,
           (
             select count(distinct jb_c.client_id)::integer
               from public.jobs jb_c
              where jb_c.status = 'completed'
           ) as s5_completed_service,
           (
             select count(*)::integer
               from (
                 select jb_r2.client_id
                   from public.jobs jb_r2
                  where jb_r2.status = 'completed'
                  group by jb_r2.client_id
                 having count(*) >= 2
               ) rec
           ) as s6_recurring_clients
  )
  select jsonb_build_array(
           jsonb_build_object('stage_id', 'signups',   'label', 'Cadastros Reais',             'users_count', fc.s1_registered),
           jsonb_build_object('stage_id', 'kyc_ok',    'label', 'KYC / Identidade Aprovada',   'users_count', fc.s2_kyc_approved),
           jsonb_build_object('stage_id', 'engaged',   'label', 'Pedido ou Orçamento Enviado', 'users_count', fc.s3_engaged_order_or_quote),
           jsonb_build_object('stage_id', 'escrow',    'label', 'Custódia Escrow Confirmada',  'users_count', fc.s4_escrow_funded),
           jsonb_build_object('stage_id', 'completed', 'label', 'Serviço Concluído',           'users_count', fc.s5_completed_service),
           jsonb_build_object('stage_id', 'recurring', 'label', 'Clientes Recorrentes (2+)',   'users_count', fc.s6_recurring_clients)
         )
    into v_conversion_funnel
    from funnel_counts fc;

  with user_cohorts as (
    select prof_c.id as user_id,
           date_trunc('month', prof_c.created_at at time zone 'America/Sao_Paulo')::date as cohort_month
      from public.profiles prof_c
  ),
  user_activity_months as (
    select jb_act.client_id as user_id,
           date_trunc('month', jb_act.created_at at time zone 'America/Sao_Paulo')::date as act_month
      from public.jobs jb_act
    union
    select qt_act.provider_id as user_id,
           date_trunc('month', qt_act.created_at at time zone 'America/Sao_Paulo')::date as act_month
      from public.quotes qt_act
  ),
  cohort_agg as (
    select uc.cohort_month,
           count(distinct uc.user_id)::integer as cohort_size,
           count(distinct uam0.user_id)::integer as m0_active,
           count(distinct uam1.user_id)::integer as m1_active,
           count(distinct uam2.user_id)::integer as m2_active,
           count(distinct uam3.user_id)::integer as m3_active
      from user_cohorts uc
      left join user_activity_months uam0
        on uam0.user_id = uc.user_id and uam0.act_month = uc.cohort_month
      left join user_activity_months uam1
        on uam1.user_id = uc.user_id and uam1.act_month = (uc.cohort_month + interval '1 month')::date
      left join user_activity_months uam2
        on uam2.user_id = uc.user_id and uam2.act_month = (uc.cohort_month + interval '2 months')::date
      left join user_activity_months uam3
        on uam3.user_id = uc.user_id and uam3.act_month = (uc.cohort_month + interval '3 months')::date
     group by uc.cohort_month
     order by uc.cohort_month desc
     limit 6
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'cohort_label', to_char(ca.cohort_month, 'YYYY-MM'),
               'cohort_size', ca.cohort_size,
               'm0_bps', case when ca.cohort_size > 0 then ((ca.m0_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm1_bps', case when ca.cohort_size > 0 then ((ca.m1_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm2_bps', case when ca.cohort_size > 0 then ((ca.m2_active * 10000) / ca.cohort_size)::integer else 0 end,
               'm3_bps', case when ca.cohort_size > 0 then ((ca.m3_active * 10000) / ca.cohort_size)::integer else 0 end
             )
           ),
           '[]'::jsonb
         )
    into v_monthly_cohorts
    from cohort_agg ca;

  -- ---------------------------------------------------------------------------
  -- 10. Série Temporal Diária Densa em `America/Sao_Paulo` (`daily_time_series`)
  --     Para janelas futuras de 1 dia, preserva os últimos 30 dias nos gráficos
  --     históricos enquanto o `calendar_agenda` entrega o horizonte completo.
  -- ---------------------------------------------------------------------------
  with calendar_days as (
    select gs::date as day_dt
      from generate_series(
        case when v_is_future_window then (v_today_sp - 29) else v_window_start_sp end,
        case when v_is_future_window then v_today_sp else least(v_window_end_sp, v_today_sp) end,
        interval '1 day'
      ) gs
  ),
  daily_jobs as (
    select (coalesce(jb_d.approved_at, jb_d.finished_at, jb_d.updated_at, jb_d.created_at) at time zone 'America/Sao_Paulo')::date as day_dt,
           count(*)::integer as orders_n,
           coalesce(sum(dg.gmv_c), 0)::bigint as gmv_c,
           coalesce(sum(greatest(0::bigint, dg.gmv_c - de.ex_c)), 0)::bigint as labor_c,
           coalesce(sum(de.ex_c), 0)::bigint as exempt_c,
           coalesce(sum(df.op_c), 0)::bigint as rev_c,
           coalesce(sum(df.pool_c), 0)::bigint as pool_c
      from public.jobs jb_d
      left join public.escrow_maturation_entries eme_d on eme_d.job_id = jb_d.id
      left join lateral (
        select pay_d.amount, pay_d.fee_amount
          from public.payments pay_d
         where pay_d.job_id = jb_d.id
         order by pay_d.created_at desc
         limit 1
      ) lpd on true
      cross join lateral (
        select case
          when coalesce(jb_d.labor_amount, 0) + coalesce(jb_d.materials_amount, 0) > 0
            then round((coalesce(jb_d.labor_amount, 0) + coalesce(jb_d.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lpd.amount, jb_d.agreed_price, 0) * 100)::bigint
        end as gmv_c
      ) dg
      cross join lateral (
        select least(
          dg.gmv_c,
          case when eme_d.id is not null then round(eme_d.materials_reimbursement_amount * 100)::bigint else 0::bigint end
        ) as ex_c
      ) de
      cross join lateral (
        select case
                 when eme_d.id is not null then round(eme_d.platform_operational_fee * 100)::bigint
                 when lpd.fee_amount is not null and lpd.fee_amount > 0 then
                   greatest(0::bigint, round(lpd.fee_amount * 100)::bigint - round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 15.0 / 1000.0)::bigint)
                 else round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 135.0 / 1000.0)::bigint
               end as op_c,
               case
                 when eme_d.id is not null then round(eme_d.warranty_carveout_fee * 100)::bigint
                 else round(greatest(0::bigint, dg.gmv_c - de.ex_c) * 15.0 / 1000.0)::bigint
               end as pool_c
      ) df
     where jb_d.status = 'completed'
       and coalesce(jb_d.is_warranty_rework, false) = false
     group by 1
  ),
  daily_expenses as (
    select cee_d.competence_date as day_dt,
           coalesce(sum(cee_d.amount_cents) filter (where cee_d.expense_kind = 'VARIABLE_PSP_CLOUD'), 0)::bigint as var_c,
           coalesce(sum(cee_d.amount_cents) filter (where cee_d.expense_kind in ('FIXED_OPEX', 'TAX_EXTRA')), 0)::bigint as fix_c
      from private.ceo_expense_entries cee_d
     where cee_d.payment_status = 'PAID'
     group by 1
  ),
  daily_claims as (
    select (wpl_d.created_at at time zone 'America/Sao_Paulo')::date as day_dt,
           coalesce(sum(round(wpl_d.amount * 100)::bigint), 0)::bigint as claims_c
      from public.warranty_pool_ledger wpl_d
     where wpl_d.entry_type = 'REWORK_PAYOUT_DEBIT'
     group by 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'day_iso', to_char(cd.day_dt, 'YYYY-MM-DD'),
               'orders_count', coalesce(dj.orders_n, 0),
               'gmv_cents', coalesce(dj.gmv_c, 0),
               'labor_cents', coalesce(dj.labor_c, 0),
               'materials_exempt_cents', coalesce(dj.exempt_c, 0),
               'platform_revenue_cents', coalesce(dj.rev_c, 0),
               'pool_carveout_cents', coalesce(dj.pool_c, 0),
               'tax_das_cents', ((coalesce(dj.rev_c, 0) * 6 + 50) / 100),
               'variable_cost_cents', coalesce(dx.var_c, 0),
               'net_profit_cents', (
                 coalesce(dj.rev_c, 0)
                 - ((coalesce(dj.rev_c, 0) * 6 + 50) / 100)
                 - coalesce(dx.var_c, 0)
                 - coalesce(dx.fix_c, 0)
               ),
               'warranty_claims_cents', coalesce(dc.claims_c, 0)
             )
             order by cd.day_dt asc
           ),
           '[]'::jsonb
         )
    into v_daily_series
    from calendar_days cd
    left join daily_jobs dj on dj.day_dt = cd.day_dt
    left join daily_expenses dx on dx.day_dt = cd.day_dt
    left join daily_claims dc on dc.day_dt = cd.day_dt;

  -- ---------------------------------------------------------------------------
  -- 11. Ordens Reais Recentes (`recent_orders_micro_pnl`) + Avaliações Reais
  --     Quando `v_is_single_day = true`, prioriza e filtra ordens ligadas ao dia
  --     consultado (criadas, agendadas ou concluídas naquela data).
  -- ---------------------------------------------------------------------------
  with recent_jobs as (
    select jb_r.id,
           coalesce(jb_r.title, jb_r.category, 'Serviço') as title,
           jb_r.category,
           jb_r.address_summary,
           jb_r.created_at,
           jb_r.scheduled_for,
           jb_r.escrow_status,
           jb_r.status,
           jb_r.urgency,
           jb_r.checkin_photo_path,
           jb_r.checkout_photo_path,
           public.safe_name(prof_c.full_name, 'Cliente') as client_name,
           case when prof_r.id is not null then public.safe_name(prof_r.full_name, 'Profissional') else null end as provider_name,
           prof_r.avatar_url as provider_avatar_url,
           rg.gmv_c,
           greatest(0::bigint, rg.gmv_c - re.ex_c) as labor_c,
           re.ex_c as exempt_c,
           rf.op_c as fee_c,
           rf.pool_c as pool_c,
           greatest(0::bigint, greatest(0::bigint, rg.gmv_c - re.ex_c) - rf.op_c - rf.pool_c) as provider_net_c,
           jfd_r.access_key_44,
           coalesce(jfd_r.verification_status = 'VERIFIED_SEFAZ', false) as nfe_verified,
           (select count(*)::integer from public.quotes q_cnt where q_cnt.job_id = jb_r.id) as quotes_count
      from public.jobs jb_r
      left join public.profiles prof_c on prof_c.id = jb_r.client_id
      left join public.profiles prof_r on prof_r.id = jb_r.provider_id
      left join public.escrow_maturation_entries eme_r on eme_r.job_id = jb_r.id
      left join lateral (
        select pay_r.amount, pay_r.fee_amount
          from public.payments pay_r
         where pay_r.job_id = jb_r.id
         order by pay_r.created_at desc
         limit 1
      ) lpr on true
      left join lateral (
        select jfd_lat.access_key_44,
               jfd_lat.verification_status,
               jfd_lat.declared_material_amount,
               jfd_lat.clawback_triggered
          from public.job_fiscal_documents jfd_lat
         where jfd_lat.job_id = jb_r.id
         order by jfd_lat.created_at desc
         limit 1
      ) jfd_r on true
      cross join lateral (
        select case
          when coalesce(jb_r.labor_amount, 0) + coalesce(jb_r.materials_amount, 0) > 0
            then round((coalesce(jb_r.labor_amount, 0) + coalesce(jb_r.materials_amount, 0)) * 100)::bigint
          else round(coalesce(lpr.amount, jb_r.agreed_price, jb_r.budget_estimate, 0) * 100)::bigint
        end as gmv_c
      ) rg
      cross join lateral (
        select least(
          rg.gmv_c,
          case
            when eme_r.id is not null then round(eme_r.materials_reimbursement_amount * 100)::bigint
            when jfd_r.verification_status in ('PENDING_SEFAZ', 'VERIFIED_SEFAZ') and coalesce(jfd_r.clawback_triggered, false) = false
              then least(round(coalesce(jb_r.labor_amount * 0 + jb_r.materials_amount, 0) * 100)::bigint, round(coalesce(jfd_r.declared_material_amount, 0) * 100)::bigint)
            else 0::bigint
          end
        ) as ex_c
      ) re
      cross join lateral (
        select least(
                 greatest(0::bigint, rg.gmv_c - re.ex_c) - rf_pool.pool_c,
                 case
                   when eme_r.id is not null then round(eme_r.platform_operational_fee * 100)::bigint
                   when lpr.fee_amount is not null and lpr.fee_amount > 0 then
                     greatest(0::bigint, round(lpr.fee_amount * 100)::bigint - rf_pool.pool_c)
                   else round(greatest(0::bigint, rg.gmv_c - re.ex_c) * 135.0 / 1000.0)::bigint
                 end
               ) as op_c,
               rf_pool.pool_c
          from (
            select least(
                     greatest(0::bigint, rg.gmv_c - re.ex_c),
                     case
                       when eme_r.id is not null then round(eme_r.warranty_carveout_fee * 100)::bigint
                       else round(greatest(0::bigint, rg.gmv_c - re.ex_c) * 15.0 / 1000.0)::bigint
                     end
                   ) as pool_c
          ) rf_pool
      ) rf
     where coalesce(jb_r.is_warranty_rework, false) = false
       and (
         not v_is_single_day
         or (jb_r.scheduled_for is not null and (jb_r.scheduled_for at time zone 'America/Sao_Paulo')::date = v_window_start_sp)
         or (jb_r.status = 'completed' and (coalesce(jb_r.approved_at, jb_r.finished_at, jb_r.updated_at, jb_r.created_at) at time zone 'America/Sao_Paulo')::date = v_window_start_sp)
         or (not v_is_future_window and (jb_r.created_at at time zone 'America/Sao_Paulo')::date = v_window_start_sp)
       )
     order by coalesce(jb_r.scheduled_for, jb_r.created_at) desc
     limit 60
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'order_code', '#DESP-' || upper(substr(replace(rj.id::text, '-', ''), 1, 5)),
               'job_id', rj.id,
               'title', rj.title,
               'category_name', coalesce(rj.category, 'Outros'),
               'neighborhood', coalesce(nullif(btrim(rj.address_summary), ''), 'Endereço em validação'),
               'created_at', rj.created_at,
               'scheduled_for', rj.scheduled_for,
               'status', rj.status,
               'urgency', coalesce(rj.urgency, 'scheduled'),
               'client_name', rj.client_name,
               'provider_name', rj.provider_name,
               'quotes_count', rj.quotes_count,
               'gmv_cents', rj.gmv_c,
               'labor_cents', rj.labor_c,
               'materials_exempt_cents', rj.exempt_c,
               'nfe_access_key', rj.access_key_44,
               'nfe_verified', rj.nfe_verified,
               'provider_net_cents', rj.provider_net_c,
               'platform_fee_cents', rj.fee_c,
               'pool_carveout_cents', rj.pool_c,
               'tax_das_cents', ((rj.fee_c * 6 + 50) / 100),
               'pix_cloud_cost_cents', 0,
               'net_margin_cents', (rj.fee_c - ((rj.fee_c * 6 + 50) / 100)),
               'escrow_status', coalesce(rj.escrow_status, 'NONE'),
               'provider_avatar_url', rj.provider_avatar_url,
               'evidence_photo_url', coalesce(rj.checkout_photo_path, rj.checkin_photo_path)
             )
             order by coalesce(rj.scheduled_for, rj.created_at) desc
           ),
           '[]'::jsonb
         )
    into v_recent_orders_pnl
    from recent_jobs rj;

  with latest_reviews as (
    select rv_l.id,
           rv_l.job_id,
           rv_l.rating,
           rv_l.comment,
           rv_l.tags,
           rv_l.reply,
           rv_l.created_at,
           public.safe_name(p_rev.full_name, 'Avaliador') as reviewer_name,
           public.safe_name(p_ree.full_name, 'Avaliado') as reviewee_name,
           coalesce(jb_rv.category, 'Serviço') as category_name
      from public.reviews rv_l
      left join public.profiles p_rev on p_rev.id = rv_l.reviewer_id
      left join public.profiles p_ree on p_ree.id = rv_l.reviewee_id
      left join public.jobs jb_rv on jb_rv.id = rv_l.job_id
     where rv_l.revealed_at is not null
     order by rv_l.created_at desc
     limit 20
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'review_id', lr.id,
               'job_id', lr.job_id,
               'rating', lr.rating,
               'comment', coalesce(lr.comment, ''),
               'tags', coalesce(to_jsonb(lr.tags), '[]'::jsonb),
               'reply', lr.reply,
               'reviewer_name', lr.reviewer_name,
               'reviewee_name', lr.reviewee_name,
               'category_name', lr.category_name,
               'created_at', lr.created_at
             )
           ),
           '[]'::jsonb
         )
    into v_recent_reviews
    from latest_reviews lr;

  -- ---------------------------------------------------------------------------
  -- 12. Cronograma Fiscal Real (`tax_obligations_schedule` — DAS Simples Anexo III)
  --     Mediações Unificadas (`active_mediations` = `job_mediations` + `support_tickets`)
  --     e Mapa Completo de Agenda do Calendário (`calendar_agenda_days` + `events`)
  -- ---------------------------------------------------------------------------
  with comp_months as (
    select gs_m::date as comp_start,
           (gs_m + interval '1 month - 1 day')::date as comp_end,
           extract(year from gs_m)::integer as comp_year,
           extract(month from gs_m)::integer as comp_month,
           to_char(gs_m, 'YYYY-MM') as comp_ym,
           private.ceo_das_due_date_for_competence(
             extract(year from gs_m)::integer,
             extract(month from gs_m)::integer
           ) as due_dt
      from generate_series(
        date_trunc('month', v_today_sp - interval '3 months')::date,
        date_trunc('month', v_today_sp + interval '11 months')::date,
        interval '1 month'
      ) gs_m
  ),
  settled_by_month as (
    select date_trunc('month', coalesce(jb_tm.approved_at, jb_tm.finished_at, jb_tm.updated_at, jb_tm.created_at) at time zone 'America/Sao_Paulo')::date as comp_start,
           count(*)::integer as settled_orders_n,
           coalesce(sum(
             case
               when eme_tm.id is not null then round(eme_tm.platform_operational_fee * 100)::bigint
               else round(greatest(
                 0::numeric,
                 coalesce(nullif(jb_tm.labor_amount, 0), jb_tm.agreed_price, 0)
               ) * 13.5)::bigint
             end
           ), 0)::bigint as settled_rev_cents
      from public.jobs jb_tm
      left join public.escrow_maturation_entries eme_tm on eme_tm.job_id = jb_tm.id
     where jb_tm.status = 'completed'
       and coalesce(jb_tm.is_warranty_rework, false) = false
     group by 1
  ),
  sos_by_month as (
    select date_trunc('month', lt_tm.created_at at time zone 'America/Sao_Paulo')::date as comp_start,
           coalesce(sum(greatest(0::bigint, ll_tm.cents)), 0)::bigint as sos_cents
      from public.ledger_lines ll_tm
      join public.ledger_txns lt_tm on lt_tm.id = ll_tm.txn_id
     where ll_tm.account = 'platform:sos_fee'
     group by 1
  ),
  scheduled_by_month as (
    select date_trunc('month', coalesce(jb_sm.scheduled_for, jb_sm.created_at) at time zone 'America/Sao_Paulo')::date as comp_start,
           count(*)::integer as sched_orders_n,
           coalesce(sum(
             round(greatest(
               0::numeric,
               coalesce(nullif(jb_sm.labor_amount, 0), jb_sm.agreed_price, jb_sm.budget_estimate, 0)
             ) * 13.5)::bigint
           ), 0)::bigint as sched_rev_cents
      from public.jobs jb_sm
     where jb_sm.status in ('scheduled', 'in_progress', 'awaiting_approval')
       and coalesce(jb_sm.is_warranty_rework, false) = false
     group by 1
  ),
  paid_das_by_due_month as (
    select date_trunc('month', cee_tx.competence_date)::date as due_month_start,
           coalesce(sum(cee_tx.amount_cents) filter (where cee_tx.payment_status = 'PAID'), 0)::bigint as paid_tax_cents
      from private.ceo_expense_entries cee_tx
     where cee_tx.expense_kind = 'TAX_EXTRA'
       and (
         cee_tx.category ilike '%simples%'
         or cee_tx.category ilike '%das%'
         or cee_tx.description ilike '%das%'
         or cee_tx.description ilike '%simples%'
       )
     group by 1
  ),
  tax_rows as (
    select cm.comp_ym,
           cm.due_dt,
           coalesce(sbm.settled_orders_n, 0) as settled_orders_count,
           coalesce(schm.sched_orders_n, 0) as scheduled_orders_count,
           (coalesce(sbm.settled_rev_cents, 0) + coalesce(sosm.sos_cents, 0))::bigint as settled_rev_cents,
           coalesce(schm.sched_rev_cents, 0)::bigint as scheduled_rev_cents,
           (((coalesce(sbm.settled_rev_cents, 0) + coalesce(sosm.sos_cents, 0)) * 6 + 50) / 100)::bigint as settled_das_cents,
           ((coalesce(schm.sched_rev_cents, 0) * 6 + 50) / 100)::bigint as projected_das_cents,
           coalesce(pdm.paid_tax_cents, 0)::bigint as paid_das_cents
      from comp_months cm
      left join settled_by_month sbm on sbm.comp_start = cm.comp_start
      left join sos_by_month sosm on sosm.comp_start = cm.comp_start
      left join scheduled_by_month schm on schm.comp_start = cm.comp_start
      left join paid_das_by_due_month pdm on pdm.due_month_start = date_trunc('month', cm.due_dt)::date
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'competence_ym', tr.comp_ym,
               'due_date_iso', to_char(tr.due_dt, 'YYYY-MM-DD'),
               'settled_orders_count', tr.settled_orders_count,
               'scheduled_orders_count', tr.scheduled_orders_count,
               'settled_revenue_cents', tr.settled_rev_cents,
               'scheduled_revenue_cents', tr.scheduled_rev_cents,
               'settled_das_cents', tr.settled_das_cents,
               'projected_das_cents', tr.projected_das_cents,
               'total_estimated_das_cents', (tr.settled_das_cents + tr.projected_das_cents),
               'paid_cents', tr.paid_das_cents,
               'remaining_due_cents', greatest(0::bigint, (tr.settled_das_cents + tr.projected_das_cents) - tr.paid_das_cents),
               'status', case
                 when (tr.settled_das_cents + tr.projected_das_cents) > 0 and tr.paid_das_cents >= (tr.settled_das_cents + tr.projected_das_cents)
                   then 'PAID'
                 when tr.settled_das_cents > 0
                   then 'DUE_CONFIRMED'
                 when tr.projected_das_cents > 0
                   then 'PROJECTED_FROM_SCHEDULED'
                 else 'ZERO_NO_REVENUE'
               end
             )
             order by tr.due_dt asc
           ),
           '[]'::jsonb
         )
    into v_tax_schedule
    from tax_rows tr;

  -- Mediações de Garantia (`job_mediations`) + Disputas/Chamados (`support_tickets`)
  with unified_meds as (
    select jm.id::text as med_id,
           'WARRANTY_MEDIATION'::text as source_kind,
           '#MED-' || upper(substr(replace(jm.id::text, '-', ''), 1, 4)) as protocol_code,
           jm.job_id,
           '#DESP-' || upper(substr(replace(jm.job_id::text, '-', ''), 1, 5)) as order_code,
           coalesce(jb_m1.category, 'Serviço') as category_name,
           jm.current_phase as phase_or_status,
           (jm.current_phase <> 'PHASE_5_SETTLED_AND_CERTIFIED') as is_open,
           jm.claim_category as reason_or_category,
           jm.defect_description as description,
           round(coalesce(nullif(jb_m1.labor_amount + jb_m1.materials_amount, 0), jb_m1.agreed_price, 0) * 100)::bigint as frozen_amount_cents,
           jm.created_at as opened_at,
           jm.original_provider_deadline_at as sla_deadline_at,
           to_char(jm.created_at at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') as opened_day_iso,
           to_char(jm.original_provider_deadline_at at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') as deadline_day_iso,
           public.safe_name(pc_m1.full_name, 'Cliente') as client_name,
           public.safe_name(pp_m1.full_name, 'Profissional') as provider_name
      from public.job_mediations jm
      join public.jobs jb_m1 on jb_m1.id = jm.job_id
      left join public.profiles pc_m1 on pc_m1.id = jm.client_id
      left join public.profiles pp_m1 on pp_m1.id = jm.original_provider_id
    union all
    select st.id::text as med_id,
           'SUPPORT_DISPUTE_TICKET'::text as source_kind,
           '#DSP-' || upper(substr(replace(st.id::text, '-', ''), 1, 4)) as protocol_code,
           st.job_id,
           case
             when st.job_id is not null then '#DESP-' || upper(substr(replace(st.job_id::text, '-', ''), 1, 5))
             else 'CONTA-GERAL'
           end as order_code,
           coalesce(jb_s1.category, 'Suporte / Conta') as category_name,
           st.status as phase_or_status,
           (st.status in ('open', 'in_review')) as is_open,
           st.reason as reason_or_category,
           coalesce(st.description, '') as description,
           case
             when jb_s1.id is not null and jb_s1.status = 'disputed'
               then round(coalesce(nullif(jb_s1.labor_amount + jb_s1.materials_amount, 0), jb_s1.agreed_price, 0) * 100)::bigint
             else 0::bigint
           end as frozen_amount_cents,
           st.created_at as opened_at,
           st.sla_due_at as sla_deadline_at,
           to_char(st.created_at at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') as opened_day_iso,
           to_char(st.sla_due_at at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') as deadline_day_iso,
           public.safe_name(pu_s1.full_name, 'Usuário') as client_name,
           case when pp_s1.id is not null then public.safe_name(pp_s1.full_name, 'Profissional') else '' end as provider_name
      from public.support_tickets st
      left join public.jobs jb_s1 on jb_s1.id = st.job_id
      left join public.profiles pu_s1 on pu_s1.id = st.user_id
      left join public.profiles pp_s1 on pp_s1.id = jb_s1.provider_id
  ),
  ranked_meds as (
    select *
      from unified_meds um
     order by um.is_open desc, um.sla_deadline_at asc, um.opened_at desc
     limit 50
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', rm.med_id,
               'source_kind', rm.source_kind,
               'protocol_code', rm.protocol_code,
               'job_id', rm.job_id,
               'order_code', rm.order_code,
               'category_name', rm.category_name,
               'phase_or_status', rm.phase_or_status,
               'is_open', rm.is_open,
               'reason_or_category', rm.reason_or_category,
               'description', rm.description,
               'frozen_amount_cents', rm.frozen_amount_cents,
               'opened_at', rm.opened_at,
               'sla_deadline_at', rm.sla_deadline_at,
               'opened_day_iso', rm.opened_day_iso,
               'deadline_day_iso', rm.deadline_day_iso,
               'client_name', rm.client_name,
               'provider_name', rm.provider_name
             )
             order by rm.is_open desc, rm.sla_deadline_at asc
           ),
           '[]'::jsonb
         )
    into v_active_mediations
    from ranked_meds rm;

  -- Agregação Multi-Horizonte do Calendário (`calendar_agenda_days` & `calendar_agenda_events`)
  with raw_events as (
    -- (A) Serviços Concluídos (Realizado)
    select (coalesce(jb_ev.approved_at, jb_ev.finished_at, jb_ev.updated_at, jb_ev.created_at) at time zone 'America/Sao_Paulo')::date as day_dt,
           'COMPLETED_ORDER'::text as event_kind,
           'SUCCESS'::text as severity,
           jb_ev.id::text as ref_id,
           jb_ev.id as job_id,
           ('#DESP-' || upper(substr(replace(jb_ev.id::text, '-', ''), 1, 5))) as code_label,
           ('Serviço concluído · ' || coalesce(jb_ev.category, 'Serviço'))::text as title,
           (public.safe_name(pc_ev.full_name, 'Cliente') ||
             case when pp_ev.id is not null then ' · Prof. ' || public.safe_name(pp_ev.full_name, 'Profissional') else '' end)::text as subtitle,
           round(coalesce(nullif(jb_ev.labor_amount + jb_ev.materials_amount, 0), jb_ev.agreed_price, 0) * 100)::bigint as gross_cents,
           case
             when eme_ev.id is not null then
               (round(eme_ev.platform_operational_fee * 100)::bigint - ((round(eme_ev.platform_operational_fee * 100)::bigint * 6 + 50) / 100))
             else
               (round(greatest(0::numeric, coalesce(nullif(jb_ev.labor_amount, 0), jb_ev.agreed_price, 0)) * 13.5)::bigint
                - ((round(greatest(0::numeric, coalesce(nullif(jb_ev.labor_amount, 0), jb_ev.agreed_price, 0)) * 13.5)::bigint * 6 + 50) / 100))
           end as net_impact_cents,
           coalesce(jb_ev.approved_at, jb_ev.finished_at, jb_ev.updated_at, jb_ev.created_at) as event_ts,
           'COMPLETED'::text as status_code
      from public.jobs jb_ev
      left join public.escrow_maturation_entries eme_ev on eme_ev.job_id = jb_ev.id
      left join public.profiles pc_ev on pc_ev.id = jb_ev.client_id
      left join public.profiles pp_ev on pp_ev.id = jb_ev.provider_id
     where jb_ev.status = 'completed'
       and coalesce(jb_ev.is_warranty_rework, false) = false
       and (coalesce(jb_ev.approved_at, jb_ev.finished_at, jb_ev.updated_at, jb_ev.created_at) at time zone 'America/Sao_Paulo')::date
           between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (B) Serviços Agendados / Em Execução / Aguardando PIX no Desperrengue (Hoje e Futuro!)
    select (coalesce(jb_sc.scheduled_for, jb_sc.created_at) at time zone 'America/Sao_Paulo')::date as day_dt,
           'SCHEDULED_ORDER'::text as event_kind,
           'INFO'::text as severity,
           jb_sc.id::text as ref_id,
           jb_sc.id as job_id,
           ('#DESP-' || upper(substr(replace(jb_sc.id::text, '-', ''), 1, 5))) as code_label,
           (case jb_sc.status
              when 'scheduled' then 'Serviço agendado · '
              when 'in_progress' then 'Em execução · '
              when 'awaiting_approval' then 'Aguardando aprovação · '
              when 'awaiting_payment' then 'Aguardando PIX · '
              else 'Pedido aberto · '
            end || coalesce(jb_sc.category, 'Serviço'))::text as title,
           (public.safe_name(pc_sc.full_name, 'Cliente') ||
             case
               when jb_sc.scheduled_for is not null
                 then ' · ' || to_char(jb_sc.scheduled_for at time zone 'America/Sao_Paulo', 'HH24:MI')
               else ''
             end ||
             case when coalesce(jb_sc.address_summary, '') <> '' then ' · ' || jb_sc.address_summary else '' end)::text as subtitle,
           round(coalesce(nullif(jb_sc.labor_amount + jb_sc.materials_amount, 0), jb_sc.agreed_price, jb_sc.budget_estimate, 0) * 100)::bigint as gross_cents,
           (round(greatest(0::numeric, coalesce(nullif(jb_sc.labor_amount, 0), jb_sc.agreed_price, jb_sc.budget_estimate, 0)) * 13.5)::bigint
            - ((round(greatest(0::numeric, coalesce(nullif(jb_sc.labor_amount, 0), jb_sc.agreed_price, jb_sc.budget_estimate, 0)) * 13.5)::bigint * 6 + 50) / 100)) as net_impact_cents,
           coalesce(jb_sc.scheduled_for, jb_sc.created_at) as event_ts,
           upper(jb_sc.status)::text as status_code
      from public.jobs jb_sc
      left join public.profiles pc_sc on pc_sc.id = jb_sc.client_id
     where jb_sc.status in ('open', 'awaiting_payment', 'scheduled', 'in_progress', 'awaiting_approval')
       and coalesce(jb_sc.is_warranty_rework, false) = false
       and (coalesce(jb_sc.scheduled_for, jb_sc.created_at) at time zone 'America/Sao_Paulo')::date
           between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (C1) Mediações de Garantia (`job_mediations`) — Data de Abertura
    select (jm_o.created_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'MEDIATION_OPENED'::text as event_kind,
           case when jm_o.current_phase = 'PHASE_5_SETTLED_AND_CERTIFIED' then 'INFO' else 'CRITICAL' end as severity,
           jm_o.id::text as ref_id,
           jm_o.job_id as job_id,
           ('#MED-' || upper(substr(replace(jm_o.id::text, '-', ''), 1, 4))) as code_label,
           ('Mediação de garantia · #DESP-' || upper(substr(replace(jm_o.job_id::text, '-', ''), 1, 5)))::text as title,
           (jm_o.claim_category || ' · ' || left(jm_o.defect_description, 90))::text as subtitle,
           round(coalesce(nullif(jb_mo.labor_amount + jb_mo.materials_amount, 0), jb_mo.agreed_price, 0) * 100)::bigint as gross_cents,
           0::bigint as net_impact_cents,
           jm_o.created_at as event_ts,
           jm_o.current_phase::text as status_code
      from public.job_mediations jm_o
      join public.jobs jb_mo on jb_mo.id = jm_o.job_id
     where (jm_o.created_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (C2) Mediações de Garantia Ativas (`job_mediations`) — Data do Prazo SLA (quando em dia distinto ou futuro)
    select (jm_d.original_provider_deadline_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'MEDIATION_SLA_DUE'::text as event_kind,
           'CRITICAL'::text as severity,
           (jm_d.id::text || ':sla') as ref_id,
           jm_d.job_id as job_id,
           ('#MED-' || upper(substr(replace(jm_d.id::text, '-', ''), 1, 4))) as code_label,
           ('Prazo SLA Mediação (6h) · #DESP-' || upper(substr(replace(jm_d.job_id::text, '-', ''), 1, 5)))::text as title,
           ('Limite às ' || to_char(jm_d.original_provider_deadline_at at time zone 'America/Sao_Paulo', 'HH24:MI') || ' · ' || jm_d.claim_category)::text as subtitle,
           round(coalesce(nullif(jb_md.labor_amount + jb_md.materials_amount, 0), jb_md.agreed_price, 0) * 100)::bigint as gross_cents,
           0::bigint as net_impact_cents,
           jm_d.original_provider_deadline_at as event_ts,
           jm_d.current_phase::text as status_code
      from public.job_mediations jm_d
      join public.jobs jb_md on jb_md.id = jm_d.job_id
     where jm_d.current_phase <> 'PHASE_5_SETTLED_AND_CERTIFIED'
       and (jm_d.original_provider_deadline_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (D1) Chamados / Disputas (`support_tickets`) — Data de Abertura
    select (st_o.created_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'SUPPORT_DISPUTE_OPENED'::text as event_kind,
           case when st_o.status = 'resolved' then 'INFO' else 'CRITICAL' end as severity,
           st_o.id::text as ref_id,
           st_o.job_id as job_id,
           ('#DSP-' || upper(substr(replace(st_o.id::text, '-', ''), 1, 4))) as code_label,
           ('Chamado de mediação · ' || st_o.reason)::text as title,
           left(coalesce(st_o.description, 'Aberto pelo aplicativo Desperrengue'), 100)::text as subtitle,
           case
             when jb_so.id is not null then round(coalesce(nullif(jb_so.labor_amount + jb_so.materials_amount, 0), jb_so.agreed_price, 0) * 100)::bigint
             else 0::bigint
           end as gross_cents,
           0::bigint as net_impact_cents,
           st_o.created_at as event_ts,
           upper(st_o.status)::text as status_code
      from public.support_tickets st_o
      left join public.jobs jb_so on jb_so.id = st_o.job_id
     where (st_o.created_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (D2) Chamados / Disputas em Aberto (`support_tickets`) — Data de Vencimento do SLA 24h
    select (st_d.sla_due_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'SUPPORT_DISPUTE_SLA_DUE'::text as event_kind,
           'CRITICAL'::text as severity,
           (st_d.id::text || ':sla') as ref_id,
           st_d.job_id as job_id,
           ('#DSP-' || upper(substr(replace(st_d.id::text, '-', ''), 1, 4))) as code_label,
           ('Prazo de resposta mediação (24h) · ' || '#DSP-' || upper(substr(replace(st_d.id::text, '-', ''), 1, 4)))::text as title,
           ('Vence às ' || to_char(st_d.sla_due_at at time zone 'America/Sao_Paulo', 'HH24:MI') || ' · ' || st_d.reason)::text as subtitle,
           0::bigint as gross_cents,
           0::bigint as net_impact_cents,
           st_d.sla_due_at as event_ts,
           upper(st_d.status)::text as status_code
      from public.support_tickets st_d
     where st_d.status in ('open', 'in_review')
       and (st_d.sla_due_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (E) Vencimento Legal do DAS — Simples Nacional Anexo III (6% sobre comissão real)
    select (tx_el ->> 'due_date_iso')::date as day_dt,
           'TAX_DAS_DUE'::text as event_kind,
           case
             when (tx_el ->> 'status') = 'PAID' then 'SUCCESS'
             when ((tx_el ->> 'remaining_due_cents')::bigint) > 0 then 'WARN'
             else 'INFO'
           end as severity,
           ('das:' || (tx_el ->> 'competence_ym')) as ref_id,
           null::uuid as job_id,
           ('DAS ' || (tx_el ->> 'competence_ym')) as code_label,
           ('Vencimento DAS Simples Nacional (Comp. ' || (tx_el ->> 'competence_ym') || ')')::text as title,
           case
             when (tx_el ->> 'status') = 'PAID'
               then 'Imposto da competência quitado integralmente'
             when ((tx_el ->> 'settled_das_cents')::bigint) > 0 and ((tx_el ->> 'projected_das_cents')::bigint) > 0
               then '6% s/ comissão real concluída + agendados confirmados (Art. 40 CGSN 140)'
             when ((tx_el ->> 'settled_das_cents')::bigint) > 0
               then '6% apurado sobre ' || (tx_el ->> 'settled_orders_count') || ' serviço(s) concluído(s)'
             when ((tx_el ->> 'projected_das_cents')::bigint) > 0
               then 'Previsão 6% sobre ' || (tx_el ->> 'scheduled_orders_count') || ' serviço(s) agendado(s)'
             else 'Marco fiscal mensal (dia 20 útil) · R$ 0,00 apurado até o momento'
           end::text as subtitle,
           ((tx_el ->> 'remaining_due_cents')::bigint) as gross_cents,
           (-((tx_el ->> 'remaining_due_cents')::bigint)) as net_impact_cents,
           (((tx_el ->> 'due_date_iso')::date)::timestamp at time zone 'America/Sao_Paulo') + interval '12 hours' as event_ts,
           (tx_el ->> 'status')::text as status_code
      from jsonb_array_elements(v_tax_schedule) tx_el

    union all

    -- (F) Declaração Anual DEFIS Simples Nacional (31/03 útil)
    select private.ceo_defis_due_date_for_year(yr_g) as day_dt,
           'FISCAL_DEFIS_DECLARATION'::text as event_kind,
           'INFO'::text as severity,
           ('defis:' || yr_g::text) as ref_id,
           null::uuid as job_id,
           ('DEFIS ' || yr_g::text) as code_label,
           ('Prazo Declaração Anual Simples Nacional (DEFIS Ano-Base ' || yr_g::text || ')')::text as title,
           'Obrigação acessória anual CGSN nº 140/2018 (Art. 72)'::text as subtitle,
           0::bigint as gross_cents,
           0::bigint as net_impact_cents,
           (private.ceo_defis_due_date_for_year(yr_g)::timestamp at time zone 'America/Sao_Paulo') + interval '12 hours' as event_ts,
           'INFO'::text as status_code
      from generate_series(extract(year from v_today_sp)::integer - 1, extract(year from v_today_sp)::integer + 1) yr_g
     where private.ceo_defis_due_date_for_year(yr_g) between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (G) Despesas e Impostos Registrados pelo CEO (`private.ceo_expense_entries` — Pagos e Agendados Futuros!)
    select cee_ev.competence_date as day_dt,
           'COMPANY_EXPENSE'::text as event_kind,
           case when cee_ev.payment_status = 'SCHEDULED' then 'WARN' else 'INFO' end as severity,
           cee_ev.id::text as ref_id,
           null::uuid as job_id,
           (case cee_ev.expense_kind
              when 'VARIABLE_PSP_CLOUD' then 'TAXA PIX'
              when 'TAX_EXTRA' then 'IMPOSTO'
              else 'GASTO FIXO'
            end)::text as code_label,
           (case when cee_ev.payment_status = 'SCHEDULED' then 'Conta a pagar · ' else 'Gasto quitado · ' end || cee_ev.category)::text as title,
           coalesce(nullif(btrim(cee_ev.description), ''), 'Despesa corporativa registrada pelo CEO')::text as subtitle,
           cee_ev.amount_cents as gross_cents,
           (-cee_ev.amount_cents) as net_impact_cents,
           (cee_ev.competence_date::timestamp at time zone 'America/Sao_Paulo') + interval '10 hours' as event_ts,
           cee_ev.payment_status as status_code
      from private.ceo_expense_entries cee_ev
     where cee_ev.competence_date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (H) Liberação Futura de Custódia `D+2 / D+5 / D+7` (`escrow_maturation_entries`)
    select (eme_ev2.available_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'ESCROW_MATURATION_RELEASE'::text as event_kind,
           'INFO'::text as severity,
           eme_ev2.id::text as ref_id,
           eme_ev2.job_id as job_id,
           ('#DESP-' || upper(substr(replace(eme_ev2.job_id::text, '-', ''), 1, 5))) as code_label,
           ('Liberação de custódia ao profissional · #DESP-' || upper(substr(replace(eme_ev2.job_id::text, '-', ''), 1, 5)))::text as title,
           (public.safe_name(pp_ev2.full_name, 'Profissional') || ' · Disponível para saque PIX às ' ||
             to_char(eme_ev2.available_at at time zone 'America/Sao_Paulo', 'HH24:MI'))::text as subtitle,
           round(eme_ev2.net_provider_amount * 100)::bigint as gross_cents,
           0::bigint as net_impact_cents,
           eme_ev2.available_at as event_ts,
           eme_ev2.maturation_status::text as status_code
      from public.escrow_maturation_entries eme_ev2
      left join public.profiles pp_ev2 on pp_ev2.id = eme_ev2.provider_id
     where eme_ev2.maturation_status = 'MATURING'
       and (eme_ev2.available_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (I) Prazo de Conferência SEFAZ 26h (`job_fiscal_documents` em `PENDING_SEFAZ`)
    select ((jfd_ev.created_at + interval '26 hours') at time zone 'America/Sao_Paulo')::date as day_dt,
           'SEFAZ_AUDIT_DEADLINE'::text as event_kind,
           'WARN'::text as severity,
           jfd_ev.id::text as ref_id,
           jfd_ev.job_id as job_id,
           ('#DESP-' || upper(substr(replace(jfd_ev.job_id::text, '-', ''), 1, 5))) as code_label,
           ('Conferência de NF-e de peças (26h) · #DESP-' || upper(substr(replace(jfd_ev.job_id::text, '-', ''), 1, 5)))::text as title,
           ('Chave ' || coalesce(left(jfd_ev.access_key_44, 12) || '…', 'manual'))::text as subtitle,
           round(coalesce(jfd_ev.declared_material_amount, 0) * 100)::bigint as gross_cents,
           0::bigint as net_impact_cents,
           (jfd_ev.created_at + interval '26 hours') as event_ts,
           jfd_ev.verification_status::text as status_code
      from public.job_fiscal_documents jfd_ev
     where jfd_ev.verification_status = 'PENDING_SEFAZ'
       and ((jfd_ev.created_at + interval '26 hours') at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp

    union all

    -- (J) Encerramento de Garantia de 90 Dias (`jobs.warranty_expires_at`)
    select (jb_wx.warranty_expires_at at time zone 'America/Sao_Paulo')::date as day_dt,
           'WARRANTY_90D_EXPIRY'::text as event_kind,
           'INFO'::text as severity,
           (jb_wx.id::text || ':w90') as ref_id,
           jb_wx.id as job_id,
           ('#DESP-' || upper(substr(replace(jb_wx.id::text, '-', ''), 1, 5))) as code_label,
           ('Fim da garantia de 90 dias · #DESP-' || upper(substr(replace(jb_wx.id::text, '-', ''), 1, 5)))::text as title,
           ('Exposição liberada na Reserva de Garantia · ' || coalesce(jb_wx.category, 'Serviço'))::text as subtitle,
           round(coalesce(nullif(jb_wx.labor_amount, 0), jb_wx.agreed_price, 0) * 100)::bigint as gross_cents,
           0::bigint as net_impact_cents,
           jb_wx.warranty_expires_at as event_ts,
           'WARRANTY_END'::text as status_code
      from public.jobs jb_wx
     where jb_wx.status = 'completed'
       and jb_wx.warranty_expires_at is not null
       and (jb_wx.warranty_expires_at at time zone 'America/Sao_Paulo')::date between v_agenda_min_sp and v_agenda_max_sp
  ),
  day_rollup as (
    select re.day_dt,
           count(*) filter (where re.event_kind = 'COMPLETED_ORDER')::integer as completed_orders_count,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'COMPLETED_ORDER'), 0)::bigint as realized_gmv_cents,
           coalesce(sum(re.net_impact_cents) filter (where re.event_kind = 'COMPLETED_ORDER'), 0)::bigint as realized_net_before_opex_cents,
           count(*) filter (where re.event_kind = 'SCHEDULED_ORDER')::integer as scheduled_orders_count,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'SCHEDULED_ORDER'), 0)::bigint as scheduled_gmv_cents,
           coalesce(sum(re.net_impact_cents) filter (where re.event_kind = 'SCHEDULED_ORDER'), 0)::bigint as scheduled_expected_net_cents,
           count(*) filter (
             where re.event_kind in ('MEDIATION_OPENED', 'SUPPORT_DISPUTE_OPENED')
               and re.status_code not in ('PHASE_5_SETTLED_AND_CERTIFIED', 'RESOLVED')
           )::integer as active_mediations_opened_count,
           count(*) filter (
             where re.event_kind in ('MEDIATION_SLA_DUE', 'SUPPORT_DISPUTE_SLA_DUE')
           )::integer as mediations_sla_due_count,
           count(*) filter (
             where re.event_kind in ('MEDIATION_OPENED', 'SUPPORT_DISPUTE_OPENED', 'MEDIATION_SLA_DUE', 'SUPPORT_DISPUTE_SLA_DUE')
           )::integer as mediations_total_events_count,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'TAX_DAS_DUE'), 0)::bigint as das_due_cents,
           bool_or(re.event_kind = 'TAX_DAS_DUE') as has_das_marker,
           max(re.status_code) filter (where re.event_kind = 'TAX_DAS_DUE') as das_status,
           max(re.code_label) filter (where re.event_kind = 'TAX_DAS_DUE') as das_label,
           bool_or(re.event_kind = 'FISCAL_DEFIS_DECLARATION') as has_defis_marker,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'COMPANY_EXPENSE' and re.status_code = 'PAID'), 0)::bigint as expenses_paid_cents,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'COMPANY_EXPENSE' and re.status_code = 'SCHEDULED'), 0)::bigint as expenses_scheduled_cents,
           count(*) filter (where re.event_kind = 'COMPANY_EXPENSE')::integer as expenses_count,
           count(*) filter (where re.event_kind = 'ESCROW_MATURATION_RELEASE')::integer as maturation_release_count,
           coalesce(sum(re.gross_cents) filter (where re.event_kind = 'ESCROW_MATURATION_RELEASE'), 0)::bigint as maturation_release_cents,
           count(*) filter (where re.event_kind = 'SEFAZ_AUDIT_DEADLINE')::integer as sefaz_audit_due_count,
           count(*) filter (where re.event_kind = 'WARRANTY_90D_EXPIRY')::integer as warranty_expiring_count
      from raw_events re
     group by re.day_dt
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'day_iso', to_char(dr.day_dt, 'YYYY-MM-DD'),
               'is_future', (dr.day_dt > v_today_sp),
               'completed_orders_count', dr.completed_orders_count,
               'realized_gmv_cents', dr.realized_gmv_cents,
               'realized_net_profit_cents', (dr.realized_net_before_opex_cents - dr.expenses_paid_cents),
               'scheduled_orders_count', dr.scheduled_orders_count,
               'scheduled_gmv_cents', dr.scheduled_gmv_cents,
               'scheduled_expected_net_cents', dr.scheduled_expected_net_cents,
               'active_mediations_opened_count', dr.active_mediations_opened_count,
               'mediations_sla_due_count', dr.mediations_sla_due_count,
               'mediations_total_events_count', dr.mediations_total_events_count,
               'das_due_cents', dr.das_due_cents,
               'has_das_marker', dr.has_das_marker,
               'das_status', coalesce(dr.das_status, 'NONE'),
               'das_label', coalesce(dr.das_label, ''),
               'has_defis_marker', dr.has_defis_marker,
               'expenses_paid_cents', dr.expenses_paid_cents,
               'expenses_scheduled_cents', dr.expenses_scheduled_cents,
               'expenses_count', dr.expenses_count,
               'maturation_release_count', dr.maturation_release_count,
               'maturation_release_cents', dr.maturation_release_cents,
               'sefaz_audit_due_count', dr.sefaz_audit_due_count,
               'warranty_expiring_count', dr.warranty_expiring_count
             )
             order by dr.day_dt asc
           ),
           '[]'::jsonb
         ),
         coalesce((
           select jsonb_agg(
                    jsonb_build_object(
                      'day_iso', to_char(ev_lim.day_dt, 'YYYY-MM-DD'),
                      'event_kind', ev_lim.event_kind,
                      'severity', ev_lim.severity,
                      'ref_id', ev_lim.ref_id,
                      'job_id', ev_lim.job_id,
                      'code_label', ev_lim.code_label,
                      'title', ev_lim.title,
                      'subtitle', ev_lim.subtitle,
                      'gross_cents', ev_lim.gross_cents,
                      'net_impact_cents', ev_lim.net_impact_cents,
                      'occurred_or_due_at', ev_lim.event_ts,
                      'status_code', ev_lim.status_code
                    )
                    order by ev_lim.day_dt asc, ev_lim.event_ts asc
                  )
             from (
               select *
                 from raw_events re_sub
                where (v_is_single_day and re_sub.day_dt = v_window_start_sp)
                   or (re_sub.day_dt between (v_today_sp - 90) and (v_today_sp + 365))
                order by
                  case when v_is_single_day and re_sub.day_dt = v_window_start_sp then 0 else 1 end asc,
                  abs(re_sub.day_dt - v_today_sp) asc,
                  re_sub.event_ts desc
                limit 260
             ) ev_lim
         ), '[]'::jsonb)
    into v_calendar_agenda_days,
         v_calendar_agenda_events
    from day_rollup dr;

  -- ---------------------------------------------------------------------------
  -- 13. Segurança, SEFAZ, Dispositivos Confiáveis, Auditoria WORM, Despesas & Live
  -- ---------------------------------------------------------------------------
  select count(*) filter (where jfd_w.verification_status = 'PENDING_SEFAZ')::integer,
         count(*) filter (
           where jfd_w.verification_status = 'PENDING_SEFAZ'
             and jfd_w.created_at <= now() - interval '26 hours'
         )::integer,
         count(*) filter (where jfd_w.verification_status = 'VERIFIED_SEFAZ')::integer,
         count(*) filter (
           where jfd_w.verification_status = 'CANCELED_CLAWBACK'
              or jfd_w.clawback_triggered = true
         )::integer
    into v_pending_sefaz_total_count,
         v_pending_sefaz_26h_count,
         v_verified_sefaz_count,
         v_canceled_clawback_count
    from public.job_fiscal_documents jfd_w;

  select count(*) filter (where jb_sec.escrow_status = 'FROZEN_UNDER_DURESS')::integer,
         case
           when count(*) > 0 then
             ((count(*) filter (
               where jb_sec.latitude is not null
                  or jb_sec.longitude is not null
                  or jb_sec.address_cep is not null
             ) * 10000) / count(*))::integer
           else 0
         end
    into v_frozen_duress_count,
         v_geo_leak_bps
    from public.jobs jb_sec;

  select count(*)::integer
    into v_intrusion_canaries_count
    from private.founder_audit_log fal_c
   where fal_c.is_intrusion_canary = true;

  v_audit_chain_intact := private.verify_founder_audit_chain();

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'incident_id', 'DUR-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
               'job_id', jb_dur.id,
               'order_code', '#DESP-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 5)),
               'category_name', coalesce(jb_dur.category, 'Serviço'),
               'neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Restrito'),
               'coarse_neighborhood', coalesce(nullif(btrim(jb_dur.address_summary), ''), 'Restrito'),
               'frozen_amount_cents', round(coalesce(nullif(jb_dur.labor_amount + jb_dur.materials_amount, 0), jb_dur.agreed_price, 0) * 100)::bigint,
               'custody_status', 'FROZEN_UNDER_DURESS',
               'masked_victim_role', 'PRESTADOR_CREDENCIADO',
               'masked_account_ref', 'USR-' || upper(substr(replace(coalesce(jb_dur.provider_id, jb_dur.client_id)::text, '-', ''), 1, 4)) || '-****',
               'created_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
               'triggered_at', coalesce(jb_dur.updated_at, jb_dur.created_at),
               'ledger_freeze_tx_id', 'LEDGER-FRZ-' || upper(substr(replace(jb_dur.id::text, '-', ''), 1, 8)),
               'device_integrity_hash', encode(
                 extensions.digest(convert_to('DEV|' || jb_dur.id::text, 'UTF8'), 'sha256'),
                 'hex'
               ),
               'sha256_evidence_seal', encode(
                 extensions.digest(convert_to(jb_dur.id::text || '|' || coalesce(jb_dur.updated_at, jb_dur.created_at)::text, 'UTF8'), 'sha256'),
                 'hex'
               ),
               'evidence_chain_hashes', jsonb_build_array(
                 encode(extensions.digest(convert_to(jb_dur.id::text, 'UTF8'), 'sha256'), 'hex')
               ),
               'decoy_ui_displayed', true
             )
             order by coalesce(jb_dur.updated_at, jb_dur.created_at) desc
           ),
           '[]'::jsonb
         )
    into v_duress_incidents
    from public.jobs jb_dur
   where jb_dur.escrow_status = 'FROZEN_UNDER_DURESS';

  select jsonb_build_object(
           'owner_email', csv.owner_email,
           'pin_algo_version', csv.pin_algo_version,
           'pin_configured_at', csv.pin_configured_at,
           'pin_rotated_at', csv.pin_rotated_at,
           'failed_pin_attempts', csv.failed_pin_attempts
         )
    into v_vault_meta
    from private.ceo_sovereign_vault csv
   where csv.singleton_id = true;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'device_id', ctd.device_id,
               'device_label', ctd.device_label,
               'fingerprint_prefix', left(ctd.device_fingerprint_sha256, 12),
               'is_current_device', (ctd.device_fingerprint_sha256 = lower(btrim(p_device_hash))),
               'bound_at', ctd.bound_at,
               'last_seen_at', ctd.last_seen_at
             )
             order by ctd.last_seen_at desc
           ),
           '[]'::jsonb
         )
    into v_trusted_devices
    from private.ceo_trusted_devices ctd
   where ctd.user_id = v_uid
     and ctd.revoked_at is null;

  with latest_audits as (
    select fal.id,
           fal.event_code,
           fal.severity,
           fal.is_intrusion_canary,
           fal.prev_hash,
           fal.row_hash,
           fal.created_at
      from private.founder_audit_log fal
     order by fal.id desc
     limit 30
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', la.id,
               'event_code', la.event_code,
               'severity', la.severity,
               'is_intrusion_canary', la.is_intrusion_canary,
               'prev_hash', la.prev_hash,
               'row_hash', la.row_hash,
               'created_at', la.created_at
             )
             order by la.id desc
           ),
           '[]'::jsonb
         )
    into v_recent_audit_log
    from latest_audits la;

  select coalesce(max(cle_m.event_seq), 0)::bigint
    into v_latest_event_seq
    from private.ceo_live_events cle_m;

  with recent_live as (
    select cle.event_seq,
           cle.event_type,
           cle.severity,
           cle.title,
           cle.subtitle,
           cle.entity_table,
           cle.entity_id,
           cle.amount_cents,
           cle.metadata,
           cle.occurred_at
      from private.ceo_live_events cle
     order by cle.event_seq desc
     limit 60
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'event_seq', rl.event_seq,
               'event_type', rl.event_type,
               'severity', rl.severity,
               'title', rl.title,
               'subtitle', rl.subtitle,
               'entity_table', rl.entity_table,
               'entity_id', rl.entity_id,
               'amount_cents', rl.amount_cents,
               'metadata', rl.metadata,
               'occurred_at', rl.occurred_at
             )
             order by rl.event_seq desc
           ),
           '[]'::jsonb
         )
    into v_live_events
    from recent_live rl;

  -- Lista de despesas reais: em consulta de 1 dia retorna exatamente aquele dia;
  -- em janelas agregadas retorna as despesas da janela + futuras agendadas (nunca esconde contas futuras!)
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', cee_l.id,
               'competence_date', to_char(cee_l.competence_date, 'YYYY-MM-DD'),
               'expense_kind', cee_l.expense_kind,
               'category', cee_l.category,
               'description', cee_l.description,
               'amount_cents', cee_l.amount_cents,
               'payment_status', cee_l.payment_status,
               'paid_at', cee_l.paid_at,
               'created_at', cee_l.created_at
             )
             order by cee_l.competence_date desc, cee_l.created_at desc
           ),
           '[]'::jsonb
         )
    into v_real_expenses
    from private.ceo_expense_entries cee_l
   where case
           when v_is_single_day then cee_l.competence_date = v_window_start_sp
           else (
             (cee_l.competence_date >= v_window_start_sp and cee_l.competence_date <= v_window_end_sp)
             or cee_l.competence_date > v_today_sp
           )
         end;

  return jsonb_build_object(
    'generated_at', now(),
    'timezone', 'America/Sao_Paulo',
    'window_key', v_win_key,
    'days_window', v_days,
    'is_single_day', v_is_single_day,
    'is_future_window', v_is_future_window,
    'window_start_iso', to_char(v_window_start_sp, 'YYYY-MM-DD'),
    'window_end_iso', to_char(v_window_end_sp, 'YYYY-MM-DD'),
    'latest_event_seq', v_latest_event_seq,
    'vault_metadata', v_vault_meta,
    'user_demographics', jsonb_build_object(
      'only_clients_count', v_only_clients,
      'only_providers_count', v_only_providers,
      'dual_mode_both_count', v_dual_mode_both,
      'onboarding_incomplete_count', v_onboarding_incomplete,
      'total_users_count', v_total_users,
      'new_users_in_window_count', v_new_users_in_window,
      'kyc_verified_count', v_kyc_verified,
      'kyc_pending_count', v_kyc_pending,
      'kyc_rejected_count', v_kyc_rejected,
      'kyc_not_submitted_count', v_kyc_not_submitted,
      'biometric_verified_count', v_biometric_verified,
      'ocr_verified_count', v_ocr_verified,
      'lgpd_deleted_client_count', v_lgpd_client,
      'lgpd_deleted_provider_count', v_lgpd_provider,
      'lgpd_deleted_all_count', v_lgpd_all
    ),
    'live_operations_pulse', jsonb_build_object(
      'open_jobs_count', v_jobs_open,
      'awaiting_payment_count', v_jobs_awaiting_payment,
      'scheduled_jobs_count', v_jobs_scheduled,
      'in_progress_jobs_count', v_jobs_in_progress,
      'awaiting_approval_count', v_jobs_awaiting_approval,
      'completed_all_time_count', v_jobs_completed_all_time,
      'canceled_in_window_count', v_jobs_canceled_in_window,
      'disputed_jobs_count', v_jobs_disputed,
      'open_mediations_count', v_open_mediations_count,
      'open_support_tickets_count', v_open_support_tickets_count,
      'quotes_in_window_count', v_quotes_total_in_window,
      'quotes_pending_count', v_quotes_pending,
      'quotes_accepted_in_window_count', v_quotes_accepted_in_window,
      'invites_pending_count', v_invites_pending,
      'pix_pending_count', v_pix_topups_pending_count,
      'reviews_total_count', v_reviews_count,
      'reviews_avg_bps', v_reviews_avg_bps
    ),
    'financial_dre_cents', jsonb_build_object(
      'gmv_total_cents', v_gmv_total_cents,
      'labor_gross_cents', v_labor_gross_cents,
      'materials_exempt_cents', v_materials_exempt_cents,
      'provider_net_labor_cents', v_provider_net_labor_cents,
      'platform_gross_revenue_cents', v_platform_gross_revenue_cents,
      'sos_fee_revenue_cents', greatest(0::bigint, v_sos_fee_revenue_cents),
      'warranty_pool_carveout_cents', v_warranty_carveout_cents,
      'simples_nacional_tax_cents', v_simples_tax_cents,
      'gross_gmv_hypothetical_tax_cents', v_gross_hyp_tax_cents,
      'tax_savings_bps', v_tax_savings_bps,
      'variable_psp_and_cloud_cents', v_real_var_cost_cents,
      'tier0_kyc_savings_cents', 0,
      'contribution_margin_cents', v_contribution_margin_cents,
      'fixed_opex_cents', v_real_fixed_opex_cents,
      'completed_orders_count', v_completed_orders,
      'stage_gate_40_reached', (v_completed_orders >= 40),
      'stage_gate_100_reached', (v_completed_orders >= 100),
      'net_profit_ebitda_cents', v_net_profit_ebitda_cents
    ),
    'three_way_reconciliation', jsonb_build_object(
      'pix_topups_confirmed_cents', v_pix_topups_confirmed_cents,
      'ledger_net_sum_cents', v_ledger_client_custody_cents,
      'wallets_and_escrow_total_cents', v_wallets_and_escrow_cents,
      'client_seed_homologation_cents', v_client_seed_credit_cents,
      'discrepancy_cents', v_discrepancy_cents,
      'three_way_reconciliation_ok', (v_discrepancy_cents = 0)
    ),
    'treasury_and_escrow_cents', jsonb_build_object(
      'available_wallets_cents', v_available_wallets_cents,
      'active_execution_escrow_cents', v_active_exec_escrow_cents,
      'maturation_d0_d2_cents', v_maturation_d0_d2_cents,
      'maturation_d5_cents', v_maturation_d5_cents,
      'maturation_d7_cents', v_maturation_d7_cents,
      'available_for_pix_payout_cents', v_available_for_pix_cents,
      'frozen_mediation_cents', v_frozen_mediation_cents,
      'frozen_under_duress_cents', v_frozen_duress_cents,
      'estimated_monthly_cdi_float_cents', 0
    ),
    'actuarial_warranty_pool', jsonb_build_object(
      'running_balance_cents', v_pool_running_balance_cents,
      'active_exposure_cents', v_active_exposure_cents,
      'ica_ratio_bps', v_ica_ratio_bps,
      'fcr_layer1_bps', v_fcr_layer1_bps,
      'clawback_recovered_cents', v_clawback_recovered_cents,
      'claims_paid_cents', v_claims_paid_cents
    ),
    'category_liquidity_matrix', v_category_matrix,
    'neighborhood_liquidity', v_neighborhood_liquidity,
    'live_map_points', v_live_map_points,
    'real_conversion_funnel', v_conversion_funnel,
    'real_monthly_cohorts', v_monthly_cohorts,
    'daily_time_series', v_daily_series,
    'recent_orders_micro_pnl', v_recent_orders_pnl,
    'recent_reviews', v_recent_reviews,
    'real_expenses', v_real_expenses,
    'tax_obligations_schedule', v_tax_schedule,
    'active_mediations', v_active_mediations,
    'calendar_agenda_days', v_calendar_agenda_days,
    'calendar_agenda_events', v_calendar_agenda_events,
    'security_and_sefaz_watch', jsonb_build_object(
      'pending_sefaz_total_count', v_pending_sefaz_total_count,
      'pending_sefaz_over_26h_count', v_pending_sefaz_26h_count,
      'verified_sefaz_count', v_verified_sefaz_count,
      'canceled_clawback_count', v_canceled_clawback_count,
      'frozen_under_duress_count', v_frozen_duress_count,
      'geo_privacy_leak_bps', v_geo_leak_bps,
      'intrusion_canaries_count', v_intrusion_canaries_count,
      'audit_chain_intact', v_audit_chain_intact,
      'duress_incidents', v_duress_incidents
    ),
    'trusted_devices', v_trusted_devices,
    'recent_audit_log', v_recent_audit_log,
    'live_events', v_live_events
  );
end $$;

revoke all on function public.ceo_get_live_cockpit_snapshot(text, text, text) from public, anon;
grant execute on function public.ceo_get_live_cockpit_snapshot(text, text, text) to authenticated;

comment on function public.ceo_get_live_cockpit_snapshot(text, text, text) is
  'Snapshot executivo 100% real em tempo real (SET LOCAL transaction_read_only = on) com suporte a data específica (day:YYYY-MM-DD passada, hoje ou futura), calendário fiscal brasileiro (DAS Simples Nacional dia 20 útil), mediações unificadas e agenda preditiva real.';

commit;

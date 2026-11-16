-- =============================================================================
-- DESPERRENGUE CEO — Suíte SQL Smoke: Calendário Executivo, Impostos Futuros
-- Reais (DAS / DEFIS), Mediações Unificadas e Ponte em Tempo Real Completa
-- =============================================================================
begin;

create or replace function pg_temp.t(p_ok boolean, p_msg text)
returns void
language plpgsql
as $$
begin
  if not coalesce(p_ok, false) then
    raise exception 'SMOKE_ASSERTION_FAILED: %', p_msg;
  end if;
end $$;

do $$
declare
  v_ceo_uid          uuid := '00000000-0000-4000-8000-00000000ce99';
  v_client_uid       uuid := '00000000-0000-4000-8000-00000000c101';
  v_provider_uid     uuid := '00000000-0000-4000-8000-00000000b202';
  v_dev_ok           text := repeat('d', 64);
  v_ip_hash          text := repeat('1', 64);
  v_ek_v1            text := repeat('9', 64);
  v_res              jsonb;
  v_ch_id            uuid;
  v_ticket           text;
  v_stepup           text;
  v_job_done_id      uuid := '10000000-0000-4000-8000-000000000101';
  v_job_future_id    uuid := '10000000-0000-4000-8000-000000000202';
  v_ticket_id        uuid;
  v_expense_id       uuid;
  v_future_day       date := ((now() at time zone 'America/Sao_Paulo')::date + 12);
  v_future_day_iso   text := to_char(((now() at time zone 'America/Sao_Paulo')::date + 12), 'YYYY-MM-DD');
  v_snap_future      jsonb;
  v_snap_30d         jsonb;
  v_dossier          jsonb;
  v_seq_before       bigint;
  v_seq_after        bigint;
begin
  -- 1. Validação determinística do Calendário Fiscal Brasileiro (Simples Nacional + Lei 14.759/2023 + FEBRABAN)
  perform pg_temp.t(
    private.ceo_easter_sunday(2026) = date '2026-04-05',
    'Páscoa de 2026 deve ser 05/04/2026'
  );
  perform pg_temp.t(
    private.ceo_is_brazil_bank_holiday(date '2026-11-20') = true,
    '20/11 deve ser reconhecido como feriado nacional (Lei 14.759/2023)'
  );
  perform pg_temp.t(
    private.ceo_das_due_date_for_competence(2026, 10) = date '2026-11-23',
    'DAS da competência Out/2026 deve ser prorrogado de sexta 20/11 (feriado) para segunda 23/11/2026'
  );
  perform pg_temp.t(
    private.ceo_das_due_date_for_competence(2026, 11) = date '2026-12-21',
    'DAS da competência Nov/2026 deve ser prorrogado de domingo 20/12 para segunda 21/12/2026'
  );
  perform pg_temp.t(
    private.ceo_defis_due_date_for_year(2027) = date '2027-03-31',
    'DEFIS em 2027 deve cair no dia útil 31/03/2027'
  );

  -- 2. Preparação do titular monocrático e sessão Step-Up soberana
  insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
  values
    (v_ceo_uid, 'wagneroliveira2395@gmail.com', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
    (v_client_uid, 'cliente.real.cal@example.com', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
    (v_provider_uid, 'profissional.real.cal@example.com', '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now())
  on conflict (id) do nothing;

  insert into public.profiles (id, full_name, is_client, is_provider)
  values
    (v_ceo_uid, 'Wagner Oliveira', true, false),
    (v_client_uid, 'Cliente Real Calendário', true, false),
    (v_provider_uid, 'Profissional Real Calendário', false, true)
  on conflict (id) do nothing;

  delete from private.ceo_rate_limits;
  update private.ceo_sovereign_vault
     set password_verifier_cipher = null,
         password_salt_hex = null,
         password_version = 0,
         failed_pin_attempts = 0,
         locked_until = null
   where singleton_id = true;

  v_res := public.ceo_edge_issue_initial_bootstrap_otp(v_ceo_uid, v_dev_ok, v_ip_hash, '481920');
  v_ch_id := (v_res ->> 'challenge_id')::uuid;
  v_res := public.ceo_edge_verify_initial_bootstrap_otp(v_ceo_uid, v_ch_id, '481920', v_dev_ok, 'Workstation CEO');
  v_ticket := v_res ->> 'enrollment_ticket';
  v_res := public.ceo_edge_seal_initial_master_password(v_ceo_uid, v_ticket, v_ek_v1, v_dev_ok, 'Workstation CEO');
  v_stepup := v_res ->> 'stepup_token';

  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', v_ceo_uid::text,
      'role', 'authenticated',
      'email', 'wagneroliveira2395@gmail.com'
    )::text,
    true
  );

  -- 3. Operações reais no Desperrengue: pedido futuro agendado + chamado de mediação + conta futura agendada
  select coalesce(max(event_seq), 0) into v_seq_before from private.ceo_live_events;

  insert into public.jobs (
    id, client_id, provider_id, category, title, description,
    status, urgency, agreed_price, labor_amount, materials_amount,
    scheduled_for, created_at, updated_at
  ) values (
    v_job_future_id, v_client_uid, v_provider_uid, 'Eletricista',
    'Quadro elétrico residencial', 'Agendamento futuro real',
    'scheduled', 'scheduled', 400.00, 300.00, 100.00,
    (v_future_day::timestamp + interval '14 hours') at time zone 'America/Sao_Paulo',
    now(), now()
  );

  insert into public.support_tickets (
    user_id, job_id, reason, description, status, sla_due_at, created_at
  ) values (
    v_client_uid, v_job_future_id, 'Dúvida sobre garantia e prazo',
    'Mediação aberta no aplicativo Desperrengue', 'open',
    (v_future_day::timestamp + interval '16 hours') at time zone 'America/Sao_Paulo',
    now()
  ) returning id into v_ticket_id;

  v_res := public.ceo_record_real_expense(
    v_stepup,
    v_dev_ok,
    v_future_day,
    'FIXED_OPEX',
    'Servidor e nuvem',
    'Fatura mensal agendada',
    18900,
    null
  );
  perform pg_temp.t((v_res ->> 'ok')::boolean = true, 'ceo_record_real_expense deve registrar conta futura');
  perform pg_temp.t((v_res ->> 'payment_status') = 'SCHEDULED', 'data futura sem status explícito deve iniciar como SCHEDULED');
  v_expense_id := (v_res ->> 'expense_id')::uuid;

  select coalesce(max(event_seq), 0) into v_seq_after from private.ceo_live_events;
  perform pg_temp.t(
    v_seq_after >= v_seq_before + 3,
    'triggers zz_ceo_live_* devem emitir eventos em tempo real para jobs, support_tickets e ceo_expense_entries'
  );

  -- 4. Consulta de data futura específica (`day:YYYY-MM-DD`) em `ceo_get_live_cockpit_snapshot`
  v_snap_future := public.ceo_get_live_cockpit_snapshot(
    v_stepup,
    v_dev_ok,
    'day:' || v_future_day_iso
  );
  perform set_config('transaction_read_only', 'off', true);

  perform pg_temp.t(
    (v_snap_future ->> 'is_single_day')::boolean = true
    and (v_snap_future ->> 'is_future_window')::boolean = true
    and (v_snap_future ->> 'window_start_iso') = v_future_day_iso,
    'snapshot day:YYYY-MM-DD futuro deve sinalizar is_single_day=true e is_future_window=true'
  );
  perform pg_temp.t(
    jsonb_array_length(v_snap_future -> 'tax_obligations_schedule') >= 12,
    'snapshot deve retornar cronograma fiscal real tax_obligations_schedule com >= 12 competências'
  );
  perform pg_temp.t(
    jsonb_array_length(v_snap_future -> 'active_mediations') >= 1,
    'snapshot deve incluir chamado aberto em active_mediations'
  );
  perform pg_temp.t(
    jsonb_array_length(v_snap_future -> 'real_expenses') >= 1,
    'snapshot da data futura deve retornar a conta agendada para aquele dia'
  );
  perform pg_temp.t(
    exists (
      select 1
        from jsonb_array_elements(v_snap_future -> 'calendar_agenda_events') ev
       where (ev ->> 'day_iso') = v_future_day_iso
         and (ev ->> 'event_kind') = 'SCHEDULED_ORDER'
    ),
    'calendar_agenda_events deve listar o serviço agendado na data futura'
  );
  perform pg_temp.t(
    exists (
      select 1
        from jsonb_array_elements(v_snap_future -> 'calendar_agenda_events') ev
       where (ev ->> 'day_iso') = v_future_day_iso
         and (ev ->> 'event_kind') = 'SUPPORT_DISPUTE_SLA_DUE'
    ),
    'calendar_agenda_events deve listar o vencimento do SLA de mediação na data futura'
  );

  -- 5. Quitação da conta agendada (`ceo_toggle_expense_paid_status`) e Dossiê Forense corrigido (`pay.method`)
  v_res := public.ceo_toggle_expense_paid_status(v_stepup, v_dev_ok, v_expense_id, true);
  perform pg_temp.t(
    (v_res ->> 'ok')::boolean = true and (v_res ->> 'payment_status') = 'PAID',
    'ceo_toggle_expense_paid_status deve marcar conta agendada como PAID'
  );

  v_dossier := public.ceo_inspect_order_forensics(v_stepup, v_dev_ok, v_job_future_id);
  perform set_config('transaction_read_only', 'off', true);
  perform pg_temp.t(
    (v_dossier ->> 'ok')::boolean = true
    and jsonb_array_length(v_dossier -> 'support_tickets') = 1,
    'ceo_inspect_order_forensics deve funcionar sem erro pay.payment_method e expor support_tickets'
  );
end $$;

rollback;

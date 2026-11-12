-- =============================================================================
-- DESPERRENGUE — Suíte SQL Zero-Trust: Temporal & Spatial Geo-Privacy Lock
--                + Auditoria de Endurecimento Criptográfico (20261113100000 / 110000)
--
-- Executa integralmente dentro de UMA transação abortada no final (ROLLBACK):
-- nada é persistido no banco. O relatório completo sai na mensagem da exceção.
--
-- Requer >= 6 contas existentes em `public.profiles` (ajustadas apenas na transação):
--   c     = cliente titular do pedido
--   c2    = outro cliente (não-parte)
--   p1    = profissional ativo (Elétrica) que vence o orçamento
--   p2    = profissional ativo (Elétrica) concorrente que perde o orçamento
--   p_out = profissional ativo de outra categoria (Pintura) / alheio
--   adm   = administrador de auditoria (`role = 'admin'`)
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
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function pg_temp.try(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;

do $$
declare
  ids      uuid[];
  c        uuid;
  c2       uuid;
  p1       uuid;
  p2       uuid;
  p_out    uuid;
  adm      uuid;
  j        uuid;
  j_emg    uuid;
  j_nodate uuid;
  q1       uuid;
  q2       uuid;
  lat0     constant double precision := -21.787812;
  lng0     constant double precision := -46.561423;
  v_loc    jsonb;
  v_loc2   jsonb;
  v_dest   jsonb;
  v_dos    jsonb;
  v_hist   jsonb;
  v_dist   double precision;
  v_rad    integer;
  v_pin    text;
  v_err    text;
  v_cnt    integer;
  v_report text;
  r_job    public.jobs%rowtype;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 6 then
    raise exception 'TESTE ABORTADO: são necessários >= 6 perfis em public.profiles (encontrados: %).',
      coalesce(array_length(ids, 1), 0);
  end if;

  c := ids[1]; c2 := ids[2]; p1 := ids[3]; p2 := ids[4]; p_out := ids[5]; adm := ids[6];

  -- ---------------------------------------------------------------------------
  -- Preparação isolada na transação
  -- ---------------------------------------------------------------------------
  update public.profiles
     set role = null,
         is_client = false,
         is_provider = false,
         client_setup_done = false,
         provider_setup_done = false,
         verification_status = 'NOT_SUBMITTED',
         address_city = 'Poços de Caldas - MG';

  update public.profiles
     set is_client = true, client_setup_done = true, full_name = 'Helena Titular'
   where id in (c, c2);

  update public.profiles
     set is_provider = true,
         verification_status = 'ACTIVE',
         provider_setup_done = true,
         latitude = lat0 + 0.01,
         longitude = lng0 + 0.01
   where id in (p1, p2, p_out);

  update public.profiles set role = 'admin', is_client = true, client_setup_done = true where id = adm;

  delete from public.provider_profiles where user_id in (p1, p2, p_out);
  insert into public.provider_profiles (user_id, specialties, visit_fee, service_radius_km, accepting_jobs)
  values
    (p1, array['Elétrica'], 40, 25, true),
    (p2, array['Elétrica'], 45, 25, true),
    (p_out, array['Jardinagem'], 35, 25, true);

  insert into public.app_settings (key, value)
  values ('checkin_sandbox', 'true')
  on conflict (key) do update set value = 'true';

  -- ---------------------------------------------------------------------------
  -- 1. CRIAÇÃO DO JOB + SANITIZAÇÃO DE `public.jobs` (ZERO LEAK NA TABELA / REALTIME)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  insert into public.jobs (
    client_id, title, description, category, urgency, visibility,
    scheduled_for, latitude, longitude, address_cep, address_summary
  ) values (
    c,
    'Quadro elétrico bifásico',
    'Substituição de DR e disjuntores',
    'Elétrica',
    'scheduled',
    'open',
    ((now() at time zone 'America/Sao_Paulo')::date + 3)::timestamp at time zone 'America/Sao_Paulo' + interval '14 hours',
    lat0,
    lng0,
    '37701-000',
    'Rua Assis Figueiredo, 1245 - Apto 402 - Centro - Poços de Caldas - MG 37701-000'
  ) returning id into j;

  insert into public.job_addresses (job_id, address_line, complement, reference)
  values (j, 'Rua Assis Figueiredo, 1245 - Centro, Poços de Caldas - MG', 'Apto 402', 'Próximo ao Palace Hotel');
  reset role;

  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    r_job.latitude is null and r_job.longitude is null and r_job.address_cep is null,
    '01 public.jobs mantém latitude, longitude e address_cep estritamente NULL (zero leak em SELECT * / Realtime)'
  );
  perform pg_temp.t(
    r_job.public_lat is not null and r_job.public_lng is not null and r_job.fuzzy_radius_m between 500 and 800,
    '02 public.jobs preenche public_lat, public_lng e fuzzy_radius_m [500..800]'
  );
  perform pg_temp.t(
    r_job.address_summary = 'Centro, Poços de Caldas - MG'
    and position('Assis' in coalesce(r_job.address_summary, '')) = 0
    and position('1245' in coalesce(r_job.address_summary, '')) = 0
    and position('402' in coalesce(r_job.address_summary, '')) = 0
    and position('37701' in coalesce(r_job.address_summary, '')) = 0,
    '03 address_summary sanitizado remove rua, número, complemento e CEP (' || coalesce(r_job.address_summary, 'null') || ')'
  );
  perform pg_temp.t(
    exists (
      select 1 from public.job_geo g
       where g.job_id = j and abs(g.lat - lat0) < 1e-6 and abs(g.lng - lng0) < 1e-6
    ),
    '04 coordenada exata migrada automaticamente para public.job_geo server-side'
  );
  perform pg_temp.t(
    exists (select 1 from public.job_addresses ja where ja.job_id = j and ja.cep = '37701-000'),
    '05 CEP migrado automaticamente para public.job_addresses.cep'
  );
  perform pg_temp.t(
    exists (
      select 1 from public.notifications n
       where n.user_id = p1
         and n.job_id = j
         and n.kind = 'new_area_job'
         and position('Assis' in coalesce(n.body, '')) = 0
         and position('1245' in coalesce(n.body, '')) = 0
    ),
    '06 jobs_notify_area_providers usa job_geo server-side e não inclui rua/número na notificação'
  );

  -- ---------------------------------------------------------------------------
  -- 2. OWNER (`owner_full`) & ADMIN (`viewer_role = 'admin'`, `phase = 'owner_full'`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  v_loc := public.get_job_location_for_viewer(j);
  perform pg_temp.t(
    v_loc ->> 'viewer_role' = 'owner'
    and v_loc ->> 'phase' = 'owner_full'
    and (v_loc ->> 'exact_unlocked')::boolean = true
    and v_loc ->> 'street' = 'Rua Assis Figueiredo'
    and v_loc ->> 'number' = '1245'
    and v_loc ->> 'complement' = 'Apto 402'
    and v_loc ->> 'reference' = 'Próximo ao Palace Hotel'
    and v_loc ->> 'cep' = '37701-000'
    and v_loc ->> 'neighborhood' = 'Centro'
    and v_loc ->> 'city' = 'Poços de Caldas'
    and v_loc ->> 'uf' = 'MG'
    and abs((v_loc ->> 'lat')::double precision - lat0) < 1e-6
    and abs((v_loc ->> 'lng')::double precision - lng0) < 1e-6
    and (v_loc ->> 'radius_m')::integer = 100,
    '07 owner recebe owner_full com rua, número, compl., ref., CEP e coordenadas exatas'
  );
  select count(*) into v_cnt from public.job_addresses where job_id = j;
  perform pg_temp.t(v_cnt = 1, '08 owner lê job_addresses via RLS em pedido aberto');
  select count(*) into v_cnt from public.job_geo where job_id = j;
  perform pg_temp.t(v_cnt = 1, '09 owner lê job_geo via RLS em pedido aberto');
  reset role;

  perform pg_temp.login(adm);
  v_loc := public.get_job_location_for_viewer(j);
  perform pg_temp.t(
    v_loc ->> 'viewer_role' = 'admin'
    and v_loc ->> 'phase' = 'owner_full'
    and (v_loc ->> 'exact_unlocked')::boolean = true
    and v_loc ->> 'street' = 'Rua Assis Figueiredo',
    '10 admin recebe viewer_role=admin, phase=owner_full e exact_unlocked=true'
  );
  reset role;

  -- ---------------------------------------------------------------------------
  -- 3. PROVIDER EM JOB `open` (`open_quoting`) + INVARIANTES GEOMÉTRICAS DO CÍRCULO FUZZY
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(p1);
  v_loc  := public.get_job_location_for_viewer(j);
  v_loc2 := public.get_job_location_for_viewer(j);
  v_dist := public.haversine_m(lat0, lng0, (v_loc ->> 'lat')::double precision, (v_loc ->> 'lng')::double precision);
  v_rad  := (v_loc ->> 'radius_m')::integer;

  perform pg_temp.t(
    v_loc ->> 'viewer_role' = 'provider'
    and v_loc ->> 'phase' = 'open_quoting'
    and (v_loc ->> 'exact_unlocked')::boolean = false
    and v_loc ->> 'city' = 'Poços de Caldas'
    and v_loc ->> 'uf' = 'MG'
    and v_loc ->> 'neighborhood' = 'Centro'
    and (v_loc ->> 'street') is null
    and (v_loc ->> 'number') is null
    and (v_loc ->> 'complement') is null
    and (v_loc ->> 'reference') is null
    and (v_loc ->> 'cep') is null,
    '11 provider em open_quoting vê apenas Bairro/Cidade/UF e todos os campos exatos NULL'
  );
  perform pg_temp.t(
    v_dist >= 150.0 and v_dist <= 350.0 and v_rad between 500 and 800 and v_dist <= (v_rad - 150),
    '12 deslocamento HMAC em [150..350]m (' || round(v_dist::numeric, 1) || 'm), raio ' || v_rad || 'm, imóvel >=150m dentro do círculo'
  );
  perform pg_temp.t(
    v_loc = v_loc2
    and (v_loc ->> 'lat')::double precision = r_job.public_lat
    and (v_loc ->> 'lng')::double precision = r_job.public_lng
    and v_rad = r_job.fuzzy_radius_m,
    '13 centro fuzzy é determinístico por job e idêntico a jobs.public_lat/public_lng/fuzzy_radius_m'
  );

  select count(*) into v_cnt from public.job_addresses where job_id = j;
  perform pg_temp.t(v_cnt = 0, '14 RLS bloqueia job_addresses para provider em open_quoting (0 linhas)');
  select count(*) into v_cnt from public.job_geo where job_id = j;
  perform pg_temp.t(v_cnt = 0, '15 RLS bloqueia job_geo para provider em open_quoting (0 linhas)');

  v_dest := public.job_destination(j);
  perform pg_temp.t(
    v_dest ->> 'source' = 'fuzzy_hmac'
    and v_dest ->> 'precision' = 'approximate'
    and (v_dest ->> 'exact_unlocked')::boolean = false
    and (v_dest ->> 'lat')::double precision = (v_loc ->> 'lat')::double precision,
    '16 job_destination devolve apenas centro fuzzy_hmac quando travado'
  );

  insert into public.quotes (job_id, provider_id, price, message)
  values (j, p1, 220, 'Orçamento completo') returning id into q1;
  reset role;

  perform pg_temp.login(p2);
  insert into public.quotes (job_id, provider_id, price, message)
  values (j, p2, 260, ' Segunda proposta') returning id into q2;
  reset role;

  -- ---------------------------------------------------------------------------
  -- 4. PROVIDER ALHEIO / OUTRO CLIENTE (`denied`) + ZERO-ORACLE
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(p_out);
  v_loc := public.get_job_location_for_viewer(j);
  perform pg_temp.t(
    v_loc ->> 'viewer_role' = 'none'
    and v_loc ->> 'phase' = 'denied'
    and (v_loc ->> 'exact_unlocked')::boolean = false
    and v_loc ->> 'city' = ''
    and (v_loc ->> 'lat') is null
    and (v_loc ->> 'lng') is null
    and (v_loc ->> 'radius_m')::integer = 0,
    '17 profissional de outra categoria recebe phase=denied sem coordenadas nem bairro'
  );
  perform pg_temp.t(
    public._can_see_exact_location(j, c) = false,
    '18 Zero-Oracle: _can_see_exact_location(job, owner_uid) retorna FALSE quando chamado por terceiro'
  );
  reset role;

  perform pg_temp.login(c2);
  v_loc := public.get_job_location_for_viewer(j);
  perform pg_temp.t(v_loc ->> 'phase' = 'denied', '19 outro cliente recebe phase=denied');
  reset role;

  -- ---------------------------------------------------------------------------
  -- 5. ACEITE (`awaiting_payment`) + AGENDADO FUTURO (`confirmed_future`) + FRONTEIRA 00:00 SP
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  perform public.accept_quote(q1);
  reset role;

  -- Mesmo que a data fosse hoje, `awaiting_payment` NUNCA desbloqueia!
  update public.jobs set scheduled_for = now() where id = j;
  perform pg_temp.login(p1);
  v_loc := public.get_job_location_for_viewer(j);
  perform pg_temp.t(
    v_loc ->> 'phase' = 'confirmed_future' and (v_loc ->> 'exact_unlocked')::boolean = false,
    '20 awaiting_payment NUNCA desbloqueia endereço exato nem na data do serviço'
  );
  reset role;

  -- Restaura data futura (+3 dias em SP) e confirma pagamento em custódia (`scheduled`)
  update public.jobs
     set scheduled_for = timestamptz '2026-11-20 14:00:00-03'
   where id = j;

  perform pg_temp.login(c);
  perform public.pay_job_mock(j, 'pix');
  -- Tentativa de enviar localização exata via chat antes do dia do serviço deve ser bloqueada
  v_err := pg_temp.try(format(
    'insert into public.messages (job_id, provider_id, sender_id, kind, body, meta) values (%L, %L, %L, %L, %L, %L::jsonb)',
    j, p1, c, 'location', 'Minha casa', json_build_object('lat', lat0, 'lng', lng0)::text
  ));
  perform pg_temp.t(
    position('LOCATION_LOCKED_UNTIL_SERVICE_DAY' in v_err) > 0,
    '21 _messages_guard bloqueia envio de kind=location no chat antes do dia agendado'
  );
  reset role;

  perform pg_temp.login(p1);
  v_loc := public.get_job_location_for_viewer(j);
  v_dos := public.provider_job_dossier(j);
  select count(*) into v_cnt from public.job_addresses where job_id = j;

  perform pg_temp.t(
    v_loc ->> 'phase' = 'confirmed_future'
    and (v_loc ->> 'exact_unlocked')::boolean = false
    and (v_loc ->> 'street') is null
    and v_loc ->> 'scheduled_date' = '2026-11-20'
    and v_loc ->> 'unlock_at' = '2026-11-20T03:00:00Z'
    and v_cnt = 0,
    '22 provider confirmado futuro (confirmed_future): rua NULL, 0 linhas em job_addresses e unlock_at=03:00:00Z (00:00 SP)'
  );
  perform pg_temp.t(
    (v_dos ->> 'exact_unlocked')::boolean = false
    and (v_dos ->> 'address_line') is null
    and (v_dos ->> 'complement') is null
    and (v_dos ->> 'reference') is null
    and v_dos ->> 'address_summary' = 'Centro, Poços de Caldas - MG',
    '23 provider_job_dossier mascara address_line/complement/reference antes do dia agendado'
  );
  reset role;

  -- Verificação exata de virada da meia-noite em America/Sao_Paulo (UTC-3 fixo)
  perform pg_temp.t(
    public._job_privacy_phase(j, p1, timestamptz '2026-11-20 02:59:59+00') = 'confirmed_future'
    and public._job_privacy_phase(j, p1, timestamptz '2026-11-20 03:00:00+00') = 'service_day',
    '24 fronteira exata 00:00 America/Sao_Paulo: 02:59:59Z -> confirmed_future | 03:00:00Z -> service_day'
  );

  -- Job `scheduled` sem `scheduled_for`: fail-closed para comum, `service_day` apenas para `emergency`
  insert into public.jobs (
    client_id, provider_id, title, description, category, urgency, status, payment_status, agreed_price
  ) values (
    c, p1, 'Sem data agendada', 'Teste fail-closed', 'Elétrica', 'scheduled', 'scheduled', 'escrow', 100
  ) returning id into j_nodate;

  insert into public.jobs (
    client_id, provider_id, title, description, category, urgency, status, payment_status, agreed_price
  ) values (
    c, p1, 'SOS imediato', 'Teste emergência', 'Elétrica', 'emergency', 'scheduled', 'escrow', 180
  ) returning id into j_emg;

  perform pg_temp.t(
    public._job_privacy_phase(j_nodate, p1, now()) = 'confirmed_future'
    and public._job_privacy_phase(j_emg, p1, now()) = 'service_day',
    '25 scheduled_for IS NULL: comum fica confirmed_future (fail-closed) e emergency libera service_day'
  );

  -- ---------------------------------------------------------------------------
  -- 6. DIA DO SERVIÇO (`service_day`) + NOTIFICAÇÃO 00:00 SP + GEOFENCE `start_job`
  -- ---------------------------------------------------------------------------
  update public.jobs
     set scheduled_for = now() + interval '10 minutes'
   where id = j;

  v_cnt := public.notify_service_day_address_unlocked(now());
  perform pg_temp.t(
    v_cnt >= 1
    and public.notify_service_day_address_unlocked(now()) = 0
    and exists (
      select 1 from public.notifications n
       where n.user_id = p1
         and n.job_id = j
         and n.kind = 'address_unlocked_today'
         and position('Assis' in coalesce(n.body, '')) = 0
         and position('1245' in coalesce(n.body, '')) = 0
    ),
    '26 notify_service_day_address_unlocked é idempotente e sem endereço no texto'
  );

  -- Concorrente que perdeu o orçamento (`p2`) continua travado mesmo no dia do serviço!
  perform pg_temp.login(p2);
  v_loc := public.get_job_location_for_viewer(j);
  select count(*) into v_cnt from public.job_addresses where job_id = j;
  perform pg_temp.t(
    v_loc ->> 'phase' = 'open_quoting'
    and (v_loc ->> 'exact_unlocked')::boolean = false
    and v_cnt = 0,
    '27 concorrente não selecionado (p2) jamais desbloqueia endereço no dia do serviço'
  );
  reset role;

  -- Profissional contratado (`p1`) no dia do serviço: desbloqueio integral + check-in GPS
  perform pg_temp.login(p1);
  v_loc  := public.get_job_location_for_viewer(j);
  v_dos  := public.provider_job_dossier(j);
  v_dest := public.job_destination(j);
  select count(*) into v_cnt from public.job_addresses where job_id = j;

  perform pg_temp.t(
    v_loc ->> 'phase' = 'service_day'
    and (v_loc ->> 'exact_unlocked')::boolean = true
    and v_loc ->> 'street' = 'Rua Assis Figueiredo'
    and v_loc ->> 'number' = '1245'
    and v_loc ->> 'complement' = 'Apto 402'
    and v_loc ->> 'reference' = 'Próximo ao Palace Hotel'
    and v_loc ->> 'cep' = '37701-000'
    and abs((v_loc ->> 'lat')::double precision - lat0) < 1e-6
    and abs((v_loc ->> 'lng')::double precision - lng0) < 1e-6
    and (v_loc ->> 'radius_m')::integer = 100
    and v_cnt = 1,
    '28 provider contratado em service_day desbloqueia endereço completo, CEP, lat/lng exatos e RLS (1 linha)'
  );
  perform pg_temp.t(
    (v_dos ->> 'exact_unlocked')::boolean = true
    and position('Rua Assis Figueiredo' in coalesce(v_dos ->> 'address_line', '')) > 0
    and (v_dest ->> 'exact_unlocked')::boolean = true
    and abs((v_dest ->> 'lat')::double precision - lat0) < 1e-6,
    '29 provider_job_dossier e job_destination liberam endereço e coordenada exatos em service_day'
  );

  -- Geofence de `start_job` (< 100 m do `job_geo` exato, sem depender de `jobs.latitude`)
  perform public.start_job(j, lat0 + 0.0003, lng0, 8, false);
  reset role;

  -- Cliente envia localização no chat durante `in_progress` (permitido) para testar expurgo pós-serviço
  perform pg_temp.login(c);
  insert into public.messages (job_id, provider_id, sender_id, kind, body, meta)
  values (j, p1, c, 'location', 'Portão lateral', jsonb_build_object('lat', lat0, 'lng', lng0));
  select pin into v_pin from public.job_secrets where job_id = j;
  reset role;

  -- ---------------------------------------------------------------------------
  -- 7. RE-BLOQUEIO PÓS-SERVIÇO LGPD (`completed` / `canceled` / `disputed` -> `closed`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(p1);
  insert into public.job_evidence (job_id, provider_id, slot, path)
  values (j, p1, 'overview', p1::text || '/done.jpg');
  perform public.complete_job_with_pin(j, v_pin);

  v_loc  := public.get_job_location_for_viewer(j);
  v_dos  := public.provider_job_dossier(j);
  v_dest := public.job_destination(j);
  v_hist := public.provider_full_service_history();
  select count(*) into v_cnt from public.job_addresses where job_id = j;

  perform pg_temp.t(
    v_loc ->> 'phase' = 'closed'
    and (v_loc ->> 'exact_unlocked')::boolean = false
    and (v_loc ->> 'lat') is null
    and (v_loc ->> 'lng') is null
    and (v_loc ->> 'street') is null
    and (v_loc ->> 'number') is null
    and (v_loc ->> 'complement') is null
    and (v_loc ->> 'reference') is null
    and (v_loc ->> 'cep') is null
    and v_loc ->> 'neighborhood' = 'Centro'
    and v_loc ->> 'city' = 'Poços de Caldas'
    and v_loc ->> 'uf' = 'MG',
    '30 pós-conclusão (closed): lat/lng/rua/nº/CEP voltam a NULL; restam apenas Bairro e Cidade/UF'
  );
  perform pg_temp.t(
    v_cnt = 0
    and v_dest is null
    and (v_dos ->> 'exact_unlocked')::boolean = false
    and (v_dos ->> 'address_line') is null
    and position('Assis' in coalesce(v_hist::text, '')) = 0
    and position('1245' in coalesce(v_hist::text, '')) = 0,
    '31 pós-conclusão: RLS=0 linhas, job_destination=NULL, dossiê e histórico sem logradouro/número'
  );
  reset role;

  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    r_job.public_lat is null and r_job.public_lng is null and r_job.fuzzy_radius_m is null,
    '32 pós-conclusão: jobs.public_lat, public_lng e fuzzy_radius_m são limpos para NULL'
  );
  perform pg_temp.t(
    not exists (
      select 1 from public.messages m
       where m.job_id = j and m.kind = 'location' and (m.meta ? 'lat' or m.meta ? 'lng')
    ),
    '33 pós-conclusão: coordenadas exatas de mensagens kind=location no chat foram expurgadas'
  );

  -- Owner continua vendo tudo exato mesmo após `completed`!
  perform pg_temp.login(c);
  v_loc := public.get_job_location_for_viewer(j);
  v_dos := public.client_job_dossier(j);
  perform pg_temp.t(
    v_loc ->> 'phase' = 'owner_full'
    and (v_loc ->> 'exact_unlocked')::boolean = true
    and abs((v_loc ->> 'lat')::double precision - lat0) < 1e-6
    and abs((v_dos ->> 'latitude')::double precision - lat0) < 1e-6,
    '34 owner mantém acesso integral (owner_full + client_job_dossier) após conclusão'
  );
  reset role;

  -- `canceled` e `disputed` também caem em `closed`
  update public.jobs set status = 'canceled' where id = j_nodate;
  update public.jobs set status = 'disputed' where id = j_emg;
  perform pg_temp.t(
    public._job_privacy_phase(j_nodate, p1, now()) = 'closed'
    and public._job_privacy_phase(j_emg, p1, now()) = 'closed',
    '35 jobs canceled e disputed também re-bloqueiam em phase=closed'
  );

  -- ---------------------------------------------------------------------------
  -- 8. ANON + AUDITORIA ZERO-TRUST (`20261113110000_security_hardening_audit.sql`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(p1);
  perform pg_temp.t(
    starts_with(pg_temp.try('select * from private.geo_privacy_secrets'), '42501')
    and starts_with(pg_temp.try('select * from private.job_forensic_secrets'), '42501'),
    '36 cofre private (geo_privacy_secrets e job_forensic_secrets) inacessível a authenticated (42501)'
  );
  perform pg_temp.t(
    starts_with(pg_temp.try(format('select public._geo_fuzzy_center(%L, -21.7, -46.5)', j)), '42501')
    and starts_with(pg_temp.try(format('select public._job_privacy_phase(%L, %L, now())', j, p1)), '42501'),
    '37 funções internas _geo_fuzzy_center e _job_privacy_phase inacessíveis via API (42501)'
  );
  perform pg_temp.t(
    starts_with(pg_temp.try(format('select public.settle_escrow_with_carveout_and_maturation(%L)', j)), '42501')
    and starts_with(pg_temp.try('select public.process_autonomous_escrow_and_mediation_queues()'), '42501'),
    '38 workers financeiros internos revogados de authenticated (42501)'
  );
  v_err := pg_temp.try(format(
    'select public.complete_job_and_schedule_escrow(%L, %L, 12345, 10, null)',
    j, p2
  ));
  perform pg_temp.t(
    starts_with(v_err, '42501:') and position('ERR_IDOR_BLOCKED' in v_err) > 0,
    '39 anti-IDOR bloqueia p_provider_id != auth.uid() em complete_job_and_schedule_escrow'
  );
  v_err := pg_temp.try(format('select public.issue_kyc_screen_flash_challenge(%L)', c));
  perform pg_temp.t(
    starts_with(v_err, '42501:') and position('ERR_IDOR_BLOCKED' in v_err) > 0,
    '40 anti-IDOR bloqueia p_user_id != auth.uid() em issue_kyc_screen_flash_challenge'
  );
  perform pg_temp.t(
    public._can_access_forensic_evidence('evidence/' || j::text || '/proof.jpg', true) = true
    and public._can_access_forensic_evidence('evidence/' || j::text || '/../evil.jpg', true) = false,
    '41 bucket forensic-evidence autoriza parte do job e bloqueia path traversal'
  );
  reset role;

  perform pg_temp.login(p_out);
  perform pg_temp.t(
    public._can_access_forensic_evidence('evidence/' || j::text || '/proof.jpg', false) = false,
    '42 bucket forensic-evidence bloqueia leitura por profissional terceiro'
  );
  reset role;

  perform pg_temp.t(
    exists (select 1 from storage.buckets where id = 'forensic-evidence' and public = false),
    '43 storage.buckets mantém forensic-evidence com public = false'
  );

  -- Isolamento de `checkout_pin_hash` e `job_presence_secret` em `private.job_forensic_secrets`
  update public.jobs
     set checkout_pin_hash = '$2a$06$testhashvalue000000000000000000000000000000000',
         job_presence_secret = 'top-secret-totp-seed'
   where id = j;
  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    r_job.checkout_pin_hash is null
    and r_job.job_presence_secret is null
    and exists (
      select 1 from private.job_forensic_secrets fs
       where fs.job_id = j
         and fs.checkout_pin_hash is not null
         and fs.job_presence_secret = 'top-secret-totp-seed'
    ),
    '44 segredos checkout_pin_hash e job_presence_secret ficam NULL em public.jobs e salvos em private.job_forensic_secrets'
  );

  -- Papel `anon`: zero acesso
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
  perform pg_temp.t(
    starts_with(pg_temp.try(format('select public.get_job_location_for_viewer(%L)', j)), '42501')
    and starts_with(pg_temp.try(format('select public._can_see_exact_location(%L)', j)), '42501')
    and starts_with(pg_temp.try('select 1 from public.job_addresses limit 1'), '42501')
    and starts_with(pg_temp.try('select 1 from public.job_geo limit 1'), '42501'),
    '45 anon recebe 42501 em get_job_location_for_viewer, _can_see_exact_location, job_addresses e job_geo'
  );
  reset role;

  -- ---------------------------------------------------------------------------
  -- Relatório consolidado
  -- ---------------------------------------------------------------------------
  select string_agg(
    (case when r2.ok then 'ok    ' else 'FAIL  ' end) || lpad(r2.n::text, 2, '0') || ' ' || r2.name,
    E'\n' order by r2.n
  ) into v_report
  from res r2;

  raise exception E'\n=== RELATÓRIO GEO-PRIVACY LOCK & ZERO-TRUST AUDIT ===\n%\n\nOK=%  FALHAS=%\n',
    v_report,
    (select count(*) from res r3 where r3.ok),
    (select count(*) from res r4 where not r4.ok);
end $$;

rollback;

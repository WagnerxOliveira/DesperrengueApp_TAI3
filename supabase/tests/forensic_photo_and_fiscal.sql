-- =============================================================================
-- DESPERRENGUE — Suíte SQL Zero-Trust: Registro Forense de Fotos (Check-in /
--                Check-out) & Endurecimento Fiscal / Smart Split (v2.11.1)
-- Migration alvo: 20261113130000_forensic_photo_and_fiscal_hardening.sql
--
-- Executa integralmente dentro de UMA transação abortada no final (ROLLBACK):
-- nada é persistido no banco. O relatório completo sai na mensagem da exceção.
--
-- Requer >= 4 contas em `public.profiles`:
--   c   = cliente titular
--   p1  = profissional ativo (Elétrica) alocado nos atendimentos
--   p2  = profissional ativo (Elétrica) concorrente / não alocado
--   adm = administrador de auditoria (`role = 'admin'`)
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

-- Gera chave NF-e/NFC-e de 44 dígitos com DV Módulo 11 matematicamente válido
create function pg_temp.make_nfe_key(p_nnf9 text, p_mod text default '65') returns text
language plpgsql immutable as $$
declare
  v_base   text := '35' || '2611' || '11222333000181' || p_mod || '001' || lpad(p_nnf9, 9, '0') || '1' || '12345678';
  v_weight int := 2;
  v_sum    int := 0;
  v_rem    int;
  v_dv     int;
  i        int;
begin
  for i in reverse 43..1 loop
    v_sum := v_sum + (substr(v_base, i, 1)::int * v_weight);
    v_weight := case when v_weight = 9 then 2 else v_weight + 1 end;
  end loop;
  v_rem := v_sum % 11;
  v_dv := case when v_rem in (0, 1) then 0 else 11 - v_rem end;
  return v_base || v_dv::text;
end $$;

do $$
declare
  ids          uuid[];
  c            uuid;
  p1           uuid;
  p2           uuid;
  adm          uuid;
  j            uuid;
  j2           uuid;
  j_mei        uuid;
  q1           uuid;
  q2           uuid;
  q_mei        uuid;
  v_pin1       text;
  v_pin2       text;
  v_key1       text;
  v_key2       text;
  v_bad_key    text;
  v_doc1       uuid;
  v_doc2       uuid;
  v_res        jsonb;
  v_err        text;
  v_debt_before numeric(12,2);
  v_debt_after  numeric(12,2);
  v_report     text;
  r_job        public.jobs%rowtype;
  r_doc        public.job_fiscal_documents%rowtype;
  r_mat        public.escrow_maturation_entries%rowtype;
  c_phash_in   constant bigint := 1099511627775;      -- 0x000000FFFFFFFFFF (MSB = 0)
  c_phash_near constant bigint := 1099511627768;      -- difere em 3 bits (< 5)
  c_phash_out1 constant bigint := -1099511627776;     -- ~c_phash_in (MSB = 1, Hamming = 64)
  c_phash_out2 constant bigint := -281474976710656;   -- 0xFFFF000000000000 (MSB = 1, Hamming = 40 vs in)
  c_phash_nf1  constant bigint := 71777214294589695;  -- 0x00FF00FF00FF00FF (Hamming >= 24 vs in/out)
  c_phash_nf2  constant bigint := -71777214294589696; -- ~c_phash_nf1 (MSB = 1, Hamming >= 24 vs in/out)
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 4 then
    raise exception 'TESTE ABORTADO: são necessários >= 4 perfis em public.profiles (encontrados: %).',
      coalesce(array_length(ids, 1), 0);
  end if;

  c := ids[1]; p1 := ids[2]; p2 := ids[3]; adm := ids[4];

  -- ---------------------------------------------------------------------------
  -- Preparação isolada na transação
  -- ---------------------------------------------------------------------------
  insert into public.app_settings (key, value) values ('checkin_sandbox', 'true')
    on conflict (key) do update set value = 'true';

  update public.profiles
     set role = null,
         is_client = false,
         is_provider = false,
         client_setup_done = false,
         provider_setup_done = false,
         verification_status = 'NOT_SUBMITTED',
         has_open_dispute = false,
         trust_tier = 'STANDARD',
         waterfall_tier_rank = 2,
         clawback_debt_balance = 0.00,
         maturing_wallet_balance = 0.00,
         available_wallet_balance = 0.00,
         external_trust_score = 85.00,
         last_latitude = null,
         last_longitude = null,
         cpf_hash = null,
         face_liveness_hash = null,
         device_fingerprint_hash = null,
         address_city = 'São Paulo - SP';

  update public.profiles
     set is_client = true, client_setup_done = true, full_name = 'Cliente Fiscal Teste'
   where id = c;

  update public.profiles
     set is_provider = true,
         verification_status = 'ACTIVE',
         provider_setup_done = true,
         latitude = -23.55052,
         longitude = -46.633308
   where id in (p1, p2);

  update public.profiles
     set role = 'admin', is_client = true, client_setup_done = true
   where id = adm;

  delete from public.provider_profiles where user_id in (p1, p2);
  insert into public.provider_profiles (user_id, specialties, visit_fee)
  values
    (p1, array['Elétrica'], 40),
    (p2, array['Elétrica'], 45);

  -- ---------------------------------------------------------------------------
  -- 01. Segurança aritmética de `hamming_distance_64` com bit de sinal (INT64_MIN)
  -- ---------------------------------------------------------------------------
  perform pg_temp.t(
    public.hamming_distance_64(0, -1) = 64
    and public.hamming_distance_64(0, (-9223372036854775807::bigint - 1)) = 1
    and public.hamming_distance_64(c_phash_in, c_phash_out1) = 64
    and public.hamming_distance_64(c_phash_in, c_phash_near) = 3,
    '01 hamming_distance_64 calcula 64 bits com sinais opostos (MSB=1 / INT64_MIN) sem overflow bigint'
  );

  -- ---------------------------------------------------------------------------
  -- Cria Job 1 (agendado -> pago -> em dia de serviço)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  insert into public.jobs (
    client_id, title, description, category, urgency, visibility,
    scheduled_for, address_summary, latitude, longitude
  ) values (
    c, 'Troca de quadro QDC', 'Substituição de disjuntores DIN', 'Elétrica',
    'scheduled', 'open', now(), 'Pinheiros, São Paulo - SP', -23.561414, -46.691415
  ) returning id into j;
  insert into public.job_addresses (job_id, address_line, cep)
  values (j, 'Rua dos Pinheiros, 500', '05422-001');
  reset role;

  perform pg_temp.login(p1);
  insert into public.quotes (job_id, provider_id, price, message)
  values (j, p1, 300.00, 'Mão de obra R$ 200 + disjuntores R$ 100')
  returning id into q1;
  reset role;

  perform pg_temp.login(c);
  perform public.accept_quote(q1);
  perform public.pay_job_mock(j, 'pix');
  select pin into v_pin1 from public.job_secrets where job_id = j;
  reset role;

  -- Configura Smart Split: R$ 200,00 mão de obra + R$ 100,00 materiais
  update public.jobs
     set labor_amount = 200.00,
         materials_amount = 100.00,
         escrow_status = 'LOCKED_100'
   where id = j;

  -- ---------------------------------------------------------------------------
  -- 02 & 03. Least-Privilege Grants (`anon` e escrita direta `authenticated`)
  -- ---------------------------------------------------------------------------
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
  perform pg_temp.t(
    starts_with(pg_temp.try(format('select public.register_forensic_photo(%L, ''check_in'', 123, %L)', j, 'evidence/' || j || '/a.jpg')), '42501')
    and starts_with(pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', ''0'', ''1'', '''', true, ''1'', 10.00, ''{}'', 0.0, 123, 100)',
      j, p1
    )), '42501')
    and starts_with(pg_temp.try(format('select public.settle_escrow_with_carveout_and_maturation(%L)', j)), '42501')
    and starts_with(pg_temp.try(format('select public.audit_sefaz_phase2_cancellation_and_clawback(%L, 100)', j)), '42501'),
    '02 anon recebe 42501 em register_forensic_photo, register_and_verify_material_fiscal_document, settle_escrow e audit_sefaz'
  );
  reset role;

  perform pg_temp.login(p1);
  perform pg_temp.t(
    starts_with(pg_temp.try(format('update public.jobs set checkin_photo_phash = 999 where id = %L', j)), '42501')
    and starts_with(pg_temp.try(format('update public.jobs set checkin_photo_path = ''x'' where id = %L', j)), '42501')
    and starts_with(pg_temp.try(format('select public.settle_escrow_with_carveout_and_maturation(%L)', j)), '42501')
    and starts_with(pg_temp.try(format('select public.audit_sefaz_phase2_cancellation_and_clawback(%L, 100)', j)), '42501'),
    '03 authenticated não pode editar colunas forenses direto nem invocar settle_escrow ou audit_sefaz (42501)'
  );

  -- ---------------------------------------------------------------------------
  -- 04..11. RPC `public.register_forensic_photo`
  -- ---------------------------------------------------------------------------
  v_err := pg_temp.try(format(
    'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
    j, c_phash_in, 'evidence/' || j || '/170000_1.jpg'
  ));
  perform pg_temp.t(
    position('FORENSIC_INVALID_JOB_STATE' in v_err) > 0,
    '04 register_forensic_photo rejeita job em estado scheduled antes do start_job (' || v_err || ')'
  );

  perform public.start_job(j, -23.561414, -46.691415, 10.0, false);
  reset role;

  perform pg_temp.login(c);
  v_err := pg_temp.try(format(
    'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
    j, c_phash_in, 'evidence/' || j || '/170000_1.jpg'
  ));
  reset role;
  perform pg_temp.login(p2);
  perform pg_temp.t(
    position('FORENSIC_UNAUTHORIZED_PROVIDER' in v_err) > 0
    and position('FORENSIC_UNAUTHORIZED_PROVIDER' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
      j, c_phash_in, 'evidence/' || j || '/170000_1.jpg'
    ))) > 0,
    '05 register_forensic_photo bloqueia cliente e profissional não alocado (FORENSIC_UNAUTHORIZED_PROVIDER)'
  );
  reset role;

  perform pg_temp.login(p1);
  perform pg_temp.t(
    position('FORENSIC_STAGE_INVALID' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''before'', %s, %L)',
      j, c_phash_in, 'evidence/' || j || '/170000_1.jpg'
    ))) > 0
    and position('FORENSIC_PHASH_REQUIRED' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', null, %L)',
      j, 'evidence/' || j || '/170000_1.jpg'
    ))) > 0,
    '06 register_forensic_photo valida p_stage (check_in/check_out) e p_phash não-nulo'
  );

  perform pg_temp.t(
    position('FORENSIC_PATH_INVALID' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
      j, c_phash_in, 'other/' || j || '/170000_1.jpg'
    ))) > 0
    and position('FORENSIC_PATH_INVALID' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
      j, c_phash_in, 'evidence/' || p1 || '/170000_1.jpg'
    ))) > 0
    and position('FORENSIC_PATH_INVALID' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
      j, c_phash_in, 'evidence/' || j || '/../secret.jpg'
    ))) > 0
    and position('FORENSIC_PATH_INVALID' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
      j, c_phash_in, 'evidence/' || j || '/payload.exe'
    ))) > 0,
    '07 register_forensic_photo rejeita prefixo fora de evidence/<job_id>/, path traversal (..) e extensão não-imagem'
  );

  v_res := public.register_forensic_photo(j, 'check_in', c_phash_in, 'evidence/' || j || '/170000_checkin.jpg');
  reset role;
  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    (v_res ->> 'recorded')::boolean = true
    and (v_res ->> 'stage') = 'check_in'
    and (v_res ->> 'phash')::bigint = c_phash_in
    and r_job.checkin_photo_phash = c_phash_in
    and r_job.checkin_photo_path = 'evidence/' || j::text || '/170000_checkin.jpg',
    '08 register_forensic_photo grava check_in (dHash + path privado) e retorna {recorded, stage, phash}'
  );

  perform pg_temp.login(p1);
  v_err := pg_temp.try(format(
    'select public.register_forensic_photo(%L, ''check_in'', %s, %L)',
    j, c_phash_out1, 'evidence/' || j || '/170000_checkin2.jpg'
  ));
  perform pg_temp.t(
    position('FORENSIC_CHECKIN_IMMUTABLE' in v_err) > 0,
    '09 check_in é estritamente imutável após gravado (FORENSIC_CHECKIN_IMMUTABLE)'
  );

  perform pg_temp.t(
    position('FORENSIC_PHOTO_DUPLICATE' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_out'', %s, %L)',
      j, c_phash_in, 'evidence/' || j || '/170000_checkout_dup.jpg'
    ))) > 0
    and position('FORENSIC_PHOTO_DUPLICATE' in pg_temp.try(format(
      'select public.register_forensic_photo(%L, ''check_out'', %s, %L)',
      j, c_phash_near, 'evidence/' || j || '/170000_checkout_near.jpg'
    ))) > 0,
    '10 check_out bloqueia foto idêntica ou quase idêntica ao check_in (hamming_distance_64 < 5 -> FORENSIC_PHOTO_DUPLICATE)'
  );

  v_res := public.register_forensic_photo(j, 'check_out', c_phash_out1, 'evidence/' || j || '/170000_checkout1.jpg');
  v_res := public.register_forensic_photo(j, 'check_out', c_phash_out2, 'evidence/' || j || '/170000_checkout2.png');
  reset role;
  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    (v_res ->> 'recorded')::boolean = true
    and (v_res ->> 'stage') = 'check_out'
    and r_job.checkout_photo_phash = c_phash_out2
    and r_job.checkout_photo_path = 'evidence/' || j::text || '/170000_checkout2.png'
    and r_job.checkin_photo_phash = c_phash_in,
    '11 check_out aceita foto distinta (incluindo bigint negativo MSB=1) sem alterar o check_in imutável'
  );

  -- ---------------------------------------------------------------------------
  -- 12..18. Endurecimento Fiscal (`MANUAL_KEY` + Zero-Trust `PENDING_SEFAZ`)
  -- ---------------------------------------------------------------------------
  v_key1 := pg_temp.make_nfe_key('000000101', '65');
  v_key2 := pg_temp.make_nfe_key('000000202', '55');
  v_bad_key := left(v_key1, 43) || (((right(v_key1, 1)::int + 1) % 10)::text);

  perform pg_temp.login(p1);
  v_err := pg_temp.try(format(
    'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
    j, p2, v_key1, c_phash_nf1
  ));
  reset role;
  perform pg_temp.login(p2);
  perform pg_temp.t(
    position('ERR_IDOR_BLOCKED' in v_err) > 0
    and position('ERR_UNAUTHORIZED_JOB' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p2, v_key1, c_phash_nf1
    ))) > 0,
    '12 register_and_verify_material_fiscal_document bloqueia IDOR de p_provider_id e prestador alheio ao job'
  );
  reset role;

  perform pg_temp.login(p1);
  perform pg_temp.t(
    position('FISCAL_HOMOLOGATION_ENV_BLOCKED' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''2'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p1, v_key1, c_phash_nf1
    ))) > 0
    and position('RECEIPT_PHOTO_REQUIRED' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, null, 100)',
      j, p1, v_key1
    ))) > 0
    and position('INVALID_CAPTURE_CHANNEL' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''SMS_SPOOF'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p1, v_key1, c_phash_nf1
    ))) > 0,
    '13 bloqueia ambiente de homologação (tpAmb=2), ausência de foto do cupom e canal inválido'
  );

  perform pg_temp.t(
    position('INVALID_NFE_KEY_MOD11' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p1, v_bad_key, c_phash_nf1
    ))) > 0,
    '14 bloqueia chave de 44 dígitos com DV Módulo 11 adulterado (INVALID_NFE_KEY_MOD11)'
  );

  perform pg_temp.t(
    position('FORENSIC_RECEIPT_PHOTO_RECYCLED' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p1, v_key1, c_phash_near
    ))) > 0
    and position('FORENSIC_RECEIPT_PHOTO_RECYCLED' in pg_temp.try(format(
      'select public.register_and_verify_material_fiscal_document(%L, %L, ''NFCE_65'', ''MANUAL_KEY'', %L, ''1'', '''', true, ''101'', 100.00, ''{}'', 0.0, %s, 100)',
      j, p1, v_key1, c_phash_out2
    ))) > 0,
    '15 impede reciclar foto de check_in ou check_out como foto de cupom fiscal (FORENSIC_RECEIPT_PHOTO_RECYCLED)'
  );

  -- Envia `MANUAL_KEY` com inputs maliciosos do cliente (`p_ela_tamper_score = 0.9900` e `p_sefaz_status_initial = 100`):
  -- o servidor DEVE ignorar ambos, aceitar a chave Mod-11 válida e gravar `PENDING_SEFAZ` sem isenção imediata!
  v_res := public.register_and_verify_material_fiscal_document(
    j,
    p1,
    'NFCE_65',
    'MANUAL_KEY',
    v_key1,
    '1',
    '',
    true,
    '',
    100.00,
    array['85362000'],
    0.9900,
    c_phash_nf1,
    100
  );
  v_doc1 := (v_res ->> 'document_id')::uuid;
  perform pg_temp.t(
    (v_res ->> 'recorded')::boolean = true
    and (v_res ->> 'verified')::boolean = false
    and (v_res ->> 'sefaz_confirmed')::boolean = false
    and (v_res ->> 'sefaz_verified')::boolean = false
    and (v_res ->> 'verification_status') = 'PENDING_SEFAZ'
    and (v_res ->> 'capture_channel') = 'MANUAL_KEY'
    and (v_res ->> 'exempt_material_amount')::numeric = 0.00
    and (v_res ->> 'receipt_number') = '000000101',
    '16 MANUAL_KEY válido ignora p_sefaz_status_initial/p_ela_tamper_score do cliente e retorna verified=false, sefaz_confirmed=false, PENDING_SEFAZ, exempt=0.00'
  );

  v_err := pg_temp.try(format(
    'update public.job_fiscal_documents set verification_status = ''VERIFIED_SEFAZ'' where id = %L',
    v_doc1
  ));
  reset role;

  -- Cliente titular do pedido lê a nota real via RLS; prestador alheio vê 0 linhas
  perform pg_temp.login(c);
  select * into r_doc from public.job_fiscal_documents where id = v_doc1;
  reset role;

  perform pg_temp.login(p2);
  perform pg_temp.t(
    r_doc.id = v_doc1
    and r_doc.verification_status = 'PENDING_SEFAZ'
    and r_doc.sefaz_status_initial is null
    and r_doc.sefaz_status_recheck is null
    and r_doc.ela_tamper_score = 0.0000
    and r_doc.capture_channel = 'MANUAL_KEY'
    and starts_with(v_err, '42501')
    and (select count(*) from public.job_fiscal_documents where id = v_doc1) = 0,
    '17 linha persistida nasce PENDING_SEFAZ (sefaz_status_initial=NULL, ela=0.0000), cliente titular lê via RLS, alheio vê 0 e UPDATE direto é bloqueado (42501)'
  );
  reset role;

  -- Valida modo MEI_RECEIPT_CGSN140 em job dedicado (teto R$ 150,00 + PENDING_SEFAZ)
  perform pg_temp.login(c);
  insert into public.jobs (
    client_id, title, description, category, urgency, visibility, scheduled_for, address_summary
  ) values (
    c, 'Tomada simples', 'Troca de tomada', 'Elétrica', 'scheduled', 'open', now(), 'Pinheiros, São Paulo - SP'
  ) returning id into j_mei;
  reset role;
  perform pg_temp.login(p1);
  insert into public.quotes (job_id, provider_id, price) values (j_mei, p1, 120.00) returning id into q_mei;
  reset role;
  perform pg_temp.login(c);
  perform public.accept_quote(q_mei);
  perform public.pay_job_mock(j_mei, 'pix');
  reset role;
  perform pg_temp.login(p1);
  v_err := pg_temp.try(format(
    'select public.register_and_verify_material_fiscal_document(%L, %L, ''MEI_RECEIPT_CGSN140'', ''OCR_MEI_RECEIPT'', null, ''1'', ''11.222.333/0001-81'', true, ''MEI-99'', 180.00, ''{}'', 0.0, %s, 100)',
    j_mei, p1, c_phash_nf1
  ));
  v_res := public.register_and_verify_material_fiscal_document(
    j_mei, p1, 'MEI_RECEIPT_CGSN140', 'OCR_MEI_RECEIPT', null, '1',
    '11.222.333/0001-81', true, 'MEI-100', 80.00, '{}', 0.5000, c_phash_nf1, 100
  );
  reset role;
  perform pg_temp.t(
    position('SMART_FISCAL_CAP_EXCEEDED' in v_err) > 0
    and (v_res ->> 'verified')::boolean = false
    and (v_res ->> 'verification_status') = 'PENDING_SEFAZ'
    and (v_res ->> 'exempt_material_amount')::numeric = 0.00
    and (v_res ->> 'smart_fiscal_cap_applied')::boolean = true,
    '18 recibo MEI aplica teto de R$ 150,00 e também nasce em PENDING_SEFAZ com exempt_material_amount=0.00'
  );

  -- ---------------------------------------------------------------------------
  -- 19 & 20. Liquidação Financeira Smart Split COM nota ainda `PENDING_SEFAZ`:
  --          NÃO concede isenção de 0% (cobra 15% sobre R$ 200 + R$ 100 = R$ 300)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(p1);
  v_res := public.complete_job_and_schedule_escrow(j, p1, c_phash_out2, 15.0, v_pin1);
  reset role;

  select * into r_mat from public.escrow_maturation_entries where job_id = j;
  perform pg_temp.t(
    (v_res ->> 'status') = 'COMPLETED_BY_PIN'
    and r_mat.gross_labor_amount = 200.00
    and r_mat.materials_reimbursement_amount = 0.00
    and r_mat.platform_operational_fee = 40.50
    and r_mat.warranty_carveout_fee = 4.50
    and r_mat.net_provider_amount = 255.00,
    '19 liquidação com nota PENDING_SEFAZ tributa 15% sobre R$ 300 (op=40.50, gar=4.50, isento=0.00, líq=255.00)'
  );

  -- Se a SEFAZ depois reportar cancelamento (cStat=101) numa nota que NUNCA deu isenção, não há bitributação
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  execute 'set local role service_role';
  v_res := public.audit_sefaz_phase2_cancellation_and_clawback(v_doc1, 101);
  reset role;

  select clawback_debt_balance into v_debt_after from public.profiles where id = p1;
  perform pg_temp.t(
    (v_res ->> 'verification_status') = 'CANCELED_CLAWBACK'
    and (v_res ->> 'clawback_debited')::numeric = 0.00
    and v_debt_after = 0.00,
    '20 cancelamento SEFAZ (cStat=101) em nota nunca isenta marca CANCELED_CLAWBACK com clawback_debited=0.00 (sem bitributação)'
  );

  -- ---------------------------------------------------------------------------
  -- 21 & 22. Liquidação Financeira Smart Split APÓS oráculo SEFAZ confirmar `cStat=100`
  --          (`VERIFIED_SEFAZ` -> 0% taxa sobre materiais) + Clawback pós-cancelamento
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  insert into public.jobs (
    client_id, title, description, category, urgency, visibility,
    scheduled_for, address_summary, latitude, longitude
  ) values (
    c, 'Instalação DPS Classe II', 'Quadro com protetor de surto', 'Elétrica',
    'scheduled', 'open', now(), 'Vila Mariana, São Paulo - SP', -23.5891, -46.6347
  ) returning id into j2;
  insert into public.job_addresses (job_id, address_line, cep)
  values (j2, 'Rua Domingos de Morais, 1200', '04010-100');
  reset role;

  perform pg_temp.login(p1);
  insert into public.quotes (job_id, provider_id, price) values (j2, p1, 300.00) returning id into q2;
  reset role;

  perform pg_temp.login(c);
  perform public.accept_quote(q2);
  perform public.pay_job_mock(j2, 'pix');
  select pin into v_pin2 from public.job_secrets where job_id = j2;
  reset role;

  update public.jobs
     set labor_amount = 200.00,
         materials_amount = 100.00,
         escrow_status = 'LOCKED_100'
   where id = j2;

  perform pg_temp.login(p1);
  perform public.start_job(j2, -23.5891, -46.6347, 10.0, false);
  perform public.register_forensic_photo(j2, 'check_in', c_phash_in, 'evidence/' || j2 || '/checkin.jpg');
  perform public.register_forensic_photo(j2, 'check_out', c_phash_out1, 'evidence/' || j2 || '/checkout.jpg');
  v_res := public.register_and_verify_material_fiscal_document(
    j2, p1, 'NFE_55', 'QR_CODE', v_key2, '1', '', true, '202', 100.00, array['85363000'], 0.0, c_phash_nf2, 100
  );
  v_doc2 := (v_res ->> 'document_id')::uuid;
  reset role;

  -- Oráculo SEFAZ server-side confirma autorização real (cStat = 100 -> VERIFIED_SEFAZ)
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  execute 'set local role service_role';
  v_res := public.audit_sefaz_phase2_cancellation_and_clawback(v_doc2, 100);
  reset role;

  perform pg_temp.login(p1);
  perform public.complete_job_and_schedule_escrow(j2, p1, c_phash_out1, 8.5, v_pin2);
  reset role;

  select * into r_mat from public.escrow_maturation_entries where job_id = j2;
  perform pg_temp.t(
    (v_res ->> 'verification_status') = 'VERIFIED_SEFAZ'
    and r_mat.gross_labor_amount = 200.00
    and r_mat.materials_reimbursement_amount = 100.00
    and r_mat.platform_operational_fee = 27.00
    and r_mat.warranty_carveout_fee = 3.00
    and r_mat.net_provider_amount = 270.00,
    '21 após oráculo SEFAZ (cStat=100 -> VERIFIED_SEFAZ), materiais R$ 100 têm isenção 0% (op=27.00, gar=3.00, líq=270.00)'
  );

  select clawback_debt_balance into v_debt_before from public.profiles where id = p1;
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  execute 'set local role service_role';
  v_res := public.audit_sefaz_phase2_cancellation_and_clawback(v_doc2, 101);
  reset role;

  select clawback_debt_balance into v_debt_after from public.profiles where id = p1;
  perform pg_temp.t(
    (v_res ->> 'canceled_on_sefaz')::boolean = true
    and (v_res ->> 'verification_status') = 'CANCELED_CLAWBACK'
    and (v_res ->> 'clawback_debited')::numeric = 15.00
    and (v_debt_after - v_debt_before) = 15.00
    and exists (
      select 1 from public.warranty_pool_ledger w
       where w.job_id = j2
         and w.entry_type = 'CARVEOUT_CONTRIBUTION_1_5_PCT'
         and w.amount = 1.50
    ),
    '22 fraude de cancelamento pós-liquidação (cStat=101 em nota VERIFIED_SEFAZ) debita clawback de R$ 15,00 (15%) e recompõe 1,5% no Fundo Garantidor'
  );

  -- ---------------------------------------------------------------------------
  -- 23. Regressão `jobs.updated_at` em runtime: `open_warranty_mediation`,
  --     `trigger_layer3_rework` e `process_autonomous_escrow_and_mediation_queues`
  --     (sem falso-positivo em `jobs_enforce_post_completion_immutability`)
  -- ---------------------------------------------------------------------------
  perform pg_temp.login(c);
  v_doc1 := public.open_warranty_mediation(
    j,
    c,
    'EXECUTION_DEFECT',
    'Disjuntor voltou a desarmar em carga nominal',
    'evidence/' || j || '/defect.jpg',
    4294967295, -- distinto de check_in e check_out
    18.0
  );
  reset role;

  update public.job_mediations
     set original_provider_deadline_at = now() - interval '5 minutes'
   where id = v_doc1;

  perform pg_temp.login(c);
  v_doc2 := public.trigger_layer3_rework(v_doc1, 120.00);
  reset role;

  v_res := public.process_autonomous_escrow_and_mediation_queues();
  select * into r_job from public.jobs where id = j;
  perform pg_temp.t(
    v_doc1 is not null
    and v_doc2 is not null
    and r_job.status = 'disputed'
    and r_job.updated_at is not null
    and (v_res ->> 'auto_released_jobs')::int >= 0
    and to_regprocedure('public.trigger_layer3_rework(uuid)') is null,
    '23 jobs.updated_at + trigger _touch_updated_at sustentam open_warranty_mediation, trigger_layer3_rework e fila autônoma pós-conclusão'
  );

  -- ---------------------------------------------------------------------------
  -- Relatório consolidado
  -- ---------------------------------------------------------------------------
  select string_agg(
    (case when r2.ok then 'ok    ' else 'FAIL  ' end) || lpad(r2.n::text, 2, '0') || ' ' || r2.name,
    E'\n' order by r2.n
  ) into v_report
  from res r2;

  raise exception E'\n=== RELATÓRIO FORENSIC PHOTO & FISCAL HARDENING ===\n%\n\nOK=%  FALHAS=%\n',
    v_report,
    (select count(*) from res r3 where r3.ok),
    (select count(*) from res r4 where not r4.ok);
end $$;

rollback;

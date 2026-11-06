-- ============================================================================
-- DESPERRENGUE — Teste de fumaça das CATEGORIAS AMPLIADAS (33) e do ponto no dossiê do cliente
-- (migration 20261107120000).
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/expanded_categories_smoke.sql
-- Requer >= 3 linhas em public.profiles.   c = cliente   p1 = Jardineiro   p2 = Eletricista
-- ============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$ insert into pg_temp.res (ok, name) values (p_ok, p_name) $$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; j uuid; n int; d jsonb;
  syn text[][] := array[
    ['Jardineiro', 'jardinagem'], ['Paisagista', 'jardinagem'], ['Dedetizador', 'dedetizacao'],
    ['Ar condicionado', 'ar-condicionado'], ['Split', 'ar-condicionado'], ['Marido de aluguel', 'pequenos reparos'],
    ['Vidraçaria', 'vidraceiro'], ['Soldador', 'serralheria'], ['Telhadista', 'telhados e calhas'],
    ['Desentupidor', 'desentupidora'], ['Piscineiro', 'piscina'], ['Antenista', 'tv e antenas'],
    ['CFTV', 'cameras e alarmes'], ['Portão eletrônico', 'portoes e interfones'], ['Painel solar', 'energia solar'],
    ['Azulejista', 'pisos e revestimentos'], ['Persiana', 'cortinas e persianas'], ['Tapeceiro', 'estofados e tapetes'],
    ['Carreto', 'mudancas e fretes'], ['Wi-Fi', 'wi-fi'], ['Wifi', 'informatica e redes'], ['Cuidadora', 'cuidador de idosos'],
    ['Nanny', 'baba'], ['Passeador de cães', 'pet care'], ['Pintor', 'pintura'], ['Eletricista', 'eletrica'],
    ['Hidráulica', 'encanador'], ['Encanador', 'encanador']
  ];
  i int;
begin
  -- ===== SINÔNIMOS NOVOS (espelham kTagAliases no app) =====
  for i in 1 .. array_length(syn, 1) loop
    perform pg_temp.t(public.norm_tag(syn[i][1]) = syn[i][2],
      format('%s: norm_tag(%L) = %L (%L)', lpad(i::text, 2, '0'), syn[i][1], syn[i][2], public.norm_tag(syn[i][1])));
  end loop;

  -- ===== CENÁRIO =====
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 3 then raise exception 'TESTE ABORTADO: são necessários >= 3 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3];

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id = c;
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee) values
    (p1, array['Jardineiro'], 30),
    (p2, array['Eletricista'], 30);

  -- Índice GIN sobre norm_tags(specialties): a view pública enxerga o sinônimo novo.
  perform pg_temp.login(c);
  select count(*) into n from public.provider_public_profiles where specialty_slugs @> array['jardinagem'];
  perform pg_temp.t(n = 1, '40 "Jardineiro" cadastrado aparece na categoria Jardinagem: ' || n);
  select count(*) into n from public.provider_public_profiles where specialty_slugs @> array['jardinagem'] and id = p2;
  perform pg_temp.t(n = 0, '41 isolamento: eletricista NÃO aparece em Jardinagem');
  select count(*) into n from public.provider_public_profiles where specialty_slugs @> array['eletrica'];
  perform pg_temp.t(n = 1, '42 "Eletricista" continua casando com Elétrica: ' || n);
  reset role;

  -- ===== DOSSIÊ: precisão e origem do ponto (mesma precedência do _job_destination) =====
  insert into public.jobs (client_id, title, description, category, visibility)
    values (c, 'Podar a cerca viva', 'desc', 'Jardinagem', 'open') returning id into j;

  perform pg_temp.login(c);
  d := public.client_job_dossier(j);
  perform pg_temp.t(d ? 'geo_precision' and d ? 'geo_source', '50 dossiê traz as chaves geo_precision/geo_source');
  perform pg_temp.t((d ->> 'latitude') is null and (d ->> 'geo_precision') is null, '51 sem ponto algum: tudo nulo');
  reset role;

  insert into public.job_geo (job_id, lat, lng, precision_level, source) values (j, -21.79, -46.56, 'locality', 'client_geocode');
  perform pg_temp.login(c);
  d := public.client_job_dossier(j);
  perform pg_temp.t((d ->> 'geo_precision') = 'locality' and (d ->> 'geo_source') = 'client_geocode', '52 só geocodificação: locality / client_geocode');
  perform pg_temp.t((d ->> 'latitude')::numeric = -21.79, '53 latitude vem do job_geo');
  reset role;

  update public.jobs set latitude = -21.80, longitude = -46.60 where id = j;
  perform pg_temp.login(c);
  d := public.client_job_dossier(j);
  perform pg_temp.t((d ->> 'geo_precision') = 'exact' and (d ->> 'geo_source') = 'client', '54 coordenadas do pedido vencem o locality: exact / client');
  perform pg_temp.t((d ->> 'latitude')::numeric = -21.80, '55 latitude vem do pedido');
  reset role;

  update public.job_geo set lat = -21.8027, lng = -46.6028, precision_level = 'house', source = 'client_pin' where job_id = j;
  perform pg_temp.login(c);
  d := public.client_job_dossier(j);
  perform pg_temp.t((d ->> 'geo_precision') = 'exact' and (d ->> 'geo_source') = 'client_pin', '56 pino confirmado vence tudo: exact / client_pin');
  perform pg_temp.t((d ->> 'latitude')::numeric = -21.8027 and (d ->> 'longitude')::numeric = -46.6028, '57 coordenadas do pino');
  reset role;

  perform pg_temp.login(p1);
  perform pg_temp.t(public.client_job_dossier(j) is null, '58 não-dono continua recebendo dossiê nulo');
  reset role;
end $$;

do $$
declare r text; bad int; tot int;
begin
  select count(*) filter (where not ok), count(*) into bad, tot from pg_temp.res;
  select string_agg(format('%s %s %s', case when ok then 'ok  ' else 'FALHA' end, lpad(n::text, 3), name), E'\n' order by n) into r from pg_temp.res;
  raise exception E'\n%\n\nOK=%  FALHAS=%', r, tot - bad, bad;
end $$;

rollback;

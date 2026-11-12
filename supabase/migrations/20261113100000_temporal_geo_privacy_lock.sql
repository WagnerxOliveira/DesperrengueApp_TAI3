-- =============================================================================
-- DESPERRENGUE — Temporal & Spatial Geo-Privacy Lock (Zero-Trust Server-Side)
-- Migration: 20261113100000_temporal_geo_privacy_lock.sql
--
-- OBJETIVO:
--   Garantir no PostgreSQL/Supabase vazamento ZERO de rua, número, complemento,
--   referência, CEP e coordenadas exatas do imóvel do cliente para profissionais
--   antes das 00:00 (America/Sao_Paulo, UTC-3 fixo) do dia agendado, e aplicar
--   re-bloqueio permanente (LGPD minimização/retenção) após conclusão,
--   cancelamento ou mediação.
--
-- CAMADAS DE DEFESA:
--   1. Segredo criptográfico de 256 bits isolado em `private.geo_privacy_secrets`
--      (schema `private` sem GRANT para `public`/`anon`/`authenticated`, RLS
--      forçado sem policies).
--   2. Centro aproximado determinístico via HMAC-SHA256 (`_geo_fuzzy_center`):
--      deslocamento esférico de 151–349 m e raio de 500–800 m (imóvel real
--      sempre contido no círculo com margem >= 150 m da borda e nunca no centro;
--      estável por job; não-invertível sem a chave secreta do servidor).
--   3. Eliminação de vazamento em `public.jobs` e `supabase_realtime`:
--      coordenadas exatas residem apenas em `public.job_geo` e endereço completo
--      apenas em `public.job_addresses`, ambos protegidos por RLS via
--      `public._can_see_exact_location(job_id, auth.uid())`. Triggers migram
--      automaticamente coordenadas/CEP enviados em `jobs` para `job_geo` /
--      `job_addresses`, mantendo `jobs.latitude = NULL`, `jobs.longitude = NULL`,
--      `jobs.address_cep = NULL`, `jobs.address_summary` sanitizado (apenas
--      Bairro + Cidade/UF) e `jobs.public_lat`/`public_lng`/`fuzzy_radius_m` com
--      o centro aproximado (ou NULL após encerramento).
--   4. Máquina de estados temporal em `America/Sao_Paulo` (`_job_privacy_phase`)
--      e RPC canônica `get_job_location_for_viewer(p_job)` + blindagem de
--      `job_destination`, `provider_job_dossier`, `provider_full_service_history`,
--      `jobs_notify_area_providers`, `job_client_cards`, `chat_counterpart`,
--      `_messages_guard` e notificação diária idempotente às 00:00 SP.
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- 1. Cofre privado do segredo HMAC-SHA256 (inacessível via PostgREST / API)
-- -----------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.geo_privacy_secrets (
  id         smallint primary key default 1 check (id = 1),
  secret_key bytea not null check (octet_length(secret_key) >= 32),
  created_at timestamptz not null default now()
);

alter table private.geo_privacy_secrets enable row level security;
alter table private.geo_privacy_secrets force row level security;
revoke all on table private.geo_privacy_secrets from public, anon, authenticated;

do $$
begin
  perform set_config('search_path', 'public, extensions', true);
  insert into private.geo_privacy_secrets (id, secret_key)
  values (1, gen_random_bytes(32))
  on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Motor interno de deslocamento espacial HMAC-SHA256 (`_geo_fuzzy_center`)
-- -----------------------------------------------------------------------------
create or replace function public._geo_fuzzy_center(
  p_job uuid,
  p_lat double precision,
  p_lng double precision
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_secret   bytea;
  v_mac      bytea;
  v_u0       double precision;
  v_u1       double precision;
  v_u2       integer;
  v_offset_m double precision;
  v_bearing  double precision;
  v_radius_m integer;
  v_ang_dist double precision;
  v_lat1     double precision;
  v_lng1     double precision;
  v_lat2     double precision;
  v_lng2     double precision;
  v_out_lat  double precision;
  v_out_lng  double precision;
begin
  if p_job is null then
    return null;
  end if;

  select s.secret_key
    into v_secret
    from private.geo_privacy_secrets s
   where s.id = 1;

  if v_secret is null then
    raise exception 'GEO_PRIVACY_SECRET_MISSING' using errcode = 'P0001';
  end if;

  v_mac := hmac(convert_to(p_job::text, 'UTF8'), v_secret, 'sha256');
  v_u2 := get_byte(v_mac, 4) * 256 + get_byte(v_mac, 5);
  v_radius_m := 500 + ((v_u2 * 301) / 65536); -- inteiro determinístico em [500, 800]

  if p_lat is null or p_lng is null
     or p_lat not between -90.0 and 90.0
     or p_lng not between -180.0 and 180.0 then
    return jsonb_build_object(
      'lat', null,
      'lng', null,
      'radius_m', v_radius_m
    );
  end if;

  v_u0 := (get_byte(v_mac, 0) * 256 + get_byte(v_mac, 1))::double precision;
  v_u1 := (get_byte(v_mac, 2) * 256 + get_byte(v_mac, 3))::double precision;

  -- [151.0, 349.0] m antes do arredondamento de 6 casas (~0,11 m), garantindo
  -- haversine_m(exato, fuzzy) estritamente em [150, 350] m e folga >= 150 m
  -- até a borda do círculo de raio [500, 800] m.
  v_offset_m := 151.0 + (v_u0 / 65535.0) * 198.0;
  v_bearing  := (v_u1 / 65536.0) * 2.0 * pi();
  v_ang_dist := v_offset_m / 6371000.0;

  v_lat1 := radians(p_lat);
  v_lng1 := radians(p_lng);

  v_lat2 := asin(
    greatest(-1.0, least(1.0,
      sin(v_lat1) * cos(v_ang_dist) +
      cos(v_lat1) * sin(v_ang_dist) * cos(v_bearing)
    ))
  );
  v_lng2 := v_lng1 + atan2(
    sin(v_bearing) * sin(v_ang_dist) * cos(v_lat1),
    cos(v_ang_dist) - sin(v_lat1) * sin(v_lat2)
  );

  v_out_lat := greatest(-90.0, least(90.0, round(degrees(v_lat2)::numeric, 6)::double precision));
  v_out_lng := round(((((degrees(v_lng2) + 540.0)::numeric) % 360.0) - 180.0), 6)::double precision;

  return jsonb_build_object(
    'lat', v_out_lat,
    'lng', v_out_lng,
    'radius_m', v_radius_m
  );
end $$;

revoke all on function public._geo_fuzzy_center(uuid, double precision, double precision)
  from public, anon, authenticated;

comment on function public._geo_fuzzy_center(uuid, double precision, double precision) is
  'Uso exclusivo interno do servidor. Calcula centro aproximado determinístico via HMAC-SHA256 com chave secreta em private.geo_privacy_secrets (deslocamento 150–350 m, raio 500–800 m; ponto real sempre dentro do círculo).';

-- -----------------------------------------------------------------------------
-- 3. Parser estruturado de endereço brasileiro & sanitizador de resumo regional
-- -----------------------------------------------------------------------------
create or replace function public._parse_job_address_parts(
  p_address_line text,
  p_summary text,
  p_fallback_city text default null
)
returns jsonb
language plpgsql
immutable
parallel safe
set search_path = public
as $$
declare
  v_line          text := btrim(coalesce(p_address_line, ''));
  v_sum           text := btrim(coalesce(p_summary, ''));
  v_fb            text := btrim(coalesce(p_fallback_city, ''));
  v_street        text := null;
  v_number        text := null;
  v_neighborhood  text := '';
  v_city          text := '';
  v_uf            text := '';
  v_cep_match     text[];
  v_cep           text := null;
  v_uf_match      text[];
  v_num_match     text[];
  v_line_segs     text[];
  v_region_raw    text := '';
  v_segs          text[];
  v_kept          text[] := '{}'::text[];
  v_seg           text;
  v_comma_parts   text[];
  v_safe_summary  text := null;
  i               integer;
begin
  -- Extrai CEP caso venha embutido em address_line ou summary
  v_cep_match := regexp_match(v_line || ' ' || v_sum, '\m([0-9]{5}-?[0-9]{3})\M');
  if v_cep_match is not null then
    v_cep := regexp_replace(v_cep_match[1], '^([0-9]{5})([0-9]{3})$', '\1-\2');
  end if;

  -- 1) Extrai rua e número a partir de p_address_line (ex.: "Rua X, 203 - Bairro, Cidade - MG")
  if v_line <> '' then
    v_line := btrim(regexp_replace(v_line, '\m[0-9]{5}-?[0-9]{3}\M', '', 'g'));
    v_line_segs := regexp_split_to_array(v_line, '\s+-\s+');
    if coalesce(array_length(v_line_segs, 1), 0) >= 1 then
      v_num_match := regexp_match(
        btrim(v_line_segs[1]),
        '^([^,]+?)(?:,\s*(s/?n[º°o]?|sem\s+n[uú]mero|[0-9]+[A-Za-z0-9/-]*))?(?:,\s*.*)?$',
        'i'
      );
      if v_num_match is not null then
        v_street := nullif(btrim(v_num_match[1]), '');
        v_number := nullif(btrim(v_num_match[2]), '');
      end if;
      if v_number is null and v_street is not null then
        v_num_match := regexp_match(
          v_street,
          '^(.*?)\s+n[º°o.]?\s*([0-9]+[A-Za-z0-9/-]*)$',
          'i'
        );
        if v_num_match is not null then
          v_street := nullif(btrim(v_num_match[1]), '');
          v_number := nullif(btrim(v_num_match[2]), '');
        end if;
      end if;
    end if;
  end if;

  -- 2) Determina a fonte regional (prioriza summary; se vazio e line tiver sufixo após ' - ', usa o sufixo)
  if v_sum <> '' then
    v_region_raw := v_sum;
  elsif coalesce(array_length(v_line_segs, 1), 0) >= 2 then
    v_region_raw := array_to_string(v_line_segs[2:array_length(v_line_segs, 1)], ' - ');
  elsif v_fb <> '' then
    v_region_raw := v_fb;
  end if;

  v_region_raw := btrim(regexp_replace(v_region_raw, '\m[0-9]{5}-?[0-9]{3}\M', '', 'g'));
  v_region_raw := btrim(regexp_replace(v_region_raw, '[,\s-]+$', ''));

  -- Extrai UF brasileira válida no final (ex.: "- MG", "/ SP", ", RJ")
  v_uf_match := regexp_match(
    v_region_raw,
    '^(.*?)\s*[-/,]\s*(AC|AL|AP|AM|BA|CE|DF|ES|GO|MA|MT|MS|MG|PA|PB|PR|PE|PI|RJ|RN|RS|RO|RR|SC|SP|SE|TO)$',
    'i'
  );
  if v_uf_match is not null then
    v_region_raw := btrim(v_uf_match[1]);
    v_uf := upper(v_uf_match[2]);
  elsif v_line <> '' then
    v_uf_match := regexp_match(
      v_line,
      '^(.*?)\s*[-/,]\s*(AC|AL|AP|AM|BA|CE|DF|ES|GO|MA|MT|MS|MG|PA|PB|PR|PE|PI|RJ|RN|RS|RO|RR|SC|SP|SE|TO)$',
      'i'
    );
    if v_uf_match is not null then
      v_uf := upper(v_uf_match[2]);
    end if;
  end if;

  -- Remove quaisquer segmentos acidentais de logradouro/número/complemento
  if v_region_raw <> '' then
    v_segs := regexp_split_to_array(v_region_raw, '\s+-\s+');
    for i in 1..coalesce(array_length(v_segs, 1), 0) loop
      v_seg := btrim(v_segs[i]);
      if v_seg = '' then
        continue;
      end if;
      -- Descarta segmento com número predial (", 123" / ", s/n") ou prefixo explícito de logradouro/complemento
      if v_seg ~* ',\s*(s/?n[º°o]?|sem\s+n[uú]mero|[0-9]{1,6}[A-Za-z0-9/-]*)\s*($|,)'
         or v_seg ~* '^\s*(rua|r\.|avenida|av\.|alameda|al\.|travessa|tv\.|estrada|est\.|rodovia|rod\.|viela|beco|servid[aã]o)\M'
         or v_seg ~* '^\s*(apto?\.?|apartamento|bloco|bl\.|casa|cs\.|fundos|sala|sl\.|loja|lj\.|lote|lt\.|condom[ií]nio|port[aã]o)\M' then
        continue;
      end if;
      v_kept := array_append(v_kept, v_seg);
    end loop;
  end if;

  if coalesce(array_length(v_kept, 1), 0) >= 2 then
    v_neighborhood := btrim(v_kept[1]);
    v_city := btrim(v_kept[array_length(v_kept, 1)]);
  elsif coalesce(array_length(v_kept, 1), 0) = 1 then
    v_comma_parts := regexp_split_to_array(v_kept[1], '\s*,\s*');
    if coalesce(array_length(v_comma_parts, 1), 0) >= 2 then
      v_neighborhood := btrim(v_comma_parts[1]);
      v_city := btrim(v_comma_parts[array_length(v_comma_parts, 1)]);
    else
      v_city := btrim(v_kept[1]);
    end if;
  end if;

  -- Fallback para cidade do perfil caso o resumo estivesse vazio ou contivesse apenas rua/número
  if v_city = '' and v_fb <> '' then
    v_uf_match := regexp_match(
      v_fb,
      '^(.*?)\s*[-/,]\s*(AC|AL|AP|AM|BA|CE|DF|ES|GO|MA|MT|MS|MG|PA|PB|PR|PE|PI|RJ|RN|RS|RO|RR|SC|SP|SE|TO)$',
      'i'
    );
    if v_uf_match is not null then
      v_fb := btrim(v_uf_match[1]);
      if v_uf = '' then
        v_uf := upper(v_uf_match[2]);
      end if;
    end if;
    if not (
      v_fb ~* ',\s*(s/?n[º°o]?|sem\s+n[uú]mero|[0-9]{1,6}[A-Za-z0-9/-]*)\s*($|,)'
      or v_fb ~* '^\s*(rua|r\.|avenida|av\.|alameda|al\.|travessa|tv\.|estrada|est\.|rodovia|rod\.|viela|beco|servid[aã]o)\M'
    ) then
      v_city := v_fb;
    end if;
  end if;

  if v_city <> '' then
    v_safe_summary := case
      when v_neighborhood <> '' and v_uf <> '' then v_neighborhood || ', ' || v_city || ' - ' || v_uf
      when v_neighborhood <> '' then v_neighborhood || ', ' || v_city
      when v_uf <> '' then v_city || ' - ' || v_uf
      else v_city
    end;
  elsif v_neighborhood <> '' then
    v_safe_summary := case when v_uf <> '' then v_neighborhood || ' - ' || v_uf else v_neighborhood end;
  end if;

  return jsonb_build_object(
    'street', v_street,
    'number', v_number,
    'neighborhood', v_neighborhood,
    'city', v_city,
    'uf', v_uf,
    'cep', v_cep,
    'safe_summary', v_safe_summary
  );
end $$;

revoke all on function public._parse_job_address_parts(text, text, text) from public, anon;
grant execute on function public._parse_job_address_parts(text, text, text) to authenticated;

comment on function public._parse_job_address_parts(text, text, text) is
  'Extrai rua, número, bairro, cidade, UF, CEP e resumo seguro (apenas Bairro + Cidade/UF, sem logradouro/número/complemento).';

create or replace function public._sanitize_address_summary(
  p_summary text,
  p_fallback_city text default null
)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select public._parse_job_address_parts(null, p_summary, p_fallback_city) ->> 'safe_summary';
$$;

revoke all on function public._sanitize_address_summary(text, text) from public, anon;
grant execute on function public._sanitize_address_summary(text, text) to authenticated;

comment on function public._sanitize_address_summary(text, text) is
  'Remove qualquer rua, número, complemento ou CEP de um resumo de endereço, preservando apenas Bairro e Cidade/UF.';

-- -----------------------------------------------------------------------------
-- 4. Máquina de estados temporal em America/Sao_Paulo (`_job_privacy_phase`)
-- -----------------------------------------------------------------------------
create or replace function public._job_privacy_phase(
  p_job uuid,
  p_viewer uuid,
  p_now timestamptz default now()
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  j            public.jobs%rowtype;
  v_is_admin   boolean := false;
  v_authorized boolean := false;
  v_today_sp   date;
  v_sched_sp   date;
begin
  if p_job is null or p_viewer is null then
    return 'denied';
  end if;

  select * into j from public.jobs where id = p_job;
  if not found then
    return 'denied';
  end if;

  -- 1. Titular do pedido (cliente dono): acesso integral permanente
  if j.client_id = p_viewer then
    return 'owner_full';
  end if;

  -- 2. Administrador de auditoria/mediação: acesso integral
  select exists (
    select 1 from public.profiles pr
     where pr.id = p_viewer and pr.role = 'admin'
  ) into v_is_admin;

  if v_is_admin then
    return 'owner_full';
  end if;

  -- 3. Verifica se o visualizador é um profissional legitimamente autorizado a ver o card do job
  if j.provider_id = p_viewer then
    v_authorized := true;
  elsif exists (
    select 1 from public.job_invites ji
     where ji.job_id = j.id and ji.provider_id = p_viewer
  ) then
    v_authorized := true;
  elsif exists (
    select 1 from public.quotes q
     where q.job_id = j.id and q.provider_id = p_viewer
  ) then
    v_authorized := true;
  elsif j.status = 'open' and j.visibility = 'open' and exists (
    select 1
      from public.profiles pr
      join public.provider_profiles pp on pp.user_id = pr.id
     where pr.id = p_viewer
       and pr.is_provider = true
       and pr.verification_status = 'ACTIVE'
       and public.norm_tags(pp.specialties) @> array[public.norm_tag(j.category)]
       and public.norm_tag(j.category) <> ''
  ) then
    v_authorized := true;
  end if;

  if not v_authorized then
    return 'denied';
  end if;

  -- 4. Pós-atendimento / cancelado / em mediação: re-bloqueio permanente (LGPD)
  if j.status in ('completed', 'canceled', 'disputed') then
    return 'closed';
  end if;

  -- 5. Sem orçamento aceito para ESTE profissional: apenas região aproximada
  if j.provider_id is distinct from p_viewer
     or j.status not in ('awaiting_payment', 'scheduled', 'in_progress', 'awaiting_approval') then
    return 'open_quoting';
  end if;

  -- 6. Serviço já iniciado em campo ou aguardando aprovação final: liberado até encerrar
  if j.status in ('in_progress', 'awaiting_approval') then
    return 'service_day';
  end if;

  -- 7. Aguardando pagamento: NUNCA libera endereço exato antes da confirmação do pagamento
  if j.status = 'awaiting_payment' then
    return 'confirmed_future';
  end if;

  -- 8. status = 'scheduled' (orçamento aceito e pago em custódia):
  --    Avalia calendário fixo America/Sao_Paulo (UTC-3, desbloqueio às 00:00 SP do dia agendado).
  if j.scheduled_for is null then
    if j.urgency = 'emergency' then
      return 'service_day';
    end if;
    return 'confirmed_future';
  end if;

  v_today_sp := (coalesce(p_now, now()) at time zone 'America/Sao_Paulo')::date;
  v_sched_sp := (j.scheduled_for at time zone 'America/Sao_Paulo')::date;

  if v_today_sp >= v_sched_sp then
    return 'service_day';
  end if;

  return 'confirmed_future';
end $$;

revoke all on function public._job_privacy_phase(uuid, uuid, timestamptz)
  from public, anon, authenticated;

comment on function public._job_privacy_phase(uuid, uuid, timestamptz) is
  'Uso interno do servidor (SECURITY DEFINER). Máquina de estados da trava Temporal & Spatial Geo-Privacy Lock no fuso America/Sao_Paulo (owner_full | open_quoting | confirmed_future | service_day | closed | denied).';

create or replace function public._can_see_exact_location(
  p_job uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- Zero-Oracle: chamadas diretas como `authenticated` nunca consultam visibilidade de terceiros
  if current_user in ('authenticated', 'anon') and p_viewer is distinct from auth.uid() then
    return false;
  end if;
  return public._job_privacy_phase(p_job, coalesce(p_viewer, auth.uid()), now()) in ('owner_full', 'service_day');
end $$;

revoke all on function public._can_see_exact_location(uuid, uuid) from public, anon;
grant execute on function public._can_see_exact_location(uuid, uuid) to authenticated;

comment on function public._can_see_exact_location(uuid, uuid) is
  'Retorna TRUE somente para o cliente dono, admin ou profissional contratado em service_day (relógio do servidor em America/Sao_Paulo). Usado em policies RLS e RPCs.';

-- -----------------------------------------------------------------------------
-- 5. RPC Canônica de Localização por Visualizador (Contrato C)
-- -----------------------------------------------------------------------------
create or replace function public.get_job_location_for_viewer(p_job uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_viewer       uuid := auth.uid();
  j              public.jobs%rowtype;
  a              public.job_addresses%rowtype;
  g              public.job_geo%rowtype;
  v_client_city  text;
  v_phase        text;
  v_role         text;
  v_unlocked     boolean;
  v_parts        jsonb;
  v_fuzzy        jsonb;
  v_lat          double precision := null;
  v_lng          double precision := null;
  v_radius_m     integer := 0;
  v_sched_sp     date := null;
  v_sched_str    text := null;
  v_unlock_at    text := null;
  v_cep          text := null;
begin
  if v_viewer is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;

  v_phase := public._job_privacy_phase(p_job, v_viewer, now());

  if v_phase = 'denied' then
    return jsonb_build_object(
      'viewer_role', 'none',
      'phase', 'denied',
      'exact_unlocked', false,
      'city', '',
      'uf', '',
      'neighborhood', '',
      'street', null,
      'number', null,
      'complement', null,
      'reference', null,
      'cep', null,
      'lat', null,
      'lng', null,
      'radius_m', 0,
      'scheduled_date', null,
      'unlock_at', null
    );
  end if;

  select * into j from public.jobs where id = p_job;
  select * into a from public.job_addresses where job_id = j.id;
  select * into g from public.job_geo where job_id = j.id;
  select pr.address_city into v_client_city from public.profiles pr where pr.id = j.client_id;

  if j.client_id = v_viewer then
    v_role := 'owner';
  elsif exists (select 1 from public.profiles pr where pr.id = v_viewer and pr.role = 'admin') then
    v_role := 'admin';
  else
    v_role := 'provider';
  end if;

  v_unlocked := v_phase in ('owner_full', 'service_day');
  v_parts := public._parse_job_address_parts(a.address_line, j.address_summary, v_client_city);
  v_cep := coalesce(nullif(btrim(coalesce(a.cep, '')), ''), v_parts ->> 'cep');

  if j.scheduled_for is not null then
    v_sched_sp  := (j.scheduled_for at time zone 'America/Sao_Paulo')::date;
    v_sched_str := to_char(v_sched_sp, 'YYYY-MM-DD');
    v_unlock_at := to_char(
      (v_sched_sp::timestamp at time zone 'America/Sao_Paulo') at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'
    );
  end if;

  if v_unlocked then
    if g.job_id is not null then
      v_lat := g.lat;
      v_lng := g.lng;
    end if;
    v_radius_m := 100;
  elsif v_phase = 'closed' then
    -- Re-bloqueio pós-serviço (LGPD): sem coordenadas nem círculo aproximado
    v_lat := null;
    v_lng := null;
    v_radius_m := 800;
  else
    -- open_quoting ou confirmed_future: centro FUZZY HMAC-SHA256 e raio 500–800 m
    v_fuzzy := public._geo_fuzzy_center(j.id, g.lat, g.lng);
    v_lat := (v_fuzzy ->> 'lat')::double precision;
    v_lng := (v_fuzzy ->> 'lng')::double precision;
    v_radius_m := coalesce((v_fuzzy ->> 'radius_m')::integer, 800);
  end if;

  return jsonb_build_object(
    'viewer_role', v_role,
    'phase', v_phase,
    'exact_unlocked', v_unlocked,
    'city', coalesce(v_parts ->> 'city', ''),
    'uf', coalesce(v_parts ->> 'uf', ''),
    'neighborhood', coalesce(v_parts ->> 'neighborhood', ''),
    'street', case when v_unlocked then v_parts ->> 'street' else null end,
    'number', case when v_unlocked then v_parts ->> 'number' else null end,
    'complement', case when v_unlocked then nullif(btrim(coalesce(a.complement, '')), '') else null end,
    'reference', case when v_unlocked then nullif(btrim(coalesce(a.reference, '')), '') else null end,
    'cep', case when v_unlocked then v_cep else null end,
    'lat', v_lat,
    'lng', v_lng,
    'radius_m', v_radius_m,
    'scheduled_date', v_sched_str,
    'unlock_at', v_unlock_at
  );
end $$;

revoke all on function public.get_job_location_for_viewer(uuid) from public, anon;
grant execute on function public.get_job_location_for_viewer(uuid) to authenticated;

comment on function public.get_job_location_for_viewer(uuid) is
  'RPC canônica (Contrato C) da trava Temporal & Spatial Geo-Privacy Lock. Retorna endereço e coordenadas exatas apenas para owner, admin ou provider contratado em service_day (00:00 America/Sao_Paulo); retorna apenas bairro/cidade/UF + centro fuzzy HMAC (500–800 m) enquanto travado e oculta coordenadas em closed/denied.';

-- -----------------------------------------------------------------------------
-- 6. Blindagem das tabelas `jobs`, `job_addresses` e `job_geo` + Realtime
-- -----------------------------------------------------------------------------
alter table public.jobs
  add column if not exists public_lat     double precision check (public_lat is null or public_lat between -90 and 90),
  add column if not exists public_lng     double precision check (public_lng is null or public_lng between -180 and 180),
  add column if not exists fuzzy_radius_m integer check (fuzzy_radius_m is null or fuzzy_radius_m between 500 and 800);

comment on column public.jobs.public_lat is
  'Latitude do centro aproximado (HMAC-SHA256, deslocado 150–350 m) para listagem/radar público; NULL quando encerrado ou sem geocodificação.';
comment on column public.jobs.public_lng is
  'Longitude do centro aproximado (HMAC-SHA256, deslocado 150–350 m) para listagem/radar público; NULL quando encerrado ou sem geocodificação.';
comment on column public.jobs.fuzzy_radius_m is
  'Raio aproximado em metros (500–800 m) correspondente a public_lat/public_lng; NULL quando encerrado.';

alter table public.job_addresses
  add column if not exists cep text;

grant select (public_lat, public_lng, fuzzy_radius_m) on public.jobs to authenticated;
grant insert (address_cep) on public.jobs to authenticated;
grant select (cep), insert (cep), update (cep) on public.job_addresses to authenticated;

-- Triggers BEFORE/AFTER em `public.jobs`, `public.job_geo` e `public.job_addresses`:
-- garantem que coordenadas exatas e CEP jamais fiquem persistidos ou transmitidos
-- via WAL (`supabase_realtime`) na tabela `public.jobs`.
create or replace function public._trg_jobs_geo_privacy_before()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_suffix  text;
  v_client_city text;
  v_addr_line   text;
  v_fuzzy       jsonb;
  v_existing_g  public.job_geo%rowtype;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  v_key_suffix := replace(new.id::text, '-', '');

  -- 1. Intercepta coordenadas exatas enviadas em `jobs` e agenda gravação em `job_geo`
  if new.latitude is not null and new.longitude is not null then
    if new.latitude between -90.0 and 90.0 and new.longitude between -180.0 and 180.0 then
      perform set_config(
        'app.pending_job_geo_' || v_key_suffix,
        new.latitude::text || ',' || new.longitude::text,
        true
      );
      if new.status in ('completed', 'canceled', 'disputed') then
        new.public_lat := null;
        new.public_lng := null;
        new.fuzzy_radius_m := null;
      else
        v_fuzzy := public._geo_fuzzy_center(new.id, new.latitude, new.longitude);
        new.public_lat := (v_fuzzy ->> 'lat')::double precision;
        new.public_lng := (v_fuzzy ->> 'lng')::double precision;
        new.fuzzy_radius_m := (v_fuzzy ->> 'radius_m')::integer;
      end if;
    end if;
    new.latitude := null;
    new.longitude := null;
  else
    new.latitude := null;
    new.longitude := null;
    if new.status in ('completed', 'canceled', 'disputed') or new.client_id is null then
      new.public_lat := null;
      new.public_lng := null;
      new.fuzzy_radius_m := null;
    elsif tg_op = 'UPDATE' and new.public_lat is null then
      select * into v_existing_g from public.job_geo where job_id = new.id;
      if found then
        v_fuzzy := public._geo_fuzzy_center(new.id, v_existing_g.lat, v_existing_g.lng);
        new.public_lat := (v_fuzzy ->> 'lat')::double precision;
        new.public_lng := (v_fuzzy ->> 'lng')::double precision;
        new.fuzzy_radius_m := (v_fuzzy ->> 'radius_m')::integer;
      end if;
    end if;
  end if;

  -- 2. Intercepta CEP enviado em `jobs` e move para `job_addresses.cep`
  if new.address_cep is not null and btrim(new.address_cep) <> '' then
    perform set_config('app.pending_job_cep_' || v_key_suffix, btrim(new.address_cep), true);
  end if;
  new.address_cep := null;

  -- 3. Sanitiza `address_summary` para conter apenas Bairro + Cidade/UF (zero rua/número/apto)
  if new.address_summary is not null then
    if new.client_id is not null then
      select pr.address_city into v_client_city from public.profiles pr where pr.id = new.client_id;
    end if;
    if tg_op = 'UPDATE' then
      select ja.address_line into v_addr_line from public.job_addresses ja where ja.job_id = new.id;
    end if;
    new.address_summary := public._parse_job_address_parts(v_addr_line, new.address_summary, v_client_city) ->> 'safe_summary';
  end if;

  return new;
end $$;

revoke all on function public._trg_jobs_geo_privacy_before() from public, anon, authenticated;

create or replace function public._trg_jobs_geo_privacy_after()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_suffix text := replace(new.id::text, '-', '');
  v_geo_raw    text;
  v_cep_raw    text;
  v_parts      text[];
  v_lat        double precision;
  v_lng        double precision;
  v_existing_g public.job_geo%rowtype;
begin
  -- 1. Persiste coordenada exata pendente em `public.job_geo` respeitando precedência `client_pin > client > geocode`
  v_geo_raw := nullif(current_setting('app.pending_job_geo_' || v_key_suffix, true), '');
  if v_geo_raw is not null then
    perform set_config('app.pending_job_geo_' || v_key_suffix, '', true);
    v_parts := string_to_array(v_geo_raw, ',');
    if array_length(v_parts, 1) = 2 then
      v_lat := v_parts[1]::double precision;
      v_lng := v_parts[2]::double precision;
      select * into v_existing_g from public.job_geo where job_id = new.id;
      if not found or v_existing_g.source <> 'client_pin' then
        insert into public.job_geo (job_id, lat, lng, precision_level, source, display_name, resolved_at)
        values (new.id, v_lat, v_lng, 'house', 'client', 'Coordenada informada pelo cliente', now())
        on conflict (job_id) do update
          set lat = excluded.lat,
              lng = excluded.lng,
              precision_level = 'house',
              source = 'client',
              display_name = excluded.display_name,
              resolved_at = now();
      end if;
    end if;
  end if;

  -- 2. Persiste CEP pendente em `job_addresses` se a linha já existir
  v_cep_raw := nullif(current_setting('app.pending_job_cep_' || v_key_suffix, true), '');
  if v_cep_raw is not null and exists (select 1 from public.job_addresses where job_id = new.id) then
    update public.job_addresses
       set cep = coalesce(cep, v_cep_raw)
     where job_id = new.id;
    perform set_config('app.pending_job_cep_' || v_key_suffix, '', true);
  end if;

  -- 3. Ao encerrar o serviço (completed/canceled/disputed), remove coordenadas exatas de mensagens de localização no chat
  if tg_op = 'UPDATE'
     and new.status in ('completed', 'canceled', 'disputed')
     and old.status is distinct from new.status then
    update public.messages
       set meta = case when meta is not null then meta - 'lat' - 'lng' - 'latitude' - 'longitude' - 'address' else null end,
           body = case when kind = 'location' then 'Localização encerrada após o término do atendimento.' else body end
     where job_id = new.id
       and kind = 'location';
  end if;

  -- 4. Anonimização LGPD (`purge_account` zera `client_id`): expurga também `job_geo`
  if tg_op = 'UPDATE' and old.client_id is not null and new.client_id is null then
    delete from public.job_geo where job_id = new.id;
  end if;

  return new;
end $$;

revoke all on function public._trg_jobs_geo_privacy_after() from public, anon, authenticated;

create or replace function public._trg_job_geo_sync_public_fuzzy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fuzzy jsonb;
begin
  v_fuzzy := public._geo_fuzzy_center(new.job_id, new.lat, new.lng);
  update public.jobs
     set public_lat = (v_fuzzy ->> 'lat')::double precision,
         public_lng = (v_fuzzy ->> 'lng')::double precision,
         fuzzy_radius_m = (v_fuzzy ->> 'radius_m')::integer
   where id = new.job_id
     and status not in ('completed', 'canceled', 'disputed')
     and client_id is not null
     and (
       public_lat is distinct from (v_fuzzy ->> 'lat')::double precision
       or public_lng is distinct from (v_fuzzy ->> 'lng')::double precision
       or fuzzy_radius_m is distinct from (v_fuzzy ->> 'radius_m')::integer
     );
  return new;
end $$;

revoke all on function public._trg_job_geo_sync_public_fuzzy() from public, anon, authenticated;

create or replace function public._trg_job_addresses_sync_cep()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_suffix text := replace(new.job_id::text, '-', '');
  v_cep_raw    text;
begin
  if new.cep is null or btrim(new.cep) = '' then
    v_cep_raw := nullif(current_setting('app.pending_job_cep_' || v_key_suffix, true), '');
    if v_cep_raw is not null then
      new.cep := v_cep_raw;
      perform set_config('app.pending_job_cep_' || v_key_suffix, '', true);
    end if;
  end if;
  return new;
end $$;

revoke all on function public._trg_job_addresses_sync_cep() from public, anon, authenticated;

-- Prefixo `aa_` garante execução ANTES de `jobs_notify_area_providers` (ordem alfabética do PostgreSQL)
drop trigger if exists aa_jobs_geo_privacy_before on public.jobs;
create trigger aa_jobs_geo_privacy_before
  before insert or update on public.jobs
  for each row execute function public._trg_jobs_geo_privacy_before();

drop trigger if exists aa_jobs_geo_privacy_after on public.jobs;
create trigger aa_jobs_geo_privacy_after
  after insert or update on public.jobs
  for each row execute function public._trg_jobs_geo_privacy_after();

drop trigger if exists aa_job_geo_sync_public_fuzzy on public.job_geo;
create trigger aa_job_geo_sync_public_fuzzy
  after insert or update on public.job_geo
  for each row execute function public._trg_job_geo_sync_public_fuzzy();

drop trigger if exists aa_job_addresses_sync_cep on public.job_addresses;
create trigger aa_job_addresses_sync_cep
  before insert or update on public.job_addresses
  for each row execute function public._trg_job_addresses_sync_cep();

-- Backfill idempotente dos jobs já existentes no banco:
-- 1) Migra `jobs.latitude/longitude` legados para `public.job_geo` (sem sobrescrever `client_pin`)
insert into public.job_geo (job_id, lat, lng, precision_level, source, display_name, resolved_at)
select j.id, j.latitude, j.longitude, 'house', 'client', 'Coordenada migrada de jobs', coalesce(j.created_at, now())
  from public.jobs j
 where j.latitude is not null
   and j.longitude is not null
   and j.latitude between -90.0 and 90.0
   and j.longitude between -180.0 and 180.0
   and j.client_id is not null
on conflict (job_id) do update
  set lat = case when public.job_geo.source = 'client_pin' then public.job_geo.lat else excluded.lat end,
      lng = case when public.job_geo.source = 'client_pin' then public.job_geo.lng else excluded.lng end,
      precision_level = case when public.job_geo.source = 'client_pin' then public.job_geo.precision_level else 'house' end,
      source = case when public.job_geo.source = 'client_pin' then public.job_geo.source else 'client' end;

-- 2) Migra `jobs.address_cep` legado para `public.job_addresses.cep`
update public.job_addresses ja
   set cep = coalesce(ja.cep, nullif(btrim(j.address_cep), ''))
  from public.jobs j
 where ja.job_id = j.id
   and j.address_cep is not null
   and btrim(j.address_cep) <> '';

-- 3) Limpa coordenadas exatas/CEP de `public.jobs`, sanitiza `address_summary` e popula `public_lat/lng`
update public.jobs j
   set latitude = null,
       longitude = null,
       address_cep = null,
       address_summary = case
         when j.address_summary is null then null
         else public._parse_job_address_parts(
           (select ja.address_line from public.job_addresses ja where ja.job_id = j.id),
           j.address_summary,
           (select pr.address_city from public.profiles pr where pr.id = j.client_id)
         ) ->> 'safe_summary'
       end,
       public_lat = case
         when j.status in ('completed', 'canceled', 'disputed') or j.client_id is null then null
         else (public._geo_fuzzy_center(j.id, g.lat, g.lng) ->> 'lat')::double precision
       end,
       public_lng = case
         when j.status in ('completed', 'canceled', 'disputed') or j.client_id is null then null
         else (public._geo_fuzzy_center(j.id, g.lat, g.lng) ->> 'lng')::double precision
       end,
       fuzzy_radius_m = case
         when j.status in ('completed', 'canceled', 'disputed') or j.client_id is null or g.job_id is null then null
         else (public._geo_fuzzy_center(j.id, g.lat, g.lng) ->> 'radius_m')::integer
       end
  from (select id from public.jobs) all_j
  left join public.job_geo g on g.job_id = all_j.id
 where j.id = all_j.id;

-- Policies RLS de `job_addresses` e `job_geo`: leitura estritamente via `_can_see_exact_location`
drop policy if exists job_addresses_select on public.job_addresses;
create policy job_addresses_select on public.job_addresses
  for select to authenticated
  using (public._can_see_exact_location(job_id, auth.uid()));

drop policy if exists job_geo_select on public.job_geo;
create policy job_geo_select on public.job_geo
  for select to authenticated
  using (public._can_see_exact_location(job_id, auth.uid()));

-- -----------------------------------------------------------------------------
-- 7. Reescrita das RPCs, Views e Guards que tocam endereço / coordenadas
-- -----------------------------------------------------------------------------

-- 7.1 `_job_destination(j)` INTERNO (usado pelo geofence server-side < 100 m em `start_job`):
--     lê exclusivamente de `public.job_geo`, sem depender de `jobs.latitude`.
create or replace function public._job_destination(j public.jobs)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  g public.job_geo%rowtype;
begin
  select * into g from public.job_geo where job_id = j.id;
  if not found then
    return null;
  end if;

  if g.source in ('client_pin', 'client') then
    return jsonb_build_object(
      'lat', g.lat,
      'lng', g.lng,
      'precision', 'exact',
      'radius_m', 100,
      'source', g.source
    );
  end if;

  return jsonb_build_object(
    'lat', g.lat,
    'lng', g.lng,
    'precision', g.precision_level,
    'radius_m', case g.precision_level when 'house' then 100 when 'street' then 250 else 0 end,
    'source', g.source
  );
end $$;

revoke all on function public._job_destination(public.jobs) from public, anon, authenticated;

comment on function public._job_destination(public.jobs) is
  'Uso exclusivo interno do servidor (ex.: geofence Haversine de start_job). Retorna o ponto exato armazenado em public.job_geo com precedência client_pin > client > geocode.';

-- 7.2 `job_destination(p_job)` PÚBLICO (autenticado): passa pelo gate temporal/espacial!
create or replace function public.job_destination(p_job uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  j       public.jobs%rowtype;
  g       public.job_geo%rowtype;
  v_phase text;
  v_dest  jsonb;
  v_fuzzy jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;

  v_phase := public._job_privacy_phase(p_job, auth.uid(), now());
  if v_phase in ('denied', 'closed') then
    return null;
  end if;

  select * into j from public.jobs where id = p_job;
  if not found then
    return null;
  end if;

  if v_phase in ('owner_full', 'service_day') then
    v_dest := public._job_destination(j);
    if v_dest is null then
      return null;
    end if;
    return v_dest || jsonb_build_object('exact_unlocked', true);
  end if;

  -- Profissional em fase travada (`open_quoting` / `confirmed_future`):
  -- devolve APENAS centro fuzzy HMAC-SHA256 e raio 500–800 m, NUNCA o ponto exato.
  select * into g from public.job_geo where job_id = j.id;
  if not found then
    return null;
  end if;

  v_fuzzy := public._geo_fuzzy_center(j.id, g.lat, g.lng);
  return jsonb_build_object(
    'lat', (v_fuzzy ->> 'lat')::double precision,
    'lng', (v_fuzzy ->> 'lng')::double precision,
    'precision', 'approximate',
    'radius_m', coalesce((v_fuzzy ->> 'radius_m')::integer, 800),
    'source', 'fuzzy_hmac',
    'exact_unlocked', false
  );
end $$;

revoke all on function public.job_destination(uuid) from public, anon;
grant execute on function public.job_destination(uuid) to authenticated;

comment on function public.job_destination(uuid) is
  'Destino do atendimento filtrado pela trava Geo-Privacy: ponto exato apenas para owner/admin ou provider contratado em service_day; centro aproximado HMAC enquanto travado; NULL em closed/denied.';

-- 7.3 `provider_job_dossier(p_job)`: oculta rua/número/complemento/referência fora de `service_day`
create or replace function public.provider_job_dossier(p_job uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  j          public.jobs%rowtype;
  pay        public.payments%rowtype;
  a          public.job_addresses%rowtype;
  c          public.profiles%rowtype;
  r          public.reviews%rowtype;
  v_review   jsonb;
  v_unlocked boolean;
  v_summary  text;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;

  select * into j from public.jobs where id = p_job and provider_id = auth.uid();
  if not found then
    return null;
  end if;

  select * into pay from public.payments where job_id = j.id;
  select * into a from public.job_addresses where job_id = j.id;
  select * into c from public.profiles where id = j.client_id;
  select * into r
    from public.reviews
   where job_id = j.id
     and reviewee_id = j.provider_id
     and reviewer_id is not distinct from j.client_id;

  if found then
    v_review := case
      when r.revealed_at is null then jsonb_build_object('state', 'hidden')
      else jsonb_build_object(
        'state', 'revealed',
        'rating', r.rating,
        'tags', to_jsonb(r.tags),
        'comment', r.comment,
        'photo_paths', to_jsonb(r.photo_paths),
        'reply', r.reply,
        'created_at', r.created_at
      )
    end;
  end if;

  v_unlocked := public._can_see_exact_location(j.id, auth.uid());
  v_summary := public._parse_job_address_parts(a.address_line, j.address_summary, c.address_city) ->> 'safe_summary';

  return jsonb_build_object(
    'job_id', j.id,
    'code', '#DSP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'status', j.status,
    'payment_status', j.payment_status,
    'title', j.title,
    'description', j.description,
    'category', j.category,
    'exact_unlocked', v_unlocked,
    'address_line', case when v_unlocked then a.address_line else null end,
    'complement', case when v_unlocked then a.complement else null end,
    'reference', case when v_unlocked then a.reference else null end,
    'address_summary', coalesce(v_summary, j.address_summary),
    'location', public.get_job_location_for_viewer(j.id),
    'scheduled_for', j.scheduled_for,
    'started_at', j.started_at,
    'started_simulated', j.start_simulated,
    'finished_at', coalesce(j.approved_at, j.finished_at),
    'gross', coalesce(pay.amount, j.agreed_price, 0),
    'fee', coalesce(pay.fee_amount, 0),
    'fee_pct', coalesce(pay.fee_pct, 0),
    'net', coalesce(pay.net_amount, 0),
    'client', jsonb_build_object(
      'id', c.id,
      'name', public.safe_name(c.full_name, 'Cliente'),
      'avatar_url', c.avatar_url
    ),
    'report', j.provider_report,
    'complementary_notes', j.complementary_notes,
    'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'evidence', coalesce((
      select jsonb_agg(
        jsonb_build_object('slot', e.slot, 'path', e.path)
        order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot)
      )
      from public.job_evidence e
      where e.job_id = j.id
    ), '[]'::jsonb),
    'review', v_review
  );
end $$;

revoke all on function public.provider_job_dossier(uuid) from public, anon;
grant execute on function public.provider_job_dossier(uuid) to authenticated;

comment on function public.provider_job_dossier(uuid) is
  'Dossiê do serviço para o profissional contratado, protegido pela trava Geo-Privacy: address_line/complement/reference só são retornados durante service_day (NULL antes da data agendada e após encerramento).';

-- 7.4 `client_job_dossier(p_job)`: cliente dono continua vendo SEMPRE endereço e mapa exatos (`job_geo`)
create or replace function public.client_job_dossier(p_job uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  j      public.jobs%rowtype;
  pay    public.payments%rowtype;
  r      public.reviews%rowtype;
  a      public.job_addresses%rowtype;
  g      public.job_geo%rowtype;
  v_my   jsonb;
  v_prov jsonb;
  v_disp jsonb;
  v_lat  double precision;
  v_lng  double precision;
  v_prec text;
  v_src  text;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;

  select * into j from public.jobs where id = p_job and client_id = auth.uid();
  if not found then
    return null;
  end if;

  select * into pay from public.payments where job_id = j.id;
  select * into a from public.job_addresses where job_id = j.id;
  select * into g from public.job_geo where job_id = j.id;

  if g.job_id is not null and g.source in ('client_pin', 'client') then
    v_lat := g.lat;
    v_lng := g.lng;
    v_prec := 'exact';
    v_src := g.source;
  elsif g.job_id is not null then
    v_lat := g.lat;
    v_lng := g.lng;
    v_prec := g.precision_level;
    v_src := g.source;
  end if;

  select * into r
    from public.reviews
   where job_id = j.id
     and reviewer_id = j.client_id
     and reviewee_id = j.provider_id;

  if found then
    v_my := jsonb_build_object(
      'rating', r.rating,
      'tags', to_jsonb(r.tags),
      'comment', r.comment,
      'created_at', r.created_at
    );
  end if;

  if j.provider_id is not null then
    select jsonb_build_object(
      'id', p.id,
      'name', public.safe_name(p.full_name, 'Profissional'),
      'avatar_url', p.avatar_url,
      'title', coalesce(pp.specialties[1], pp.headline),
      'rating_avg', pp.rating_avg,
      'rating_count', pp.rating_count
    )
    into v_prov
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
    where p.id = j.provider_id;
  end if;

  select jsonb_build_object(
    'opened_by', case when t.user_id = j.client_id then 'client' else 'provider' end,
    'reason', t.reason,
    'description', t.description,
    'status', t.status,
    'opened_at', t.created_at,
    'resolution', t.resolution
  )
  into v_disp
  from public.support_tickets t
  where t.job_id = j.id
  order by t.created_at
  limit 1;

  return jsonb_build_object(
    'job_id', j.id,
    'code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'title', j.title,
    'description', j.description,
    'category', j.category,
    'status', j.status,
    'urgency', j.urgency,
    'created_at', j.created_at,
    'scheduled_for', j.scheduled_for,
    'started_at', j.started_at,
    'finished_at', coalesce(j.approved_at, j.finished_at),
    'address_summary', j.address_summary,
    'address_line', a.address_line,
    'complement', a.complement,
    'reference', a.reference,
    'cep', a.cep,
    'latitude', v_lat,
    'longitude', v_lng,
    'geo_precision', v_prec,
    'geo_source', v_src,
    'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'amount', coalesce(pay.amount, j.agreed_price, 0),
    'payment_status', j.payment_status,
    'canceled_at', j.canceled_at,
    'cancel_reason', j.cancel_reason,
    'dispute', v_disp,
    'provider', v_prov,
    'report', j.provider_report,
    'complementary_notes', j.complementary_notes,
    'evidence', coalesce((
      select jsonb_agg(
        jsonb_build_object('slot', e.slot, 'path', e.path)
        order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot)
      )
      from public.job_evidence e
      where e.job_id = j.id
    ), '[]'::jsonb),
    'my_review', v_my
  );
end $$;

revoke all on function public.client_job_dossier(uuid) from public, anon;
grant execute on function public.client_job_dossier(uuid) to authenticated;

comment on function public.client_job_dossier(uuid) is
  'Dossiê completo do pedido exclusivo para o cliente titular (owner_full), lendo coordenadas exatas de public.job_geo e endereço completo de public.job_addresses em qualquer fase.';

-- 7.5 `is_job_portfolio_eligible` e `provider_full_service_history`:
--     corrige referências de colunas (`m.current_phase`, `pay.amount`, `j.warranty_expires_at`)
--     e garante re-bloqueio LGPD permanente (apenas Bairro + Cidade/UF em `city_and_state`).
create or replace function public.is_job_portfolio_eligible(p_job uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.jobs j
      left join public.payments pay on pay.job_id = j.id
     where j.id = p_job
       and j.status = 'completed'
       and coalesce(pay.status, 'released') = 'released'
       and coalesce(j.escrow_status, 'settled') in ('settled', 'released', 'SETTLED', 'RELEASED_TO_MATURATION')
       and not exists (
         select 1
           from public.job_mediations m
          where m.job_id = j.id
            and m.current_phase not in ('PHASE_5_SETTLED_AND_CERTIFIED')
       )
  );
$$;

revoke all on function public.is_job_portfolio_eligible(uuid) from public, anon;
grant execute on function public.is_job_portfolio_eligible(uuid) to authenticated;

comment on function public.is_job_portfolio_eligible(uuid) is
  'Verifica se um atendimento concluído está liquidado e sem mediação aberta para exibição no portfólio público.';

create or replace function public.provider_full_service_history()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
               'city_and_state', coalesce(
                 public._sanitize_address_summary(j.address_summary, cl.address_city),
                 'Local Verificado'
               ),
               'completed_at', coalesce(j.approved_at, j.finished_at, j.canceled_at, j.created_at),
               'service_value', coalesce(pay.net_amount, j.agreed_price, 0),
               'gross_amount', coalesce(pay.amount, j.agreed_price, 0),
               'materials_amount', coalesce(j.materials_amount, 0),
               'platform_fee_amount', coalesce(pay.fee_amount, 0),
               'lifecycle_stage', case
                 when j.status = 'canceled' then 'canceled'
                 when j.status = 'disputed' or exists (
                   select 1
                     from public.job_mediations m
                    where m.job_id = j.id
                      and m.current_phase not in ('PHASE_5_SETTLED_AND_CERTIFIED')
                 ) then 'in_mediation'
                 when j.status = 'completed' and public.is_job_portfolio_eligible(j.id) then 'settled_and_paid'
                 else 'under_protection'
               end,
               'is_paid_100_percent', (j.status = 'completed' and public.is_job_portfolio_eligible(j.id)),
               'protection_ends_at', coalesce(j.warranty_expires_at, pay.released_at),
               'canceled_by_role', case
                 when j.status <> 'canceled' then null
                 when j.canceled_by = j.client_id then 'client'
                 when j.canceled_by = j.provider_id then 'provider'
                 else 'system'
               end,
               'cancel_reason', j.cancel_reason,
               'is_pinned', exists (
                 select 1 from public.provider_case_pins k
                  where k.job_id = j.id and k.provider_id = v_uid
               ),
               'is_reviewed_by_client', (r.id is not null and r.revealed_at is not null),
               'client_rating', r.rating,
               'client_review_comment', r.comment,
               'client_praise_tags', coalesce(to_jsonb(r.tags), '[]'::jsonb),
               'client_reviewed_at', r.revealed_at,
               'client_display_name', public._short_name(cl.full_name),
               'photos', coalesce((
                 select jsonb_agg(p.path order by p.ord)
                   from (
                     select e.path, array_position(array['overview', 'detail', 'angle', 'clean'], e.slot) as ord
                       from public.job_evidence e
                      where e.job_id = j.id and e.slot in ('overview', 'detail', 'angle', 'clean')
                     union all
                     select unnest(coalesce(j.photo_paths, '{}'::text[])) as path, 100 as ord
                   ) p
                  where p.path is not null and btrim(p.path) <> ''
               ), '[]'::jsonb)
             ) as item
        from public.jobs j
        left join public.payments pay on pay.job_id = j.id
        left join public.reviews r on r.job_id = j.id
                                  and r.reviewee_id = j.provider_id
                                  and r.reviewer_id is not distinct from j.client_id
        left join public.profiles cl on cl.id = j.client_id
       where j.provider_id = v_uid
         and j.status in ('completed', 'disputed', 'canceled')
    ) sub;

  return v_out;
end $$;

revoke all on function public.provider_full_service_history() from public, anon;
grant execute on function public.provider_full_service_history() to authenticated;

comment on function public.provider_full_service_history() is
  'Histórico de serviços encerrados do profissional autenticado com re-bloqueio LGPD permanente (expõe apenas Bairro e Cidade/UF em city_and_state, jamais rua/número/CEP/coordenadas).';

-- 7.6 `jobs_notify_area_providers`: usa `public.job_geo` server-side para filtro espacial (quando presente)
--     e garante texto de notificação 100% livre de rua/número/coordenadas.
create or replace function public.jobs_notify_area_providers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  g public.job_geo%rowtype;
begin
  if new.visibility <> 'open'
     or new.urgency = 'emergency'
     or new.status <> 'open'
     or public.norm_tag(new.category) = '' then
    return new;
  end if;

  -- `aa_jobs_geo_privacy_after` já executou antes deste trigger e populou `job_geo`
  select * into g from public.job_geo where job_id = new.id;

  for r in
    select pp.user_id
      from public.provider_profiles pp
      join public.profiles p on p.id = pp.user_id
     where p.is_provider
       and p.verification_status = 'ACTIVE'
       and coalesce(pp.accepting_jobs, true)
       and pp.user_id <> new.client_id
       and public.norm_tags(pp.specialties) @> array[public.norm_tag(new.category)]
       and (
         g.job_id is null
         or p.latitude is null
         or p.longitude is null
         or pp.service_radius_km is null
         or public.haversine_m(g.lat, g.lng, p.latitude, p.longitude) <= (pp.service_radius_km::double precision * 1000.0)
       )
     limit 200
  loop
    perform public.notify_user(
      r.user_id,
      'new_area_job',
      'Novo pedido de ' || new.category,
      'Um cliente da sua região precisa de ' || new.category || ': "' || left(coalesce(new.title, ''), 60) || '". Envie seu orçamento.',
      new.id
    );
  end loop;

  return new;
end $$;

revoke all on function public.jobs_notify_area_providers() from public, anon, authenticated;

-- 7.7 `job_client_cards`, `chat_counterpart` e `_messages_guard`:
--     sanitiza `address_city` contra logradouro acidental e impede envio de localização exata fora de `service_day`.
create or replace view public.job_client_cards as
  select j.id as job_id,
         j.client_id,
         case
           when j.client_id = auth.uid() or j.provider_id = auth.uid()
             then public.safe_name(p.full_name, 'Cliente')
           else public.safe_name(split_part(p.full_name, ' ', 1), 'Cliente')
         end as full_name,
         p.avatar_url,
         public._sanitize_address_summary(p.address_city) as address_city
    from public.jobs j
    join public.profiles p on p.id = j.client_id
   where j.client_id = auth.uid()
      or j.provider_id = auth.uid()
      or public.is_admin()
      or public.is_invited(j.id)
      or public.has_quoted_job(j.id)
      or (
        j.status = 'open'
        and j.visibility = 'open'
        and public.is_active_provider()
        and public.provider_matches_category(j.category)
      );

revoke all on public.job_client_cards from anon;
grant select on public.job_client_cards to authenticated;

create or replace function public.chat_counterpart(p_job uuid, p_provider uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  j public.jobs%rowtype;
  v jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not public.can_chat(p_job, p_provider) then
    return null;
  end if;

  select * into j from public.jobs where id = p_job;
  if auth.uid() = p_provider then
    select jsonb_build_object(
      'id', c.id,
      'role', 'client',
      'name', public.safe_name(
        case when j.provider_id = auth.uid() then c.full_name else split_part(c.full_name, ' ', 1) end,
        'Cliente'
      ),
      'avatar_url', c.avatar_url,
      'subtitle', public._sanitize_address_summary(c.address_city)
    )
    into v
    from public.profiles c
    where c.id = j.client_id;
  else
    select jsonb_build_object(
      'id', p.id,
      'role', 'provider',
      'name', public.safe_name(p.full_name, 'Profissional'),
      'avatar_url', p.avatar_url,
      'subtitle', coalesce(pp.specialties[1], pp.headline)
    )
    into v
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
    where p.id = p_provider;
  end if;
  return v;
end $$;

revoke all on function public.chat_counterpart(uuid, uuid) from public, anon;
grant execute on function public.chat_counterpart(uuid, uuid) to authenticated;

create or replace function public._messages_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  j public.jobs%rowtype;
begin
  select * into j from public.jobs where id = new.job_id;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  if j.status in ('completed', 'canceled') then
    raise exception 'CHAT_ARCHIVED: esta conversa foi arquivada.' using errcode = 'P0001';
  end if;

  -- Impede vazamento prematuro de pino GPS no chat antes do dia agendado do serviço
  if new.kind = 'location'
     and new.sender_id = j.client_id
     and public._job_privacy_phase(new.job_id, new.provider_id, now()) <> 'service_day' then
    raise exception 'LOCATION_LOCKED_UNTIL_SERVICE_DAY: Por segurança residencial, a localização exata é liberada automaticamente no dia agendado do serviço.' using errcode = 'P0001';
  end if;

  return new;
end $$;

revoke all on function public._messages_guard() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 8. Notificação diária idempotente às 00:00 America/Sao_Paulo ("Endereço liberado hoje")
-- -----------------------------------------------------------------------------
create unique index if not exists idx_notifications_address_unlocked_once
  on public.notifications (user_id, job_id, kind)
  where kind = 'address_unlocked_today' and job_id is not null;

create or replace function public.notify_service_day_address_unlocked(
  p_now timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_sp date := (coalesce(p_now, now()) at time zone 'America/Sao_Paulo')::date;
  v_count    integer := 0;
  r          record;
begin
  for r in
    select j.id, j.provider_id, j.title
      from public.jobs j
     where j.status = 'scheduled'
       and j.provider_id is not null
       and j.scheduled_for is not null
       and (j.scheduled_for at time zone 'America/Sao_Paulo')::date = v_today_sp
       and not exists (
         select 1
           from public.notifications n
          where n.user_id = j.provider_id
            and n.job_id = j.id
            and n.kind = 'address_unlocked_today'
       )
  loop
    insert into public.notifications (user_id, kind, title, body, job_id)
    values (
      r.provider_id,
      'address_unlocked_today',
      'Endereço liberado hoje',
      'O endereço completo e a rota de "' || left(coalesce(r.title, 'seu atendimento'), 60) || '" já estão disponíveis para o atendimento de hoje.',
      r.id
    )
    on conflict (user_id, job_id, kind)
      where kind = 'address_unlocked_today' and job_id is not null
    do nothing;

    v_count := v_count + 1;
  end loop;

  return v_count;
end $$;

revoke all on function public.notify_service_day_address_unlocked(timestamptz)
  from public, anon, authenticated;

comment on function public.notify_service_day_address_unlocked(timestamptz) is
  'Disparo diário idempotente às 00:00 America/Sao_Paulo (03:00 UTC via pg_cron). Avisa o profissional contratado que o endereço do atendimento de hoje foi liberado, sem incluir rua/número no texto da notificação.';

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    begin
      perform cron.unschedule('geo-privacy-unlock-00sp');
    exception when others then
      null;
    end;
    -- 03:00 UTC = 00:00 America/Sao_Paulo (UTC-3 fixo)
    perform cron.schedule(
      'geo-privacy-unlock-00sp',
      '0 3 * * *',
      'select public.notify_service_day_address_unlocked();'
    );
  end if;
end $$;

commit;

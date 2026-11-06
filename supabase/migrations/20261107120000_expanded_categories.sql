-- =============================================================================
-- DESPERRENGUE — Mais categorias de serviço (33) e sinônimos de profissões.
--
-- O catálogo de categorias vive no app (core/models/marketplace_models.dart: kCategories) e o
-- banco só precisa conhecer os SINÔNIMOS para casar "Eletricista" com "Elétrica", "Jardineiro"
-- com "Jardinagem" etc. `norm_tag` é o espelho de `kTagAliases`
-- (app/lib/core/utils/tag_normalizer.dart); o teste app/test/tag_alias_parity_test.dart compara
-- as duas listas e falha se divergirem.
--
-- ATENÇÃO: o índice GIN `provider_profiles_specialty_slugs_gin` é construído sobre
-- `norm_tags(specialties)`. Trocar o corpo de `norm_tag` muda o resultado dessa expressão, então o
-- índice é RECONSTRUÍDO ao final (REINDEX).
-- =============================================================================
begin;

create or replace function public.norm_tag(p_tag text)
returns text language plpgsql immutable parallel safe as $$
declare n text;
begin
  if p_tag is null then return ''; end if;
  n := lower(btrim(p_tag));
  n := translate(n, 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn');
  n := btrim(regexp_replace(n, '\s+', ' ', 'g'));
  return case
    when n in ('eletricista', 'eletricidade', 'instalacao eletrica', 'instalacoes eletricas') then 'eletrica'
    when n in ('encanamento', 'hidraulica', 'hidraulico', 'bombeiro hidraulico') then 'encanador'
    when n in ('diarista', 'faxina', 'faxineira', 'faxineiro') then 'limpeza'
    when n in ('montador', 'montagem de moveis', 'montador de moveis') then 'montagem'
    when n in ('pintor') then 'pintura'
    when n in ('chaveiros') then 'chaveiro'
    when n in ('alvenaria') then 'pedreiro'
    when n in ('gesseiro', 'drywall') then 'gesso'
    when n in ('marceneiro', 'carpintaria', 'carpinteiro') then 'marcenaria'
    when n in ('ar condicionado', 'arcondicionado', 'climatizacao', 'refrigeracao', 'split') then 'ar-condicionado'
    when n in ('marido de aluguel', 'faz tudo', 'reparos') then 'pequenos reparos'
    when n in ('jardineiro', 'paisagismo', 'paisagista') then 'jardinagem'
    when n in ('dedetizador', 'controle de pragas', 'desinsetizacao') then 'dedetizacao'
    when n in ('vidracaria', 'vidros') then 'vidraceiro'
    when n in ('serralheiro', 'soldador') then 'serralheria'
    when n in ('telhadista', 'telhado', 'calheiro', 'calhas') then 'telhados e calhas'
    when n in ('impermeabilizador') then 'impermeabilizacao'
    when n in ('desentupidor', 'desentupimento') then 'desentupidora'
    when n in ('piscineiro') then 'piscina'
    when n in ('assistencia tecnica', 'conserto de geladeira', 'tecnico de eletrodomesticos') then 'eletrodomesticos'
    when n in ('antenista', 'instalacao de tv') then 'tv e antenas'
    when n in ('cftv', 'alarme', 'alarmes', 'cameras', 'seguranca eletronica') then 'cameras e alarmes'
    when n in ('portao eletronico', 'interfone', 'automacao de portoes') then 'portoes e interfones'
    when n in ('placa solar', 'painel solar', 'fotovoltaica') then 'energia solar'
    when n in ('gas', 'aquecedor', 'instalador de gas') then 'gas e aquecedores'
    when n in ('azulejista', 'ladrilheiro', 'pisos', 'revestimentos') then 'pisos e revestimentos'
    when n in ('cortina', 'persiana') then 'cortinas e persianas'
    when n in ('limpeza de estofados', 'lavagem de sofa', 'tapeceiro') then 'estofados e tapetes'
    when n in ('mudanca', 'frete', 'fretes', 'carreto') then 'mudancas e fretes'
    when n in ('informatica', 'tecnico de informatica', 'wifi', 'redes') then 'informatica e redes'
    when n in ('cuidador', 'cuidadora') then 'cuidador de idosos'
    when n in ('nanny') then 'baba'
    when n in ('pet sitter', 'banho e tosa', 'passeador de caes') then 'pet care'
    else n
  end;
end $$;

reindex index public.provider_profiles_specialty_slugs_gin;

-- 6. client_job_dossier passa a informar a PRECISÃO e a ORIGEM do ponto, e usa a mesma precedência
-- do _job_destination (pino do cliente → coordenadas do pedido → geocodificação). Assim o app sabe
-- quando o ponto é só aproximado (centro da cidade/rua) e oferece "Ajustar o ponto exato".
-- Cliente dono: histórico completo do pedido em QUALQUER estado. Sem taxa/líquido do profissional.
create or replace function public.client_job_dossier(p_job uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype; pay public.payments%rowtype; r public.reviews%rowtype;
        a public.job_addresses%rowtype; g public.job_geo%rowtype;
        v_my jsonb; v_prov jsonb; v_disp jsonb;
        v_lat double precision; v_lng double precision; v_prec text; v_src text;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and client_id = auth.uid();
  if not found then return null; end if;
  select * into pay from public.payments where job_id = j.id;
  select * into a from public.job_addresses where job_id = j.id;
  select * into g from public.job_geo where job_id = j.id;
  if g.job_id is not null and g.source = 'client_pin' then
    v_lat := g.lat; v_lng := g.lng; v_prec := 'exact'; v_src := 'client_pin';
  elsif j.latitude is not null and j.longitude is not null then
    v_lat := j.latitude; v_lng := j.longitude; v_prec := 'exact'; v_src := 'client';
  elsif g.job_id is not null then
    v_lat := g.lat; v_lng := g.lng; v_prec := g.precision_level; v_src := g.source;
  end if;
  select * into r from public.reviews where job_id = j.id and reviewer_id = j.client_id and reviewee_id = j.provider_id;
  if found then
    v_my := jsonb_build_object('rating', r.rating, 'tags', to_jsonb(r.tags), 'comment', r.comment, 'created_at', r.created_at);
  end if;
  if j.provider_id is not null then
    select jsonb_build_object('id', p.id, 'name', public.safe_name(p.full_name, 'Profissional'), 'avatar_url', p.avatar_url,
             'title', coalesce(pp.specialties[1], pp.headline), 'rating_avg', pp.rating_avg, 'rating_count', pp.rating_count)
      into v_prov from public.profiles p left join public.provider_profiles pp on pp.user_id = p.id where p.id = j.provider_id;
  end if;
  -- Contestação mais antiga do serviço (qualquer das partes): quem abriu, motivo e andamento.
  select jsonb_build_object(
           'opened_by', case when t.user_id = j.client_id then 'client' else 'provider' end,
           'reason', t.reason, 'description', t.description, 'status', t.status,
           'opened_at', t.created_at, 'resolution', t.resolution)
    into v_disp
    from public.support_tickets t where t.job_id = j.id order by t.created_at limit 1;
  return jsonb_build_object(
    'job_id', j.id, 'code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'title', j.title, 'description', j.description, 'category', j.category, 'status', j.status,
    'urgency', j.urgency, 'created_at', j.created_at,
    'scheduled_for', j.scheduled_for, 'started_at', j.started_at, 'finished_at', coalesce(j.approved_at, j.finished_at),
    'address_summary', j.address_summary, 'address_line', a.address_line,
    'latitude', v_lat, 'longitude', v_lng, 'geo_precision', v_prec, 'geo_source', v_src,
    'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'amount', coalesce(pay.amount, j.agreed_price, 0), 'payment_status', j.payment_status,
    'canceled_at', j.canceled_at, 'cancel_reason', j.cancel_reason,
    'dispute', v_disp,
    'provider', v_prov, 'report', j.provider_report,
    'evidence', coalesce((select jsonb_agg(jsonb_build_object('slot', e.slot, 'path', e.path)
                          order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot))
                           from public.job_evidence e where e.job_id = j.id), '[]'::jsonb),
    'my_review', v_my);
end $$;
revoke all on function public.client_job_dossier(uuid) from public, anon;
grant execute on function public.client_job_dossier(uuid) to authenticated;

commit;
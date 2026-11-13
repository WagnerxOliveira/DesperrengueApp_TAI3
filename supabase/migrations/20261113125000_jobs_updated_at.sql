-- =============================================================================
-- DESPERRENGUE — Coluna `public.jobs.updated_at` + Trigger Leve `_touch_updated_at`
-- Migration: 20261113125000_jobs_updated_at.sql
--
-- CONTEXTO:
--   Rotinas já publicadas (`complete_job_and_schedule_escrow`, `open_warranty_mediation`,
--   `process_autonomous_escrow_and_mediation_queues`) e `register_forensic_photo`
--   atualizam `public.jobs.updated_at`, coluna que não havia sido criada nas
--   migrations originais de `public.jobs`.
--   Esta migration (ordenada antes de `20261113130000`) adiciona `updated_at` de forma
--   idempotente e mantém-na sincronizada via trigger `BEFORE UPDATE` leve (`SECURITY INVOKER`
--   com `search_path = public`), sem interferir em `jobs_enforce_post_completion_immutability`
--   (que inspeciona apenas `description`, `provider_report` e `photo_paths`).
-- =============================================================================

begin;

alter table public.jobs
  add column if not exists updated_at timestamptz not null default now();

revoke update (updated_at) on public.jobs from public, anon, authenticated;

comment on column public.jobs.updated_at is
  'Carimbo UTC da última atualização da ordem de serviço, mantido automaticamente por trigger BEFORE UPDATE.';

create or replace function public._touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end $$;

revoke all on function public._touch_updated_at() from public, anon;

comment on function public._touch_updated_at() is
  'Trigger BEFORE UPDATE leve (SECURITY INVOKER, search_path fixo) que atualiza new.updated_at em UTC.';

drop trigger if exists jobs_touch_updated_at on public.jobs;
create trigger jobs_touch_updated_at
  before update on public.jobs
  for each row execute function public._touch_updated_at();

commit;

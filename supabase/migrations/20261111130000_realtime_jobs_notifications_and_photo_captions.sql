-- =============================================================================
-- DESPERRENGUE — Migration v2.8.6:
-- 1. Anotações Contextuais de Fotos do Pedido (photo_annotations JSONB:
--    descrição breve do que a foto mostra + sugestão de ação + pino focal x,y)
-- 2. Sincronização Instantânea em Tempo Real de Meus Pedidos (public.jobs e
--    public.job_invites em supabase_realtime + REPLICA IDENTITY FULL)
-- 3. Marcação Atômica e Instantânea de Notificações como Vistas/Lidas
--    (REPLICA IDENTITY FULL em public.notifications + RPC mark_notification_read)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Coluna JSONB de Anotações de Fotos do Pedido (Descrição + Sugestão + Pino)
-- -----------------------------------------------------------------------------
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS photo_annotations JSONB NOT NULL DEFAULT '[]'::jsonb;

GRANT INSERT (photo_annotations), UPDATE (photo_annotations)
  ON public.jobs TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. Publicação Realtime Completa (jobs, job_invites, quotes, notifications)
--    + REPLICA IDENTITY FULL para garantir que filtros .eq('client_id', uid)
--    e .eq('user_id', uid) recebam todos os eventos INSERT e UPDATE sem perda.
-- -----------------------------------------------------------------------------
ALTER TABLE public.jobs REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'jobs'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'job_invites'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.job_invites;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'quotes'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.quotes;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. RPC Transacional para Marcar Notificação (Individual ou Todas) como Vista
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id UUID DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_updated INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;

  IF p_notification_id IS NOT NULL THEN
    UPDATE public.notifications
       SET read_at = COALESCE(read_at, timezone('utc', now()))
     WHERE id = p_notification_id
       AND user_id = v_uid;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
  ELSE
    UPDATE public.notifications
       SET read_at = timezone('utc', now())
     WHERE user_id = v_uid
       AND read_at IS NULL;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
  END IF;

  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_notification_read(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

COMMIT;

-- Produção: desliga o modo de homologação do check-in ("Simular dia/hora e GPS no local").
-- Com a flag em 'false', `start_job(..., p_simulate := true)` volta a respeitar horário e geofence (<100 m).
-- Idempotente: pode rodar várias vezes sem efeito colateral.
insert into public.app_settings (key, value)
values ('checkin_sandbox', 'false')
on conflict (key) do update set value = 'false';

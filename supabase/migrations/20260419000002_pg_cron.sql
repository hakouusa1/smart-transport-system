-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── SETUP INSTRUCTIONS ──────────────────────────────────────────────────────
-- Before running this migration, store your Supabase service_role key in
-- Supabase Dashboard → Settings → Vault → New Secret:
--   Name : supabase_service_role_key
--   Value: <your service_role JWT from Project Settings → API>
--
-- Then expose it via app.settings in the SQL editor:
--   ALTER DATABASE postgres SET app.settings.service_role_key = '<key>';
-- ────────────────────────────────────────────────────────────────────────────

-- Schedule daily maintenance check at 07:00 UTC (08:00 Algeria UTC+1)
SELECT cron.schedule(
  'daily-maintenance-alerts',
  '0 7 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://dqtedpkzuppiotbvkxon.supabase.co/functions/v1/check-maintenance',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body    := '{}'::jsonb
  ) AS request_id;
  $$
);

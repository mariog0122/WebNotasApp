-- ====================================================================
-- MIGRATION: 27_p2_client_observability.sql
-- PURPOSE: Privacy-preserving authenticated client error telemetry.
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.client_error_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  fingerprint text NOT NULL CHECK (fingerprint ~ '^[0-9a-f]{64}$'),
  error_name varchar(80) NOT NULL,
  error_code varchar(80) NOT NULL,
  source varchar(32) NOT NULL CHECK (source IN ('vue', 'window', 'unhandledrejection', 'other')),
  route varchar(256) NOT NULL,
  release varchar(80) NOT NULL DEFAULT 'unknown',
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  received_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_client_error_events_received
  ON public.client_error_events (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_error_events_fingerprint_received
  ON public.client_error_events (fingerprint, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_error_events_school_received
  ON public.client_error_events (school_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_error_events_user_received
  ON public.client_error_events (user_id, received_at DESC);

CREATE OR REPLACE FUNCTION public.prepare_client_error_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'CLIENT_ERROR_AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF (
    SELECT count(*)
    FROM public.client_error_events event
    WHERE event.user_id = v_user_id
      AND event.received_at >= v_now - interval '1 minute'
  ) >= 20 THEN
    RAISE EXCEPTION 'CLIENT_ERROR_RATE_LIMITED' USING ERRCODE = '54000';
  END IF;

  NEW.user_id := auth.uid();
  NEW.school_id := public.get_user_school_id();
  NEW.received_at := v_now;
  IF NEW.occurred_at IS NULL
     OR NEW.occurred_at > v_now + interval '5 minutes'
     OR NEW.occurred_at < v_now - interval '7 days' THEN
    NEW.occurred_at := v_now;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_client_error_event_trigger ON public.client_error_events;
CREATE TRIGGER prepare_client_error_event_trigger
BEFORE INSERT ON public.client_error_events
FOR EACH ROW EXECUTE FUNCTION public.prepare_client_error_event();

ALTER TABLE public.client_error_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_error_events FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS client_error_events_insert ON public.client_error_events;
CREATE POLICY client_error_events_insert
ON public.client_error_events
FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND school_id IS NOT DISTINCT FROM public.get_user_school_id()
);

DROP POLICY IF EXISTS client_error_events_select ON public.client_error_events;
CREATE POLICY client_error_events_select
ON public.client_error_events
FOR SELECT TO authenticated
USING (public.is_platform_admin());

REVOKE ALL ON public.client_error_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.client_error_events TO authenticated;
REVOKE ALL ON FUNCTION public.prepare_client_error_event() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  existing_job bigint;
BEGIN
  SELECT jobid INTO existing_job FROM cron.job WHERE jobname = 'purge-client-error-events';
  IF existing_job IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job);
  END IF;
  PERFORM cron.schedule(
    'purge-client-error-events',
    '17 3 * * *',
    $job$DELETE FROM public.client_error_events WHERE received_at < timezone('utc'::text, now()) - interval '90 days'$job$
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_platform_health()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, storage, cron
AS $$
DECLARE
  v_storage_ok boolean;
  v_cron_ok boolean;
  v_rls_ok boolean;
  v_billing_ok boolean;
  v_client_errors_15m bigint;
  v_client_errors_24h bigint;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'PLATFORM_HEALTH_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) = 3 AND bool_and(NOT b.public)
    INTO v_storage_ok
  FROM storage.buckets b
  WHERE b.id IN ('student-photos', 'profile-photos', 'institution-assets');

  SELECT EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname = 'reconcile-subscription-lifecycle' AND active
  ) INTO v_cron_ok;

  SELECT bool_and(c.relrowsecurity)
    INTO v_rls_ok
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('schools', 'profiles', 'students', 'grades', 'subscriptions', 'payments', 'client_error_events');

  v_billing_ok := to_regprocedure(
    'public.record_manual_payment(uuid,numeric,text,text,timestamptz,text)'
  ) IS NOT NULL;

  SELECT
    count(*) FILTER (WHERE received_at >= timezone('utc'::text, now()) - interval '15 minutes'),
    count(*) FILTER (WHERE received_at >= timezone('utc'::text, now()) - interval '24 hours')
  INTO v_client_errors_15m, v_client_errors_24h
  FROM public.client_error_events;

  RETURN json_build_object(
    'checked_at', timezone('utc'::text, now()),
    'services', json_build_array(
      json_build_object('key', 'database', 'name', 'Base de datos', 'status', 'operational', 'detail', 'Consulta server-side completada'),
      json_build_object('key', 'auth', 'name', 'Autenticación', 'status', CASE WHEN auth.uid() IS NOT NULL THEN 'operational' ELSE 'down' END, 'detail', 'JWT de Platform Admin validado'),
      json_build_object('key', 'storage', 'name', 'Storage privado', 'status', CASE WHEN v_storage_ok THEN 'operational' ELSE 'degraded' END, 'detail', '3 buckets requeridos y privados'),
      json_build_object('key', 'cron', 'name', 'Automatización de suscripciones', 'status', CASE WHEN v_cron_ok THEN 'operational' ELSE 'down' END, 'detail', 'Job horario activo'),
      json_build_object('key', 'billing', 'name', 'Cobro manual', 'status', CASE WHEN v_billing_ok THEN 'operational' ELSE 'down' END, 'detail', 'RPC transaccional disponible'),
      json_build_object('key', 'rls', 'name', 'Aislamiento RLS', 'status', CASE WHEN v_rls_ok THEN 'operational' ELSE 'down' END, 'detail', 'Tablas críticas con RLS habilitado'),
      json_build_object(
        'key', 'telemetry',
        'name', 'Errores del cliente',
        'status', CASE WHEN v_client_errors_15m >= 20 THEN 'down' WHEN v_client_errors_15m > 0 THEN 'degraded' ELSE 'operational' END,
        'detail', format('%s en 15 min / %s en 24 h', v_client_errors_15m, v_client_errors_24h)
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_health() TO authenticated;

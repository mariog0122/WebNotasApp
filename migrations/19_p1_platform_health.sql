-- ====================================================================
-- MIGRATION: 19_p1_platform_health.sql
-- PURPOSE: Server-measured health for the SuperAdmin dashboard.
-- ====================================================================

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
    AND c.relname IN ('schools', 'profiles', 'students', 'grades', 'subscriptions', 'payments');

  v_billing_ok := to_regprocedure(
    'public.record_manual_payment(uuid,numeric,text,text,timestamptz,text)'
  ) IS NOT NULL;

  RETURN json_build_object(
    'checked_at', timezone('utc'::text, now()),
    'services', json_build_array(
      json_build_object('key', 'database', 'name', 'Base de datos', 'status', 'operational', 'detail', 'Consulta server-side completada'),
      json_build_object('key', 'auth', 'name', 'Autenticación', 'status', CASE WHEN auth.uid() IS NOT NULL THEN 'operational' ELSE 'down' END, 'detail', 'JWT de Platform Admin validado'),
      json_build_object('key', 'storage', 'name', 'Storage privado', 'status', CASE WHEN v_storage_ok THEN 'operational' ELSE 'degraded' END, 'detail', '3 buckets requeridos y privados'),
      json_build_object('key', 'cron', 'name', 'Automatización de suscripciones', 'status', CASE WHEN v_cron_ok THEN 'operational' ELSE 'down' END, 'detail', 'Job horario activo'),
      json_build_object('key', 'billing', 'name', 'Cobro manual', 'status', CASE WHEN v_billing_ok THEN 'operational' ELSE 'down' END, 'detail', 'RPC transaccional disponible'),
      json_build_object('key', 'rls', 'name', 'Aislamiento RLS', 'status', CASE WHEN v_rls_ok THEN 'operational' ELSE 'down' END, 'detail', 'Tablas críticas con RLS habilitado')
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_health() TO authenticated;

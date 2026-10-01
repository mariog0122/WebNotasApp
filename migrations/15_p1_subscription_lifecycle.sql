-- ====================================================================
-- MIGRATION: 15_p1_subscription_lifecycle.sql
-- PURPOSE: Automated trial expiry, payment grace and safe suspension.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.reconcile_subscription_lifecycle()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, cron
AS $$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_trial_schools uuid[] := '{}'::uuid[];
  v_overdue_schools uuid[] := '{}'::uuid[];
  v_suspended_schools uuid[] := '{}'::uuid[];
BEGIN
  -- Direct authenticated calls are limited to platform administrators.
  -- pg_cron has no JWT subject and executes as the function owner.
  IF auth.uid() IS NOT NULL AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(array_agg(s.school_id), '{}'::uuid[])
    INTO v_trial_schools
  FROM public.subscriptions s
  WHERE s.status::text = 'trial'
    AND s.trial_ends_at IS NOT NULL
    AND s.trial_ends_at <= v_now;

  UPDATE public.subscriptions
  SET status = 'suspended', updated_at = v_now
  WHERE school_id = ANY(v_trial_schools);

  UPDATE public.schools
  SET status = 'suspended', is_active = false,
      suspended_reason = 'Periodo de prueba finalizado',
      suspended_at = v_now, updated_at = v_now
  WHERE id = ANY(v_trial_schools);

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  )
  SELECT id, 'trial', 'suspended', 'Periodo de prueba finalizado',
         'Acceso suspendido automáticamente; los datos se conservan.', NULL
  FROM public.schools
  WHERE id = ANY(v_trial_schools);

  SELECT COALESCE(array_agg(s.school_id), '{}'::uuid[])
    INTO v_overdue_schools
  FROM public.subscriptions s
  WHERE s.status::text = 'active'
    AND s.next_billing_date IS NOT NULL
    AND s.next_billing_date <= v_now;

  UPDATE public.subscriptions
  SET status = 'grace_period',
      grace_period_until = v_now + interval '7 days',
      updated_at = v_now
  WHERE school_id = ANY(v_overdue_schools);

  UPDATE public.schools
  SET status = 'grace_period', is_active = true, updated_at = v_now
  WHERE id = ANY(v_overdue_schools);

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  )
  SELECT id, 'active', 'grace_period', 'Pago pendiente',
         'Se habilitó un periodo de gracia automático de 7 días.', NULL
  FROM public.schools
  WHERE id = ANY(v_overdue_schools);

  SELECT COALESCE(array_agg(s.school_id), '{}'::uuid[])
    INTO v_suspended_schools
  FROM public.subscriptions s
  WHERE s.status::text IN ('past_due', 'grace_period')
    AND s.grace_period_until IS NOT NULL
    AND s.grace_period_until <= v_now;

  UPDATE public.subscriptions
  SET status = 'suspended', updated_at = v_now
  WHERE school_id = ANY(v_suspended_schools);

  UPDATE public.schools
  SET status = 'suspended', is_active = false,
      suspended_reason = 'Periodo de gracia finalizado sin pago',
      suspended_at = v_now, updated_at = v_now
  WHERE id = ANY(v_suspended_schools);

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  )
  SELECT id, 'grace_period', 'suspended', 'Pago pendiente',
         'Acceso suspendido automáticamente; los datos se conservan.', NULL
  FROM public.schools
  WHERE id = ANY(v_suspended_schools);

  RETURN json_build_object(
    'success', true,
    'processed_at', v_now,
    'expired_trials', cardinality(v_trial_schools),
    'entered_grace', cardinality(v_overdue_schools),
    'suspended_after_grace', cardinality(v_suspended_schools)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_subscription_lifecycle() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_subscription_lifecycle() TO authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule('reconcile-subscription-lifecycle');
EXCEPTION
  WHEN OTHERS THEN NULL;
END
$$;

SELECT cron.schedule(
  'reconcile-subscription-lifecycle',
  '17 * * * *',
  'select public.reconcile_subscription_lifecycle();'
);

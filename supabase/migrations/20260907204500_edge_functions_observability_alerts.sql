-- Migration: 20260907204500_edge_functions_observability_alerts.sql
-- Purpose: Create protected telemetry table and automatic burst alerting for Edge Function 500 errors.
-- Resolves: Sprint 6 - Acción 6.2 (Monitoreo y alertas automáticas en Edge Functions)

-- 1. Table for Edge Function server error events
CREATE TABLE IF NOT EXISTS public.edge_function_error_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name text NOT NULL,
  error_message text,
  status_code int DEFAULT 500 NOT NULL,
  school_id uuid REFERENCES public.schools(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  occurred_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Performance indexes for real-time aggregation and dashboards
CREATE INDEX IF NOT EXISTS idx_edge_func_err_name_occurred 
  ON public.edge_function_error_events (function_name, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_edge_func_err_occurred 
  ON public.edge_function_error_events (occurred_at DESC);

-- 3. Row Level Security: strictly restrict access
ALTER TABLE public.edge_function_error_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_function_error_events FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS edge_function_error_events_admin_select ON public.edge_function_error_events;
CREATE POLICY edge_function_error_events_admin_select
  ON public.edge_function_error_events
  FOR SELECT
  TO authenticated
  USING (public.is_platform_admin());

DROP POLICY IF EXISTS edge_function_error_events_service_insert ON public.edge_function_error_events;
CREATE POLICY edge_function_error_events_service_insert
  ON public.edge_function_error_events
  FOR INSERT
  TO service_role
  WITH CHECK (true);

REVOKE ALL ON public.edge_function_error_events FROM public, anon, authenticated;
GRANT SELECT ON public.edge_function_error_events TO authenticated;
GRANT ALL ON public.edge_function_error_events TO service_role;

-- 4. Function to detect error burst (e.g., more than N 500 errors in last M minutes)
CREATE OR REPLACE FUNCTION public.check_edge_function_error_burst(
  p_function_name text,
  p_window_minutes int DEFAULT 15,
  p_threshold int DEFAULT 5
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_error_count int;
BEGIN
  SELECT count(*)
    INTO v_error_count
    FROM public.edge_function_error_events
   WHERE function_name = p_function_name
     AND status_code >= 500
     AND occurred_at >= timezone('utc'::text, now()) - (p_window_minutes || ' minutes')::interval;

  RETURN v_error_count >= p_threshold;
END;
$$;

-- 5. Helper function to record edge function error and verify burst status atomically
CREATE OR REPLACE FUNCTION public.record_edge_function_error(
  p_function_name text,
  p_error_message text,
  p_status_code int DEFAULT 500,
  p_school_id uuid DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
  v_is_burst boolean;
  v_recent_count int;
BEGIN
  INSERT INTO public.edge_function_error_events (
    function_name, error_message, status_code, school_id, user_id, metadata
  ) VALUES (
    p_function_name, p_error_message, p_status_code, p_school_id, p_user_id, p_metadata
  ) RETURNING id INTO v_new_id;

  SELECT count(*)
    INTO v_recent_count
    FROM public.edge_function_error_events
   WHERE function_name = p_function_name
     AND status_code >= 500
     AND occurred_at >= timezone('utc'::text, now()) - interval '15 minutes';

  v_is_burst := (v_recent_count >= 5);

  -- If burst detected, log critical audit entry
  IF v_is_burst THEN
    INSERT INTO public.audit_log (
      action, table_name, record_id, new_values
    ) VALUES (
      'EDGE_FUNCTION_BURST_ALERT',
      'edge_function_error_events',
      v_new_id::text,
      jsonb_build_object(
        'function_name', p_function_name,
        'recent_errors_15m', v_recent_count,
        'last_error', p_error_message,
        'alert_level', 'CRITICAL'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_new_id,
    'alert_triggered', v_is_burst,
    'recent_count_15m', v_recent_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.check_edge_function_error_burst(text, int, int) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_edge_function_error_burst(text, int, int) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.record_edge_function_error(text, text, int, uuid, uuid, jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_edge_function_error(text, text, int, uuid, uuid, jsonb) TO service_role;

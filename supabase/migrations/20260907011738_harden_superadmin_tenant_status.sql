-- Global Superadmin status mutations must use the clicked institution as target.
-- The RPC remains exposed only to authenticated callers and enforces platform roles internally.
CREATE OR REPLACE FUNCTION public.set_tenant_status(
  p_school_id uuid,
  p_new_status text,
  p_reason text DEFAULT 'Modificación por Superadmin',
  p_observation text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_previous_status text;
  v_user_role text;
  v_is_authorized boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticación requerida' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_user_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF public.is_platform_admin()
     OR v_user_role = 'superadmin'
     OR public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_support']) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Acceso denegado: se requiere un rol administrativo de plataforma'
      USING ERRCODE = '42501';
  END IF;

  IF p_school_id IS NULL THEN
    RAISE EXCEPTION 'Institución requerida' USING ERRCODE = '22004';
  END IF;

  IF p_new_status IS NULL OR p_new_status NOT IN ('active', 'trial', 'past_due', 'suspended', 'cancelled') THEN
    RAISE EXCEPTION 'Estado no válido' USING ERRCODE = '22023';
  END IF;

  SELECT status::text INTO v_previous_status
  FROM public.schools
  WHERE id = p_school_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Institución no encontrada' USING ERRCODE = 'P0002';
  END IF;

  IF v_previous_status = p_new_status THEN
    RETURN json_build_object(
      'success', true,
      'changed', false,
      'school_id', p_school_id,
      'previous_status', v_previous_status,
      'new_status', p_new_status,
      'message', 'La institución ya tenía el estado solicitado.'
    );
  END IF;

  UPDATE public.schools
  SET status = p_new_status::public.tenant_status_type,
      is_active = p_new_status IN ('active', 'trial'),
      suspended_reason = CASE
        WHEN p_new_status = 'suspended' THEN COALESCE(NULLIF(trim(p_reason), ''), 'Suspendido por Superadmin')
        ELSE NULL
      END,
      suspended_at = CASE WHEN p_new_status = 'suspended' THEN timezone('utc', now()) ELSE NULL END,
      suspended_by = CASE WHEN p_new_status = 'suspended' THEN auth.uid() ELSE NULL END,
      updated_at = timezone('utc', now())
  WHERE id = p_school_id;

  UPDATE public.subscriptions
  SET status = p_new_status::public.tenant_status_type,
      cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN timezone('utc', now()) ELSE NULL END,
      updated_at = timezone('utc', now())
  WHERE school_id = p_school_id;

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  ) VALUES (
    p_school_id,
    v_previous_status::public.tenant_status_type,
    p_new_status::public.tenant_status_type,
    left(COALESCE(NULLIF(trim(p_reason), ''), 'Cambio de estado'), 500),
    left(NULLIF(trim(p_observation), ''), 2000),
    auth.uid()
  );

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) VALUES (
    p_school_id,
    auth.uid(),
    'TENANT_STATUS_CHANGED',
    'schools',
    p_school_id::text,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object('status', p_new_status, 'result', 'success')
  );

  RETURN json_build_object(
    'success', true,
    'changed', true,
    'school_id', p_school_id,
    'previous_status', v_previous_status,
    'new_status', p_new_status,
    'message', 'Estado actualizado exitosamente.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_tenant_status(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_tenant_status(uuid, text, text, text) TO authenticated, service_role;

-- Other critical institution-management RPCs follow the same least-privilege boundary.
REVOKE ALL ON FUNCTION public.delete_tenant(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_tenant(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text, text) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

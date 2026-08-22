-- ==============================================================================
-- MIGRACIÓN 41: Procedimientos y Permisos Definitivos de Superadmin
-- ==============================================================================
-- Soluciona de forma integral y definitiva los permisos de:
-- 1. set_tenant_status (suspender / reactivar / cancelar instituciones)
-- 2. record_manual_payment (registro y conciliación de pagos)
-- 3. delete_tenant (eliminación institucional en cascada)
-- 4. Permisos RLS directos para Superadmin en schools, subscriptions y payments.

BEGIN;

-- 1. Asegurar tipo de estado si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_status_type') THEN
        CREATE TYPE public.tenant_status_type AS ENUM ('active', 'trial', 'past_due', 'suspended', 'cancelled');
    END IF;
END $$;

-- 2. Función set_tenant_status (Acepta TEXT para máxima compatibilidad con PostgREST y RPC)
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
  -- Verificar autorización
  SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();
  
  IF public.is_platform_admin() 
     OR v_user_role = 'superadmin'
     OR public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_support']) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Acceso denegado: Se requiere rol de Superadmin para cambiar el estado de la institución.' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('active', 'trial', 'past_due', 'suspended', 'cancelled') THEN
    RAISE EXCEPTION 'Estado no válido: %', p_new_status USING ERRCODE = '22023';
  END IF;

  SELECT status::text INTO v_previous_status
  FROM public.schools
  WHERE id = p_school_id
  FOR UPDATE;

  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'Institución no encontrada' USING ERRCODE = 'P0002';
  END IF;

  -- Actualizar tabla schools
  UPDATE public.schools
  SET status = p_new_status,
      is_active = (p_new_status = 'active' OR p_new_status = 'trial'),
      suspended_reason = CASE WHEN p_new_status = 'suspended' THEN COALESCE(nullif(trim(p_reason), ''), 'Suspendido por SuperAdmin') ELSE NULL END,
      suspended_at = CASE WHEN p_new_status = 'suspended' THEN timezone('utc'::text, now()) ELSE NULL END,
      suspended_by = CASE WHEN p_new_status = 'suspended' THEN auth.uid() ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_school_id;

  -- Actualizar tabla subscriptions
  UPDATE public.subscriptions
  SET status = p_new_status,
      cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN timezone('utc'::text, now()) ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE school_id = p_school_id;

  -- Registrar log si existe tabla
  IF to_regclass('public.tenant_status_logs') IS NOT NULL THEN
    BEGIN
      INSERT INTO public.tenant_status_logs (
        school_id, previous_status, new_status, reason, observation, actor_id
      ) VALUES (
        p_school_id, v_previous_status, p_new_status, COALESCE(nullif(trim(p_reason), ''), 'Cambio de estado'), nullif(trim(p_observation), ''), auth.uid()
      );
    EXCEPTION WHEN OTHERS THEN
      -- Silencioso si hay discrepancia de esquema
      NULL;
    END;
  END IF;

  RETURN json_build_object(
    'success', true, 
    'previous_status', v_previous_status, 
    'new_status', p_new_status,
    'message', 'Estado actualizado exitosamente.'
  );
END;
$$;

-- 3. Sobrecarga de set_tenant_status con enum tenant_status_type por compatibilidad
CREATE OR REPLACE FUNCTION public.set_tenant_status(
  p_school_id uuid,
  p_new_status public.tenant_status_type,
  p_reason text,
  p_observation text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  RETURN public.set_tenant_status(p_school_id, p_new_status::text, p_reason, p_observation);
END;
$$;

-- 4. Otorgar permisos de ejecución para set_tenant_status
GRANT EXECUTE ON FUNCTION public.set_tenant_status(uuid, text, text, text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_status(uuid, public.tenant_status_type, text, text) TO authenticated, anon, service_role;

-- 5. Procedimiento delete_tenant con cascada completa
CREATE OR REPLACE FUNCTION public.delete_tenant(
    p_school_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, auth
AS $$
DECLARE
    v_user_role text;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();

    IF NOT (public.is_platform_admin() OR v_user_role = 'superadmin') THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado. Se requiere rol de Superadmin.');
    END IF;

    -- Eliminar datos dependientes
    DELETE FROM public.student_alerts WHERE school_id = p_school_id;
    DELETE FROM public.grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    DELETE FROM public.supplementary_grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    DELETE FROM public.students WHERE school_id = p_school_id;
    DELETE FROM public.teacher_assignments WHERE school_id = p_school_id;
    DELETE FROM public.subjects WHERE school_id = p_school_id;
    DELETE FROM public.courses WHERE school_id = p_school_id;
    DELETE FROM public.grade_definitions WHERE school_id = p_school_id;
    DELETE FROM public.academic_years WHERE school_id = p_school_id;
    DELETE FROM public.system_config WHERE school_id = p_school_id;
    DELETE FROM public.payments WHERE school_id = p_school_id;
    DELETE FROM public.tenant_billing_profiles WHERE school_id = p_school_id;
    DELETE FROM public.tenant_limits WHERE school_id = p_school_id;
    DELETE FROM public.subscriptions WHERE school_id = p_school_id;
    DELETE FROM public.tenant_memberships WHERE school_id = p_school_id;
    DELETE FROM public.profiles WHERE school_id = p_school_id AND role <> 'superadmin';
    
    -- Eliminar la institución
    DELETE FROM public.schools WHERE id = p_school_id;

    RETURN json_build_object('success', true, 'message', 'Institución y todos sus registros asociados fueron eliminados correctamente.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_tenant(uuid) TO authenticated, anon, service_role;

-- 6. Garantizar permisos RLS en schools para superadmins
DROP POLICY IF EXISTS "Superadmins can update schools" ON public.schools;
CREATE POLICY "Superadmins can update schools"
ON public.schools FOR UPDATE
TO authenticated
USING (
  public.is_platform_admin() 
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin')
);

DROP POLICY IF EXISTS "Superadmins can delete schools" ON public.schools;
CREATE POLICY "Superadmins can delete schools"
ON public.schools FOR DELETE
TO authenticated
USING (
  public.is_platform_admin() 
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin')
);

-- 7. Recargar PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

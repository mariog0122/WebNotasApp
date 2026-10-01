-- ==============================================================================
-- MIGRACIÓN 44: Bloqueo de Modificaciones del Año Lectivo (is_locked)
-- ==============================================================================
-- 1. Agrega columna is_locked a la tabla academic_years.
-- 2. Crea función RPC toggle_academic_year_lock con validación de roles:
--    Super Administrador, Administrador de la Institución o Rector.
-- 3. Actualiza políticas RLS y funciones de consulta de años lectivos.
-- ==============================================================================

BEGIN;

-- 1. Agregar columna is_locked a academic_years
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS is_locked boolean DEFAULT false NOT NULL;

-- 2. Crear índice para optimizar consultas de años bloqueados/activos
CREATE INDEX IF NOT EXISTS idx_academic_years_locked ON public.academic_years(is_locked);

-- 3. Función RPC segura para bloquear o desbloquear un año lectivo
CREATE OR REPLACE FUNCTION public.toggle_academic_year_lock(
  target_year_id uuid,
  lock_status boolean
)
RETURNS public.academic_years
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid;
  v_year public.academic_years;
  v_caller_role text;
  v_is_platform_admin boolean;
  v_is_authorized boolean := false;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  -- Obtener el año lectivo objetivo
  SELECT * INTO v_year FROM public.academic_years WHERE id = target_year_id;
  IF v_year IS NULL THEN
    RAISE EXCEPTION 'Año lectivo no encontrado con ID: %', target_year_id;
  END IF;

  -- Validar si es administrador de plataforma (Superadmin)
  v_is_platform_admin := public.is_platform_admin();

  -- Obtener rol del perfil
  SELECT p.role INTO v_caller_role FROM public.profiles p WHERE p.id = v_caller_id;

  -- Comprobar autorización: Superadmin, o Directivo de la institución (Admin / Rector)
  IF v_is_platform_admin OR v_caller_role = 'superadmin' THEN
    v_is_authorized := true;
  ELSIF v_year.school_id IS NOT NULL THEN
    -- Validar si el usuario pertenece a la institución y tiene rol de admin, school_admin o rector
    IF (
      v_caller_role IN ('admin', 'school_admin', 'rector')
      AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = v_caller_id
          AND (p.school_id = v_year.school_id OR p.school_id IS NULL)
      )
    ) OR EXISTS (
      SELECT 1 FROM public.school_memberships sm
      WHERE sm.user_id = v_caller_id
        AND sm.school_id = v_year.school_id
        AND sm.role IN ('admin', 'school_admin', 'rector')
        AND COALESCE(sm.is_active, true) = true
    ) OR public.has_tenant_permission('settings.manage') THEN
      v_is_authorized := true;
    END IF;
  ELSE
    -- Año global sin school_id asignado: solo directivos o administradores pueden alternarlo
    IF v_caller_role IN ('admin', 'school_admin', 'rector') OR public.is_admin() THEN
      v_is_authorized := true;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Acceso denegado: Solo el Super Administrador, Administrador Institucional o Rector pueden bloquear o desbloquear el año lectivo.';
  END IF;

  -- Actualizar el estado de bloqueo
  UPDATE public.academic_years
  SET is_locked = lock_status
  WHERE id = target_year_id
  RETURNING * INTO v_year;

  RETURN v_year;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_academic_year_lock(uuid, boolean) TO authenticated, service_role;

-- 4. Actualizar función get_academic_years_list() para incluir el campo is_locked
CREATE OR REPLACE FUNCTION public.get_academic_years_list()
RETURNS TABLE(
    id UUID,
    name TEXT,
    start_year INTEGER,
    end_year INTEGER,
    is_active BOOLEAN,
    is_current BOOLEAN,
    is_locked BOOLEAN,
    courses_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ay.id,
        ay.name,
        ay.start_year,
        ay.end_year,
        ay.is_active,
        ay.is_current,
        COALESCE(ay.is_locked, false) as is_locked,
        COUNT(c.id)::BIGINT as courses_count
    FROM public.academic_years ay
    LEFT JOIN public.courses c ON c.academic_year = ay.name
    WHERE ay.school_id = public.get_user_school_id() OR ay.school_id IS NULL OR public.is_platform_admin()
    GROUP BY ay.id, ay.name, ay.start_year, ay.end_year, ay.is_active, ay.is_current, ay.is_locked
    ORDER BY ay.start_year DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_academic_years_list() TO authenticated, service_role;

-- 5. Actualizar políticas RLS de academic_years para que UPDATE valide permisos
DROP POLICY IF EXISTS "academic_years_update" ON public.academic_years;
CREATE POLICY "academic_years_update" ON public.academic_years FOR UPDATE TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
)
WITH CHECK (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
);

COMMIT;

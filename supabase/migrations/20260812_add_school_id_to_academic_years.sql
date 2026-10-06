-- Migración: Agregar columna school_id a la tabla academic_years para soporte multi-tenant
BEGIN;

-- 1. Agregar columna school_id si no existe
ALTER TABLE public.academic_years 
ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;

-- 2. Poblar school_id para registros existentes que no tengan asignado un colegio
DO $$
DECLARE
  v_default_school_id UUID;
BEGIN
  SELECT id INTO v_default_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  IF v_default_school_id IS NOT NULL THEN
    UPDATE public.academic_years 
    SET school_id = v_default_school_id 
    WHERE school_id IS NULL;
  END IF;
END $$;

-- 3. Ajustar la restricción de unicidad del nombre para que sea por institución (school_id, name)
ALTER TABLE public.academic_years DROP CONSTRAINT IF EXISTS academic_years_name_key;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'academic_years_school_id_name_key'
  ) THEN
    ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_school_id_name_key UNIQUE (school_id, name);
  END IF;
END $$;

-- 4. Crear índice para optimizar búsquedas por school_id
CREATE INDEX IF NOT EXISTS idx_academic_years_school_id ON public.academic_years(school_id);

-- 5. Actualizar políticas RLS de academic_years
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS academic_years_select ON public.academic_years;
CREATE POLICY academic_years_select ON public.academic_years FOR SELECT TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR school_id IS NULL
);

DROP POLICY IF EXISTS academic_years_insert ON public.academic_years;
CREATE POLICY academic_years_insert ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin() OR (
    school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.manage')
  )
);

DROP POLICY IF EXISTS academic_years_update ON public.academic_years;
CREATE POLICY academic_years_update ON public.academic_years FOR UPDATE TO authenticated
USING (
  public.is_platform_admin() OR (
    school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.manage')
  )
)
WITH CHECK (
  public.is_platform_admin() OR (
    school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.manage')
  )
);

DROP POLICY IF EXISTS academic_years_delete ON public.academic_years;
CREATE POLICY academic_years_delete ON public.academic_years FOR DELETE TO authenticated
USING (
  public.is_platform_admin() OR (
    school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.manage')
  )
);

-- Refrescar el cache del esquema en PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

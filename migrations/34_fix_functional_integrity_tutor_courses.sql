-- ==============================================================================
-- Migración 34: Integridad Funcional, Columna tutor_name, Años Lectivos y Cache
-- ==============================================================================
BEGIN;

-- 1. Añadir columna tutor_name a la tabla courses si no existe
ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS tutor_name text;

-- 2. Asegurar que courses tenga columna school_id
ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;

-- 3. Asegurar que academic_years tenga columna school_id
ALTER TABLE public.academic_years 
ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;

-- 4. Asociar registros huérfanos de academic_years y courses al primer colegio existente si school_id es null
DO $$
DECLARE
  v_default_school_id UUID;
BEGIN
  SELECT id INTO v_default_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  IF v_default_school_id IS NOT NULL THEN
    UPDATE public.academic_years 
    SET school_id = v_default_school_id 
    WHERE school_id IS NULL;

    UPDATE public.courses 
    SET school_id = v_default_school_id 
    WHERE school_id IS NULL;
  END IF;
END $$;

-- 5. Ajustar restricción de unicidad de academic_years a nivel de institución
ALTER TABLE public.academic_years DROP CONSTRAINT IF EXISTS academic_years_name_key;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'academic_years_school_id_name_key'
  ) THEN
    ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_school_id_name_key UNIQUE (school_id, name);
  END IF;
END $$;

-- 6. Índices para acelerar búsquedas y joins
CREATE INDEX IF NOT EXISTS idx_courses_school_id ON public.courses(school_id);
CREATE INDEX IF NOT EXISTS idx_courses_academic_year ON public.courses(academic_year);
CREATE INDEX IF NOT EXISTS idx_academic_years_school_id ON public.academic_years(school_id);
CREATE INDEX IF NOT EXISTS idx_course_subjects_course_school ON public.course_subjects(school_id, course_id);
CREATE INDEX IF NOT EXISTS idx_students_course_school ON public.students(school_id, course_id);

-- 7. Políticas RLS seguras para courses
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.courses;
DROP POLICY IF EXISTS "courses_select_policy" ON public.courses;
CREATE POLICY "courses_select_policy" ON public.courses 
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR school_id = public.get_user_school_id()
  OR school_id IS NULL
);

DROP POLICY IF EXISTS "courses_insert_policy" ON public.courses;
CREATE POLICY "courses_insert_policy" ON public.courses 
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('courses.create'))
  OR (school_id = public.get_user_school_id())
);

DROP POLICY IF EXISTS "courses_update_policy" ON public.courses;
CREATE POLICY "courses_update_policy" ON public.courses 
FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('courses.update'))
  OR (school_id = public.get_user_school_id())
)
WITH CHECK (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('courses.update'))
  OR (school_id = public.get_user_school_id())
);

DROP POLICY IF EXISTS "courses_delete_policy" ON public.courses;
CREATE POLICY "courses_delete_policy" ON public.courses 
FOR DELETE TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('courses.delete'))
  OR (school_id = public.get_user_school_id())
);

-- 8. Políticas RLS para academic_years
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "academic_years_select" ON public.academic_years;
CREATE POLICY "academic_years_select" ON public.academic_years 
FOR SELECT TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR school_id IS NULL
);

DROP POLICY IF EXISTS "academic_years_manage" ON public.academic_years;
CREATE POLICY "academic_years_manage" ON public.academic_years 
FOR ALL TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
)
WITH CHECK (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
);

-- 9. Forzar recarga inmediata de caché en PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

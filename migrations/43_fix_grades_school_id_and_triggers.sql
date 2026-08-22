-- ==============================================================================
-- MIGRATION 43: FIX GRADES SCHEMA, TRIGGER AND AUDIT SYNCHRONIZATION
-- Resuelve el error: record "new" has no field "school_id" al guardar notas
-- ==============================================================================

-- 1. Asegurar columnas de dimensiones e institución en la tabla grades
ALTER TABLE public.grades 
  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS course_subject_id uuid REFERENCES public.course_subjects(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS quarter_id uuid REFERENCES public.quarters(id) ON DELETE CASCADE;

-- 2. Índices de aceleración para consultas y aislamiento multi-tenant
CREATE INDEX IF NOT EXISTS idx_grades_school_id ON public.grades(school_id);
CREATE INDEX IF NOT EXISTS idx_grades_course_subject_id ON public.grades(course_subject_id);
CREATE INDEX IF NOT EXISTS idx_grades_quarter_id ON public.grades(quarter_id);

-- 3. Crear esquema private si no existiera
CREATE SCHEMA IF NOT EXISTS private;

-- 4. Reemplazar función de trigger para sincronización segura
CREATE OR REPLACE FUNCTION private.synchronize_grade_dimensions_from_definition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_course_subject_id uuid;
  v_quarter_id uuid;
  v_definition_school_id uuid;
BEGIN
  -- Obtener dimensiones desde la definición de la calificación
  SELECT gd.course_subject_id, gd.quarter_id, gd.school_id
  INTO v_course_subject_id, v_quarter_id, v_definition_school_id
  FROM public.grade_definitions gd
  WHERE gd.id = NEW.grade_definition_id;

  IF v_course_subject_id IS NOT NULL THEN
    NEW.course_subject_id := v_course_subject_id;
  END IF;

  IF v_quarter_id IS NOT NULL THEN
    NEW.quarter_id := v_quarter_id;
  END IF;

  IF v_definition_school_id IS NOT NULL THEN
    NEW.school_id := v_definition_school_id;
  END IF;

  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

-- 5. Reactivar el trigger en la tabla grades
DROP TRIGGER IF EXISTS synchronize_grade_dimensions_from_definition ON public.grades;
CREATE TRIGGER synchronize_grade_dimensions_from_definition
BEFORE INSERT OR UPDATE ON public.grades
FOR EACH ROW
EXECUTE FUNCTION private.synchronize_grade_dimensions_from_definition();

-- 6. Retro-rellenar dimensiones para registros existentes
UPDATE public.grades g
SET school_id = gd.school_id,
    course_subject_id = gd.course_subject_id,
    quarter_id = gd.quarter_id
FROM public.grade_definitions gd
WHERE g.grade_definition_id = gd.id
  AND (g.school_id IS NULL OR g.course_subject_id IS NULL OR g.quarter_id IS NULL);

-- 7. Asegurar permisos de ejecución en las funciones RPC de guardado
GRANT EXECUTE ON FUNCTION public.save_grade_batch(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_qualitative_grade_batch(uuid, uuid, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.import_students_batch(uuid, jsonb) TO authenticated;

-- 8. Asegurar RLS en la tabla grades para usuarios autenticados
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "grades_insert" ON public.grades;
DROP POLICY IF EXISTS "grades_update" ON public.grades;
DROP POLICY IF EXISTS "grades_select" ON public.grades;
DROP POLICY IF EXISTS "grades_delete" ON public.grades;
DROP POLICY IF EXISTS "grades_all_auth" ON public.grades;
DROP POLICY IF EXISTS "grades_cud" ON public.grades;
DROP POLICY IF EXISTS "grades_teacher_cud" ON public.grades;

CREATE POLICY "grades_select" ON public.grades 
FOR SELECT TO authenticated 
USING (
  school_id = public.get_user_school_id() 
  OR public.is_platform_admin() 
  OR school_id IS NULL
);

CREATE POLICY "grades_insert" ON public.grades 
FOR INSERT TO authenticated 
WITH CHECK (
  school_id = public.get_user_school_id() 
  OR public.is_platform_admin() 
  OR school_id IS NULL
);

CREATE POLICY "grades_update" ON public.grades 
FOR UPDATE TO authenticated 
USING (
  school_id = public.get_user_school_id() 
  OR public.is_platform_admin() 
  OR school_id IS NULL
)
WITH CHECK (
  school_id = public.get_user_school_id() 
  OR public.is_platform_admin() 
  OR school_id IS NULL
);

CREATE POLICY "grades_delete" ON public.grades 
FOR DELETE TO authenticated 
USING (
  school_id = public.get_user_school_id() 
  OR public.is_platform_admin() 
  OR school_id IS NULL
);

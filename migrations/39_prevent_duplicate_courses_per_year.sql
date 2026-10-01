-- ==============================================================================
-- MIGRACIÓN 39: Restricción de Cursos Únicos por Escuela y Año Lectivo
-- ==============================================================================
-- Impide crear o renombrar cursos duplicados (mismo nombre ignorando mayúsculas/minúsculas
-- y espacios) dentro de la misma institución y año lectivo.

BEGIN;

-- 1. Función de validación de unicidad amigable
CREATE OR REPLACE FUNCTION public.check_duplicate_course_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_trimmed_name text;
  v_exists boolean;
BEGIN
  v_trimmed_name := trim(NEW.name);

  IF v_trimmed_name IS NULL OR v_trimmed_name = '' THEN
    RAISE EXCEPTION 'El nombre del curso no puede estar vacío.'
      USING ERRCODE = '22023';
  END IF;

  -- Comprobar si existe otro curso con el mismo nombre normalizado en la misma escuela y año lectivo
  SELECT EXISTS (
    SELECT 1 
    FROM public.courses c
    WHERE c.school_id = NEW.school_id
      AND c.academic_year = NEW.academic_year
      AND lower(trim(c.name)) = lower(v_trimmed_name)
      AND (TG_OP = 'INSERT' OR c.id <> NEW.id)
  ) INTO v_exists;

  IF v_exists THEN
    RAISE EXCEPTION 'DUPLICATE_COURSE_NAME: Ya existe un curso con el nombre "%" en el año lectivo %.', v_trimmed_name, NEW.academic_year
      USING ERRCODE = '23505';
  END IF;

  NEW.name := v_trimmed_name;
  RETURN NEW;
END;
$$;

-- 2. Vincular trigger antes de INSERT o UPDATE en public.courses
DROP TRIGGER IF EXISTS trg_check_duplicate_course_name ON public.courses;
CREATE TRIGGER trg_check_duplicate_course_name
BEFORE INSERT OR UPDATE OF name, academic_year, school_id ON public.courses
FOR EACH ROW
EXECUTE FUNCTION public.check_duplicate_course_name();

-- 3. Crear índice único funcional en public.courses si no existen registros duplicados conflictivos
DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS idx_courses_unique_school_year_name 
  ON public.courses (school_id, academic_year, lower(trim(name)));
EXCEPTION
  WHEN unique_violation OR duplicate_table THEN
    RAISE NOTICE 'Índice único no creado directamente por datos existentes, pero el trigger validará todas las futuras inserciones/actualizaciones.';
END $$;

-- 4. Actualizar función de copia de cursos entre años lectivos
-- Permite copiar los cursos a un año lectivo diferente y omite duplicados si ya existen en el año destino.
CREATE OR REPLACE FUNCTION public.copy_courses_to_academic_year(
  source_year_id uuid,
  target_year_id uuid,
  include_subjects boolean DEFAULT true
)
RETURNS TABLE(new_course_id uuid, original_course_id uuid, course_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  source_year public.academic_years;
  target_year public.academic_years;
  source_course record;
  created_course_id uuid;
  existing_course_id uuid;
  actor_school_id uuid := public.get_user_school_id();
BEGIN
  IF actor_school_id IS NULL OR NOT (public.has_tenant_permission('settings.manage') OR public.is_platform_admin()) THEN
    RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO source_year FROM public.academic_years WHERE id = source_year_id;
  SELECT * INTO target_year FROM public.academic_years WHERE id = target_year_id;

  IF source_year.id IS NULL OR target_year.id IS NULL THEN
    RAISE EXCEPTION 'Año lectivo no encontrado' USING ERRCODE = 'P0002';
  END IF;

  IF source_year.id = target_year.id THEN
    RAISE EXCEPTION 'No se pueden copiar cursos al mismo año lectivo de origen' USING ERRCODE = '22023';
  END IF;

  FOR source_course IN
    SELECT c.* 
    FROM public.courses c
    WHERE c.academic_year = source_year.name 
      AND c.school_id = actor_school_id
  LOOP
    -- Verificar si el curso ya existe en el año lectivo destino
    SELECT id INTO existing_course_id
    FROM public.courses
    WHERE school_id = actor_school_id
      AND academic_year = target_year.name
      AND lower(trim(name)) = lower(trim(source_course.name))
    LIMIT 1;

    IF existing_course_id IS NOT NULL THEN
      created_course_id := existing_course_id;
    ELSE
      INSERT INTO public.courses (name, academic_year, level, track, school_id)
      VALUES (trim(source_course.name), target_year.name, source_course.level, source_course.track, actor_school_id)
      RETURNING id INTO created_course_id;
    END IF;

    IF include_subjects AND created_course_id IS NOT NULL THEN
      INSERT INTO public.course_subjects (course_id, subject_id, teacher_id, school_id)
      SELECT created_course_id, cs.subject_id, NULL, actor_school_id
      FROM public.course_subjects cs
      WHERE cs.course_id = source_course.id 
        AND cs.school_id = actor_school_id
      ON CONFLICT (course_id, subject_id) DO NOTHING;
    END IF;

    new_course_id := created_course_id;
    original_course_id := source_course.id;
    course_name := source_course.name;
    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.copy_courses_to_academic_year(uuid, uuid, boolean) TO authenticated, service_role;

-- 5. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

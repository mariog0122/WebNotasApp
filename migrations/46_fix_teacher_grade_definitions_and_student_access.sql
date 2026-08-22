-- ==============================================================================
-- MIGRACIÓN 46: FIX TEACHER GRADE DEFINITIONS AND STUDENT ACCESS
-- ==============================================================================
-- Resuelve el problema donde los docentes con materias asignadas no cargaban
-- a los estudiantes porque:
-- 1. La política RLS de grade_definitions impedía al docente inicializar las
--    columnas de calificación del trimestre al abrir el acta.
-- 2. Se añade la función RPC atómica ensure_default_grade_definitions para
--    crear las 19 dimensiones estándar de forma segura tanto para administradores
--    como para docentes asignados.
-- 3. Se actualizan las políticas RLS en grade_definitions para permitir lectura,
--    inserción y edición de nombres de columnas a docentes asignados.
-- 4. Se asegura la compatibilidad de roles ('teacher', 'docente') al asignar materias.
-- ==============================================================================

BEGIN;

-- 1. Función RPC segura para asegurar/crear columnas de calificación por defecto
CREATE OR REPLACE FUNCTION public.ensure_default_grade_definitions(
  p_course_subject_id uuid,
  p_quarter_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_teacher_id uuid;
  v_caller_id uuid := auth.uid();
  v_existing_count int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  -- Obtener escuela y docente asignado a la asignatura
  SELECT cs.school_id, cs.teacher_id 
  INTO v_school_id, v_teacher_id
  FROM public.course_subjects cs
  WHERE cs.id = p_course_subject_id;

  IF v_school_id IS NULL THEN
    -- Fallback: obtener de la tabla courses
    SELECT c.school_id INTO v_school_id
    FROM public.course_subjects cs
    JOIN public.courses c ON c.id = cs.course_id
    WHERE cs.id = p_course_subject_id;
  END IF;

  IF v_school_id IS NULL THEN
    v_school_id := public.get_user_school_id();
  END IF;

  -- Verificar autorización: admin de plataforma, admin de institución, o docente asignado
  IF NOT (
    public.is_platform_admin()
    OR public.has_tenant_permission('settings.manage')
    OR public.has_tenant_permission('grades.create')
    OR v_teacher_id = v_caller_id
    OR v_school_id = public.get_user_school_id()
  ) THEN
    RAISE EXCEPTION 'No autorizado para gestionar dimensiones de calificación en esta asignatura.';
  END IF;

  -- Contar si ya existen columnas para esta asignatura y periodo
  SELECT count(*) INTO v_existing_count
  FROM public.grade_definitions
  WHERE course_subject_id = p_course_subject_id
    AND quarter_id = p_quarter_id;

  IF v_existing_count > 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'created', 0,
      'existing', v_existing_count,
      'course_subject_id', p_course_subject_id,
      'quarter_id', p_quarter_id
    );
  END IF;

  -- Insertar las 19 definiciones estándar del sistema educativo
  INSERT INTO public.grade_definitions (course_subject_id, quarter_id, school_id, name, category, sort_order)
  VALUES
    -- INDIVIDUAL (8 columnas)
    (p_course_subject_id, p_quarter_id, v_school_id, 'Lecciones 1', 'INDIVIDUAL', 1),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Lecciones 2', 'INDIVIDUAL', 2),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Pruebas 1', 'INDIVIDUAL', 3),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Pruebas 2', 'INDIVIDUAL', 4),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Tareas 1', 'INDIVIDUAL', 5),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Tareas 2', 'INDIVIDUAL', 6),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Proyectos 1', 'INDIVIDUAL', 7),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Proyectos 2', 'INDIVIDUAL', 8),
    -- GRUPAL (8 columnas)
    (p_course_subject_id, p_quarter_id, v_school_id, 'Proyectos 1', 'GRUPAL', 9),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Proyectos 2', 'GRUPAL', 10),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Exposiciones 1', 'GRUPAL', 11),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Exposiciones 2', 'GRUPAL', 12),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Talleres 1', 'GRUPAL', 13),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Talleres 2', 'GRUPAL', 14),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Productos 1', 'GRUPAL', 15),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Productos 2', 'GRUPAL', 16),
    -- REFUERZO (1 columna)
    (p_course_subject_id, p_quarter_id, v_school_id, 'Refuerzo Pedagogico', 'REFUERZO', 17),
    -- SUMATIVA (2 columnas)
    (p_course_subject_id, p_quarter_id, v_school_id, 'Proyecto Interdisciplinario', 'SUMATIVA', 18),
    (p_course_subject_id, p_quarter_id, v_school_id, 'Examen del Trimestre', 'SUMATIVA', 19)
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'created', 19,
    'course_subject_id', p_course_subject_id,
    'quarter_id', p_quarter_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_default_grade_definitions(uuid, uuid) TO authenticated, service_role;

-- 2. Actualizar políticas RLS en grade_definitions para no bloquear a docentes
ALTER TABLE public.grade_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "grade_definitions_select" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_insert" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_update" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_delete" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_all_auth" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_teacher_cud" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_admin_delete" ON public.grade_definitions;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.grade_definitions;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.grade_definitions;

CREATE POLICY "grade_definitions_select" ON public.grade_definitions
FOR SELECT TO authenticated
USING (
  school_id = public.get_user_school_id()
  OR public.is_platform_admin()
  OR school_id IS NULL
  OR public.is_active_tenant_member(school_id)
);

CREATE POLICY "grade_definitions_insert" ON public.grade_definitions
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('grades.create')
      OR EXISTS (
        SELECT 1 FROM public.course_subjects cs
        WHERE cs.id = course_subject_id
          AND (cs.teacher_id = auth.uid() OR cs.teacher_id IS NULL)
      )
    )
  )
);

CREATE POLICY "grade_definitions_update" ON public.grade_definitions
FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('grades.update')
      OR EXISTS (
        SELECT 1 FROM public.course_subjects cs
        WHERE cs.id = course_subject_id
          AND (cs.teacher_id = auth.uid() OR cs.teacher_id IS NULL)
      )
    )
  )
)
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('grades.update')
      OR EXISTS (
        SELECT 1 FROM public.course_subjects cs
        WHERE cs.id = course_subject_id
          AND (cs.teacher_id = auth.uid() OR cs.teacher_id IS NULL)
      )
    )
  )
);

CREATE POLICY "grade_definitions_delete" ON public.grade_definitions
FOR DELETE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    school_id = public.get_user_school_id()
    AND public.has_tenant_permission('settings.manage')
  )
);

-- 3. Actualizar función save_course_subject_assignments para soportar rol 'docente' o 'teacher'
CREATE OR REPLACE FUNCTION public.save_course_subject_assignments(
  p_course_id uuid,
  p_assignments jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_item jsonb;
  v_subject_id uuid;
  v_teacher_id uuid;
BEGIN
  IF jsonb_typeof(p_assignments) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_ASSIGNMENT_BATCH' USING errcode = 'P0001';
  END IF;

  SELECT c.school_id INTO v_school_id
  FROM public.courses c
  WHERE c.id = p_course_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'COURSE_NOT_FOUND' USING errcode = 'P0001';
  END IF;

  IF NOT public.is_admin()
     OR (NOT public.is_platform_admin() AND v_school_id IS DISTINCT FROM public.get_user_school_id()) THEN
    RAISE EXCEPTION 'COURSE_ASSIGNMENT_FORBIDDEN' USING errcode = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT value->>'subject_id' subject_id, count(*) amount
      FROM jsonb_array_elements(p_assignments)
      GROUP BY value->>'subject_id'
      HAVING count(*) > 1
    ) duplicates
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_SUBJECT_ASSIGNMENT' USING errcode = 'P0001';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_assignments)
  LOOP
    BEGIN
      v_subject_id := (v_item->>'subject_id')::uuid;
      v_teacher_id := nullif(v_item->>'teacher_id', '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'INVALID_ASSIGNMENT_ID' USING errcode = 'P0001';
    END;

    IF NOT EXISTS (
      SELECT 1 FROM public.subjects s
      WHERE s.id = v_subject_id AND s.school_id = v_school_id
    ) THEN
      RAISE EXCEPTION 'INVALID_ASSIGNED_SUBJECT' USING errcode = 'P0001';
    END IF;

    IF v_teacher_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = v_teacher_id
        AND p.school_id = v_school_id
        AND (p.role IN ('teacher', 'docente') OR public.is_active_tenant_member(p.school_id))
        AND COALESCE(p.is_active, true)
    ) THEN
      RAISE EXCEPTION 'INVALID_ASSIGNED_TEACHER' USING errcode = 'P0001';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM public.course_subjects cs
    WHERE cs.course_id = p_course_id
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_assignments) item
        WHERE (item->>'subject_id')::uuid = cs.subject_id
      )
      AND (
        EXISTS (SELECT 1 FROM public.grade_definitions gd WHERE gd.course_subject_id = cs.id)
        OR EXISTS (SELECT 1 FROM public.grades g WHERE g.course_subject_id = cs.id)
        OR EXISTS (SELECT 1 FROM public.qualitative_grades qg WHERE qg.course_subject_id = cs.id)
        OR EXISTS (SELECT 1 FROM public.supplementary_exams se WHERE se.course_subject_id = cs.id)
      )
  ) THEN
    RAISE EXCEPTION 'COURSE_SUBJECT_HAS_ACADEMIC_DATA' USING errcode = 'P0001';
  END IF;

  DELETE FROM public.course_subjects cs
  WHERE cs.course_id = p_course_id
    AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_assignments) item
      WHERE (item->>'subject_id')::uuid = cs.subject_id
    );

  INSERT INTO public.course_subjects (course_id, subject_id, teacher_id, school_id)
  SELECT
    p_course_id,
    (item->>'subject_id')::uuid,
    nullif(item->>'teacher_id', '')::uuid,
    v_school_id
  FROM jsonb_array_elements(p_assignments) item
  ON CONFLICT (course_id, subject_id) DO UPDATE
  SET teacher_id = excluded.teacher_id,
      school_id = excluded.school_id;

  RETURN jsonb_build_object(
    'course_id', p_course_id,
    'assignment_count', jsonb_array_length(p_assignments),
    'teacher_assignment_count', (
      SELECT count(*) FROM jsonb_array_elements(p_assignments) item
      WHERE nullif(item->>'teacher_id', '') IS NOT NULL
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_course_subject_assignments(uuid, jsonb) TO authenticated, service_role;

COMMIT;

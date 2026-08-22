-- ==============================================================================
-- MIGRACIÓN 48: MÓDULO DE ASISTENCIA (DOCENTES E INSPECCIÓN GENERAL)
-- ==============================================================================
-- 1. Crea la tabla public.attendance_records para el registro diario y por materia
--    de la asistencia escolar (Presente, Atraso, Falta Injustificada, Falta Justificada, Fuga).
-- 2. Define constraint de unicidad para evitar duplicados por estudiante, fecha, curso,
--    materia y bloque horario.
-- 3. Crea la función RPC transaccional public.save_attendance_batch.
-- 4. Crea la función RPC public.justify_attendance_records para Inspección General.
-- 5. Habilita RLS con políticas de aislamiento multi-tenant y permisos por rol.
-- ==============================================================================

BEGIN;

-- 1. Tabla principal de Asistencia
CREATE TABLE IF NOT EXISTS public.attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  course_id uuid REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  student_id uuid REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  teacher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  attendance_date date NOT NULL,
  hour_block text DEFAULT 'jornada_completa' NOT NULL, -- '1', '2', '3', 'jornada_completa'
  status text NOT NULL DEFAULT 'presente', -- 'presente' | 'atraso' | 'falta_injustificada' | 'falta_justificada' | 'fuga'
  justification_reason text,
  justified_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  justified_at timestamptz,
  observations text,
  academic_year text,
  quarter_id uuid REFERENCES public.quarters(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Constraint de unicidad para evitar registros duplicados
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_student_attendance_entry'
  ) THEN
    ALTER TABLE public.attendance_records
    ADD CONSTRAINT unique_student_attendance_entry
    UNIQUE (student_id, attendance_date, course_id, subject_id, hour_block);
  END IF;
END $$;

-- 2. Índices de aceleración
CREATE INDEX IF NOT EXISTS idx_attendance_records_school_id ON public.attendance_records(school_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_course_id ON public.attendance_records(course_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_student_id ON public.attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_date ON public.attendance_records(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_records_status ON public.attendance_records(status);
CREATE INDEX IF NOT EXISTS idx_attendance_records_course_date ON public.attendance_records(course_id, attendance_date);

-- 3. Trigger para actualizar el timestamp updated_at
CREATE OR REPLACE FUNCTION private.touch_attendance_records_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_attendance_records_updated_at ON public.attendance_records;
CREATE TRIGGER trg_attendance_records_updated_at
BEFORE UPDATE ON public.attendance_records
FOR EACH ROW
EXECUTE FUNCTION private.touch_attendance_records_updated_at();

-- 4. Función RPC transaccional para guardar asistencia en lote (un curso completo en 1 clic)
CREATE OR REPLACE FUNCTION public.save_attendance_batch(
  p_course_id uuid,
  p_subject_id uuid,
  p_date date,
  p_hour_block text,
  p_records jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_school_id uuid;
  v_academic_year text;
  v_rec record;
  v_saved_count int := 0;
  v_student_id uuid;
  v_status text;
  v_obs text;
  v_quarter_id uuid;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  IF p_course_id IS NULL OR p_date IS NULL THEN
    RAISE EXCEPTION 'El curso y la fecha son obligatorios.';
  END IF;

  -- Resolver school_id y año lectivo desde el curso
  SELECT c.school_id, c.academic_year INTO v_school_id, v_academic_year
  FROM public.courses c
  WHERE c.id = p_course_id;

  IF v_school_id IS NULL THEN
    v_school_id := public.get_user_school_id();
  END IF;

  -- Verificar autorización de tenant
  IF NOT (
    public.is_platform_admin()
    OR v_school_id = public.get_user_school_id()
    OR public.is_active_tenant_member(v_school_id)
  ) THEN
    RAISE EXCEPTION 'No tienes autorización para registrar asistencia en esta institución.';
  END IF;

  -- Resolver trimestre activo si no se especificó
  SELECT q.id INTO v_quarter_id
  FROM public.quarters q
  WHERE (q.school_id = v_school_id OR q.school_id IS NULL)
    AND q.is_active = true
  LIMIT 1;

  -- Procesar cada registro del lote
  FOR v_rec IN SELECT * FROM jsonb_to_recordset(p_records) AS x(
    student_id uuid,
    status text,
    observations text,
    quarter_id uuid
  )
  LOOP
    v_student_id := v_rec.student_id;
    v_status := COALESCE(v_rec.status, 'presente');
    v_obs := v_rec.observations;
    IF v_rec.quarter_id IS NOT NULL THEN
      v_quarter_id := v_rec.quarter_id;
    END IF;

    IF v_student_id IS NOT NULL THEN
      INSERT INTO public.attendance_records (
        school_id,
        course_id,
        subject_id,
        student_id,
        teacher_id,
        attendance_date,
        hour_block,
        status,
        observations,
        academic_year,
        quarter_id
      )
      VALUES (
        v_school_id,
        p_course_id,
        p_subject_id,
        v_student_id,
        v_caller_id,
        p_date,
        COALESCE(p_hour_block, 'jornada_completa'),
        v_status,
        v_obs,
        v_academic_year,
        v_quarter_id
      )
      ON CONFLICT (student_id, attendance_date, course_id, subject_id, hour_block)
      DO UPDATE SET
        status = EXCLUDED.status,
        observations = EXCLUDED.observations,
        teacher_id = v_caller_id,
        updated_at = timezone('utc'::text, now());

      v_saved_count := v_saved_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'saved_count', v_saved_count,
    'date', p_date,
    'course_id', p_course_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_attendance_batch(uuid, uuid, date, text, jsonb) TO authenticated, service_role;

-- 5. Función RPC para justificar inasistencias desde Inspección General
CREATE OR REPLACE FUNCTION public.justify_attendance_records(
  p_student_id uuid,
  p_dates date[],
  p_reason text,
  p_course_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_updated_count int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  IF p_student_id IS NULL OR p_dates IS NULL OR array_length(p_dates, 1) = 0 THEN
    RAISE EXCEPTION 'Estudiante y fechas requeridos para la justificación.';
  END IF;

  UPDATE public.attendance_records
  SET
    status = 'falta_justificada',
    justification_reason = p_reason,
    justified_by = v_caller_id,
    justified_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  WHERE student_id = p_student_id
    AND attendance_date = ANY(p_dates)
    AND (p_course_id IS NULL OR course_id = p_course_id)
    AND status IN ('falta_injustificada', 'atraso');

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'updated_count', v_updated_count,
    'student_id', p_student_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.justify_attendance_records(uuid, date[], text, uuid) TO authenticated, service_role;

-- 6. Políticas de Seguridad RLS para attendance_records
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_records_select" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_insert" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_update" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_delete" ON public.attendance_records;

CREATE POLICY "attendance_records_select" ON public.attendance_records
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('attendance.read')
      OR public.has_tenant_permission('attendance.manage')
      OR public.has_tenant_permission('grades.read')
      OR teacher_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.course_subjects cs
        WHERE cs.course_id = attendance_records.course_id
          AND cs.teacher_id = auth.uid()
      )
    )
  )
);

CREATE POLICY "attendance_records_insert" ON public.attendance_records
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('attendance.manage')
      OR public.has_tenant_permission('grades.create')
      OR teacher_id = auth.uid()
    )
  )
);

CREATE POLICY "attendance_records_update" ON public.attendance_records
FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('attendance.manage')
      OR teacher_id = auth.uid()
    )
  )
)
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('attendance.manage')
      OR teacher_id = auth.uid()
    )
  )
);

CREATE POLICY "attendance_records_delete" ON public.attendance_records
FOR DELETE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('attendance.manage')
    )
  )
);

COMMIT;

-- ==============================================================================
-- MIGRACIÓN 47: MÓDULO DE INFORMES DOCENTES Y CITACIONES
-- ==============================================================================
-- 1. Crea la tabla public.teacher_reports para almacenar los informes y citaciones
--    generados por los docentes con destino a padres de familia, DECE,
--    Vicerrectorado, Inspección o Rectorado.
-- 2. Define índices de aceleración para consultas multi-tenant por institución,
--    curso, estudiante, docente y plantilla.
-- 3. Crea función RPC transaccional public.save_teacher_report.
-- 4. Habilita RLS con políticas de aislamiento por institución y roles.
-- ==============================================================================

BEGIN;

-- 1. Tabla principal de Informes Docentes
CREATE TABLE IF NOT EXISTS public.teacher_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  course_id uuid REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  student_id uuid REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  teacher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  academic_year text,
  quarter_id uuid REFERENCES public.quarters(id) ON DELETE SET NULL,
  template_type text NOT NULL, -- 'citacion_representante' | 'informe_rendimiento' | 'informe_comportamiento' | 'informe_dece_vicerrectorado' | 'acta_compromiso'
  title text NOT NULL,
  recipient_role text NOT NULL DEFAULT 'representante_legal', -- 'representante_legal' | 'dece' | 'vicerrectorado' | 'inspeccion' | 'rectorado' | 'tutor'
  recipient_name text,
  status text NOT NULL DEFAULT 'borrador', -- 'borrador' | 'enviado' | 'en_revision' | 'atendido' | 'archivado'
  priority text NOT NULL DEFAULT 'normal', -- 'baja' | 'normal' | 'alta' | 'urgente'
  citation_date date,
  citation_time text,
  citation_location text,
  reason text NOT NULL,
  academic_score numeric(4,2),
  observations text,
  agreements_commitments text,
  recommendations text,
  custom_payload jsonb DEFAULT '{}'::jsonb,
  signature_data jsonb,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Índices para acelerar búsquedas y filtros
CREATE INDEX IF NOT EXISTS idx_teacher_reports_school_id ON public.teacher_reports(school_id);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_course_id ON public.teacher_reports(course_id);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_student_id ON public.teacher_reports(student_id);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_teacher_id ON public.teacher_reports(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_template_type ON public.teacher_reports(template_type);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_status ON public.teacher_reports(status);
CREATE INDEX IF NOT EXISTS idx_teacher_reports_created_at ON public.teacher_reports(created_at DESC);

-- 3. Trigger para actualizar el timestamp updated_at
CREATE OR REPLACE FUNCTION private.touch_teacher_reports_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_teacher_reports_updated_at ON public.teacher_reports;
CREATE TRIGGER trg_teacher_reports_updated_at
BEFORE UPDATE ON public.teacher_reports
FOR EACH ROW
EXECUTE FUNCTION private.touch_teacher_reports_updated_at();

-- 4. Función RPC segura para guardar/actualizar informes docentes
CREATE OR REPLACE FUNCTION public.save_teacher_report(
  p_report jsonb
)
RETURNS public.teacher_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_school_id uuid;
  v_report_id uuid;
  v_course_id uuid;
  v_student_id uuid;
  v_result public.teacher_reports;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  v_course_id := (p_report->>'course_id')::uuid;
  v_student_id := (p_report->>'student_id')::uuid;

  IF v_course_id IS NULL OR v_student_id IS NULL THEN
    RAISE EXCEPTION 'El curso y el estudiante son campos obligatorios.';
  END IF;

  -- Resolver school_id desde el curso
  SELECT c.school_id INTO v_school_id
  FROM public.courses c
  WHERE c.id = v_course_id;

  IF v_school_id IS NULL THEN
    v_school_id := public.get_user_school_id();
  END IF;

  -- Comprobar autorización de tenant
  IF NOT (
    public.is_platform_admin()
    OR v_school_id = public.get_user_school_id()
    OR public.is_active_tenant_member(v_school_id)
  ) THEN
    RAISE EXCEPTION 'No tienes autorización para registrar informes en esta institución.';
  END IF;

  IF p_report ? 'id' AND nullif(p_report->>'id', '') IS NOT NULL THEN
    v_report_id := (p_report->>'id')::uuid;
    
    -- Actualizar informe existente
    UPDATE public.teacher_reports
    SET
      course_id = v_course_id,
      subject_id = nullif(p_report->>'subject_id', '')::uuid,
      student_id = v_student_id,
      academic_year = p_report->>'academic_year',
      quarter_id = nullif(p_report->>'quarter_id', '')::uuid,
      template_type = COALESCE(p_report->>'template_type', 'citacion_representante'),
      title = COALESCE(p_report->>'title', 'Informe Docente'),
      recipient_role = COALESCE(p_report->>'recipient_role', 'representante_legal'),
      recipient_name = p_report->>'recipient_name',
      status = COALESCE(p_report->>'status', 'borrador'),
      priority = COALESCE(p_report->>'priority', 'normal'),
      citation_date = nullif(p_report->>'citation_date', '')::date,
      citation_time = p_report->>'citation_time',
      citation_location = p_report->>'citation_location',
      reason = COALESCE(p_report->>'reason', ''),
      academic_score = nullif(p_report->>'academic_score', '')::numeric,
      observations = p_report->>'observations',
      agreements_commitments = p_report->>'agreements_commitments',
      recommendations = p_report->>'recommendations',
      custom_payload = COALESCE(p_report->'custom_payload', '{}'::jsonb),
      signature_data = CASE WHEN p_report ? 'signature_data' THEN p_report->'signature_data' ELSE signature_data END
    WHERE id = v_report_id
      AND (
        teacher_id = v_caller_id
        OR public.is_admin()
        OR public.has_tenant_permission('settings.manage')
      )
    RETURNING * INTO v_result;

    IF v_result.id IS NULL THEN
      RAISE EXCEPTION 'Informe no encontrado o no tienes permiso para editarlo.';
    END IF;
  ELSE
    -- Insertar nuevo informe
    INSERT INTO public.teacher_reports (
      school_id,
      course_id,
      subject_id,
      student_id,
      teacher_id,
      academic_year,
      quarter_id,
      template_type,
      title,
      recipient_role,
      recipient_name,
      status,
      priority,
      citation_date,
      citation_time,
      citation_location,
      reason,
      academic_score,
      observations,
      agreements_commitments,
      recommendations,
      custom_payload,
      signature_data
    )
    VALUES (
      v_school_id,
      v_course_id,
      nullif(p_report->>'subject_id', '')::uuid,
      v_student_id,
      v_caller_id,
      p_report->>'academic_year',
      nullif(p_report->>'quarter_id', '')::uuid,
      COALESCE(p_report->>'template_type', 'citacion_representante'),
      COALESCE(p_report->>'title', 'Informe Docente'),
      COALESCE(p_report->>'recipient_role', 'representante_legal'),
      p_report->>'recipient_name',
      COALESCE(p_report->>'status', 'borrador'),
      COALESCE(p_report->>'priority', 'normal'),
      nullif(p_report->>'citation_date', '')::date,
      p_report->>'citation_time',
      p_report->>'citation_location',
      COALESCE(p_report->>'reason', ''),
      nullif(p_report->>'academic_score', '')::numeric,
      p_report->>'observations',
      p_report->>'agreements_commitments',
      p_report->>'recommendations',
      COALESCE(p_report->'custom_payload', '{}'::jsonb),
      p_report->'signature_data'
    )
    RETURNING * INTO v_result;
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_teacher_report(jsonb) TO authenticated, service_role;

-- 5. Políticas RLS para teacher_reports
ALTER TABLE public.teacher_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_reports_select" ON public.teacher_reports;
DROP POLICY IF EXISTS "teacher_reports_insert" ON public.teacher_reports;
DROP POLICY IF EXISTS "teacher_reports_update" ON public.teacher_reports;
DROP POLICY IF EXISTS "teacher_reports_delete" ON public.teacher_reports;

CREATE POLICY "teacher_reports_select" ON public.teacher_reports
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('reports.read')
      OR public.has_tenant_permission('grades.read')
      OR teacher_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.course_subjects cs
        WHERE cs.course_id = teacher_reports.course_id
          AND cs.teacher_id = auth.uid()
      )
    )
  )
);

CREATE POLICY "teacher_reports_insert" ON public.teacher_reports
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR public.has_tenant_permission('grades.create')
      OR public.has_tenant_permission('reports.read')
      OR teacher_id = auth.uid()
    )
  )
);

CREATE POLICY "teacher_reports_update" ON public.teacher_reports
FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
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
      OR teacher_id = auth.uid()
    )
  )
);

CREATE POLICY "teacher_reports_delete" ON public.teacher_reports
FOR DELETE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR public.has_tenant_permission('settings.manage')
      OR (teacher_id = auth.uid() AND status = 'borrador')
    )
  )
);

COMMIT;

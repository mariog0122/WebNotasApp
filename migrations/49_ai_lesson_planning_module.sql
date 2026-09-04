-- ==============================================================================
-- MIGRACIÓN 49: MÓDULO DE PLANIFICACIÓN EDUCATIVA CON IA (CURRÍCULO ECUADOR)
-- ==============================================================================
-- 1. Tablas para catálogo curricular de Ecuador versionado (DCD, Criterios, Indicadores)
-- 2. Tablas para planificaciones didácticas (lesson_plans), versiones e historial
-- 3. Tabla para recursos didácticos generados (lesson_plan_resources)
-- 4. Tablas para seguimiento y recuperación pedagógica por estudiante (student_support_plans, events)
-- 5. Tablas para configuración de IA institucional (institution_ai_settings) y ledger de uso
-- 6. RPCs para verificación de acceso, registro transaccional y políticas RLS multi-tenant
-- ==============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS private;

-- 1. Catálogo Curricular Versionado de Ecuador
CREATE TABLE IF NOT EXISTS public.curriculum_catalogs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country text DEFAULT 'EC' NOT NULL,
  framework_version text DEFAULT 'MINEDUC_2023_COMPETENCIAS' NOT NULL,
  title text NOT NULL,
  description text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.curriculum_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id uuid REFERENCES public.curriculum_catalogs(id) ON DELETE CASCADE,
  level text NOT NULL, -- inicial, basica_elemental, basica_media, basica_superior, bachillerato_general, bachillerato_tecnico
  grade_year text NOT NULL, -- ej. '2do EGB', '8vo EGB', '1ro BGU'
  subject_name text NOT NULL, -- ej. 'Matemáticas', 'Lengua y Literatura'
  unit_number int DEFAULT 1,
  unit_title text NOT NULL,
  topic_title text NOT NULL,
  dcd_code text NOT NULL, -- Destreza con Criterio de Desempeño: ej. 'M.3.1.1'
  dcd_description text NOT NULL,
  evaluation_criteria_code text, -- ej. 'CE.M.3.1'
  evaluation_criteria_description text,
  evaluation_indicator_code text, -- ej. 'I.M.3.1.1'
  evaluation_indicator_description text,
  learning_objective_code text, -- ej. 'O.M.3.1'
  learning_objective_description text,
  bloom_level text DEFAULT 'comprender', -- recordar, comprender, aplicar, analizar, evaluar, crear
  competencies text[] DEFAULT ARRAY['comunicacionales', 'matematicas', 'digitales', 'socioemocionales']::text[],
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_curriculum_items_filter ON public.curriculum_items(level, grade_year, subject_name);
CREATE INDEX IF NOT EXISTS idx_curriculum_items_dcd ON public.curriculum_items(dcd_code);

-- 2. Tabla Principal de Planificaciones Didácticas (Lesson Plans)
CREATE TABLE IF NOT EXISTS public.lesson_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  teacher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  course_id uuid REFERENCES public.courses(id) ON DELETE SET NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  academic_year text NOT NULL,
  quarter_id uuid REFERENCES public.quarters(id) ON DELETE SET NULL,
  title text NOT NULL,
  regime text DEFAULT 'costa_galapagos' NOT NULL, -- costa_galapagos | sierra_amazonia
  level text NOT NULL, -- inicial, basica_elemental, basica_media, basica_superior, bachillerato_general, bachillerato_tecnico
  grade_year text NOT NULL,
  parallel text DEFAULT 'A',
  target_age_min int DEFAULT 6,
  target_age_max int DEFAULT 7,
  students_count int DEFAULT 30,
  duration_minutes int DEFAULT 45 NOT NULL,
  session_count int DEFAULT 2 NOT NULL,
  estimated_date date DEFAULT CURRENT_DATE,
  subject_name text NOT NULL,
  unit_title text NOT NULL,
  topic_title text NOT NULL,
  competencies text[] DEFAULT ARRAY[]::text[],
  dcd_codes text[] DEFAULT ARRAY[]::text[],
  dcd_descriptions text[] DEFAULT ARRAY[]::text[],
  evaluation_criteria_codes text[] DEFAULT ARRAY[]::text[],
  evaluation_criteria_descriptions text[] DEFAULT ARRAY[]::text[],
  evaluation_indicators text[] DEFAULT ARRAY[]::text[],
  learning_objectives text[] DEFAULT ARRAY[]::text[],
  bloom_level text DEFAULT 'comprender',
  evidence_type text DEFAULT 'desempeno_y_producto',
  methodology_primary text DEFAULT 'ERCA' NOT NULL, -- ERCA, ABP_PROYECTOS, ABP_PROBLEMAS, COOPERATIVO, AULA_INVERTIDA, DUA
  methodology_secondary text[] DEFAULT ARRAY[]::text[],
  modality text DEFAULT 'presencial' NOT NULL, -- presencial, virtual, hibrida
  group_organization text DEFAULT 'equipos' NOT NULL, -- individual, parejas, equipos, grupo_completo
  available_resources text[] DEFAULT ARRAY['pizarra', 'proyector', 'texto_escolar']::text[],
  context_type text DEFAULT 'urbano' NOT NULL, -- urbano, rural, conectividad_limitada
  evaluation_focus text[] DEFAULT ARRAY['formativa', 'sumativa']::text[],
  dua_principles text[] DEFAULT ARRAY['implicacion', 'representacion', 'accion_expresion']::text[],
  pacing_type text DEFAULT 'estandar' NOT NULL, -- refuerzo, estandar, profundizacion
  learning_barriers text[] DEFAULT ARRAY[]::text[],
  adaptations_needed boolean DEFAULT false,
  adaptations_degree text DEFAULT 'grado_1', -- grado_1, grado_2, grado_3
  support_strategies text[] DEFAULT ARRAY[]::text[],
  content_summary text,
  didactic_sequence jsonb DEFAULT '{}'::jsonb NOT NULL, -- Fases ERCA (Experiencia, Reflexión, Conceptualización, Aplicación) o Metodología
  evaluation_plan jsonb DEFAULT '{}'::jsonb NOT NULL, -- Técnicas, Instrumentos, Rúbricas, Evidencias
  inclusion_dua_plan jsonb DEFAULT '{}'::jsonb NOT NULL, -- Estrategias DUA, Adaptaciones pedagógicas
  resources_plan jsonb DEFAULT '{}'::jsonb NOT NULL,
  status text DEFAULT 'borrador' NOT NULL, -- borrador, generando, lista, en_revision, aprobada, archivada
  version int DEFAULT 1 NOT NULL,
  is_demo boolean DEFAULT false NOT NULL,
  ai_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_lesson_plans_school_id ON public.lesson_plans(school_id);
CREATE INDEX IF NOT EXISTS idx_lesson_plans_teacher_id ON public.lesson_plans(teacher_id);
CREATE INDEX IF NOT EXISTS idx_lesson_plans_course_id ON public.lesson_plans(course_id);
CREATE INDEX IF NOT EXISTS idx_lesson_plans_status ON public.lesson_plans(status);
CREATE INDEX IF NOT EXISTS idx_lesson_plans_created_at ON public.lesson_plans(created_at DESC);

-- 3. Historial de Versiones de Planificaciones
CREATE TABLE IF NOT EXISTS public.lesson_plan_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_plan_id uuid REFERENCES public.lesson_plans(id) ON DELETE CASCADE NOT NULL,
  version_number int NOT NULL,
  snapshot_content jsonb NOT NULL,
  change_summary text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lesson_plan_versions_plan ON public.lesson_plan_versions(lesson_plan_id, version_number DESC);

-- 4. Recursos Didácticos Generados
CREATE TABLE IF NOT EXISTS public.lesson_plan_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  lesson_plan_id uuid REFERENCES public.lesson_plans(id) ON DELETE CASCADE NOT NULL,
  teacher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  resource_type text NOT NULL, -- guia_docente, ficha_trabajo, actividad_inicio, rubrica, lista_cotejo, cuestionario, etc.
  title text NOT NULL,
  content jsonb NOT NULL,
  difficulty_level text DEFAULT 'medio' NOT NULL, -- inicial, medio, avanzado, adaptado
  status text DEFAULT 'listo' NOT NULL,
  target_students uuid[] DEFAULT ARRAY[]::uuid[],
  is_assigned boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lesson_plan_resources_plan ON public.lesson_plan_resources(lesson_plan_id);
CREATE INDEX IF NOT EXISTS idx_lesson_plan_resources_school ON public.lesson_plan_resources(school_id);

-- 5. Planes de Apoyo y Recuperación Pedagógica por Estudiante
CREATE TABLE IF NOT EXISTS public.student_support_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  lesson_plan_id uuid REFERENCES public.lesson_plans(id) ON DELETE SET NULL,
  student_id uuid REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  teacher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  course_id uuid REFERENCES public.courses(id) ON DELETE SET NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  support_type text NOT NULL, -- refuerzo, recuperacion, adecuacion, diferenciada, profundizacion, retroalimentacion, comunicacion_familia
  observed_difficulty text NOT NULL,
  evidence_type text NOT NULL, -- calificacion, rubrica, tarea, observacion, inasistencia
  intensity text DEFAULT 'moderada' NOT NULL, -- leve, moderada, intensiva
  duration_weeks int DEFAULT 2 NOT NULL,
  proposed_actions jsonb NOT NULL, -- Propuesta estructurada de apoyo
  status text DEFAULT 'propuesta' NOT NULL, -- propuesta, aprobado_docente, en_progreso, logrado, requiere_intervencion
  target_date date,
  approved_at timestamptz,
  approved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  observations text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_student_support_plans_school ON public.student_support_plans(school_id);
CREATE INDEX IF NOT EXISTS idx_student_support_plans_student ON public.student_support_plans(student_id);
CREATE INDEX IF NOT EXISTS idx_student_support_plans_teacher ON public.student_support_plans(teacher_id);
CREATE INDEX IF NOT EXISTS idx_student_support_plans_status ON public.student_support_plans(status);

CREATE TABLE IF NOT EXISTS public.student_support_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  support_plan_id uuid REFERENCES public.student_support_plans(id) ON DELETE CASCADE NOT NULL,
  event_type text NOT NULL, -- creacion, aprobacion, registro_avance, evaluacion_cierre
  notes text NOT NULL,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Configuración de Inteligencia Artificial por Institución
CREATE TABLE IF NOT EXISTS public.institution_ai_settings (
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE PRIMARY KEY,
  mode text DEFAULT 'managed' NOT NULL, -- 'managed' | 'byok' | 'demo'
  provider text DEFAULT 'gemini' NOT NULL, -- 'gemini' | 'demo'
  model_id text DEFAULT 'gemini-1.5-flash' NOT NULL,
  encrypted_api_key text, -- Clave opcional de la institución (BYOK) cifrada
  monthly_quota_generations int DEFAULT 200 NOT NULL,
  teacher_daily_limit int DEFAULT 15 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  status text DEFAULT 'demo' NOT NULL, -- 'active', 'demo', 'suspended', 'limit_reached'
  alert_thresholds jsonb DEFAULT '[70, 90, 100]'::jsonb NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Ledger de Consumo y Auditoría de IA
CREATE TABLE IF NOT EXISTS public.ai_usage_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  task_type text NOT NULL, -- plan_generation, section_regeneration, resource_generation, student_support_generation
  provider text NOT NULL,
  model_id text NOT NULL,
  prompt_tokens_estimated int DEFAULT 0,
  completion_tokens_estimated int DEFAULT 0,
  duration_ms int DEFAULT 0,
  status text DEFAULT 'success' NOT NULL, -- success, error, quota_exceeded
  is_demo boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_school ON public.ai_usage_ledger(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_user ON public.ai_usage_ledger(user_id, created_at DESC);

-- 8. Triggers de actualización de timestamps
CREATE OR REPLACE FUNCTION private.touch_lesson_plans_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lesson_plans_updated_at ON public.lesson_plans;
CREATE TRIGGER trg_lesson_plans_updated_at
BEFORE UPDATE ON public.lesson_plans
FOR EACH ROW EXECUTE FUNCTION private.touch_lesson_plans_updated_at();

DROP TRIGGER IF EXISTS trg_student_support_plans_updated_at ON public.student_support_plans;
CREATE TRIGGER trg_student_support_plans_updated_at
BEFORE UPDATE ON public.student_support_plans
FOR EACH ROW EXECUTE FUNCTION private.touch_lesson_plans_updated_at();

-- 8.5. Asegurar existencia de la tabla tenant_features y sus políticas RLS
CREATE TABLE IF NOT EXISTS public.tenant_features (
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    feature_key text NOT NULL, -- grades, attendance, enrollment, reports, projects, alerts, ai_planning
    enabled boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (school_id, feature_key)
);

ALTER TABLE public.tenant_features ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tenant_features' AND policyname = 'tenant_features_select_policy'
  ) THEN
    CREATE POLICY "tenant_features_select_policy" ON public.tenant_features
    FOR SELECT TO authenticated
    USING (
      public.is_platform_admin() 
      OR school_id = public.get_user_school_id()
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tenant_features' AND policyname = 'tenant_features_all_policy'
  ) THEN
    CREATE POLICY "tenant_features_all_policy" ON public.tenant_features
    FOR ALL TO authenticated
    USING (
      public.is_platform_admin()
    );
  END IF;
END $$;

-- 9. Registrar Módulo en Feature Flags (tenant_features)
DO $$
DECLARE
  sch_rec RECORD;
BEGIN
  FOR sch_rec IN SELECT id FROM public.schools LOOP
    INSERT INTO public.tenant_features (school_id, feature_key, enabled)
    VALUES (sch_rec.id, 'ai_planning', true)
    ON CONFLICT (school_id, feature_key) DO NOTHING;

    INSERT INTO public.institution_ai_settings (school_id, mode, provider, model_id, status)
    VALUES (sch_rec.id, 'managed', 'gemini', 'gemini-2.5-flash', 'active')
    ON CONFLICT (school_id) DO NOTHING;
  END LOOP;
END $$;

-- 10. RPC para verificar acceso y estado del módulo de IA
CREATE OR REPLACE FUNCTION public.check_ai_planning_access(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_school_id uuid := COALESCE(p_school_id, public.get_user_school_id());
  v_feature_enabled boolean := false;
  v_ai_settings record;
  v_usage_count int := 0;
  v_teacher_daily_count int := 0;
  v_sub_status text := 'trial';
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  -- Comprobar si el tenant tiene la feature activa
  SELECT enabled INTO v_feature_enabled
  FROM public.tenant_features
  WHERE school_id = v_school_id AND feature_key = 'ai_planning';

  -- Si no existe en tenant_features, verificar fallback
  IF v_feature_enabled IS NULL THEN
    v_feature_enabled := true;
  END IF;

  -- Obtener estado de suscripción defensivamente
  BEGIN
    SELECT status INTO v_sub_status
    FROM public.subscriptions
    WHERE school_id = v_school_id
    LIMIT 1;
  EXCEPTION WHEN undefined_table THEN
    v_sub_status := 'active';
  END;

  -- Obtener settings de IA
  SELECT * INTO v_ai_settings
  FROM public.institution_ai_settings
  WHERE school_id = v_school_id;

  -- Contar consumo mensual
  SELECT count(*) INTO v_usage_count
  FROM public.ai_usage_ledger
  WHERE school_id = v_school_id
    AND created_at >= date_trunc('month', now())
    AND status = 'success';

  -- Contar consumo diario del docente
  SELECT count(*) INTO v_teacher_daily_count
  FROM public.ai_usage_ledger
  WHERE school_id = v_school_id
    AND user_id = v_caller_id
    AND created_at >= date_trunc('day', now())
    AND status = 'success';

  RETURN jsonb_build_object(
    'school_id', v_school_id,
    'module_enabled', v_feature_enabled,
    'subscription_status', COALESCE(v_sub_status, 'active'),
    'mode', COALESCE(v_ai_settings.mode, 'managed'),
    'provider', COALESCE(v_ai_settings.provider, 'gemini'),
    'model_id', COALESCE(v_ai_settings.model_id, 'gemini-2.5-flash'),
    'ai_status', COALESCE(v_ai_settings.status, 'active'),
    'monthly_quota', COALESCE(v_ai_settings.monthly_quota_generations, 200),
    'monthly_usage', v_usage_count,
    'teacher_daily_limit', COALESCE(v_ai_settings.teacher_daily_limit, 15),
    'teacher_daily_usage', v_teacher_daily_count,
    'is_limit_reached', (v_usage_count >= COALESCE(v_ai_settings.monthly_quota_generations, 200)),
    'is_teacher_limit_reached', (v_teacher_daily_count >= COALESCE(v_ai_settings.teacher_daily_limit, 15))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_ai_planning_access(uuid) TO authenticated, service_role;

-- 11. Habilitar RLS en todas las nuevas tablas
ALTER TABLE public.curriculum_catalogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.curriculum_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plan_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_plan_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_support_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_support_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.institution_ai_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_ledger ENABLE ROW LEVEL SECURITY;

-- Políticas de lectura para Catálogo Curricular (público para autenticados)
DROP POLICY IF EXISTS "curriculum_catalogs_read" ON public.curriculum_catalogs;
CREATE POLICY "curriculum_catalogs_read" ON public.curriculum_catalogs
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "curriculum_items_read" ON public.curriculum_items;
CREATE POLICY "curriculum_items_read" ON public.curriculum_items
FOR SELECT TO authenticated USING (true);

-- Políticas para lesson_plans
DROP POLICY IF EXISTS "lesson_plans_select" ON public.lesson_plans;
CREATE POLICY "lesson_plans_select" ON public.lesson_plans
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR teacher_id = auth.uid()
      OR public.has_tenant_permission('grades.read')
    )
  )
);

DROP POLICY IF EXISTS "lesson_plans_insert" ON public.lesson_plans;
CREATE POLICY "lesson_plans_insert" ON public.lesson_plans
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR teacher_id = auth.uid()
      OR public.has_tenant_permission('grades.create')
    )
  )
);

DROP POLICY IF EXISTS "lesson_plans_update" ON public.lesson_plans;
CREATE POLICY "lesson_plans_update" ON public.lesson_plans
FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
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
      OR teacher_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "lesson_plans_delete" ON public.lesson_plans;
CREATE POLICY "lesson_plans_delete" ON public.lesson_plans
FOR DELETE TO authenticated
USING (
  public.is_platform_admin()
  OR (
    (school_id = public.get_user_school_id() OR school_id IS NULL)
    AND (
      public.is_admin()
      OR teacher_id = auth.uid()
    )
  )
);

-- Políticas para lesson_plan_resources
DROP POLICY IF EXISTS "lesson_plan_resources_all" ON public.lesson_plan_resources;
CREATE POLICY "lesson_plan_resources_all" ON public.lesson_plan_resources
FOR ALL TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND (public.is_admin() OR teacher_id = auth.uid()))
);

-- Políticas para student_support_plans
DROP POLICY IF EXISTS "student_support_plans_all" ON public.student_support_plans;
CREATE POLICY "student_support_plans_all" ON public.student_support_plans
FOR ALL TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND (public.is_admin() OR teacher_id = auth.uid() OR public.has_tenant_permission('attendance.read')))
);

-- Políticas para institution_ai_settings
DROP POLICY IF EXISTS "institution_ai_settings_select" ON public.institution_ai_settings;
CREATE POLICY "institution_ai_settings_select" ON public.institution_ai_settings
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR school_id = public.get_user_school_id()
);

DROP POLICY IF EXISTS "institution_ai_settings_manage" ON public.institution_ai_settings;
CREATE POLICY "institution_ai_settings_manage" ON public.institution_ai_settings
FOR ALL TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.is_admin())
);

-- Políticas para ai_usage_ledger
DROP POLICY IF EXISTS "ai_usage_ledger_select" ON public.ai_usage_ledger;
CREATE POLICY "ai_usage_ledger_select" ON public.ai_usage_ledger
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND (public.is_admin() OR user_id = auth.uid()))
);

DROP POLICY IF EXISTS "ai_usage_ledger_insert" ON public.ai_usage_ledger;
CREATE POLICY "ai_usage_ledger_insert" ON public.ai_usage_ledger
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR school_id = public.get_user_school_id()
);

COMMIT;

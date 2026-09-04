-- ==============================================================================
-- MIGRACIÓN 51: SISTEMA SEGURO DE RETROALIMENTACIÓN, CUARENTENA Y MEMORIA DE IA
-- ==============================================================================
-- 1. Tabla de Logs de Feedback Docente con captura de Diffs estructurados
-- 2. Tabla de Cuarentena de Conocimiento (AI Knowledge Quarantine)
-- 3. Tabla de Memoria Institucional y Ejemplos Dorados Versionados (RAG seguro)
-- 4. Tabla de Auditoría de Evaluaciones de Modelos (ai_evaluation_runs)
-- 5. Tabla de Eventos de Auditoría Inmutables (ai_audit_events)
-- 6. Funciones RPC transaccionales con Rate Limiting y Deduplicación
-- 7. Políticas RLS multi-tenant estrictas
-- ==============================================================================

BEGIN;

-- 1. Tabla de Registro de Retroalimentación Docente (Feedback Logs)
CREATE TABLE IF NOT EXISTS public.ai_feedback_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL NOT NULL,
  target_type text NOT NULL, -- 'lesson_plan', 'section', 'resource', 'student_support'
  target_id uuid NOT NULL,
  section_key text, -- 'summary', 'didactic_sequence', 'evaluation_plan', 'inclusion_dua_plan', 'resources_plan'
  rating int CHECK (rating BETWEEN 1 AND 5) NOT NULL, -- 1: Pésimo/Inadecuado ... 5: Excelente
  sentiment text GENERATED ALWAYS AS (
    CASE 
      WHEN rating >= 4 THEN 'positive'
      WHEN rating = 3 THEN 'neutral'
      ELSE 'negative'
    END
  ) STORED,
  category text DEFAULT 'pedagogical' NOT NULL, -- pedagogical, curriculum, difficulty, format, methodology, institutional_preference, factual_error, style, resource_quality, other
  tags text[] DEFAULT ARRAY[]::text[],
  original_feedback text,
  sanitized_feedback text,
  diff_content jsonb DEFAULT '{}'::jsonb NOT NULL, -- { original: "...", edited: "...", changes: [] }
  confidence_score numeric(3, 2) DEFAULT 0.80 NOT NULL,
  risk_level text DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high')) NOT NULL,
  status text DEFAULT 'received' CHECK (status IN ('received', 'sanitized', 'classified', 'quarantined', 'approved', 'rejected', 'promoted', 'archived')) NOT NULL,
  raw_hash text, -- Para deduplicación anti-spam
  is_golden_candidate boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_feedback_school_status ON public.ai_feedback_logs(school_id, status);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_target ON public.ai_feedback_logs(target_id, target_type);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_user ON public.ai_feedback_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_hash ON public.ai_feedback_logs(raw_hash, created_at DESC);

-- 2. Zona de Cuarentena de Conocimiento (AI Knowledge Quarantine)
-- Ningún registro en esta tabla ingresa al RAG ni al System Prompt sin aprobación humana
CREATE TABLE IF NOT EXISTS public.ai_knowledge_quarantine (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  feedback_id uuid REFERENCES public.ai_feedback_logs(id) ON DELETE CASCADE NOT NULL,
  scope text DEFAULT 'institution' CHECK (scope IN ('user', 'institution', 'global')) NOT NULL,
  category text NOT NULL,
  sanitized_content text NOT NULL,
  candidate_guideline jsonb NOT NULL,
  confidence numeric(3, 2) DEFAULT 0.80 NOT NULL,
  risk_score numeric(3, 2) DEFAULT 0.10 NOT NULL,
  status text DEFAULT 'pending_review' CHECK (status IN ('pending_review', 'under_evaluation', 'approved', 'rejected')) NOT NULL,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_quarantine_school_status ON public.ai_knowledge_quarantine(school_id, status);
CREATE INDEX IF NOT EXISTS idx_ai_quarantine_feedback ON public.ai_knowledge_quarantine(feedback_id);

-- 3. Base de Conocimiento y Memoria Institucional Versionada (RAG Seguro)
CREATE TABLE IF NOT EXISTS public.ai_institutional_memory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE, -- NULL para conocimiento verificado 'global'
  scope text DEFAULT 'institution' CHECK (scope IN ('user', 'institution', 'global')) NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL, -- Solo aplica para scope='user'
  subject_name text NOT NULL, -- ej. 'Matemáticas', 'Lengua y Literatura', 'Ciencias Naturales'
  grade_year text, -- ej. '6to EGB', '1ro BGU' o NULL para general
  level text NOT NULL, -- inicial, basica_elemental, basica_media, basica_superior, bachillerato_general, bachillerato_tecnico
  memory_type text DEFAULT 'institutional_guideline' CHECK (memory_type IN ('few_shot_sample', 'institutional_guideline', 'pedagogical_caution', 'teacher_preference')) NOT NULL,
  title text NOT NULL,
  content_excerpt jsonb NOT NULL, -- Extracto estructurado sanitizado (guía de estilo, fragmento ERCA modelo, rúbrica modelo)
  version int DEFAULT 1 NOT NULL,
  supersedes_id uuid REFERENCES public.ai_institutional_memory(id) ON DELETE SET NULL, -- Trazabilidad de versiones y rollback
  confidence_score numeric(3, 2) DEFAULT 1.00 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  approved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  usage_count int DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_memory_retrieval ON public.ai_institutional_memory(school_id, subject_name, level, is_active);
CREATE INDEX IF NOT EXISTS idx_ai_memory_scope ON public.ai_institutional_memory(scope, is_active);
CREATE INDEX IF NOT EXISTS idx_ai_memory_supersedes ON public.ai_institutional_memory(supersedes_id);

-- 4. Registro de Evaluaciones de Modelos contra Golden Dataset
CREATE TABLE IF NOT EXISTS public.ai_evaluation_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id text NOT NULL,
  prompt_version text NOT NULL,
  knowledge_version int DEFAULT 1 NOT NULL,
  metrics jsonb NOT NULL, -- { curriculum_alignment: 0.95, pedagogical_quality: 0.92, hallucination_rate: 0.01, overall_score: 0.94 }
  dataset_size int NOT NULL,
  passed boolean NOT NULL,
  executed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_eval_runs_model ON public.ai_evaluation_runs(model_id, prompt_version, created_at DESC);

-- 5. Tabla de Auditoría Inmutable de Eventos de IA
CREATE TABLE IF NOT EXISTS public.ai_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type text NOT NULL, -- 'AI_FEEDBACK_CREATED', 'AI_FEEDBACK_REVIEWED', 'AI_KNOWLEDGE_APPROVED', 'AI_KNOWLEDGE_REJECTED', 'AI_KNOWLEDGE_PROMOTED', 'AI_PROMPT_VERSION_CHANGED', 'AI_KNOWLEDGE_VERSION_CHANGED'
  target_id uuid,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_audit_school_event ON public.ai_audit_events(school_id, event_type, created_at DESC);

-- 6. RPC: submit_ai_feedback con Rate Limiting y Deduplicación
CREATE OR REPLACE FUNCTION public.submit_ai_feedback(
  p_school_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_section_key text,
  p_rating int,
  p_category text,
  p_tags text[],
  p_sanitized_feedback text,
  p_diff_content jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_school_id uuid := COALESCE(p_school_id, public.get_user_school_id());
  v_raw_hash text;
  v_recent_count int := 0;
  v_hourly_count int := 0;
  v_feedback_id uuid;
  v_quarantine_id uuid := NULL;
  v_is_candidate boolean := false;
  v_confidence numeric(3, 2) := 0.85;
  v_risk text := 'low';
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  -- 1. Validar Rate Limiting (Máximo 20 feedbacks por usuario por hora)
  SELECT count(*) INTO v_hourly_count
  FROM public.ai_feedback_logs
  WHERE user_id = v_caller_id
    AND created_at >= (now() - interval '1 hour');

  IF v_hourly_count >= 20 THEN
    RAISE EXCEPTION 'Límite de retroalimentación alcanzado (máximo 20 envíos por hora).';
  END IF;

  -- 2. Deduplicación por Hash (Evitar doble clic en 60 segundos)
  v_raw_hash := md5(concat(v_caller_id::text, ':', p_target_id::text, ':', COALESCE(p_section_key, 'all'), ':', p_rating::text, ':', COALESCE(p_sanitized_feedback, '')));
  
  SELECT count(*) INTO v_recent_count
  FROM public.ai_feedback_logs
  WHERE raw_hash = v_raw_hash
    AND created_at >= (now() - interval '60 seconds');

  IF v_recent_count > 0 THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true, 'message', 'Retroalimentación ya registrada recientemente.');
  END IF;

  -- 3. Determinar si califica como candidato a conocimiento (ej. 5 estrellas con texto útil o corrección detallada)
  IF (p_rating >= 4 AND p_sanitized_feedback IS NOT NULL AND length(trim(p_sanitized_feedback)) >= 10)
     OR (p_diff_content IS NOT NULL AND p_diff_content != '{}'::jsonb) THEN
    v_is_candidate := true;
  END IF;

  -- 4. Insertar en ai_feedback_logs
  INSERT INTO public.ai_feedback_logs (
    school_id,
    user_id,
    target_type,
    target_id,
    section_key,
    rating,
    category,
    tags,
    sanitized_feedback,
    diff_content,
    confidence_score,
    risk_level,
    status,
    raw_hash,
    is_golden_candidate
  ) VALUES (
    v_school_id,
    v_caller_id,
    p_target_type,
    p_target_id,
    p_section_key,
    p_rating,
    COALESCE(p_category, 'pedagogical'),
    COALESCE(p_tags, ARRAY[]::text[]),
    p_sanitized_feedback,
    COALESCE(p_diff_content, '{}'::jsonb),
    v_confidence,
    v_risk,
    CASE WHEN v_is_candidate THEN 'quarantined' ELSE 'received' END,
    v_raw_hash,
    v_is_candidate
  )
  RETURNING id INTO v_feedback_id;

  -- 5. Si es candidato, ingresar a cuarentena para revisión humana (NUNCA directo a producción)
  IF v_is_candidate THEN
    INSERT INTO public.ai_knowledge_quarantine (
      school_id,
      feedback_id,
      scope,
      category,
      sanitized_content,
      candidate_guideline,
      confidence,
      risk_score,
      status
    ) VALUES (
      v_school_id,
      v_feedback_id,
      'institution',
      COALESCE(p_category, 'pedagogical'),
      COALESCE(p_sanitized_feedback, 'Corrección estructurada de documento'),
      jsonb_build_object(
        'target_type', p_target_type,
        'section_key', p_section_key,
        'rating', p_rating,
        'diff', p_diff_content
      ),
      v_confidence,
      0.05,
      'pending_review'
    )
    RETURNING id INTO v_quarantine_id;
  END IF;

  -- 6. Auditoría inmutable
  INSERT INTO public.ai_audit_events (
    school_id,
    user_id,
    event_type,
    target_id,
    details
  ) VALUES (
    v_school_id,
    v_caller_id,
    'AI_FEEDBACK_CREATED',
    v_feedback_id,
    jsonb_build_object(
      'target_type', p_target_type,
      'rating', p_rating,
      'quarantined', v_is_candidate
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'feedback_id', v_feedback_id,
    'quarantined', v_is_candidate,
    'quarantine_id', v_quarantine_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_ai_feedback(uuid, text, uuid, text, int, text, text[], text, jsonb) TO authenticated;

-- 7. RPC: get_institutional_ai_context (RAG optimizado delimitado)
CREATE OR REPLACE FUNCTION public.get_institutional_ai_context(
  p_school_id uuid,
  p_subject_name text,
  p_grade_year text,
  p_level text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid := COALESCE(p_school_id, public.get_user_school_id());
  v_guidelines jsonb;
  v_few_shots jsonb;
BEGIN
  -- Obtener lineamientos institucionales activos (Level 2)
  SELECT jsonb_agg(
    jsonb_build_object(
      'title', title,
      'memory_type', memory_type,
      'guideline', content_excerpt
    )
  ) INTO v_guidelines
  FROM (
    SELECT title, memory_type, content_excerpt
    FROM public.ai_institutional_memory
    WHERE is_active = true
      AND (school_id = v_school_id OR scope = 'global')
      AND (subject_name = p_subject_name OR subject_name = 'General')
      AND level = p_level
      AND memory_type = 'institutional_guideline'
    ORDER BY usage_count DESC, created_at DESC
    LIMIT 2
  ) sub_g;

  -- Obtener ejemplos dorados verificados (Top-1)
  SELECT jsonb_agg(
    jsonb_build_object(
      'title', title,
      'example', content_excerpt
    )
  ) INTO v_few_shots
  FROM (
    SELECT title, content_excerpt
    FROM public.ai_institutional_memory
    WHERE is_active = true
      AND (school_id = v_school_id OR scope = 'global')
      AND subject_name = p_subject_name
      AND level = p_level
      AND memory_type = 'few_shot_sample'
    ORDER BY confidence_score DESC, usage_count DESC
    LIMIT 1
  ) sub_f;

  RETURN jsonb_build_object(
    'has_context', (v_guidelines IS NOT NULL OR v_few_shots IS NOT NULL),
    'guidelines', COALESCE(v_guidelines, '[]'::jsonb),
    'few_shot_examples', COALESCE(v_few_shots, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_institutional_ai_context(uuid, text, text, text) TO authenticated;

-- 8. RPC: review_quarantine_item (Revisión y Aprobación Humana de Cuarentena)
CREATE OR REPLACE FUNCTION public.review_quarantine_item(
  p_quarantine_id uuid,
  p_action text, -- 'approve', 'reject'
  p_review_notes text DEFAULT NULL,
  p_target_scope text DEFAULT 'institution'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_quarantine record;
  v_feedback record;
  v_new_memory_id uuid := NULL;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado.';
  END IF;

  -- Verificar permisos de administración
  IF NOT (public.is_admin() OR public.is_platform_admin()) THEN
    RAISE EXCEPTION 'No tiene permisos para revisar elementos de cuarentena.';
  END IF;

  SELECT * INTO v_quarantine
  FROM public.ai_knowledge_quarantine
  WHERE id = p_quarantine_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Registro de cuarentena no encontrado.';
  END IF;

  SELECT * INTO v_feedback
  FROM public.ai_feedback_logs
  WHERE id = v_quarantine.feedback_id;

  IF p_action = 'approve' THEN
    -- Actualizar estado de cuarentena
    UPDATE public.ai_knowledge_quarantine
    SET status = 'approved',
        reviewed_by = v_caller_id,
        reviewed_at = timezone('utc'::text, now()),
        review_notes = p_review_notes
    WHERE id = p_quarantine_id;

    -- Actualizar estado en feedback log
    UPDATE public.ai_feedback_logs
    SET status = 'approved'
    WHERE id = v_quarantine.feedback_id;

    -- Promover a ai_institutional_memory
    INSERT INTO public.ai_institutional_memory (
      school_id,
      scope,
      subject_name,
      level,
      memory_type,
      title,
      content_excerpt,
      confidence_score,
      is_active,
      approved_by,
      approved_at
    ) VALUES (
      CASE WHEN p_target_scope = 'global' THEN NULL ELSE v_quarantine.school_id END,
      p_target_scope,
      'General',
      'basica_media',
      'institutional_guideline',
      concat('Guía Validada: ', substring(v_quarantine.sanitized_content from 1 for 40)),
      v_quarantine.candidate_guideline,
      1.00,
      true,
      v_caller_id,
      timezone('utc'::text, now())
    )
    RETURNING id INTO v_new_memory_id;

    -- Auditoría
    INSERT INTO public.ai_audit_events (
      school_id,
      user_id,
      event_type,
      target_id,
      details
    ) VALUES (
      v_quarantine.school_id,
      v_caller_id,
      'AI_KNOWLEDGE_APPROVED',
      v_new_memory_id,
      jsonb_build_object('quarantine_id', p_quarantine_id, 'scope', p_target_scope)
    );

    RETURN jsonb_build_object('success', true, 'status', 'approved', 'memory_id', v_new_memory_id);
  ELSE
    -- Rechazar
    UPDATE public.ai_knowledge_quarantine
    SET status = 'rejected',
        reviewed_by = v_caller_id,
        reviewed_at = timezone('utc'::text, now()),
        review_notes = p_review_notes
    WHERE id = p_quarantine_id;

    UPDATE public.ai_feedback_logs
    SET status = 'rejected'
    WHERE id = v_quarantine.feedback_id;

    INSERT INTO public.ai_audit_events (
      school_id,
      user_id,
      event_type,
      target_id,
      details
    ) VALUES (
      v_quarantine.school_id,
      v_caller_id,
      'AI_KNOWLEDGE_REJECTED',
      p_quarantine_id,
      jsonb_build_object('notes', p_review_notes)
    );

    RETURN jsonb_build_object('success', true, 'status', 'rejected');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_quarantine_item(uuid, text, text, text) TO authenticated;

-- 9. Habilitar RLS en todas las nuevas tablas
ALTER TABLE public.ai_feedback_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_quarantine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_institutional_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evaluation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_audit_events ENABLE ROW LEVEL SECURITY;

-- Políticas para ai_feedback_logs
DROP POLICY IF EXISTS "ai_feedback_select" ON public.ai_feedback_logs;
CREATE POLICY "ai_feedback_select" ON public.ai_feedback_logs
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND (public.is_admin() OR user_id = auth.uid()))
);

DROP POLICY IF EXISTS "ai_feedback_insert" ON public.ai_feedback_logs;
CREATE POLICY "ai_feedback_insert" ON public.ai_feedback_logs
FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR school_id = public.get_user_school_id()
);

-- Políticas para ai_knowledge_quarantine
DROP POLICY IF EXISTS "ai_quarantine_all" ON public.ai_knowledge_quarantine;
CREATE POLICY "ai_quarantine_all" ON public.ai_knowledge_quarantine
FOR ALL TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.is_admin())
);

-- Políticas para ai_institutional_memory
DROP POLICY IF EXISTS "ai_memory_select" ON public.ai_institutional_memory;
CREATE POLICY "ai_memory_select" ON public.ai_institutional_memory
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR scope = 'global'
  OR school_id = public.get_user_school_id()
);

DROP POLICY IF EXISTS "ai_memory_manage" ON public.ai_institutional_memory;
CREATE POLICY "ai_memory_manage" ON public.ai_institutional_memory
FOR ALL TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.is_admin())
);

-- Políticas para ai_evaluation_runs
DROP POLICY IF EXISTS "ai_eval_runs_select" ON public.ai_evaluation_runs;
CREATE POLICY "ai_eval_runs_select" ON public.ai_evaluation_runs
FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "ai_eval_runs_insert" ON public.ai_evaluation_runs;
CREATE POLICY "ai_eval_runs_insert" ON public.ai_evaluation_runs
FOR INSERT TO authenticated
WITH CHECK (public.is_platform_admin() OR public.is_admin());

-- Políticas para ai_audit_events
DROP POLICY IF EXISTS "ai_audit_events_select" ON public.ai_audit_events;
CREATE POLICY "ai_audit_events_select" ON public.ai_audit_events
FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR (school_id = public.get_user_school_id() AND public.is_admin())
);

COMMIT;

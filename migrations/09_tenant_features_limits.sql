-- ====================================================================
-- MIGRATION: 09_tenant_features_limits.sql
-- PURPOSE: FASE 9 (Feature Flags por Tenant) y FASE 10 (Límites Configurables)
-- ====================================================================

-- 1. TENANT FEATURES TABLE (Módulos por Institución)
CREATE TABLE IF NOT EXISTS public.tenant_features (
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    feature_key text NOT NULL, -- grades, attendance, enrollment, reports, projects, lms, payments, ai, api
    enabled boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (school_id, feature_key)
);

-- Inicializar módulos por defecto para escuelas existentes
DO $$
DECLARE
    sch_rec RECORD;
    feat text;
    feats text[] := ARRAY['grades', 'attendance', 'enrollment', 'reports', 'projects', 'alerts'];
BEGIN
    FOR sch_rec IN SELECT id FROM public.schools LOOP
        FOREACH feat IN ARRAY feats LOOP
            INSERT INTO public.tenant_features (school_id, feature_key, enabled)
            VALUES (sch_rec.id, feat, true)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END FOR;
END $$;

-- 2. TENANT LIMITS TABLE
CREATE TABLE IF NOT EXISTS public.tenant_limits (
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE PRIMARY KEY,
    max_users integer DEFAULT 50 NOT NULL,
    max_teachers integer DEFAULT 20 NOT NULL,
    max_students integer DEFAULT 500 NOT NULL,
    storage_mb integer DEFAULT 5120 NOT NULL, -- MBs
    max_documents integer DEFAULT 1000 NOT NULL,
    max_emails_month integer DEFAULT 5000 NOT NULL,
    max_api_requests integer DEFAULT 100000 NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Inicializar límites para escuelas existentes
DO $$
DECLARE
    sch_rec RECORD;
BEGIN
    FOR sch_rec IN SELECT id FROM public.schools LOOP
        INSERT INTO public.tenant_limits (school_id, max_users, max_teachers, max_students, storage_mb)
        VALUES (sch_rec.id, 100, 50, 1500, 20480)
        ON CONFLICT DO NOTHING;
    END FOR;
END $$;

-- 3. FUNCIÓN RPC PARA OBTENER USO Y PORCENTAJES DE LÍMITES POR TENANT
CREATE OR REPLACE FUNCTION public.get_tenant_usage_stats(p_school_id uuid)
RETURNS json AS $$
DECLARE
    v_limits record;
    v_count_users integer := 0;
    v_count_teachers integer := 0;
    v_count_students integer := 0;
    v_storage_bytes bigint := 0;
    v_storage_mb numeric := 0;
BEGIN
    -- Obtener límites
    SELECT * INTO v_limits FROM public.tenant_limits WHERE school_id = p_school_id;
    IF v_limits IS NULL THEN
        -- Retornar valores por defecto si no hay registro
        v_limits := ROW(p_school_id, 50, 20, 500, 5120, 1000, 5000, 100000, now());
    END IF;

    -- Constar usuarios de la escuela
    SELECT count(*) INTO v_count_users 
    FROM public.profiles 
    WHERE school_id = p_school_id;

    -- Contar docentes de la escuela
    SELECT count(*) INTO v_count_teachers 
    FROM public.profiles 
    WHERE school_id = p_school_id AND role = 'teacher';

    -- Contar estudiantes de la escuela
    SELECT count(*) INTO v_count_students 
    FROM public.students 
    WHERE school_id = p_school_id;

    -- Estimado de storage (si existe bucket metadata)
    SELECT COALESCE(sum((metadata->>'size')::bigint), 0) INTO v_storage_bytes
    FROM storage.objects
    WHERE bucket_id IN ('student-photos', 'institution-assets');

    v_storage_mb := round((v_storage_bytes / (1024.0 * 1024.0))::numeric, 2);

    RETURN json_build_object(
        'users', json_build_object('current', v_count_users, 'limit', v_limits.max_users, 'percentage', round((v_count_users::numeric / GREATEST(v_limits.max_users, 1)) * 100, 1)),
        'teachers', json_build_object('current', v_count_teachers, 'limit', v_limits.max_teachers, 'percentage', round((v_count_teachers::numeric / GREATEST(v_limits.max_teachers, 1)) * 100, 1)),
        'students', json_build_object('current', v_count_students, 'limit', v_limits.max_students, 'percentage', round((v_count_students::numeric / GREATEST(v_limits.max_students, 1)) * 100, 1)),
        'storage', json_build_object('current_mb', v_storage_mb, 'limit_mb', v_limits.storage_mb, 'percentage', round((v_storage_mb / GREATEST(v_limits.storage_mb, 1)) * 100, 1))
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

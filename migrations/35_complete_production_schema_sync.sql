-- ==============================================================================
-- MIGRACIÓN 35: Sincronización Maestra y Consolidación de Esquema para Producción
-- ==============================================================================
-- Esta migración es 100% IDEMPOTENTE (se puede ejecutar múltiples veces de forma segura).
-- Agrupa todas las mejoras de aislamiento, columnas de tutores, claves foráneas,
-- eliminación en cascada, buckets de almacenamiento y funciones RPC esenciales.

BEGIN;

-- 1. Esquema privado para funciones internas
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM public, anon, authenticated;

-- 1.1 Triggers de seguridad compatibles con ejecuciones administrativas (auth.uid() is null)
CREATE OR REPLACE FUNCTION public.protect_profile_authorization_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR public.is_platform_admin() THEN
    RETURN NEW;
  END IF;

  IF OLD.school_id = public.get_user_school_id()
     AND public.has_tenant_permission('users.manage') THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.email IS DISTINCT FROM OLD.email
       OR NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.role = 'superadmin' THEN
      RAISE EXCEPTION 'Campos de autorización protegidos' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.id = (SELECT auth.uid()) THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.email IS DISTINCT FROM OLD.email
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION 'Campos de autorización protegidos' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Perfil no autorizado' USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public.set_school_id_from_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  actor_school_id uuid := public.get_user_school_id();
BEGIN
  IF (SELECT auth.uid()) IS NULL OR public.is_platform_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.school_id IS NULL THEN
    NEW.school_id := actor_school_id;
  END IF;
  IF actor_school_id IS NULL OR NEW.school_id IS DISTINCT FROM actor_school_id THEN
    RAISE EXCEPTION 'Tenant no autorizado' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Asegurar columnas esenciales en tablas públicas
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS tutor_name text;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS receipt_url text;
ALTER TABLE public.tenant_billing_profiles ADD COLUMN IF NOT EXISTS latest_receipt_url text;

-- 3. Vincular registros huérfanos al colegio principal si school_id es null
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

-- 4. Restricción de unicidad de años lectivos aislada por institución y compatibilidad de campos
ALTER TABLE public.academic_years DROP CONSTRAINT IF EXISTS academic_years_name_key;
ALTER TABLE public.academic_years ALTER COLUMN start_year DROP NOT NULL;
ALTER TABLE public.academic_years ALTER COLUMN end_year DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'academic_years_school_id_name_key'
  ) THEN
    ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_school_id_name_key UNIQUE (school_id, name);
  END IF;
END $$;

-- 4.1 Trigger para auto-completar start_year, end_year y school_id en academic_years
CREATE OR REPLACE FUNCTION public.auto_fill_academic_year_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_first_year integer;
  v_second_year integer;
BEGIN
  IF NEW.name IS NOT NULL THEN
    v_first_year := NULLIF(substring(NEW.name FROM '([0-9]{4})'), '')::integer;
    v_second_year := NULLIF(substring(NEW.name FROM '[0-9]{4}.*?([0-9]{4})'), '')::integer;
  END IF;

  IF NEW.start_year IS NULL THEN
    NEW.start_year := COALESCE(v_first_year, extract(year FROM now())::integer);
  END IF;

  IF NEW.end_year IS NULL THEN
    NEW.end_year := COALESCE(v_second_year, NEW.start_year + 1);
  END IF;

  IF NEW.school_id IS NULL THEN
    NEW.school_id := public.get_user_school_id();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_fill_academic_year_fields ON public.academic_years;
CREATE TRIGGER auto_fill_academic_year_fields
BEFORE INSERT OR UPDATE ON public.academic_years
FOR EACH ROW
EXECUTE FUNCTION public.auto_fill_academic_year_fields();

DROP TRIGGER IF EXISTS set_academic_years_school_id ON public.academic_years;
CREATE TRIGGER set_academic_years_school_id
BEFORE INSERT ON public.academic_years
FOR EACH ROW
EXECUTE FUNCTION public.set_school_id_from_auth();

-- 4.2 Políticas RLS robustas para academic_years
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "academic_years_select" ON public.academic_years;
DROP POLICY IF EXISTS "academic_years_insert" ON public.academic_years;
DROP POLICY IF EXISTS "academic_years_update" ON public.academic_years;
DROP POLICY IF EXISTS "academic_years_delete" ON public.academic_years;
DROP POLICY IF EXISTS "academic_years_manage" ON public.academic_years;

CREATE POLICY "academic_years_select" ON public.academic_years FOR SELECT TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR school_id IS NULL
);

CREATE POLICY "academic_years_insert" ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR (school_id IS NULL AND public.get_user_school_id() IS NOT NULL)
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
);

CREATE POLICY "academic_years_update" ON public.academic_years FOR UPDATE TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
)
WITH CHECK (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
);

CREATE POLICY "academic_years_delete" ON public.academic_years FOR DELETE TO authenticated
USING (
  public.is_platform_admin() 
  OR school_id = public.get_user_school_id()
  OR public.has_tenant_permission('settings.manage')
  OR public.is_admin()
  OR public.is_superadmin()
);

-- 5. Claves foráneas y eliminación en cascada de perfiles y membresías
DO $$
BEGIN
  -- profiles -> auth.users CASCADE
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_id_fkey') THEN
    ALTER TABLE public.profiles DROP CONSTRAINT profiles_id_fkey;
  END IF;
  ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

  -- tenant_memberships -> profiles CASCADE
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenant_memberships_user_id_fkey') THEN
    ALTER TABLE public.tenant_memberships DROP CONSTRAINT tenant_memberships_user_id_fkey;
  END IF;
  ALTER TABLE public.tenant_memberships ADD CONSTRAINT tenant_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

  -- tenant_billing_profiles -> schools CASCADE
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenant_billing_profiles_school_id_fkey') THEN
    ALTER TABLE public.tenant_billing_profiles DROP CONSTRAINT tenant_billing_profiles_school_id_fkey;
  END IF;
  ALTER TABLE public.tenant_billing_profiles ADD CONSTRAINT tenant_billing_profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Aviso al ajustar foreign keys: %', SQLERRM;
END $$;

-- 6. Índices de cobertura de alto rendimiento
CREATE INDEX IF NOT EXISTS idx_courses_school_id ON public.courses(school_id);
CREATE INDEX IF NOT EXISTS idx_courses_academic_year ON public.courses(academic_year);
CREATE INDEX IF NOT EXISTS idx_academic_years_school_id ON public.academic_years(school_id);
CREATE INDEX IF NOT EXISTS idx_course_subjects_course_school ON public.course_subjects(school_id, course_id);
CREATE INDEX IF NOT EXISTS idx_students_course_school ON public.students(school_id, course_id);
CREATE INDEX IF NOT EXISTS idx_grades_student_definition ON public.grades(student_id, grade_definition_id);
CREATE INDEX IF NOT EXISTS idx_payments_school_id ON public.payments(school_id);
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user_school ON public.tenant_memberships(user_id, school_id);

-- 7. Buckets de almacenamiento de Storage para la plataforma
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),
  ('institution-logos', 'institution-logos', true),
  ('billing-proofs', 'billing-proofs', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  -- Policies para avatars
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload avatars' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Authenticated users can upload avatars" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view avatars' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Anyone can view avatars" ON storage.objects FOR SELECT TO public USING (bucket_id = 'avatars');
  END IF;

  -- Policies para institution-logos
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload logos' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Authenticated users can upload logos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'institution-logos');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view logos' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Anyone can view logos" ON storage.objects FOR SELECT TO public USING (bucket_id = 'institution-logos');
  END IF;

  -- Policies para billing-proofs
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload billing proofs' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Authenticated users can upload billing proofs" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'billing-proofs');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can view billing proofs' AND tablename = 'objects' AND schemaname = 'storage') THEN
    CREATE POLICY "Authenticated users can view billing proofs" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'billing-proofs');
  END IF;
END $$;

-- 8. Sincronización de dimensiones de calificaciones (Trigger canónico)
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
  v_definition_course_id uuid;
  v_student_school_id uuid;
  v_student_course_id uuid;
BEGIN
  SELECT gd.course_subject_id, gd.quarter_id, gd.school_id, cs.course_id
  INTO v_course_subject_id, v_quarter_id, v_definition_school_id, v_definition_course_id
  FROM public.grade_definitions gd
  JOIN public.course_subjects cs ON cs.id = gd.course_subject_id
  WHERE gd.id = NEW.grade_definition_id;

  IF v_course_subject_id IS NOT NULL AND v_quarter_id IS NOT NULL THEN
    NEW.course_subject_id := v_course_subject_id;
    NEW.quarter_id := v_quarter_id;
    NEW.school_id := v_definition_school_id;
  END IF;

  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS synchronize_grade_dimensions_from_definition ON public.grades;
CREATE TRIGGER synchronize_grade_dimensions_from_definition
BEFORE INSERT OR UPDATE ON public.grades
FOR EACH ROW
EXECUTE FUNCTION private.synchronize_grade_dimensions_from_definition();

-- 9. RPC para eliminación integral de instituciones (Tenants)
CREATE OR REPLACE FUNCTION public.delete_tenant(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_school_name text;
    v_is_admin boolean;
    v_user_ids uuid[];
    v_deleted_users_count integer := 0;
BEGIN
    SELECT (
        public.is_platform_admin() OR public.is_platform_owner() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin')
    ) INTO v_is_admin;

    IF NOT COALESCE(v_is_admin, false) THEN
        RAISE EXCEPTION 'Acceso denegado. Solo los administradores de la plataforma pueden eliminar instituciones.';
    END IF;

    SELECT name INTO v_school_name FROM public.schools WHERE id = p_school_id;
    IF v_school_name IS NULL THEN
        RAISE EXCEPTION 'Institución no encontrada.';
    END IF;

    SELECT array_agg(id) INTO v_user_ids
    FROM public.profiles
    WHERE school_id = p_school_id AND role != 'superadmin';

    -- Limpieza en cascada de datos académicos
    DELETE FROM public.grades WHERE school_id = p_school_id 
        OR student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    DELETE FROM public.grade_definitions WHERE school_id = p_school_id;
    DELETE FROM public.course_subjects WHERE school_id = p_school_id;
    DELETE FROM public.student_alerts WHERE school_id = p_school_id;
    DELETE FROM public.students WHERE school_id = p_school_id;
    DELETE FROM public.courses WHERE school_id = p_school_id;
    DELETE FROM public.subjects WHERE school_id = p_school_id;
    DELETE FROM public.quarters WHERE school_id = p_school_id;
    DELETE FROM public.academic_years WHERE school_id = p_school_id;

    -- Limpieza de suscripciones, pagos y membresías
    DELETE FROM public.payments WHERE school_id = p_school_id;
    DELETE FROM public.tenant_billing_profiles WHERE school_id = p_school_id;
    DELETE FROM public.tenant_memberships WHERE school_id = p_school_id;
    DELETE FROM public.audit_log WHERE school_id = p_school_id;

    -- Eliminación de perfiles y usuarios de Auth
    IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
        v_deleted_users_count := array_length(v_user_ids, 1);
        DELETE FROM public.profiles WHERE id = ANY(v_user_ids);
        DELETE FROM auth.users WHERE id = ANY(v_user_ids);
    END IF;

    UPDATE public.profiles SET school_id = NULL WHERE school_id = p_school_id;
    DELETE FROM public.schools WHERE id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_users', v_deleted_users_count,
        'message', format('La institución "%s" y sus datos fueron eliminados correctamente.', v_school_name)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_tenant(uuid) TO authenticated;

-- 10. RPC para registro de comprobantes de pago / transferencia
CREATE OR REPLACE FUNCTION public.upload_tenant_payment_proof(
    p_school_id uuid,
    p_receipt_url text,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_subscription_id uuid;
    v_sub_price numeric;
BEGIN
    IF NOT (public.is_platform_admin() OR (public.get_user_school_id() = p_school_id AND public.has_tenant_permission('billing.manage'))) THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado para esta institución.');
    END IF;

    IF nullif(trim(p_receipt_url), '') IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Se requiere la URL o foto del comprobante.');
    END IF;

    INSERT INTO public.tenant_billing_profiles (school_id, latest_receipt_url, updated_at)
    VALUES (p_school_id, trim(p_receipt_url), timezone('utc'::text, now()))
    ON CONFLICT (school_id) DO UPDATE
    SET latest_receipt_url = EXCLUDED.latest_receipt_url,
        updated_at = timezone('utc'::text, now());

    INSERT INTO public.payments (
        school_id, amount, currency, provider,
        status, paid_at, payment_type, notes, receipt_url, recorded_by
    ) VALUES (
        p_school_id, 0, 'USD', 'transfer',
        'pending', timezone('utc'::text, now()), 'subscription',
        nullif(trim(p_notes), ''), trim(p_receipt_url), auth.uid()
    );

    RETURN json_build_object('success', true, 'message', 'Comprobante de pago registrado exitosamente.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.upload_tenant_payment_proof(uuid, text, text) TO authenticated;

-- 11. RPC canónico get_my_access_context y permisos para autenticación y superadministradores
CREATE OR REPLACE FUNCTION public.get_my_access_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_platform_admin boolean := false;
  v_is_platform_owner boolean := false;
  v_platform_roles jsonb := '[]'::jsonb;
  v_default_school_id uuid;
  v_memberships jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'user_id', null,
      'is_platform_admin', false,
      'is_platform_owner', false,
      'platform_roles', '[]'::jsonb,
      'default_school_id', null,
      'memberships', '[]'::jsonb
    );
  END IF;

  v_is_platform_admin := public.is_platform_admin();
  v_is_platform_owner := public.is_platform_owner();

  -- Respaldo directo si el perfil es superadmin
  IF NOT coalesce(v_is_platform_admin, false) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = v_uid AND role = 'superadmin' AND coalesce(is_active, true)
    ) INTO v_is_platform_admin;
  END IF;

  SELECT coalesce(
    jsonb_agg(pr.name::text ORDER BY pr.name::text),
    '[]'::jsonb
  ) INTO v_platform_roles
  FROM public.user_platform_roles upr
  JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
  WHERE upr.user_id = v_uid;

  IF v_is_platform_admin AND (v_platform_roles = '[]'::jsonb OR v_platform_roles IS NULL) THEN
    v_platform_roles := '["platform_admin", "platform_owner"]'::jsonb;
    v_is_platform_owner := true;
  END IF;

  v_default_school_id := public.get_user_school_id();

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'school_id', tm.school_id,
        'role', tr.name::text,
        'permissions', coalesce(
          (
            SELECT jsonb_agg(p.code ORDER BY p.code)
            FROM public.role_permissions rp
            JOIN public.permissions p ON p.id = rp.permission_id
            WHERE rp.tenant_role_id = tm.tenant_role_id
          ),
          '[]'::jsonb
        )
      )
      ORDER BY tm.created_at, tm.school_id
    ),
    '[]'::jsonb
  ) INTO v_memberships
  FROM public.tenant_memberships tm
  JOIN public.tenant_roles tr ON tr.id = tm.tenant_role_id
  WHERE tm.user_id = v_uid
    AND tm.is_active = true;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'is_platform_admin', coalesce(v_is_platform_admin, false),
    'is_platform_owner', coalesce(v_is_platform_owner, false),
    'platform_roles', coalesce(v_platform_roles, '[]'::jsonb),
    'default_school_id', v_default_school_id,
    'memberships', coalesce(v_memberships, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_access_context() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_owner() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO anon, authenticated, service_role;

-- 12. Recargar caché de PostgREST para reflejar todos los cambios de inmediato
NOTIFY pgrst, 'reload schema';

COMMIT;

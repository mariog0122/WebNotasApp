-- ==============================================================================
-- MIGRACIÓN 42 (CONSOLIDADO MAESTRO): Sincronización de RPCs y Permisos Faltantes
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 0. DROPS PREVENTIVOS DE FUNCIONES CON CAMBIO DE TIPO DE RETORNO
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.delete_tenant(uuid);
DROP FUNCTION IF EXISTS public.set_tenant_status(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.set_tenant_status(uuid, public.tenant_status_type, text, text);
DROP FUNCTION IF EXISTS public.set_tenant_status(uuid, text, text);
DROP FUNCTION IF EXISTS public.record_manual_payment(uuid, numeric, text, text, timestamptz, text, text);
DROP FUNCTION IF EXISTS public.record_manual_payment(uuid, numeric, text, text, timestamptz, text);
DROP FUNCTION IF EXISTS public.upload_tenant_payment_proof(uuid, text, text);
DROP FUNCTION IF EXISTS public.get_tenant_usage_stats(uuid);
DROP FUNCTION IF EXISTS public.copy_courses_to_academic_year(uuid, text, text);

-- ------------------------------------------------------------------------------
-- 1. FUNCIÓN: has_platform_role (Sin drop, actualización directa)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_platform_role(p_roles text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.user_platform_roles upr
      JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
      WHERE upr.user_id = auth.uid()
        AND pr.name::text = ANY(p_roles)
    )
    OR (
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'superadmin'
          AND COALESCE(p.is_active, true)
      )
      AND p_roles && ARRAY['platform_owner', 'platform_admin', 'platform_support', 'platform_finance']::text[]
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_platform_role(text[]) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 2. FUNCIÓN: set_tenant_status (Suspender / Reactivar / Cancelar Institución)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_tenant_status(
  p_school_id uuid,
  p_new_status text,
  p_reason text DEFAULT 'Modificación por Superadmin',
  p_observation text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_previous_status text;
  v_user_role text;
  v_is_authorized boolean := false;
BEGIN
  SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();
  
  IF public.is_platform_admin() 
     OR v_user_role = 'superadmin'
     OR public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_support']) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Acceso denegado: Se requiere rol de Superadmin para cambiar el estado de la institución.' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('active', 'trial', 'past_due', 'suspended', 'cancelled') THEN
    RAISE EXCEPTION 'Estado no válido: %', p_new_status USING ERRCODE = '22023';
  END IF;

  SELECT status::text INTO v_previous_status
  FROM public.schools
  WHERE id = p_school_id
  FOR UPDATE;

  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'Institución no encontrada' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.schools
  SET status = p_new_status,
      is_active = (p_new_status = 'active' OR p_new_status = 'trial'),
      suspended_reason = CASE WHEN p_new_status = 'suspended' THEN COALESCE(nullif(trim(p_reason), ''), 'Suspendido por SuperAdmin') ELSE NULL END,
      suspended_at = CASE WHEN p_new_status = 'suspended' THEN timezone('utc'::text, now()) ELSE NULL END,
      suspended_by = CASE WHEN p_new_status = 'suspended' THEN auth.uid() ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_school_id;

  UPDATE public.subscriptions
  SET status = p_new_status,
      cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN timezone('utc'::text, now()) ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE school_id = p_school_id;

  IF to_regclass('public.tenant_status_logs') IS NOT NULL THEN
    BEGIN
      INSERT INTO public.tenant_status_logs (
        school_id, previous_status, new_status, reason, observation, actor_id
      ) VALUES (
        p_school_id, v_previous_status, p_new_status, COALESCE(nullif(trim(p_reason), ''), 'Cambio de estado'), nullif(trim(p_observation), ''), auth.uid()
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN json_build_object(
    'success', true, 
    'previous_status', v_previous_status, 
    'new_status', p_new_status,
    'message', 'Estado actualizado exitosamente.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_tenant_status(uuid, text, text, text) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 3. FUNCIÓN: record_manual_payment (Conciliación y Renovación de Pagos)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_manual_payment(
  p_school_id uuid,
  p_amount numeric,
  p_provider_reference text,
  p_external_invoice_number text,
  p_paid_at timestamptz,
  p_notes text,
  p_receipt_url text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_sub RECORD;
  v_next_billing timestamptz;
  v_payment_id uuid;
  v_clean_receipt_url text;
  v_cycle text;
  v_calc_base timestamptz;
  v_is_authorized boolean := false;
  v_user_role text;
BEGIN
  SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();
  
  IF public.is_platform_admin() 
     OR v_user_role = 'superadmin'
     OR public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Acceso denegado: Se requiere rol de Superadmin para registrar pagos.' USING ERRCODE = '42501';
  END IF;

  v_clean_receipt_url := nullif(trim(p_receipt_url), '');

  SELECT s.*, p.monthly_price, p.annual_price, p.trial_days, p.name AS plan_name
  INTO v_sub
  FROM public.subscriptions s
  LEFT JOIN public.plans p ON p.id = s.plan_id
  WHERE s.school_id = p_school_id
  FOR UPDATE;

  IF v_sub.id IS NULL THEN
    RAISE EXCEPTION 'No se encontró suscripción para esta institución.' USING ERRCODE = 'P0002';
  END IF;

  v_cycle := COALESCE(v_sub.billing_cycle, 'monthly');
  v_calc_base := COALESCE(v_sub.next_billing_date, v_sub.trial_ends_at, timezone('utc'::text, now()));
  IF v_calc_base < timezone('utc'::text, now()) THEN
    v_calc_base := timezone('utc'::text, now());
  END IF;

  IF v_cycle = 'yearly' THEN
    v_next_billing := v_calc_base + INTERVAL '1 year';
  ELSE
    v_next_billing := v_calc_base + INTERVAL '1 month';
  END IF;

  INSERT INTO public.payments (
    school_id, amount, currency, provider, provider_reference,
    external_invoice_number, status, paid_at, payment_type, notes, receipt_url, recorded_by
  ) VALUES (
    p_school_id, p_amount, 'USD', 'manual_transfer', trim(p_provider_reference),
    trim(p_external_invoice_number), 'completed', p_paid_at, 'subscription',
    nullif(trim(p_notes), ''), v_clean_receipt_url, auth.uid()
  ) RETURNING id INTO v_payment_id;

  UPDATE public.subscriptions
  SET status = 'active',
      next_billing_date = v_next_billing,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_sub.id;

  UPDATE public.schools
  SET status = 'active',
      is_active = true,
      suspended_reason = NULL,
      suspended_at = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_school_id;

  INSERT INTO public.tenant_billing_profiles (
    school_id, implementation_fee_status, latest_receipt_url, updated_at
  ) VALUES (
    p_school_id, 'paid', v_clean_receipt_url, timezone('utc'::text, now())
  )
  ON CONFLICT (school_id) DO UPDATE
  SET implementation_fee_status = 'paid',
      latest_receipt_url = COALESCE(v_clean_receipt_url, tenant_billing_profiles.latest_receipt_url),
      updated_at = timezone('utc'::text, now());

  RETURN json_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'next_billing_date', v_next_billing,
    'status', 'active',
    'message', 'Pago registrado y suscripción renovada exitosamente.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text, text) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 4. FUNCIÓN: upload_tenant_payment_proof (Carga de Comprobante por Colegio)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upload_tenant_payment_proof(
    p_school_id uuid,
    p_receipt_url text,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_clean_url text;
    v_payment_id uuid;
    v_user_role text;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();

    IF NOT (
        public.is_platform_admin()
        OR v_user_role IN ('superadmin', 'admin', 'school_admin', 'rector')
        OR public.get_user_school_id() = p_school_id
        OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
        OR EXISTS (SELECT 1 FROM public.tenant_memberships WHERE user_id = auth.uid() AND school_id = p_school_id AND is_active)
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado para registrar comprobante.');
    END IF;

    v_clean_url := nullif(trim(p_receipt_url), '');
    IF v_clean_url IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Se requiere la URL o archivo del comprobante.');
    END IF;

    INSERT INTO public.tenant_billing_profiles (school_id, latest_receipt_url, updated_at)
    VALUES (p_school_id, v_clean_url, timezone('utc'::text, now()))
    ON CONFLICT (school_id) DO UPDATE
    SET latest_receipt_url = EXCLUDED.latest_receipt_url,
        updated_at = timezone('utc'::text, now());

    INSERT INTO public.payments (
        school_id, amount, currency, provider,
        status, paid_at, payment_type, notes, receipt_url, recorded_by
    ) VALUES (
        p_school_id, 0, 'USD', 'transfer',
        'pending', timezone('utc'::text, now()), 'subscription',
        COALESCE(nullif(trim(p_notes), ''), 'Comprobante subido por la institución'),
        v_clean_url, auth.uid()
    ) RETURNING id INTO v_payment_id;

    RETURN json_build_object(
        'success', true, 
        'message', 'Comprobante de pago registrado exitosamente.',
        'payment_id', v_payment_id,
        'receipt_url', v_clean_url
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upload_tenant_payment_proof(uuid, text, text) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 5. FUNCIÓN: delete_tenant (Eliminación en Cascada por Superadmin)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_tenant(
    p_school_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, auth
AS $$
DECLARE
    v_user_role text;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();

    IF NOT (public.is_platform_admin() OR v_user_role = 'superadmin') THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado. Se requiere rol de Superadmin.');
    END IF;

    DELETE FROM public.student_alerts WHERE school_id = p_school_id;
    DELETE FROM public.grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    DELETE FROM public.supplementary_grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    DELETE FROM public.students WHERE school_id = p_school_id;
    DELETE FROM public.teacher_assignments WHERE school_id = p_school_id;
    DELETE FROM public.subjects WHERE school_id = p_school_id;
    DELETE FROM public.courses WHERE school_id = p_school_id;
    DELETE FROM public.grade_definitions WHERE school_id = p_school_id;
    DELETE FROM public.academic_years WHERE school_id = p_school_id;
    DELETE FROM public.system_config WHERE school_id = p_school_id;
    DELETE FROM public.payments WHERE school_id = p_school_id;
    DELETE FROM public.tenant_billing_profiles WHERE school_id = p_school_id;
    DELETE FROM public.tenant_limits WHERE school_id = p_school_id;
    DELETE FROM public.subscriptions WHERE school_id = p_school_id;
    DELETE FROM public.tenant_memberships WHERE school_id = p_school_id;
    DELETE FROM public.profiles WHERE school_id = p_school_id AND role <> 'superadmin';
    DELETE FROM public.schools WHERE id = p_school_id;

    RETURN json_build_object('success', true, 'message', 'Institución y todos sus datos fueron eliminados correctamente.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_tenant(uuid) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 6. FUNCIÓN: get_tenant_usage_stats (Métricas de Uso de la Institución)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_tenant_usage_stats(
    p_school_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_users_count integer;
    v_teachers_count integer;
    v_students_count integer;
    v_courses_count integer;
    v_grades_count integer;
BEGIN
    SELECT count(*) INTO v_users_count FROM public.profiles WHERE school_id = p_school_id;
    SELECT count(*) INTO v_teachers_count FROM public.profiles WHERE school_id = p_school_id AND role = 'docente';
    SELECT count(*) INTO v_students_count FROM public.students WHERE school_id = p_school_id;
    SELECT count(*) INTO v_courses_count FROM public.courses WHERE school_id = p_school_id;
    SELECT count(*) INTO v_grades_count FROM public.grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);

    RETURN json_build_object(
        'users_count', v_users_count,
        'teachers_count', v_teachers_count,
        'students_count', v_students_count,
        'courses_count', v_courses_count,
        'grades_count', v_grades_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_tenant_usage_stats(uuid) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 7. FUNCIÓN: copy_courses_to_academic_year (Copia de Cursos a Nuevo Año Lectivo)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.copy_courses_to_academic_year(
    p_school_id uuid,
    p_source_academic_year text,
    p_target_academic_year text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, auth
AS $$
DECLARE
    v_inserted_count integer := 0;
    v_skipped_count integer := 0;
    r RECORD;
BEGIN
    IF NOT (public.is_platform_admin() OR public.get_user_school_id() = p_school_id) THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado para esta institución.');
    END IF;

    FOR r IN (
        SELECT name, level, section, tutor_name, school_id
        FROM public.courses
        WHERE school_id = p_school_id AND academic_year = p_source_academic_year
    ) LOOP
        IF EXISTS (
            SELECT 1 FROM public.courses
            WHERE school_id = p_school_id 
              AND academic_year = p_target_academic_year
              AND lower(trim(name)) = lower(trim(r.name))
        ) THEN
            v_skipped_count := v_skipped_count + 1;
        ELSE
            INSERT INTO public.courses (school_id, name, level, section, tutor_name, academic_year)
            VALUES (r.school_id, r.name, r.level, r.section, r.tutor_name, p_target_academic_year);
            v_inserted_count := v_inserted_count + 1;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'inserted', v_inserted_count,
        'skipped', v_skipped_count,
        'message', format('Se copiaron %s cursos (%s omitidos por ya existir).', v_inserted_count, v_skipped_count)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.copy_courses_to_academic_year(uuid, text, text) TO authenticated, anon, service_role;

-- ------------------------------------------------------------------------------
-- 8. STORAGE Y POLÍTICAS RLS
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('billing-proofs', 'billing-proofs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public view for billing proofs" ON storage.objects;
DROP POLICY IF EXISTS "Allow upload billing proofs" ON storage.objects;
DROP POLICY IF EXISTS "Allow update billing proofs" ON storage.objects;

CREATE POLICY "Public view for billing proofs" ON storage.objects FOR SELECT USING (bucket_id = 'billing-proofs');
CREATE POLICY "Allow upload billing proofs" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'billing-proofs');
CREATE POLICY "Allow update billing proofs" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'billing-proofs');

ALTER TABLE public.tenant_billing_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Billing profiles readable by authorized users" ON public.tenant_billing_profiles;
CREATE POLICY "Billing profiles readable by authorized users"
ON public.tenant_billing_profiles FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  OR school_id = public.get_user_school_id()
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin')
);

GRANT SELECT, INSERT, UPDATE ON TABLE public.tenant_billing_profiles TO authenticated;

DROP POLICY IF EXISTS "Superadmins can update schools" ON public.schools;
CREATE POLICY "Superadmins can update schools" ON public.schools FOR UPDATE TO authenticated
USING (public.is_platform_admin() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin'));

DROP POLICY IF EXISTS "Superadmins can delete schools" ON public.schools;
CREATE POLICY "Superadmins can delete schools" ON public.schools FOR DELETE TO authenticated
USING (public.is_platform_admin() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin'));

NOTIFY pgrst, 'reload schema';

COMMIT;

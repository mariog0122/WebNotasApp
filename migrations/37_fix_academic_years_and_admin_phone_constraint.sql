-- ==============================================================================
-- MIGRACIÓN 37: Corrección Integral de Años Lectivos y Validación de Teléfono de Administrador
-- ==============================================================================
-- 1. Resuelve el error de not-null constraint en start_year / end_year en academic_years.
-- 2. Resuelve el error de violación de RLS en academic_years permitiendo crear años lectivos a directivos.
-- 3. Asigna triggers automáticos para inferir start_year, end_year y school_id.
-- 4. Exige obligatoriedad y unicidad del número de teléfono al crear un administrador de colegio.

BEGIN;

-- 1. Asegurar columnas y relajar not-null en start_year y end_year de academic_years
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;
ALTER TABLE public.academic_years ALTER COLUMN start_year DROP NOT NULL;
ALTER TABLE public.academic_years ALTER COLUMN end_year DROP NOT NULL;

-- 2. Trigger para auto-completar start_year, end_year y school_id si no fueron provistos explícitamente
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
  -- Inferir años desde el nombre (ej. "2026-2027" o "2026")
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

-- 3. Asegurar trigger de validación/asignación de tenant
DROP TRIGGER IF EXISTS set_academic_years_school_id ON public.academic_years;
CREATE TRIGGER set_academic_years_school_id
BEFORE INSERT ON public.academic_years
FOR EACH ROW
EXECUTE FUNCTION public.set_school_id_from_auth();

-- 4. Actualizar Políticas RLS de academic_years para que administradores y directivos puedan crear años
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

-- 5. Actualizar RPC provision_tenant_wizard con validación estricta y unicidad de teléfono
CREATE OR REPLACE FUNCTION public.provision_tenant_wizard(
  p_name text,
  p_trade_name text,
  p_code text,
  p_country text,
  p_province text,
  p_city text,
  p_timezone text,
  p_admin_name text,
  p_admin_email text,
  p_admin_phone text,
  p_plan_id uuid,
  p_billing_cycle text,
  p_price numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_admin_user_id uuid;
  v_admin_school_id uuid;
  v_admin_tenant_role_id uuid;
  v_subscription_id uuid;
  v_plan public.plans%ROWTYPE;
  v_agreed_price numeric(10,2);
  v_trial_ends_at timestamptz;
  v_curr_year integer := extract(year from now())::integer;
  v_year_name text;
  v_clean_phone text;
  v_phone_digits text;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Acceso denegado.');
  END IF;

  IF nullif(trim(p_name), '') IS NULL
     OR nullif(trim(p_code), '') IS NULL
     OR nullif(trim(p_admin_email), '') IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Nombre, código y correo del administrador son obligatorios.');
  END IF;

  -- Validación obligatoria de teléfono móvil para el administrador
  v_clean_phone := nullif(trim(p_admin_phone), '');
  IF v_clean_phone IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'El número de teléfono móvil del administrador es obligatorio.');
  END IF;

  v_phone_digits := regexp_replace(v_clean_phone, '\D', '', 'g');
  IF length(v_phone_digits) < 8 THEN
    RETURN json_build_object('success', false, 'message', 'El número de teléfono del administrador debe contener al menos 8 dígitos.');
  END IF;

  SELECT p.id, p.school_id INTO v_admin_user_id, v_admin_school_id
  FROM public.profiles p
  WHERE lower(p.email) = lower(trim(p_admin_email))
  LIMIT 1;

  IF v_admin_user_id IS NULL THEN
    SELECT u.id INTO v_admin_user_id
    FROM auth.users u
    WHERE lower(u.email) = lower(trim(p_admin_email))
    LIMIT 1;
  END IF;

  -- Validación de unicidad de teléfono en Supabase
  IF EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE phone IS NOT NULL 
      AND (
        trim(phone) = v_clean_phone 
        OR regexp_replace(phone, '\D', '', 'g') = v_phone_digits
      )
      AND (v_admin_user_id IS NULL OR id != v_admin_user_id)
  ) THEN
    RETURN json_build_object(
      'success', false, 
      'message', 'El número de teléfono ' || v_clean_phone || ' ya está registrado en el sistema. Debe usar un número diferente para el administrador del colegio.'
    );
  END IF;

  IF p_billing_cycle NOT IN ('monthly', 'yearly') THEN
    RETURN json_build_object('success', false, 'message', 'Ciclo de facturación no válido.');
  END IF;

  SELECT * INTO v_plan
  FROM public.plans
  WHERE id = p_plan_id
    AND active
    AND code LIKE 'institutional_%';

  IF v_plan.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Plan comercial no válido.');
  END IF;

  v_agreed_price := CASE
    WHEN p_billing_cycle = 'yearly' THEN v_plan.annual_price
    ELSE v_plan.monthly_price
  END;
  v_trial_ends_at := timezone('utc'::text, now()) + make_interval(days => v_plan.trial_days);

  IF v_admin_school_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'message', 'El administrador ya pertenece a otra institución.');
  END IF;

  INSERT INTO public.schools (
    name, trade_name, code, country, province, city, timezone, status, is_active
  ) VALUES (
    trim(p_name), COALESCE(nullif(trim(p_trade_name), ''), trim(p_name)), upper(trim(p_code)),
    COALESCE(nullif(trim(p_country), ''), 'Ecuador'), p_province, p_city,
    COALESCE(nullif(trim(p_timezone), ''), 'America/Guayaquil'), 'trial', true
  ) RETURNING id INTO v_school_id;

  SELECT id INTO v_admin_tenant_role_id
  FROM public.tenant_roles
  WHERE name = 'school_admin';

  IF v_admin_user_id IS NOT NULL AND v_admin_tenant_role_id IS NOT NULL THEN
    UPDATE public.profiles
    SET school_id = v_school_id,
        role = 'admin',
        full_name = COALESCE(nullif(trim(p_admin_name), ''), full_name),
        phone = v_clean_phone
    WHERE id = v_admin_user_id;

    INSERT INTO public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
    VALUES (v_admin_user_id, v_school_id, v_admin_tenant_role_id, true)
    ON CONFLICT (user_id, school_id) DO UPDATE SET is_active = true;
  END IF;

  INSERT INTO public.subscriptions (
    school_id, plan_id, status, billing_cycle, agreed_price,
    started_at, trial_ends_at, next_billing_date
  ) VALUES (
    v_school_id, v_plan.id, 'trial', p_billing_cycle, v_agreed_price,
    timezone('utc'::text, now()), v_trial_ends_at, v_trial_ends_at
  ) RETURNING id INTO v_subscription_id;

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  ) VALUES (
    v_school_id, NULL, 'trial', 'Alta de institución',
    'Prueba comercial de 15 días iniciada', auth.uid()
  );

  -- Crear año lectivo inicial por defecto
  v_year_name := v_curr_year::text || '-' || (v_curr_year + 1)::text;
  INSERT INTO public.academic_years (
    name, start_year, end_year, is_active, is_current, school_id
  ) VALUES (
    v_year_name, v_curr_year, v_curr_year + 1, true, true, v_school_id
  ) ON CONFLICT DO NOTHING;

  -- Crear configuración inicial del colegio
  INSERT INTO public.system_config (
    school_id, key, value, description
  ) VALUES
    (v_school_id, 'institution_name', trim(p_name), 'Nombre de la institución'),
    (v_school_id, 'institution_logo_url', '', 'Logo de la institución')
  ON CONFLICT (school_id, key) DO UPDATE SET value = EXCLUDED.value;

  RETURN json_build_object(
    'success', true,
    'message', 'Institución provisionada en periodo de prueba.',
    'school_id', v_school_id,
    'subscription_id', v_subscription_id,
    'admin_registered', v_admin_user_id IS NOT NULL,
    'agreed_price', v_agreed_price,
    'billing_cycle', p_billing_cycle,
    'trial_ends_at', v_trial_ends_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.provision_tenant_wizard(text,text,text,text,text,text,text,text,text,text,uuid,text,numeric) TO authenticated, service_role;

-- 6. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ====================================================================
-- MIGRATION: 14_p1_commercial_catalog_limits.sql
-- PURPOSE: Server-owned commercial catalog, trials and tenant capacity.
-- ====================================================================

-- 1. Make the database catalog match the public offer.
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS monthly_price numeric(10,2);
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS annual_price numeric(10,2);
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS student_limit integer;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS trial_days integer DEFAULT 15;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS implementation_fee numeric(10,2) DEFAULT 350;

UPDATE public.plans
SET code = 'institutional_500'
WHERE code = 'basic'
  AND NOT EXISTS (SELECT 1 FROM public.plans WHERE code = 'institutional_500');

UPDATE public.plans
SET code = 'institutional_1000'
WHERE code = 'pro'
  AND NOT EXISTS (SELECT 1 FROM public.plans WHERE code = 'institutional_1000');

UPDATE public.plans
SET code = 'institutional_2000'
WHERE code = 'enterprise'
  AND NOT EXISTS (SELECT 1 FROM public.plans WHERE code = 'institutional_2000');

UPDATE public.plans
SET
  name = 'Plan Institucional 500',
  price = 89,
  monthly_price = 89,
  annual_price = 890,
  student_limit = 500,
  trial_days = 15,
  implementation_fee = 350,
  billing_interval = 'monthly',
  limits = jsonb_build_object('max_students', 500),
  features = '{"grades":true,"reports":true,"alerts":true,"projects":true,"pdf_advanced":true}'::jsonb,
  active = true
WHERE code = 'institutional_500';

UPDATE public.plans
SET
  name = 'Plan Institucional 1000',
  price = 129,
  monthly_price = 129,
  annual_price = 1290,
  student_limit = 1000,
  trial_days = 15,
  implementation_fee = 350,
  billing_interval = 'monthly',
  limits = jsonb_build_object('max_students', 1000),
  features = '{"grades":true,"reports":true,"alerts":true,"projects":true,"pdf_advanced":true}'::jsonb,
  active = true
WHERE code = 'institutional_1000';

UPDATE public.plans
SET
  name = 'Plan Institucional 2000',
  price = 179,
  monthly_price = 179,
  annual_price = 1790,
  student_limit = 2000,
  trial_days = 15,
  implementation_fee = 350,
  billing_interval = 'monthly',
  limits = jsonb_build_object('max_students', 2000),
  features = '{"grades":true,"reports":true,"alerts":true,"projects":true,"pdf_advanced":true}'::jsonb,
  active = true
WHERE code = 'institutional_2000';

-- Legacy/experimental plans remain for referential history, but cannot be sold.
UPDATE public.plans
SET active = false
WHERE code NOT IN ('institutional_500', 'institutional_1000', 'institutional_2000');

-- Historical rows still satisfy the stricter schema without becoming sellable.
UPDATE public.plans
SET monthly_price = COALESCE(monthly_price, price),
    annual_price = COALESCE(annual_price, price * 10),
    student_limit = COALESCE(student_limit, (limits->>'max_students')::integer, 1),
    trial_days = COALESCE(trial_days, 15),
    implementation_fee = COALESCE(implementation_fee, 350);

ALTER TABLE public.plans ALTER COLUMN monthly_price SET NOT NULL;
ALTER TABLE public.plans ALTER COLUMN annual_price SET NOT NULL;
ALTER TABLE public.plans ALTER COLUMN student_limit SET NOT NULL;
ALTER TABLE public.plans ALTER COLUMN trial_days SET NOT NULL;
ALTER TABLE public.plans ALTER COLUMN implementation_fee SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'plans_commercial_values_check') THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_commercial_values_check CHECK (
      monthly_price >= 0
      AND annual_price >= 0
      AND student_limit > 0
      AND trial_days >= 0
      AND implementation_fee >= 0
    );
  END IF;
END
$$;

-- 2. Persist the server-derived commercial agreement on each subscription.
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS billing_cycle text DEFAULT 'monthly';
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS agreed_price numeric(10,2);
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;

UPDATE public.subscriptions s
SET
  billing_cycle = COALESCE(s.billing_cycle, 'monthly'),
  agreed_price = CASE
    WHEN COALESCE(s.billing_cycle, 'monthly') = 'yearly' THEN p.annual_price
    ELSE p.monthly_price
  END
FROM public.plans p
WHERE p.id = s.plan_id;

ALTER TABLE public.subscriptions ALTER COLUMN billing_cycle SET NOT NULL;
ALTER TABLE public.subscriptions ALTER COLUMN agreed_price SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_billing_cycle_check') THEN
    ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_billing_cycle_check
      CHECK (billing_cycle IN ('monthly', 'yearly'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_agreed_price_check') THEN
    ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_agreed_price_check
      CHECK (agreed_price >= 0);
  END IF;
END
$$;

-- 3. Materialized tenant limits, synchronized from the subscribed plan.
CREATE TABLE IF NOT EXISTS public.tenant_limits (
  school_id uuid PRIMARY KEY REFERENCES public.schools(id) ON DELETE CASCADE,
  max_users integer NOT NULL DEFAULT 100000,
  max_teachers integer NOT NULL DEFAULT 100000,
  max_students integer NOT NULL,
  storage_mb integer NOT NULL DEFAULT 102400,
  max_documents integer NOT NULL DEFAULT 100000,
  max_emails_month integer NOT NULL DEFAULT 100000,
  max_api_requests integer NOT NULL DEFAULT 100000,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT tenant_limits_positive_check CHECK (
    max_users > 0 AND max_teachers > 0 AND max_students > 0
    AND storage_mb > 0 AND max_documents > 0
    AND max_emails_month > 0 AND max_api_requests > 0
  )
);

INSERT INTO public.tenant_limits (school_id, max_students)
SELECT s.school_id, p.student_limit
FROM public.subscriptions s
JOIN public.plans p ON p.id = s.plan_id
ON CONFLICT (school_id) DO UPDATE
SET max_students = EXCLUDED.max_students,
    updated_at = timezone('utc'::text, now());

CREATE OR REPLACE FUNCTION public.sync_tenant_limit_from_subscription()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_student_limit integer;
BEGIN
  SELECT p.student_limit INTO v_student_limit
  FROM public.plans p
  WHERE p.id = NEW.plan_id AND p.active;

  IF v_student_limit IS NULL THEN
    RAISE EXCEPTION 'ACTIVE_PLAN_REQUIRED' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.tenant_limits (school_id, max_students)
  VALUES (NEW.school_id, v_student_limit)
  ON CONFLICT (school_id) DO UPDATE
  SET max_students = EXCLUDED.max_students,
      updated_at = timezone('utc'::text, now());

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_subscription_tenant_limit ON public.subscriptions;
CREATE TRIGGER sync_subscription_tenant_limit
AFTER INSERT OR UPDATE OF plan_id ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.sync_tenant_limit_from_subscription();

-- 4. Enforce capacity atomically for every insertion path (UI, import or RPC).
CREATE OR REPLACE FUNCTION public.enforce_student_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_limit integer;
  v_current integer;
BEGIN
  IF NEW.school_id IS NULL THEN
    NEW.school_id := public.get_user_school_id();
  END IF;

  IF NEW.school_id IS NULL THEN
    RAISE EXCEPTION 'TENANT_REQUIRED' USING ERRCODE = '42501';
  END IF;

  -- Serialize concurrent inserts per tenant so two requests cannot exceed capacity.
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.school_id::text, 0));

  SELECT tl.max_students INTO v_limit
  FROM public.tenant_limits tl
  WHERE tl.school_id = NEW.school_id;

  IF v_limit IS NULL THEN
    RAISE EXCEPTION 'SUBSCRIPTION_LIMIT_REQUIRED' USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_current
  FROM public.students s
  WHERE s.school_id = NEW.school_id
    AND (TG_OP = 'INSERT' OR s.id IS DISTINCT FROM NEW.id);

  IF v_current >= v_limit THEN
    RAISE EXCEPTION 'STUDENT_LIMIT_REACHED: current %, limit %', v_current, v_limit
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS zz_enforce_student_limit ON public.students;
CREATE TRIGGER zz_enforce_student_limit
BEFORE INSERT OR UPDATE OF school_id ON public.students
FOR EACH ROW EXECUTE FUNCTION public.enforce_student_limit();

-- 5. Entitlement is evaluated on every tenant resolution, even before cron runs.
CREATE OR REPLACE FUNCTION public.is_school_entitled(p_school_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.schools sc
    JOIN public.subscriptions su ON su.school_id = sc.id
    WHERE sc.id = p_school_id
      AND COALESCE(sc.is_active, false)
      AND sc.status::text IN ('trial', 'active', 'past_due', 'grace_period')
      AND (
        su.status::text = 'active'
        OR (
          su.status::text = 'trial'
          AND su.trial_ends_at IS NOT NULL
          AND su.trial_ends_at > timezone('utc'::text, now())
        )
        OR (
          su.status::text IN ('past_due', 'grace_period')
          AND su.grace_period_until IS NOT NULL
          AND su.grace_period_until > timezone('utc'::text, now())
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT COALESCE(
    (
      SELECT tm.school_id
      FROM public.tenant_memberships tm
      WHERE tm.user_id = (SELECT auth.uid())
        AND tm.is_active
        AND public.is_school_entitled(tm.school_id)
      ORDER BY tm.created_at
      LIMIT 1
    ),
    (
      SELECT p.school_id
      FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND COALESCE(p.is_active, true)
        AND public.is_school_entitled(p.school_id)
      LIMIT 1
    )
  );
$$;

-- 6. Provision a 15-day trial. Client-provided p_price is intentionally ignored.
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
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Acceso denegado.');
  END IF;

  IF nullif(trim(p_name), '') IS NULL
     OR nullif(trim(p_code), '') IS NULL
     OR nullif(trim(p_admin_email), '') IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Nombre, código y correo del administrador son obligatorios.');
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
        phone = COALESCE(nullif(trim(p_admin_phone), ''), phone)
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
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'El código institucional ya está registrado.');
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'No fue posible aprovisionar la institución.');
END;
$$;

-- 7. Tenant-facing usage is authorized and storage is scoped by path prefix.
CREATE OR REPLACE FUNCTION public.get_tenant_usage_stats(p_school_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, storage
AS $$
DECLARE
  v_limits public.tenant_limits%ROWTYPE;
  v_users integer;
  v_teachers integer;
  v_students integer;
  v_storage_mb numeric;
BEGIN
  IF NOT public.is_platform_admin()
     AND p_school_id IS DISTINCT FROM public.get_user_school_id() THEN
    RAISE EXCEPTION 'Tenant no autorizado' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_limits FROM public.tenant_limits WHERE school_id = p_school_id;
  IF v_limits.school_id IS NULL THEN
    RAISE EXCEPTION 'SUBSCRIPTION_LIMIT_REQUIRED' USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_users FROM public.profiles WHERE school_id = p_school_id;
  SELECT count(*) INTO v_teachers FROM public.profiles WHERE school_id = p_school_id AND role = 'teacher';
  SELECT count(*) INTO v_students FROM public.students WHERE school_id = p_school_id;
  SELECT round((COALESCE(sum((metadata->>'size')::bigint), 0) / 1048576.0)::numeric, 2)
    INTO v_storage_mb
  FROM storage.objects
  WHERE bucket_id IN ('student-photos', 'institution-assets', 'profile-photos')
    AND split_part(name, '/', 1) = p_school_id::text;

  RETURN json_build_object(
    'users', json_build_object('current', v_users, 'limit', v_limits.max_users),
    'teachers', json_build_object('current', v_teachers, 'limit', v_limits.max_teachers),
    'students', json_build_object(
      'current', v_students,
      'limit', v_limits.max_students,
      'percentage', round(v_students::numeric / v_limits.max_students * 100, 1)
    ),
    'storage', json_build_object('current_mb', v_storage_mb, 'limit_mb', v_limits.storage_mb)
  );
END;
$$;

-- 8. RLS and execution privileges for the new commercial surface.
ALTER TABLE public.tenant_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Platform admins manage tenant limits" ON public.tenant_limits;
CREATE POLICY "Platform admins manage tenant limits"
ON public.tenant_limits FOR ALL TO authenticated
USING (public.is_platform_admin())
WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Tenant members read own limits" ON public.tenant_limits;
CREATE POLICY "Tenant members read own limits"
ON public.tenant_limits FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

REVOKE ALL ON TABLE public.tenant_limits FROM anon;
GRANT SELECT ON TABLE public.tenant_limits TO authenticated;

REVOKE ALL ON FUNCTION public.is_school_entitled(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_tenant_usage_stats(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sync_tenant_limit_from_subscription() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_student_limit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_school_entitled(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_usage_stats(uuid) TO authenticated;

-- Keep the legacy RPC signature during the frontend rollout, but only authenticated
-- platform administrators can execute it. p_price has no authority in its body.
REVOKE ALL ON FUNCTION public.provision_tenant_wizard(
  text, text, text, text, text, text, text, text, text, text, uuid, text, numeric
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provision_tenant_wizard(
  text, text, text, text, text, text, text, text, text, text, uuid, text, numeric
) TO authenticated;

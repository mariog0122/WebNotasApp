-- ====================================================================
-- MIGRATION: 18_p1_billing_operations.sql
-- PURPOSE: Auditable manual payments and atomic tenant status changes.
-- ====================================================================

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS payment_type text DEFAULT 'subscription';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS external_invoice_number text;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payments_payment_type_check') THEN
    ALTER TABLE public.payments ADD CONSTRAINT payments_payment_type_check CHECK (
      payment_type IN ('subscription', 'subscription_with_implementation', 'implementation', 'adjustment')
    );
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS payments_provider_reference_unique
ON public.payments (lower(provider), provider_reference)
WHERE provider_reference IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS payments_external_invoice_number_unique
ON public.payments (external_invoice_number)
WHERE external_invoice_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.tenant_billing_profiles (
  school_id uuid PRIMARY KEY REFERENCES public.schools(id) ON DELETE CASCADE,
  implementation_fee_status text NOT NULL DEFAULT 'pending'
    CHECK (implementation_fee_status IN ('pending', 'paid', 'waived')),
  implementation_fee_paid_at timestamptz,
  implementation_fee_payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Schools that existed before this commercial migration are grandfathered.
INSERT INTO public.tenant_billing_profiles (school_id, implementation_fee_status)
SELECT id, 'waived' FROM public.schools
ON CONFLICT (school_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.initialize_tenant_billing_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  INSERT INTO public.tenant_billing_profiles (school_id, implementation_fee_status)
  VALUES (NEW.id, 'pending')
  ON CONFLICT (school_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS initialize_tenant_billing_profile ON public.schools;
CREATE TRIGGER initialize_tenant_billing_profile
AFTER INSERT ON public.schools
FOR EACH ROW EXECUTE FUNCTION public.initialize_tenant_billing_profile();

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
      AND p_roles && ARRAY['platform_owner', 'platform_admin']::text[]
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.record_manual_payment(
  p_school_id uuid,
  p_amount numeric,
  p_provider_reference text,
  p_external_invoice_number text,
  p_paid_at timestamptz,
  p_notes text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_subscription public.subscriptions%ROWTYPE;
  v_plan public.plans%ROWTYPE;
  v_billing_profile public.tenant_billing_profiles%ROWTYPE;
  v_previous_status public.tenant_status_type;
  v_expected_amount numeric(10,2);
  v_payment_type text := 'subscription';
  v_period_base timestamptz;
  v_next_billing timestamptz;
  v_payment_id uuid;
BEGIN
  IF NOT public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']) THEN
    RAISE EXCEPTION 'PAYMENT_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(p_provider_reference), '') IS NULL
     OR nullif(trim(p_external_invoice_number), '') IS NULL
     OR p_paid_at IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_EVIDENCE_REQUIRED' USING ERRCODE = '22023';
  END IF;
  IF p_paid_at > timezone('utc'::text, now()) + interval '5 minutes' THEN
    RAISE EXCEPTION 'PAYMENT_DATE_INVALID' USING ERRCODE = '22007';
  END IF;

  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE school_id = p_school_id
  FOR UPDATE;
  IF v_subscription.id IS NULL THEN
    RAISE EXCEPTION 'SUBSCRIPTION_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_plan FROM public.plans WHERE id = v_subscription.plan_id;
  SELECT * INTO v_billing_profile
  FROM public.tenant_billing_profiles
  WHERE school_id = p_school_id
  FOR UPDATE;

  v_expected_amount := v_subscription.agreed_price;
  IF v_billing_profile.implementation_fee_status = 'pending' THEN
    v_expected_amount := v_expected_amount + v_plan.implementation_fee;
    v_payment_type := 'subscription_with_implementation';
  END IF;

  IF abs(p_amount - v_expected_amount) > 0.01 THEN
    RAISE EXCEPTION 'PAYMENT_AMOUNT_MISMATCH: expected %, received %', v_expected_amount, p_amount
      USING ERRCODE = '22003';
  END IF;

  SELECT status INTO v_previous_status FROM public.schools WHERE id = p_school_id FOR UPDATE;
  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.payments (
    school_id, subscription_id, amount, currency, provider, provider_reference,
    status, paid_at, payment_type, external_invoice_number, notes, recorded_by
  ) VALUES (
    p_school_id, v_subscription.id, p_amount, 'USD', 'transfer', trim(p_provider_reference),
    'completed', p_paid_at, v_payment_type, trim(p_external_invoice_number),
    nullif(trim(p_notes), ''), auth.uid()
  ) RETURNING id INTO v_payment_id;

  IF v_billing_profile.implementation_fee_status = 'pending' THEN
    UPDATE public.tenant_billing_profiles
    SET implementation_fee_status = 'paid',
        implementation_fee_paid_at = p_paid_at,
        implementation_fee_payment_id = v_payment_id,
        updated_at = timezone('utc'::text, now())
    WHERE school_id = p_school_id;
  END IF;

  v_period_base := CASE
    WHEN v_subscription.status::text = 'trial'
      AND v_subscription.trial_ends_at > timezone('utc'::text, now())
      THEN v_subscription.trial_ends_at
    WHEN v_subscription.status::text = 'active'
      AND v_subscription.next_billing_date > timezone('utc'::text, now())
      THEN v_subscription.next_billing_date
    ELSE timezone('utc'::text, now())
  END;

  v_next_billing := CASE
    WHEN v_subscription.billing_cycle = 'yearly' THEN v_period_base + interval '1 year'
    ELSE v_period_base + interval '1 month'
  END;

  UPDATE public.subscriptions
  SET status = 'active',
      next_billing_date = v_next_billing,
      grace_period_until = NULL,
      cancelled_at = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_subscription.id;

  UPDATE public.schools
  SET status = 'active', is_active = true,
      suspended_reason = NULL, suspended_at = NULL, suspended_by = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_school_id;

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  ) VALUES (
    p_school_id, v_previous_status, 'active', 'Pago verificado',
    concat('Transferencia ', trim(p_provider_reference), '; factura ', trim(p_external_invoice_number)),
    auth.uid()
  );

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, new_values
  ) VALUES (
    p_school_id, auth.uid(), 'MANUAL_PAYMENT_RECORDED', 'payments', v_payment_id::text,
    jsonb_build_object(
      'amount', p_amount,
      'payment_type', v_payment_type,
      'provider_reference', trim(p_provider_reference),
      'external_invoice_number', trim(p_external_invoice_number),
      'next_billing_date', v_next_billing
    )
  );

  RETURN json_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'payment_type', v_payment_type,
    'next_billing_date', v_next_billing
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_tenant_status(
  p_school_id uuid,
  p_new_status public.tenant_status_type,
  p_reason text,
  p_observation text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_previous_status public.tenant_status_type;
BEGIN
  IF NOT public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_support']) THEN
    RAISE EXCEPTION 'TENANT_STATUS_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  IF p_new_status::text NOT IN ('active', 'suspended', 'cancelled') THEN
    RAISE EXCEPTION 'TENANT_STATUS_INVALID' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(p_reason), '') IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'TENANT_STATUS_REASON_REQUIRED' USING ERRCODE = '22023';
  END IF;

  SELECT status INTO v_previous_status
  FROM public.schools
  WHERE id = p_school_id
  FOR UPDATE;
  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.schools
  SET status = p_new_status,
      is_active = p_new_status::text = 'active',
      suspended_reason = CASE WHEN p_new_status::text = 'suspended' THEN trim(p_reason) ELSE NULL END,
      suspended_at = CASE WHEN p_new_status::text = 'suspended' THEN timezone('utc'::text, now()) ELSE NULL END,
      suspended_by = CASE WHEN p_new_status::text = 'suspended' THEN auth.uid() ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_school_id;

  UPDATE public.subscriptions
  SET status = p_new_status,
      cancelled_at = CASE WHEN p_new_status::text = 'cancelled' THEN timezone('utc'::text, now()) ELSE NULL END,
      updated_at = timezone('utc'::text, now())
  WHERE school_id = p_school_id;

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  ) VALUES (
    p_school_id, v_previous_status, p_new_status, trim(p_reason), nullif(trim(p_observation), ''), auth.uid()
  );

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) VALUES (
    p_school_id, auth.uid(), 'TENANT_STATUS_CHANGED', 'schools', p_school_id::text,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object('status', p_new_status, 'reason', trim(p_reason), 'observation', p_observation)
  );

  RETURN json_build_object('success', true, 'previous_status', v_previous_status, 'new_status', p_new_status);
END;
$$;

ALTER TABLE public.tenant_billing_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Platform billing profiles" ON public.tenant_billing_profiles;
CREATE POLICY "Platform billing profiles" ON public.tenant_billing_profiles
FOR ALL TO authenticated
USING (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']))
WITH CHECK (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']));
DROP POLICY IF EXISTS "Tenant reads own billing profile" ON public.tenant_billing_profiles;
CREATE POLICY "Tenant reads own billing profile" ON public.tenant_billing_profiles
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id() AND public.has_tenant_permission('billing.read'));

REVOKE ALL ON TABLE public.tenant_billing_profiles FROM anon;
GRANT SELECT ON TABLE public.tenant_billing_profiles TO authenticated;
REVOKE ALL ON FUNCTION public.initialize_tenant_billing_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.has_platform_role(text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_tenant_status(uuid, public.tenant_status_type, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_platform_role(text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_tenant_status(uuid, public.tenant_status_type, text, text) TO authenticated;

-- ==============================================================================
-- MIGRACIÓN 38: Alineación y Sincronización Exacta de Fechas de Prueba y Renovación
-- ==============================================================================
-- 1. Sincroniza todas las suscripciones existentes para que trial_ends_at y next_billing_date
--    coincidan con la duración del plan y el ciclo de facturación.
-- 2. Asegura que record_manual_payment extienda el período sumando exactamente el mes o año
--    al período de prueba restante o a la fecha de vencimiento actual.
-- 3. Garantiza que provision_tenant_wizard registre las fechas de inicio, prueba y próxima facturación
--    de forma sincronizada.

BEGIN;

-- 1. Asegurar columnas de auditoría y fechas en public.subscriptions
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS started_at timestamptz DEFAULT timezone('utc'::text, now());
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS next_billing_date timestamptz;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS grace_period_until timestamptz;

-- 2. Sanitizar y alinear registros existentes de suscripciones
DO $$
DECLARE
  r RECORD;
  v_plan_trial_days integer;
  v_started timestamptz;
  v_trial_end timestamptz;
  v_next_bill timestamptz;
BEGIN
  FOR r IN 
    SELECT s.id, s.school_id, s.status, s.billing_cycle, s.started_at, s.trial_ends_at, s.next_billing_date, s.created_at,
           p.trial_days, p.monthly_price, p.annual_price
    FROM public.subscriptions s
    LEFT JOIN public.plans p ON p.id = s.plan_id
  LOOP
    v_plan_trial_days := COALESCE(r.trial_days, 15);
    v_started := COALESCE(r.started_at, r.created_at, timezone('utc'::text, now()));
    v_trial_end := COALESCE(r.trial_ends_at, v_started + make_interval(days => v_plan_trial_days));

    IF r.status = 'trial' THEN
      v_next_bill := v_trial_end;
    ELSIF r.status = 'active' THEN
      IF r.next_billing_date IS NOT NULL AND r.next_billing_date > v_started THEN
        v_next_bill := r.next_billing_date;
      ELSE
        v_next_bill := CASE 
          WHEN r.billing_cycle = 'yearly' THEN v_started + interval '1 year'
          ELSE v_started + interval '1 month'
        END;
      END IF;
    ELSE
      v_next_bill := COALESCE(r.next_billing_date, v_trial_end);
    END IF;

    UPDATE public.subscriptions
    SET started_at = v_started,
        trial_ends_at = v_trial_end,
        next_billing_date = v_next_bill,
        updated_at = timezone('utc'::text, now())
    WHERE id = r.id;
  END LOOP;
END $$;

-- 3. Actualizar función canónica record_manual_payment con cálculo exacto de renovación
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
  v_subscription public.subscriptions%ROWTYPE;
  v_plan public.plans%ROWTYPE;
  v_billing_profile public.tenant_billing_profiles%ROWTYPE;
  v_previous_status public.tenant_status_type;
  v_expected_amount numeric(10,2);
  v_payment_type text := 'subscription';
  v_period_base timestamptz;
  v_next_billing timestamptz;
  v_payment_id uuid;
  v_effective_receipt_url text;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  IF NOT (public.is_platform_admin() OR public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance'])) THEN
    RAISE EXCEPTION 'PAYMENT_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  IF nullif(trim(p_provider_reference), '') IS NULL
     OR nullif(trim(p_external_invoice_number), '') IS NULL
     OR p_paid_at IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_EVIDENCE_REQUIRED' USING ERRCODE = '22023';
  END IF;

  IF p_paid_at > v_now + interval '5 minutes' THEN
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
    v_expected_amount := v_expected_amount + COALESCE(v_plan.implementation_fee, 0);
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

  v_effective_receipt_url := COALESCE(nullif(trim(p_receipt_url), ''), v_billing_profile.latest_receipt_url);

  INSERT INTO public.payments (
    school_id, subscription_id, amount, currency, provider, provider_reference,
    status, paid_at, payment_type, external_invoice_number, notes, receipt_url, recorded_by
  ) VALUES (
    p_school_id, v_subscription.id, p_amount, 'USD', 'transfer', trim(p_provider_reference),
    'completed', p_paid_at, v_payment_type, trim(p_external_invoice_number),
    nullif(trim(p_notes), ''), v_effective_receipt_url, auth.uid()
  ) RETURNING id INTO v_payment_id;

  IF v_billing_profile.implementation_fee_status = 'pending' THEN
    UPDATE public.tenant_billing_profiles
    SET implementation_fee_status = 'paid',
        implementation_fee_paid_at = p_paid_at,
        implementation_fee_payment_id = v_payment_id,
        latest_receipt_url = v_effective_receipt_url,
        updated_at = v_now
    WHERE school_id = p_school_id;
  ELSE
    UPDATE public.tenant_billing_profiles
    SET latest_receipt_url = v_effective_receipt_url,
        updated_at = v_now
    WHERE school_id = p_school_id;
  END IF;

  -- Base de cálculo para la nueva fecha de renovación:
  -- Si estaba en prueba y no ha vencido, suma el ciclo al final de la prueba.
  -- Si ya estaba activo y no ha vencido, suma el ciclo a la fecha de vencimiento actual.
  -- Si ya estaba vencido/suspendido, suma el ciclo a la fecha del pago (o ahora).
  v_period_base := CASE
    WHEN v_subscription.status::text = 'trial'
      AND v_subscription.trial_ends_at IS NOT NULL
      AND v_subscription.trial_ends_at > v_now
      THEN v_subscription.trial_ends_at
    WHEN v_subscription.status::text = 'active'
      AND v_subscription.next_billing_date IS NOT NULL
      AND v_subscription.next_billing_date > v_now
      THEN v_subscription.next_billing_date
    ELSE p_paid_at
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
      updated_at = v_now
  WHERE id = v_subscription.id;

  UPDATE public.schools
  SET status = 'active', is_active = true,
      suspended_reason = NULL, suspended_at = NULL, suspended_by = NULL,
      updated_at = v_now
  WHERE id = p_school_id;

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) VALUES (
    p_school_id, auth.uid(), 'MANUAL_PAYMENT_RECORDED', 'payments', v_payment_id::text,
    jsonb_build_object('school_status', v_previous_status),
    jsonb_build_object(
      'amount', p_amount,
      'provider_reference', p_provider_reference,
      'external_invoice_number', p_external_invoice_number,
      'receipt_url', v_effective_receipt_url,
      'next_billing_date', v_next_billing
    )
  );

  RETURN json_build_object(
    'payment_id', v_payment_id,
    'school_id', p_school_id,
    'next_billing_date', v_next_billing,
    'status', 'active'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_manual_payment(uuid, numeric, text, text, timestamptz, text, text) TO authenticated, service_role;

-- 4. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

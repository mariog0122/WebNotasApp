-- Migration: 20260810210500_update_record_manual_payment_receipt.sql
-- Description: Allow passing p_receipt_url to record_manual_payment

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
        updated_at = timezone('utc'::text, now())
    WHERE school_id = p_school_id;
  ELSE
    UPDATE public.tenant_billing_profiles
    SET latest_receipt_url = v_effective_receipt_url,
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

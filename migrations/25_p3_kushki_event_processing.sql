-- ====================================================================
-- MIGRATION: 25_p3_kushki_event_processing.sql
-- PURPOSE: Atomically turn an authenticated Kushki approval into a
--          payment, invoice allocation and active subscription.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.process_kushki_payment_event(p_event_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_event public.payment_events%ROWTYPE;
  v_summary jsonb;
  v_metadata jsonb;
  v_transaction_status text;
  v_transaction_type text;
  v_reference text;
  v_invoice_number text;
  v_school_text text;
  v_school_id uuid;
  v_amount numeric(12,2);
  v_currency text;
  v_paid_at timestamptz;
  v_subscription public.subscriptions%ROWTYPE;
  v_plan public.plans%ROWTYPE;
  v_billing_profile public.tenant_billing_profiles%ROWTYPE;
  v_previous_status public.tenant_status_type;
  v_expected_amount numeric(12,2);
  v_payment_type text := 'subscription';
  v_period_base timestamptz;
  v_next_billing timestamptz;
  v_payment public.payments%ROWTYPE;
BEGIN
  SELECT * INTO v_event
  FROM public.payment_events
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF v_event.provider <> 'kushki' THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_PROVIDER_INVALID' USING ERRCODE = '22023';
  END IF;
  IF v_event.status IN ('processed', 'ignored') THEN
    RETURN json_build_object(
      'success', true,
      'duplicate', true,
      'event_id', v_event.id,
      'status', v_event.status,
      'payment_id', v_event.payment_id
    );
  END IF;

  v_summary := v_event.payload_summary;
  v_transaction_status := upper(coalesce(v_summary->>'transaction_status', ''));
  v_transaction_type := upper(coalesce(v_summary->>'transaction_type', ''));

  -- A valid decline or a non-sale event is acknowledged without changing billing.
  IF v_transaction_status IN ('DECLINED', 'DECLINE', 'REJECTED')
     OR v_transaction_type <> 'SALE'
     OR v_transaction_status NOT IN ('APPROVAL', 'APPROVED') THEN
    UPDATE public.payment_events
    SET status = 'ignored',
        attempt_count = attempt_count + 1,
        error_message = NULL,
        processed_at = timezone('utc'::text, now())
    WHERE id = v_event.id;

    RETURN json_build_object(
      'success', true,
      'duplicate', false,
      'event_id', v_event.id,
      'status', 'ignored'
    );
  END IF;

  v_metadata := coalesce(v_summary->'metadata', '{}'::jsonb);
  v_school_text := nullif(trim(v_metadata->>'school_id'), '');
  v_invoice_number := nullif(trim(v_metadata->>'invoice_number'), '');
  v_reference := coalesce(
    nullif(trim(v_summary->>'transaction_id'), ''),
    nullif(trim(v_summary->>'ticket_number'), ''),
    nullif(trim(v_summary->>'transaction_reference'), '')
  );
  v_currency := upper(coalesce(nullif(trim(v_summary->>'currency'), ''), ''));

  BEGIN
    v_school_id := v_school_text::uuid;
    v_amount := (v_summary #>> '{amount,total}')::numeric(12,2);
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'KUSHKI_EVENT_MAPPING_REQUIRED' USING ERRCODE = '22023';
  END;

  IF v_school_id IS NULL OR v_invoice_number IS NULL OR v_reference IS NULL
     OR v_amount IS NULL OR v_amount <= 0 OR v_currency <> 'USD' THEN
    RAISE EXCEPTION 'KUSHKI_EVENT_MAPPING_REQUIRED' USING ERRCODE = '22023';
  END IF;

  v_paid_at := CASE
    WHEN jsonb_typeof(v_summary->'created') = 'number'
      THEN to_timestamp((v_summary->>'created')::double precision)
    ELSE timezone('utc'::text, now())
  END;

  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE school_id = v_school_id
  FOR UPDATE;
  IF v_subscription.id IS NULL THEN
    RAISE EXCEPTION 'SUBSCRIPTION_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_plan FROM public.plans WHERE id = v_subscription.plan_id;
  IF v_plan.id IS NULL THEN
    RAISE EXCEPTION 'PLAN_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.tenant_billing_profiles (school_id, implementation_fee_status)
  VALUES (v_school_id, 'pending')
  ON CONFLICT (school_id) DO NOTHING;

  SELECT * INTO v_billing_profile
  FROM public.tenant_billing_profiles
  WHERE school_id = v_school_id
  FOR UPDATE;

  v_expected_amount := v_subscription.agreed_price;
  IF v_billing_profile.implementation_fee_status = 'pending' THEN
    v_expected_amount := v_expected_amount + v_plan.implementation_fee;
    v_payment_type := 'subscription_with_implementation';
  END IF;

  IF abs(v_amount - v_expected_amount) > 0.01 THEN
    RAISE EXCEPTION 'KUSHKI_PAYMENT_AMOUNT_MISMATCH: expected %, received %', v_expected_amount, v_amount
      USING ERRCODE = '22003';
  END IF;

  SELECT * INTO v_payment
  FROM public.payments
  WHERE lower(provider) = 'kushki'
    AND provider_reference = v_reference;

  IF v_payment.id IS NOT NULL THEN
    IF v_payment.school_id <> v_school_id OR v_payment.amount <> v_amount OR v_payment.status <> 'completed' THEN
      RAISE EXCEPTION 'KUSHKI_PAYMENT_REPLAY_MISMATCH' USING ERRCODE = '22000';
    END IF;

    UPDATE public.payment_events
    SET status = 'processed', school_id = v_school_id, payment_id = v_payment.id,
        attempt_count = attempt_count + 1, error_message = NULL,
        processed_at = timezone('utc'::text, now())
    WHERE id = v_event.id;

    RETURN json_build_object(
      'success', true,
      'duplicate', true,
      'event_id', v_event.id,
      'status', 'processed',
      'payment_id', v_payment.id
    );
  END IF;

  SELECT status INTO v_previous_status
  FROM public.schools
  WHERE id = v_school_id
  FOR UPDATE;
  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.payments (
    school_id, subscription_id, amount, currency, provider, provider_reference,
    status, paid_at, payment_type, external_invoice_number, notes, recorded_by
  ) VALUES (
    v_school_id, v_subscription.id, v_amount, 'USD', 'kushki', v_reference,
    'completed', v_paid_at, v_payment_type, v_invoice_number,
    concat('Evento Kushki ', v_event.id::text), NULL
  ) RETURNING * INTO v_payment;

  IF v_billing_profile.implementation_fee_status = 'pending' THEN
    UPDATE public.tenant_billing_profiles
    SET implementation_fee_status = 'paid',
        implementation_fee_paid_at = v_paid_at,
        implementation_fee_payment_id = v_payment.id,
        updated_at = timezone('utc'::text, now())
    WHERE school_id = v_school_id;
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
  SET status = 'active', next_billing_date = v_next_billing,
      grace_period_until = NULL, cancelled_at = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_subscription.id;

  UPDATE public.schools
  SET status = 'active', is_active = true,
      suspended_reason = NULL, suspended_at = NULL, suspended_by = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_school_id;

  INSERT INTO public.tenant_status_logs (
    school_id, previous_status, new_status, reason, observation, actor_id
  ) VALUES (
    v_school_id, v_previous_status, 'active', 'Pago Kushki aprobado',
    concat('Referencia ', v_reference, '; factura ', v_invoice_number), NULL
  );

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, new_values
  ) VALUES (
    v_school_id, NULL, 'KUSHKI_PAYMENT_PROCESSED', 'payments', v_payment.id::text,
    jsonb_build_object(
      'event_id', v_event.id,
      'amount', v_amount,
      'payment_type', v_payment_type,
      'provider_reference', v_reference,
      'external_invoice_number', v_invoice_number,
      'next_billing_date', v_next_billing
    )
  );

  UPDATE public.payment_events
  SET status = 'processed', school_id = v_school_id, payment_id = v_payment.id,
      attempt_count = attempt_count + 1, error_message = NULL,
      processed_at = timezone('utc'::text, now())
  WHERE id = v_event.id;

  RETURN json_build_object(
    'success', true,
    'duplicate', false,
    'event_id', v_event.id,
    'status', 'processed',
    'payment_id', v_payment.id,
    'next_billing_date', v_next_billing
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_kushki_payment_event(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_kushki_payment_event(uuid) TO service_role;


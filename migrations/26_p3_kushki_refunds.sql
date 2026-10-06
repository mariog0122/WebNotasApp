-- ====================================================================
-- MIGRATION: 26_p3_kushki_refunds.sql
-- PURPOSE: Idempotent reconciliation of Kushki REFUND and VOID events.
-- ====================================================================

ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE public.invoices ADD CONSTRAINT invoices_status_check CHECK (
  status IN (
    'draft', 'issued', 'partially_paid', 'paid', 'overdue', 'void',
    'partially_refunded', 'refunded'
  )
);

CREATE TABLE IF NOT EXISTS public.payment_refunds (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  payment_event_id uuid NOT NULL UNIQUE REFERENCES public.payment_events(id) ON DELETE RESTRICT,
  provider_reference text NOT NULL UNIQUE,
  refund_type text NOT NULL CHECK (refund_type IN ('refund', 'void')),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'),
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_payment_refunds_payment
  ON public.payment_refunds (payment_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.process_kushki_refund_event(p_event_id uuid)
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
  v_sale_reference text;
  v_sale_ticket text;
  v_invoice_number text;
  v_amount numeric(12,2);
  v_currency text;
  v_payment public.payments%ROWTYPE;
  v_invoice public.invoices%ROWTYPE;
  v_refund public.payment_refunds%ROWTYPE;
  v_total_refunded numeric(12,2);
  v_previous_status public.tenant_status_type;
  v_changes_access boolean := false;
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

  IF v_transaction_status IN ('DECLINED', 'DECLINE', 'REJECTED')
     OR v_transaction_type NOT IN ('REFUND', 'VOID')
     OR v_transaction_status NOT IN ('APPROVAL', 'APPROVED') THEN
    UPDATE public.payment_events
    SET status = 'ignored', attempt_count = attempt_count + 1,
        error_message = NULL, processed_at = timezone('utc'::text, now())
    WHERE id = v_event.id;

    RETURN json_build_object(
      'success', true,
      'duplicate', false,
      'event_id', v_event.id,
      'status', 'ignored'
    );
  END IF;

  v_metadata := coalesce(v_summary->'metadata', '{}'::jsonb);
  v_reference := coalesce(
    nullif(trim(v_summary->>'transaction_id'), ''),
    nullif(trim(v_summary->>'ticket_number'), ''),
    nullif(trim(v_summary->>'transaction_reference'), '')
  );
  v_sale_reference := nullif(trim(v_summary->>'sale_transaction_reference'), '');
  v_sale_ticket := nullif(trim(v_summary->>'sale_ticket_number'), '');
  v_invoice_number := nullif(trim(v_metadata->>'invoice_number'), '');
  v_currency := upper(coalesce(nullif(trim(v_summary->>'currency'), ''), ''));

  BEGIN
    v_amount := (v_summary #>> '{amount,total}')::numeric(12,2);
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'KUSHKI_REFUND_MAPPING_REQUIRED' USING ERRCODE = '22023';
  END;

  IF v_reference IS NULL OR v_amount IS NULL OR v_amount <= 0 OR v_currency <> 'USD'
     OR (v_sale_reference IS NULL AND v_sale_ticket IS NULL AND v_invoice_number IS NULL) THEN
    RAISE EXCEPTION 'KUSHKI_REFUND_MAPPING_REQUIRED' USING ERRCODE = '22023';
  END IF;

  SELECT p.* INTO v_payment
  FROM public.payment_events sale_event
  JOIN public.payments p ON p.id = sale_event.payment_id
  WHERE sale_event.provider = 'kushki'
    AND sale_event.status = 'processed'
    AND (
      (v_sale_reference IS NOT NULL AND sale_event.payload_summary->>'transaction_reference' = v_sale_reference)
      OR (v_sale_ticket IS NOT NULL AND sale_event.payload_summary->>'ticket_number' = v_sale_ticket)
    )
  ORDER BY sale_event.processed_at DESC
  LIMIT 1
  FOR UPDATE OF p;

  IF v_payment.id IS NULL AND v_invoice_number IS NOT NULL THEN
    SELECT p.* INTO v_payment
    FROM public.invoices i
    JOIN public.invoice_payment_allocations a ON a.invoice_id = i.id
    JOIN public.payments p ON p.id = a.payment_id
    WHERE i.invoice_number = v_invoice_number
      AND lower(p.provider) = 'kushki'
    ORDER BY p.paid_at DESC
    LIMIT 1
    FOR UPDATE OF p;
  END IF;

  IF v_payment.id IS NULL THEN
    RAISE EXCEPTION 'KUSHKI_ORIGINAL_PAYMENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  SELECT i.* INTO v_invoice
  FROM public.invoices i
  JOIN public.invoice_payment_allocations a ON a.invoice_id = i.id
  WHERE a.payment_id = v_payment.id
  ORDER BY i.issued_at DESC
  LIMIT 1
  FOR UPDATE OF i;

  SELECT COALESCE(sum(amount), 0) INTO v_total_refunded
  FROM public.payment_refunds
  WHERE payment_id = v_payment.id AND status = 'completed';

  IF v_amount > v_payment.amount OR v_total_refunded + v_amount > v_payment.amount + 0.01 THEN
    RAISE EXCEPTION 'KUSHKI_REFUND_AMOUNT_INVALID' USING ERRCODE = '22003';
  END IF;

  INSERT INTO public.payment_refunds (
    payment_id, payment_event_id, provider_reference, refund_type,
    amount, currency, status
  ) VALUES (
    v_payment.id, v_event.id, v_reference, lower(v_transaction_type),
    v_amount, 'USD', 'completed'
  ) RETURNING * INTO v_refund;

  v_total_refunded := v_total_refunded + v_amount;

  IF v_invoice.id IS NOT NULL THEN
    UPDATE public.invoices
    SET status = CASE
          WHEN v_total_refunded >= total - 0.01 AND v_transaction_type = 'VOID' THEN 'void'
          WHEN v_total_refunded >= total - 0.01 THEN 'refunded'
          ELSE 'partially_refunded'
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_invoice.id;
  END IF;

  IF v_total_refunded >= v_payment.amount - 0.01 THEN
    UPDATE public.payments SET status = 'refunded' WHERE id = v_payment.id;

    -- Only the most recent paid period affects current access.
    IF NOT EXISTS (
      SELECT 1 FROM public.payments newer
      WHERE newer.subscription_id = v_payment.subscription_id
        AND newer.id <> v_payment.id
        AND newer.status = 'completed'
        AND newer.paid_at > v_payment.paid_at
    ) THEN
      SELECT status INTO v_previous_status
      FROM public.schools
      WHERE id = v_payment.school_id
      FOR UPDATE;

      IF v_previous_status::text IN ('active', 'trial') THEN
        UPDATE public.subscriptions
        SET status = 'grace_period',
            next_billing_date = timezone('utc'::text, now()),
            grace_period_until = timezone('utc'::text, now()) + interval '7 days',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_payment.subscription_id;

        UPDATE public.schools
        SET status = 'grace_period', is_active = true,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_payment.school_id;

        INSERT INTO public.tenant_status_logs (
          school_id, previous_status, new_status, reason, observation, actor_id
        ) VALUES (
          v_payment.school_id, v_previous_status, 'grace_period',
          'Pago Kushki devuelto',
          'Se habilitó un periodo de gracia de 7 días para revisión financiera.', NULL
        );
        v_changes_access := true;
      END IF;
    END IF;
  END IF;

  INSERT INTO public.audit_log (
    school_id, user_id, action, table_name, record_id, new_values
  ) VALUES (
    v_payment.school_id, NULL, 'KUSHKI_REFUND_PROCESSED', 'payment_refunds', v_refund.id::text,
    jsonb_build_object(
      'event_id', v_event.id,
      'payment_id', v_payment.id,
      'refund_type', lower(v_transaction_type),
      'amount', v_amount,
      'total_refunded', v_total_refunded,
      'access_changed', v_changes_access
    )
  );

  UPDATE public.payment_events
  SET status = 'processed', school_id = v_payment.school_id, payment_id = v_payment.id,
      attempt_count = attempt_count + 1, error_message = NULL,
      processed_at = timezone('utc'::text, now())
  WHERE id = v_event.id;

  RETURN json_build_object(
    'success', true,
    'duplicate', false,
    'event_id', v_event.id,
    'status', 'processed',
    'refund_id', v_refund.id,
    'payment_id', v_payment.id,
    'access_changed', v_changes_access
  );
END;
$$;

ALTER TABLE public.payment_refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Billing reads refunds"
ON public.payment_refunds FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.payments p
    WHERE p.id = payment_id
      AND (
        public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance'])
        OR (p.school_id = public.get_user_school_id() AND public.has_tenant_permission('billing.read'))
      )
  )
);

REVOKE ALL ON TABLE public.payment_refunds FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.payment_refunds TO authenticated;
GRANT ALL ON TABLE public.payment_refunds TO service_role;
REVOKE ALL ON FUNCTION public.process_kushki_refund_event(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_kushki_refund_event(uuid) TO service_role;


-- ====================================================================
-- MIGRATION: 23_p3_billing_ledger.sql
-- PURPOSE: Idempotent invoices, payment allocation and provider events.
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE RESTRICT,
  subscription_id uuid REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  invoice_number text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'issued'
    CHECK (status IN ('draft', 'issued', 'partially_paid', 'paid', 'overdue', 'void')),
  currency text NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'),
  subtotal numeric(12,2) NOT NULL CHECK (subtotal >= 0),
  tax numeric(12,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
  total numeric(12,2) NOT NULL CHECK (total >= 0),
  period_start timestamptz,
  period_end timestamptz,
  issued_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  due_at timestamptz,
  paid_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT invoices_total_components_check CHECK (total = subtotal + tax),
  CONSTRAINT invoices_period_check CHECK (
    period_start IS NULL OR period_end IS NULL OR period_end > period_start
  )
);

CREATE TABLE IF NOT EXISTS public.invoice_payment_allocations (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  invoice_id uuid NOT NULL REFERENCES public.invoices(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (invoice_id, payment_id)
);

CREATE TABLE IF NOT EXISTS public.payment_events (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  provider text NOT NULL,
  provider_event_id text NOT NULL,
  event_type text NOT NULL,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  payload_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'processed', 'ignored', 'failed')),
  school_id uuid REFERENCES public.schools(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  error_message text,
  received_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  processed_at timestamptz,
  UNIQUE (provider, provider_event_id)
);

CREATE INDEX IF NOT EXISTS idx_invoices_school_status
  ON public.invoices (school_id, status, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_subscription
  ON public.invoices (subscription_id, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_invoice_allocations_payment
  ON public.invoice_payment_allocations (payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_status_received
  ON public.payment_events (status, received_at);
CREATE INDEX IF NOT EXISTS idx_payment_events_school
  ON public.payment_events (school_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_events_payment
  ON public.payment_events (payment_id);

CREATE OR REPLACE FUNCTION public.ingest_payment_event(
  p_provider text,
  p_provider_event_id text,
  p_event_type text,
  p_payload_hash text,
  p_payload_summary jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_provider text := lower(nullif(trim(p_provider), ''));
  v_event_id text := nullif(trim(p_provider_event_id), '');
  v_hash text := lower(nullif(trim(p_payload_hash), ''));
  v_row public.payment_events%ROWTYPE;
BEGIN
  IF v_provider IS NULL OR v_event_id IS NULL OR nullif(trim(p_event_type), '') IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_IDENTITY_REQUIRED' USING ERRCODE = '22023';
  END IF;
  IF v_hash IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_HASH_INVALID' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.payment_events (
    provider, provider_event_id, event_type, payload_hash, payload_summary
  ) VALUES (
    v_provider, v_event_id, trim(p_event_type), v_hash, COALESCE(p_payload_summary, '{}'::jsonb)
  )
  ON CONFLICT (provider, provider_event_id) DO NOTHING
  RETURNING * INTO v_row;

  IF v_row.id IS NOT NULL THEN
    RETURN json_build_object('success', true, 'duplicate', false, 'event_id', v_row.id);
  END IF;

  SELECT * INTO v_row
  FROM public.payment_events
  WHERE provider = v_provider AND provider_event_id = v_event_id;

  IF v_row.payload_hash <> v_hash OR v_row.event_type <> trim(p_event_type) THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_REPLAY_MISMATCH' USING ERRCODE = '22000';
  END IF;

  RETURN json_build_object(
    'success', true,
    'duplicate', true,
    'event_id', v_row.id,
    'status', v_row.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_payment_event(
  p_event_id uuid,
  p_status text,
  p_school_id uuid DEFAULT NULL,
  p_payment_id uuid DEFAULT NULL,
  p_error_message text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_row public.payment_events%ROWTYPE;
BEGIN
  IF p_status NOT IN ('processed', 'ignored', 'failed') THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_STATUS_INVALID' USING ERRCODE = '22023';
  END IF;

  UPDATE public.payment_events
  SET status = p_status,
      school_id = COALESCE(p_school_id, school_id),
      payment_id = COALESCE(p_payment_id, payment_id),
      attempt_count = attempt_count + 1,
      error_message = CASE WHEN p_status = 'failed' THEN nullif(trim(p_error_message), '') ELSE NULL END,
      processed_at = CASE WHEN p_status IN ('processed', 'ignored') THEN timezone('utc'::text, now()) ELSE NULL END
  WHERE id = p_event_id
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_EVENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  RETURN json_build_object(
    'success', true,
    'event_id', v_row.id,
    'status', v_row.status,
    'attempt_count', v_row.attempt_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_completed_payment_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_invoice public.invoices%ROWTYPE;
  v_subscription public.subscriptions%ROWTYPE;
  v_allocated numeric(12,2);
BEGIN
  IF NEW.status <> 'completed' OR nullif(trim(NEW.external_invoice_number), '') IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE id = NEW.subscription_id;

  SELECT * INTO v_invoice
  FROM public.invoices
  WHERE invoice_number = trim(NEW.external_invoice_number)
  FOR UPDATE;

  IF v_invoice.id IS NULL THEN
    INSERT INTO public.invoices (
      school_id, subscription_id, invoice_number, status, currency,
      subtotal, tax, total, period_start, period_end, issued_at, due_at,
      metadata, created_by
    ) VALUES (
      NEW.school_id, NEW.subscription_id, trim(NEW.external_invoice_number), 'issued', NEW.currency,
      NEW.amount, 0, NEW.amount, v_subscription.started_at, v_subscription.next_billing_date,
      NEW.paid_at, NEW.paid_at,
      jsonb_build_object('source', NEW.provider, 'payment_type', NEW.payment_type),
      NEW.recorded_by
    ) RETURNING * INTO v_invoice;
  ELSIF v_invoice.school_id <> NEW.school_id
     OR v_invoice.currency <> NEW.currency
     OR v_invoice.total <> NEW.amount
     OR v_invoice.status = 'void' THEN
    RAISE EXCEPTION 'INVOICE_PAYMENT_MISMATCH' USING ERRCODE = '22000';
  END IF;

  INSERT INTO public.invoice_payment_allocations (
    invoice_id, payment_id, amount, created_by
  ) VALUES (
    v_invoice.id, NEW.id, NEW.amount, NEW.recorded_by
  )
  ON CONFLICT (invoice_id, payment_id) DO NOTHING;

  SELECT COALESCE(sum(amount), 0) INTO v_allocated
  FROM public.invoice_payment_allocations
  WHERE invoice_id = v_invoice.id;

  UPDATE public.invoices
  SET status = CASE
        WHEN v_allocated >= total THEN 'paid'
        WHEN v_allocated > 0 THEN 'partially_paid'
        ELSE status
      END,
      paid_at = CASE WHEN v_allocated >= total THEN COALESCE(paid_at, NEW.paid_at) ELSE paid_at END,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_invoice.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_completed_payment_invoice ON public.payments;
CREATE TRIGGER sync_completed_payment_invoice
AFTER INSERT OR UPDATE OF status, external_invoice_number ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.sync_completed_payment_invoice();

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Billing reads invoices"
ON public.invoices FOR SELECT TO authenticated
USING (
  public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance'])
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('billing.read'))
);
CREATE POLICY "Platform inserts invoices"
ON public.invoices FOR INSERT TO authenticated
WITH CHECK (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']));
CREATE POLICY "Platform updates invoices"
ON public.invoices FOR UPDATE TO authenticated
USING (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']))
WITH CHECK (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']));
CREATE POLICY "Platform deletes invoices"
ON public.invoices FOR DELETE TO authenticated
USING (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']));

CREATE POLICY "Billing reads allocations"
ON public.invoice_payment_allocations FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.invoices i
    WHERE i.id = invoice_id
      AND (
        public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance'])
        OR (i.school_id = public.get_user_school_id() AND public.has_tenant_permission('billing.read'))
      )
  )
);

CREATE POLICY "Platform reads payment events"
ON public.payment_events FOR SELECT TO authenticated
USING (public.has_platform_role(ARRAY['platform_owner', 'platform_admin', 'platform_finance']));

REVOKE ALL ON TABLE public.invoices, public.invoice_payment_allocations, public.payment_events FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.invoices, public.invoice_payment_allocations TO authenticated;
GRANT SELECT ON TABLE public.payment_events TO authenticated;
GRANT ALL ON TABLE public.invoices, public.invoice_payment_allocations, public.payment_events TO service_role;

REVOKE ALL ON FUNCTION public.ingest_payment_event(text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_payment_event(uuid, text, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_completed_payment_invoice() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ingest_payment_event(text, text, text, text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_payment_event(uuid, text, uuid, uuid, text) TO service_role;

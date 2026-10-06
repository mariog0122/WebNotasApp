-- Cover the two actor foreign keys introduced by the P3 billing ledger.
CREATE INDEX IF NOT EXISTS idx_invoices_created_by
  ON public.invoices (created_by);

CREATE INDEX IF NOT EXISTS idx_invoice_allocations_created_by
  ON public.invoice_payment_allocations (created_by);

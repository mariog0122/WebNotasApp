import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('auditable billing operations', () => {
  it('records payments and status changes through transactional RPCs', () => {
    const source = readFileSync(
      new URL('../src/views/superadmin/TenantsTab.vue', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('record_manual_payment'")
    expect(source).toContain("rpc('set_tenant_status'")
    expect(source).not.toMatch(/from\('schools'\)\.update/)
    expect(source).not.toMatch(/from\('tenant_status_logs'\)\.insert/)
  })

  it('keeps invoices, allocations and provider events idempotent', () => {
    const migration = readFileSync(
      new URL('../../migrations/23_p3_billing_ledger.sql', import.meta.url),
      'utf8',
    )

    expect(migration).toContain('CREATE TABLE IF NOT EXISTS public.invoices')
    expect(migration).toContain('CREATE TABLE IF NOT EXISTS public.invoice_payment_allocations')
    expect(migration).toContain('CREATE TABLE IF NOT EXISTS public.payment_events')
    expect(migration).toContain('UNIQUE (provider, provider_event_id)')
    expect(migration).toContain('PAYMENT_EVENT_REPLAY_MISMATCH')
    expect(migration).toContain('sync_completed_payment_invoice')
    expect(migration).toContain('GRANT EXECUTE ON FUNCTION public.ingest_payment_event')
    expect(migration).toContain('TO service_role')
  })

  it('authenticates Kushki webhooks before storing a redacted event summary', () => {
    const source = readFileSync(
      new URL('../../supabase/functions/kushki-webhook/index.ts', import.meta.url),
      'utf8',
    )

    expect(source).toContain("headers.get('x-kushki-signature')")
    expect(source).toContain("headers.get('x-kushki-id')")
    expect(source).toContain("headers.get('x-kushki-key')")
    expect(source).toContain('KUSHKI_WEBHOOK_SIGNATURE')
    expect(source).toContain('KUSHKI_MERCHANT_ID')
    expect(source).toContain("crypto.subtle.importKey")
    expect(source).toContain('constantTimeEqual')
    expect(source).toContain("rpc('ingest_payment_event'")
    expect(source).toContain('p_payload_summary')
    expect(source).not.toContain('SUPABASE_ANON_KEY')
  })

  it('exposes the reconciled invoice history to platform operators', () => {
    const source = readFileSync(
      new URL('../src/views/superadmin/TenantsTab.vue', import.meta.url),
      'utf8',
    )

    expect(source).toContain("from('invoices')")
    expect(source).toContain('openInvoicesModal')
    expect(source).toContain('invoice_payment_allocations')
    expect(source).toContain('Historial de facturas')
  })

  it('processes approved Kushki events atomically and safely on retries', () => {
    const migration = readFileSync(
      new URL('../../migrations/25_p3_kushki_event_processing.sql', import.meta.url),
      'utf8',
    )
    const webhook = readFileSync(
      new URL('../../supabase/functions/kushki-webhook/index.ts', import.meta.url),
      'utf8',
    )

    expect(migration).toContain('process_kushki_payment_event')
    expect(migration).toContain('KUSHKI_PAYMENT_AMOUNT_MISMATCH')
    expect(migration).toContain('KUSHKI_EVENT_MAPPING_REQUIRED')
    expect(migration).toContain("provider, provider_reference")
    expect(migration).toContain("TO service_role")
    expect(webhook).toContain("rpc('process_kushki_payment_event'")
    expect(webhook).toContain('invoice_number')
    expect(webhook).toContain('school_id')
    expect(webhook).toContain('body.created > 10_000_000_000')
  })

  it('reconciles Kushki refunds and voids without duplicating reversals', () => {
    const migration = readFileSync(
      new URL('../../migrations/26_p3_kushki_refunds.sql', import.meta.url),
      'utf8',
    )
    const webhook = readFileSync(
      new URL('../../supabase/functions/kushki-webhook/index.ts', import.meta.url),
      'utf8',
    )

    expect(migration).toContain('CREATE TABLE IF NOT EXISTS public.payment_refunds')
    expect(migration).toContain('process_kushki_refund_event')
    expect(migration).toContain('KUSHKI_REFUND_AMOUNT_INVALID')
    expect(migration).toContain("'partially_refunded'")
    expect(migration).toContain("TO service_role")
    expect(webhook).toContain("rpc('process_kushki_refund_event'")
    expect(webhook).toContain('sale_transaction_reference')
    expect(webhook).toContain('sale_ticket_number')
  })
})

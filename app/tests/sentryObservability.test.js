import { describe, expect, it, vi } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

import { parseSentryDsn, sendSentryEnvelope, reportClientError } from '../src/lib/telemetry'
import { toEdgeErrorCode } from '../../supabase/functions/_shared/telemetry'

const root = path.resolve(import.meta.dirname, '..')
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8')

describe('Sprint 6: Production Observability, Sentry & Edge Functions Alerting', () => {
  it('never persists arbitrary exception messages in Edge telemetry', () => {
    expect(toEdgeErrorCode(new Error('MANAGE_TENANT_USER_FAILED'))).toBe('MANAGE_TENANT_USER_FAILED')
    expect(toEdgeErrorCode(new Error('user mario@example.com failed'))).toBe('UNEXPECTED_EDGE_FUNCTION_ERROR')
    expect(toEdgeErrorCode('')).toBe('UNEXPECTED_EDGE_FUNCTION_ERROR')
  })

  it('parses valid Sentry DSNs and rejects invalid formats', () => {
    const validDsn = 'https://abcdef1234567890@o123456.ingest.sentry.io/9876543'
    const parsed = parseSentryDsn(validDsn)

    expect(parsed).toMatchObject({
      publicKey: 'abcdef1234567890',
      projectId: '9876543',
      host: 'o123456.ingest.sentry.io',
      envelopeEndpoint: 'https://o123456.ingest.sentry.io/api/9876543/envelope/',
    })

    expect(parseSentryDsn('')).toBeNull()
    expect(parseSentryDsn(null)).toBeNull()
    expect(parseSentryDsn('not-a-valid-url')).toBeNull()
  })

  it('formats and dispatches valid Sentry envelopes honoring privacy contracts', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({ ok: true })
    globalThis.fetch = fetchSpy

    const event = {
      fingerprint: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      error_name: 'TypeError',
      error_code: 'NETWORK_TIMEOUT',
      source: 'vue',
      route: '/grades',
      release: 'v1.5.0',
    }

    const dsn = 'https://testkey@sentry.example.com/12345'
    const result = await sendSentryEnvelope(dsn, event, { environment: 'production' })

    expect(result).toBe(true)
    expect(fetchSpy).toHaveBeenCalledTimes(1)

    const [url, requestOptions] = fetchSpy.mock.calls[0]
    expect(url).toBe('https://sentry.example.com/api/12345/envelope/')
    expect(requestOptions.headers['Content-Type']).toBe('application/x-sentry-envelope')
    expect(requestOptions.headers['X-Sentry-Auth']).toContain('sentry_key=testkey')

    const body = requestOptions.body
    expect(body).toContain('"event_id"')
    expect(body).toContain('"type":"event"')
    expect(body).toContain('"platform":"javascript"')
    expect(body).toContain('"environment":"production"')
    expect(body).toContain('"route":"/grades"')
  })

  it('forwards errors to Sentry when sentryDsn is passed in reportClientError', async () => {
    const fetchSpy = vi.fn().mockResolvedValue({ ok: true })
    globalThis.fetch = fetchSpy

    const insert = vi.fn().mockResolvedValue({ error: null })
    const client = { from: vi.fn(() => ({ insert })) }

    const err = new Error('Test unhandled client error')
    const dsn = 'https://clientkey@sentry.example.com/54321'

    const success = await reportClientError(client, err, {
      source: 'window',
      route: '/courses',
      sentryDsn: dsn,
      environment: 'staging',
    })

    expect(success).toBe(true)
    expect(client.from).toHaveBeenCalledWith('client_error_events')
    expect(insert).toHaveBeenCalledTimes(1)
    expect(fetchSpy).toHaveBeenCalledTimes(1)
  })

  it('verifies Edge Functions 500 error table and burst alerting migration', () => {
    const migrationPath = path.resolve(root, '../supabase/migrations/20260907204500_edge_functions_observability_alerts.sql')
    expect(fs.existsSync(migrationPath)).toBe(true)

    const sql = fs.readFileSync(migrationPath, 'utf8')

    // Table definition
    expect(sql).toContain('CREATE TABLE IF NOT EXISTS public.edge_function_error_events')
    expect(sql).toContain('function_name text NOT NULL')
    expect(sql).toContain('status_code int DEFAULT 500 NOT NULL')

    // RLS
    expect(sql).toContain('ALTER TABLE public.edge_function_error_events ENABLE ROW LEVEL SECURITY;')
    expect(sql).toContain('ALTER TABLE public.edge_function_error_events FORCE ROW LEVEL SECURITY;')
    expect(sql).toContain('public.is_platform_admin()')

    // Burst detection RPCs
    expect(sql).toContain('CREATE OR REPLACE FUNCTION public.check_edge_function_error_burst')
    expect(sql).toContain('CREATE OR REPLACE FUNCTION public.record_edge_function_error')
    expect(sql).toContain("'EDGE_FUNCTION_BURST_ALERT'")
    expect(sql).toContain('GRANT EXECUTE ON FUNCTION public.record_edge_function_error')
    expect(sql).toContain('TO service_role;')
  })

  it('verifies shared Edge Function telemetry helper exists and exports reportEdgeFunctionError', () => {
    const helperPath = path.resolve(root, '../supabase/functions/_shared/telemetry.ts')
    expect(fs.existsSync(helperPath)).toBe(true)

    const helperCode = fs.readFileSync(helperPath, 'utf8')
    expect(helperCode).toContain('export async function reportEdgeFunctionError')
    expect(helperCode).toContain("adminClient.rpc('record_edge_function_error'")
    expect(helperCode).toContain('alert_triggered')
  })

  it('connects every mutable tenant and billing Edge Function to protected telemetry', () => {
    const functions = [
      'provision-tenant/index.ts',
      'manage-tenant-user/index.ts',
      'invite-tenant-user/index.ts',
      'kushki-webhook/index.ts',
    ]

    for (const relativePath of functions) {
      const source = fs.readFileSync(path.resolve(root, `../supabase/functions/${relativePath}`), 'utf8')
      expect(source, relativePath).toContain('reportEdgeFunctionError')
    }
  })

  it('verifies main.js wires up Sentry DSN configuration to error telemetry', () => {
    const mainSource = read('src/main.js')
    expect(mainSource).toContain('installErrorTelemetry')
    expect(mainSource).toContain('VITE_SENTRY_DSN')
    expect(mainSource).toContain('sentryDsn:')
  })
})

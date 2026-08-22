import { describe, expect, it, vi } from 'vitest'
import { readFileSync } from 'node:fs'

import { buildClientErrorEvent, reportClientError, sanitizeRoute } from '../src/lib/telemetry'

describe('privacy-preserving client observability', () => {
  it('removes query strings and fragments from reported routes', () => {
    expect(sanitizeRoute('/students?student_id=secret#profile')).toBe('/students')
    expect(sanitizeRoute('https://school.example/grades?course=private')).toBe('/grades')
    expect(sanitizeRoute('/students/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')).toBe('/students/:id')
    expect(sanitizeRoute('/reports/12345')).toBe('/reports/:id')
  })

  it('fingerprints errors without persisting messages or stack traces', async () => {
    const error = Object.assign(new Error('Student Jane Doe failed at /students?id=secret'), {
      code: 'PGRST116',
    })
    const event = await buildClientErrorEvent(error, {
      source: 'vue',
      route: '/students?id=secret',
      release: 'test-release',
    })

    expect(event).toMatchObject({
      error_name: 'Error',
      error_code: 'PGRST116',
      source: 'vue',
      route: '/students',
      release: 'test-release',
    })
    expect(event.fingerprint).toMatch(/^[0-9a-f]{64}$/)
    expect(event).not.toHaveProperty('message')
    expect(event).not.toHaveProperty('stack')
    expect(JSON.stringify(event)).not.toContain('Jane Doe')
    expect(JSON.stringify(event)).not.toContain('secret')
  })

  it('writes only the minimized event to the protected telemetry table', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    const from = vi.fn(() => ({ insert }))

    const result = await reportClientError(
      { from },
      Object.assign(new Error('private detail'), { code: 'NETWORK_ERROR' }),
      { source: 'unhandledrejection', route: '/reports?student=private', release: 'test' },
    )

    expect(result).toBe(true)
    expect(from).toHaveBeenCalledWith('client_error_events')
    expect(insert).toHaveBeenCalledTimes(1)
    expect(insert.mock.calls[0][0]).not.toHaveProperty('message')
    expect(insert.mock.calls[0][0].route).toBe('/reports')
  })

  it('defines tenant-safe storage, server-side identity and rate limiting', () => {
    const migration = readFileSync(
      new URL('../../migrations/27_p2_client_observability.sql', import.meta.url),
      'utf8',
    )
    const bootstrap = readFileSync(new URL('../src/main.js', import.meta.url), 'utf8')

    expect(migration).toContain('CREATE TABLE IF NOT EXISTS public.client_error_events')
    expect(migration).toContain('ENABLE ROW LEVEL SECURITY')
    expect(migration).toContain('NEW.user_id := auth.uid()')
    expect(migration).toContain('NEW.school_id := public.get_user_school_id()')
    expect(migration).toContain('CLIENT_ERROR_RATE_LIMITED')
    expect(migration).toContain('public.is_platform_admin()')
    expect(migration).toContain('REVOKE ALL ON public.client_error_events FROM PUBLIC, anon, authenticated')
    expect(migration).toContain('REVOKE ALL ON FUNCTION public.prepare_client_error_event() FROM PUBLIC, anon, authenticated')
    expect(migration).toContain("'purge-client-error-events'")
    expect(migration).toContain("interval '90 days'")
    expect(bootstrap).toContain('installErrorTelemetry')
  })
})

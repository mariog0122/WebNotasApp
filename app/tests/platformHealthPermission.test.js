import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('platform health database permission', () => {
  it('grants the authenticated application role, while keeping the RPC unavailable to anonymous callers', () => {
    const migration = readFileSync(
      new URL('../../supabase/migrations/20260907004700_fix_platform_health_permission.sql', import.meta.url),
      'utf8',
    )
    expect(migration).toContain('REVOKE ALL ON FUNCTION public.get_platform_health() FROM PUBLIC, anon;')
    expect(migration).toContain('GRANT EXECUTE ON FUNCTION public.get_platform_health() TO authenticated;')
  })
})

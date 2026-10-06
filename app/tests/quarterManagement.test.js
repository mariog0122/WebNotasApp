import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const dashboard = readFileSync(new URL('../src/views/Dashboard.vue', import.meta.url), 'utf8')
const gradesPage = readFileSync(new URL('../src/composables/useGradesPage.js', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919160000_atomic_quarter_management.sql', import.meta.url),
  'utf8',
)
const creationMigration = readFileSync(
  new URL('../../supabase/migrations/20260919200000_secure_default_quarter_creation.sql', import.meta.url),
  'utf8',
)

describe('atomic quarter management', () => {
  it('activates and locks periods only through confirmed RPC responses', () => {
    expect(dashboard).toContain("rpc('set_active_quarter'")
    expect(dashboard).toContain("rpc('set_quarter_lock'")
    expect(dashboard).not.toMatch(/from\('quarters'\)\.update/)
    expect(dashboard).toContain('La base de datos no confirmó el período activo.')
  })

  it('serializes activation and restricts both operations to institutional settings managers', () => {
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain("public.has_tenant_permission('settings.manage')")
    expect(migration).toContain('v_quarter.school_id is distinct from public.get_user_school_id()')
    expect(migration).toContain('grant execute on function public.set_active_quarter(uuid)')
    expect(migration).toContain('grant execute on function public.set_quarter_lock(uuid, boolean)')
  })

  it('creates the complete default period set through one confirmed server transaction', () => {
    expect(gradesPage).toContain("rpc('create_default_quarters'")
    expect(gradesPage).not.toMatch(/from\('quarters'\)\s*\n?\s*\.insert/)
    expect(gradesPage).toContain('La base de datos no confirmó todos los períodos creados.')
    expect(creationMigration).toContain('pg_advisory_xact_lock')
    expect(creationMigration).toContain("public.has_tenant_permission('settings.manage')")
    expect(creationMigration).toContain("raise exception 'La institución ya tiene períodos configurados'")
    expect(creationMigration).toContain('revoke insert, update, delete on public.quarters from authenticated')
  })
})

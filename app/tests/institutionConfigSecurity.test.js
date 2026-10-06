import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const dashboard = readFileSync(new URL('../src/views/Dashboard.vue', import.meta.url), 'utf8')
const tenantService = readFileSync(new URL('../src/services/tenantService.js', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919203000_secure_institution_config.sql', import.meta.url),
  'utf8',
)

describe('secure institution configuration', () => {
  it('saves the identity through one confirmed tenant RPC and cleans failed uploads', () => {
    expect(dashboard).toContain("rpc('save_institution_identity'")
    expect(dashboard).toContain('La base de datos no confirmó la configuración institucional.')
    expect(dashboard).toContain("supabase.storage.from('institution-assets').remove([uploadedLogoPath])")
    expect(dashboard).not.toMatch(/from\('system_config'\)[\s\S]{0,120}\.upsert\(/)
  })

  it('removes legacy system_config write fallbacks and revokes browser mutations', () => {
    expect(tenantService).not.toMatch(/from\('system_config'\)[\s\S]{0,180}\.(upsert|delete)\(/)
    expect(migration).toContain("public.has_tenant_permission('settings.manage')")
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain('revoke insert, update, delete on public.system_config from authenticated')
  })
})

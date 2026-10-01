import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const readApp = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const readRoot = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8')

describe('atomic tenant user role management', () => {
  it('uses one authorized RPC instead of two inconsistent browser updates', () => {
    const dashboard = readApp('src/views/Dashboard.vue')

    expect(dashboard).toContain("rpc('update_tenant_user_role'")
    expect(dashboard).not.toMatch(/from\('tenant_memberships'\)[\s\S]{0,160}\.update\(\{ role:/)
    expect(dashboard).not.toMatch(/from\('profiles'\)[\s\S]{0,160}\.update\(\{ role:/)
  })

  it('authorizes the target school and synchronizes membership plus legacy profile role', () => {
    const migration = readRoot('supabase/migrations/20260919153000_atomic_tenant_user_role_management.sql')

    expect(migration).toContain("public.has_tenant_permission('users.manage')")
    expect(migration).toContain('p_school_id is distinct from public.get_user_school_id()')
    expect(migration).toContain('tenant_role_id = excluded.tenant_role_id')
    expect(migration).toContain("case when v_role_name = 'teacher' then 'teacher' else 'admin' end")
    expect(migration).toContain('TENANT_USER_ROLE_UPDATED')
  })
})

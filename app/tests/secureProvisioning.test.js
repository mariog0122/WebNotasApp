import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('secure tenant provisioning', () => {
  it('orchestrates tenant creation through an authenticated Edge Function', () => {
    const wizardSource = readFileSync(
      new URL('../src/views/superadmin/WizardTab.vue', import.meta.url),
      'utf8',
    )

    expect(wizardSource).toContain("functions.invoke('provision-tenant'")
    expect(wizardSource).not.toContain("rpc('provision_tenant_wizard'")
  })

  it('verifies the caller and creates a confirmed password administrator server-side', () => {
    const functionSource = readFileSync(
      new URL('../../supabase/functions/provision-tenant/index.ts', import.meta.url),
      'utf8',
    )

    expect(functionSource).toContain('auth.getUser')
    expect(functionSource).toContain("rpc('is_platform_admin')")
    expect(functionSource).toContain('auth.admin.createUser')
    expect(functionSource).toContain('email_confirm: true')
    expect(functionSource).toContain('adminPassword')
    expect(functionSource).toContain('inviteUserByEmail')
    expect(functionSource).toContain('SUPABASE_SERVICE_ROLE_KEY')
  })

  it('lets tenant administrators invite teachers only through a verified Edge Function', () => {
    const dashboardSource = readFileSync(
      new URL('../src/views/Dashboard.vue', import.meta.url),
      'utf8',
    )
    const functionSource = readFileSync(
      new URL('../../supabase/functions/invite-tenant-user/index.ts', import.meta.url),
      'utf8',
    )

    expect(dashboardSource).toContain("functions.invoke('manage-tenant-user'")
    expect(functionSource).toContain('auth.getUser')
    expect(functionSource).toContain('inviteUserByEmail')
    expect(functionSource).toContain("role !== 'teacher'")
    expect(dashboardSource).toContain('schoolId: authStore.activeSchoolId')
    expect(functionSource).toContain("rpc('is_platform_admin')")
    expect(functionSource).toContain("rpc('has_tenant_permission'")
    expect(functionSource).toContain('targetSchoolId')
    expect(functionSource).not.toContain("['admin', 'superadmin'].includes(callerProfile.role)")
    expect(functionSource).toContain("action: 'TENANT_USER_INVITED'")
  })
})

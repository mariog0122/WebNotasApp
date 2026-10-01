import { describe, expect, it, vi } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'

const source = readFileSync(new URL('../src/views/superadmin/TenantsTab.vue', import.meta.url), 'utf8')

let statusModule = null
try {
  statusModule = await import('../src/lib/superadminTenantStatus.js')
} catch {
  // RED: the explicit target API does not exist yet.
}

describe('superadmin institution status actions', () => {
  it('passes the institution from the clicked row and never falls back to modal selection state', () => {
    expect(source).toContain("const executeStatusChange = async (newStatus, targetTenant) =>")
    expect(source).toContain('@click="executeStatusChange(\'active\', t)"')
    expect(source).not.toContain("executeStatusChange('active', tenant)")
    expect(source).not.toContain('tenant = selectedTenant.value')
  })

  it('uses a dedicated action target for suspension confirmation', () => {
    expect(source).toContain('const statusActionTarget = ref(null)')
    expect(source).toContain("executeStatusChange('suspended', statusActionTarget)")
  })

  it('keeps institution deletion behind the authorized RPC without a direct-table fallback', () => {
    expect(source).toContain("rpc('delete_tenant'")
    expect(source).toContain("if (!data?.success) throw new Error('La función segura rechazó la eliminación de la institución.')")
    expect(source).not.toMatch(/if \(error\) \{[\s\S]{0,200}from\('schools'\)[\s\S]{0,100}\.delete\(\)/)
  })

  it('sends institution A even when institution B is the unrelated selected context', async () => {
    expect(statusModule?.createTenantStatusManager).toBeTypeOf('function')

    const rpc = vi.fn().mockResolvedValue({
      data: { success: true, changed: true, previous_status: 'suspended', new_status: 'active' },
      error: null
    })
    const selectedInstitution = { id: '22222222-2222-4222-8222-222222222222' }
    const targetInstitution = { id: '11111111-1111-4111-8111-111111111111' }
    const manager = statusModule.createTenantStatusManager({ rpc })

    await manager.changeStatus({
      targetInstitutionId: targetInstitution.id,
      newStatus: 'active',
      reason: 'Reactivación manual'
    })

    expect(selectedInstitution.id).not.toBe(targetInstitution.id)
    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc).toHaveBeenCalledWith('set_tenant_status', expect.objectContaining({
      p_school_id: targetInstitution.id,
      p_new_status: 'active'
    }))
  })

  it('rejects invalid targets before calling the backend', async () => {
    expect(statusModule?.createTenantStatusManager).toBeTypeOf('function')
    const rpc = vi.fn()
    const manager = statusModule.createTenantStatusManager({ rpc })

    await expect(manager.changeStatus({ targetInstitutionId: null, newStatus: 'active' }))
      .rejects.toMatchObject({ code: 'INVALID_INSTITUTION_ID' })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('deduplicates double clicks while the same status operation is in flight', async () => {
    expect(statusModule?.createTenantStatusManager).toBeTypeOf('function')
    let finishRequest
    const rpc = vi.fn(() => new Promise(resolve => { finishRequest = resolve }))
    const manager = statusModule.createTenantStatusManager({ rpc })
    const input = {
      targetInstitutionId: '11111111-1111-4111-8111-111111111111',
      newStatus: 'active'
    }

    const first = manager.changeStatus(input)
    const duplicate = await manager.changeStatus(input)
    expect(duplicate).toMatchObject({ success: true, changed: false, skipped: true })
    expect(rpc).toHaveBeenCalledOnce()

    finishRequest({ data: { success: true, changed: true }, error: null })
    await first
  })

  it('converts backend details into a controlled user-facing error', async () => {
    expect(statusModule?.createTenantStatusManager).toBeTypeOf('function')
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { code: '42501', message: 'permission denied for internal relation private_data' }
    })
    const manager = statusModule.createTenantStatusManager({ rpc })

    await expect(manager.changeStatus({
      targetInstitutionId: '11111111-1111-4111-8111-111111111111',
      newStatus: 'active'
    })).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'No tienes autorización para cambiar el estado de esta institución.'
    })
  })

  it('includes a later database hardening migration with least-privilege and idempotency controls', () => {
    const migrationsDir = new URL('../../supabase/migrations/', import.meta.url)
    const migrationText = readdirSync(migrationsDir)
      .filter(name => name.endsWith('.sql'))
      .sort()
      .map(name => readFileSync(new URL(name, migrationsDir), 'utf8'))
      .join('\n')

    expect(migrationText).toContain("'changed', false")
    expect(migrationText).toMatch(/REVOKE ALL ON FUNCTION public\.set_tenant_status\(uuid, text, text, text\) FROM PUBLIC, anon/i)
    expect(migrationText).toMatch(/GRANT EXECUTE ON FUNCTION public\.set_tenant_status\(uuid, text, text, text\) TO authenticated, service_role/i)
  })
})

import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../src/views/superadmin/TenantsTab.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919173000_atomic_tenant_academic_restore.sql', import.meta.url),
  'utf8',
)

describe('tenant academic backup and restore', () => {
  it('fails backup generation when any required query fails and scopes periods to the tenant', () => {
    expect(source).toContain("supabase.from('quarters').select('*').eq('school_id', schoolId)")
    expect(source).toContain('if (result.error) throw new Error')
    expect(source).toContain('if (gRes.error) throw new Error')
    expect(source).toContain('if (qgRes.error) throw new Error')
    expect(source).toContain('if (seRes.error) throw new Error')
    expect(source).toContain('academic_years: academicYearsRes.data || []')
    expect(source).toContain('tenant_limits: tenantLimitsRes.data || null')
  })

  it('uses one confirmed RPC and never restores tables directly from the browser', () => {
    const restoreBlock = source.slice(
      source.indexOf('const executeJsonRestore'),
      source.indexOf('onMounted(() =>'),
    )
    expect(restoreBlock).toContain("rpc('restore_tenant_academic_backup'")
    expect(restoreBlock).toContain('if (!data?.success || !data?.school_id)')
    expect(restoreBlock).not.toContain(".from('schools')")
    expect(restoreBlock).not.toContain('.insert(')
    expect(restoreBlock).not.toContain('.upsert(')
  })

  it('validates the file shape and limits its size before sending it to PostgreSQL', () => {
    expect(source).toContain('file.size > 25 * 1024 * 1024')
    expect(source).toContain('if (!Array.isArray(rows))')
    expect(source).toContain('Las relaciones académicas del respaldo no tienen un formato válido.')
  })

  it('restricts restore to platform owners and enforces atomic relational reconstruction', () => {
    expect(migration).toContain("public.has_platform_role(array['platform_owner'])")
    expect(migration).toContain('La institución destino debe estar vacía')
    expect(migration).toContain('v_course_map')
    expect(migration).toContain('v_student_map')
    expect(migration).toContain('v_definition_map')
    expect(migration).toContain('TENANT_ACADEMIC_BACKUP_RESTORED')
    expect(migration).toContain('on conflict (school_id) do update set')
    expect(migration).toContain('revoke all on function public.restore_tenant_academic_backup')
  })
})

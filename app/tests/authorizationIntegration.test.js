import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const readAppFile = (relativePath) =>
  readFileSync(new URL(`../${relativePath}`, import.meta.url), 'utf8')

describe('authorization integration', () => {
  it('loads the canonical database authorization context with the authenticated profile', () => {
    const authStore = readAppFile('src/stores/auth.js')

    expect(authStore).toContain("rpc('get_my_access_context')")
    expect(authStore).toContain('accessContext')
    expect(authStore).toContain('activeSchoolId')
    expect(authStore).not.toMatch(/const\s+userRole\s*=\s*authStore\.profile\?\.role\s*\|\|/)
  })

  it('uses permission metadata in the router and sends denied users to 403', () => {
    const router = readAppFile('src/router/index.js')

    expect(router).toContain("name: 'forbidden'")
    expect(router).toContain("permission: 'students.read'")
    expect(router).toContain('platformAdminOnly: true')
    expect(router).toContain('canAccessRoute')
    expect(router).not.toContain('requiresSuperAdmin')
    expect(router).not.toContain("['admin', 'superadmin'].includes")
  })

  it('builds navigation from canonical permissions instead of profile.role', () => {
    const sidebar = readAppFile('src/components/Sidebar.vue')

    expect(sidebar).toContain('hasAccessPermission')
    expect(sidebar).toContain('isPlatformAdmin')
    expect(sidebar).toContain('roleLabel')
    expect(sidebar).not.toMatch(/profile\?\.role\s*===/)
  })

  it('gates student mutations in handlers and in both responsive views', () => {
    const students = readAppFile('src/views/Students.vue')

    expect(students).toContain("hasAccessPermission(authStore.accessContext, 'students.create')")
    expect(students).toContain("hasAccessPermission(authStore.accessContext, 'students.update')")
    expect(students).toContain("hasAccessPermission(authStore.accessContext, 'students.delete')")
    expect(students).toContain('if (!canDeleteStudents.value) return rejectUnauthorizedWrite()')
    expect(students).toContain('v-if="canCreateStudents"')
    expect(students).toContain('v-if="canUpdateStudents"')
    expect(students).toContain('v-if="canDeleteStudents"')
  })

  it('does not make authorization decisions from legacy profile roles', () => {
    for (const file of [
      'src/router/index.js',
      'src/components/Sidebar.vue',
      'src/views/Dashboard.vue',
      'src/views/Profile.vue',
    ]) {
      expect(readAppFile(file), file).not.toMatch(/profile\?*\.role\s*(?:===|!==)|includes\(authStore\.profile\?\.role\)/)
    }
  })
})

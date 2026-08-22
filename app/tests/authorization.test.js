import { describe, expect, it } from 'vitest'
import {
  canAccessRoute,
  createAuthorizationContext,
  hasAccessPermission,
  isInstitutionAdmin,
  roleLabel,
} from '../src/lib/permissions.js'

const context = (overrides = {}) => createAuthorizationContext({
  user_id: 'user-1',
  is_platform_admin: false,
  is_platform_owner: false,
  platform_roles: [],
  default_school_id: 'school-a',
  memberships: [
    {
      school_id: 'school-a',
      role: 'teacher',
      permissions: ['students.read', 'grades.read', 'grades.create', 'grades.update', 'reports.read'],
    },
  ],
  ...overrides,
})

describe('canonical authorization context', () => {
  it('fails closed when the backend context is absent', () => {
    const access = createAuthorizationContext(null)

    expect(access.isPlatformAdmin).toBe(false)
    expect(access.activeMembership).toBeNull()
    expect(hasAccessPermission(access, 'students.read')).toBe(false)
    expect(canAccessRoute({ permission: 'students.read' }, access)).toBe(false)
  })

  it('lets a platform owner administer the SaaS without depending on a tenant role', () => {
    const access = context({
      is_platform_admin: true,
      is_platform_owner: true,
      platform_roles: ['platform_owner'],
      default_school_id: null,
      memberships: [],
    })

    expect(access.isPlatformAdmin).toBe(true)
    expect(access.isPlatformOwner).toBe(true)
    expect(isInstitutionAdmin(access)).toBe(true)
    expect(hasAccessPermission(access, 'students.delete')).toBe(true)
    expect(canAccessRoute({ platformAdminOnly: true }, access)).toBe(true)
  })

  it('uses the selected tenant membership and its database permissions', () => {
    const access = context({
      active_school_id: 'school-b',
      memberships: [
        { school_id: 'school-a', role: 'teacher', permissions: ['students.read'] },
        { school_id: 'school-b', role: 'school_admin', permissions: ['students.read', 'students.create'] },
      ],
    })

    expect(access.activeSchoolId).toBe('school-b')
    expect(access.activeMembership.role).toBe('school_admin')
    expect(isInstitutionAdmin(access)).toBe(true)
    expect(hasAccessPermission(access, 'students.create')).toBe(true)
  })

  it('does not grant student writes to a teacher through the legacy profile role', () => {
    const access = context()

    expect(hasAccessPermission(access, 'students.read')).toBe(true)
    expect(hasAccessPermission(access, 'students.create')).toBe(false)
    expect(hasAccessPermission(access, 'students.update')).toBe(false)
    expect(canAccessRoute({ permission: 'students.read' }, access)).toBe(true)
    expect(canAccessRoute({ permission: 'students.create' }, access)).toBe(false)
  })

  it('rejects a tenant selection outside the user memberships', () => {
    const access = createAuthorizationContext({
      ...context().raw,
      active_school_id: 'school-foreign',
    })

    expect(access.activeSchoolId).toBe('school-a')
    expect(access.activeMembership?.schoolId).toBe('school-a')
  })

  it('supports explicit route permissions and a readable role label', () => {
    const access = context()

    expect(canAccessRoute({ requiresAuth: true }, access)).toBe(true)
    expect(canAccessRoute({ permission: 'reports.read' }, access)).toBe(true)
    expect(canAccessRoute({ platformAdminOnly: true }, access)).toBe(false)
    expect(roleLabel(access)).toBe('Docente')
  })
})

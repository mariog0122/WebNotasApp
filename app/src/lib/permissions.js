/**
 * Autorización del cliente.
 *
 * La fuente de verdad es el contexto calculado por PostgreSQL. Estas funciones
 * solo sirven para presentar la UI correcta; RLS sigue siendo quien autoriza
 * cada lectura y escritura.
 */

export const PLATFORM_ROLES = Object.freeze({
  OWNER: 'platform_owner',
  ADMIN: 'platform_admin',
  SUPPORT: 'platform_support',
  FINANCE: 'platform_finance',
  READONLY: 'platform_readonly',
})

export const TENANT_ROLES = Object.freeze({
  SCHOOL_ADMIN: 'school_admin',
  RECTOR: 'rector',
  VICERRECTOR: 'vicerrector',
  SECRETARY: 'secretary',
  TEACHER: 'teacher',
  INSPECTOR: 'inspector',
  COUNSELOR: 'counselor',
  STUDENT: 'student',
  PARENT: 'parent',
})

// Conservado únicamente para componentes antiguos que aún muestran una etiqueta.
export const ROLES = Object.freeze({
  SUPERADMIN: 'superadmin',
  ADMIN: 'admin',
  TEACHER: 'teacher',
})

const INSTITUTION_ADMIN_ROLES = new Set([
  TENANT_ROLES.SCHOOL_ADMIN,
  TENANT_ROLES.RECTOR,
])

const ROLE_LABELS = Object.freeze({
  [PLATFORM_ROLES.OWNER]: 'Propietario de plataforma',
  [PLATFORM_ROLES.ADMIN]: 'Administrador de plataforma',
  [PLATFORM_ROLES.SUPPORT]: 'Soporte de plataforma',
  [PLATFORM_ROLES.FINANCE]: 'Finanzas de plataforma',
  [PLATFORM_ROLES.READONLY]: 'Auditor de plataforma',
  [TENANT_ROLES.SCHOOL_ADMIN]: 'Administrador institucional',
  [TENANT_ROLES.RECTOR]: 'Rector',
  [TENANT_ROLES.VICERRECTOR]: 'Vicerrector',
  [TENANT_ROLES.SECRETARY]: 'Secretaría',
  [TENANT_ROLES.TEACHER]: 'Docente',
  [TENANT_ROLES.INSPECTOR]: 'Inspector',
  [TENANT_ROLES.COUNSELOR]: 'Consejería estudiantil',
  [TENANT_ROLES.STUDENT]: 'Estudiante',
  [TENANT_ROLES.PARENT]: 'Representante',
})

const normalizeMembership = (membership) => ({
  schoolId: membership?.school_id || membership?.schoolId || null,
  role: membership?.role || null,
  permissions: [...new Set(Array.isArray(membership?.permissions) ? membership.permissions : [])],
})

/** Convierte la respuesta del RPC en una estructura predecible y deniega por defecto. */
export const createAuthorizationContext = (rawContext) => {
  const raw = rawContext && typeof rawContext === 'object' ? rawContext : {}
  const memberships = (Array.isArray(raw.memberships) ? raw.memberships : [])
    .map(normalizeMembership)
    .filter((membership) => membership.schoolId && membership.role)
  const platformRoles = [...new Set(Array.isArray(raw.platform_roles) ? raw.platform_roles : [])]
  const isPlatformOwner = raw.is_platform_owner === true || platformRoles.includes(PLATFORM_ROLES.OWNER)
  const isPlatformAdmin = raw.is_platform_admin === true
    || isPlatformOwner
    || platformRoles.includes(PLATFORM_ROLES.ADMIN)

  const requestedSchoolId = raw.active_school_id || raw.default_school_id || null
  const requestedMembership = memberships.find(({ schoolId }) => schoolId === requestedSchoolId) || null
  const activeMembership = requestedMembership || memberships[0] || null
  const activeSchoolId = isPlatformAdmin
    ? (requestedSchoolId || activeMembership?.schoolId || raw.school_id || null)
    : (activeMembership?.schoolId || (memberships.length === 0 ? (raw.school_id || requestedSchoolId || null) : null))

  return Object.freeze({
    raw,
    userId: raw.user_id || null,
    platformRoles: Object.freeze(platformRoles),
    memberships: Object.freeze(memberships),
    isPlatformAdmin,
    isPlatformOwner,
    activeSchoolId,
    activeMembership,
  })
}

export const hasAccessPermission = (accessContext, permissionCode) => {
  if (!accessContext || !permissionCode) return false
  if (accessContext.isPlatformAdmin) return true
  return accessContext.activeMembership?.permissions?.includes(permissionCode) === true
}

export const isInstitutionAdmin = (accessContext) => {
  if (!accessContext) return false
  const activeRole = accessContext.activeMembership?.role || accessContext.raw?.role
  return accessContext.isPlatformAdmin
    || INSTITUTION_ADMIN_ROLES.has(activeRole)
    || ['admin', 'school_admin', 'rector', 'superadmin'].includes(activeRole)
}

/**
 * Determina si el usuario tiene privilegios para bloquear o desbloquear el año lectivo.
 * Permitido exclusivamente para Super Administrador, Administrador Institucional o Rector.
 */
export const canManageAcademicYearLock = (accessContext, profile = null) => {
  if (!accessContext && !profile) return false
  if (accessContext?.isPlatformAdmin || accessContext?.isPlatformOwner) return true
  const role = accessContext?.activeMembership?.role || accessContext?.raw?.role || profile?.role
  if (['superadmin', 'admin', 'school_admin', 'rector'].includes(role)) return true
  if (isInstitutionAdmin(accessContext)) return true
  return false
}

export const canAccessRoute = (meta = {}, accessContext) => {
  if (meta.platformAdminOnly) return accessContext?.isPlatformAdmin === true
  if (meta.institutionAdminOnly && !isInstitutionAdmin(accessContext)) return false
  if (meta.permission && !hasAccessPermission(accessContext, meta.permission)) return false
  if (meta.requiresAuth && !accessContext?.userId) return false
  return true
}

export const roleLabel = (accessContext) => {
  const role = accessContext?.isPlatformOwner
    ? PLATFORM_ROLES.OWNER
    : accessContext?.platformRoles?.[0] || accessContext?.activeMembership?.role
  return ROLE_LABELS[role] || 'Acceso institucional'
}

/** Compatibilidad temporal para módulos que consultan un rol aislado. */
export const hasPermission = (role, resource, action) => {
  if (!role || !resource || !action) return false
  if (role === ROLES.SUPERADMIN) return true

  const legacyCodes = {
    admin: new Set([
      'students.view', 'students.create', 'students.update', 'students.delete', 'students.export',
      'courses.view', 'courses.create', 'courses.update', 'courses.delete', 'courses.export',
      'subjects.view', 'subjects.create', 'subjects.update', 'subjects.delete',
      'grades.view', 'grades.create', 'grades.update', 'grades.delete', 'grades.export',
      'institution.view', 'institution.update', 'reports.view', 'reports.export', 'audit.view',
    ]),
    teacher: new Set([
      'students.view', 'students.export', 'courses.view', 'courses.export', 'subjects.view',
      'grades.view', 'grades.create', 'grades.update', 'grades.export',
      'institution.view', 'reports.view', 'reports.export',
    ]),
  }

  return legacyCodes[role]?.has(`${resource}.${action}`) === true
}

export const usePermissions = (authStore) => ({
  get userRole() {
    return authStore.accessContext?.activeMembership?.role || null
  },
  get isAdmin() {
    return isInstitutionAdmin(authStore.accessContext)
  },
  get isPlatformAdmin() {
    return authStore.accessContext?.isPlatformAdmin === true
  },
  get canManageAcademicYearLock() {
    return canManageAcademicYearLock(authStore.accessContext, authStore.profile)
  },
  can: (resource, action) => hasAccessPermission(
    authStore.accessContext,
    `${resource}.${action === 'view' ? 'read' : action}`,
  ),
})

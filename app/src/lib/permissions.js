/**
 * Control de acceso por roles
 * Permite verificar permisos de manera centralizada
 */

/**
 * Roles disponibles
 */
export const ROLES = {
    ADMIN: 'admin',
    TEACHER: 'teacher'
}

/**
 * Permisos por recurso y acción
 */
export const PERMISSIONS = {
    // Estudiantes
    students: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        create: [ROLES.ADMIN, ROLES.TEACHER],
        update: [ROLES.ADMIN, ROLES.TEACHER],
        delete: [ROLES.ADMIN],
        export: [ROLES.ADMIN, ROLES.TEACHER]
    },
    
    // Cursos
    courses: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        create: [ROLES.ADMIN],
        update: [ROLES.ADMIN],
        delete: [ROLES.ADMIN],
        export: [ROLES.ADMIN, ROLES.TEACHER]
    },
    
    // Asignaturas
    subjects: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        create: [ROLES.ADMIN],
        update: [ROLES.ADMIN],
        delete: [ROLES.ADMIN]
    },
    
    // Calificaciones
    grades: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        create: [ROLES.ADMIN, ROLES.TEACHER],
        update: [ROLES.ADMIN, ROLES.TEACHER],
        delete: [ROLES.ADMIN],
        export: [ROLES.ADMIN, ROLES.TEACHER]
    },
    
    // Configuración de institución
    institution: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        update: [ROLES.ADMIN]
    },
    
    // Reportes
    reports: {
        view: [ROLES.ADMIN, ROLES.TEACHER],
        export: [ROLES.ADMIN, ROLES.TEACHER]
    },
    
    // Auditoría (solo admin)
    audit: {
        view: [ROLES.ADMIN]
    }
}

/**
 * Verifica si un rol tiene permiso para una acción
 * @param {string} role - Rol del usuario
 * @param {string} resource - Recurso a verificar
 * @param {string} action - Acción a realizar
 * @returns {boolean}
 */
export const hasPermission = (role, resource, action) => {
    if (!role || !resource || !action) return false
    
    const resourcePermissions = PERMISSIONS[resource]
    if (!resourcePermissions) return false
    
    const allowedRoles = resourcePermissions[action]
    if (!allowedRoles) return false
    
    return allowedRoles.includes(role)
}

/**
 * Hook de Vue para verificar permisos
 * @param {Object} authStore - Store de autenticación
 * @returns {Object} - Funciones de verificación
 */
export const usePermissions = (authStore) => {
    const userRole = authStore.profile?.role || ROLES.TEACHER
    
    const can = (resource, action) => hasPermission(userRole, resource, action)
    
    const canView = (resource) => can(resource, 'view')
    const canCreate = (resource) => can(resource, 'create')
    const canUpdate = (resource) => can(resource, 'update')
    const canDelete = (resource) => can(resource, 'delete')
    const canExport = (resource) => can(resource, 'export')
    
    const isAdmin = userRole === ROLES.ADMIN
    
    return {
        userRole,
        isAdmin,
        can,
        canView,
        canCreate,
        canUpdate,
        canDelete,
        canExport
    }
}

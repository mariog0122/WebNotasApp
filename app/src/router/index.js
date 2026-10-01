import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useUIStore } from '../stores/ui'
import Login from '../views/Login.vue'
import { canAccessRoute } from '../lib/permissions'
import { isAal2Required } from '../lib/mfa'
import { intelligenceRoutes } from '../modules/intelligence/router/routes'

const isIntelligenceModuleEnabled = async (schoolId) => {
    const { intelligenceFeatureService } = await import('../modules/intelligence/services/intelligenceFeatureService')
    return intelligenceFeatureService.checkModuleEnabled({ schoolId })
}

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
        {
            path: '/login',
            name: 'login',
            component: Login
        },
        {
            path: '/reset-password',
            name: 'reset-password',
            component: Login
        },
        {
            path: '/change-password',
            name: 'change-password',
            component: Login
        },
        {
            path: '/auth/callback',
            name: 'auth-callback',
            component: Login
        },
        {
            path: '/',
            name: 'dashboard',
            component: () => import('../views/Dashboard.vue'),
            meta: { title: 'Panel Principal', requiresAuth: true }
        },
        {
            path: '/courses',
            name: 'courses',
            component: () => import('../views/Courses.vue'),
            meta: { title: 'Cursos', requiresAuth: true, institutionAdminOnly: true }
        },
        {
            path: '/subjects',
            name: 'subjects',
            component: () => import('../views/Subjects.vue'),
            meta: { title: 'Asignaturas', requiresAuth: true, institutionAdminOnly: true }
        },
        {
            path: '/students',
            name: 'students',
            component: () => import('../views/Students.vue'),
            meta: { title: 'Estudiantes', requiresAuth: true, permission: 'students.read' }
        },
        {
            path: '/grades',
            name: 'grades',
            component: () => import('../views/Grades.vue'),
            meta: { title: 'Calificaciones', requiresAuth: true, permission: 'grades.read' }
        },
        {
            path: '/reports',
            name: 'reports',
            component: () => import('../views/Reports.vue'),
            meta: { requiresAuth: true, permission: 'reports.read', title: 'Reportes Académicos' }
        },
        {
            path: '/teacher-reports',
            name: 'teacher-reports',
            component: () => import('../views/TeacherReports.vue'),
            meta: { title: 'Informes Docentes', requiresAuth: true, permission: 'reports.read' }
        },
        {
            path: '/planificacion-ia',
            name: 'planificacion-ia',
            component: () => import('../views/AIPlanning.vue'),
            meta: { title: 'Planificación con IA', requiresAuth: true, permission: 'grades.read' }
        },
        ...intelligenceRoutes,
        {
            path: '/families',
            name: 'families',
            component: () => import('../views/Families.vue'),
            meta: { title: 'Familias', requiresAuth: true, permission: 'students.read' }
        },
        {
            path: '/attendance',
            name: 'attendance',
            component: () => import('../views/Attendance.vue'),
            meta: { title: 'Asistencia', requiresAuth: true, permission: 'attendance.read' }
        },
        {
            path: '/alerts',
            name: 'alerts',
            component: () => import('../views/Alerts.vue'),
            meta: { title: 'Bienestar Estudiantil', requiresAuth: true, permission: 'wellbeing.read' }
        },
        {
            path: '/profile',
            name: 'profile',
            component: () => import('../views/Profile.vue'),
            meta: { title: 'Mi Perfil', requiresAuth: true }
        },
        {
            path: '/superadmin',
            name: 'superadmin',
            component: () => import('../views/SuperAdmin.vue'),
            meta: { title: 'Administración de Plataforma', requiresAuth: true, platformAdminOnly: true }
        },
        {
            path: '/acceso-denegado',
            name: 'forbidden',
            component: () => import('../views/Forbidden.vue'),
            meta: { title: 'Acceso Denegado', requiresAuth: true }
        },
        {
            path: '/planes',
            name: 'planes',
            component: () => import('../views/Pricing.vue'),
            meta: { requiresAuth: false }
        },
        {
            path: '/precios',
            redirect: '/planes'
        },
        {
            path: '/terminos',
            name: 'terminos',
            component: () => import('../views/Terms.vue'),
            meta: { requiresAuth: false }
        },
        {
            path: '/privacidad',
            name: 'privacidad',
            component: () => import('../views/Privacy.vue'),
            meta: { requiresAuth: false }
        },
    ]
})

router.beforeEach(async (to, from, next) => {
    const authStore = useAuthStore()
    const uiStore = useUIStore()

    // Mostrar loading de autenticación solo si la ruta requiere autenticación
    if (to.meta.requiresAuth) {
        uiStore.setAuthLoading(true)
    }

    try {
        await authStore.ensureSession()

        const mfaPending = await isAal2Required()

        if (to.meta.requiresAuth && (!authStore.user || !authStore.profile || mfaPending)) {
            next({ name: 'login', query: { reason: mfaPending ? 'mfa_required' : 'access' } })
        } else if (to.meta.requiresAuth && !canAccessRoute(to.meta, authStore.accessContext)) {
            next({ name: 'forbidden', query: { from: to.fullPath } })
        } else if (to.meta.intelligenceFeature && !await isIntelligenceModuleEnabled(authStore.activeSchoolId)) {
            next({ name: 'forbidden', query: { from: to.fullPath, reason: 'module_disabled' } })
        } else if (to.name === 'login' && authStore.user && !mfaPending) {
            next({ name: 'dashboard' })
        } else {
            next()
        }
    } catch (error) {
        console.error('Error en guard de autenticación:', error)
        if (to.meta.requiresAuth) {
            next({ name: 'login' })
        } else {
            next()
        }
    } finally {
        uiStore.setAuthLoading(false)
    }
})

export default router

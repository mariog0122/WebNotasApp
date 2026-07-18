import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useUIStore } from '../stores/ui'
import Login from '../views/Login.vue'
import Dashboard from '../views/Dashboard.vue'

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
        {
            path: '/login',
            name: 'login',
            component: Login
        },
        {
            path: '/',
            name: 'dashboard',
            component: Dashboard,
            meta: { requiresAuth: true }
        },
        {
            path: '/courses',
            name: 'courses',
            component: () => import('../views/Courses.vue'),
            meta: { requiresAuth: true }
        },
        {
            path: '/subjects',
            name: 'subjects',
            component: () => import('../views/Subjects.vue'),
            meta: { requiresAuth: true }
        },
        {
            path: '/students',
            name: 'students',
            component: () => import('../views/Students.vue'),
            meta: { requiresAuth: true }
        },
        {
            path: '/grades',
            name: 'grades',
            component: () => import('../views/Grades.vue'),
            meta: { requiresAuth: true }
        },
        {
            path: '/reports',
            name: 'reports',
            component: () => import('../views/Reports.vue'),
            meta: { requiresAuth: true, requiresAdmin: true }
        },
        {
            path: '/families',
            name: 'families',
            component: () => import('../views/Families.vue'),
            meta: { requiresAuth: true }
        },
        {
            path: '/profile',
            name: 'profile',
            component: () => import('../views/Profile.vue'),
            meta: { requiresAuth: true }
        },
    ]
})

router.beforeEach(async (to, from, next) => {
    const authStore = useAuthStore()
    const uiStore = useUIStore()

    // Mostrar loading de autenticación (evitar en login para mayor fluidez)
    if (to.name !== 'login') {
        uiStore.setAuthLoading(true)
    }

    try {
        // Revalidar sesión en cada navegación (Supabase). No usar initialize() con timeout:
        // podía anular al usuario tras login o con red lenta y impedir entrar al CRM.
        await authStore.ensureSession()

        if (to.meta.requiresAuth && !authStore.user) {
            next({ name: 'login' })
        } else if (to.meta.requiresAdmin && authStore.profile?.role !== 'admin') {
            next({ name: 'dashboard' })
        } else if (to.name === 'login' && authStore.user) {
            next({ name: 'dashboard' })
        } else {
            next()
        }
    } catch (error) {
        console.error('Error en guard de autenticación:', error)
        if (to.name !== 'login') {
            next({ name: 'login' })
        } else {
            next()
        }
    } finally {
        uiStore.setAuthLoading(false)
    }
})

export default router

<script setup>
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useUIStore } from '../stores/ui'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  LogOut,
  User,
  ChevronLeft,
  ChevronRight,
  Moon,
  Sun
} from 'lucide-vue-next'
import { useTheme } from '../composables/useTheme'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { hasAccessPermission, isInstitutionAdmin, roleLabel } from '../lib/permissions'
import BrandLogo from './ui/BrandLogo.vue'

const authStore = useAuthStore()
const uiStore = useUIStore()
const router = useRouter()
const route = useRoute()
const { theme, toggleTheme } = useTheme()

const institutionName = ref('')
const institutionLogoUrl = ref('')
const isCollapsed = computed({
  get: () => uiStore.isSidebarCollapsed,
  set: (val) => { uiStore.isSidebarCollapsed = val }
})

// Cerrar automáticamente el menú móvil al navegar
watch(() => route.path, () => {
  uiStore.isMobileMenuOpen = false
})

const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))
const isPlatformAdmin = computed(() => authStore.accessContext?.isPlatformAdmin === true)
const can = (permission) => hasAccessPermission(authStore.accessContext, permission)
const isActive = (path) => route.path === path

const navLinks = computed(() => [
  { name: 'Inicio', subtitle: 'Dashboard', path: '/', color: '#F59E0B', iconType: 'home' },
  ...(isAdmin.value ? [
    { name: 'Cursos', subtitle: 'Gestionar aulas y niveles', path: '/courses', color: '#6366F1', iconType: 'courses' },
    { name: 'Asignaturas', subtitle: 'Materias y contenidos', path: '/subjects', color: '#8B5CF6', iconType: 'subjects' },
  ] : []),
  ...(can('students.read') ? [
    { name: 'Estudiantes', subtitle: 'Registro estudiantil', path: '/students', color: '#06B6D4', iconType: 'students' },
    { name: 'Familias', subtitle: 'Representantes legales', path: '/families', color: '#EC4899', iconType: 'families' },
  ] : []),
  ...(can('attendance.read') || can('attendance.manage') || can('grades.read') || isAdmin.value ? [
    { name: 'Asistencia', subtitle: 'Control de asistencia', path: '/attendance', color: '#10B981', iconType: 'attendance' }
  ] : []),
  ...(can('grades.read') ? [{ name: 'Calificaciones', subtitle: 'Notas y evaluaciones', path: '/grades', color: '#F97316', iconType: 'grades' }] : []),
  ...(can('reports.read') ? [
    { name: 'Reportes', subtitle: 'Informes y estadísticas', path: '/reports', color: '#3B82F6', iconType: 'reports' }
  ] : []),
  ...(can('grades.read') || can('reports.read') || isAdmin.value ? [
    { name: 'Informes Docentes', subtitle: 'Documentos del profesor', path: '/teacher-reports', color: '#14B8A6', iconType: 'teacher-reports' },
    { name: 'Planificación IA', subtitle: 'Asistente inteligente', path: '/planificacion-ia', color: '#A855F7', iconType: 'ai-planning' }
  ] : []),
  ...(can('attendance.read') ? [{ name: 'Alertas DECE', subtitle: 'Bienestar estudiantil', path: '/alerts', color: '#EF4444', iconType: 'alerts' }] : []),
  { name: 'Mi Perfil', subtitle: 'Cuenta y preferencias', path: '/profile', color: '#64748B', iconType: 'profile' },
  ...(isPlatformAdmin.value ? [{ name: 'Súper Admin', subtitle: 'Administración global', path: '/superadmin', color: '#DC2626', iconType: 'superadmin' }] : [])
])

const handleLogout = async () => {
  await authStore.signOut()
  router.push('/login')
}

const fetchInstitutionConfig = async () => {
  institutionName.value = ''
  institutionLogoUrl.value = ''
  const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!schoolId) return
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .eq('school_id', schoolId)
    .in('key', ['institution_name', 'institution_logo_url'])
  if (error) return
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || 'Logreva'
  institutionLogoUrl.value = await resolvePrivateImageUrl(
    supabase,
    'institution-assets',
    normalizeStoragePath(map.institution_logo_url, 'institution-assets'),
  ).catch(() => '')
}

const onLogoError = async () => {
  if (institutionLogoUrl.value) {
    const path = normalizeStoragePath(institutionLogoUrl.value, 'institution-assets')
    if (path && !path.startsWith('http')) {
      const signedUrl = await resolvePrivateImageUrl(supabase, 'institution-assets', path).catch(() => '')
      if (signedUrl && signedUrl !== institutionLogoUrl.value) {
        institutionLogoUrl.value = signedUrl
        return
      }
    }
  }
  institutionLogoUrl.value = ''
}

onMounted(() => {
  fetchInstitutionConfig()
  window.addEventListener('institution-config-updated', fetchInstitutionConfig)
})

onUnmounted(() => {
  window.removeEventListener('institution-config-updated', fetchInstitutionConfig)
})

watch(() => authStore.activeSchoolId, () => {
  fetchInstitutionConfig()
})

const toggleSidebar = () => {
  uiStore.isSidebarCollapsed = !uiStore.isSidebarCollapsed
}
</script>

<template>
  <!-- Mobile Backdrop Overlay -->
  <div 
    v-if="uiStore.isMobileMenuOpen" 
    @click="uiStore.isMobileMenuOpen = false"
    aria-hidden="true"
    class="fixed inset-0 z-40 bg-slate-950/70 backdrop-blur-sm lg:hidden transition-opacity"
  ></div>

  <!-- Sidebar Container -->
  <aside 
    id="main-sidebar"
    aria-label="Navegación principal"
    :class="[
      'sidebar-container fixed inset-y-0 left-0 z-50 transition-all duration-300 ease-in-out flex flex-col',
      isCollapsed ? 'w-20' : 'w-[85vw] max-w-[320px] lg:w-72',
      uiStore.isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]"
  >
    <!-- Logo & Institution Name -->
    <div class="sidebar-header">
      <div class="sidebar-logo-wrapper">
        <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="sidebar-logo-img" @error="onLogoError" />
        <BrandLogo v-else variant="mark" tone="light" decorative class="sidebar-logo-fallback" />
      </div>
      <div v-if="!isCollapsed" class="sidebar-brand-text">
        <h1 class="sidebar-institution-name">{{ institutionName }}</h1>
        <p class="sidebar-brand-tagline">LOGREVA · Gestión Académica</p>
      </div>
    </div>

    <!-- Section Label -->
    <div v-if="!isCollapsed" class="sidebar-section-label">
      <span>MÓDULOS</span>
      <svg width="10" height="6" viewBox="0 0 10 6" fill="none" class="sidebar-section-chevron">
        <path d="M1 5L5 1L9 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>

    <!-- Navigation Links -->
    <nav class="sidebar-nav custom-scrollbar">
      <router-link 
        v-for="link in navLinks" 
        :key="link.path"
        :to="link.path"
        @click="uiStore.isMobileMenuOpen = false"
        :class="['sidebar-nav-item', { 'sidebar-nav-item--active': isActive(link.path) }]"
        :style="isActive(link.path) ? { '--item-active-color': link.color } : {}"
      >
        <!-- Colored Icon Container -->
        <div 
          class="sidebar-icon-box"
          :style="{ 
            backgroundColor: isActive(link.path) ? link.color : (link.color + '18'),
            color: isActive(link.path) ? '#fff' : link.color
          }"
        >
          <!-- Home / Dashboard -->
          <svg v-if="link.iconType === 'home'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          <!-- Courses -->
          <svg v-else-if="link.iconType === 'courses'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/>
            <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
          </svg>
          <!-- Subjects -->
          <svg v-else-if="link.iconType === 'subjects'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
            <line x1="9" y1="7" x2="17" y2="7"/>
            <line x1="9" y1="11" x2="14" y2="11"/>
          </svg>
          <!-- Students -->
          <svg v-else-if="link.iconType === 'students'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M22 10v6M2 10l10-5 10 5-10 5z"/>
            <path d="M6 12v5c0 2 3 3 6 3s6-1 6-3v-5"/>
          </svg>
          <!-- Families -->
          <svg v-else-if="link.iconType === 'families'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <circle cx="9" cy="7" r="3"/>
            <path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"/>
            <circle cx="17" cy="10" r="2.5"/>
            <path d="M21 21v-1.5a3 3 0 0 0-3-3h-.5"/>
          </svg>
          <!-- Attendance -->
          <svg v-else-if="link.iconType === 'attendance'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
            <path d="M9 16l2 2 4-4"/>
          </svg>
          <!-- Grades -->
          <svg v-else-if="link.iconType === 'grades'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="8" y1="13" x2="16" y2="13"/>
            <line x1="8" y1="17" x2="13" y2="17"/>
            <path d="M10 9l1.5 1.5L15 7" stroke-width="1.8"/>
          </svg>
          <!-- Reports -->
          <svg v-else-if="link.iconType === 'reports'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <rect x="3" y="3" width="18" height="18" rx="2"/>
            <rect x="7" y="14" width="3" height="5" rx="0.5"/>
            <rect x="13" y="10" width="3" height="9" rx="0.5"/>
            <line x1="7" y1="8" x2="10" y2="8"/>
            <line x1="13" y1="6" x2="16" y2="6"/>
          </svg>
          <!-- Teacher Reports -->
          <svg v-else-if="link.iconType === 'teacher-reports'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="8" y1="13" x2="16" y2="13"/>
            <line x1="8" y1="17" x2="16" y2="17"/>
            <circle cx="12" cy="9.5" r="1.5" stroke-width="1.5"/>
          </svg>
          <!-- AI Planning -->
          <svg v-else-if="link.iconType === 'ai-planning'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 16.8l-6.2 4.5 2.4-7.4L2 9.4h7.6z"/>
          </svg>
          <!-- Alerts / DECE -->
          <svg v-else-if="link.iconType === 'alerts'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <path d="M12 2L2 22h20L12 2z"/>
            <line x1="12" y1="9" x2="12" y2="14"/>
            <circle cx="12" cy="17.5" r="0.8" fill="currentColor" stroke="none"/>
          </svg>
          <!-- Profile -->
          <svg v-else-if="link.iconType === 'profile'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <circle cx="12" cy="8" r="4"/>
            <path d="M6 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"/>
          </svg>
          <!-- Super Admin -->
          <svg v-else-if="link.iconType === 'superadmin'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sidebar-icon-svg">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
          </svg>
        </div>

        <!-- Text: Name + Subtitle -->
        <div v-if="!isCollapsed" class="sidebar-nav-text">
          <span class="sidebar-nav-name">{{ link.name }}</span>
          <span class="sidebar-nav-subtitle">{{ link.subtitle }}</span>
        </div>
        
        <!-- Tooltip for collapsed state -->
        <div v-if="isCollapsed" class="sidebar-tooltip">
          <span class="sidebar-tooltip-name">{{ link.name }}</span>
          <span class="sidebar-tooltip-sub">{{ link.subtitle }}</span>
        </div>
      </router-link>
    </nav>

    <!-- Footer / Profile -->
    <div class="sidebar-footer">
      <!-- Profile Action -->
      <router-link 
        to="/profile"
        @click="uiStore.isMobileMenuOpen = false"
        class="sidebar-profile-link"
      >
        <div class="sidebar-avatar">
           <img
            v-if="authStore.profile?.photo_url"
            :src="authStore.profile.photo_url"
            alt="Profile"
            class="sidebar-avatar-img"
          />
          <User v-else class="sidebar-avatar-fallback" />
        </div>
        <div v-if="!isCollapsed" class="sidebar-profile-info">
          <p class="sidebar-profile-name">{{ authStore.profile?.full_name || 'Mi Perfil' }}</p>
          <p class="sidebar-profile-role">{{ roleLabel(authStore.accessContext) }}</p>
        </div>
      </router-link>

      <!-- Logout & Collapse Actions -->
      <div class="sidebar-actions">
        <button 
           @click="handleLogout"
           class="sidebar-action-btn sidebar-action-btn--logout"
           title="Cerrar Sesión"
           aria-label="Cerrar sesión"
        >
          <LogOut class="w-5 h-5" />
          <span v-if="!isCollapsed" class="sidebar-action-label">Salir</span>
        </button>

        <button 
          @click="toggleTheme"
          class="sidebar-action-btn sidebar-action-btn--theme"
           :title="theme === 'dark' ? 'Modo Claro' : 'Modo Oscuro'"
           :aria-label="theme === 'dark' ? 'Activar modo claro' : 'Activar modo oscuro'"
        >
          <Sun v-if="theme === 'dark'" class="w-5 h-5" style="color: #FBBF24;" />
          <Moon v-else class="w-5 h-5" style="color: #6366F1;" />
        </button>

        <button 
           @click="toggleSidebar"
           :aria-label="isCollapsed ? 'Expandir menú lateral' : 'Contraer menú lateral'"
           class="sidebar-action-btn sidebar-action-btn--collapse"
        >
          <ChevronLeft v-if="!isCollapsed" class="w-5 h-5" />
          <ChevronRight v-else class="w-5 h-5" />
        </button>
      </div>
    </div>
  </aside>
</template>

<style scoped>
/* ============================================= */
/* SIDEBAR CONTAINER                             */
/* ============================================= */
.sidebar-container {
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
  border-right: 1px solid rgba(51, 65, 85, 0.5);
  box-shadow: 4px 0 24px rgba(0, 0, 0, 0.3);
  color: #94a3b8;
}

/* ============================================= */
/* HEADER                                        */
/* ============================================= */
.sidebar-header {
  padding: 1.25rem 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  border-bottom: 1px solid rgba(51, 65, 85, 0.4);
}

.sidebar-logo-wrapper {
  flex-shrink: 0;
  height: 2.75rem;
  width: 2.75rem;
  border-radius: 0.75rem;
  background: linear-gradient(135deg, #6366F1, #8B5CF6);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
}

.sidebar-logo-img {
  height: 100%;
  width: 100%;
  object-fit: contain;
  padding: 0.2rem;
}

.sidebar-logo-fallback {
  height: 1.75rem;
  width: 1.75rem;
}

.sidebar-brand-text {
  flex: 1;
  min-width: 0;
}

.sidebar-institution-name {
  font-weight: 700;
  color: #f1f5f9;
  font-size: 0.875rem;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.sidebar-brand-tagline {
  font-size: 0.6rem;
  color: #818cf8;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  margin-top: 0.2rem;
}

/* ============================================= */
/* SECTION LABEL                                 */
/* ============================================= */
.sidebar-section-label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.25rem 0.25rem;
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.15em;
  color: #475569;
}

.sidebar-section-chevron {
  color: #475569;
}

/* ============================================= */
/* NAVIGATION                                    */
/* ============================================= */
.sidebar-nav {
  flex: 1;
  padding: 0.5rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  overflow-y: auto;
}

.sidebar-nav-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 0.75rem;
  border-radius: 0.75rem;
  transition: all 0.2s ease;
  text-decoration: none;
  position: relative;
  cursor: pointer;
}

.sidebar-nav-item:hover {
  background: rgba(51, 65, 85, 0.5);
}

.sidebar-nav-item--active {
  background: rgba(99, 102, 241, 0.12) !important;
  box-shadow: inset 3px 0 0 var(--item-active-color, #6366F1);
}

/* ============================================= */
/* ICON BOX                                      */
/* ============================================= */
.sidebar-icon-box {
  flex-shrink: 0;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 0.625rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.25s ease;
}

.sidebar-nav-item:hover .sidebar-icon-box {
  transform: scale(1.08);
}

.sidebar-icon-svg {
  width: 1.15rem;
  height: 1.15rem;
}

/* ============================================= */
/* NAV TEXT                                       */
/* ============================================= */
.sidebar-nav-text {
  display: flex;
  flex-direction: column;
  min-width: 0;
  flex: 1;
}

.sidebar-nav-name {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #e2e8f0;
  line-height: 1.3;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sidebar-nav-item--active .sidebar-nav-name {
  color: #fff;
  font-weight: 700;
}

.sidebar-nav-subtitle {
  font-size: 0.65rem;
  color: #64748b;
  line-height: 1.3;
  margin-top: 0.05rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sidebar-nav-item--active .sidebar-nav-subtitle {
  color: #94a3b8;
}

/* ============================================= */
/* TOOLTIP (collapsed)                           */
/* ============================================= */
.sidebar-tooltip {
  position: absolute;
  left: 100%;
  margin-left: 0.75rem;
  padding: 0.5rem 0.75rem;
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 0.5rem;
  opacity: 0;
  visibility: hidden;
  transition: all 0.15s ease;
  white-space: nowrap;
  z-index: 100;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.sidebar-nav-item:hover .sidebar-tooltip {
  opacity: 1;
  visibility: visible;
}

.sidebar-tooltip-name {
  font-size: 0.75rem;
  font-weight: 600;
  color: #f1f5f9;
}

.sidebar-tooltip-sub {
  font-size: 0.6rem;
  color: #64748b;
}

/* ============================================= */
/* FOOTER                                        */
/* ============================================= */
.sidebar-footer {
  padding: 0.75rem;
  border-top: 1px solid rgba(51, 65, 85, 0.4);
  background: rgba(15, 23, 42, 0.6);
}

.sidebar-profile-link {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem;
  border-radius: 0.75rem;
  transition: background 0.2s ease;
  text-decoration: none;
}

.sidebar-profile-link:hover {
  background: rgba(51, 65, 85, 0.5);
}

.sidebar-avatar {
  height: 2.5rem;
  width: 2.5rem;
  border-radius: 50%;
  border: 2px solid #334155;
  overflow: hidden;
  flex-shrink: 0;
  background: #1e293b;
  transition: border-color 0.2s ease;
}

.sidebar-profile-link:hover .sidebar-avatar {
  border-color: #6366F1;
}

.sidebar-avatar-img {
  height: 100%;
  width: 100%;
  object-fit: cover;
}

.sidebar-avatar-fallback {
  width: 100%;
  height: 100%;
  padding: 0.4rem;
  color: #64748b;
}

.sidebar-profile-info {
  flex: 1;
  min-width: 0;
}

.sidebar-profile-name {
  font-size: 0.75rem;
  font-weight: 600;
  color: #f1f5f9;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sidebar-profile-role {
  font-size: 0.6rem;
  color: #64748b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ============================================= */
/* ACTION BUTTONS                                */
/* ============================================= */
.sidebar-actions {
  margin-top: 0.75rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sidebar-action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.5rem;
  border-radius: 0.5rem;
  transition: all 0.2s ease;
  border: none;
  background: transparent;
  cursor: pointer;
  color: #64748b;
}

.sidebar-action-btn:hover {
  background: rgba(51, 65, 85, 0.5);
}

.sidebar-action-btn--logout:hover {
  color: #f43f5e;
  background: rgba(244, 63, 94, 0.1);
}

.sidebar-action-btn--theme:hover {
  background: rgba(99, 102, 241, 0.1);
}

.sidebar-action-btn--collapse {
  display: none;
}

@media (min-width: 1024px) {
  .sidebar-action-btn--collapse {
    display: flex;
  }
}

.sidebar-action-label {
  margin-left: 0.5rem;
  font-size: 0.75rem;
  font-weight: 500;
}

/* ============================================= */
/* SCROLLBAR                                     */
/* ============================================= */
.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}

.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #334155;
  border-radius: 10px;
}

.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #475569;
}
</style>

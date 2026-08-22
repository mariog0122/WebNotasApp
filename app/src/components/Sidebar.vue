<script setup>
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useUIStore } from '../stores/ui'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  LayoutDashboard, 
  BookOpen, 
  GraduationCap, 
  Users, 
  ScrollText, 
  UsersRound, 
  FileBarChart,
  FileText,
  CalendarCheck,
  LogOut,
  User,
  ChevronLeft,
  ChevronRight,
  Menu,
  School,
  Moon,
  Sun,
  ShieldAlert,
  Settings
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
  { name: 'Panel Principal', path: '/', icon: LayoutDashboard },
  ...(isAdmin.value ? [
    { name: 'Cursos', path: '/courses', icon: School },
    { name: 'Asignaturas', path: '/subjects', icon: BookOpen },
  ] : []),
  ...(can('students.read') ? [
    { name: 'Estudiantes', path: '/students', icon: GraduationCap },
    { name: 'Familias', path: '/families', icon: UsersRound },
  ] : []),
  ...(can('attendance.read') || can('attendance.manage') || can('grades.read') || isAdmin.value ? [
    { name: 'Asistencia', path: '/attendance', icon: CalendarCheck }
  ] : []),
  ...(can('grades.read') ? [{ name: 'Calificaciones', path: '/grades', icon: ScrollText }] : []),
  ...(can('reports.read') ? [
    { name: 'Reportes', path: '/reports', icon: FileBarChart }
  ] : []),
  ...(can('grades.read') || can('reports.read') || isAdmin.value ? [
    { name: 'Informes Docentes', path: '/teacher-reports', icon: FileText }
  ] : []),
  ...(can('attendance.read') ? [{ name: 'Alertas DECE', path: '/alerts', icon: ShieldAlert }] : []),
  { name: 'Mi Perfil', path: '/profile', icon: User },
  ...(isPlatformAdmin.value ? [{ name: 'Súper Admin', path: '/superadmin', icon: Settings }] : [])
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
      'fixed inset-y-0 left-0 z-50 bg-white/95 dark:bg-slate-900/95 backdrop-blur-xl text-slate-800 dark:text-slate-300 transition-all duration-300 ease-in-out border-r border-slate-200 dark:border-slate-800/50 shadow-2xl flex flex-col',
      isCollapsed ? 'w-20' : 'w-[85vw] max-w-[320px] lg:w-64',
      uiStore.isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]"
  >
    <!-- Logo & Institution Name -->
    <div class="p-6 flex items-center gap-3 border-b border-slate-200 dark:border-slate-800/50">
      <div class="flex-shrink-0 h-10 w-10 rounded-xl bg-indigo-600 flex items-center justify-center overflow-hidden shadow-indigo-500/20 shadow-lg">
        <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="h-full w-full object-contain p-1" @error="onLogoError" />
        <BrandLogo v-else variant="mark" tone="light" decorative class="h-7 w-7" />
      </div>
      <div v-if="!isCollapsed" class="flex-1 overflow-hidden">
        <h1 class="font-bold text-slate-900 dark:text-white text-sm leading-tight break-words">{{ institutionName }}</h1>
        <p class="text-[10px] text-indigo-600 dark:text-cyan-400/80 font-semibold uppercase tracking-[0.14em] mt-0.5">LOGREVA · Gestión Académica</p>
      </div>
    </div>

    <!-- Navigation Links -->
    <nav class="flex-1 px-3 py-6 space-y-1.5 overflow-y-auto custom-scrollbar">
      <router-link 
        v-for="link in navLinks" 
        :key="link.path"
        :to="link.path"
        @click="uiStore.isMobileMenuOpen = false"
        :class="[
          'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group relative text-sm',
          isActive(link.path) 
            ? 'bg-indigo-600 text-white shadow-indigo-600/20 shadow-lg font-bold' 
            : 'text-slate-700 hover:text-indigo-600 hover:bg-indigo-50 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white font-medium'
        ]"
      >
        <component :is="link.icon" :class="['w-5 h-5 flex-shrink-0', isActive(link.path) ? 'text-white' : 'text-slate-500 group-hover:text-indigo-600 dark:text-slate-400 dark:group-hover:text-indigo-400']" />
        <span v-if="!isCollapsed">{{ link.name }}</span>
        
        <!-- Tooltip for collapsed state -->
        <div v-if="isCollapsed" class="absolute left-full ml-2 px-2 py-1 bg-slate-800 text-white text-xs rounded opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all whitespace-nowrap z-50">
          {{ link.name }}
        </div>
      </router-link>
    </nav>

    <!-- Footer / Profile -->
    <div class="p-4 border-t border-slate-200 dark:border-slate-800/50 bg-slate-50 dark:bg-slate-900/50">
      <!-- Profile Action -->
      <router-link 
        to="/profile"
        @click="uiStore.isMobileMenuOpen = false"
        class="flex items-center gap-3 p-2 rounded-xl hover:bg-slate-200/60 dark:hover:bg-slate-800 transition-colors group relative"
      >
        <div class="h-10 w-10 rounded-full border-2 border-slate-300 dark:border-slate-700 overflow-hidden flex-shrink-0 group-hover:border-indigo-500 transition-colors shadow-inner bg-slate-200 dark:bg-slate-800">
           <img
            v-if="authStore.profile?.photo_url"
            :src="authStore.profile.photo_url"
            alt="Profile"
            class="h-full w-full object-cover"
          />
          <User v-else class="w-full h-full p-2 text-slate-500 dark:text-slate-400" />
        </div>
        <div v-if="!isCollapsed" class="flex-1 min-w-0">
          <p class="text-xs font-semibold text-slate-900 dark:text-white truncate">{{ authStore.profile?.full_name || 'Mi Perfil' }}</p>
          <p class="text-[10px] text-slate-500 dark:text-slate-400 truncate">{{ roleLabel(authStore.accessContext) }}</p>
        </div>
      </router-link>

      <!-- Logout & Collapse Actions -->
      <div class="mt-4 flex items-center justify-between">
        <button 
           @click="handleLogout"
          class="flex items-center justify-center p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-400/10 transition-all group"
           title="Cerrar Sesión"
           aria-label="Cerrar sesión"
        >
          <LogOut class="w-5 h-5" />
          <span v-if="!isCollapsed" class="ml-2 text-xs font-medium">Salir</span>
        </button>

        <button 
          @click="toggleTheme"
          class="flex items-center justify-center p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50 dark:hover:bg-amber-400/10 transition-all group"
           :title="theme === 'dark' ? 'Modo Claro' : 'Modo Oscuro'"
           :aria-label="theme === 'dark' ? 'Activar modo claro' : 'Activar modo oscuro'"
        >
          <Sun v-if="theme === 'dark'" class="w-5 h-5 text-amber-400" />
          <Moon v-else class="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
        </button>

        <button 
           @click="toggleSidebar"
           :aria-label="isCollapsed ? 'Expandir menú lateral' : 'Contraer menú lateral'"
          class="hidden lg:flex items-center justify-center p-2 rounded-lg text-slate-500 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-slate-800 transition-all"
        >
          <ChevronLeft v-if="!isCollapsed" class="w-5 h-5" />
          <ChevronRight v-else class="w-5 h-5" />
        </button>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #1e293b;
  border-radius: 10px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #334155;
}
</style>

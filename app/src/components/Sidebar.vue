<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuthStore } from '../stores/auth'
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
  LogOut,
  User,
  ChevronLeft,
  ChevronRight,
  Menu,
  School,
  Moon,
  Sun
} from 'lucide-vue-next'
import { useTheme } from '../composables/useTheme'

const authStore = useAuthStore()
const router = useRouter()
const route = useRoute()
const { theme, toggleTheme } = useTheme()

const institutionName = ref('')
const institutionLogoUrl = ref('')
const isCollapsed = ref(false)
const isMobileMenuOpen = ref(false)

const isAdmin = computed(() => authStore.profile?.role === 'admin')
const isActive = (path) => route.path === path

const navLinks = computed(() => [
  { name: 'Dashboard', path: '/', icon: LayoutDashboard },
  { name: 'Cursos', path: '/courses', icon: School },
  { name: 'Asignaturas', path: '/subjects', icon: BookOpen },
  { name: 'Estudiantes', path: '/students', icon: GraduationCap },
  { name: 'Calificaciones', path: '/grades', icon: ScrollText },
  { name: 'Familias', path: '/families', icon: UsersRound },
  { name: 'Mi Perfil', path: '/profile', icon: User },
  ...(isAdmin.value ? [{ name: 'Reportes', path: '/reports', icon: FileBarChart }] : [])
])

const handleLogout = async () => {
  await authStore.signOut()
  router.push('/login')
}

const fetchInstitutionConfig = async () => {
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .in('key', ['institution_name', 'institution_logo_url'])
  if (error) return
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || 'Sistema de Notas'
  institutionLogoUrl.value = map.institution_logo_url || ''
}

onMounted(() => {
  fetchInstitutionConfig()
})

const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value
}

const toggleMobileMenu = () => {
  isMobileMenuOpen.value = !isMobileMenuOpen.value
}
</script>

<template>
  <!-- Mobile Menu Button -->
  <button 
    @click="toggleMobileMenu"
    class="lg:hidden fixed top-4 left-4 z-50 p-2 bg-slate-900 text-white rounded-lg shadow-lg"
  >
    <Menu v-if="!isMobileMenuOpen" class="w-6 h-6" />
    <ChevronLeft v-else class="w-6 h-6" />
  </button>

  <!-- Sidebar Container -->
  <aside 
    :class="[
      'fixed inset-y-0 left-0 z-40 bg-slate-900/95 backdrop-blur-xl text-slate-300 transition-all duration-300 ease-in-out border-r border-slate-800/50 shadow-2xl flex flex-col',
      isCollapsed ? 'w-20' : 'w-64',
      isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]"
  >
    <!-- Logo & Institution Name -->
    <div class="p-6 flex items-center gap-3 border-b border-slate-800/50">
      <div class="flex-shrink-0 h-10 w-10 rounded-xl bg-indigo-600 flex items-center justify-center overflow-hidden shadow-indigo-500/20 shadow-lg">
        <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="h-full w-full object-contain p-1" />
        <School v-else class="text-white w-6 h-6" />
      </div>
      <div v-if="!isCollapsed" class="flex-1 overflow-hidden">
        <h1 class="font-bold text-white text-sm leading-tight break-words">{{ institutionName }}</h1>
        <p class="text-[10px] text-slate-500 font-medium uppercase tracking-wider mt-0.5">Gestión Académica</p>
      </div>
    </div>

    <!-- Navigation Links -->
    <nav class="flex-1 px-3 py-6 space-y-1.5 overflow-y-auto custom-scrollbar">
      <router-link 
        v-for="link in navLinks" 
        :key="link.path"
        :to="link.path"
        @click="isMobileMenuOpen = false"
        :class="[
          'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group relative',
          isActive(link.path) 
            ? 'bg-indigo-600 text-white shadow-indigo-600/20 shadow-lg' 
            : 'hover:bg-slate-800 hover:text-white'
        ]"
      >
        <component :is="link.icon" :class="['w-5 h-5 flex-shrink-0', isActive(link.path) ? 'text-white' : 'text-slate-400 group-hover:text-indigo-400']" />
        <span v-if="!isCollapsed" class="font-medium text-sm">{{ link.name }}</span>
        
        <!-- Tooltip for collapsed state -->
        <div v-if="isCollapsed" class="absolute left-full ml-2 px-2 py-1 bg-slate-800 text-white text-xs rounded opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all whitespace-nowrap z-50">
          {{ link.name }}
        </div>
      </router-link>
    </nav>

    <!-- Footer / Profile -->
    <div class="p-4 border-t border-slate-800/50 bg-slate-900/50">
      <!-- Profile Action -->
      <router-link 
        to="/profile"
        @click="isMobileMenuOpen = false"
        class="flex items-center gap-3 p-2 rounded-xl hover:bg-slate-800 transition-colors group relative"
      >
        <div class="h-10 w-10 rounded-full border-2 border-slate-700 overflow-hidden flex-shrink-0 group-hover:border-indigo-500 transition-colors shadow-inner bg-slate-800">
           <img
            v-if="authStore.profile?.photo_url"
            :src="authStore.profile.photo_url"
            alt="Profile"
            class="h-full w-full object-cover"
          />
          <User v-else class="w-full h-full p-2 text-slate-400" />
        </div>
        <div v-if="!isCollapsed" class="flex-1 min-w-0">
          <p class="text-xs font-semibold text-white truncate">{{ authStore.profile?.full_name || 'Mi Perfil' }}</p>
          <p class="text-[10px] text-slate-500 truncate capitalize">{{ authStore.profile?.role || 'Docente' }}</p>
        </div>
      </router-link>

      <!-- Logout & Collapse Actions -->
      <div class="mt-4 flex items-center justify-between">
        <button 
          @click="handleLogout"
          class="flex items-center justify-center p-2 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-400/10 transition-all group"
          title="Cerrar Sesión"
        >
          <LogOut class="w-5 h-5" />
          <span v-if="!isCollapsed" class="ml-2 text-xs font-medium">Salir</span>
        </button>

        <button 
          @click="toggleTheme"
          class="flex items-center justify-center p-2 rounded-lg text-slate-400 hover:text-amber-400 hover:bg-amber-400/10 transition-all group"
          :title="theme === 'dark' ? 'Modo Claro' : 'Modo Oscuro'"
        >
          <Sun v-if="theme === 'dark'" class="w-5 h-5 text-amber-400" />
          <Moon v-else class="w-5 h-5 text-indigo-400" />
        </button>

        <button 
          @click="toggleSidebar"
          class="hidden lg:flex items-center justify-center p-2 rounded-lg text-slate-500 hover:text-white hover:bg-slate-800 transition-all"
        >
          <ChevronLeft v-if="!isCollapsed" class="w-5 h-5" />
          <ChevronRight v-else class="w-5 h-5" />
        </button>
      </div>
    </div>
  </aside>

  <!-- Overlay for mobile menu -->
  <div 
    v-if="isMobileMenuOpen" 
    @click="isMobileMenuOpen = false"
    class="fixed inset-0 bg-black/50 backdrop-blur-sm z-30 lg:hidden"
  ></div>
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

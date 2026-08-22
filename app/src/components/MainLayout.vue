<script setup>
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import Sidebar from './Sidebar.vue'
import ErrorBoundary from './ErrorBoundary.vue'
import { useUIStore } from '../stores/ui'
import { useAcademicYearStore } from '../stores/academicYear'
import { Menu, ChevronLeft, Calendar } from 'lucide-vue-next'

const route = useRoute()
const uiStore = useUIStore()
const academicYearStore = useAcademicYearStore()

const toggleMobileMenu = () => {
  uiStore.isMobileMenuOpen = !uiStore.isMobileMenuOpen
}

// Bloquear scroll del body al abrir el drawer móvil
watch(() => uiStore.isMobileMenuOpen, (isOpen) => {
  if (isOpen) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
})

// Cerrar drawer al presionar la tecla ESC
const handleKeyDown = (e) => {
  if (e.key === 'Escape' && uiStore.isMobileMenuOpen) {
    uiStore.isMobileMenuOpen = false
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown)
  document.body.style.overflow = ''
})
</script>

<template>
  <div class="flex min-h-screen bg-slate-50 dark:bg-slate-950 overflow-x-hidden font-sans text-slate-900 dark:text-slate-100">
    <a href="#main-content" class="skip-link">Saltar al contenido principal</a>
    <!-- Sidebar -->
    <Sidebar />

    <!-- Main Content Area - Con padding izquierdo para el sidebar -->
    <div 
      :class="[
        'flex-1 flex flex-col min-h-screen min-w-0 transition-all duration-300 ease-in-out',
        uiStore.isSidebarCollapsed ? 'lg:pl-20' : 'lg:pl-64'
      ]"
    >
      <!-- Top header (Sticky) -->
      <header class="h-16 bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border-b border-slate-200/60 dark:border-slate-800/60 sticky top-0 z-30 flex items-center justify-between px-4 sm:px-8 transition-colors">
        <div class="flex items-center gap-3 min-w-0">
          <button 
            @click="toggleMobileMenu"
            class="lg:hidden min-w-[44px] min-h-[44px] flex items-center justify-center -ml-2 text-slate-600 hover:text-slate-900 dark:text-slate-300 dark:hover:text-white rounded-xl transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500/50 touch-manipulation"
            :aria-label="uiStore.isMobileMenuOpen ? 'Cerrar menú principal' : 'Abrir menú principal'"
            :aria-expanded="uiStore.isMobileMenuOpen"
            aria-controls="main-sidebar"
          >
            <Menu v-if="!uiStore.isMobileMenuOpen" class="w-6 h-6" />
            <ChevronLeft v-else class="w-6 h-6" />
          </button>
          
          <h2 class="text-base sm:text-lg font-bold text-slate-800 dark:text-slate-100 tracking-tight truncate max-w-[200px] sm:max-w-none">
            {{ uiStore.pageTitle || ($route.name ? $route.name.charAt(0).toUpperCase() + $route.name.slice(1) : 'Panel') }}
          </h2>
        </div>
        
        <div class="flex items-center gap-3 shrink-0">
          <!-- Año Lectivo Pill en Top Header -->
          <div 
            v-if="academicYearStore.selectedYearName"
            class="flex items-center gap-1.5 px-2.5 sm:px-3 py-1 sm:py-1.5 rounded-xl border text-[11px] sm:text-xs font-semibold shadow-sm transition-colors"
            :class="[
              academicYearStore.isLocked 
                ? 'bg-rose-50 dark:bg-rose-950/80 border-rose-200 dark:border-rose-900/80 text-rose-800 dark:text-rose-300'
                : 'bg-slate-100/90 dark:bg-slate-800/90 border-slate-200/80 dark:border-slate-700/80 text-slate-700 dark:text-slate-200'
            ]"
            :title="academicYearStore.isLocked ? 'Año Lectivo Bloqueado: ' + academicYearStore.selectedYearName : (academicYearStore.isCurrentYear ? 'Año Lectivo Activo: ' + academicYearStore.selectedYearName : 'Año Lectivo Histórico: ' + academicYearStore.selectedYearName)"
          >
            <Lock v-if="academicYearStore.isLocked" class="w-3.5 h-3.5 text-rose-500 shrink-0" />
            <Calendar v-else class="w-3.5 h-3.5 text-indigo-500 shrink-0" />
            <span class="hidden sm:inline font-normal" :class="academicYearStore.isLocked ? 'text-rose-600 dark:text-rose-400' : 'text-slate-500 dark:text-slate-400'">Año:</span>
            <span>{{ academicYearStore.selectedYearName }}</span>
            <span 
              class="w-2 h-2 rounded-full"
              :class="academicYearStore.isLocked ? 'bg-rose-500' : (academicYearStore.isCurrentYear ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500')"
            ></span>
          </div>

          <div class="text-[10px] sm:text-xs font-semibold text-emerald-700 bg-emerald-100 dark:bg-emerald-950/80 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800 px-2.5 py-1 rounded-full uppercase tracking-wider leading-none flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> En Línea
          </div>
        </div>
      </header>

      <!-- Page Content -->
      <main id="main-content" tabindex="-1" class="flex-1 min-w-0 overflow-x-hidden overflow-y-auto custom-scrollbar-main transition-all duration-300">
        <div class="p-3 sm:p-6 md:p-8 max-w-[1920px] w-full mx-auto min-w-0">
          <router-view v-slot="{ Component }">
            <transition name="fade-slide" mode="out-in">
              <div :key="$route.fullPath">
                <ErrorBoundary>
                  <Suspense>
                    <template #default>
                      <component :is="Component" />
                    </template>
                    <template #fallback>
                      <div class="flex items-center justify-center min-h-[400px]">
                        <div class="flex flex-col items-center gap-4">
                          <div class="relative">
                            <div class="absolute inset-0 bg-indigo-500/20 blur-xl rounded-full animate-pulse"></div>
                            <svg class="animate-spin h-10 w-10 text-indigo-600 relative" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                            </svg>
                          </div>
                          <p class="text-sm font-medium text-slate-500 animate-pulse">Cargando módulo...</p>
                        </div>
                      </div>
                    </template>
                  </Suspense>
                </ErrorBoundary>
              </div>
            </transition>
          </router-view>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
/* Page transitions */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.25s ease-out;
}

.fade-slide-enter-from {
  opacity: 0;
  transform: translateY(10px);
}

.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

.custom-scrollbar-main::-webkit-scrollbar {
  width: 6px;
}
.custom-scrollbar-main::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar-main::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}
.custom-scrollbar-main::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
</style>

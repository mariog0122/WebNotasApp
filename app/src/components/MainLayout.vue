<script setup>
import { ref } from 'vue'
import Sidebar from './Sidebar.vue'
import ErrorBoundary from './ErrorBoundary.vue'

// Logic to pass down sidebar state if needed, 
// but for simplicity, the sidebar manages its own state
// and the content area just needs to be responsive.
</script>

<template>
  <div class="flex min-h-screen bg-slate-50 overflow-hidden font-sans text-slate-900">
    <!-- Sidebar -->
    <Sidebar />

    <!-- Main Content Area - Con padding izquierdo para el sidebar -->
    <div class="flex-1 flex flex-col min-h-screen transition-all duration-300 ease-in-out content-layout-wrapper">
      <!-- Top header (Sticky or static) -->
      <header class="h-16 bg-white/70 dark:bg-slate-900/70 backdrop-blur-xl border-b border-slate-200/50 dark:border-slate-800/50 sticky top-0 z-30 flex items-center justify-between px-8 transition-colors">
        <div class="flex items-center gap-4">
          <!-- Placeholder for breadcrumbs or page title -->
          <h2 class="text-lg font-bold text-slate-800 dark:text-slate-100 tracking-tight">
            {{ $route.name ? $route.name.charAt(0).toUpperCase() + $route.name.slice(1) : 'Panel' }}
          </h2>
        </div>
        
        <div class="flex items-center gap-4">
          <!-- Notification Bell or other actions could go here -->
          <div class="text-xs font-medium text-slate-400 bg-slate-100 dark:bg-slate-800 dark:text-slate-300 px-2 py-1 rounded-md uppercase tracking-widest leading-none">
            En Línea
          </div>
        </div>
      </header>

      <!-- Page Content -->
      <main class="flex-1 overflow-x-hidden overflow-y-auto custom-scrollbar-main transition-all duration-300">
        <div class="p-6 md:p-8">
          <router-view v-slot="{ Component }">
            <transition 
              name="fade-slide" 
              mode="out-in"
            >
              <ErrorBoundary>
                <Suspense>
                  <template #default>
                    <component :is="Component" />
                  </template>
                  <template #fallback>
                    <div class="flex items-center justify-center min-h-[400px]">
                      <div class="flex flex-col items-center gap-4">
                        <div class="relative">
                          <div class="absolute inset-0 bg-blue-500/20 blur-xl rounded-full animate-pulse"></div>
                          <svg class="animate-spin h-10 w-10 text-blue-600 relative" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
            </transition>
          </router-view>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
/* Responsive padding for desktop */
@media (min-width: 1024px) {
  /* This matches the sidebar widths */
  .flex-1 {
    /* If we wanted to shift the entire content, we'd use margin or padding here.
       But since the sidebar is fixed, we use padding-left on the content container.
       Wait, let's use a dynamic class based on sidebar state if we want to be fancy.
       For now, let's just make sure the sidebar doesn't overlap.
    */
  }
}

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
  background: #f1f5f9;
}
.custom-scrollbar-main::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}
.custom-scrollbar-main::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
</style>

<style>
/* Responsive padding for desktop based on sidebar state */
@media (min-width: 1024px) {
  /* Expanded sidebar (w-64) */
  .content-layout-wrapper {
    padding-left: 16rem;
  }
  
  /* Collapsed sidebar (w-20) */
  body:has(aside.w-20) .content-layout-wrapper {
    padding-left: 5rem;
  }
}
</style>

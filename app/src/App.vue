<script setup>
import { computed, onMounted, watch, onErrorCaptured, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useUIStore } from './stores/ui'
import { useTheme } from './composables/useTheme'
import { useNetwork } from './composables/useNetwork'
import InteractiveGridPattern from './components/InteractiveGridPattern.vue'
import MainLayout from './components/MainLayout.vue'
import ErrorBoundary from './components/ErrorBoundary.vue'
import { Toaster, toast } from 'vue-sonner'

const route = useRoute()
const uiStore = useUIStore()
const { initTheme } = useTheme()
const { isOnline } = useNetwork()

const globalError = ref(null)

onErrorCaptured((err, instance, info) => {
  console.error('Error Boundary Caught:', err, info)
  globalError.value = err
  toast.error('Ocurrió un error inesperado', {
    description: err.message || 'La aplicación pudo haberse recuperado parcialmente.',
    duration: 8000
  })
  // Prevent the error from crashing the entire Vue app
  return false
})

watch(isOnline, (online) => {
  if (!online) {
    toast.error('Sin conexión a internet. Modo Lectura activado.', {
      duration: Number.POSITIVE_INFINITY,
      id: 'offline-toast'
    })
  } else {
    toast.dismiss('offline-toast')
    toast.success('Conexión restaurada.')
  }
})

onMounted(() => {
  initTheme()
  if (!isOnline.value) {
    toast.error('Estás sin conexión. Modo Lectura activado.', {
      duration: Number.POSITIVE_INFINITY,
      id: 'offline-toast'
    })
  }
})

const isLoginPage = computed(() => route.name === 'login')
</script>

<template>
  <div class="relative min-h-screen font-sans antialiased text-slate-900">
    <!-- Global Background Grid - DISABLED: was blocking pointer events across the app -->
    <!--
    <InteractiveGridPattern
      v-if="!isLoginPage"
      class="fixed inset-0 z-0 opacity-40 pointer-events-none"
      :width="40"
      :height="40"
    />
    -->

    <!-- Auth Loading Flash -->
    <Transition name="fade">
      <div
        v-if="uiStore.showAuthFlash"
        class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-md"
      >
        <div class="bg-white rounded-3xl shadow-2xl p-10 flex flex-col items-center gap-6 transform scale-110">
          <div class="relative">
            <div class="absolute inset-0 bg-indigo-500/20 blur-xl rounded-full animate-pulse"></div>
            <svg class="animate-spin h-12 w-12 text-indigo-600 relative" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
          <div class="text-center">
            <p class="text-slate-900 font-bold text-lg">WebNotas</p>
            <p class="text-slate-500 text-sm">Verificando sesión segura...</p>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Main Content Wrapper -->
    <ErrorBoundary>
      <Suspense>
        <template #default>
          <div>
            <template v-if="isLoginPage">
              <router-view />
            </template>
            
            <template v-else>
              <MainLayout />
            </template>
          </div>
        </template>
        <template #fallback>
          <div class="fixed inset-0 flex flex-col items-center justify-center bg-slate-50">
            <div class="animate-spin h-10 w-10 border-4 border-indigo-500 border-t-transparent rounded-full mb-4"></div>
            <p class="text-slate-500 font-medium">Cargando aplicación...</p>
          </div>
        </template>
      </Suspense>
    </ErrorBoundary>

    <!-- Global Toaster from vue-sonner -->
    <Toaster position="bottom-right" expand :richColors="true" closeButton theme="system" />
  </div>
</template>

<style>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}

/* Base styles for smooth scrolling and better typography */
html {
  scroll-behavior: smooth;
}

body {
  @apply bg-slate-50;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* Custom scrollbars for the whole app */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}
::-webkit-scrollbar-track {
  background: transparent;
}
::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}
::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
</style>

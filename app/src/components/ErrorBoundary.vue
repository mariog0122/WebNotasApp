<script setup>
import { ref, onErrorCaptured } from 'vue'
import { toast } from 'vue-sonner'

const error = ref(null)

onErrorCaptured((err, instance, info) => {
  error.value = err
  console.error('[ErrorBoundary Captured]', err, instance, info)
  toast.error(`Ha ocurrido un error inesperado. Por favor, recarga la página.`, {
    description: err.message || 'Fallo interno',
    duration: 5000,
  })
  
  // Return false to prevent the error from propagating further up
  return false
})

import { watch } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
watch(
  () => route.path,
  () => {
    if (error.value) {
      error.value = null
    }
  }
)
</script>

<template>
  <!-- Render the children components normally, unless an error occurred -->
  <slot v-if="!error"></slot>

  <!-- Fallback UI if this boundary catches an error -->
  <div v-else class="flex flex-col items-center justify-center p-8 m-4 border-2 border-red-500/20 bg-red-500/5 rounded-xl">
    <div class="p-3 bg-red-100 dark:bg-red-900/30 rounded-full mb-4">
      <svg class="w-8 h-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
      </svg>
    </div>
    <h3 class="text-lg font-bold text-red-600 dark:text-red-400 mb-2">Error de Carga</h3>
    <p class="text-sm text-slate-500 dark:text-slate-400 text-center mb-6">
      No pudimos cargar esta sección de la aplicación correctamente.
    </p>
    <button 
      @click="error = null"
      class="px-4 py-2 bg-slate-900 dark:bg-slate-800 text-white rounded-lg hover:bg-slate-800 dark:hover:bg-slate-700 transition-colors shadow-md"
    >
      Reintentar
    </button>
  </div>
</template>

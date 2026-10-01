<script setup>
defineProps({
  isAdmin: {
    type: Boolean,
    default: false
  },
  loadingQuarters: {
    type: Boolean,
    default: false
  },
  quartersError: {
    type: String,
    default: ''
  },
  quarters: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits(['set-active', 'toggle-lock'])
</script>

<template>
  <div v-if="isAdmin" class="app-card p-6 mb-8 border border-amber-200 dark:border-amber-900/40 bg-amber-50/30 dark:bg-amber-950/20 shadow-sm rounded-2xl">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-amber-600 dark:text-amber-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
        </svg>
        Gestión de Períodos de Calificación
      </h2>
      <div class="text-xs text-amber-800 dark:text-amber-300 bg-amber-100 dark:bg-amber-900/60 border border-amber-200 dark:border-amber-800 px-3 py-1 rounded-full font-bold">Control de Rector</div>
    </div>
    
    <div v-if="loadingQuarters" class="text-sm text-slate-500 dark:text-slate-400 py-4 text-center">Cargando períodos...</div>
    <div v-else-if="quartersError" class="text-sm text-rose-600 dark:text-rose-400 py-4">{{ quartersError }}</div>
    <div v-else class="overflow-x-auto bg-slate-50/50 dark:bg-slate-950/60 rounded-xl border border-slate-200 dark:border-slate-800">
      <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-800">
        <thead class="bg-amber-100/50 dark:bg-amber-900/30">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Período</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Activo (Por Defecto)</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Estado (Bloqueo)</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Acción</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-200 dark:divide-slate-800">
          <tr v-for="q in quarters" :key="q.id" class="hover:bg-slate-100/50 dark:hover:bg-slate-800/50 transition-colors">
            <td class="px-4 py-3 text-sm font-bold text-slate-900 dark:text-white">
              {{ q.name }}
            </td>
            <td class="px-4 py-3 text-center">
              <input 
                type="radio" 
                name="active_quarter" 
                :checked="q.is_active" 
                @change="emit('set-active', q)" 
                class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 cursor-pointer"
              >
            </td>
            <td class="px-4 py-3 text-center">
              <span v-if="q.is_locked" class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-rose-100 dark:bg-rose-950/80 text-rose-800 dark:text-rose-300 border border-rose-200 dark:border-rose-800">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
                </svg>
                Cerrado
              </span>
              <span v-else class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-100 dark:bg-emerald-950/80 text-emerald-800 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10 2a5 5 0 00-5 5v2a2 2 0 00-2 2v5a2 2 0 002 2h10a2 2 0 002-2v-5a2 2 0 00-2-2H7V7a3 3 0 015.905-.75 1 1 0 001.937-.5A5.002 5.002 0 0010 2z" />
                </svg>
                Abierto
              </span>
            </td>
            <td class="px-4 py-3 text-center">
              <button 
                @click="emit('toggle-lock', q)" 
                :class="['px-3 py-1.5 text-xs font-semibold rounded-lg border transition-colors focus:ring-2 focus:outline-none shadow-sm', 
                         q.is_locked ? 'bg-white dark:bg-slate-800 text-emerald-700 dark:text-emerald-400 border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 focus:ring-emerald-500' : 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-300 dark:border-rose-800 hover:bg-rose-100 dark:hover:bg-rose-900/50 focus:ring-rose-500']"
              >
                {{ q.is_locked ? 'Desbloquear Período' : 'Bloquear (Cerrar) Período' }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
      <strong>Nota:</strong> Los períodos bloqueados previenen que los docentes modifiquen calificaciones en dicho período. Actívelo cuando hayan finalizado las juntas de curso.
    </p>
  </div>
</template>

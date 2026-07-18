<script setup>
import { inject } from 'vue'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'

const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')
</script>

<template>
  <div>
    <div class="app-card p-5 mb-6 border border-slate-200/80 shadow-sm bg-gradient-to-br from-white via-white to-slate-50">
      <div class="flex items-center gap-4">
        <div class="h-14 w-14 rounded-2xl border border-slate-200 bg-white overflow-hidden flex items-center justify-center shadow-sm ring-1 ring-slate-100">
          <img v-if="gp.institutionLogoUrl" :src="gp.institutionLogoUrl" alt="Logo institución" class="h-full w-full object-contain p-1" />
          <span v-else class="text-xs text-slate-500">Logo</span>
        </div>
        <div>
          <h2 class="text-xl font-semibold tracking-tight text-slate-900">{{ gp.institutionName || 'Institución' }}</h2>
          <p class="text-sm text-slate-500">Reporte de calificaciones y actas</p>
        </div>
      </div>
    </div>
    <h1 class="app-title mb-2">Registro de calificaciones</h1>
    <p class="text-sm text-slate-500 mb-6 max-w-2xl">
      Selecciona curso y periodo, abre cada materia y guarda los cambios. Las medias ponderadas (70% formativo / 30% sumativo) se calculan en tiempo real.
    </p>

    <div
      v-if="gp.periodHint"
      class="mb-5 rounded-xl border border-amber-200/90 bg-amber-50 px-4 py-3 text-sm text-amber-950 shadow-sm"
      role="status"
      aria-live="polite"
    >
      {{ gp.periodHint }}
    </div>
  </div>
</template>

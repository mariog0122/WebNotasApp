<script setup>
import { inject } from 'vue'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'

const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')
</script>

<template>
  <div>
    <div class="app-card p-5 mb-6 flex flex-col md:flex-row gap-5 items-end border border-slate-200/80 shadow-sm">
      <div class="w-full md:w-1/3">
        <label for="grades-select-course" class="block text-slate-600 text-sm font-medium mb-1.5">Curso</label>
        <select id="grades-select-course" v-model="gp.selectedCourse" class="app-input">
          <option :value="null">Selecciona un curso…</option>
          <option v-for="c in gp.courses" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
      <div class="w-full md:w-1/3">
        <label for="grades-select-quarter" class="block text-slate-600 text-sm font-medium mb-1.5">Periodo</label>
        <select id="grades-select-quarter" v-model="gp.selectedQuarter" class="app-input">
          <option v-for="q in gp.quarters" :key="q.id" :value="q.id">{{ q.name }}</option>
        </select>
      </div>
    </div>

    <div v-if="gp.quartersLoading" class="text-sm text-slate-500 mb-4 flex items-center gap-2">
      <span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-teal-600 border-t-transparent" aria-hidden="true" />
      Cargando periodos…
    </div>
    <div
      v-else-if="gp.quartersError"
      class="text-sm text-rose-600 mb-4 rounded-lg border border-rose-100 bg-rose-50 px-3 py-2"
      role="alert"
    >
      {{ gp.quartersError }}
    </div>
    <div v-else-if="gp.quarters.length === 0" class="app-card p-5 mb-6 border border-slate-200">
      <p class="text-sm text-slate-600 mb-3">No hay periodos creados. Crea al menos uno para continuar.</p>
      <button type="button" class="app-btn app-btn-primary" @click="gp.createDefaultQuarters">
        Crear periodos por defecto
      </button>
    </div>
  </div>
</template>

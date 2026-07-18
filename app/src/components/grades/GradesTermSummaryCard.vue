<script setup>
import { inject } from 'vue'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'

const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')
</script>

<template>
  <div
    v-if="gp.selectedCourse && gp.selectedQuarter"
    class="app-card p-5 mb-6 border border-teal-100/80 bg-gradient-to-r from-teal-50/40 to-white shadow-sm"
  >
    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
      <div>
        <h2 class="text-lg font-semibold text-slate-900">Resumen del periodo</h2>
        <p class="text-sm text-slate-500">
          {{ gp.getCourseName() }} · {{ gp.getQuarterName() }}
        </p>
      </div>
      <div class="flex flex-wrap gap-3 text-sm">
        <div class="rounded-lg border border-slate-200 bg-white px-3 py-2 shadow-sm">
          Estudiantes: <span class="text-slate-900 font-bold tabular-nums">{{ gp.studentsCount }}</span>
        </div>
        <div class="rounded-lg border border-slate-200 bg-white px-3 py-2 shadow-sm">
          Asignaturas: <span class="text-slate-900 font-bold tabular-nums">{{ gp.subjects.length }}</span>
        </div>
      </div>
    </div>
    <p class="text-sm text-slate-500 mt-3">Abre una asignatura para registrar o revisar el acta.</p>
    <div class="mt-4 flex flex-wrap items-center gap-3">
      <button type="button" class="app-btn app-btn-primary" @click="gp.showProjectModal = true">
        Proyecto interdisciplinario
      </button>
      <span v-if="gp.projectMessage" class="text-sm text-amber-700">{{ gp.projectMessage }}</span>
    </div>
    <div v-if="gp.subjectsError" class="mt-3 text-sm text-rose-600" role="alert">{{ gp.subjectsError }}</div>
    <div class="mt-3">
      <button type="button" class="app-btn app-btn-ghost text-xs" @click="gp.fetchSubjectsForCourse(gp.selectedCourse)">
        Recargar asignaturas
      </button>
    </div>
  </div>
</template>

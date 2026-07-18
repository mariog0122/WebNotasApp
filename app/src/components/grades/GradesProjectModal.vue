<script setup>
import { inject, ref, watch, nextTick } from 'vue'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'

const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')

const dialogRef = ref(null)

watch(
  () => gp.showProjectModal,
  async (open) => {
    await nextTick()
    const el = dialogRef.value
    if (!el) return
    try {
      if (open) {
        if (!el.open) el.showModal()
      } else if (el.open) {
        el.close()
      }
    } catch (e) {
      console.warn('[GradesProjectModal] dialog API', e)
    }
  },
  { flush: 'post' },
)

const onDialogClose = () => {
  gp.showProjectModal = false
}
</script>

<template>
  <dialog
    ref="dialogRef"
    class="premium-dialog max-h-[100dvh] w-[calc(100%-2rem)] max-w-4xl overflow-hidden rounded-2xl border border-white/10 bg-slate-900 p-0 text-left shadow-2xl backdrop:bg-black/70 backdrop:backdrop-blur-sm"
    aria-labelledby="grades-proj-modal-title"
    @close="onDialogClose"
    @cancel.prevent="gp.showProjectModal = false"
  >
    <div v-if="gp.showProjectModal" class="max-h-[85dvh] overflow-y-auto bg-slate-900">
      <!-- Header -->
      <div class="bg-gradient-to-r from-teal-600 via-teal-500 to-emerald-500 px-5 py-5">
        <h3 id="grades-proj-modal-title" class="text-xl font-bold text-white flex items-center gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>
          Proyecto global del periodo
        </h3>
        <p class="text-sm text-white/70 mt-1">Elige en qué asignaturas aplica el proyecto y registra una nota por estudiante y materia.</p>
      </div>

      <div class="px-5 py-5 space-y-6">
        <!-- Subject Selection Cards -->
        <div>
          <div class="flex items-center gap-2 mb-3">
            <span class="inline-block w-1 h-5 rounded bg-gradient-to-b from-teal-400 to-teal-600"></span>
            <h4 class="text-sm font-bold text-white uppercase tracking-wide">Asignaturas incluidas</h4>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
            <div
              v-for="subject in gp.subjects"
              :key="'p' + subject.subject_id"
              class="subject-select-card"
              :class="{ 'is-selected': gp.projectSubjects?.has(subject.subject_id) }"
              @click="gp.toggleProjectSubject(subject.subject_id)"
            >
              <div class="subject-select-check">
                <svg v-if="gp.projectSubjects?.has(subject.subject_id)" xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" /></svg>
              </div>
              <div class="subject-select-icon">📘</div>
              <span class="text-sm font-medium text-slate-200">{{ subject.name }}</span>
            </div>
          </div>
          <div class="mt-3">
            <button
              type="button"
              class="rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 px-5 py-2 text-sm font-bold text-white hover:from-teal-500 hover:to-teal-400 shadow-lg shadow-teal-900/30 transition-all disabled:opacity-60"
              :disabled="gp.projectSaving"
              @click="gp.saveProjectSettings"
            >
              Guardar asignaturas
            </button>
          </div>
        </div>

        <!-- Grades Table -->
        <div>
          <div class="flex items-center gap-2 mb-3">
            <span class="inline-block w-1 h-5 rounded bg-gradient-to-b from-emerald-400 to-emerald-600"></span>
            <h4 class="text-sm font-bold text-white uppercase tracking-wide">Notas por materia</h4>
          </div>
          <div class="max-h-80 overflow-y-auto border border-slate-700 rounded-xl">
            <table class="min-w-full divide-y divide-slate-700">
              <thead class="bg-slate-800/80 sticky top-0 z-10">
                <tr>
                  <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-slate-300 uppercase tracking-wider">Estudiante</th>
                  <th
                    v-for="sub in gp.getSelectedProjectSubjects()"
                    :key="'ph' + sub.subject_id"
                    scope="col"
                    class="px-4 py-3 text-left text-xs font-bold text-slate-300 uppercase tracking-wider"
                  >
                    {{ sub.name }}
                  </th>
                  <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-teal-300 uppercase tracking-wider w-32">Promedio</th>
                </tr>
              </thead>
              <tbody class="bg-slate-900 divide-y divide-slate-700/50">
                <tr v-for="student in gp.projectStudents" :key="'pg' + student.id" class="hover:bg-slate-800/50 transition-colors">
                  <th scope="row" class="px-4 py-3 text-sm text-white font-medium text-left">{{ student.full_name }}</th>
                  <td
                    v-for="sub in gp.getSelectedProjectSubjects()"
                    :key="'pc' + student.id + '-' + sub.subject_id"
                    class="px-2 py-2"
                  >
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      max="10"
                      class="w-24 rounded-lg bg-slate-950 text-white p-2 border border-slate-600 focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition-all text-center"
                      :value="gp.projectSubjectGrades?.[student.id]?.[sub.subject_id] ?? ''"
                      @input="(e) => gp.onProjectInput(student.id, sub.subject_id, e)"
                    />
                  </td>
                  <td class="px-4 py-3 text-sm text-teal-300 font-bold tabular-nums">
                    {{ gp.getProjectAverage(student.id)?.toFixed(2) || '-' }}
                  </td>
                </tr>
                <tr v-if="gp.projectStudents?.length === 0">
                  <td :colspan="gp.getSelectedProjectSubjects()?.length + 2" class="px-4 py-6 text-center text-sm text-slate-400">
                    No hay estudiantes en este curso.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="mt-3 flex flex-wrap items-center gap-3">
            <button
              type="button"
              class="rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 py-2 text-sm font-bold text-white hover:from-emerald-500 hover:to-emerald-400 shadow-lg shadow-emerald-900/30 transition-all disabled:opacity-60"
              :disabled="gp.projectSaving"
              @click="gp.saveProjectGrades"
            >
              Guardar notas de proyecto
            </button>
            <span v-if="gp.projectMessage" class="text-sm text-amber-200 font-medium">{{ gp.projectMessage }}</span>
          </div>
        </div>
      </div>
    </div>

    <div v-if="gp.showProjectModal" class="border-t border-slate-800 bg-slate-950 px-5 py-3 flex justify-end">
      <button
        type="button"
        class="rounded-xl border border-slate-600 px-5 py-2 text-sm font-medium text-slate-300 hover:text-white hover:border-slate-500 transition-colors"
        @click="gp.showProjectModal = false"
      >
        Cerrar
      </button>
    </div>
  </dialog>
</template>

<style scoped>
.premium-dialog::backdrop {
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(4px);
}

.subject-select-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  border: 2px solid #334155;
  background: #0f172a;
  cursor: pointer;
  transition: all 0.2s ease;
  user-select: none;
}

.subject-select-card:hover {
  border-color: #64748b;
  background: #1e293b;
}

.subject-select-card.is-selected {
  border-color: #0d9488;
  background: linear-gradient(135deg, rgba(13, 148, 136, 0.15), rgba(20, 184, 166, 0.05));
  box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.2);
}

.subject-select-check {
  width: 20px;
  height: 20px;
  border-radius: 6px;
  border: 2px solid #475569;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.subject-select-card.is-selected .subject-select-check {
  background: linear-gradient(135deg, #0d9488, #14b8a6);
  border-color: #0d9488;
  color: #fff;
}

.subject-select-icon {
  font-size: 18px;
  flex-shrink: 0;
}
</style>

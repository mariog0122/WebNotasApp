<script setup>
import { inject, ref, watch, nextTick } from 'vue'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'

const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')

const dialogRef = ref(null)

watch(
  () => gp.showHeaderModal,
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
      console.warn('[GradesColumnRenameModal] dialog API', e)
    }
  },
  { flush: 'post' },
)

const onDialogClose = () => {
  gp.showHeaderModal = false
}

const quickTags = [
  'Lecciones 1',
  'Lecciones 2',
  'Pruebas 1',
  'Pruebas 2',
  'Tareas 1',
  'Tareas 2',
  'Proyectos 1',
  'Proyectos 2',
  'Exposiciones 1',
  'Exposiciones 2',
  'Talleres 1',
  'Talleres 2',
  'Productos 1',
  'Productos 2',
  'Refuerzo Pedagogico',
  'Proyecto Interdisciplinario',
  'Examen del Trimestre',
]
</script>

<template>
  <dialog
    ref="dialogRef"
    class="premium-dialog max-h-[100dvh] w-[calc(100%-2rem)] max-w-lg overflow-hidden rounded-2xl border border-white/10 bg-slate-900 p-0 text-left shadow-2xl backdrop:bg-black/70 backdrop:backdrop-blur-sm"
    aria-labelledby="grades-col-modal-title"
    @close="onDialogClose"
    @cancel.prevent="gp.showHeaderModal = false"
  >
    <template v-if="gp.editingDefinition">
      <div class="bg-gradient-to-r from-teal-600 to-teal-500 px-5 py-4">
        <h3 id="grades-col-modal-title" class="text-lg font-bold text-white">Editar nombre de columna</h3>
        <p class="text-sm text-teal-100/70 mt-0.5">Personaliza el nombre de esta columna de calificación.</p>
      </div>

      <div class="px-5 py-5 bg-slate-900">
        <label class="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">Nombre de la columna</label>
        <input
          v-model="gp.editingDefinition.name"
          class="w-full bg-slate-950 text-white rounded-xl p-3 border border-slate-600 focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition-all"
        />
        <div class="mt-5">
          <span class="text-xs text-slate-500 uppercase tracking-wider font-semibold block mb-3">Sugerencias rápidas</span>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="tag in quickTags"
              :key="tag"
              type="button"
              class="rounded-full bg-slate-800 text-slate-300 text-xs px-3 py-1.5 hover:bg-teal-600/20 hover:text-teal-300 hover:border-teal-500/30 border border-slate-700 transition-all duration-200"
              @click="gp.editingDefinition.name = tag"
            >
              {{ tag }}
            </button>
          </div>
        </div>
      </div>

      <div class="border-t border-slate-800 bg-slate-950 px-5 py-3 flex justify-end gap-2">
        <button
          type="button"
          class="rounded-xl border border-slate-600 px-4 py-2 text-sm font-medium text-slate-300 hover:text-white hover:border-slate-500 transition-colors"
          @click="gp.showHeaderModal = false"
        >
          Cancelar
        </button>
        <button
          type="button"
          class="rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 px-5 py-2 text-sm font-bold text-white hover:from-teal-500 hover:to-teal-400 shadow-lg shadow-teal-900/30 transition-all"
          @click="gp.saveHeader"
        >
          Guardar
        </button>
      </div>
    </template>
  </dialog>
</template>

<style scoped>
.premium-dialog::backdrop {
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(4px);
}
</style>

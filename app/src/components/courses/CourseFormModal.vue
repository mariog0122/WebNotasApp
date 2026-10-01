<script setup>
defineProps({
  show: {
    type: Boolean,
    default: false
  },
  editingCourse: {
    type: Object,
    default: null
  },
  form: {
    type: Object,
    required: true
  },
  courseSaving: {
    type: Boolean,
    default: false
  },
  courseSaveError: {
    type: String,
    default: ''
  },
  isDuplicateCourseName: {
    type: Boolean,
    default: false
  },
  levelOptions: {
    type: Array,
    required: true
  },
  trackOptions: {
    type: Array,
    required: true
  }
})

const emit = defineEmits(['close', 'save', 'clear-error'])
</script>

<template>
  <div v-if="show" class="modal-container" role="dialog" aria-modal="true">
    <div class="modal-backdrop" @click="emit('close')"></div>
    <div class="modal-panel">
      <div class="modal-header modal-header-accent">
        <h3 class="modal-title" style="color:#fff">{{ editingCourse ? 'Editar Curso' : 'Nuevo Curso' }}</h3>
        <p class="modal-subtitle">{{ editingCourse ? 'Modifica los datos del curso.' : 'Ingresa los datos del nuevo curso.' }}</p>
      </div>
      <div class="modal-body">
        <div v-if="courseSaveError" class="mb-4 p-3 bg-rose-50 border border-rose-200 rounded-xl text-xs text-rose-700 font-medium flex items-center gap-2 shadow-sm">
          <span class="text-rose-500 font-bold shrink-0">⚠</span>
          <span>{{ courseSaveError }}</span>
        </div>

        <div class="modal-field">
          <label class="modal-label">Nombre del Curso *</label>
          <input 
            v-model="form.name" 
            type="text" 
            class="app-input"
            :class="{ 'border-rose-400 focus:border-rose-500 focus:ring-rose-500': isDuplicateCourseName }"
            placeholder="Ej: 1ro Bachillerato A"
            @input="emit('clear-error')"
          >
          <p v-if="isDuplicateCourseName" class="text-xs text-rose-600 font-semibold mt-1">
            ⚠ Ya existe un curso registrado con este nombre en este año lectivo.
          </p>
        </div>
        <div class="modal-field">
          <label class="modal-label">Año Lectivo</label>
          <input v-model="form.academic_year" type="text" class="app-input bg-slate-100 dark:bg-slate-800/80 cursor-not-allowed" readonly>
        </div>
        <div class="modal-field">
          <label class="modal-label">Nivel</label>
          <select v-model="form.level" class="app-input">
            <option v-for="opt in levelOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
        </div>
        <div class="modal-field">
          <label class="modal-label">Itinerario</label>
          <select v-model="form.track" class="app-input">
            <option v-for="opt in trackOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button @click="emit('close')" :disabled="courseSaving" class="app-btn app-btn-ghost">Cancelar</button>
        <button @click="emit('save')" :disabled="courseSaving || isDuplicateCourseName" class="app-btn app-btn-primary disabled:opacity-50">
          <svg v-if="!courseSaving" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
          {{ courseSaving ? 'Guardando...' : 'Guardar' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  show: {
    type: Boolean,
    default: false
  },
  managingCourse: {
    type: Object,
    default: null
  },
  allSubjects: {
    type: Array,
    default: () => []
  },
  institutionTeachers: {
    type: Array,
    default: () => []
  },
  courseSubjectTeachers: {
    type: Object,
    required: true
  },
  selectedCourseSubjects: {
    type: Object,
    required: true
  },
  subjectsLoading: {
    type: Boolean,
    default: false
  },
  subjectsSaving: {
    type: Boolean,
    default: false
  },
  subjectsMessage: {
    type: String,
    default: ''
  },
  creatingBaseSubjects: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits([
  'close',
  'save',
  'toggle-subject',
  'select-all',
  'deselect-all',
  'create-default-subjects'
])
</script>

<template>
  <div v-if="show" class="modal-container" role="dialog" aria-modal="true">
    <div class="modal-backdrop" @click="emit('close')"></div>
    <div class="modal-panel modal-panel-lg">
      <div class="modal-header modal-header-accent">
        <h3 class="modal-title" style="color:#fff">Asignar Materias - {{ managingCourse?.name }}</h3>
        <p class="modal-subtitle">Selecciona las materias que forman parte de la malla de este curso.</p>
      </div>
      <div class="modal-body" style="max-height:55vh;overflow-y:auto">
        <!-- Selection Controls Bar -->
        <div v-if="allSubjects.length > 0" class="flex flex-wrap items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-200 dark:border-slate-800">
          <span class="text-xs font-semibold text-slate-600 dark:text-slate-400">
            {{ selectedCourseSubjects.size }} de {{ allSubjects.length }} materias seleccionadas
          </span>
          <div class="flex items-center gap-2">
            <button 
              type="button" 
              @click="emit('select-all')" 
              class="px-2.5 py-1 text-xs font-medium text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 rounded-lg hover:bg-teal-100 transition-colors"
            >
              Seleccionar Todas
            </button>
            <button 
              type="button" 
              @click="emit('deselect-all')" 
              class="px-2.5 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 rounded-lg hover:bg-slate-200 transition-colors"
            >
              Deseleccionar
            </button>
          </div>
        </div>

        <p v-if="subjectsMessage" class="text-sm mb-3 font-medium" :class="subjectsMessage.includes('Error') ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'">
          {{ subjectsMessage }}
        </p>

        <div v-if="subjectsLoading" class="text-center py-8">
          <span class="app-spinner mr-2"></span>
          <span class="text-sm text-slate-500">Cargando asignaturas disponibles...</span>
        </div>

        <div v-else-if="allSubjects.length === 0" class="text-center py-6 px-4 bg-slate-50 dark:bg-slate-900/60 rounded-2xl border border-slate-200 dark:border-slate-800 space-y-3">
          <div class="w-12 h-12 rounded-2xl bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-300 mx-auto flex items-center justify-center text-xl font-bold">
            📚
          </div>
          <div>
            <p class="text-sm font-bold text-slate-800 dark:text-slate-200">No hay asignaturas registradas en la institución</p>
            <p class="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
              Puedes generar las 8 materias base del currículo ecuatoriano en un clic o gestionarlas en la sección de Asignaturas.
            </p>
          </div>
          <div class="pt-2">
            <button 
              type="button" 
              @click="emit('create-default-subjects')" 
              :disabled="creatingBaseSubjects"
              class="app-btn app-btn-primary text-xs font-bold px-4 py-2"
            >
              <span v-if="creatingBaseSubjects" class="app-spinner w-3.5 h-3.5 mr-1.5"></span>
              <span>{{ creatingBaseSubjects ? 'Creando materias...' : '⚡ Crear 8 Asignaturas Base Automáticas' }}</span>
            </button>
          </div>
        </div>

        <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div 
            v-for="subject in allSubjects" 
            :key="subject.id"
            class="flex flex-col p-3 rounded-xl border border-slate-200 dark:border-slate-800 transition-all shadow-sm"
            :class="{ 'bg-teal-50/80 dark:bg-teal-950/40 border-teal-300 dark:border-teal-800/80 ring-1 ring-teal-500/20': selectedCourseSubjects.has(subject.id), 'hover:bg-slate-50 dark:hover:bg-slate-800/60': !selectedCourseSubjects.has(subject.id) }"
          >
            <label class="flex items-center gap-3 cursor-pointer select-none">
              <input 
                type="checkbox" 
                :checked="selectedCourseSubjects.has(subject.id)" 
                @change="emit('toggle-subject', subject.id)"
                class="h-4 w-4 text-teal-600 rounded border-slate-300 focus:ring-teal-500 cursor-pointer"
              >
              <div class="flex-1 min-w-0">
                <span class="text-sm font-semibold text-slate-900 dark:text-slate-100 block truncate">{{ subject.name }}</span>
                <span v-if="subject.is_project_subject" class="text-[10px] font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400">
                  Interdisciplinario
                </span>
              </div>
            </label>

            <!-- Asignación de Docente -->
            <div v-if="selectedCourseSubjects.has(subject.id)" class="mt-2.5 pt-2 border-t border-teal-200/80 dark:border-teal-800/60 flex items-center gap-2">
              <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 shrink-0">Docente:</span>
              <select 
                v-model="courseSubjectTeachers[subject.id]"
                class="text-xs py-1 px-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 flex-1 focus:ring-1 focus:ring-teal-500 shadow-sm"
              >
                <option :value="null">-- Sin docente asignado --</option>
                <option v-for="t in institutionTeachers" :key="t.id" :value="t.id">
                  {{ t.full_name || t.email }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button @click="emit('close')" class="app-btn app-btn-ghost">Cancelar</button>
        <button @click="emit('save')" :disabled="subjectsSaving || subjectsLoading" class="app-btn app-btn-primary flex items-center gap-1.5">
          <span v-if="subjectsSaving" class="app-spinner w-3.5 h-3.5"></span>
          <span>{{ subjectsSaving ? 'Guardando...' : 'Guardar Materias' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>

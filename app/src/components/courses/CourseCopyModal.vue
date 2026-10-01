<script setup>
defineProps({
  show: {
    type: Boolean,
    default: false
  },
  academicYears: {
    type: Array,
    default: () => []
  },
  selectedAcademicYear: {
    type: [String, Number],
    default: null
  },
  copyFromYear: {
    type: [String, Number],
    default: null
  },
  copyingCourses: {
    type: Boolean,
    default: false
  },
  copyResult: {
    type: Array,
    default: null
  }
})

const emit = defineEmits(['close', 'copy', 'update:copyFromYear'])
</script>

<template>
  <div v-if="show" class="modal-container" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="modal-backdrop" aria-hidden="true" @click="emit('close')"></div>
    <div class="modal-panel sm:max-w-lg w-full">
      <div class="modal-body">
        <h3 class="text-lg leading-6 font-medium text-slate-900 dark:text-white" id="modal-title">
          Copiar Cursos de Otro Año Lectivo
        </h3>
        <div class="mt-4">
          <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
            Copia los cursos de un año lectivo anterior al año actual.
            Las materias de cada curso también se copian.
          </p>
          <select 
            :value="copyFromYear" 
            @change="emit('update:copyFromYear', $event.target.value)" 
            class="app-input w-full"
          >
            <option :value="null">Selecciona el año lectivo de origen</option>
            <option 
              v-for="year in academicYears.filter(y => y.id !== selectedAcademicYear)" 
              :key="year.id" 
              :value="year.id"
            >
              {{ year.name }}
            </option>
          </select>
          <div v-if="copyResult && copyResult.length > 0" class="mt-4 p-3 bg-emerald-50 border border-emerald-200 rounded-md">
            <p class="text-sm text-emerald-700">
              Se copiaron {{ copyResult.length }} cursos exitosamente.
            </p>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button 
          @click="emit('copy')" 
          :disabled="!copyFromYear || copyingCourses" 
          class="app-btn app-btn-primary w-full sm:w-auto"
        >
          {{ copyingCourses ? 'Copiando...' : 'Copiar Cursos' }}
        </button>
        <button @click="emit('close')" class="app-btn app-btn-ghost w-full sm:w-auto mt-3 sm:mt-0">
          Cerrar
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { 
  Search, 
  CheckCircle, 
  Calendar, 
  FileText, 
  User, 
  Clock, 
  ShieldCheck, 
  AlertCircle, 
  Loader2, 
  ArrowRight 
} from 'lucide-vue-next'

const props = defineProps({
  students: { type: Array, default: () => [] },
  selectedStudent: { type: Object, default: null },
  unexcusedAbsences: { type: Array, default: () => [] },
  selectedDates: { type: Array, default: () => [] },
  reason: { type: String, required: true },
  loading: { type: Boolean, default: false },
  onSelectStudent: { type: Function, required: true },
  onSubmitJustification: { type: Function, required: true }
})

const emit = defineEmits(['update:reason', 'update:selectedDates'])

const studentSearch = ref('')

const filteredStudents = computed(() => {
  const term = studentSearch.value.trim().toLowerCase()
  if (!term) return props.students.slice(0, 15)
  return props.students.filter(s => 
    s.full_name?.toLowerCase().includes(term) || 
    s.student_cedula?.includes(term)
  ).slice(0, 15)
})

const toggleDate = (dateStr) => {
  const current = [...props.selectedDates]
  const idx = current.indexOf(dateStr)
  if (idx > -1) {
    current.splice(idx, 1)
  } else {
    current.push(dateStr)
  }
  emit('update:selectedDates', current)
}

const selectAllDates = () => {
  const allDates = props.unexcusedAbsences.map(a => a.attendance_date)
  emit('update:selectedDates', allDates)
}

const clearSelectedDates = () => {
  emit('update:selectedDates', [])
}
</script>

<template>
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    
    <!-- Columna 1: Búsqueda y Selección de Estudiante -->
    <div class="lg:col-span-1 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4 shadow-sm flex flex-col space-y-4">
      <div class="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-800">
        <div class="p-2 rounded-xl bg-teal-500/10 text-teal-600 dark:text-teal-400">
          <User class="w-5 h-5" />
        </div>
        <div>
          <h3 class="font-bold text-sm text-slate-900 dark:text-white">Buscar Estudiante</h3>
          <p class="text-[11px] text-slate-500">Selecciona el alumno para justificar faltas</p>
        </div>
      </div>

      <!-- Buscador -->
      <div class="relative">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
        <input
          v-model="studentSearch"
          type="text"
          placeholder="Nombre o cédula del estudiante..."
          class="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none placeholder-slate-400"
        />
      </div>

      <!-- Lista de Estudiantes -->
      <div class="flex-1 overflow-y-auto max-h-[420px] custom-scrollbar space-y-1.5 pr-1">
        <button
          v-for="st in filteredStudents"
          :key="st.id"
          type="button"
          @click="onSelectStudent(st)"
          :class="[
            'w-full p-2.5 rounded-xl text-left transition-all flex items-center justify-between border cursor-pointer',
            selectedStudent?.id === st.id
              ? 'border-teal-500 bg-teal-500/10 dark:bg-teal-500/15 ring-1 ring-teal-500/40 text-teal-900 dark:text-teal-200'
              : 'border-slate-100 dark:border-slate-800/80 bg-white dark:bg-slate-950 hover:border-slate-200 dark:hover:border-slate-700'
          ]"
        >
          <div>
            <strong class="text-xs text-slate-900 dark:text-white font-bold block">{{ st.full_name }}</strong>
            <span class="text-[10px] text-slate-500 dark:text-slate-400 font-mono">
              C.I. {{ st.student_cedula || 'N/A' }}
            </span>
          </div>
          <ArrowRight class="w-4 h-4 text-slate-400 shrink-0" />
        </button>

        <div v-if="filteredStudents.length === 0" class="p-6 text-center text-xs text-slate-400">
          No se encontraron estudiantes
        </div>
      </div>
    </div>

    <!-- Columna 2: Faltas Pendientes y Formulario de Justificación -->
    <div class="lg:col-span-2 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-5">
      
      <div v-if="selectedStudent" class="space-y-5">
        
        <!-- Header del Estudiante Seleccionado -->
        <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 flex items-center justify-between flex-wrap gap-3">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-teal-600 text-white font-bold flex items-center justify-center text-sm shadow-md">
              {{ selectedStudent.full_name?.charAt(0) || 'E' }}
            </div>
            <div>
              <h4 class="font-bold text-sm text-slate-900 dark:text-white">{{ selectedStudent.full_name }}</h4>
              <p class="text-xs text-slate-500">
                C.I. {{ selectedStudent.student_cedula }} • Representante: {{ selectedStudent.representative_name || 'N/A' }}
              </p>
            </div>
          </div>

          <div class="text-right">
            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-rose-500/10 text-rose-600 border border-rose-500/20">
              {{ unexcusedAbsences.length }} Faltas / Atrasos Pendientes
            </span>
          </div>
        </div>

        <!-- Lista de Inasistencias con Checkbox -->
        <div class="space-y-2.5">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300">
              1. Selecciona las fechas a justificar:
            </label>
            <div class="flex items-center gap-2">
              <button
                type="button"
                @click="selectAllDates"
                class="text-[11px] font-bold text-teal-600 hover:underline cursor-pointer"
              >
                Seleccionar todas
              </button>
              <span class="text-slate-300">|</span>
              <button
                type="button"
                @click="clearSelectedDates"
                class="text-[11px] font-bold text-slate-500 hover:underline cursor-pointer"
              >
                Limpiar
              </button>
            </div>
          </div>

          <div v-if="unexcusedAbsences.length > 0" class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-60 overflow-y-auto custom-scrollbar p-1">
            <label
              v-for="abs in unexcusedAbsences"
              :key="abs.id"
              :class="[
                'p-3 rounded-xl border flex items-center gap-3 cursor-pointer transition-all',
                selectedDates.includes(abs.attendance_date)
                  ? 'border-teal-500 bg-teal-500/10 dark:bg-teal-500/15 ring-1 ring-teal-500/40'
                  : 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-950 hover:border-slate-300'
              ]"
            >
              <input
                type="checkbox"
                :checked="selectedDates.includes(abs.attendance_date)"
                @change="toggleDate(abs.attendance_date)"
                class="w-4 h-4 rounded text-teal-600 focus:ring-teal-500 border-slate-300"
              />
              <div class="flex-1 text-xs">
                <div class="flex items-center justify-between">
                  <strong class="text-slate-900 dark:text-white font-bold">📅 {{ abs.attendance_date }}</strong>
                  <span :class="[
                    'px-2 py-0.5 rounded text-[10px] font-bold uppercase',
                    abs.status === 'atraso' ? 'bg-amber-100 text-amber-800' : 'bg-rose-100 text-rose-800'
                  ]">
                    {{ abs.status === 'atraso' ? 'Atraso' : 'Falta Injustificada' }}
                  </span>
                </div>
                <p class="text-[11px] text-slate-500 mt-0.5">
                  {{ abs.subjects?.name || 'Jornada general' }} {{ abs.observations ? `(${abs.observations})` : '' }}
                </p>
              </div>
            </label>
          </div>

          <div v-else class="p-6 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-center text-xs text-emerald-700 dark:text-emerald-300">
            <CheckCircle class="w-6 h-6 mx-auto mb-1 text-emerald-600" />
            Este estudiante no registra faltas injustificadas ni atrasos pendientes.
          </div>
        </div>

        <!-- Formulario de Motivo de Justificación -->
        <div v-if="unexcusedAbsences.length > 0" class="space-y-4 pt-2 border-t border-slate-100 dark:border-slate-800">
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              2. Motivo y Justificativo Institucional (Certificado Médico / Calamidad): *
            </label>
            <textarea
              :value="reason"
              @input="emit('update:reason', $event.target.value)"
              rows="3"
              placeholder="Ej. Presenta certificado médico del Ministerio de Salud Pública por reposo de 48 horas..."
              class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
            ></textarea>
          </div>

          <!-- Botón de Aplicar Justificación -->
          <div class="flex justify-end">
            <button
              type="button"
              :disabled="loading || selectedDates.length === 0 || !reason.trim()"
              @click="onSubmitJustification"
              class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-xs font-bold shadow-lg shadow-teal-900/20 transition-all disabled:opacity-50 cursor-pointer"
            >
              <ShieldCheck class="w-4 h-4" />
              {{ loading ? 'Procesando...' : `Justificar ${selectedDates.length} Faltas Seleccionadas` }}
            </button>
          </div>
        </div>

      </div>

      <!-- Estado Vacío Inicial -->
      <div v-else class="p-16 text-center space-y-3">
        <div class="w-14 h-14 rounded-2xl bg-slate-100 dark:bg-slate-800 text-slate-400 flex items-center justify-center mx-auto">
          <Search class="w-7 h-7" />
        </div>
        <h4 class="font-bold text-sm text-slate-800 dark:text-slate-200">Selecciona un estudiante para comenzar</h4>
        <p class="text-xs text-slate-500 max-w-sm mx-auto">
          Utiliza el buscador de la izquierda para ubicar al estudiante y revisar su historial de inasistencias.
        </p>
      </div>

    </div>

  </div>
</template>

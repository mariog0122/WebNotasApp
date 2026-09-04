<script setup>
import { reactive } from 'vue'
import { 
  X, 
  Sparkles, 
  User, 
  TrendingUp, 
  CheckCircle2, 
  AlertTriangle, 
  Calendar, 
  ShieldCheck,
  Loader2,
  HeartHandshake
} from 'lucide-vue-next'
import { STUDENT_SUPPORT_CATEGORIES } from '../../lib/ecuadorCurriculumCatalog'

const props = defineProps({
  student: {
    type: Object,
    required: true
  },
  plan: {
    type: Object,
    required: true
  },
  generating: {
    type: Boolean,
    default: false
  },
  onSubmit: {
    type: Function,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  }
})

const form = reactive({
  supportType: 'refuerzo',
  observedDifficulty: 'Dificultad en la resolución de ejercicios de aplicación práctica y cálculo.',
  evidenceType: 'calificacion', // calificacion | rubrica | tarea | observacion | inasistencia
  intensity: 'moderada', // leve | moderada | intensiva
  durationWeeks: 2,
  targetDate: new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10),
  observations: ''
})

const handleSave = () => {
  props.onSubmit(props.student.id, { ...form })
}
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-900/80">
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-2xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20">
            <HeartHandshake class="w-6 h-6" />
          </div>
          <div>
            <h2 class="text-base font-bold text-slate-900 dark:text-white">Plan de Apoyo Pedagógico Individual</h2>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Estudiante: <strong class="text-slate-900 dark:text-white">{{ student.full_name }}</strong>
            </p>
          </div>
        </div>

        <button
          @click="onClose"
          type="button"
          class="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Form Body -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-5">
        
        <!-- Tipo de Apoyo -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Objetivo de la Intervención</label>
          <select
            v-model="form.supportType"
            class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
          >
            <option v-for="cat in STUDENT_SUPPORT_CATEGORIES" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
          </select>
        </div>

        <!-- Dificultad Observada -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Dificultad Pedagógica Observada</label>
          <textarea
            v-model="form.observedDifficulty"
            rows="2"
            class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none placeholder-slate-400"
            placeholder="Describe brevemente la dificultad específica detectada en la materia..."
          ></textarea>
        </div>

        <!-- Evidencia e Intensidad -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Evidencia de Origen</label>
            <select
              v-model="form.evidenceType"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
            >
              <option value="calificacion">Calificación menor a 7/10</option>
              <option value="rubrica">Rúbrica de evaluación formativa</option>
              <option value="tarea">Tareas o talleres incompletos</option>
              <option value="observacion">Observación directa en clase</option>
              <option value="inasistencia">Inasistencias justificadas/reiteradas</option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Intensidad del Apoyo</label>
            <div class="grid grid-cols-3 gap-1.5">
              <button
                v-for="intVal in [{ id: 'leve', label: 'Leve' }, { id: 'moderada', label: 'Moderada' }, { id: 'intensiva', label: 'Intensiva' }]"
                :key="intVal.id"
                @click="form.intensity = intVal.id"
                type="button"
                :class="[
                  'py-2 rounded-xl border text-center text-xs font-bold transition-all',
                  form.intensity === intVal.id
                    ? 'border-indigo-500 bg-indigo-600 text-white'
                    : 'border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-50'
                ]"
              >
                {{ intVal.label }}
              </button>
            </div>
          </div>
        </div>

        <!-- Duración y Fecha Límite -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Duración (Semanas)</label>
            <input
              v-model.number="form.durationWeeks"
              type="number"
              min="1"
              max="6"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
            />
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Fecha de Cierre / Evaluación</label>
            <input
              v-model="form.targetDate"
              type="date"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
            />
          </div>
        </div>

        <!-- Alerta de Privacidad -->
        <div class="p-3.5 rounded-2xl bg-teal-50 dark:bg-teal-500/10 border border-teal-200 dark:border-teal-500/20 text-xs text-teal-800 dark:text-teal-300 flex items-start gap-2.5">
          <ShieldCheck class="w-4 h-4 text-teal-600 dark:text-teal-400 mt-0.5 shrink-0" />
          <p>
            <strong>Privacidad protegida:</strong> La propuesta se genera mediante identificadores anonimizados sin enviar nombres ni datos clínicos al proveedor de IA.
          </p>
        </div>

      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t border-slate-200 dark:border-slate-800 flex items-center justify-end gap-3 bg-slate-50 dark:bg-slate-900/80">
        <button
          @click="onClose"
          type="button"
          class="px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          Cancelar
        </button>

        <button
          @click="handleSave"
          :disabled="generating"
          type="button"
          class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/20 transition-all cursor-pointer disabled:opacity-50"
        >
          <Loader2 v-if="generating" class="w-4 h-4 animate-spin" />
          <Sparkles v-else class="w-4 h-4" />
          <span>{{ generating ? 'Generando Propuesta...' : 'Generar y Aprobar Plan' }}</span>
        </button>
      </div>

    </div>
  </div>
</template>
